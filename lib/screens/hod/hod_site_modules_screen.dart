import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'modules/hod_attendance_screen.dart';
import 'modules/hod_cash_screen.dart';
import 'modules/hod_daily_data_screen.dart';
import 'modules/hod_food_screen.dart';
import 'modules/hod_maps_screen.dart';
import 'modules/hod_machines_entry_screen.dart';
import 'modules/hod_other_screens.dart';
import 'modules/hod_rental_screen.dart';
import 'modules/hod_reports_screen.dart';
import 'modules/hod_stock_inventory_screen.dart';
import 'modules/hod_suppliers_screen.dart';
import 'modules/hod_tasks_screen.dart';

class HodModuleInfo {
  final String title;
  final String supervisorTitle;
  final String emoji;
  final IconData icon;
  final Color color;
  final Widget screen;

  const HodModuleInfo({
    required this.title,
    required this.supervisorTitle,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class HodSiteModulesScreen extends StatelessWidget {
  final String siteName;
  final String siteId;
  final String? thavvuPointName;
  final String? thavvuPointId;
  final String? assignedTo;
  final String? supervisorId;
  final Map<String, int> moduleAlertCounts;

  const HodSiteModulesScreen({
    super.key,
    required this.siteName,
    required this.siteId,
    this.thavvuPointName,
    this.thavvuPointId,
    this.assignedTo,
    this.supervisorId,
    this.moduleAlertCounts = const {},
  });

  static const List<HodModuleInfo> modules = [
    HodModuleInfo(
      title: 'Machines',
      supervisorTitle: 'Machine Entry',
      emoji: '🚜',
      icon: Icons.construction_rounded,
      color: Color(0xFFD97706),
      screen: HodMachinesEntryScreen(),
    ),
    HodModuleInfo(
      title: 'Daily Data',
      supervisorTitle: 'Daily Data',
      emoji: '📝',
      icon: Icons.edit_calendar_rounded,
      color: Color(0xFF1976D2),
      screen: HodDailyDataScreen(),
    ),
    HodModuleInfo(
      title: 'Attendance',
      supervisorTitle: 'Attendance',
      emoji: '👷',
      icon: Icons.fingerprint_rounded,
      color: Color(0xFF0FA37A),
      screen: const HodAttendanceScreen(
        title: 'Attendance',
        moduleFilter: 'Attendance',
      ),
    ),
    HodModuleInfo(
      title: 'Maps',
      supervisorTitle: 'Maps & Specs',
      emoji: '🗺️',
      icon: Icons.map_outlined,
      color: Color(0xFF1976D2),
      screen: HodMapsScreen(),
    ),
    HodModuleInfo(
      title: 'Stock',
      supervisorTitle: 'Stock Inventory',
      emoji: '📦',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFFE6A817),
      screen: HodStockInventoryScreen(),
    ),
    HodModuleInfo(
      title: 'Suppliers',
      supervisorTitle: 'Suppliers',
      emoji: '🏗️',
      icon: Icons.storefront_rounded,
      color: Color(0xFF2563EB),
      screen: HodSuppliersScreen(),
    ),
    HodModuleInfo(
      title: 'Rental',
      supervisorTitle: 'Rental',
      emoji: '🔑',
      icon: Icons.key_outlined,
      color: Color(0xFFE53935),
      screen: HodRentalScreen(),
    ),
    HodModuleInfo(
      title: 'Cash',
      supervisorTitle: 'Cash',
      emoji: '💰',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF0FA37A),
      screen: HodCashScreen(),
    ),
    HodModuleInfo(
      title: 'Food',
      supervisorTitle: 'Food',
      emoji: '🍱',
      icon: Icons.restaurant_menu_outlined,
      color: Color(0xFFE6A817),
      screen: HodFoodScreen(),
    ),
    HodModuleInfo(
      title: 'Tasks',
      supervisorTitle: 'Tasks & Checklist',
      emoji: '✅',
      icon: Icons.task_alt_outlined,
      color: Color(0xFF0FA37A),
      screen: HodTasksScreen(),
    ),
    HodModuleInfo(
      title: 'Reports',
      supervisorTitle: 'Reports',
      emoji: '📈',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF9C27B0),
      screen: HodReportsScreen(),
    ),
    HodModuleInfo(
      title: 'Other',
      supervisorTitle: 'Others',
      emoji: '⚙️',
      icon: Icons.more_horiz,
      color: Color(0xFF795548),
      screen: HodOtherScreens(),
    ),
  ];

