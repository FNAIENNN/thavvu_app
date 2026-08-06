import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/hod_site_models.dart';
import '../../services/hod_alert_service.dart';
import '../../services/hod_site_workspace_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class HodReadOnlyOverviewScreen extends StatefulWidget {
  final ValueChanged<String> onNavigateModule;
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenSites;

  const HodReadOnlyOverviewScreen({
    super.key,
    required this.onNavigateModule,
    required this.onOpenAlerts,
    required this.onOpenSites,
  });

  @override
  State<HodReadOnlyOverviewScreen> createState() =>
      _HodReadOnlyOverviewScreenState();
}

class _HodReadOnlyOverviewScreenState extends State<HodReadOnlyOverviewScreen>
    with SingleTickerProviderStateMixin {
  final HodSiteWorkspaceService _workspaceService = HodSiteWorkspaceService();
  final HodAlertService _alertService = const HodAlertService();

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late Future<_HodOverviewData> _future;

  String _greeting = 'Good morning';

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    _updateGreeting();
  }

  Future<_HodOverviewData> _loadData() async {
    final sites = await _workspaceService.adminCreatedSites();
    final supervisors = await _workspaceService.supervisors();
    final alerts = await _alertService.alertsForHod('HOD-001');
    final history = await _workspaceService.workHistoryRows();

    // Real supervisor accounts from the backend. RLS restricts this to the
    // signed-in HOD's own department (profiles.hod_id = auth.uid()).
    List<_BackendSupervisor> backendSupervisors = const [];
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, emp_id, phone, is_active')
          .eq('role', 'supervisor')
          .order('created_at');
      backendSupervisors = (rows as List)
          .map((r) => _BackendSupervisor(
                id: (r['id'] ?? '').toString(),
                fullName: (r['full_name'] ?? '').toString(),
                email: (r['email'] ?? '').toString(),
                empId: (r['emp_id'] ?? '').toString(),
                phone: (r['phone'] ?? '').toString(),
                isActive: r['is_active'] == true,
              ))
          .toList();
    } catch (e) {
      debugPrint('backendSupervisors load failed: $e');
    }

    return _HodOverviewData(
      sites: sites,
      supervisors: supervisors,
      backendSupervisors: backendSupervisors,
      alerts: alerts,
      history: history,
    );
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        _greeting = 'Good morning';
      } else if (hour < 17) {
        _greeting = 'Good afternoon';
      } else {
        _greeting = 'Good evening';
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: FutureBuilder<_HodOverviewData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const _HodOverviewData();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _loadData());
              await _future;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroHeader(),
                      const SizedBox(height: 16),
                      _buildStatsSection(
                        data,
                        snapshot.connectionState,
                      ),
                      const SizedBox(height: 16),
                      _buildSupervisorAccessSection(data),
                      const SizedBox(height: 16),
                      _buildAlertsSection(data),
                      const SizedBox(height: 16),
                      _buildClassicControlPanel(data),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F3460), Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -38,
            right: -35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -52,
            left: -35,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success.withValues(alpha: 0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                        blurRadius: 18,
                        offset: const Offset(0, 8),
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
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                        ),
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
                        '$_greeting, HOD Admin!',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTodayDate()} • HOD workspace',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Text(
                    'HOD-001',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE0F2FE),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    _HodOverviewData data,
    ConnectionState connectionState,
  ) {
    final loading = connectionState != ConnectionState.done;
    final totalPoints =
        data.sites.fold<int>(0, (sum, site) => sum + site.activePointCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            'Sites',
            loading ? '-' : '${data.sites.length}',
            AppTheme.info,
            Icons.apartment_rounded,
            'All places',
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            'Thavvu Points',
            loading ? '-' : '$totalPoints',
            AppTheme.success,
            Icons.account_tree_rounded,
            'Mapped points',
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            'Alerts',
            loading ? '-' : '${data.alerts.length}',
            AppTheme.warning,
            Icons.notifications_active_rounded,
            'Need review',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
    String sub,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.16)),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
            ),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(_HodOverviewData data) {
    final recentHistory = data.history.take(2).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: 'HOD Alerts')),
              TextButton.icon(
                onPressed: widget.onOpenAlerts,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Open'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (data.alerts.isEmpty)
            _buildAlertTile(
              title: 'No pending HOD alerts',
              message:
                  'Supervisor requests and review updates will appear here when action is needed.',
              icon: Icons.notifications_none_rounded,
              color: AppTheme.info,
              onTap: widget.onOpenAlerts,
            )
          else
            ...data.alerts.map(
              (alert) => _buildAlertTile(
                title: alert.title,
                message: alert.message,
                icon: alert.icon,
                color: alert.color,
                onTap: widget.onOpenAlerts,
              ),
            ),
          if (recentHistory.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...recentHistory.map(
              (row) => _buildAlertTile(
                title: '${row.module} • ${row.status}',
                message:
                    '${row.siteName} • ${row.pointName} • ${row.assignedTo}',
                icon: row.icon,
                color: row.color,
                onTap: widget.onOpenSites,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCreateSupervisorSheet() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        HodAdminSite? selectedSite;
        HodThavvuPoint? selectedPoint;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          color: AppTheme.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Supervisor Login',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'The generated ID and password will appear on HOD home.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 3
                            ? 'Enter supervisor name'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Login Email',
                      hintText: 'supervisor@site.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) =>
                        value == null || !value.trim().contains('@')
                            ? 'Enter valid email'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 8
                            ? 'Enter phone number'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary Password',
                      hintText: 'Minimum 6 characters',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 6
                            ? 'Minimum 6 characters'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<List<HodAdminSite>>(
                    future: _workspaceService.adminCreatedSites(),
                    builder: (context, snapshot) {
                      final sites = snapshot.data ?? const <HodAdminSite>[];
                      return InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Assign to Site (optional)',
                          prefixIcon: Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<HodAdminSite?>(
                            value: selectedSite,
                            isExpanded: true,
                            isDense: true,
                            hint: const Text('Assign later from HOD Sites'),
                            items: [
                              const DropdownMenuItem<HodAdminSite?>(
                                value: null,
                                child: Text('Assign later'),
                              ),
                              ...sites.map(
                                (site) => DropdownMenuItem<HodAdminSite?>(
                                  value: site,
                                  child: Text('${site.name} — ${site.place}'),
                                ),
                              ),
                            ],
                            onChanged: (site) => setSheetState(() {
                              selectedSite = site;
                              selectedPoint = null;
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedSite != null)
                    FutureBuilder<List<HodThavvuPoint>>(
                      future: _workspaceService
                          .thavvuPointsForSite(selectedSite!.id),
                      builder: (context, snapshot) {
                        final points =
                            snapshot.data ?? const <HodThavvuPoint>[];
                        return InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Assign to Thavvu Point (optional)',
                            prefixIcon: Icon(Icons.place_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<HodThavvuPoint?>(
                              value: selectedPoint,
                              isExpanded: true,
                              isDense: true,
                              hint: const Text('Choose a point'),
                              items: [
                                const DropdownMenuItem<HodThavvuPoint?>(
                                  value: null,
                                  child: Text('Assign later'),
                                ),
                                ...points.map(
                                  (point) => DropdownMenuItem<HodThavvuPoint?>(
                                    value: point,
                                    child: Text(point.pointName),
                                  ),
                                ),
                              ],
                              onChanged: (point) => setSheetState(() {
                                selectedPoint = point;
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        try {
                          final supervisor =
                              await _workspaceService.createSupervisor(
                            name: nameController.text,
                            email: emailController.text,
                            phone: phoneController.text,
                            password: passwordController.text,
                            siteId: selectedSite?.id,
                            pointId: selectedPoint?.id,
                          );
                          if (!mounted || !sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          setState(() => _future = _loadData());
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${supervisor.name} login created: ${supervisor.id}',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Create Supervisor Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.info,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildSupervisorAccessSection(_HodOverviewData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE0E7F5)),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(title: 'Supervisor Logins'),
                ),
                TextButton.icon(
                  onPressed: _showCreateSupervisorSheet,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: const Text('Create'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data.backendSupervisors.isNotEmpty)
              ...data.backendSupervisors.map(_buildBackendSupervisorCard)
            else if (data.supervisors.isEmpty)
              const Text(
                'No supervisors created yet.',
                style: TextStyle(color: AppTheme.textSecondary),
              )
            else
              ...data.supervisors.take(4).map(_buildSupervisorLoginCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorLoginCard(HodSupervisorAccount supervisor) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.engineering_outlined,
                color: AppTheme.info, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supervisor.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${supervisor.id} • ${supervisor.email}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Password: ${supervisor.password}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy login',
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      'ID: ${supervisor.id}\nEmail: ${supervisor.email}\nPassword: ${supervisor.password}',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${supervisor.name} login copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendSupervisorCard(_BackendSupervisor sup) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: sup.isActive
                  ? AppTheme.info.withValues(alpha: 0.1)
                  : AppTheme.textSecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              sup.isActive
                  ? Icons.engineering_outlined
                  : Icons.person_off_outlined,
              color: sup.isActive ? AppTheme.info : AppTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sup.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: sup.isActive
                            ? AppTheme.successBg
                            : AppTheme.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        sup.isActive ? 'ACTIVE' : 'DEACTIVATED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: sup.isActive
                              ? AppTheme.success
                              : AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${sup.empId} • ${sup.email}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Manage supervisor',
            onSelected: (action) {
              switch (action) {
                case 'reset':
                  _showResetSupervisorPassword(sup);
                  break;
                case 'edit':
                  _showEditSupervisor(sup);
                  break;
                case 'toggle':
                  _confirmToggleSupervisor(sup);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'reset',
                child: Text('Reset Password'),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit Details'),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Text(sup.isActive
                    ? 'Deactivate Account'
                    : 'Reactivate Account'),
              ),
            ],
            icon: const Icon(Icons.more_vert, size: 19),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetSupervisorPassword(_BackendSupervisor sup) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New password (min 6 characters)',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final pw = ctrl.text.trim();
    if (pw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: AppTheme.danger));
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'admin_reset_supervisor_password',
        params: {'p_supervisor_id': sup.id, 'p_new_password': pw},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password reset for ${sup.fullName}'),
          backgroundColor: AppTheme.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Reset failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _showEditSupervisor(_BackendSupervisor sup) async {
    final nameCtrl = TextEditingController(text: sup.fullName);
    final phoneCtrl = TextEditingController(text: sup.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Supervisor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc(
        'admin_update_supervisor',
        params: {
          'p_supervisor_id': sup.id,
          'p_name': nameCtrl.text.trim(),
          'p_phone': phoneCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Supervisor updated'),
          backgroundColor: AppTheme.success));
      setState(() => _future = _loadData());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Update failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _confirmToggleSupervisor(_BackendSupervisor sup) async {
    final deactivating = sup.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(deactivating ? 'Deactivate ${sup.fullName}?' : 'Reactivate ${sup.fullName}?'),
        content: Text(deactivating
            ? 'The supervisor will not be able to sign in. Their data stays intact and their point assignments are released.'
            : 'The supervisor will be able to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(deactivating ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.rpc(
        deactivating ? 'admin_deactivate_supervisor' : 'admin_reactivate_supervisor',
        params: {'p_supervisor_id': sup.id},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(deactivating
              ? '${sup.fullName} deactivated'
              : '${sup.fullName} reactivated'),
          backgroundColor: AppTheme.success));
      setState(() => _future = _loadData());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Action failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.danger));
    }
  }

  Widget _buildAlertTile({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassicControlPanel(_HodOverviewData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF4F8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE0E7F5)),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F3460), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HOD Control Center',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Quick access for sites, alerts and profile review.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildMiniAction(
                  icon: Icons.apartment_rounded,
                  label: 'Sites',
                  value: '${data.sites.length}',
                  color: AppTheme.info,
                  onTap: widget.onOpenSites,
                ),
                const SizedBox(width: 10),
                _buildMiniAction(
                  icon: Icons.notifications_active_rounded,
                  label: 'Alerts',
                  value: '${data.alerts.length}',
                  color: AppTheme.warning,
                  onTap: widget.onOpenAlerts,
                ),
                const SizedBox(width: 10),
                _buildMiniAction(
                  icon: Icons.fingerprint_rounded,
                  label: 'Attendance',
                  value: 'Live',
                  color: const Color(0xFF0FA37A),
                  onTap: () => widget.onNavigateModule('/attendance'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'HOD Modules Overview',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _buildGridModuleTile(
                  icon: Icons.fingerprint_rounded,
                  label: 'Attendance',
                  color: const Color(0xFF0FA37A),
                  onTap: () => widget.onNavigateModule('/attendance'),
                ),
                _buildGridModuleTile(
                  icon: Icons.construction_rounded,
                  label: 'Machines',
                  color: const Color(0xFFD97706),
                  onTap: () => widget.onNavigateModule('/machines'),
                ),
                _buildGridModuleTile(
                  icon: Icons.edit_calendar_rounded,
                  label: 'Daily Data',
                  color: const Color(0xFF1976D2),
                  onTap: () => widget.onNavigateModule('/daily'),
                ),
                _buildGridModuleTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Stock',
                  color: const Color(0xFFE6A817),
                  onTap: () => widget.onNavigateModule('/stock'),
                ),
                _buildGridModuleTile(
                  icon: Icons.storefront_rounded,
                  label: 'Suppliers',
                  color: const Color(0xFF2563EB),
                  onTap: () => widget.onNavigateModule('/suppliers'),
                ),
                _buildGridModuleTile(
                  icon: Icons.key_outlined,
                  label: 'Rental',
                  color: const Color(0xFFE53935),
                  onTap: () => widget.onNavigateModule('/rental'),
                ),
                _buildGridModuleTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Cash',
                  color: const Color(0xFF0FA37A),
                  onTap: () => widget.onNavigateModule('/cash'),
                ),
                _buildGridModuleTile(
                  icon: Icons.restaurant_menu_outlined,
                  label: 'Food',
                  color: const Color(0xFFE6A817),
                  onTap: () => widget.onNavigateModule('/food'),
                ),
                _buildGridModuleTile(
                  icon: Icons.task_alt_outlined,
                  label: 'Tasks',
                  color: const Color(0xFF0FA37A),
                  onTap: () => widget.onNavigateModule('/tasks'),
                ),
                _buildGridModuleTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  color: const Color(0xFF9C27B0),
                  onTap: () => widget.onNavigateModule('/reports'),
                ),
                _buildGridModuleTile(
                  icon: Icons.map_outlined,
                  label: 'Maps',
                  color: const Color(0xFF1976D2),
                  onTap: () => widget.onNavigateModule('/maps'),
                ),
                _buildGridModuleTile(
                  icon: Icons.tune_rounded,
                  label: 'Registry',
                  color: const Color(0xFF6D4C41),
                  onTap: () => widget.onNavigateModule('/registry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridModuleTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HodOverviewData {
  final List<HodAdminSite> sites;
  final List<HodSupervisorAccount> supervisors;
  final List<_BackendSupervisor> backendSupervisors;
  final List<HodAlertViewData> alerts;
  final List<HodWorkHistoryRow> history;

  const _HodOverviewData({
    this.sites = const [],
    this.supervisors = const [],
    this.backendSupervisors = const [],
    this.alerts = const [],
    this.history = const [],
  });
}

/// A supervisor account managed through the Supabase backend (RLS scoped to
/// the signed-in HOD's department). Carries the real profiles UUID so the
/// HOD can reset / deactivate / update the account.
class _BackendSupervisor {
  final String id;
  final String fullName;
  final String email;
  final String empId;
  final String phone;
  final bool isActive;

  const _BackendSupervisor({
    required this.id,
    required this.fullName,
    required this.email,
    required this.empId,
    required this.phone,
    required this.isActive,
  });
}

String _formatTodayDate() {
  final now = DateTime.now();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
}
