import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'attendance_context_service.dart';

// ─── GIN domain models (multi-item Goods Inward Notes at Thavvu Points) ──────

enum GinLineAction { reorder, extra, done }

enum GinReconciliationStatus { matched, shortage, excess }

GinLineAction? _parseAction(Object? value) {
  switch (value?.toString()) {
    case 'reorder':
      return GinLineAction.reorder;
    case 'extra':
      return GinLineAction.extra;
    case 'done':
      return GinLineAction.done;
    default:
      return null;
  }
}

String? _actionName(GinLineAction? action) {
  switch (action) {
    case GinLineAction.reorder:
      return 'reorder';
    case GinLineAction.extra:
      return 'extra';
    case GinLineAction.done:
      return 'done';
    default:
      return null;
  }
}

class GinThavvuPoint {
  final String id;
  final String name;
  final String? siteId;

  const GinThavvuPoint({
    required this.id,
    required this.name,
    this.siteId,
  });

  factory GinThavvuPoint.fromJson(Map<String, dynamic> json) {
    return GinThavvuPoint(
      id: json['id']?.toString() ?? '',
      name: json['point_name']?.toString() ?? '',
      siteId: json['site_id']?.toString(),
    );
  }
}

class GinBillLine {
  final String id;
  final String itemName;
  final double orderedQty;
  final double billedQty;

  /// Editable by the supervisor on the reconciliation table.
  double receivedQty;
  final String uom;
  final GinLineAction? action;
  final String? actionNote;
  final GinLineAction? hodAction;
  final String? hodActionNote;

  GinBillLine({
    required this.id,
    required this.itemName,
    required this.orderedQty,
    required this.billedQty,
    required this.receivedQty,
    this.uom = 'units',
    this.action,
    this.actionNote,
    this.hodAction,
    this.hodActionNote,
  });

  double get diffBilledReceived => billedQty - receivedQty;
  double get diffOrderedReceived => orderedQty - receivedQty;

  GinReconciliationStatus get status {
    if (diffBilledReceived == 0 && diffOrderedReceived == 0) {
      return GinReconciliationStatus.matched;
    }
    return receivedQty < billedQty
        ? GinReconciliationStatus.shortage
        : GinReconciliationStatus.excess;
  }

  /// Default action offered in the ACTIONS column.
  GinLineAction get suggestedAction {
    switch (status) {
      case GinReconciliationStatus.shortage:
        return GinLineAction.reorder;
      case GinReconciliationStatus.excess:
        return GinLineAction.extra;
      case GinReconciliationStatus.matched:
        return GinLineAction.done;
    }
  }

  factory GinBillLine.fromJson(Map<String, dynamic> json) {
    return GinBillLine(
      id: json['id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      orderedQty: _toDouble(json['ordered_qty']),
      billedQty: _toDouble(json['billed_qty']),
      receivedQty: _toDouble(json['received_qty']),
      uom: json['uom']?.toString() ?? 'units',
      action: _parseAction(json['action']),
      actionNote: json['action_note']?.toString(),
      hodAction: _parseAction(json['hod_action']),
      hodActionNote: json['hod_action_note']?.toString(),
    );
  }
}

class GinBillDocument {
  final String id;
  final String name;
  final String type; // invoice | delivery_note | photo
  final String? storagePath;
  final DateTime? uploadedAt;

  const GinBillDocument({
    required this.id,
    required this.name,
    required this.type,
    this.storagePath,
    this.uploadedAt,
  });

