import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/attendance_context_service.dart';
import '../../../services/cash_repository.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/reports_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

/// HOD Reports Module — live cross-site aggregation.
///
/// The supervisor Reports screen is site-scoped; this HOD screen aggregates
/// every module (attendance, food, stock, machines, diesel, rental, cash)
/// across all sites the HOD can see, with per-site drill-down.
class HodReportsScreen extends StatefulWidget {
  const HodReportsScreen({super.key});

  @override
  State<HodReportsScreen> createState() => _HodReportsScreenState();
}

class _SiteReport {
  final String siteId;
  final String siteName;
  final String place;
  final Map<String, double> live;

  const _SiteReport({
    required this.siteId,
    required this.siteName,
    required this.place,
    required this.live,
  });
}

class _HodReportsScreenState extends State<HodReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final ReportsRepository _reportsRepo = ReportsRepository();
  final AttendanceContextService _contextService = AttendanceContextService();

  bool _loading = true;
  bool _refreshing = false;
  String _currentSiteId = 'SITE-VJA-001';
  List<_SiteReport> _siteReports = <_SiteReport>[];
  Map<String, Map<String, int>> _flow = {};
  RealtimeChannel? _cashChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    unawaited(_initServer());
  }

  @override
  void dispose() {
    CashRepository().stopWatching(_cashChannel);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initServer() async {
    try {
      final siteId = await _contextService.resolveSiteId();
      if (!mounted) return;
      _currentSiteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
      // Realtime refresh when cash moves (approvals happen live on the HOD shell).
      _cashChannel = CashRepository().watchAll(_currentSiteId, _loadAll);
      await _loadAll();
    } catch (_) {
      // Supabase not initialized / offline: render empty reports instead
      // of hanging on a spinner.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAll() async {
    try {
      final sites = await Supabase.instance.client
          .from('sites')
          .select('id, name, place')
          .order('name');
      final siteRows = (sites as List).cast<Map>();

      final reports = <_SiteReport>[];
      final flow = <String, Map<String, int>>{};
      for (final row in siteRows) {
        final siteId = row['id']?.toString() ?? '';
        final live = await _aggregateSite(siteId);
        flow[siteId] = await _aggregateFlow(siteId);
        reports.add(_SiteReport(
          siteId: siteId,
          siteName: row['name']?.toString() ?? siteId,
          place: row['place']?.toString() ?? '',
          live: live,
        ));
      }

      if (!mounted) return;
      setState(() {
        _siteReports = reports;
        _flow = flow;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<Map<String, double>> _aggregateSite(String siteId) async {
    final results = await Future.wait([
      _reportsRepo.attendanceSummary(siteId),
      _reportsRepo.foodRequests(siteId),
      _reportsRepo.stockSummary(siteId),
      _reportsRepo.dieselIssued(siteId),
      _reportsRepo.machineLogs(siteId),
      _reportsRepo.rentalSummary(siteId),
      _reportsRepo.cashSpent(siteId),
      CashRepository().availableBalance(siteId),
    ]);
    final attendance = results[0] as Map<String, int>;
    final stock = results[2] as Map<String, double>;
    final rental = results[5] as Map<String, double>;
    return {
      'present': (attendance['present'] ?? 0).toDouble(),
      'absent': (attendance['absent'] ?? 0).toDouble(),
      'late': (attendance['late'] ?? 0).toDouble(),
      'leave': (attendance['leave'] ?? 0).toDouble(),
      'food': (results[1] as int).toDouble(),
      'stockItems': stock['items'] ?? 0,
      'lowStock': stock['low'] ?? 0,
      'diesel': results[3] as double,
      'machines': (results[4] as int).toDouble(),
      'rentalCount': rental['count'] ?? 0,
      'rentalTotal': rental['total'] ?? 0,
      'cashSpent': results[6] as double,
      'cashBalance': results[7] as double,
    };
  }

  Future<Map<String, int>> _aggregateFlow(String siteId) async {
    final results = await Future.wait([
      _reportsRepo.registrySummary(siteId),
      _reportsRepo.ordersSummary(siteId),
      _reportsRepo.ginSummary(siteId),
      _reportsRepo.flowSummary(siteId),
    ]);
    final merged = <String, int>{};
    for (final map in results) {
      merged.addAll(map);
    }
    return merged;
  }

  Future<void> _refreshAll() async {
    setState(() => _refreshing = true);
    await _loadAll();
    if (!mounted) return;
    setState(() => _refreshing = false);
    _showSnack('Reports refreshed.', AppTheme.info);
  }

  // ── Helpers ──────────────────────────────────────────────────

  Map<String, double> get _totals {
    final totals = <String, double>{};
    for (final report in _siteReports) {
      report.live.forEach((key, value) {
        totals[key] = (totals[key] ?? 0) + value;
      });
    }
    return totals;
  }

  String _money(double value) {
    return value >= 1000
        ? '₹${(value / 1000).toStringAsFixed(1)}k'
        : '₹${value.toStringAsFixed(0)}';
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
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value',
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color,
      {String? sub}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            if (sub != null)
              Text(sub,
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textHint)),
          ],
        ),
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
            const Icon(Icons.inbox_outlined, size: 42, color: AppTheme.textHint),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: 'HOD Reports',
      actions: [
        IconButton(
          tooltip: 'Refresh reports',
          onPressed: _refreshing ? null : _refreshAll,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Sites'),
        Tab(text: 'Cash & Rental'),
        Tab(text: 'Registries & Flow'),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildSitesTab(),
          _buildCashRentalTab(),
          _buildFlowTab(),
        ],
      ),
    );
  }

  // ── Tab 4: Registries & Flow ─────────────────────────────────

  Widget _buildFlowTab() {
    if (_siteReports.isEmpty) {
      return Center(
        child: Text('No site data yet.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(Icons.tune_rounded,
            'Registries & Workflow', 'All master data and every module entry in one place'),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Master Data (active)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              ..._siteReports.map((report) {
                final flow = _flow[report.siteId] ?? const {};
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.siteName,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _flowStat(Icons.business_outlined, 'Suppliers',
                              flow['suppliers'] ?? 0, AppTheme.info),
                          _flowStat(Icons.person_outline, 'Workers',
                              flow['workers'] ?? 0, AppTheme.success),
                          _flowStat(Icons.construction_rounded, 'Machines',
                              flow['machines'] ?? 0, AppTheme.warning),
                          _flowStat(Icons.inventory_2_outlined, 'Items',
                              flow['items'] ?? 0, AppTheme.primary),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order → GIN Lifecycle',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              ..._siteReports.map((report) {
                final flow = _flow[report.siteId] ?? const {};
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(report.siteName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                      ),
                      _pill('${flow['placed'] ?? 0} placed',
                          AppTheme.warning),
                      const SizedBox(width: 4),
                      _pill('${flow['received'] ?? 0} received',
                          AppTheme.info),
                      const SizedBox(width: 4),
                      _pill('${flow['added'] ?? 0} added',
                          AppTheme.success),
                      const SizedBox(width: 4),
                      _pill('${flow['pending'] ?? 0} GIN pending',
                          AppTheme.warning),
                      const SizedBox(width: 4),
                      _pill('${flow['approved'] ?? 0} approved',
                          AppTheme.success),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Module Activity',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              ..._siteReports.map((report) {
                final flow = _flow[report.siteId] ?? const {};
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(report.siteName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                      ),
                      _pill('${flow['movements'] ?? 0} stock moves',
                          AppTheme.primary),
                      const SizedBox(width: 4),
                      _pill('${flow['transfers'] ?? 0} transfers',
                          AppTheme.info),
                      const SizedBox(width: 4),
                      _pill('${flow['tasks'] ?? 0} tasks',
                          AppTheme.warning),
                      const SizedBox(width: 4),
                      _pill('${flow['tasksDone'] ?? 0} done',
                          AppTheme.success),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _flowStat(IconData icon, String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text('$value',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9.5, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
    );
  }

  // ── Tab 1: Overview ──────────────────────────────────────────

  Future<void> _openSiteDetail(_SiteReport report) async {
    final results = await Future.wait([
      _reportsRepo.recentSiteActivity(report.siteId),
      _reportsRepo.pointSummary(report.siteId),
    ]);
    if (!mounted) return;
    final activity = results[0] as List<SiteActivityEntry>;
    final pointSummary = results[1] as Map<String, Map<String, double>>;
    final live = report.live;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.97,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.siteName,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary)),
                      Text(
                          '${report.siteId}${report.place.isNotEmpty ? ' • ${report.place}' : ''}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppTheme.textHint)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Download site CSV',
                  onPressed: () => _exportSiteCsv(report),
                  icon: const Icon(Icons.download_outlined,
                      color: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(live['present'] ?? 0).round()} workers present',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(live['absent'] ?? 0).round()} absent • '
                    '${(live['late'] ?? 0).round()} late • '
                    '${(live['leave'] ?? 0).round()} leave',
                    style: const TextStyle(
                        fontSize: 12.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _detailSection(
                Icons.grid_view_outlined, 'Live module summary'),
            _panel(
              child: Column(
                children: [
                  Row(
                    children: [
                      _statCard(Icons.restaurant_outlined, 'Food',
                          '${(live['food'] ?? 0).round()}', AppTheme.success),
                      const SizedBox(width: 8),
                      _statCard(Icons.inventory_2_outlined, 'Stock items',
                          '${(live['stockItems'] ?? 0).round()}', AppTheme.info,
                          sub: '${(live['lowStock'] ?? 0).round()} low'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statCard(Icons.local_gas_station_outlined, 'Diesel',
                          '${(live['diesel'] ?? 0).round()} L', AppTheme.warning),
                      const SizedBox(width: 8),
                      _statCard(Icons.precision_manufacturing_outlined,
                          'Machines', '${(live['machines'] ?? 0).round()}',
                          AppTheme.secondary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statCard(Icons.handyman_outlined, 'Rentals',
                          _money(live['rentalTotal'] ?? 0), AppTheme.textSecondary,
                          sub: '${(live['rentalCount'] ?? 0).round()} entries'),
                      const SizedBox(width: 8),
                      _statCard(Icons.payments_outlined, 'Cash spent',
                          _money(live['cashSpent'] ?? 0), AppTheme.danger,
                          sub: 'Bal ${_money(live['cashBalance'] ?? 0)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _detailSection(Icons.flag_outlined, 'Thavvu Points',
                "Every module's rows grouped per point"),
            if (pointSummary.isEmpty)
              _panel(child: _emptyView('No point-scoped data for this site yet.'))
            else
              ...pointSummary.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _pointMetric('Rows', '${(entry.value['count'] ?? 0).round()}'),
                            _pointMetric('Attendance', '${(entry.value['attendance'] ?? 0).round()}'),
                            _pointMetric('Food', '${(entry.value['food'] ?? 0).round()}'),
                            _pointMetric('Cash', '${(entry.value['cash'] ?? 0).round()}'),
                            _pointMetric('Rental', '${(entry.value['rental'] ?? 0).round()}'),
                            _pointMetric('Tasks', '${(entry.value['tasks'] ?? 0).round()}'),
                            _pointMetric('Stock', '${(entry.value['stock'] ?? 0).round()}'),
                            _pointMetric('Machines', '${(entry.value['machines'] ?? 0).round()}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _detailSection(Icons.timeline_outlined,
                'Recent activity', 'Every module event with its date & time'),
            if (activity.isEmpty)
              _panel(child: _emptyView('No recorded activity for this site yet.'))
            else
              _panel(
                child: Column(
                  children: [
                    for (var i = 0; i < activity.length; i++)
                      _activityRow(activity[i], key: ValueKey('activity-$i')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(IconData icon, String title, [String? subtitle]) {
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
                if (subtitle != null)
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

  Widget _activityRow(SiteActivityEntry entry, {required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(entry.icon, size: 15, color: entry.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text(entry.subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.at != null
                ? '${_date(entry.at!)} ${_time(entry.at!)}'
                : '',
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  String _date(DateTime d) {
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _time(DateTime d) {
    final local = d.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportSiteCsv(_SiteReport report) async {
    final live = report.live;
    final activity = await _reportsRepo.recentSiteActivity(report.siteId);
    final buffer = StringBuffer();
    buffer.writeln('Site Report — ${report.siteName} (${report.siteId})');
    buffer.writeln('Generated,${DateTime.now().toIso8601String()}');
    buffer.writeln(csvRow([
      'Metric',
      'Value',
    ]));
    buffer.writeln(csvRow(['Present', '${(live['present'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Absent', '${(live['absent'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Late', '${(live['late'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Leave', '${(live['leave'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Food', '${(live['food'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Stock items', '${(live['stockItems'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Low stock', '${(live['lowStock'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Diesel (L)', '${(live['diesel'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Machines', '${(live['machines'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Rental entries', '${(live['rentalCount'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Rental total', '${(live['rentalTotal'] ?? 0).toStringAsFixed(2)}']));
    buffer.writeln(csvRow(['Cash spent', '${(live['cashSpent'] ?? 0).toStringAsFixed(2)}']));
    buffer.writeln(csvRow(['Cash balance', '${(live['cashBalance'] ?? 0).toStringAsFixed(2)}']));
    buffer.writeln();
    buffer.writeln('Activity (date,time,source,title,subtitle)');
    buffer.writeln(csvRow(['Date', 'Time', 'Source', 'Title', 'Subtitle']));
    for (final e in activity) {
      buffer.writeln(csvRow([
        e.at != null ? _date(e.at!) : '',
        e.at != null ? _time(e.at!) : '',
        e.source,
        e.title,
        e.subtitle,
      ]));
    }
    final fileName =
        'hod_report_${report.siteId}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final path = await downloadCsvFile(fileName: fileName, csv: buffer.toString());
    if (!mounted) return;
    if (path != null) {
      _showSnack('Report saved to $path', AppTheme.success);
    } else {
      _showSnack('${report.siteName} report download started.', AppTheme.success);
    }
  }

  Future<void> _exportOverviewCsv() async {
    final totals = _totals;
    final buffer = StringBuffer();
    buffer.writeln('HOD Cross-Site Overview — '
        '${DateTime.now().toIso8601String()}');
    buffer.writeln(csvRow(['Metric', 'Value']));
    buffer.writeln(csvRow(['Sites', '${_siteReports.length}']));
    buffer.writeln(csvRow(['Present', '${(totals['present'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Absent', '${(totals['absent'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Late', '${(totals['late'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Leave', '${(totals['leave'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Food', '${(totals['food'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Stock items', '${(totals['stockItems'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Low stock', '${(totals['lowStock'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Diesel (L)', '${(totals['diesel'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Machines', '${(totals['machines'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Rental entries', '${(totals['rentalCount'] ?? 0).round()}']));
    buffer.writeln(csvRow(['Rental total', '${(totals['rentalTotal'] ?? 0).toStringAsFixed(2)}']));
    buffer.writeln(csvRow(['Cash spent', '${(totals['cashSpent'] ?? 0).toStringAsFixed(2)}']));
    buffer.writeln(csvRow(['Cash balance', '${(totals['cashBalance'] ?? 0).toStringAsFixed(2)}']));
    buffer.writeln();
    buffer.writeln('Per-site summary');
    buffer.writeln(csvRow([
      'Site ID',
      'Site Name',
      'Present',
      'Food',
      'Stock',
      'Low',
      'Diesel L',
      'Machines',
      'Rentals ₹',
      'Cash ₹',
    ]));
    for (final r in _siteReports) {
      buffer.writeln(csvRow([
        r.siteId,
        r.siteName,
        '${(r.live['present'] ?? 0).round()}',
        '${(r.live['food'] ?? 0).round()}',
        '${(r.live['stockItems'] ?? 0).round()}',
        '${(r.live['lowStock'] ?? 0).round()}',
        '${(r.live['diesel'] ?? 0).round()}',
        '${(r.live['machines'] ?? 0).round()}',
        '${(r.live['rentalTotal'] ?? 0).toStringAsFixed(2)}',
        '${(r.live['cashSpent'] ?? 0).toStringAsFixed(2)}',
      ]));
    }
    final fileName =
        'hod_reports_overview_${DateTime.now().millisecondsSinceEpoch}.csv';
    final path = await downloadCsvFile(fileName: fileName, csv: buffer.toString());
    if (!mounted) return;
    if (path != null) {
      _showSnack('Overview saved to $path', AppTheme.success);
    } else {
      _showSnack('Overview CSV download started.', AppTheme.success);
    }
  }

  Widget _buildOverviewTab() {
    if (_loading) return _loadingView();
    final totals = _totals;
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
                  Icon(Icons.analytics_outlined, size: 16, color: Colors.white70),
                  SizedBox(width: 6),
                  Text('LIVE CROSS-SITE SUMMARY',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 6),
              Text('${_siteReports.length} sites • ${totals['present']?.round() ?? 0} workers present',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 6),
              Text('₹${((totals['cashSpent'] ?? 0)).toStringAsFixed(0)} spent • ${_money(totals['rentalTotal'] ?? 0)} rentals',
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _siteReports.isEmpty ? null : _exportOverviewCsv,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primaryLight),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download overview CSV',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(Icons.grid_view_outlined, 'Module totals', 'Aggregated across all visible sites'),
        _panel(
          child: Column(
            children: [
              Row(
                children: [
                  _statCard(Icons.people_outline, 'Present',
                      '${totals['present']?.round() ?? 0}', AppTheme.primary,
                      sub: '${totals['absent']?.round() ?? 0} absent'),
                  const SizedBox(width: 8),
                  _statCard(Icons.restaurant_outlined, 'Food',
                      '${totals['food']?.round() ?? 0}', AppTheme.success),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard(Icons.inventory_2_outlined, 'Stock items',
                      '${totals['stockItems']?.round() ?? 0}', AppTheme.info,
                      sub: '${totals['lowStock']?.round() ?? 0} low'),
                  const SizedBox(width: 8),
                  _statCard(Icons.local_gas_station_outlined, 'Diesel',
                      '${totals['diesel']?.round() ?? 0} L', AppTheme.warning),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard(Icons.precision_manufacturing_outlined, 'Machines',
                      '${totals['machines']?.round() ?? 0}', AppTheme.secondary),
                  const SizedBox(width: 8),
                  _statCard(Icons.handyman_outlined, 'Rental ₹',
                      _money(totals['rentalTotal'] ?? 0), AppTheme.textSecondary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(Icons.warning_amber_outlined, 'Attention needed',
            'Sites with low stock or no activity today'),
        _panel(
          child: _siteReports.isEmpty
              ? _emptyView('No sites found.')
              : Column(
                  children: _siteReports.map((report) {
                    final low = report.live['lowStock'] ?? 0;
                    final present = report.live['present'] ?? 0;
                    final attention = low >= 3 || present == 0;
                    if (!attention) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            low >= 3 ? Icons.warning_amber_outlined : Icons.info_outline,
                            size: 18,
                            color: low >= 3 ? AppTheme.warning : AppTheme.info,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('${report.siteName} (${report.siteId})',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          ),
                          Text(
                            low >= 3
                                ? '${low.round()} low stock'
                                : 'No attendance yet',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: low >= 3 ? AppTheme.warning : AppTheme.info),
                          ),
                        ],
                      ),
                    );
                  }).whereType<Widget>().toList(),
                ),
        ),
      ],
    );
  }

  // ── Tab 2: Sites ─────────────────────────────────────────────

  Widget _buildSitesTab() {
    if (_loading) return _loadingView();
    if (_siteReports.isEmpty) {
      return _emptyView('No sites visible to your account.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(Icons.location_city_outlined, 'Site reports',
            '${_siteReports.length} sites • tap a site to expand'),
        ..._siteReports.map((report) => _siteCard(report)),
      ],
    );
  }

  Widget _siteCard(_SiteReport report) {
    final live = report.live;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openSiteDetail(report),
        child: _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.siteName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text('${report.siteId}${report.place.isNotEmpty ? ' • ${report.place}' : ''}',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (live['present'] ?? 0) > 0 ? AppTheme.successBg : AppTheme.warningBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (live['present'] ?? 0) > 0 ? 'ACTIVE' : 'NO DATA',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: (live['present'] ?? 0) > 0 ? AppTheme.success : AppTheme.warning),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _siteMetric(Icons.people_outline, 'Present', '${(live['present'] ?? 0).round()}'),
                  _siteMetric(Icons.restaurant_outlined, 'Food', '${(live['food'] ?? 0).round()}'),
                  _siteMetric(Icons.inventory_2_outlined, 'Stock', '${(live['stockItems'] ?? 0).round()}'),
                  _siteMetric(Icons.warning_amber_outlined, 'Low', '${(live['lowStock'] ?? 0).round()}'),
                  _siteMetric(Icons.local_gas_station_outlined, 'Diesel', '${(live['diesel'] ?? 0).round()} L'),
                  _siteMetric(Icons.precision_manufacturing_outlined, 'Machines', '${(live['machines'] ?? 0).round()}'),
                  _siteMetric(Icons.handyman_outlined, 'Rentals', _money(live['rentalTotal'] ?? 0)),
                  _siteMetric(Icons.payments_outlined, 'Cash', _money(live['cashSpent'] ?? 0)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.touch_app_outlined,
                      size: 13, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text('Tap for full site data • Download CSV',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Download ${report.siteName} CSV',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _exportSiteCsv(report),
                    icon: const Icon(Icons.download_outlined,
                        size: 18, color: AppTheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _siteMetric(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text('$label: ',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        Text(value,
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ],
    );
  }

  // ── Tab 3: Cash & Rental ─────────────────────────────────────

  Widget _buildCashRentalTab() {
    if (_loading) return _loadingView();
    final totals = _totals;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(Icons.account_balance_wallet_outlined, 'Financial position',
            'Cash spent vs balance, rental totals'),
        _panel(
          child: Column(
            children: [
              Row(
                children: [
                  _statCard(Icons.payments_outlined, 'Cash spent',
                      _money(totals['cashSpent'] ?? 0), AppTheme.danger),
                  const SizedBox(width: 8),
                  _statCard(Icons.account_balance_outlined, 'Cash balance',
                      _money(totals['cashBalance'] ?? 0), AppTheme.success),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard(Icons.handyman_outlined, 'Rental total',
                      _money(totals['rentalTotal'] ?? 0), AppTheme.info),
                  const SizedBox(width: 8),
                  _statCard(Icons.receipt_long_outlined, 'Rental entries',
                      '${(totals['rentalCount'] ?? 0).round()}', AppTheme.textSecondary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(Icons.account_balance_outlined, 'Cash position by site',
            'Approved spend vs available balance'),
        if (_siteReports.isEmpty)
          _panel(child: _emptyView('No sites found.'))
        else
          ..._siteReports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.siteName,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 10),
                    _barRow('Spent', report.live['cashSpent'] ?? 0, AppTheme.danger,
                        (totals['cashSpent'] ?? 0) > 0
                            ? ((report.live['cashSpent'] ?? 0) / (totals['cashSpent'] ?? 1)).clamp(0.0, 1.0)
                            : 0),
                    const SizedBox(height: 8),
                    _barRow('Balance', report.live['cashBalance'] ?? 0, AppTheme.success,
                        (totals['cashBalance'] ?? 0) > 0
                            ? ((report.live['cashBalance'] ?? 0) / (totals['cashBalance'] ?? 1)).clamp(0.0, 1.0)
                            : 0),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _barRow(String label, double value, Color color, double fraction) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceDark,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(_money(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    );
  }
}