  int _alertCountFor(HodModuleInfo module) {
    return moduleAlertCounts[module.title] ??
        moduleAlertCounts[module.supervisorTitle] ??
        0;
  }

  Widget _screenFor(HodModuleInfo module) {
    final hodId = _resolveHodId();
    final pointId = thavvuPointId;
    final supervisor = supervisorId ?? assignedTo;
    final Widget child;
    switch (module.title) {
      case 'Machines':
        child = HodMachinesEntryScreen(
          siteId: siteId,
          siteName: siteName,
          thavvuPointId: pointId,
          supervisorId: supervisor ?? 'SUP-VJA-001',
          hodId: hodId,
        );
        break;
      case 'Daily Data':
        child = HodDailyDataScreen(
          siteId: siteId,
          siteName: siteName,
          thavvuPointId: pointId,
          supervisorId: supervisor ?? 'SUP-VJA-001',
          supervisorName: assignedTo ?? supervisor ?? 'Supervisor',
          hodId: hodId,
        );
        break;
      case 'Attendance':
        child = HodAttendanceScreen(
          title: '$siteName Attendance',
          moduleFilter: 'Attendance',
        );
        break;
      default:
        child = module.screen;
    }

    return _HodSelectedContextWrapper(
      siteName: siteName,
      siteId: siteId,
      thavvuPointName: thavvuPointName,
      thavvuPointId: thavvuPointId,
      assignedTo: assignedTo,
      child: child,
    );
  }

  /// The authenticated HOD's profiles.id UUID when signed in (the value the
  /// DB UUID FKs expect); falls back to the display id for offline/dev.
  String _resolveHodId() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) return user.id;
    } catch (_) {
      // Supabase not initialized (widget tests / early startup).
    }
    return 'HOD-001';
  }

  @override
  Widget build(BuildContext context) {
    final totalAlerts =
        moduleAlertCounts.values.fold<int>(0, (sum, count) => sum + count);
    final pointTitle = thavvuPointName ?? 'Site-level modules';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: Text(pointTitle),
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
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
                  color: const Color(0xFF0F3460).withValues(alpha: 0.16),
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
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.account_tree_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pointTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$siteName · $siteId',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (thavvuPointId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Thavvu ID: $thavvuPointId',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (assignedTo != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Assigned to $assignedTo',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
                if (totalAlerts > 0) _NotificationBadge(count: totalAlerts),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'HOD Modules',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Classic module desk arranged in supervisor order.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];
              final count = _alertCountFor(module);
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _screenFor(module)),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E4F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.035),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(module.emoji,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 5),
                          Icon(module.icon, color: module.color, size: 18),
                          const SizedBox(height: 5),
                          Text(
                            module.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: _NotificationBadge(count: count),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HodSelectedContextWrapper extends StatelessWidget {
  final String siteName;
  final String siteId;
  final String? thavvuPointName;
  final String? thavvuPointId;
  final String? assignedTo;
  final Widget child;

  const _HodSelectedContextWrapper({
    required this.siteName,
    required this.siteId,
    required this.thavvuPointName,
    required this.thavvuPointId,
    required this.assignedTo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final pointLabel = thavvuPointId == null
        ? 'Site-level modules'
        : '${thavvuPointName ?? 'Selected Thavvu Point'} • $thavvuPointId';
    return Column(
      children: [
        Material(
          color: const Color(0xFF0F3460),
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_rounded,
                      color: Color(0xFFE0F2FE), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: $pointLabel  •  $siteName ($siteId)'
                      '${assignedTo == null ? '' : '  •  $assignedTo'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final int count;

  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
