import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/overview_screen.dart';
import 'screens/machines_entry_screen.dart';
import 'screens/daily_data_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/stock_inventory_screen.dart';
// Use your actual Internal Transfer screen filename
import 'screens/internal_transfer_screen.dart';
import 'screens/rental_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/reports_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const ThavvuApp());
}

class ThavvuApp extends StatelessWidget {
  const ThavvuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thavvu Supervisor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const RootScreen(),
        '/stock': (context) => const StockInventoryScreen(),
        '/transfers': (context) => const InternalTransferScreen(), // Your working screen
        '/rental': (context) => const RentalScreen(),
        '/tasks': (context) => const TasksScreen(),
        '/reports': (context) => const ReportsScreen(),
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _navigateToModule(String route) {
    Navigator.pushNamed(context, route);
  }

  static const List<_NavItem> _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Home'),
    _NavItem(Icons.construction_outlined, Icons.construction, 'Machines'),
    _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Daily'),
    _NavItem(Icons.badge_outlined, Icons.badge, 'Attend.'),
    _NavItem(Icons.more_horiz, Icons.more_horiz, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = [
      'Thavvu Supervisor',
      'New Machines Entry',
      'Daily Machines Data',
      'Attendance',
      'More Modules',
    ];
    final subtitles = [
      'Supervisor workflow portal',
      'Register new machine',
      'Log daily activity',
      'Mark worker attendance',
      'All modules',
    ];

    final safeIndex = _currentIndex.clamp(0, titles.length - 1);

    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.surfaceCard,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titles[safeIndex],
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          Text(
            subtitles[safeIndex],
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        if (_currentIndex == 0)
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppTheme.textSecondary),
            onPressed: () {},
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'SV',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return OverviewScreen(
          onNavigate: _navigateTo,
          onNavigateModule: _navigateToModule,
        );
      case 1:
        return const MachinesEntryScreen();
      case 2:
        return const DailyDataScreen();
      case 3:
        return const AttendanceScreen();
      case 4:
        return _MoreScreen(onNavigateModule: _navigateToModule);
      default:
        return OverviewScreen(
          onNavigate: _navigateTo,
          onNavigateModule: _navigateToModule,
        );
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.8)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: _navItems.asMap().entries.map((e) {
              final int i = e.key;
              final _NavItem item = e.value;
              final bool selected = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _currentIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                          ),
                        ),
                        if (selected)
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 20,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── MORE SCREEN ──────────────────────────────────────────────────────────────
class _MoreScreen extends StatelessWidget {
  final Function(String) onNavigateModule;

  const _MoreScreen({required this.onNavigateModule});

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'emoji': '📦',
        'title': 'Stock Inventory',
        'subtitle': 'Orders · Returns · Levels',
        'color': AppTheme.warning,
        'route': '/stock'
      },
      {
        'emoji': '🔄',
        'title': 'Internal Transfers',
        'subtitle': 'Point-to-point stock',
        'color': AppTheme.info,
        'route': '/transfers'
      },
      {
        'emoji': '🔑',
        'title': 'Rental',
        'subtitle': 'Equipment hire tracking',
        'color': AppTheme.danger,
        'route': '/rental'
      },
      {
        'emoji': '✅',
        'title': 'Tasks & Checklist',
        'subtitle': 'HOD-assigned · Daily/Weekly',
        'color': AppTheme.success,
        'route': '/tasks'
      },
      {
        'emoji': '📊',
        'title': 'Reports',
        'subtitle': 'Auto-generated · 7 types',
        'color': AppTheme.primary,
        'route': '/reports'
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Additional Modules',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 14),
          ...items.map((item) => GestureDetector(
                onTap: () => onNavigateModule(item['route'] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(item['emoji'] as String,
                            style: const TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['subtitle'] as String,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
