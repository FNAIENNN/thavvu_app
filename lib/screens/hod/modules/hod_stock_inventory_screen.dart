import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/attendance_context_service.dart';
import '../../../services/stock_inventory_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

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
  String? _itemId;
  String _pointId = 'SP-001';
  String _pointName = 'Site A — North';
  final _batchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initServer();
  }

  @override
  void dispose() {
    for (final channel in _channels) {
      _repo.stopWatching(channel);
    }
    _tabController.dispose();
    _batchCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
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

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.fetchItems(),
        _repo.fetchBatchBalances(),
        _repo.fetchOrders(),
        _repo.fetchGinBills(),
        _repo.fetchConsumptions(),
        _repo.fetchTransfers(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<StockInventoryItem>;
        _balances = results[1] as List<StockBatchBalance>;
        _orders = results[2] as List<StockOrder>;
        _ginBills = results[3] as List<StockGinBill>;
        _consumptions = results[4] as List<StockConsumption>;
        _transfers = results[5] as List<StockTransfer>;
        _itemId ??= _items.isEmpty ? null : _items.first.id;
        if (_balances.isNotEmpty) {
          _pointId = _balances.first.stockPointId;
          _pointName = _balances.first.stockPointName;
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
    for (final b in _balances) {
      map[b.stockPointId] = b.stockPointName;
    }
    return map;
  }

  StockInventoryItem? get _selectedItem {
    for (final i in _items) {
      if (i.id == _itemId) return i;
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════

  Future<void> _placeOrder() async {
    final item = _selectedItem;
    if (item == null) {
      _snack('Select an item', AppTheme.warning);
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _snack('Enter a valid quantity', AppTheme.warning);
      return;
    }
    setState(() => _saving = true);
    final ok = await _repo.placeOrder(
      orderNo: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      siteId: _siteId,
      stockPointId: _pointId,
      stockPointName: _pointName,
      itemId: item.id,
      itemName: item.name,
      batch: _batchCtrl.text.trim().isEmpty
          ? 'B-${item.code}-${DateTime.now().year}'
          : _batchCtrl.text.trim(),
      quantity: qty,
      unit: item.uom,
      notes: _notesCtrl.text.trim(),
      thavvuPointId: await _contextService.resolvePointId(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _snack('Order placed — supervisor can receive it in Stock → View Orders',
          AppTheme.success);
      _qtyCtrl.clear();
      _notesCtrl.clear();
      _tabController.animateTo(3);
    } else {
      _snack('Failed to place order', AppTheme.danger);
    }
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
                          'The supervisor receives this order in Stock → View Orders and reviews it in GIN.',
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
          DropdownButtonFormField<String>(
            initialValue: _itemId,
            isExpanded: true,
            decoration: _dec('Item', Icons.category_outlined),
            items: _items
                .map((i) => DropdownMenuItem(
                    value: i.id,
                    child: Text('${i.name} (${i.uom})',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _itemId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _points.keys.contains(_pointId) ? _pointId : null,
            isExpanded: true,
            decoration: _dec('Stock Point', Icons.warehouse_outlined),
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
            controller: _batchCtrl,
            decoration: _dec('Batch (optional)', Icons.qr_code_2),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Quantity', Icons.numbers_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: _dec('Notes (optional)', Icons.notes_outlined),
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
              label: const Text('Place Order',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Orders ─────────────────────────────────────────────

  Widget _buildOrders() {
    if (_orders.isEmpty) {
      return _emptyView('No orders placed yet. Place one from the '
          'Place Order tab — the supervisor receives it and it flows '
          'through GIN approval.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final o = _orders[i];
        final Color color;
        final String status;
        switch (o.status) {
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
                    child: Text(o.orderNo,
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
              const SizedBox(height: 10),
              Text(o.itemName,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Batch ${o.batch}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text('${_qty(o.quantity)} ${o.unit}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(o.stockPointName,
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              if ((o.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(o.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textHint)),
              ],
            ],
          ),
        );
      },
    );
  }
}
