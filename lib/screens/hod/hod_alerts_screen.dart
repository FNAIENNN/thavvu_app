import 'package:flutter/material.dart';

import '../../models/hod_site_models.dart';
import '../../services/auth_service.dart';
import '../../services/hod_alert_service.dart';
import '../../services/hod_site_workspace_service.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import 'hod_site_modules_screen.dart';
import 'hod_sites_screen.dart';

class HodAlertsScreen extends StatefulWidget {
  const HodAlertsScreen({super.key});

  @override
  State<HodAlertsScreen> createState() => _HodAlertsScreenState();
}

class _HodAlertsScreenState extends State<HodAlertsScreen> {
  final HodAlertService _alertService = const HodAlertService();
  final HodSiteWorkspaceService _workspaceService = HodSiteWorkspaceService();
  late Future<List<HodAlertViewData>> _futureAlerts;
  late Future<List<HodWorkHistoryRow>> _futureHistory;

  @override
  void initState() {
    super.initState();
    _futureAlerts = _alertService.alertsForHod('HOD-001');
    _futureHistory = _workspaceService.workHistoryRows();
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content:
            const Text('Are you sure you want to logout from HOD workspace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Map<String, List<HodAlertViewData>> _groupBySite(
    List<HodAlertViewData> alerts,
  ) {
    final grouped = <String, List<HodAlertViewData>>{};
    for (final alert in alerts) {
      grouped.putIfAbsent(alert.siteName, () => []).add(alert);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo.png',
              key: const Key('hodTopBarLogo'),
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ),
        title: const Text('HOD Alerts'),
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {
              _futureAlerts = _alertService.alertsForHod('HOD-001');
              _futureHistory = _workspaceService.workHistoryRows();
            }),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<HodAlertViewData>>(
        future: _futureAlerts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final alerts = snapshot.data ?? const <HodAlertViewData>[];
          final groupedAlerts = _groupBySite(alerts);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(totalAlerts: alerts.length),
              const SizedBox(height: 16),
              _HistoryTableSection(futureHistory: _futureHistory),
              const SizedBox(height: 16),
              const Text(
                'Site Alerts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (groupedAlerts.isEmpty)
                const _EmptyAlertsCard()
              else
                ...groupedAlerts.entries.map(
                  (entry) => _SiteAlertCard(
                    siteName: entry.key,
                    alerts: entry.value,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HodSiteModulesScreen(
                          siteName: entry.key,
                          siteId: entry.value.first.siteId,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HodSitesScreen()),
                  ),
                  icon: const Icon(Icons.apartment_rounded),
                  label: const Text('View All Sites'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int totalAlerts;

  const _HeaderCard({required this.totalAlerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3460), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3460).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/logo.png',
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HOD Alerts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalAlerts supervisor module alerts available for HOD review.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTableSection extends StatelessWidget {
  final Future<List<HodWorkHistoryRow>> futureHistory;

  const _HistoryTableSection({required this.futureHistory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E4F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.table_chart_rounded, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HOD Work History Table',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Record of site, Thavvu Point, assigned person, status and timestamp.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<HodWorkHistoryRow>>(
            future: futureHistory,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <HodWorkHistoryRow>[];
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (rows.isEmpty) {
                return const Text('No history rows yet.');
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF1F5F9),
                  ),
                  columns: const [
                    DataColumn(label: Text('Site')),
                    DataColumn(label: Text('Thavvu Point')),
                    DataColumn(label: Text('Module')),
                    DataColumn(label: Text('Assigned To')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(row.siteName)),
                            DataCell(Text(row.pointName)),
                            DataCell(Row(
                              children: [
                                Icon(row.icon, size: 16, color: row.color),
                                const SizedBox(width: 6),
                                Text(row.module),
                              ],
                            )),
                            DataCell(Text(row.assignedTo)),
                            DataCell(Text(row.status)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyAlertsCard extends StatelessWidget {
  const _EmptyAlertsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('No pending supervisor alerts right now.'),
      ),
    );
  }
}

class _SiteAlertCard extends StatelessWidget {
  final String siteName;
  final List<HodAlertViewData> alerts;
  final VoidCallback onTap;

  const _SiteAlertCard({
    required this.siteName,
    required this.alerts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final latest = alerts.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: latest.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(latest.icon, color: latest.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siteName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: alerts
                          .map(
                            (alert) => Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(alert.module),
                              avatar: Icon(alert.icon,
                                  size: 14, color: alert.color),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${alerts.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
