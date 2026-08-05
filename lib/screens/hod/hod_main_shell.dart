import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../login_screen.dart';
import '../hod_module_review_screen.dart';
import '../registry/registry_hub_screen.dart';
import 'hod_alerts_screen.dart';
import 'hod_read_only_overview_screen.dart';
import 'hod_sites_screen.dart';
import 'modules/hod_attendance_screen.dart';
import 'modules/hod_cash_screen.dart';
import 'modules/hod_daily_data_screen.dart';
import 'modules/hod_food_screen.dart';
import 'modules/hod_gin_approvals_screen.dart';
import 'modules/hod_registration_approvals_screen.dart';
import 'modules/hod_maps_screen.dart';
import 'modules/hod_machines_entry_screen.dart';
import 'modules/hod_rental_screen.dart';
import 'modules/hod_reports_screen.dart';
import 'modules/hod_stock_inventory_screen.dart';
import 'modules/hod_suppliers_screen.dart';
import 'modules/hod_tasks_screen.dart';
import 'modules/hod_transfers_screen.dart';
import 'modules/hod_internal_transfer_screen.dart';

class HodMainShell extends StatefulWidget {
  const HodMainShell({super.key});

  @override
  State<HodMainShell> createState() => _HodMainShellState();
}

class _HodMainShellState extends State<HodMainShell>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();

  late final AnimationController _drawerAnimController;
  late final Animation<double> _drawerFade;

  int _notificationCount = 5;
  int _selectedBottomIndex = 0;
  bool _isNavigating = false;

  Map<String, String> _userData = const {};

  // HOD IDs data - visible after HOD login.
  final Map<String, dynamic> _thavvuIds = {
    'hodId': 'THV-HOD-042',
    'workspaceId': 'THV-HOD-WORKSPACE-001',
    'primarySiteId': 'ALL-SITES',
    'approvalDeskId': 'THV-APR-HOD-001',
    'companyRegId': 'THV-CIN-2024-001',
  };

  final Map<String, dynamic> _hodData = {
    'name': 'HOD Admin',
    'empId': 'HOD-001',
    'role': 'Head of Department',
    'site': 'All Sites & Thavvu Points',
    'phone': '+91 98765 43210',
    'email': 'hod@thavvu.com',
    'joinDate': '12 Jan 2022',
    'tasksReviewed': 248,
    'reportsReviewed': 64,
    'approvalPct': '91%',
  };

  String get _displayName {
    final storedName = _userData['name']?.trim();
    if (storedName != null && storedName.isNotEmpty) return storedName;
    return _hodData['name'].toString();
  }

  String get _displayEmpId {
    final storedEmpId = _userData['empId']?.trim();
    if (storedEmpId != null && storedEmpId.isNotEmpty) return storedEmpId;
    return _hodData['empId'].toString();
  }

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
    _drawerFade = CurvedAnimation(
      parent: _drawerAnimController,
      curve: Curves.easeOut,
    );
    unawaited(_loadUserData());
  }

  Future<void> _loadUserData() async {
    final data = await AuthService.getUserData();
    var merged = Map<String, String>.from(data);
    // Overlay the REAL profile (session user) so the HOD workspace shows the
    // logged-in account's credentials, not demo defaults.
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final rows = await Supabase.instance.client
            .from('profiles')
            .select('emp_id, full_name, email, phone, role')
            .eq('id', user.id)
            .limit(1);
        if (rows.isNotEmpty) {
          final p = Map<String, dynamic>.from(rows.first);
          merged = {
            ...data,
            if (p['full_name']?.toString().trim().isNotEmpty ?? false)
              'name': p['full_name']!.toString(),
            if (p['emp_id']?.toString().trim().isNotEmpty ?? false)
              'empId': p['emp_id']!.toString(),
            if (p['email']?.toString().trim().isNotEmpty ?? false)
              'email': p['email']!.toString(),
            if (p['phone']?.toString().trim().isNotEmpty ?? false)
              'phone': p['phone']!.toString(),
            if (p['role']?.toString().trim().isNotEmpty ?? false)
              'role': p['role']!.toString(),
          };
        }
      }
    } catch (_) {
      // Offline / RLS failure → keep prefs values; demo defaults still apply.
    }
    if (!mounted) return;
    setState(() => _userData = merged);
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

  Future<void> _pushScreen(Widget screen) async {
    if (_isNavigating || !mounted) return;

    final navigator = _contentNavigatorKey.currentState;
    if (navigator == null) return;

    setState(() => _isNavigating = true);
    try {
      await navigator.push(
        MaterialPageRoute(builder: (_) => screen),
      );
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      } else {
        _isNavigating = false;
      }
    }
  }

  Widget _buildHomeTab() {
    return HodReadOnlyOverviewScreen(
      onNavigateModule: _handleModuleRoute,
      onOpenAlerts: () => _selectBottomNav(2),
      onOpenSites: () => _selectBottomNav(1),
    );
  }

  Widget _bottomTabPage(int index) {
    switch (index) {
      case 1:
        return const HodSitesScreen();
      case 2:
        return const HodAlertsScreen();
      case 3:
        return _buildProfileTabPage();
      case 0:
      default:
        return _buildHomeTab();
    }
  }

  void _selectBottomNav(int index) {
    if (!mounted) return;

    setState(() => _selectedBottomIndex = index);

    _contentNavigatorKey.currentState?.pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _bottomTabPage(index),
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (_) => false,
    );
  }

  /// Called by HOD overview shortcuts, drawer items, and shell navigation.
  void _handleModuleRoute(String route) {
    switch (route) {
      case '/machines':
        unawaited(_pushScreen(const HodMachinesEntryScreen()));
        break;
      case '/daily':
        unawaited(_pushScreen(const HodDailyDataScreen()));
        break;
      case '/attendance':
        unawaited(_pushScreen(const HodAttendanceScreen(
          title: 'HOD Attendance',
          moduleFilter: 'Attendance',
        )));
        break;
      case '/stock':
        unawaited(_pushScreen(const HodStockInventoryScreen()));
        break;
      case '/gin-approvals':
        unawaited(_pushScreen(const HodGinApprovalsScreen()));
        break;
      case '/registrations':
        unawaited(_pushScreen(const HodRegistrationApprovalsScreen()));
        break;
      case '/suppliers':
        unawaited(_pushScreen(const HodSuppliersScreen()));
        break;
      case '/rental':
        unawaited(_pushScreen(const HodRentalScreen()));
        break;
      case '/cash':
        unawaited(_pushScreen(const HodCashScreen()));
        break;
      case '/food':
        unawaited(_pushScreen(const HodFoodScreen()));
        break;
      case '/tasks':
        unawaited(_pushScreen(const HodTasksScreen()));
        break;
      case '/reports':
        unawaited(_pushScreen(const HodReportsScreen()));
        break;
      case '/transfers':
        unawaited(_pushScreen(const HodTransfersScreen()));
        break;
      case '/registry':
        unawaited(_pushScreen(const RegistryHubScreen()));
        break;
      case '/internal-transfer':
        unawaited(_pushScreen(const HodInternalTransferScreen()));
        break;
      case '/maps':
        unawaited(_pushScreen(const HodMapsScreen()));
        break;
      case '/sites':
        _selectBottomNav(1);
        break;
      case '/alerts':
        _selectBottomNav(2);
        break;
      case '/others':
        unawaited(_pushScreen(const HodModuleReviewScreen(
          title: 'HOD Others',
          moduleFilter: 'Others',
          actorId: 'HOD-001',
        )));
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final navigator = _contentNavigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return false;
        }
        if (_selectedBottomIndex != 0) {
          _selectBottomNav(0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF4F6FC),
        drawer: _buildSideDrawer(),
        appBar: _buildAppBar(),
        body: Navigator(
          key: _contentNavigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => _buildHomeTab(),
          ),
        ),
        bottomNavigationBar: _buildMinimalBottomNav(),
      ),
    );
  }

  Widget _buildMinimalBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F3460).withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _bottomNavButton(
              index: 0,
              icon: Icons.home_rounded,
              label: 'Home',
              color: const Color(0xFF1976D2),
            ),
            _bottomNavButton(
              index: 1,
              icon: Icons.apartment_rounded,
              label: 'Sites',
              color: const Color(0xFF0FA37A),
            ),
            _bottomNavButton(
              index: 2,
              icon: Icons.notifications_active_rounded,
              label: 'Alerts',
              color: const Color(0xFFE6A817),
            ),
            _bottomNavButton(
              index: 3,
              icon: Icons.person_rounded,
              label: 'Profile',
              color: const Color(0xFF9C27B0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavButton({
    required int index,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final selected = _selectedBottomIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectBottomNav(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 31 : 28,
                height: selected ? 31 : 28,
                decoration: BoxDecoration(
                  color: selected ? color : color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: selected ? 17 : 16,
                  color: selected ? Colors.white : color,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected
                    ? Padding(
                        key: ValueKey(label),
                        padding: const EdgeInsets.only(left: 7),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
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
                errorBuilder: (_, __, ___) => const Text(
                  '🛡️',
                  style: TextStyle(fontSize: 20),
                ),
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
                color: Colors.white,
              ),
            ),
            TextSpan(
              text: 'HOD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: Color(0xFF4FC3F7),
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        // HOD ID badge - visible after login.
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
                  _displayEmpId,
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

        // Notification bell.
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => _showNotificationsPanel(context),
              tooltip: 'HOD Notifications',
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
                      color: const Color(0xFF0F3460),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_notificationCount',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Profile icon — clean circular avatar with initials.
        GestureDetector(
          onTap: () => _selectBottomNav(3),
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
              _initials(_displayName),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'HD';
    return parts.map((part) => part[0].toUpperCase()).take(2).join();
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
                  borderRadius: BorderRadius.circular(2),
                ),
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
                  child: const Icon(
                    Icons.verified_user,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HOD Thavvu IDs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A1628),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Department and approval workspace identifiers',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildIdCard(
              'HOD ID',
              _displayEmpId,
              Icons.admin_panel_settings,
              const Color(0xFF1976D2),
            ),
            const SizedBox(height: 10),
            _buildIdCard(
              'Workspace ID',
              _thavvuIds['workspaceId'].toString(),
              Icons.dashboard_customize,
              const Color(0xFF0FA37A),
            ),
            const SizedBox(height: 10),
            _buildIdCard(
              'Sites Scope',
              _thavvuIds['primarySiteId'].toString(),
              Icons.location_city,
              const Color(0xFF9C27B0),
            ),
            const SizedBox(height: 10),
            _buildIdCard(
              'Approval Desk ID',
              _thavvuIds['approvalDeskId'].toString(),
              Icons.verified,
              const Color(0xFFE6A817),
            ),
            const SizedBox(height: 10),
            _buildIdCard(
              'Company Reg ID',
              _thavvuIds['companyRegId'].toString(),
              Icons.business,
              const Color(0xFFE53935),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1976D2).withOpacity(0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF1976D2)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These HOD IDs are used for module approvals, finance requests, and site-level review tracking.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1976D2)),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                      'HOD Alerts',
                      Icons.notifications_active_rounded,
                      () => _handleModuleRoute('/alerts'),
                    ),
                    _buildDrawerPushTile(
                      'Sites & Thavvu Points',
                      Icons.apartment_rounded,
                      () => _handleModuleRoute('/sites'),
                    ),
                    _buildDrawerPushTile(
                      'Machine Entry',
                      Icons.construction_rounded,
                      () => _handleModuleRoute('/machines'),
                    ),
                    _buildDrawerPushTile(
                      'Daily Data',
                      Icons.edit_calendar_rounded,
                      () => _handleModuleRoute('/daily'),
                    ),
                    _buildDrawerPushTile(
                      'Attendance',
                      Icons.fingerprint_rounded,
                      () => _handleModuleRoute('/attendance'),
                    ),
                    const SizedBox(height: 8),
                    _buildDrawerSection('Modules'),
                    _buildDrawerModuleTile(
                      Icons.map_outlined,
                      'Maps & Specs',
                      () => _handleModuleRoute('/maps'),
                      const Color(0xFF1976D2),
                    ),
                    _buildDrawerModuleTile(
                      Icons.inventory_2_outlined,
                      'Stock Inventory',
                      () => _handleModuleRoute('/stock'),
                      const Color(0xFFE6A817),
                    ),
                    _buildDrawerModuleTile(
                      Icons.fact_check_outlined,
                      'GIN Approvals',
                      () => _handleModuleRoute('/gin-approvals'),
                      const Color(0xFF00897B),
                    ),
                    _buildDrawerModuleTile(
                      Icons.badge_outlined,
                      'Supervisor Registrations',
                      () => _handleModuleRoute('/registrations'),
                      const Color(0xFF6A1B9A),
                    ),
                    _buildDrawerModuleTile(
                      Icons.storefront_rounded,
                      'Suppliers',
                      () => _handleModuleRoute('/suppliers'),
                      const Color(0xFF2563EB),
                    ),
                    _buildDrawerModuleTile(
                      Icons.tune_rounded,
                      'Manage Data',
                      () => _handleModuleRoute('/registry'),
                      const Color(0xFF6D4C41),
                    ),
                    _buildDrawerModuleTile(
                      Icons.key_outlined,
                      'Rental',
                      () => _handleModuleRoute('/rental'),
                      const Color(0xFFE53935),
                    ),
                    _buildDrawerModuleTile(
                      Icons.account_balance_wallet_outlined,
                      'Cash',
                      () => _handleModuleRoute('/cash'),
                      const Color(0xFF0FA37A),
                    ),
                    _buildDrawerModuleTile(
                      Icons.restaurant_menu_outlined,
                      'Food',
                      () => _handleModuleRoute('/food'),
                      const Color(0xFFE6A817),
                    ),
                    _buildDrawerModuleTile(
                      Icons.task_alt_outlined,
                      'Tasks & Checklist',
                      () => _handleModuleRoute('/tasks'),
                      const Color(0xFF0FA37A),
                    ),
                    _buildDrawerModuleTile(
                      Icons.bar_chart_rounded,
                      'Reports',
                      () => _handleModuleRoute('/reports'),
                      const Color(0xFF9C27B0),
                    ),
                    _buildDrawerModuleTile(
                      Icons.swap_horiz_rounded,
                      'Transfers',
                      () => _handleModuleRoute('/transfers'),
                      const Color(0xFF00695C),
                    ),
                    _buildDrawerModuleTile(
                      Icons.repeat_rounded,
                      'Internal Transfer',
                      () => _handleModuleRoute('/internal-transfer'),
                      const Color(0xFF4527A0),
                    ),
                    _buildDrawerModuleTile(
                      Icons.more_horiz,
                      'Others',
                      () => _handleModuleRoute('/others'),
                      const Color(0xFF795548),
                    ),
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
          border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.2)),
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
              child: const Icon(
                Icons.verified_user,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HOD Thavvu IDs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF90CAF9),
                    ),
                  ),
                  Text(
                    _displayEmpId,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF64B5F6)),
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
                    errorBuilder: (_, __, ___) => const Text(
                      '🛡️',
                      style: TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _displayEmpId,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 0.5,
                      ),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 11, color: Colors.white70),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _hodData['site'].toString(),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
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
              border:
                  Border.all(color: const Color(0xFF0FA37A).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 7, color: Color(0xFF66BB6A)),
                const SizedBox(width: 5),
                Text(
                  _hodData['role'].toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF66BB6A),
                    fontWeight: FontWeight.w600,
                  ),
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
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerPushTile(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white54),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerModuleTile(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white60,
                ),
              ),
            ),
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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
                      color: Color(0xFFEF9A9A),
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: Color(0xFFEF9A9A)),
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
        'icon': Icons.verified_outlined,
        'color': const Color(0xFF1976D2),
        'title': 'Machine payment approval',
        'body': 'New machine advance request is waiting for HOD approval.',
        'time': '2 min ago',
        'read': false,
      },
      {
        'icon': Icons.fingerprint_rounded,
        'color': const Color(0xFF0FA37A),
        'title': 'Attendance review pending',
        'body': 'Check-in, check-out and outside-worker wage data need review.',
        'time': '3 hrs ago',
        'read': false,
      },
      {
        'icon': Icons.inventory_2_outlined,
        'color': const Color(0xFFE6A817),
        'title': 'Stock and return alert',
        'body':
            'Diesel low-stock, GIN, material returns and stock requests need review.',
        'time': 'Yesterday',
        'read': false,
      },
      {
        'icon': Icons.task_alt_outlined,
        'color': const Color(0xFF9C27B0),
        'title': 'Task checklist revision',
        'body':
            'A supervisor checklist was resubmitted after HOD revision request.',
        'time': 'Yesterday',
        'read': false,
      },
      {
        'icon': Icons.apps_rounded,
        'color': const Color(0xFFE53935),
        'title': 'Mandatory module alerts',
        'body':
            'Machine, daily data, rental, cash, food, reports, maps and others are alert-enabled.',
        'time': '2 days ago',
        'read': false,
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HOD Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A1628),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _notificationCount = 0);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1976D2)),
                    ),
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
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (n['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            n['icon'] as IconData,
                            size: 20,
                            color: n['color'] as Color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      n['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0A1628),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    n['time'] as String,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                n['body'] as String,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF555555)),
                              ),
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
                              shape: BoxShape.circle,
                            ),
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

  Widget _buildProfileTabPage() {
    final initials = _initials(_displayName);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3460), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F3460).withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _displayName,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _displayEmpId,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _hodData['role'].toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _profileBadge(Icons.badge, _displayEmpId),
                  const SizedBox(width: 8),
                  _profileBadge(Icons.location_on, 'All Sites'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _profileStatBox(
              'Reviews',
              '${_hodData['tasksReviewed']}',
              Icons.task_alt,
              const Color(0xFF0FA37A),
            ),
            const SizedBox(width: 10),
            _profileStatBox(
              'Reports',
              '${_hodData['reportsReviewed']}',
              Icons.bar_chart,
              const Color(0xFF1976D2),
            ),
            const SizedBox(width: 10),
            _profileStatBox(
              'Approval',
              _hodData['approvalPct'].toString(),
              Icons.verified,
              const Color(0xFF9C27B0),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
                  Icon(Icons.verified_user, size: 16, color: Color(0xFF1976D2)),
                  SizedBox(width: 8),
                  Text(
                    'HOD Thavvu IDs',
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
                      'HOD',
                      _displayEmpId,
                      const Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _profileIdMini(
                      'Scope',
                      _thavvuIds['primarySiteId'].toString(),
                      const Color(0xFF0FA37A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _profileIdMini(
                      'Desk',
                      _thavvuIds['approvalDeskId'].toString(),
                      const Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _profileIdMini(
                      'Company',
                      _thavvuIds['companyRegId'].toString(),
                      const Color(0xFFE6A817),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _profileInfoTile(
            Icons.phone_outlined, 'Phone', _hodData['phone'].toString()),
        _profileInfoTile(
            Icons.mail_outline, 'Email', _hodData['email'].toString()),
        _profileInfoTile(Icons.calendar_today_outlined, 'Joined',
            _hodData['joinDate'].toString()),
        _profileInfoTile(Icons.location_city_outlined, 'Workspace',
            _hodData['site'].toString()),
        const SizedBox(height: 12),
        _profileActionTile(Icons.edit_outlined, 'Edit Profile',
            const Color(0xFF1976D2), () {}),
        _profileActionTile(Icons.lock_outline, 'Change Password',
            const Color(0xFF9C27B0), () {}),
        _profileActionTile(Icons.support_agent_outlined, 'Contact Admin',
            const Color(0xFF0FA37A), () {}),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _confirmLogout(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFEF9A9A).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, size: 20, color: Color(0xFFE53935)),
                SizedBox(width: 14),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE53935),
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 18, color: Color(0xFFE53935)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── PROFILE SHEET ────────────────────────────────────────────────────────

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
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
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
            Text(
              value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A1628),
                  ),
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A1628),
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade300),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
            SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of Thavvu HOD?',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await AuthService.logout();
              if (!mounted) return;
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Log Out',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
