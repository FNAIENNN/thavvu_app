import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('App Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _row('Name', user?.name ?? '—'),
                _row('Email', user?.email ?? '—'),
                _row('Employee ID', user?.empId ?? '—'),
                _row('Site', user?.site ?? '—'),
                _row('Role', user?.role ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Local Backend / Approvals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Pending machines: ${store.pendingMachines.length} · Pending orders: ${store.stockOrders.where((o) => o.status == 'pending').length} · Pending users: ${store.users.where((u) => !u.approved).length}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await store.approveAllPendingMachines();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All pending machines approved'), backgroundColor: AppTheme.success),
                      );
                    }
                  },
                  icon: const Icon(Icons.construction, size: 18),
                  label: const Text('Approve Pending Machines'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await store.approveAllPendingOrders();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pending stock orders approved & inventory updated'), backgroundColor: AppTheme.success),
                      );
                    }
                  },
                  icon: const Icon(Icons.inventory_2, size: 18),
                  label: const Text('Approve Pending Stock Orders'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    for (final r in store.stockReturns.where((r) => r.status == 'pending').toList()) {
                      await store.approveStockReturn(r.id);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pending returns approved'), backgroundColor: AppTheme.success),
                      );
                    }
                  },
                  icon: const Icon(Icons.assignment_return, size: 18),
                  label: const Text('Approve Pending Returns'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await store.approvePendingUsers();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pending user accounts approved'), backgroundColor: AppTheme.success),
                      );
                    }
                  },
                  icon: const Icon(Icons.how_to_reg, size: 18),
                  label: const Text('Approve Pending Users'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Reset Demo Data?'),
                        content: const Text('This clears local data and restores seed records.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.resetDemoData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Demo data restored'), backgroundColor: AppTheme.info),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Reset Demo Data'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Thavvu Supervisor v1.0.0', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text(
                  'Demo credentials: rajesh@thavvu.com / password',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
