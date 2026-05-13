import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'overview_screen.dart';
import 'machines_entry_screen.dart';
import 'daily_data_screen.dart';
import 'attendance_screen.dart';
import 'stock_inventory_screen.dart';
import 'internal_transfer_screen.dart';
import 'rental_screen.dart';
import 'tasks_screen.dart';
import 'reports_screen.dart';
import 'maps_screen.dart';
import 'hod_tasks_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _drawerAnimController;
  late Animation<double> _drawerFade;

  int _notificationCount = 3;

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
    'avatar': '👷',
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
    _drawerFade = CurvedAnimation(parent: _drawerAnimController, curve: Curves.easeOut);
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

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return OverviewScreen(
          onNavigate: (i) => setState(() => _currentIndex = i),
          onNavigateModule: _handleModuleNavigation,
        );
      case 1:
        return const MachinesEntryScreen();
      case 2:
        return const DailyDataScreen();
      case 3:
        return const AttendanceScreen();
      case 4:
        return _buildMoreScreen();
      default:
        return OverviewScreen(
          onNavigate: (i) => setState(() => _currentIndex = i),
          onNavigateModule: _handleModuleNavigation,
        );
    }
  }

  Widget _buildMoreScreen() {
    final modules = [
      {'title': 'Stock Inventory', 'route': '/stock', 'emoji': '📦', 'color': const Color(0xFFE6A817)},
      {'title': 'Internal Transfers', 'route': '/transfers', 'emoji': '🔄', 'color': const Color(0xFF1976D2)},
      {'title': 'Rental', 'route': '/rental', 'emoji': '🔑', 'color': const Color(0xFFE53935)},
      {'title': 'Tasks & Checklist', 'route': '/tasks', 'emoji': '✅', 'color': const Color(0xFF0FA37A)},
      {'title': 'Reports', 'route': '/reports', 'emoji': '📊', 'color': const Color(0xFF9C27B0)},
      {'title': 'Maps & Specs', 'route': '/maps', 'emoji': '🗺️', 'color': const Color(0xFF1976D2)},
      {'title': 'HOD Tasks', 'route': '/hodtasks', 'emoji': '📋', 'color': const Color(0xFF0FA37A)},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Additional Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              final Color moduleColor = module['color'] as Color;
              return GestureDetector(
                onTap: () => _handleModuleNavigation(module['route'] as String),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: moduleColor.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(module['emoji'] as String, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(
                        module['title'] as String,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: moduleColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleModuleNavigation(String route) {
    Widget screen;
    switch (route) {
      case '/stock':
        screen = const StockInventoryScreen();
        break;
      case '/transfers':
        screen = const InternalTransferScreen();
        break;
      case '/rental':
        screen = const RentalScreen();
        break;
      case '/tasks':
        screen = const TasksScreen();
        break;
      case '/reports':
        screen = const ReportsScreen();
        break;
      case '/maps':
        screen = const MapsScreen();
        break;
      case '/hodtasks':
        screen = const HODTasksScreen();
        break;
      default:
        screen = OverviewScreen(
          onNavigate: (i) => setState(() => _currentIndex = i),
          onNavigateModule: _handleModuleNavigation,
        );
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F6FC),
      drawer: _buildSideDrawer(),
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_currentIndex), child: _buildCurrentScreen()),
      ),
    );
  }

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
                errorBuilder: (context, error, stackTrace) {
                  return const Text('👷', style: TextStyle(fontSize: 20));
                },
              ),
            ),
          ),
        ),
      ),
      title: RichText(
        text: const TextSpan(
          children: [
            TextSpan(text: 'Thavvu ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            TextSpan(text: 'Supervisor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: Color(0xFF4FC3F7))),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
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
                    border: Border.all(color: const Color(0xFF0F3460), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text('$_notificationCount', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        GestureDetector(
          onTap: () => _showProfileSheet(context),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    _supervisorData['name'].toString().split(' ').map((e) => e[0]).take(2).join(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

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
                    _buildDrawerNavTile('Home', Icons.home_rounded, 0),
                    _buildDrawerNavTile('Machine', Icons.construction_rounded, 1),
                    _buildDrawerNavTile('Daily', Icons.edit_calendar_rounded, 2),
                    _buildDrawerNavTile('Attendance', Icons.fingerprint_rounded, 3),
                    _buildDrawerNavTile('More', Icons.grid_view_rounded, 4),
                    const SizedBox(height: 8),
                    _buildDrawerSection('Modules'),
                    _buildDrawerModuleTile(Icons.map_outlined, 'Maps & Specs', '/maps', const Color(0xFF1976D2)),
                    _buildDrawerModuleTile(Icons.assignment_outlined, 'HOD Tasks', '/hodtasks', const Color(0xFF0FA37A)),
                    _buildDrawerModuleTile(Icons.inventory_2_outlined, 'Stock Inventory', '/stock', const Color(0xFFE6A817)),
                    _buildDrawerModuleTile(Icons.swap_horiz_rounded, 'Internal Transfers', '/transfers', const Color(0xFF1976D2)),
                    _buildDrawerModuleTile(Icons.key_outlined, 'Rental', '/rental', const Color(0xFFE53935)),
                    _buildDrawerModuleTile(Icons.task_alt_outlined, 'Tasks & Checklist', '/tasks', const Color(0xFF0FA37A)),
                    _buildDrawerModuleTile(Icons.bar_chart_rounded, 'Reports', '/reports', const Color(0xFF9C27B0)),
                    const SizedBox(height: 8),
                    _buildDrawerSection('Settings'),
                    _buildDrawerModuleTile(Icons.settings_outlined, 'App Settings', '/settings', Colors.grey),
                    _buildDrawerModuleTile(Icons.help_outline_rounded, 'Help & Support', '/help', Colors.grey),
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
                    errorBuilder: (context, error, stackTrace) => const Text('👷', style: TextStyle(fontSize: 26)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_supervisorData['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(_supervisorData['empId'], style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 11, color: Colors.white70),
                const SizedBox(width: 4),
                Flexible(child: Text(_supervisorData['site'], style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0FA37A).withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0FA37A).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 7, color: Color(0xFF66BB6A)),
                const SizedBox(width: 5),
                Text(_supervisorData['role'], style: const TextStyle(fontSize: 10, color: Color(0xFF66BB6A), fontWeight: FontWeight.w600)),
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
      child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.3), letterSpacing: 1.2)),
    );
  }

  Widget _buildDrawerNavTile(String label, IconData icon, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1976D2).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: const Color(0xFF1976D2).withOpacity(0.4), width: 0.8) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? const Color(0xFF4FC3F7) : Colors.white54),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? Colors.white : Colors.white60)),
            if (isActive) ...[
              const Spacer(),
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4FC3F7), shape: BoxShape.circle)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerModuleTile(IconData icon, String label, String route, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _handleModuleNavigation(route);
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
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white60)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16, color: Colors.white.withOpacity(0.2)),
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
                border: Border.all(color: const Color(0xFFE53935).withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF9A9A)),
                  SizedBox(width: 12),
                  Text('Log Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF9A9A))),
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

  void _showNotificationsPanel(BuildContext context) {
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                ],
              ),
            ),
            const Expanded(child: Center(child: Text('No new notifications'))),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      alignment: Alignment.center,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            _supervisorData['name'].toString().split(' ').map((e) => e[0]).take(2).join(),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_supervisorData['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(_supervisorData['role'], style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _profileStatBox('Tasks Done', '${_supervisorData['tasksCompleted']}', Icons.task_alt, const Color(0xFF0FA37A)),
                  const SizedBox(width: 10),
                  _profileStatBox('Reports', '${_supervisorData['reportsGenerated']}', Icons.bar_chart, const Color(0xFF1976D2)),
                  const SizedBox(width: 10),
                  _profileStatBox('Attendance', _supervisorData['attendancePct'], Icons.fingerprint, const Color(0xFF9C27B0)),
                ],
              ),
              const SizedBox(height: 16),
              _profileInfoTile(Icons.phone_outlined, 'Phone', _supervisorData['phone']),
              _profileInfoTile(Icons.mail_outline, 'Email', _supervisorData['email']),
              _profileInfoTile(Icons.calendar_today_outlined, 'Joined', _supervisorData['joinDate']),
              _profileInfoTile(Icons.location_city_outlined, 'Site', _supervisorData['site']),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE0E4F0)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _confirmLogout(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEF9A9A).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: Color(0xFFE53935)),
                      SizedBox(width: 14),
                      Text('Log Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
                      Spacer(),
                      Icon(Icons.chevron_right, size: 18, color: Color(0xFFE53935)),
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

  Widget _profileStatBox(String label, String value, IconData icon, Color color) {
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
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
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
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0A1628))),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
            SizedBox(width: 10),
            Text('Log Out', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text('Are you sure you want to log out of Thavvu Supervisor?', style: TextStyle(fontSize: 14, color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}