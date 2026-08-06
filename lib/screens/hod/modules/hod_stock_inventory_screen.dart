import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/attendance_context_service.dart';
import '../../../services/gin_repository.dart';
import '../../../services/stock_inventory_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';
import '../../gin/gin_bill_details_screen.dart';

/// HOD Stock module — production dashboard.
///
/// Covers the same major areas as the supervisor Stock module with
/// HOD-specialized powers:
///   1. Stock Available — every item grouped by category, showing type,
///      batch breakdown, on-hand stock and LOW STOCK flags. Tapping an
///      item opens a full detail sheet (batches + movement audit trail).
///   2. Actions — supervisor GIN submissions awaiting HOD review. HOD can
///      approve / reject / comment so the receive → review → stock flow
///      closes on the supervisor side.
///   3. Place Order — order stock that the supervisor receives.
///   4. Orders — live order status (placed → received → added to stock).
class HodStockInventoryScreen extends StatefulWidget {
  const HodStockInventoryScreen({super.key});

  @override
  State<HodStockInventoryScreen> createState() =>
      _HodStockInventoryScreenState();
}

class _HodStockInventoryScreenState extends State<HodStockInventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = StockInventoryRepository();
  final AttendanceContextService _contextService = AttendanceContextService();

  List<StockInventoryItem> _items = <StockInventoryItem>[];
  List<StockBatchBalance> _balances = <StockBatchBalance>[];
  List<StockOrder> _orders = <StockOrder>[];
  List<StockGinBill> _ginBills = <StockGinBill>[];
  List<StockConsumption> _consumptions = <StockConsumption>[];
  List<StockTransfer> _transfers = <StockTransfer>[];

  bool _loading = true;
  bool _busy = false;
  String _siteId = 'SITE-VJA-001';

  final List<RealtimeChannel> _channels = <RealtimeChannel>[];

  // Place order form state.
  String _pointId = 'SP-001';
  String _pointName = 'Site A — North';
  final _notesCtrl = TextEditingController();
  final List<_HodOrderItemDraft> _orderDrafts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _addOrderDraft();
    _initServer();
  }

  @override
  void dispose() {
    for (final channel in _channels) {
      _repo.stopWatching(channel);
    }
    _tabController.dispose();
    _notesCtrl.dispose();
    for (final draft in _orderDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _initServer() async {
    try {
      final siteId = await _contextService.resolveSiteId();
      if (!mounted) return;
      _siteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
    } catch (_) {
      // Best-effort context; default site id keeps the screen usable.
    }
    _channels.add(_repo.watchBatchBalances(_load));
    _channels.add(_repo.watchOrders(_load));
    _channels.add(_repo.watchGinBills(_load));
    _channels.add(_repo.watchConsumptions(_load));
    _channels.add(_repo.watchTransfers(_load));
    await _load();
  }

  List<Map<String, String>> _thavvuPointsList = <Map<String, String>>[];

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.fetchItems(),
        _repo.fetchBatchBalances(),
        _repo.fetchOrders(),
        _repo.fetchGinBills(),
        _repo.fetchConsumptions(),
        _repo.fetchTransfers(),
        _repo.fetchThavvuPoints(siteId: _siteId),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<StockInventoryItem>;
        _balances = results[1] as List<StockBatchBalance>;
        _orders = results[2] as List<StockOrder>;
        _ginBills = results[3] as List<StockGinBill>;
        _consumptions = results[4] as List<StockConsumption>;
        _transfers = results[5] as List<StockTransfer>;
        _thavvuPointsList = results[6] as List<Map<String, String>>;
        final pointsMap = _points;
        if (pointsMap.isNotEmpty) {
          _pointId = pointsMap.keys.first;
          _pointName = pointsMap.values.first;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Could not load stock data', AppTheme.danger);
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await _load();
    if (!mounted) return;
    _snack('Stock dashboard refreshed.', AppTheme.info);
  }

  // ══════════════════════════════════════════════════════════════
  // DERIVED DATA
  // ══════════════════════════════════════════════════════════════

  double _totalForItem(String itemId) => _balances
      .where((b) => b.itemId == itemId)
      .fold(0, (sum, b) => sum + b.availableQty);

  List<StockBatchBalance> _batchesForItem(String itemId) =>
      _balances.where((b) => b.itemId == itemId).toList();

  bool _isLow(StockInventoryItem item) =>
      item.tracksLowStock && _totalForItem(item.id) <= item.reorderLevel;

  List<String> get _categories {
    final set = <String>{};
    for (final item in _items) {
      final category = item.category.isNotEmpty ? item.category : item.group;
      if (category.isNotEmpty) set.add(category);
    }
    if (set.isEmpty) set.add('General');
    final list = set.toList()..sort();
    return list;
  }

  List<StockInventoryItem> _itemsIn(String category) {
    return _items
        .where((item) {
          final c = item.category.isNotEmpty ? item.category : item.group;
          return c == category;
        })
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<StockGinBill> get _pendingGin => _ginBills
      .where((b) => b.status == 'pending_review' && b.hodStatus == 'pending')
      .toList();

  List<StockGinBill> get _reviewedGin => _ginBills
      .where((b) => b.hodStatus == 'approved' || b.hodStatus == 'rejected')
      .toList();

  Map<String, String> get _points {
    final map = <String, String>{};
    for (final pt in _thavvuPointsList) {
      final id = pt['id'] ?? '';
      final name = pt['name'] ?? id;
      if (id.isNotEmpty) {
        map[id] = name;
      }
    }
    for (final b in _balances) {
      if (b.stockPointId.isNotEmpty && b.stockPointName.isNotEmpty) {
        map.putIfAbsent(b.stockPointId, () => b.stockPointName);
      }
    }
    if (map.isEmpty) {
      map['TP-VJA-001'] = 'Thavvu Point 1 — Vijayawada Yard';
      map['TP-VJA-002'] = 'Thavvu Point 2 — Delta Pond';
      map['TP-HYD-001'] = 'Thavvu Point 1 — Hyderabad Site';
    }
    return map;
  }

  // ══════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════

  Future<void> _placeOrder() async {
    // Every line must have an item (picked or typed) and a quantity > 0.
    final validItems = <_HodOrderItemDraft>[];
    for (final draft in _orderDrafts) {
      if (draft.manual) {
        if (draft.nameCtrl.text.trim().isEmpty) {
          _snack('Every order line needs an item name', AppTheme.warning);
          return;
        }
      } else {
        final item = _itemFor(draft.itemId);
        if (item == null) {
          _snack('Every order line needs an item selected', AppTheme.warning);
          return;
        }
      }
      final qty = double.tryParse(draft.qtyCtrl.text.trim()) ?? 0;
      if (qty <= 0) {
        _snack('Enter a valid quantity for every line', AppTheme.warning);
        return;
      }
      validItems.add(draft);
    }
    if (validItems.isEmpty) {
      _snack('Add at least one item to the order', AppTheme.warning);
      return;
    }

    final orderNo = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _saving = true);
    final ok = await _repo.placeMultiOrder(
      orderNo: orderNo,
      siteId: _siteId,
      stockPointId: _pointId,
      stockPointName: _pointName,
      thavvuPointId: await _contextService.resolvePointId(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      items: [
        for (final draft in validItems)
          if (draft.manual)
            StockOrderItemDraft(
              itemName: draft.nameCtrl.text.trim(),
              itemCode: draft.nameCtrl.text.trim(),
              unit: draft.uomCtrl.text.trim().isEmpty
                  ? 'units'
                  : draft.uomCtrl.text.trim(),
              batch: draft.batchCtrl.text.trim().isEmpty
                  ? null
                  : draft.batchCtrl.text.trim(),
              quantity: double.tryParse(draft.qtyCtrl.text.trim()) ?? 0,
            )
          else
            StockOrderItemDraft(
              itemId: draft.itemId,
              itemName: _itemFor(draft.itemId)!.name,
              itemCode: _itemFor(draft.itemId)!.code,
              unit: _itemFor(draft.itemId)!.uom,
              batch: draft.batchCtrl.text.trim().isEmpty
                  ? null
                  : draft.batchCtrl.text.trim(),
              quantity: double.tryParse(draft.qtyCtrl.text.trim()) ?? 0,
            ),
      ],
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _snack('Order $orderNo placed with ${validItems.length} item(s) — '
          'supervisor receives it in Stock → View Orders → GIN', AppTheme.success);
      _notesCtrl.clear();
      for (final draft in _orderDrafts) {
        draft.dispose();
      }
      _orderDrafts.clear();
      _addOrderDraft();
      _tabController.animateTo(3);
    } else {
      _snack('Failed to place order', AppTheme.danger);
    }
  }

  StockInventoryItem? _itemFor(String? itemId) {
    if (itemId == null) return null;
    for (final item in _items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  void _addOrderDraft() {
    setState(() => _orderDrafts.add(_HodOrderItemDraft()));
  }

  void _removeOrderDraft(int index) {
    if (_orderDrafts.length <= 1) {
      _snack('Keep at least one order line', AppTheme.warning);
      return;
    }
    setState(() => _orderDrafts.removeAt(index).dispose());
  }

  Future<void> _reviewGin(StockGinBill bill, {required String status}) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(
          status == 'approved' ? 'Approve GIN' : 'Reject GIN',
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${bill.ginNo} • ${bill.itemName} • ${_qty(bill.quantity)} ${bill.unit}',
              style: const TextStyle(
                  fontSize: 13.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'HOD note (optional)',
                hintText: 'Tell the supervisor what to fix or confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  status == 'rejected' ? AppTheme.danger : AppTheme.primary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              status == 'approved' ? 'Approve' : 'Reject',
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await _repo.reviewGinAsHod(
      bill: bill,
      status: status,
      note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _snack(
        status == 'approved'
            ? 'GIN approved — supervisor can add to stock.'
            : 'GIN rejected — supervisor notified to fix.',
        status == 'approved' ? AppTheme.success : AppTheme.warning,
      );
      await _load();
    } else {
      _snack('Review failed. Check RLS permissions.', AppTheme.danger);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════

  String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }

  Widget _emptyView(String message) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined,
                size: 42, color: AppTheme.textHint),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13.5, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: 'HOD Stock',
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _busy ? null : _refreshAll,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Stock'),
        Tab(text: 'Actions'),
        Tab(text: 'Place Order'),
        Tab(text: 'Orders'),
      ],
      body: _loading
          ? _loadingView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStockAvailableTab(),
                _buildActionsTab(),
                _buildPlaceOrder(),
                _buildOrders(),
              ],
            ),
    );
  }

  // ── Tab 1: Stock Available ────────────────────────────────────

  Widget _buildStockAvailableTab() {
    final lowCount = _items.where(_isLow).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(
          Icons.inventory_2_outlined,
          'Stock available',
          '$_items items • $lowCount low • tap an item for full detail',
        ),
        for (final category in _categories) ...[
          _categoryHeader(category),
          ..._itemsIn(category).map((item) => _stockItemCard(item)),
        ],
      ],
    );
  }

  Widget _categoryHeader(String category) {
    final items = _itemsIn(category);
    final low = items.where(_isLow).length;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(category.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary)),
          ),
          const SizedBox(width: 8),
          Text('${items.length} items',
              style:
                  const TextStyle(fontSize: 11.5, color: AppTheme.textHint)),
          if (low > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.warningBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$low LOW',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warning)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stockItemCard(StockInventoryItem item) {
    final total = _totalForItem(item.id);
    final batches = _batchesForItem(item.id);
    final low = _isLow(item);
    final typeLabel = item.category.isNotEmpty
        ? item.category
        : (item.group.isNotEmpty ? item.group : 'General');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openItemDetail(item),
        child: _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.name,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                  ),
                  if (low)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('LOW STOCK',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.danger)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.successBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('OK',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.success)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip(Icons.category_outlined, typeLabel,
                      AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  _chip(Icons.straighten_outlined, item.uom,
                      AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  if (item.brand.isNotEmpty)
                    _chip(Icons.storefront_outlined, item.brand,
                        AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_qty(total)} ${item.uom} on hand',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: low ? AppTheme.danger : AppTheme.primary),
                    ),
                  ),
                  if (item.tracksLowStock)
                    Text('reorder ${_qty(item.reorderLevel)} ${item.uom}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textHint)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.textHint),
                ],
              ),
              if (batches.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: batches
                      .map((b) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              '${b.batchId}: ${_qty(b.availableQty)} ${item.uom}'
                              '${b.looseQty > 0 ? ' + ${_qty(b.looseQty)} loose' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Future<void> _openItemDetail(StockInventoryItem item) async {
    final batches = _batchesForItem(item.id);
    final movements = await _repo.fetchMovementsForItem(item.id);
    if (!mounted) return;
    final total = _totalForItem(item.id);
    final low = _isLow(item);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: low ? AppTheme.dangerBg : AppTheme.successBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(low ? 'LOW STOCK' : 'IN STOCK',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: low ? AppTheme.danger : AppTheme.success)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${item.code} • ${item.group} • ${item.category}',
                style:
                    const TextStyle(fontSize: 12.5, color: AppTheme.textHint)),
            const SizedBox(height: 16),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ON HAND',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Text('${_qty(total)} ${item.uom}',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: low ? AppTheme.danger : AppTheme.primary)),
                  const SizedBox(height: 4),
                  if (item.tracksLowStock)
                    Text(
                        'Reorder level: ${_qty(item.reorderLevel)} ${item.uom} '
                        '• ${item.brand.isNotEmpty ? 'Brand: ${item.brand}' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle(
                Icons.layers_outlined, 'Batches', '${batches.length} batches'),
            if (batches.isEmpty)
              _panel(child: _emptyView('No batches with stock for this item.'))
            else
              ...batches.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.batchId,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary)),
                              const SizedBox(height: 3),
                              Text(b.stockPointName,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppTheme.textHint)),
                              const SizedBox(height: 2),
                              Text('Updated ${_formatDate(b.updatedAt)}',
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppTheme.textHint)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${_qty(b.availableQty)} ${item.uom}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primary)),
                            if (b.looseQty > 0)
                              Text('+ ${_qty(b.looseQty)} loose',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.warning)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _sectionTitle(
                Icons.timeline_outlined, 'Movement audit', 'Latest activity'),
            if (movements.isEmpty)
              _panel(child: _emptyView('No movements recorded yet.'))
            else
              _panel(
                child: Column(
                  children: movements
                      .map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _movementColor(m.movementType)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                      _movementIcon(m.movementType),
                                      size: 14,
                                      color:
                                          _movementColor(m.movementType)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(m.movementType.toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textPrimary)),
                                      Text(m.reason,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textHint)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '${m.quantity > 0 ? '+' : ''}${_qty(m.quantity)}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _movementColor(
                                            m.movementType))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _movementColor(String type) {
    switch (type) {
      case 'gin':
      case 'transfer_in':
      case 'return':
        return AppTheme.success;
      case 'issue':
      case 'transfer_out':
        return AppTheme.warning;
      default:
        return AppTheme.info;
    }
  }

  IconData _movementIcon(String type) {
    switch (type) {
      case 'gin':
        return Icons.add_box_outlined;
      case 'transfer_in':
        return Icons.south_west_outlined;
      case 'transfer_out':
        return Icons.north_east_outlined;
      case 'return':
        return Icons.replay_outlined;
      case 'issue':
        return Icons.outbox_outlined;
      default:
        return Icons.swap_horiz_outlined;
    }
  }

  // ── Tab 2: Actions (GIN approvals) ────────────────────────────

  Widget _buildActionsTab() {
    final pending = _pendingGin;
    final reviewed = _reviewedGin;
    final recentConsumptions = _consumptions.take(8).toList();
    final recentTransfers = _transfers.take(8).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(
          Icons.fact_check_outlined,
          'Supervisor GIN actions',
          '${pending.length} awaiting your review • ${reviewed.length} reviewed',
        ),
        if (pending.isEmpty)
          _panel(
            child: _emptyView(
                'No GIN bills awaiting review. When the supervisor receives '
                'an order, it appears here for your approval.'),
          )
        else
          ...pending.map(
            (bill) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(bill.ginNo,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.warningBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('PENDING',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.warning)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(bill.itemName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Batch ${bill.batch} • ${bill.stockPointName}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                        Text('${_qty(bill.quantity)} ${bill.unit}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Received by ${bill.receivedBy ?? 'supervisor'} • ${_formatDate(bill.createdAt)}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.textHint)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () =>
                                    _reviewGin(bill, status: 'approved'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.success,
                              side: const BorderSide(
                                  color: AppTheme.successLight),
                            ),
                            icon: const Icon(Icons.check_circle_outline,
                                size: 16),
                            label: const Text('Approve',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () =>
                                    _reviewGin(bill, status: 'rejected'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.danger,
                              side: const BorderSide(
                                  color: AppTheme.dangerLight),
                            ),
                            icon:
                                const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Reject',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (reviewed.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle(
              Icons.history_outlined, 'Reviewed', 'Your past decisions'),
          ...reviewed.map(
            (bill) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _panel(
                child: Row(
                  children: [
                    Icon(
                      bill.hodStatus == 'approved'
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 20,
                      color: bill.hodStatus == 'approved'
                          ? AppTheme.success
                          : AppTheme.danger,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${bill.ginNo} • ${bill.itemName}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary)),
                          Text(
                            bill.hodNote != null
                                ? 'Note: ${bill.hodNote}'
                                : '${bill.hodStatus.toUpperCase()} by ${bill.hodReviewedBy ?? 'HOD'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppTheme.textHint),
                          ),
                        ],
                      ),
                    ),
                    Text(_formatDate(bill.hodReviewedAt),
                        style: const TextStyle(
                            fontSize: 10.5, color: AppTheme.textHint)),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _sectionTitle(
          Icons.pending_actions_outlined,
          'Supervisor activity',
          'Consumption + internal transfers across sites',
        ),
        if (recentConsumptions.isEmpty && recentTransfers.isEmpty)
          _panel(child: _emptyView('No consumption or transfer activity yet.'))
        else ...[
          if (recentConsumptions.isNotEmpty) ...[
            const Text('CONSUMPTIONS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            ...recentConsumptions.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _panel(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.outbox_outlined,
                            size: 14, color: AppTheme.warning),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.itemName,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary)),
                            Text(
                              'Batch ${c.batchCode} • ${c.stockPointName} • ${c.reason}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textHint),
                            ),
                          ],
                        ),
                      ),
                      Text('−${_qty(c.quantity)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warning)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (recentTransfers.isNotEmpty) ...[
            const Text('TRANSFERS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            ...recentTransfers.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _panel(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.swap_horiz_outlined,
                            size: 14, color: AppTheme.info),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t.transferNo} • ${t.itemName}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary)),
                            Text(
                              '${t.fromPoint} → ${t.toPoint} • ${t.status}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textHint),
                            ),
                          ],
                        ),
                      ),
                      Text('${_qty(t.quantity)} ${t.unit}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.info)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── Tab 3: Place Order ────────────────────────────────────────

  Widget _buildPlaceOrder() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.storefront_outlined,
                    color: AppTheme.primary, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Place Stock Order',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      SizedBox(height: 3),
                      Text(
                          'Add multiple items in ONE order. The supervisor receives it in Stock → View Orders and reviews it in GIN.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.playlist_add_check_circle_outlined,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Order Items',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${_orderDrafts.length} line(s)',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _orderDrafts.length; i++)
            _buildOrderItemRow(i),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addOrderDraft,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Another Item'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _points.keys.contains(_pointId) ? _pointId : null,
            isExpanded: true,
            decoration: _dec('Thavvu Point', Icons.warehouse_outlined),
            items: _points.entries
                .map((e) => DropdownMenuItem(
                    value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _pointId = v;
                _pointName = _points[v] ?? v;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: _dec('Order Notes (optional)', Icons.notes_outlined),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : _placeOrder,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_shopping_cart_outlined, size: 18),
              label: Text(
                _saving
                    ? 'Placing Order...'
                    : 'Place Order (${_orderDrafts.length} item${_orderDrafts.length == 1 ? '' : 's'})',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(int index) {
    final draft = _orderDrafts[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  draft.manual
                      ? (draft.nameCtrl.text.trim().isEmpty
                          ? 'New item (type name below)'
                          : draft.nameCtrl.text.trim())
                      : draft.itemId == null
                          ? 'Select item'
                          : (_itemFor(draft.itemId)?.name ?? 'Item'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _removeOrderDraft(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      size: 14, color: AppTheme.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Catalog Item')),
              ButtonSegment(value: true, label: Text('New Item')),
            ],
            selected: {draft.manual},
            onSelectionChanged: (s) => setState(() => draft.manual = s.first),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),
          if (draft.manual)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: draft.nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'New Item Name',
                      hintText: 'e.g., TMT Steel Bar 16mm',
                      isDense: true,
                      prefixIcon:
                          const Icon(Icons.edit_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.uomCtrl,
                    decoration: InputDecoration(
                      labelText: 'UoM',
                      isDense: true,
                      prefixIcon: const Icon(Icons.straighten, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            )
          else
            DropdownButtonFormField<String>(
              initialValue: draft.itemId,
              isExpanded: true,
              hint: const Text('Item', style: TextStyle(fontSize: 13)),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.category_outlined, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              items: _items
                  .map((i) => DropdownMenuItem(
                      value: i.id,
                      child: Text('${i.name} (${i.uom})',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => draft.itemId = v),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    isDense: true,
                    prefixIcon: const Icon(Icons.numbers_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.batchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Batch (optional)',
                    hintText: 'auto if empty',
                    isDense: true,
                    prefixIcon: const Icon(Icons.qr_code_2, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Orders ─────────────────────────────────────────────

  /// Opens the GIN reconciliation table for this exact order so HOD sees
  /// every item line, the supervisor's ACTIONS and can approve / reject.
  Future<void> _openOrderGin(StockOrderGroup group) async {
    final bill = await GinRepository().fetchBillByOrderNo(group.orderNo);
    if (!mounted) return;
    if (bill == null) {
      _snack('No GIN bill found for ${group.orderNo} yet', AppTheme.warning);
      return;
    }
    final updated = await Navigator.push<GinBill?>(
      context,
      MaterialPageRoute(
        builder: (_) => GinBillDetailsScreen(
          bill: bill,
          mode: GinReviewMode.hod,
          repo: GinRepository(),
          onChanged: (_) {},
        ),
      ),
    );
    if (updated != null && mounted) _load();
  }

  Widget _buildOrders() {
    if (_orders.isEmpty) {
      return _emptyView('No orders placed yet. Place one from the '
          'Place Order tab — the supervisor receives it and it flows '
          'through GIN approval.');
    }
    final groups = StockOrderGroup.groupOrders(_orders);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final group = groups[i];
        final Color color;
        final String status;
        switch (group.status) {
          case 'received':
            color = AppTheme.info;
            status = 'Received — in GIN review';
            break;
          case 'added_to_stock':
            color = AppTheme.success;
            status = 'Added to stock';
            break;
          case 'cancelled':
            color = AppTheme.textMuted;
            status = 'Cancelled';
            break;
          default:
            color = AppTheme.warning;
            status = 'Placed — awaiting receive';
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(group.orderNo,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${group.itemCount} item(s) · '
                  '${_qty(group.totalQuantity)} total',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              for (final item in group.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 7, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item.itemName,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                      ),
                      const SizedBox(width: 8),
                      Text('${_qty(item.quantity)} ${item.unit}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(group.stockPointName,
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              if ((group.items.first.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(group.items.first.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textHint)),
              ],
              if (group.status == 'received' ||
                  group.status == 'added_to_stock') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openOrderGin(group),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(
                        group.status == 'received'
                            ? 'View GIN — approve / reject'
                            : 'View GIN table & actions',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One line of the HOD multi-item order form. Supports picking an existing
/// catalog item OR typing a brand-new item manually (server creates it).
class _HodOrderItemDraft {
  String? itemId;
  bool manual = false;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController uomCtrl = TextEditingController(text: 'units');
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController batchCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    uomCtrl.dispose();
    qtyCtrl.dispose();
    batchCtrl.dispose();
  }
}
