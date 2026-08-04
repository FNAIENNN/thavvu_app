import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/attendance_context_service.dart';
import '../../../services/stock_inventory_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

/// HOD Transfers — production review of every internal stock transfer.
///
/// Mirrors the supervisor Stock → Transfer flow with HOD-specialized
/// visibility: all transfers across the site with live status
/// (initiated → delivered → received), point scoping, and the ability to
/// initiate a new transfer the supervisor then delivers/receives.
class HodTransfersScreen extends StatefulWidget {
  const HodTransfersScreen({super.key});

  @override
  State<HodTransfersScreen> createState() => _HodTransfersScreenState();
}

class _HodTransfersScreenState extends State<HodTransfersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = StockInventoryRepository();
  final AttendanceContextService _contextService = AttendanceContextService();

  List<StockTransfer> _transfers = <StockTransfer>[];
  List<StockInventoryItem> _items = <StockInventoryItem>[];
  List<StockBatchBalance> _balances = <StockBatchBalance>[];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _busy = false;
  String _siteId = 'SITE-VJA-001';

  // New transfer form.
  String? _itemId;
  String? _fromPointId;
  String? _toPointId;
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initServer();
  }

  @override
  void dispose() {
    _repo.stopWatching(_channel);
    _tabController.dispose();
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
      // Best-effort context.
    }
    _channel = _repo.watchTransfers(_load);
    await _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.fetchTransfers(),
        _repo.fetchItems(),
        _repo.fetchBatchBalances(),
      ]);
      if (!mounted) return;
      setState(() {
        _transfers = results[0] as List<StockTransfer>;
        _items = results[1] as List<StockInventoryItem>;
        _balances = results[2] as List<StockBatchBalance>;
        _itemId ??= _items.isEmpty ? null : _items.first.id;
        final points = _pointOptions;
        _fromPointId ??= points.isEmpty ? null : points.first;
        _toPointId ??= points.length > 1 ? points[1] : (points.isEmpty ? null : points.first);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await _load();
    if (!mounted) return;
    _showSnack('Transfers refreshed.', AppTheme.info);
  }

  // ── Derived ──────────────────────────────────────────────────

  List<String> get _pointOptions {
    final set = <String>{};
    for (final b in _balances) {
      set.add(b.stockPointName);
    }
    return set.toList()..sort();
  }

  String _pointName(String? id) {
    if (id == null || id.isEmpty) return '—';
    for (final b in _balances) {
      if (b.stockPointId == id) return b.stockPointName;
    }
    return id;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return AppTheme.success;
      case 'delivered':
        return AppTheme.info;
      case 'cancelled':
        return AppTheme.textMuted;
      default:
        return AppTheme.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'initiated':
        return 'Initiated — awaiting delivery';
      case 'delivered':
        return 'Delivered — awaiting receive';
      case 'received':
        return 'Received — stock added';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  void _showSnack(String message, Color color) {
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

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _createTransfer() async {
    final item = _items.where((i) => i.id == _itemId).toList();
    if (item.isEmpty) {
      _showSnack('Select an item', AppTheme.warning);
      return;
    }
    if (_fromPointId == null || _toPointId == null || _fromPointId == _toPointId) {
      _showSnack('Choose two different stock points', AppTheme.warning);
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _showSnack('Enter a valid quantity', AppTheme.warning);
      return;
    }
    setState(() => _busy = true);
    final ok = await _repo.createTransfer(
      transferNo: 'TRF-${DateTime.now().millisecondsSinceEpoch}',
      siteId: _siteId,
      fromPointId: _fromPointId!,
      fromPoint: _pointName(_fromPointId),
      toPointId: _toPointId!,
      toPoint: _pointName(_toPointId),
      itemId: item.first.id,
      itemName: item.first.name,
      batch: 'B-${item.first.code}-${DateTime.now().year}',
      quantity: qty,
      looseQuantity: 0,
      unit: item.first.uom,
      notes: _notesCtrl.text.trim(),
      thavvuPointId: await _contextService.resolvePointId(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _qtyCtrl.clear();
      _notesCtrl.clear();
      _showSnack('Transfer created — supervisor delivers & receives it.',
          AppTheme.success);
      _tabController.animateTo(1);
      await _load();
    } else {
      _showSnack('Failed to create transfer', AppTheme.danger);
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: 'HOD Transfers',
      actions: [
        IconButton(
          tooltip: 'Refresh transfers',
          onPressed: _busy ? null : _refreshAll,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Transfers'),
        Tab(text: 'New Transfer'),
      ],
      body: _loading
          ? _loadingView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTransfersTab(),
                _buildNewTransferTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final initiated = _transfers.where((t) => t.status == 'initiated').length;
    final delivered = _transfers.where((t) => t.status == 'delivered').length;
    final received = _transfers.where((t) => t.status == 'received').length;
    final cancelled = _transfers.where((t) => t.status == 'cancelled').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.swap_horiz_outlined,
                      size: 16, color: Colors.white70),
                  SizedBox(width: 6),
                  Text('LIVE TRANSFER PIPELINE',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 6),
              Text('${_transfers.length} total transfers',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _heroMetric('Initiated', '$initiated'),
                  _heroMetric('Delivered', '$delivered'),
                  _heroMetric('Received', '$received'),
                  _heroMetric('Cancelled', '$cancelled'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(Icons.local_shipping_outlined, 'Stock points',
            'Points available for transfers'),
        _panel(
          child: _pointOptions.isEmpty
              ? _emptyView('No stock points found.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pointOptions
                      .map((p) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(p,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary)),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _heroMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ],
    );
  }

  Widget _buildTransfersTab() {
    if (_transfers.isEmpty) {
      return _emptyView('No transfers yet. Create one from the '
          'New Transfer tab — the supervisor delivers & receives it.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(Icons.local_shipping_outlined, 'All transfers',
            '${_transfers.length} • live status from the DB'),
        ..._transfers.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openTransferDetail(t),
              child: _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.transferNo,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(t.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_statusLabel(t.status),
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: _statusColor(t.status))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(t.itemName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t.fromPoint} → ${t.toPoint}',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                        Text('${_qty(t.quantity)} ${t.unit}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Initiated ${_formatDate(t.initiatedAt)} • Batch ${t.batch}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.textHint)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openTransferDetail(StockTransfer t) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.45,
        maxChildSize: 0.9,
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
                  child: Text(t.transferNo,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(t.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(t.status),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: _statusColor(t.status))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('Item', t.itemName),
            _detailRow('Batch', t.batch),
            _detailRow('From', t.fromPoint),
            _detailRow('To', t.toPoint),
            _detailRow('Quantity', '${_qty(t.quantity)} ${t.unit}'),
            _detailRow('Initiated', _formatDate(t.initiatedAt)),
            _detailRow('Delivered',
                t.deliveredAt != null ? _formatDate(t.deliveredAt) : '—'),
            _detailRow('Received',
                t.receivedAt != null ? _formatDate(t.receivedAt) : '—'),
            if ((t.notes ?? '').isNotEmpty) _detailRow('Notes', t.notes!),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12.5, color: AppTheme.textHint)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildNewTransferTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.add_circle_outline, 'Initiate transfer',
              'Creates a stock_transfers row the supervisor delivers & receives'),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  initialValue: _fromPointId,
                  isExpanded: true,
                  decoration: _dec('From point', Icons.warehouse_outlined),
                  items: _pointOptions
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _fromPointId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _toPointId,
                  isExpanded: true,
                  decoration: _dec('To point', Icons.add_location_alt_outlined),
                  items: _pointOptions
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _toPointId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Quantity', Icons.numbers_outlined),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _dec('Notes (optional)', Icons.notes_outlined),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _createTransfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: Text(_busy ? 'Creating…' : 'Create transfer',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
