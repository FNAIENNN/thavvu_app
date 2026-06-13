import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'overview_screen.dart';
import 'machines_entry_screen_.dart';
import 'daily_data_screen.dart';
import 'attendance_screen.dart';
import 'stock_inventory_screen.dart';
import 'internal_transfer_screen.dart';
import 'rental_screen.dart';
import 'cash_screen.dart';
import 'food_screen.dart';
import 'tasks_screen.dart';
import 'reports_screen.dart';
import 'maps_screen.dart';
import 'hod_tasks_screen.dart';
import 'other_screens.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _drawerAnimController;
  late Animation<double> _drawerFade;

  int _notificationCount = 3;

  // Thavvu IDs data - visible after login
  final Map<String, dynamic> _thavvuIds = {
    'supervisorId': 'THV-SUP-001',
    'siteId': 'THV-SITE-CHN-001',
    'hodId': 'THV-HOD-042',
    'companyRegId': 'THV-CIN-2024-001',
  };

  final Map<String, dynamic> _supervisorData = {
    'name': 'Rajesh Kumar',
    'empId': 'EMP-001',
    'role': 'Senior Supervisor',
    'site': 'Site A – Chennai North',
    'phone': '+91 98765 43210',
    'email': 'rajesh@thavvu.com',
    'joinDate': '12 Jan 2022',
    'tasksCompleted': 142,
    'reportsGenerated': 38,
    'attendancePct': '94%',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _drawerAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _drawerFade =
        CurvedAnimation(parent: _drawerAnimController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _drawerAnimController.dispose();
    super.dispose();
  }

  void _openDrawer() {
    _drawerAnimController.forward();
    _scaffoldKey.currentState?.openDrawer();
  }

  // ── Navigation helpers ───────────────────────────────────────────────────

  void _pushScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Called by OverviewScreen quick actions and module grid.
  void _handleQuickNav(int index) {
    switch (index) {
      case 1:
        _pushScreen(const MachinesEntryScreen(isHOD: false));
        break;
      case 2:
        _pushScreen(const DailyDataScreen());
        break;
      case 3:
        _pushScreen(const AttendanceScreen());
        break;
      default:
        break;
    }
  }

  void _handleModuleRoute(String route) {
    switch (route) {
      case '/stock':
        _pushScreen(const StockInventoryScreen());
        break;
      case '/transfers':
        _pushScreen(const InternalTransferScreen());
        break;
      case '/rental':
        _pushScreen(const RentalScreen());
        break;
      case '/cash':
        _pushScreen(const CashScreen());
        break;
      case '/food':
        _pushScreen(const FoodScreen());
        break;
      case '/tasks':
        _pushScreen(const TasksScreen());
        break;
      case '/reports':
        _pushScreen(const ReportsScreen());
        break;
      case '/maps':
        _pushScreen(const MapsScreen());
        break;
      case '/hodtasks':
        _pushScreen(const HODTasksScreen());
        break;
      case '/others':
        _pushScreen(const OthersScreen());
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F6FC),
      drawer: _buildSideDrawer(),
      appBar: _buildAppBar(),
      body: OverviewScreen(
        onNavigate: _handleQuickNav,
        onNavigateModule: _handleModuleRoute,
      ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F3460),
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      leadingWidth: 56,
      leading: GestureDetector(
        onTap: _openDrawer,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Text('👷', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ),
      ),
      title: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
                text: 'Thavvu ',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            TextSpan(
                text: 'Supervisor',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF4FC3F7))),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        // Thavvu ID badge - visible after login
        GestureDetector(
          onTap: () => _showThavvuIdsSheet(context),
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _thavvuIds['supervisorId'],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Notification bell
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 24),
              onPressed: () => _showNotificationsPanel(context),
              tooltip: 'Notifications',
            ),
            if (_notificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF0F3460), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_notificationCount',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),

        // Profile icon — clean circular avatar with initials
        GestureDetector(
          onTap: () => _showProfileSheet(context),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _supervisorData['name']
                  .toString()
                  .split(' ')
                  .map((e) => e[0])
                  .take(2)
                  .join(),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── THAVVU IDs SHEET ─────────────────────────────────────────────────────
  void _showThavvuIdsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F6FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.verified_user,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thavvu IDs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A1628),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your organization identification numbers',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildIdCard(
              'Supervisor ID',
              _thavvuIds['supervisorId'],
              Icons.badge,
              const Color(0xFF1976D2),
            ),
            const SizedBox(height: 10),
            _buildIdCard(
              'Site ID',
              _thavvuIds['siteId'],
              Icons.location_city,
              const Color(0xFF0FA37A),
            ),
            const SizedBox(height: 10),
            _buildIdCard(
              'HOD ID',
              _thavvuIds['hodId'],
              Icons.admin_panel_settings,
              const Color(0xFF9C27B0),
            ),
            const SizedBox(height: 10),
            _buildIdCard(
              'Company Reg ID',
              _thavvuIds['companyRegId'],
              Icons.business,
              const Color(0xFFE6A817),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1976D2).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF1976D2)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These IDs are automatically assigned by HOD and cannot be modified.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF1976D2)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIdCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied!'),
                  backgroundColor: color,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.copy, size: 16, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ── SIDE DRAWER ──────────────────────────────────────────────────────────
  Widget _buildSideDrawer() {
    return Drawer(
      width: 280,
      backgroundColor: const Color(0xFF0A1628),
      child: SafeArea(
        child: FadeTransition(
          opacity: _drawerFade,
          child: Column(
            children: [
              _buildDrawerHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildDrawerSection('Main'),
                    _buildDrawerPushTile(
                        'Machine Entry',
                        Icons.construction_rounded,
                        () => _pushScreen(const MachinesEntryScreen(isHOD: false))),
                    _buildDrawerPushTile(
                        'Daily Data',
                        Icons.edit_calendar_rounded,
                        () => _pushScreen(const DailyDataScreen())),
                    _buildDrawerPushTile(
                        'Attendance',
                        Icons.fingerprint_rounded,
                        () => _pushScreen(const AttendanceScreen())),
                    const SizedBox(height: 8),
                    _buildDrawerSection('Modules'),
                    _buildDrawerModuleTile(
                        Icons.map_outlined,
                        'Maps & Specs',
                        () => _pushScreen(const MapsScreen()),
                        const Color(0xFF1976D2)),
                    _buildDrawerModuleTile(
                        Icons.assignment_outlined,
                        'HOD Tasks',
                        () => _pushScreen(const HODTasksScreen()),
                        const Color(0xFF0FA37A)),
                    _buildDrawerModuleTile(
                        Icons.inventory_2_outlined,
                        'Stock Inventory',
                        () => _pushScreen(const StockInventoryScreen()),
                        const Color(0xFFE6A817)),
                    _buildDrawerModuleTile(
                        Icons.swap_horiz_rounded,
                        'Internal Transfers',
                        () => _pushScreen(const InternalTransferScreen()),
                        const Color(0xFF1976D2)),
                    _buildDrawerModuleTile(
                        Icons.key_outlined,
                        'Rental',
                        () => _pushScreen(const RentalScreen()),
                        const Color(0xFFE53935)),
                    _buildDrawerModuleTile(
                        Icons.task_alt_outlined,
                        'Tasks & Checklist',
                        () => _pushScreen(const TasksScreen()),
                        const Color(0xFF0FA37A)),
                    _buildDrawerModuleTile(
                        Icons.bar_chart_rounded,
                        'Reports',
                        () => _pushScreen(const ReportsScreen()),
                        const Color(0xFF9C27B0)),
                    _buildDrawerModuleTile(
                        Icons.more_horiz,
                        'Others',
                        () => _pushScreen(const OthersScreen()),
                        const Color(0xFF795548)),
                    // Thavvu IDs shortcut in drawer
                    const SizedBox(height: 8),
                    _buildDrawerSection('Account'),
                    _buildDrawerThavvuIdTile(),
                  ],
                ),
              ),
              _buildDrawerFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerThavvuIdTile() {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showThavvuIdsSheet(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF1976D2).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.verified_user,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thavvu IDs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF90CAF9),
                    ),
                  ),
                  Text(
                    _thavvuIds['supervisorId'],
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: Color(0xFF64B5F6)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('👷', style: TextStyle(fontSize: 26)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _supervisorData['name'],
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    Text(
                      _thavvuIds['supervisorId'],
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 11, color: Colors.white70),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _supervisorData['site'],
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0FA37A).withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF0FA37A).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 7, color: Color(0xFF66BB6A)),
                const SizedBox(width: 5),
                Text(
                  _supervisorData['role'],
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF66BB6A),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.3),
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildDrawerPushTile(
      String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white54),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerModuleTile(
      IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white60),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 16, color: Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _confirmLogout(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFE53935).withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded,
                      size: 18, color: Color(0xFFEF9A9A)),
                  SizedBox(width: 12),
                  Text(
                    'Log Out',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF9A9A)),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFFEF9A9A)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── NOTIFICATIONS PANEL ──────────────────────────────────────────────────
  void _showNotificationsPanel(BuildContext context) {
    final notifications = [
      {
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF0FA37A),
        'title': 'Task Completed',
        'body': 'Machine M-004 daily log submitted',
        'time': '2 min ago',
        'read': false,
      },
      {
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFE6A817),
        'title': 'Low Diesel Alert',
        'body': 'Batch D-012 below 20% threshold',
        'time': '1 hr ago',
        'read': false,
      },
      {
        'icon': Icons.person_add_rounded,
        'color': const Color(0xFF1976D2),
        'title': 'New Worker Added',
        'body': 'Karthik Kumar registered to Site A',
        'time': '3 hrs ago',
        'read': false,
      },
      {
        'icon': Icons.description_outlined,
        'color': const Color(0xFF9C27B0),
        'title': 'Report Ready',
        'body': 'Monthly machines summary available',
        'time': 'Yesterday',
        'read': true,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F6FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notifications',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A1628))),
                  TextButton(
                    onPressed: () {
                      setState(() => _notificationCount = 0);
                      Navigator.pop(context);
                    },
                    child: const Text('Mark all read',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF1976D2))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = notifications[i];
                  final isUnread = !(n['read'] as bool);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUnread
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isUnread
                              ? (n['color'] as Color).withOpacity(0.2)
                              : Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                (n['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(n['icon'] as IconData,
                              size: 20, color: n['color'] as Color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(n['title'] as String,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0A1628))),
                                  Text(n['time'] as String,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(n['body'] as String,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF555555))),
                            ],
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: n['color'] as Color,
                                shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── PROFILE SHEET ────────────────────────────────────────────────────────
  void _showProfileSheet(BuildContext context) {
    final initials = _supervisorData['name']
        .toString()
        .split(' ')
        .map((e) => e[0])
        .take(2)
        .join();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F6FC),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Profile hero
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F3460), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF1976D2).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _supervisorData['name'],
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _thavvuIds['supervisorId'],
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _supervisorData['role'],
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.65)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _profileBadge(
                            Icons.badge, _supervisorData['empId']),
                        const SizedBox(width: 8),
                        _profileBadge(Icons.location_on, 'Site A'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _profileStatBox(
                      'Tasks Done',
                      '${_supervisorData['tasksCompleted']}',
                      Icons.task_alt,
                      const Color(0xFF0FA37A)),
                  const SizedBox(width: 10),
                  _profileStatBox(
                      'Reports',
                      '${_supervisorData['reportsGenerated']}',
                      Icons.bar_chart,
                      const Color(0xFF1976D2)),
                  const SizedBox(width: 10),
                  _profileStatBox(
                      'Attendance',
                      _supervisorData['attendancePct'],
                      Icons.fingerprint,
                      const Color(0xFF9C27B0)),
                ],
              ),
              const SizedBox(height: 16),
              // Thavvu IDs in profile
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E4F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_user,
                            size: 16, color: Color(0xFF1976D2)),
                        SizedBox(width: 8),
                        Text(
                          'Thavvu IDs',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A1628),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _profileIdMini(
                              'Supervisor',
                              _thavvuIds['supervisorId'],
                              const Color(0xFF1976D2)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _profileIdMini(
                              'Site',
                              _thavvuIds['siteId'],
                              const Color(0xFF0FA37A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _profileIdMini(
                              'HOD',
                              _thavvuIds['hodId'],
                              const Color(0xFF9C27B0)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _profileIdMini(
                              'Company',
                              _thavvuIds['companyRegId'],
                              const Color(0xFFE6A817)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _profileInfoTile(
                  Icons.phone_outlined, 'Phone', _supervisorData['phone']),
              _profileInfoTile(
                  Icons.mail_outline, 'Email', _supervisorData['email']),
              _profileInfoTile(Icons.calendar_today_outlined, 'Joined',
                  _supervisorData['joinDate']),
              _profileInfoTile(Icons.location_city_outlined, 'Site',
                  _supervisorData['site']),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE0E4F0)),
              const SizedBox(height: 8),
              _profileActionTile(Icons.edit_outlined, 'Edit Profile',
                  const Color(0xFF1976D2), () {}),
              _profileActionTile(Icons.lock_outline, 'Change Password',
                  const Color(0xFF9C27B0), () {}),
              _profileActionTile(Icons.support_agent_outlined, 'Contact HOD',
                  const Color(0xFF0FA37A), () {}),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFFE0E4F0)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _confirmLogout(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            const Color(0xFFEF9A9A).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          size: 20, color: Color(0xFFE53935)),
                      SizedBox(width: 14),
                      Text('Log Out',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE53935))),
                      Spacer(),
                      Icon(Icons.chevron_right,
                          size: 18, color: Color(0xFFE53935)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileIdMini(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _profileBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _profileStatBox(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _profileInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A1628))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileActionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9)),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A1628))),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 16, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  // ── LOGOUT ───────────────────────────────────────────────────────────────
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
            SizedBox(width: 10),
            Text('Log Out',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of Thavvu Supervisor?',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}