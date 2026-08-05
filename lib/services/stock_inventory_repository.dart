import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockInventoryRepository {
  StockInventoryRepository({SupabaseClient? client})
      : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first query.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const itemsTable = 'stock_items';
  static const batchesTable = 'stock_batch_balances';
  static const movementsTable = 'stock_movements';
  static const ordersTable = 'stock_orders';
  static const ginTable = 'stock_gin_bills';
  static const consumptionTable = 'stock_consumption';
  static const transfersTable = 'stock_transfers';

  Future<List<StockInventoryItem>> fetchItems() async {
    final response = await _client
        .from(itemsTable)
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);
    return (response as List)
        .map((row) => StockInventoryItem.fromJson(_asMap(row)))
        .toList();
  }

  /// All catalog items including soft-deleted (inactive) ones — used by the
  /// Manage Items screen so deleted items can be restored or seen.
  Future<List<StockInventoryItem>> fetchAllItems() async {
    final response = await _client
        .from(itemsTable)
        .select()
        .order('name', ascending: true);
    return (response as List)
        .map((row) => StockInventoryItem.fromJson(_asMap(row)))
        .toList();
  }

  /// Adds a new catalog item (permanent). `stock_items.id` is TEXT in the
  /// live schema, so the id is generated here.
  Future<bool> addStockItem({
    required String name,
    required String uom,
    String? code,
    String? category,
    String? groupName,
  }) async {
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return false;
      final generatedCode = (code == null || code.trim().isEmpty)
          ? 'ITEM-${DateTime.now().millisecondsSinceEpoch}'
          : code.trim();
      await _client.from(itemsTable).insert({
        'id': 'ITEM-${DateTime.now().millisecondsSinceEpoch}',
        'code': generatedCode,
        'item_code': generatedCode,
        'name': trimmed,
        'item_name': trimmed,
        'group_name': groupName ?? 'General',
        'category': category ?? 'General',
        'uom': uom.trim().isEmpty ? 'units' : uom.trim(),
        'primary_uom': uom.trim().isEmpty ? 'units' : uom.trim(),
        'batch_required': true,
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('addStockItem failed: $e');
      return false;
    }
  }

  /// Soft-delete / restore a catalog item (is_active=false hides it from
  /// every dropdown and list; history is preserved).
  Future<bool> setStockItemActive(String itemId, bool active) async {
    try {
      await _client
          .from(itemsTable)
          .update({'is_active': active,
                   'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('setStockItemActive failed: $e');
      return false;
    }
  }

  Future<List<StockBatchBalance>> fetchBatchBalances() async {
    final response = await _client
        .from(batchesTable)
        .select()
        .gt('available_qty', 0)
        .order('item_name', ascending: true)
        .order('batch_id', ascending: true);
    return (response as List)
        .map((row) => StockBatchBalance.fromJson(_asMap(row)))
        .toList();
  }

  RealtimeChannel watchBatchBalances(void Function() onChanged) {
    return _client
        .channel('public:$batchesTable')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: batchesTable,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> stopWatching(RealtimeChannel? channel) async {
    if (channel == null) return;
    await _client.removeChannel(channel);
  }

  /// Issues stock through the database transaction used by all supervisor
  /// modules. The server locks the balance, prevents negative stock and makes
  /// retries safe using (module, sourceReference, balance) idempotency.
  Future<StockModuleIssueResult> issueForModule({
    required String? siteId,
    required String module,
    required String sourceReference,
    required String stockBalanceId,
    required double quantity,
    required String note,
  }) async {
    final response = await _client.rpc('issue_stock_for_module', params: {
      'p_site_id': siteId,
      'p_module': module,
      'p_source_reference': sourceReference,
      'p_stock_balance_id': stockBalanceId,
      'p_quantity': quantity,
      'p_note': note,
    });
    final rows = response as List;
    if (rows.isEmpty) throw StateError('Stock issue was not recorded.');
    return StockModuleIssueResult.fromJson(_asMap(rows.first));
  }

  /// Finds an available balance for a named fuel stock point. Matching is
  /// deliberate: never silently take fuel from a different point.
  Future<StockBatchBalance> findFuelBalance({
    required String stockPointName,
    required String fuelType,
  }) async {
    final balances = await fetchBatchBalances();
    final normalizedFuel = fuelType.trim().toLowerCase();
    final candidates = balances.where((balance) {
      final isFuel = balance.itemName.toLowerCase().contains(normalizedFuel) ||
          balance.itemCode.toLowerCase().contains(normalizedFuel);
      return isFuel &&
          balance.stockPointName.trim().toLowerCase() ==
              stockPointName.trim().toLowerCase();
    }).toList();
    if (candidates.isEmpty) {
      throw StateError('No $fuelType stock is available at $stockPointName.');
    }
    return candidates.first;
  }

  Future<void> issueBatchStock({
    required String itemId,
    required String batchBalanceId,
    required String batchId,
    required String stockPointId,
    required double quantity,
    required double looseQuantity,
    required String movementType,
    required String reason,
    required String referenceId,
    String? toStockPointId,
    String? photoName,
  }) async {
    final current = await _client
        .from(batchesTable)
        .select('available_qty, loose_qty')
        .eq('id', batchBalanceId)
        .single();
    final row = _asMap(current);
    final available = _toDouble(row['available_qty']);
    final loose = _toDouble(row['loose_qty']);
    if (quantity <= 0 || quantity > available) {
      throw StateError(
          'Insufficient stock for $batchId. Available: $available.');
    }

    await _client.from(movementsTable).insert({
      'reference_id': referenceId,
      'movement_type': movementType,
      'item_id': itemId,
      'batch_balance_id': batchBalanceId,
      'batch_id': batchId,
      'from_stock_point_id': stockPointId,
      'to_stock_point_id': toStockPointId,
      'quantity': quantity,
      'loose_quantity': looseQuantity,
      'reason': reason,
      'photo_name': photoName,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _client.from(batchesTable).update({
      'available_qty': available - quantity,
      'loose_qty': (loose - looseQuantity).clamp(0, double.infinity),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', batchBalanceId);
  }

  /// Returns stock back into a balance (e.g. supervisor return, unused
  /// material). Adds quantity to the batch and writes a 'return' movement.
  /// Idempotent on referenceId so retries cannot double-return.
  Future<bool> returnStock({
    required String? siteId,
    required StockBatchBalance balance,
    required double quantity,
    required String reason,
    required String referenceId,
  }) async {
    try {
      if (quantity <= 0) return false;
      final existing = await _client
          .from(movementsTable)
          .select('id')
          .eq('reference_id', referenceId)
          .maybeSingle();
      if (existing != null) return true;

      final current = await _client
          .from(batchesTable)
          .select('available_qty, loose_qty')
          .eq('id', balance.id)
          .single();
      final row = _asMap(current);
      final available = _toDouble(row['available_qty']);
      final loose = _toDouble(row['loose_qty']);

      await _client.from(batchesTable).update({
        'available_qty': available + quantity,
        'loose_qty': loose,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', balance.id);

      await _client.from(movementsTable).insert({
        'reference_id': referenceId,
        'movement_type': 'return',
        'item_id': balance.itemId,
        'batch_balance_id': balance.id,
        'batch_id': balance.batchId,
        'from_stock_point_id': balance.stockPointId,
        'quantity': quantity,
        'loose_quantity': 0,
        'reason': 'Return — $reason',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error returning stock: $e');
      return false;
    }
  }

  Future<List<StockMovementRecord>> fetchMovements({int limit = 100}) async {
    final response = await _client
        .from(movementsTable)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((row) => StockMovementRecord.fromJson(_asMap(row)))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ORDERS (placed by HOD, received by supervisor)
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<StockOrder>> fetchOrders() async {
    final response = await _client
        .from(ordersTable)
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => StockOrder.fromJson(_asMap(row)))
        .toList();
  }

  /// HOD places ONE order with MULTIPLE items at once. Every line becomes a
  /// stock_orders row sharing the same order_no (an order group), inserted
  /// atomically through the `stock_place_multi_order` RPC.
  Future<bool> placeMultiOrder({
    required String orderNo,
    required String? siteId,
    required String stockPointId,
    required String stockPointName,
    String? thavvuPointId,
    required List<StockOrderItemDraft> items,
    String? notes,
  }) async {
    try {
      final result = await _client.rpc('stock_place_multi_order', params: {
        'p_order_no': orderNo,
        'p_site_id': siteId,
        'p_stock_point_id': stockPointId,
        'p_stock_point_name': stockPointName,
        'p_thavvu_point_id': thavvuPointId,
        'p_notes': notes,
        'p_items': [
          for (final item in items)
            {
              if (item.itemId != null && item.itemId!.isNotEmpty)
                'item_id': item.itemId,
              'item_name': item.itemName,
              'item_code': item.itemCode,
              'batch': item.batch,
              'quantity': item.quantity,
              'unit': item.unit,
              'notes': item.notes,
            },
        ],
      });
      return _asMap(result)['ok'] == true;
    } catch (e) {
      debugPrint('placeMultiOrder failed: $e');
      return false;
    }
  }

  /// HOD places an order for a stock item (single-line convenience wrapper,
  /// kept for existing callers — new UI uses [placeMultiOrder]).
  Future<bool> placeOrder({
    required String orderNo,
    required String? siteId,
    required String stockPointId,
    required String stockPointName,
    required String itemId,
    required String itemName,
    required String batch,
    required double quantity,
    required String unit,
    String? notes,
    String? thavvuPointId,
  }) async {
    try {
      await _client.from(ordersTable).insert({
        'order_no': orderNo,
        'site_id': siteId,
        'thavvu_point_id': thavvuPointId,
        'stock_point_id': stockPointId,
        'stock_point_name': stockPointName,
        'item_id': itemId,
        'item_name': itemName,
        'batch': batch,
        'quantity': quantity,
        'unit': unit,
        'status': 'placed',
        'notes': notes,
        'placed_by': _client.auth.currentUser?.email ?? 'HOD',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error placing stock order: $e');
      return false;
    }
  }

  /// Supervisor receives a placed order group: the RPC creates ONE
  /// multi-item GIN bill from every line of the order and marks the order
  /// rows 'received'. Returns the created bill's id + gin_no (or null).
  Future<Map<String, String>?> receiveOrderToGin(String orderNo) async {
    try {
      final result = await _client
          .rpc('gin_create_from_order', params: {'p_order_no': orderNo});
      final map = _asMap(result);
      if (map['ok'] != true) return null;
      return {
        'id': map['id']?.toString() ?? '',
        'gin_no': map['gin_no']?.toString() ?? '',
      };
    } catch (e) {
      debugPrint('receiveOrderToGin failed: $e');
      return null;
    }
  }

  /// Manual stock entry: adds stock at a Thavvu Point (creates the item if
  /// needed, upserts the batch balance, writes a 'manual_in' movement).
  /// Returns the created balance details or null on failure.
  Future<Map<String, dynamic>?> manualStockEntry({
    required String itemName,
    required double quantity,
    required String thavvuPointId,
    required String thavvuPointName,
    String uom = 'units',
    String? batch,
    String? note,
    String? itemCode,
    String? siteId,
  }) async {
    try {
      final result = await _client.rpc('stock_manual_entry', params: {
        'p_item_name': itemName,
        'p_quantity': quantity,
        'p_thavvu_point_id': thavvuPointId,
        'p_thavvu_point_name': thavvuPointName,
        'p_uom': uom,
        'p_batch': batch,
        'p_note': note,
        'p_item_code': itemCode,
        'p_site_id': siteId,
      });
      final map = _asMap(result);
      if (map['ok'] != true) return null;
      return map;
    } catch (e) {
      debugPrint('manualStockEntry failed: $e');
      return null;
    }
  }

  /// Supervisor marks an order as received. Creates a GIN bill row that
  /// appears in the GIN tab for item/quantity review before adding stock.
  Future<bool> markOrderReceived(StockOrder order) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from(ordersTable)
          .update({'status': 'received', 'updated_at': now})
          .eq('id', order.id);
      final ginNo = 'GIN-${now.substring(0, 10).replaceAll('-', '')}-'
          '${order.orderNo.replaceAll(RegExp('[^0-9]'), '').padLeft(3, '0')}';
      await _client.from(ginTable).insert({
        'gin_no': ginNo,
        'site_id': order.siteId,
        'order_id': order.id,
        'stock_point_id': order.stockPointId,
        'stock_point_name': order.stockPointName,
        'item_id': order.itemId,
        'item_name': order.itemName,
        'batch': order.batch,
        'quantity': order.quantity,
        'unit': order.unit,
        'status': 'pending_review',
        'received_by': _client.auth.currentUser?.email ?? 'supervisor',
        'created_at': now,
      });
      return true;
    } catch (e) {
      debugPrint('Error marking order received: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GIN BILLS — review received goods, then add to stock
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<StockGinBill>> fetchGinBills() async {
    final response = await _client
        .from(ginTable)
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => StockGinBill.fromJson(_asMap(row)))
        .toList();
  }

  /// Review a GIN bill and add the goods into stock:
  ///  - upserts the batch balance (adds qty to existing batch or creates it)
  ///  - records a 'gin' stock movement
  ///  - marks the bill 'added_to_stock'
  Future<bool> reviewGinAddToStock(
    StockGinBill bill, {
    double? overrideQuantity,
  }) async {
    try {
      final qty = overrideQuantity ?? bill.quantity;
      if (qty <= 0) return false;
      await _addToBatchBalance(
        itemId: bill.itemId,
        itemName: bill.itemName,
        itemCode: bill.itemName,
        pointId: bill.stockPointId,
        pointName: bill.stockPointName,
        batch: bill.batch,
        qty: qty,
        loose: 0,
      );
      await _client.from(movementsTable).insert({
        'reference_id': bill.ginNo,
        'movement_type': 'gin',
        'item_id': bill.itemId,
        'batch_id': bill.batch,
        'to_stock_point_id': bill.stockPointId,
        'quantity': qty,
        'loose_quantity': 0,
        'reason': 'Goods inward — ${bill.itemName}',
        'photo_name': bill.photoName,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _client.from(ginTable).update({
        'status': 'added_to_stock',
        'reviewed_by': _client.auth.currentUser?.email ?? 'supervisor',
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bill.id);
      return true;
    } catch (e) {
      debugPrint('Error adding GIN to stock: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HOD GIN REVIEW — approve / reject / comment on supervisor GIN actions
  // ═══════════════════════════════════════════════════════════════════════

  /// HOD reviews a GIN bill submitted by the supervisor. Sets hod_status,
  /// hod_note and review metadata so the supervisor sees the decision and
  /// the flow closes (approved → add to stock, rejected → supervisor fixes).
  Future<bool> reviewGinAsHod({
    required StockGinBill bill,
    required String status, // 'approved' | 'rejected'
    String? note,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from(ginTable).update({
        'hod_status': status,
        'hod_note': note,
        'hod_reviewed_by': _client.auth.currentUser?.email ?? 'HOD',
        'hod_reviewed_at': now,
      }).eq('id', bill.id);
      return true;
    } catch (e) {
      debugPrint('Error reviewing GIN as HOD: $e');
      return false;
    }
  }

  /// Movements for one item (audit trail shown in the HOD stock detail).
  Future<List<StockMovementRecord>> fetchMovementsForItem(
    String itemId, {
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from(movementsTable)
          .select()
          .eq('item_id', itemId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((row) => StockMovementRecord.fromJson(_asMap(row)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching movements for item: $e');
      return const <StockMovementRecord>[];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONSUMPTION — batch quantity + photo proof, auto stock deduction
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<StockConsumption>> fetchConsumptions() async {
    final response = await _client
        .from(consumptionTable)
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => StockConsumption.fromJson(_asMap(row)))
        .toList();
  }

  /// Record consumption: deducts the batch balance and writes a
  /// consumption row + an 'issue' stock movement.
  Future<bool> recordConsumption({
    required String? siteId,
    required StockBatchBalance balance,
    required double quantity,
    required double looseQuantity,
    required String reason,
    String? photoName,
    String? thavvuPointId,
  }) async {
    try {
      if (quantity <= 0 && looseQuantity <= 0) return false;
      if (quantity > balance.availableQty) return false;
      await _client.from(batchesTable).update({
        'available_qty': balance.availableQty - quantity,
        'loose_qty': (balance.looseQty - looseQuantity).clamp(0, double.infinity),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', balance.id);
      await _client.from(consumptionTable).insert({
        'site_id': siteId,
        'thavvu_point_id': thavvuPointId,
        'stock_point_id': balance.stockPointId,
        'stock_point_name': balance.stockPointName,
        'item_id': balance.itemId,
        'item_name': balance.itemName,
        'batch_id': balance.batchId,
        'batch_code': balance.batchCode,
        'quantity': quantity,
        'loose_quantity': looseQuantity,
        'uom': 'units',
        'reason': reason,
        'photo_name': photoName,
        'consumed_by': _client.auth.currentUser?.email ?? 'supervisor',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _client.from(movementsTable).insert({
        'reference_id': 'CONS-${DateTime.now().millisecondsSinceEpoch}',
        'movement_type': 'issue',
        'item_id': balance.itemId,
        'batch_balance_id': balance.id,
        'batch_id': balance.batchId,
        'from_stock_point_id': balance.stockPointId,
        'quantity': quantity,
        'loose_quantity': looseQuantity,
        'reason': 'Consumption — $reason',
        'photo_name': photoName,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error recording consumption: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INTERNAL TRANSFERS — deliver deducts sender, receive adds receiver
  // ═══════════════════════════════════════════════════════════════════════

  /// Transfers, optionally scoped by direction so a supervisor's
  /// Delivering tab only lists transfers sent FROM their points and the
  /// Receiving tab only lists transfers TO their points.
  Future<List<StockTransfer>> fetchTransfers({
    List<String>? fromPointIds,
    List<String>? toPointIds,
    int limit = 200,
  }) async {
    var query = _client.from(transfersTable).select();
    if (fromPointIds != null && fromPointIds.isNotEmpty) {
      query = query.inFilter('from_point_id', fromPointIds);
    }
    if (toPointIds != null && toPointIds.isNotEmpty) {
      query = query.inFilter('to_point_id', toPointIds);
    }
    final response = await query
        .order('initiated_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((row) => StockTransfer.fromJson(_asMap(row)))
        .toList();
  }

  /// All Thavvu Points HOD created for a site — the enterprise transfer
  /// nodes. Stock moves between these points (no warehouse layer).
  Future<List<Map<String, dynamic>>> fetchThavvuPointsForSite(
    String? siteId,
  ) async {
    if (siteId == null || siteId.isEmpty) return const [];
    try {
      final response = await _client
          .from('thavvu_points')
          .select('id, point_name')
          .eq('site_id', siteId)
          .order('created_at', ascending: true);
      return (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } catch (e) {
      debugPrint('fetchThavvuPointsForSite failed: $e');
      return const [];
    }
  }

  Future<bool> createTransfer({
    required String transferNo,
    required String? siteId,
    required String fromPointId,
    required String fromPoint,
    required String toPointId,
    required String toPoint,
    required String itemId,
    required String itemName,
    required String batch,
    required double quantity,
    required double looseQuantity,
    required String unit,
    String? notes,
    String? thavvuPointId,
    String? fromThavvuPointId,
    String? fromThavvuPoint,
    String? toThavvuPointId,
    String? toThavvuPoint,
  }) async {
    try {
      await _client.from(transfersTable).insert({
        'transfer_no': transferNo,
        'site_id': siteId,
        'thavvu_point_id': thavvuPointId,
        'from_point_id': fromPointId,
        'from_point': fromPoint,
        'to_point_id': toPointId,
        'to_point': toPoint,
        // Enterprise tracking: always record which Thavvu Points the goods
        // were sent from / to (default to the endpoint values for legacy
        // callers that do not pass them explicitly).
        'from_thavvu_point_id': fromThavvuPointId ?? fromPointId,
        'from_thavvu_point': fromThavvuPoint ?? fromPoint,
        'to_thavvu_point_id': toThavvuPointId ?? toPointId,
        'to_thavvu_point': toThavvuPoint ?? toPoint,
        'item_id': itemId,
        'item_name': itemName,
        'batch': batch,
        'quantity': quantity,
        'loose_quantity': looseQuantity,
        'unit': unit,
        'status': 'initiated',
        'notes': notes,
        'initiated_by': _client.auth.currentUser?.email ?? 'supervisor',
        'initiated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error creating transfer: $e');
      return false;
    }
  }

  /// Mark a transfer delivered: deducts stock from the sender point.
  ///
  /// Idempotent: if the transfer is already delivered (or further along),
  /// the call is a no-op success so retries and realtime races cannot
  /// double-deduct the sender's stock.
  Future<bool> markTransferDelivered(
    StockTransfer transfer, {
    StockBatchBalance? senderBalance,
  }) async {
    try {
      if (transfer.status == 'delivered' || transfer.status == 'received') {
        return true;
      }
      if (transfer.status != 'initiated') return false;
      final balance = senderBalance ??
          await _findBalance(
            itemId: transfer.itemId,
            pointId: transfer.fromPointId,
            batch: transfer.batch,
          );
      if (balance == null) return false;
      if (transfer.quantity > balance.availableQty) return false;
      await _client.from(batchesTable).update({
        'available_qty': balance.availableQty - transfer.quantity,
        'loose_qty': (balance.looseQty - transfer.looseQuantity)
            .clamp(0, double.infinity),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', balance.id);
      await _client.from(transfersTable).update({
        'status': 'delivered',
        'delivered_by': _client.auth.currentUser?.email ?? 'supervisor',
        'delivered_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', transfer.id);
      await _client.from(movementsTable).insert({
        'reference_id': transfer.transferNo,
        'movement_type': 'transfer_out',
        'item_id': transfer.itemId,
        'batch_balance_id': balance.id,
        'batch_id': transfer.batch,
        'from_stock_point_id': transfer.fromPointId,
        'to_stock_point_id': transfer.toPointId,
        'quantity': transfer.quantity,
        'loose_quantity': transfer.looseQuantity,
        'reason': 'Internal transfer out — ${transfer.itemName}',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking transfer delivered: $e');
      return false;
    }
  }

  /// Mark a transfer received: adds stock to the receiver point.
  ///
  /// The receiver must first verify the goods (the checklist), then this
  /// records the actually received quantity, condition and notes before
  /// adding stock. Idempotent: already-received transfers are a no-op so
  /// double taps cannot double-add to the receiver's stock.
  Future<bool> markTransferReceived(
    StockTransfer transfer, {
    double? receivedQuantity,
    String? condition,
    List<String>? checklist,
    String? notes,
    String? receivedByName,
  }) async {
    try {
      if (transfer.status == 'received') return true;
      if (transfer.status != 'delivered') return false;
      final receivedQty = receivedQuantity ?? transfer.quantity;
      if (receivedQty <= 0) return false;
      await _addToBatchBalance(
        itemId: transfer.itemId,
        itemName: transfer.itemName,
        itemCode: transfer.itemName,
        pointId: transfer.toPointId,
        pointName: transfer.toPoint,
        batch: transfer.batch,
        qty: receivedQty,
        loose: 0,
      );
      await _client.from(transfersTable).update({
        'status': 'received',
        'received_by': _client.auth.currentUser?.email ?? 'supervisor',
        'received_by_name': receivedByName,
        'received_at': DateTime.now().toUtc().toIso8601String(),
        'received_quantity': receivedQty,
        'received_condition': condition,
        'receive_checklist': checklist,
        'receive_notes': notes,
      }).eq('id', transfer.id);
      await _client.from(movementsTable).insert({
        'reference_id': transfer.transferNo,
        'movement_type': 'transfer_in',
        'item_id': transfer.itemId,
        'batch_id': transfer.batch,
        'from_stock_point_id': transfer.fromPointId,
        'to_stock_point_id': transfer.toPointId,
        'quantity': receivedQty,
        'loose_quantity': 0,
        'reason': 'Internal transfer in — ${transfer.itemName}',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking transfer received: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BATCH BALANCE HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<StockBatchBalance?> _findBalance({
    required String itemId,
    required String pointId,
    required String batch,
  }) async {
    final response = await _client
        .from(batchesTable)
        .select()
        .eq('item_id', itemId)
        .eq('stock_point_id', pointId)
        .eq('batch_id', batch)
        .limit(1);
    final list = response as List;
    if (list.isEmpty) return null;
    return StockBatchBalance.fromJson(_asMap(list.first));
  }

  /// Add quantity to a batch balance — updates the existing row for the
  /// (item, point, batch) or creates a new balance row.
  Future<void> _addToBatchBalance({
    required String itemId,
    required String itemName,
    required String itemCode,
    required String pointId,
    required String pointName,
    required String batch,
    required double qty,
    required double loose,
  }) async {
    final existing =
        await _findBalance(itemId: itemId, pointId: pointId, batch: batch);
    if (existing != null) {
      await _client.from(batchesTable).update({
        'available_qty': existing.availableQty + qty,
        'loose_qty': existing.looseQty + loose,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', existing.id);
    } else {
      await _client.from(batchesTable).insert({
        'item_id': itemId,
        'item_name': itemName,
        'item_code': itemCode,
        'stock_point_id': pointId,
        'stock_point_name': pointName,
        'location': pointName,
        'batch_id': batch,
        'batch_code': batch,
        'available_qty': qty,
        'loose_qty': loose,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REALTIME WATCHERS
  // ═══════════════════════════════════════════════════════════════════════

  RealtimeChannel watchOrders(void Function() onChanged) {
    return _client
        .channel('public:$ordersTable')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: ordersTable,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel watchGinBills(void Function() onChanged) {
    return _client
        .channel('public:$ginTable')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: ginTable,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel watchConsumptions(void Function() onChanged) {
    return _client
        .channel('public:$consumptionTable')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: consumptionTable,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel watchTransfers(void Function() onChanged) {
    return _client
        .channel('public:$transfersTable')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: transfersTable,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return Map<String, dynamic>.from(value as Map);
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class StockInventoryItem {
  final String id;
  final String code;
  final String name;
  final String group;
  final String category;
  final String uom;
  final String brand;
  final bool batchRequired;
  final double reorderLevel;
  final bool isActive;

  const StockInventoryItem({
    required this.id,
    required this.code,
    required this.name,
    required this.group,
    required this.category,
    required this.uom,
    required this.brand,
    required this.batchRequired,
    this.reorderLevel = 0,
    this.isActive = true,
  });

  factory StockInventoryItem.fromJson(Map<String, dynamic> json) {
    return StockInventoryItem(
      id: _string(json, 'id'),
      code: _string(json, 'code', fallback: _string(json, 'item_code')),
      name: _string(json, 'name', fallback: _string(json, 'item_name')),
      group: _string(json, 'group_name', fallback: _string(json, 'group')),
      isActive: json['is_active'] as bool? ?? true,
      category: _string(json, 'category'),
      uom: _string(json, 'uom', fallback: _string(json, 'primary_uom')),
      brand: _string(json, 'brand'),
      batchRequired: json['batch_required'] != false,
      reorderLevel: _double(json, 'reorder_level'),
    );
  }

  /// A reorder level of 0 means the item is not tracked for low stock.
  bool get tracksLowStock => reorderLevel > 0;
}

class StockModuleIssueResult {
  final String usageEventId;
  final double remainingQuantity;
  final bool wasAlreadyIssued;

  const StockModuleIssueResult({
    required this.usageEventId,
    required this.remainingQuantity,
    required this.wasAlreadyIssued,
  });

  factory StockModuleIssueResult.fromJson(Map<String, dynamic> json) {
    return StockModuleIssueResult(
      usageEventId: _string(json, 'usage_event_id'),
      remainingQuantity:
          double.tryParse(json['remaining_quantity']?.toString() ?? '') ?? 0,
      wasAlreadyIssued: json['was_already_issued'] == true,
    );
  }
}

class StockBatchBalance {
  final String id;
  final String itemId;
  final String itemName;
  final String itemCode;
  final String stockPointId;
  final String stockPointName;
  final String location;
  final String batchId;
  final double availableQty;
  final double looseQty;
  final DateTime? updatedAt;

  const StockBatchBalance({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.stockPointId,
    required this.stockPointName,
    required this.location,
    required this.batchId,
    required this.availableQty,
    required this.looseQty,
    required this.updatedAt,
  });

  factory StockBatchBalance.fromJson(Map<String, dynamic> json) {
    return StockBatchBalance(
      id: _string(json, 'id'),
      itemId: _string(json, 'item_id'),
      itemName: _string(json, 'item_name'),
      itemCode: _string(json, 'item_code'),
      stockPointId: _string(json, 'stock_point_id'),
      stockPointName: _string(json, 'stock_point_name'),
      location: _string(json, 'location'),
      batchId: _string(json, 'batch_id', fallback: _string(json, 'batch_code')),
      availableQty: _double(json, 'available_qty'),
      looseQty: _double(json, 'loose_qty'),
      updatedAt: DateTime.tryParse(_string(json, 'updated_at')),
    );
  }

  String get batchCode => batchId;
}

/// An order placed by HOD that the supervisor receives and reviews.
class StockOrderItemDraft {
  /// Null for a manually typed item — the server creates it on placement.
  final String? itemId;
  final String itemName;
  final String unit;
  final String? itemCode;
  final String? batch;
  final double quantity;
  final String? notes;

  const StockOrderItemDraft({
    this.itemId,
    required this.itemName,
    required this.unit,
    this.itemCode,
    this.batch,
    required this.quantity,
    this.notes,
  });
}

/// One order placed by HOD = a group of stock_orders rows sharing the same
/// order_no (multi-item orders). Status is derived from the group lines.
class StockOrderGroup {
  final String orderNo;
  final String? siteId;
  final String stockPointId;
  final String stockPointName;
  final String? thavvuPointId;
  final String? placedBy;
  final DateTime? createdAt;
  final List<StockOrder> items;

  const StockOrderGroup({
    required this.orderNo,
    this.siteId,
    required this.stockPointId,
    required this.stockPointName,
    this.thavvuPointId,
    this.placedBy,
    this.createdAt,
    required this.items,
  });

  int get itemCount => items.length;
  double get totalQuantity =>
      items.fold(0, (sum, o) => sum + o.quantity);

  /// placed | received | added_to_stock | cancelled — derived from lines.
  String get status {
    if (items.isEmpty) return 'placed';
    if (items.every((o) => o.status == 'cancelled')) return 'cancelled';
    if (items.every((o) =>
        o.status == 'added_to_stock' || o.status == 'cancelled')) {
      return items.every((o) => o.status == 'added_to_stock')
          ? 'added_to_stock'
          : 'placed';
    }
    if (items.any((o) => o.status == 'placed')) return 'placed';
    return 'received';
  }

  bool get canReceive => status == 'placed';

  static List<StockOrderGroup> groupOrders(List<StockOrder> orders) {
    final byNo = <String, List<StockOrder>>{};
    for (final order in orders) {
      byNo.putIfAbsent(order.orderNo, () => []).add(order);
    }
    final groups = byNo.entries.map((e) {
      final first = e.value.first;
      return StockOrderGroup(
        orderNo: e.key,
        siteId: first.siteId,
        stockPointId: first.stockPointId,
        stockPointName: first.stockPointName,
        thavvuPointId: first.thavvuPointId,
        placedBy: first.placedBy,
        createdAt: first.createdAt,
        items: e.value,
      );
    }).toList();
    groups.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return groups;
  }
}

class StockOrder {
  final String id;
  final String orderNo;
  final String? siteId;
  final String stockPointId;
  final String stockPointName;
  final String? thavvuPointId;
  final String itemId;
  final String itemName;
  final String batch;
  final double quantity;
  final String unit;
  final String status; // placed | received | added_to_stock | cancelled
  final String? notes;
  final String? placedBy;
  final DateTime? createdAt;

  const StockOrder({
    required this.id,
    required this.orderNo,
    this.siteId,
    required this.stockPointId,
    required this.stockPointName,
    this.thavvuPointId,
    required this.itemId,
    required this.itemName,
    required this.batch,
    required this.quantity,
    required this.unit,
    required this.status,
    this.notes,
    this.placedBy,
    this.createdAt,
  });

  factory StockOrder.fromJson(Map<String, dynamic> json) {
    return StockOrder(
      id: _string(json, 'id'),
      orderNo: _string(json, 'order_no'),
      siteId: json['site_id']?.toString(),
      stockPointId: _string(json, 'stock_point_id'),
      stockPointName: _string(json, 'stock_point_name'),
      thavvuPointId: json['thavvu_point_id']?.toString(),
      itemId: _string(json, 'item_id'),
      itemName: _string(json, 'item_name'),
      batch: _string(json, 'batch'),
      quantity: _double(json, 'quantity'),
      unit: _string(json, 'unit', fallback: 'units'),
      status: _string(json, 'status', fallback: 'placed'),
      notes: json['notes']?.toString(),
      placedBy: json['placed_by']?.toString(),
      createdAt: DateTime.tryParse(_string(json, 'created_at')),
    );
  }
}

/// Goods inward bill created when a received order is reviewed.
class StockGinBill {
  final String id;
  final String ginNo;
  final String? siteId;
  final String? orderId;
  final String stockPointId;
  final String stockPointName;
  final String itemId;
  final String itemName;
  final String batch;
  final double quantity;
  final String unit;
  final String status; // pending_review | added_to_stock
  final String? photoName;
  final String? receivedBy;
  final String? reviewedBy;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String hodStatus; // pending | approved | rejected
  final String? hodNote;
  final String? hodReviewedBy;
  final DateTime? hodReviewedAt;

  const StockGinBill({
    required this.id,
    required this.ginNo,
    this.siteId,
    this.orderId,
    required this.stockPointId,
    required this.stockPointName,
    required this.itemId,
    required this.itemName,
    required this.batch,
    required this.quantity,
    required this.unit,
    required this.status,
    this.photoName,
    this.receivedBy,
    this.reviewedBy,
    this.createdAt,
    this.reviewedAt,
    this.hodStatus = 'pending',
    this.hodNote,
    this.hodReviewedBy,
    this.hodReviewedAt,
  });

  factory StockGinBill.fromJson(Map<String, dynamic> json) {
    return StockGinBill(
      id: _string(json, 'id'),
      ginNo: _string(json, 'gin_no'),
      siteId: json['site_id']?.toString(),
      orderId: json['order_id']?.toString(),
      stockPointId: _string(json, 'stock_point_id'),
      stockPointName: _string(json, 'stock_point_name'),
      itemId: _string(json, 'item_id'),
      itemName: _string(json, 'item_name'),
      batch: _string(json, 'batch'),
      quantity: _double(json, 'quantity'),
      unit: _string(json, 'unit', fallback: 'units'),
      status: _string(json, 'status', fallback: 'pending_review'),
      photoName: json['photo_name']?.toString(),
      receivedBy: json['received_by']?.toString(),
      reviewedBy: json['reviewed_by']?.toString(),
      createdAt: DateTime.tryParse(_string(json, 'created_at')),
      reviewedAt: DateTime.tryParse(_string(json, 'reviewed_at')),
      hodStatus: _string(json, 'hod_status', fallback: 'pending'),
      hodNote: json['hod_note']?.toString(),
      hodReviewedBy: json['hod_reviewed_by']?.toString(),
      hodReviewedAt: DateTime.tryParse(_string(json, 'hod_reviewed_at')),
    );
  }
}

/// Audit row from stock_movements.
class StockMovementRecord {
  final String id;
  final String referenceId;
  final String movementType;
  final String itemId;
  final String batchId;
  final String stockPointId;
  final double quantity;
  final double looseQuantity;
  final String reason;
  final DateTime? createdAt;

  const StockMovementRecord({
    required this.id,
    required this.referenceId,
    required this.movementType,
    required this.itemId,
    required this.batchId,
    required this.stockPointId,
    required this.quantity,
    required this.looseQuantity,
    required this.reason,
    required this.createdAt,
  });

  factory StockMovementRecord.fromJson(Map<String, dynamic> json) {
    return StockMovementRecord(
      id: _string(json, 'id'),
      referenceId: _string(json, 'reference_id'),
      movementType: _string(json, 'movement_type'),
      itemId: _string(json, 'item_id'),
      batchId: _string(json, 'batch_id'),
      stockPointId: _string(json, 'from_stock_point_id'),
      quantity: double.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      looseQuantity:
          double.tryParse(json['loose_quantity']?.toString() ?? '') ?? 0,
      reason: _string(json, 'reason'),
      createdAt: DateTime.tryParse(_string(json, 'created_at')),
    );
  }
}

/// Consumption entry with batch quantity + photo proof.
class StockConsumption {
  final String id;
  final String? siteId;
  final String stockPointName;
  final String itemName;
  final String batchCode;
  final double quantity;
  final double looseQuantity;
  final String reason;
  final String? photoName;
  final String? consumedBy;
  final DateTime? createdAt;

  const StockConsumption({
    required this.id,
    this.siteId,
    required this.stockPointName,
    required this.itemName,
    required this.batchCode,
    required this.quantity,
    required this.looseQuantity,
    required this.reason,
    this.photoName,
    this.consumedBy,
    this.createdAt,
  });

  factory StockConsumption.fromJson(Map<String, dynamic> json) {
    return StockConsumption(
      id: _string(json, 'id'),
      siteId: json['site_id']?.toString(),
      stockPointName: _string(json, 'stock_point_name'),
      itemName: _string(json, 'item_name'),
      batchCode: _string(json, 'batch_code', fallback: _string(json, 'batch_id')),
      quantity: _double(json, 'quantity'),
      looseQuantity: _double(json, 'loose_quantity'),
      reason: _string(json, 'reason'),
      photoName: json['photo_name']?.toString(),
      consumedBy: json['consumed_by']?.toString(),
      createdAt: DateTime.tryParse(_string(json, 'created_at')),
    );
  }
}

/// Internal transfer record with deliver/receive flow.
class StockTransfer {
  final String id;
  final String transferNo;
  final String? siteId;
  final String fromPointId;
  final String fromPoint;
  final String toPointId;
  final String toPoint;
  final String? fromThavvuPointId;
  final String? fromThavvuPoint;
  final String? toThavvuPointId;
  final String? toThavvuPoint;
  final String itemId;
  final String itemName;
  final String batch;
  final double quantity;
  final double looseQuantity;
  final String unit;
  final String status; // initiated | delivered | received | cancelled
  final String? notes;
  final String? photoName;
  final String? initiatedBy;
  final String? deliveredBy;
  final String? receivedBy;
  final String? receivedByName;
  final double? receivedQuantity;
  final String? receivedCondition;
  final List<String> receiveChecklist;
  final String? receiveNotes;
  final DateTime? initiatedAt;
  final DateTime? deliveredAt;
  final DateTime? receivedAt;

  const StockTransfer({
    required this.id,
    required this.transferNo,
    this.siteId,
    required this.fromPointId,
    required this.fromPoint,
    required this.toPointId,
    required this.toPoint,
    this.fromThavvuPointId,
    this.fromThavvuPoint,
    this.toThavvuPointId,
    this.toThavvuPoint,
    required this.itemId,
    required this.itemName,
    required this.batch,
    required this.quantity,
    required this.looseQuantity,
    required this.unit,
    required this.status,
    this.notes,
    this.photoName,
    this.initiatedBy,
    this.deliveredBy,
    this.receivedBy,
    this.receivedByName,
    this.receivedQuantity,
    this.receivedCondition,
    this.receiveChecklist = const [],
    this.receiveNotes,
    this.initiatedAt,
    this.deliveredAt,
    this.receivedAt,
  });

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    return StockTransfer(
      id: _string(json, 'id'),
      transferNo: _string(json, 'transfer_no'),
      siteId: json['site_id']?.toString(),
      fromPointId: _string(json, 'from_point_id'),
      fromPoint: _string(json, 'from_point'),
      toPointId: _string(json, 'to_point_id'),
      toPoint: _string(json, 'to_point'),
      fromThavvuPointId: json['from_thavvu_point_id']?.toString(),
      fromThavvuPoint: json['from_thavvu_point']?.toString(),
      toThavvuPointId: json['to_thavvu_point_id']?.toString(),
      toThavvuPoint: json['to_thavvu_point']?.toString(),
      itemId: _string(json, 'item_id'),
      itemName: _string(json, 'item_name'),
      batch: _string(json, 'batch'),
      quantity: _double(json, 'quantity'),
      looseQuantity: _double(json, 'loose_quantity'),
      unit: _string(json, 'unit', fallback: 'units'),
      status: _string(json, 'status', fallback: 'initiated'),
      notes: json['notes']?.toString(),
      photoName: json['photo_name']?.toString(),
      initiatedBy: json['initiated_by']?.toString(),
      deliveredBy: json['delivered_by']?.toString(),
      receivedBy: json['received_by']?.toString(),
      receivedByName: json['received_by_name']?.toString(),
      receivedQuantity: _doubleOrNull(json, 'received_quantity'),
      receivedCondition: json['received_condition']?.toString(),
      receiveChecklist: _stringList(json, 'receive_checklist'),
      receiveNotes: json['receive_notes']?.toString(),
      initiatedAt: DateTime.tryParse(_string(json, 'initiated_at')),
      deliveredAt: DateTime.tryParse(_string(json, 'delivered_at')),
      receivedAt: DateTime.tryParse(_string(json, 'received_at')),
    );
  }
}

String _string(Map<String, dynamic> json, String key, {String fallback = ''}) {
  final value = json[key];
  if (value == null) return fallback;
  return value.toString();
}

double _double(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) {
    return value.map((e) => e.toString()).toList(growable: false);
  }
  return const [];
}
