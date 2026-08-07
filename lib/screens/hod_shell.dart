import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_feed_view.dart';
import 'login_screen.dart';

/// HOD dashboard: site/Thavvu-point scoped approvals, stock overview,
/// transfers, daily-log review, live reports, and supplier payments —
/// all backed directly by [AppStore]'s remote-hydrated collections.
class HodShell extends StatefulWidget {
  const HodShell({super.key});

  @override
  State<HodShell> createState() => _HodShellState();
}

class _HodShellState extends State<HodShell> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    Tab(text: 'Approvals', icon: Icon(Icons.fact_check_outlined, size: 18)),
    Tab(text: 'Stock', icon: Icon(Icons.inventory_2_outlined, size: 18)),
    Tab(text: 'Transfers', icon: Icon(Icons.compare_arrows, size: 18)),
    Tab(text: 'Daily Logs', icon: Icon(Icons.edit_calendar_outlined, size: 18)),
    Tab(text: 'Reports', icon: Icon(Icons.bar_chart_rounded, size: 18)),
    Tab(text: 'Suppliers', icon: Icon(Icons.storefront_outlined, size: 18)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppStore>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final profile = store.currentProfile;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        foregroundColor: Colors.white,
        title: RichText(
          text: TextSpan(
            children: [
              const TextSpan(text: 'HOD ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              TextSpan(text: profile?.name.isNotEmpty == true ? profile!.name : 'Dashboard', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF4FC3F7))),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: _confirmLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFF4FC3F7),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: _tabs,
        ),
      ),
      body: Column(
        children: [
          const _SiteAndPointSelector(),
          if (!store.remoteEnabled) const _RemoteRequiredBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ApprovalsTab(),
                _StockOverviewTab(),
                _TransfersTab(),
                _DailyLogsTab(),
                _ReportsTab(),
                _SuppliersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Site / Thavvu Point selector header ────────────────────────────────────

class _SiteAndPointSelector extends StatelessWidget {
  const _SiteAndPointSelector();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.remoteEnabled || store.remoteSites.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppTheme.surfaceCard,
      child: Row(
        children: [
          Expanded(
            child: _dropdown<String>(
              icon: Icons.location_city_outlined,
              hint: 'Select site',
              value: store.activeSiteId,
              items: store.remoteSites
                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                if (v != null) store.setActiveSite(v);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _dropdown<String>(
              icon: Icons.place_outlined,
              hint: 'Thavvu point',
              value: store.activeThavvuPointId,
              items: store.remoteThavvuPoints
                  .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                if (v != null) store.setActiveThavvuPoint(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required IconData icon,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: AppTheme.textMuted), const SizedBox(width: 6), Text(hint, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))]),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RemoteRequiredBanner extends StatelessWidget {
  const _RemoteRequiredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.dangerBg,
      child: Row(
        children: const [
          Icon(Icons.wifi_off_rounded, size: 16, color: AppTheme.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not connected to the live backend. Data shown may be stale until connectivity returns.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyNotice({required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Shared section/tile helpers ─────────────────────────────────────────────

Widget _sectionCard({required String title, required Color color, required int count, required List<Widget> children}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border, width: 0.8),
      boxShadow: AppTheme.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (children.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Nothing pending', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          )
        else
          ...children,
      ],
    ),
  );
}

Widget _approveRejectRow({required VoidCallback onApprove, required VoidCallback onReject}) {
  return Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.close, size: 16, color: AppTheme.danger),
          label: const Text('Reject', style: TextStyle(fontSize: 12, color: AppTheme.danger)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger), padding: const EdgeInsets.symmetric(vertical: 8)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Approve', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
        ),
      ),
    ],
  );
}

// ── Approvals tab ────────────────────────────────────────────────────────────

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.remoteEnabled) {
      return const _EmptyNotice(message: 'Connect to the live backend to review approvals.', icon: Icons.wifi_off_rounded);
    }

    final pendingLogs = store.remoteDailyLogs.where((l) => l.status == 'submitted').toList();
    final pendingOrders = store.remoteStockOrders.where((o) => o.status == 'pending').toList();
    final pendingPayments = store.supplierPayments.where((p) => p.status == 'pending').toList();

    return RefreshIndicator(
      onRefresh: store.hydrateFromRemote,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              title: 'Daily Logs Pending Review',
              color: AppTheme.info,
              count: pendingLogs.length,
              children: pendingLogs.map((log) => _dailyLogTile(context, log)).toList(),
            ),
            _sectionCard(
              title: 'Stock Orders Pending Approval',
              color: AppTheme.warning,
              count: pendingOrders.length,
              children: pendingOrders.map((order) => _stockOrderTile(context, order)).toList(),
            ),
            _sectionCard(
              title: 'Supplier Payments Pending Review',
              color: AppTheme.danger,
              count: pendingPayments.length,
              children: pendingPayments.map((p) => _supplierPaymentTile(context, p)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyLogTile(BuildContext context, DailyLog log) {
    final store = context.read<AppStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Machine ${log.machineId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Working hrs: ${log.usedAmount.toStringAsFixed(1)} · Diesel: ${log.dieselAmount.toStringAsFixed(1)} · Beta: ₹${log.betaAmount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          if (log.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(log.notes, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
          const SizedBox(height: 10),
          _approveRejectRow(
            onApprove: () => store.reviewRemoteDailyLog(log.id, 'approved'),
            onReject: () => store.reviewRemoteDailyLog(log.id, 'rejected'),
          ),
        ],
      ),
    );
  }

  Widget _stockOrderTile(BuildContext context, StockOrder order) {
    final store = context.read<AppStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${order.item} × ${order.quantity} ${order.unit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(order.stockPointName, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          if (order.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(order.notes, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
          const SizedBox(height: 10),
          _approveRejectRow(
            onApprove: () => store.reviewRemoteStockOrder(order.id, 'approved'),
            onReject: () => store.reviewRemoteStockOrder(order.id, 'rejected'),
          ),
        ],
      ),
    );
  }

  Widget _supplierPaymentTile(BuildContext context, SupplierPayment payment) {
    final store = context.read<AppStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${payment.supplierName} · ₹${payment.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Method: ${payment.mode.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          _approveRejectRow(
            onApprove: () => store.reviewSupplierPayment(payment.id, 'approved'),
            onReject: () => store.reviewSupplierPayment(payment.id, 'rejected'),
          ),
        ],
      ),
    );
  }
}

// ── Stock overview tab ───────────────────────────────────────────────────────

class _StockOverviewTab extends StatelessWidget {
  const _StockOverviewTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.remoteEnabled) {
      return const _EmptyNotice(message: 'Connect to the live backend to view stock levels.', icon: Icons.wifi_off_rounded);
    }
    final grouped = store.stockItemsByCategory;
    final balances = store.balancesForActivePoint;

    if (grouped.isEmpty) {
      return const _EmptyNotice(message: 'No stock catalog items found.');
    }

    return RefreshIndicator(
      onRefresh: store.hydrateFromRemote,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: grouped.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border, width: 0.8),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(StockCategory.label(entry.key), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  ...entry.value.map((item) {
                    final balance = balances.where((b) => b.itemName.toLowerCase() == item.name.toLowerCase()).fold<double>(0, (sum, b) => sum + b.quantity);
                    final isLow = balance <= item.reorderLevel;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isLow ? AppTheme.danger : AppTheme.success).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${balance.toStringAsFixed(balance % 1 == 0 ? 0 : 1)} ${item.unit}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isLow ? AppTheme.danger : AppTheme.success),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Transfers tab ─────────────────────────────────────────────────────────────

class _TransfersTab extends StatelessWidget {
  const _TransfersTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.remoteEnabled) {
      return const _EmptyNotice(message: 'Connect to the live backend to view transfers.', icon: Icons.wifi_off_rounded);
    }
    final transfers = store.remoteTransfers;
    if (transfers.isEmpty) {
      return const _EmptyNotice(message: 'No transfers recorded yet.', icon: Icons.compare_arrows);
    }

    return RefreshIndicator(
      onRefresh: store.hydrateFromRemote,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transfers.length,
        itemBuilder: (context, i) {
          final t = transfers[i];
          final pending = t.status == 'pending_ack';
          final statusColor = t.status == 'completed' ? AppTheme.success : pending ? AppTheme.warning : AppTheme.danger;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 0.8),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${t.item} · ${t.quantity} ${t.unit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(t.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${t.fromPoint} → ${t.toPoint}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(t.date, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                if (pending) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.read<AppStore>().acknowledgeRemoteTransfer(t.id),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Received', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Daily logs tab (full history + review) ──────────────────────────────────

class _DailyLogsTab extends StatelessWidget {
  const _DailyLogsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.remoteEnabled) {
      return const _EmptyNotice(message: 'Connect to the live backend to review daily logs.', icon: Icons.wifi_off_rounded);
    }
    final logs = store.remoteDailyLogs;
    if (logs.isEmpty) {
      return const _EmptyNotice(message: 'No daily logs submitted yet.', icon: Icons.edit_calendar_outlined);
    }

    return RefreshIndicator(
      onRefresh: store.hydrateFromRemote,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        itemBuilder: (context, i) {
          final log = logs[i];
          final color = log.status == 'approved' ? AppTheme.success : log.status == 'rejected' ? AppTheme.danger : AppTheme.warning;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 0.8),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Machine ${log.machineId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(log.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Working hrs: ${log.usedAmount.toStringAsFixed(1)} · Diesel: ${log.dieselAmount.toStringAsFixed(1)} · Beta: ₹${log.betaAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                if (log.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(log.notes, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
                if (log.status == 'submitted') ...[
                  const SizedBox(height: 10),
                  _approveRejectRow(
                    onApprove: () => context.read<AppStore>().reviewRemoteDailyLog(log.id, 'approved'),
                    onReject: () => context.read<AppStore>().reviewRemoteDailyLog(log.id, 'rejected'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Reports tab ───────────────────────────────────────────────────────────────

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: ActivityFeedView(),
    );
  }
}

// ── Suppliers tab ─────────────────────────────────────────────────────────────

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.remoteEnabled) {
      return const _EmptyNotice(message: 'Connect to the live backend to manage suppliers.', icon: Icons.wifi_off_rounded);
    }

    return RefreshIndicator(
      onRefresh: store.hydrateFromRemote,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suppliers (${store.suppliers.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            if (store.suppliers.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No suppliers registered for this site yet.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)))
            else
              ...store.suppliers.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(s.category, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        if (s.phone.isNotEmpty) Text(s.phone, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )),
            const SizedBox(height: 20),
            Text('Payment Requests (${store.supplierPayments.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            if (store.supplierPayments.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No supplier payment requests yet.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)))
            else
              ...store.supplierPayments.map((p) => _paymentTile(context, p)),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(BuildContext context, SupplierPayment p) {
    final color = p.status == 'approved'
        ? AppTheme.success
        : p.status == 'rejected'
            ? AppTheme.danger
            : AppTheme.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 0.8), boxShadow: AppTheme.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${p.supplierName} · ₹${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(p.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Method: ${p.mode.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          if (p.status == 'pending') ...[
            const SizedBox(height: 10),
            _approveRejectRow(
              onApprove: () => context.read<AppStore>().reviewSupplierPayment(p.id, 'approved'),
              onReject: () => context.read<AppStore>().reviewSupplierPayment(p.id, 'rejected'),
            ),
          ],
        ],
      ),
    );
  }
}
