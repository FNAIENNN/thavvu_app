import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/attendance_context_service.dart';
import '../../../services/stock_inventory_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

/// HOD Internal Transfer — point-to-point material movement review.
///
/// Uses the same Supabase `stock_transfers` backend as the supervisor's
/// Stock → Transfer flow, but is built as its own module: HOD sees every
/// internal move between stock points with live status and can track the
/// deliver → receive chain across the site.
class HodInternalTransferScreen extends StatefulWidget {
  const HodInternalTransferScreen({super.key});

  @override
  State<HodInternalTransferScreen> createState() =>
      _HodInternalTransferScreenState();
}

class _HodInternalTransferScreenState extends State<HodInternalTransferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = StockInventoryRepository();
  final AttendanceContextService _contextService = AttendanceContextService();

  List<StockTransfer> _transfers = <StockTransfer>[];
  RealtimeChannel? _channel;
  bool _loading = true;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initServer();
  }

  @override
  void dispose() {
    _repo.stopWatching(_channel);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initServer() async {
    try {
      await _contextService.resolveSiteId();
    } catch (_) {
      // Best-effort context.
    }
    _channel = _repo.watchTransfers(_load);
    await _load();
  }

  Future<void> _load() async {
    try {
      final transfers = await _repo.fetchTransfers();
      if (!mounted) return;
      setState(() {
        _transfers = transfers;
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
    _showSnack('Internal transfers refreshed.', AppTheme.info);
  }

  List<StockTransfer> get _filtered {
    if (_statusFilter == 'All') return _transfers;
    return _transfers.where((t) => t.status == _statusFilter).toList();
  }

  int get _inTransit =>
      _transfers.where((t) => t.status == 'initiated' || t.status == 'delivered').length;

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
        return 'Initiated';
      case 'delivered':
        return 'Delivered';
      case 'received':
        return 'Received';
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

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: 'HOD Internal Transfer',
      actions: [
        IconButton(
          tooltip: 'Refresh transfers',
          onPressed: _refreshAll,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Movements'),
      ],
      body: _loading
          ? _loadingView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildMovementsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
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
                  Icon(Icons.repeat_outlined, size: 16, color: Colors.white70),
                  SizedBox(width: 6),
                  Text('INTERNAL MOVEMENTS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 6),
              Text('${_transfers.length} total moves',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _heroMetric('In transit', '$_inTransit'),
                  _heroMetric('Received', '$received'),
                  _heroMetric('Cancelled', '$cancelled'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(Icons.rule_outlined, 'Movement status guide',
            'How an internal transfer closes'),
        _panel(
          child: Column(
            children: [
              _guideRow(Icons.flag_outlined, 'Initiated',
                  'HOD or supervisor starts the move', AppTheme.warning),
              _guideRow(Icons.local_shipping_outlined, 'Delivered',
                  'Stock deducted from the from-point', AppTheme.info),
              _guideRow(Icons.check_circle_outline, 'Received',
                  'Stock added to the to-point — closed', AppTheme.success),
            ],
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

  Widget _guideRow(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(Icons.compare_arrows_outlined, 'Movements',
            '${_filtered.length} of ${_transfers.length} • point-to-point'),
        _panel(
          child: DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Status filter',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All statuses')),
              DropdownMenuItem(value: 'initiated', child: Text('Initiated')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'received', child: Text('Received')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
          ),
        ),
        const SizedBox(height: 12),
        if (_filtered.isEmpty)
          _panel(child: _emptyView('No internal movements match.'))
        else
          ..._filtered.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                            color:
                                _statusColor(t.status).withValues(alpha: 0.12),
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
                            fontSize: 14.5,
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
                        '${_formatDate(t.initiatedAt)} • Batch ${t.batch}'
                        '${t.receivedAt != null ? ' • Received ${_formatDate(t.receivedAt)}' : ''}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.textHint)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