  factory GinBillDocument.fromJson(Map<String, dynamic> json) {
    return GinBillDocument(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'photo',
      storagePath: json['storage_path']?.toString(),
      uploadedAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class GinBill {
  final String id;
  final String ginNo;
  final String billNumber;
  final String? supplierId;
  final String supplierName;
  final String thavvuPointId;
  final String thavvuPointName;
  final String? siteId;
  final DateTime? billDate;
  final String status; // pending | submitted | approved | rejected | added_to_stock
  final String hodStatus; // pending | approved | rejected
  final String? hodNote;
  final String? submittedBy;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final List<GinBillLine> lines;
  final List<GinBillDocument> documents;

  GinBill({
    required this.id,
    required this.ginNo,
    required this.billNumber,
    this.supplierId,
    required this.supplierName,
    required this.thavvuPointId,
    required this.thavvuPointName,
    this.siteId,
    this.billDate,
    this.status = 'pending',
    this.hodStatus = 'pending',
    this.hodNote,
    this.submittedBy,
    this.submittedAt,
    this.createdAt,
    required this.lines,
    this.documents = const [],
  });

  bool get isDraft => id.isEmpty;
  bool get isPending => status == 'pending' || status == 'submitted';
  bool get isRejected => status == 'rejected';
  bool get isApproved => status == 'approved' || status == 'added_to_stock';
  bool get addedToStock => status == 'added_to_stock';

  int get shortageCount =>
      lines.where((l) => l.status == GinReconciliationStatus.shortage).length;
  int get excessCount =>
      lines.where((l) => l.status == GinReconciliationStatus.excess).length;
  int get matchedCount =>
      lines.where((l) => l.status == GinReconciliationStatus.matched).length;
  bool get allMatched => shortageCount == 0 && excessCount == 0;

  double get totalOrdered => lines.fold(0, (s, l) => s + l.orderedQty);
  double get totalBilled => lines.fold(0, (s, l) => s + l.billedQty);
  double get totalReceived => lines.fold(0, (s, l) => s + l.receivedQty);

  factory GinBill.fromJson(Map<String, dynamic> json) {
    final rawLines = json['gin_bill_items'];
    final rawDocs = json['gin_bill_documents'];
    final lines = rawLines is List
        ? rawLines
            .map((row) => GinBillLine.fromJson(_asMap(row)))
            .toList(growable: false)
        : <GinBillLine>[];
    final docs = rawDocs is List
        ? rawDocs
            .map((row) => GinBillDocument.fromJson(_asMap(row)))
            .toList(growable: false)
        : <GinBillDocument>[];
    return GinBill(
      id: json['id']?.toString() ?? '',
      ginNo: json['gin_no']?.toString() ?? '',
      billNumber: json['bill_number']?.toString() ?? '',
      supplierId: json['supplier_id']?.toString(),
      supplierName: json['supplier_name']?.toString() ?? '',
      thavvuPointId: json['thavvu_point_id']?.toString() ?? '',
      thavvuPointName: json['thavvu_point_name']?.toString() ?? '',
      siteId: json['site_id']?.toString(),
      billDate: DateTime.tryParse(json['bill_date']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'pending',
      hodStatus: json['hod_status']?.toString() ?? 'pending',
      hodNote: json['hod_note']?.toString(),
      submittedBy: json['submitted_by']?.toString(),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      lines: lines,
      documents: docs,
    );
  }

  /// A draft copy used by the GIN composer before it reaches the server.
  factory GinBill.draft({
    required String ginNo,
    required String billNumber,
    required String supplierName,
    String? supplierId,
    required String thavvuPointId,
    required String thavvuPointName,
    String? siteId,
    DateTime? billDate,
    required List<GinBillLine> lines,
  }) {
    return GinBill(
      id: '',
      ginNo: ginNo,
      billNumber: billNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      thavvuPointId: thavvuPointId,
      thavvuPointName: thavvuPointName,
      siteId: siteId,
      billDate: billDate,
      status: 'pending',
      hodStatus: 'pending',
      lines: lines,
    );
  }
}

/// Local attachment kept in memory until the GIN is submitted.
class GinDocumentDraft {
  final String name;
  final String type;
  final Uint8List bytes;
  final String extension;

  const GinDocumentDraft({
    required this.name,
    required this.type,
    required this.bytes,
    this.extension = 'jpg',
  });
}

// ─── Repository ──────────────────────────────────────────────────────────────

Map<String, dynamic> _asMap(Object? value) {
  return Map<String, dynamic>.from(value as Map);
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

/// Backend for the multi-item GIN flow.
///
/// Reads the new `gin_bills` / `gin_bill_items` / `gin_bill_documents`
/// tables (migration 00035) and drives all writes through the SECURITY
/// DEFINER RPCs (`gin_submit_bill`, `gin_update_bill`, `gin_hod_review`,
/// `gin_add_to_stock`) so every mutation is atomic and server-validated.
class GinRepository {
  GinRepository({SupabaseClient? client}) : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until the
  /// first query.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const _pointsTable = 'thavvu_points';
  static const _billsTable = 'gin_bills';
  static const _itemsTable = 'gin_bill_items';
  static const _documentsTable = 'gin_bill_documents';
  static const _bucket = 'gin-documents';

  // ── Thavvu Points ─────────────────────────────────────────────────────────

  /// Points for the supervisor's site, with the actively selected point
  /// (ThavvuPointContext) ranked first.
  Future<List<GinThavvuPoint>> fetchThavvuPoints() async {
    final context = AttendanceContextService();
    String? siteId;
    String? selectedPointId;
    try {
      siteId = await context.resolveSiteId();
    } catch (_) {}
    try {
      selectedPointId = await context.resolvePointId();
    } catch (_) {}

    var query = _client.from(_pointsTable).select('id, point_name, site_id');
    if (siteId != null && siteId.isNotEmpty) {
      query = query.eq('site_id', siteId);
    }
    final response = await query.order('created_at', ascending: true);
    final points = (response as List)
        .map((row) => GinThavvuPoint.fromJson(_asMap(row)))
        .toList(growable: false);

    if (selectedPointId != null && points.isNotEmpty) {
      final sorted = [...points];
      sorted.sort((a, b) {
        if (a.id == selectedPointId) return -1;
        if (b.id == selectedPointId) return 1;
        return 0;
      });
      return sorted;
    }
    return points;
  }

  // ── Bills ─────────────────────────────────────────────────────────────────

  /// Bills with their lines and documents embedded (FK relations).
  Future<List<GinBill>> fetchBills({
    String? pointId,
    bool onlyPending = false,
    int limit = 200,
  }) async {
    var query = _client
        .from(_billsTable)
        .select('*, $_itemsTable(*), $_documentsTable(*)');
    if (pointId != null && pointId.isNotEmpty) {
      query = query.eq('thavvu_point_id', pointId);
    }
    if (onlyPending) {
      query = query.inFilter('status', const ['pending', 'submitted']);
    }
    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((row) => GinBill.fromJson(_asMap(row)))
        .toList(growable: false);
  }

  Future<GinBill?> fetchBill(String billId) async {
    final response = await _client
        .from(_billsTable)
        .select('*, $_itemsTable(*), $_documentsTable(*)')
        .eq('id', billId)
        .limit(1);
    final list = response as List;
    if (list.isEmpty) return null;
    return GinBill.fromJson(_asMap(list.first));
  }

  /// The GIN bill created from a stock order (bill_number == order_no).
  /// Lets HOD / supervisor open the exact reconciliation table for an order.
  Future<GinBill?> fetchBillByOrderNo(String orderNo) async {
    final response = await _client
        .from(_billsTable)
        .select('*, $_itemsTable(*), $_documentsTable(*)')
        .eq('bill_number', orderNo)
        .limit(1);
    final list = response as List;
    if (list.isEmpty) return null;
    return GinBill.fromJson(_asMap(list.first));
  }

  // ── RPC writes ────────────────────────────────────────────────────────────

  /// Composes and submits a new GIN bill atomically. Documents are uploaded
  /// to storage first; the RPC then records their paths. Returns the server
  /// bill or null on failure.
  Future<GinBill?> submitBill({
    required String billNumber,
    required String supplierName,
    String? supplierId,
    required String thavvuPointId,
    required String thavvuPointName,
    String? siteId,
    DateTime? billDate,
    required List<GinBillLine> lines,
    List<GinDocumentDraft> documents = const [],
    String? ginNo,
  }) async {
    try {
      final resolvedGinNo =
          ginNo ?? await generateGinNo();
      final uploadedDocs = <Map<String, String>>[];
      for (final doc in documents) {
        final path = await uploadDocument(
          doc.bytes,
          fileName: doc.name,
          type: doc.type,
          ginNo: resolvedGinNo,
        );
        if (path == null) {
          debugPrint('GIN document upload failed for ${doc.name}');
          return null;
        }
        uploadedDocs.add({
          'name': doc.name,
          'type': doc.type,
          'storage_path': path,
        });
      }
      final result = await _client.rpc('gin_submit_bill', params: {
        'p_bill_number': billNumber,
        'p_supplier_name': supplierName,
        'p_supplier_id': supplierId,
        'p_thavvu_point_id': thavvuPointId,
        'p_thavvu_point_name': thavvuPointName,
        'p_site_id': siteId,
        'p_bill_date': billDate?.toIso8601String().substring(0, 10),
        'p_gin_no': resolvedGinNo,
        'p_items': [
          for (final line in lines)
            {
              'item_name': line.itemName,
              'ordered_qty': line.orderedQty,
              'billed_qty': line.billedQty,
              'received_qty': line.receivedQty,
              'uom': line.uom,
              'action': _actionName(line.action),
              'action_note': line.actionNote,
            },
        ],
        'p_documents': uploadedDocs,
      });
      final id = _asMap(result)['id']?.toString();
      if (id == null || id.isEmpty) return null;
      return fetchBill(id);
    } catch (e) {
      debugPrint('gin_submit_bill failed: $e');
      return null;
    }
  }

  /// Updates a pending / rejected bill (HOD rejection loop) and re-submits.
  Future<GinBill?> updateBill({
    required String billId,
    required String billNumber,
    required String supplierName,
    String? supplierId,
    required String thavvuPointId,
    required String thavvuPointName,
    String? siteId,
    DateTime? billDate,
    required List<GinBillLine> lines,
    List<GinDocumentDraft> documents = const [],
  }) async {
    try {
      final bill = await fetchBill(billId);
      final uploadedDocs = <Map<String, String>>[];
      for (final doc in documents) {
        final path = await uploadDocument(
          doc.bytes,
          fileName: doc.name,
          type: doc.type,
          ginNo: bill?.ginNo ?? await generateGinNo(),
        );
        if (path == null) {
          debugPrint('GIN document upload failed for ${doc.name}');
          return null;
        }
        uploadedDocs.add({
          'name': doc.name,
          'type': doc.type,
          'storage_path': path,
        });
      }
      final result = await _client.rpc('gin_update_bill', params: {
        'p_bill_id': billId,
        'p_bill_number': billNumber,
        'p_supplier_name': supplierName,
        'p_supplier_id': supplierId,
        'p_thavvu_point_id': thavvuPointId,
        'p_thavvu_point_name': thavvuPointName,
        'p_site_id': siteId,
        'p_bill_date': billDate?.toIso8601String().substring(0, 10),
        'p_items': [
          for (final line in lines)
            {
              'item_name': line.itemName,
              'ordered_qty': line.orderedQty,
              'billed_qty': line.billedQty,
              'received_qty': line.receivedQty,
              'uom': line.uom,
              'action': _actionName(line.action),
              'action_note': line.actionNote,
            },
        ],
        'p_documents': uploadedDocs,
      });
      final ok = _asMap(result)['ok'] == true;
      if (!ok) return null;
      return fetchBill(billId);
    } catch (e) {
      debugPrint('gin_update_bill failed: $e');
      return null;
    }
  }

  /// HOD decision on a bill. Approving automatically adds the received
  /// quantities to the Thavvu Point stock (batch = GIN no).
  Future<Map<String, dynamic>?> reviewAsHod({
    required String billId,
    required String decision, // approved | rejected
    String? note,
    List<Map<String, String>> itemActions = const [],
  }) async {
    try {
      final result = await _client.rpc('gin_hod_review', params: {
        'p_bill_id': billId,
        'p_decision': decision,
        'p_note': note,
        'p_item_actions': itemActions,
      });
      return _asMap(result);
    } catch (e) {
      debugPrint('gin_hod_review failed: $e');
      return null;
    }
  }

  /// Adds an approved GIN to stock (idempotent; normally runs inside the
  /// HOD approval RPC, exposed here for retries / supervisor re-run).
  Future<Map<String, dynamic>?> addToStock(String billId) async {
    try {
      final result =
          await _client.rpc('gin_add_to_stock', params: {'p_bill_id': billId});
      return _asMap(result);
    } catch (e) {
      debugPrint('gin_add_to_stock failed: $e');
      return null;
    }
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  /// Uploads one GIN document to the `gin-documents` bucket and returns the
  /// storage path (or null on failure).
  Future<String?> uploadDocument(
    Uint8List bytes, {
    required String fileName,
    required String type, // invoice | delivery_note | photo
    required String ginNo,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final safeName = fileName
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path =
          '${user.id}/gin/$ginNo/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _client.storage.from(_bucket).uploadBinary(path, bytes);
      return path;
    } catch (e) {
      debugPrint('GIN document upload failed: $e');
      return null;
    }
  }

  String publicDocumentUrl(String? storagePath) {
    if (storagePath == null || storagePath.isEmpty) return '';
    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  // ── GIN number ────────────────────────────────────────────────────────────

  Future<String> generateGinNo() async {
    final now = DateTime.now();
    final date = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final rand = Random().nextInt(0xFFFF).toRadixString(16).toUpperCase();
    return 'GIN-$date-$rand';
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  RealtimeChannel watchGinBills(void Function() onChanged) {
    return _client
        .channel('public:$_billsTable')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _billsTable,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> stopWatching(RealtimeChannel? channel) async {
    if (channel == null) return;
    await _client.removeChannel(channel);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

}
