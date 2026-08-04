import 'package:flutter/material.dart';

import '../../models/hod_site_models.dart';
import '../../services/hod_alert_service.dart';
import '../../services/hod_site_workspace_service.dart';
import 'hod_thavvu_points_screen.dart';

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class HodSitesScreen extends StatefulWidget {
  const HodSitesScreen({super.key});

  @override
  State<HodSitesScreen> createState() => _HodSitesScreenState();
}

class _HodSitesScreenState extends State<HodSitesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final HodSiteWorkspaceService _workspaceService = HodSiteWorkspaceService();
  final HodAlertService _alertService = const HodAlertService();

  late Future<_HodSitesData> _future;
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  String _query = '';

  // Color palette for site cards — cycles by index
  static const List<_SiteTheme> _siteThemes = [
    _SiteTheme(
      accent: Color(0xFF1565C0),
      light: Color(0xFFE6F1FB),
      icon: Icons.apartment_rounded,
    ),
    _SiteTheme(
      accent: Color(0xFF0FA37A),
      light: Color(0xFFE1F5EE),
      icon: Icons.terrain_rounded,
    ),
    _SiteTheme(
      accent: Color(0xFF9C27B0),
      light: Color(0xFFF3E5F5),
      icon: Icons.foundation_rounded,
    ),
    _SiteTheme(
      accent: Color(0xFFD97706),
      light: Color(0xFFFFF8E1),
      icon: Icons.holiday_village_rounded,
    ),
    _SiteTheme(
      accent: Color(0xFFE53935),
      light: Color(0xFFFFEBEE),
      icon: Icons.warehouse_rounded,
    ),
    _SiteTheme(
      accent: Color(0xFF0288D1),
      light: Color(0xFFE1F5FE),
      icon: Icons.water_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
  }

  Future<_HodSitesData> _loadData() async {
    final sites = await _workspaceService.adminCreatedSites();
    final alerts = await _alertService.alertsForHod('HOD-001');
    return _HodSitesData(sites: sites, alerts: alerts);
  }

  List<HodAdminSite> _filteredSites(List<HodAdminSite> sites) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return sites;
    return sites.where((site) {
      return site.place.toLowerCase().contains(q) ||
          site.name.toLowerCase().contains(q) ||
          site.id.toLowerCase().contains(q) ||
          site.adminName.toLowerCase().contains(q);
    }).toList();
  }

  Map<String, int> _moduleAlertCounts(
      String siteId, List<HodAlertViewData> alerts) {
    final counts = <String, int>{};
    for (final a in alerts.where((a) => a.siteId == siteId)) {
      counts[a.module] = (counts[a.module] ?? 0) + 1;
    }
    return counts;
  }

  int _siteAlertCount(String siteId, List<HodAlertViewData> alerts) =>
      alerts.where((a) => a.siteId == siteId).length;

  void _openSite(HodAdminSite site, List<HodAlertViewData> alerts) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HodThavvuPointsScreen(
          site: site,
          moduleAlertCounts: _moduleAlertCounts(site.id, alerts),
        ),
      ),
    );
  }

  Future<void> _showCreateSiteSheet() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final placeController = TextEditingController();
    final adminController = TextEditingController();
    final acresController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
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
                          color: const Color(0xFFE6F1FB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Site',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Define acreage before creating Thavvu Points.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
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
                      labelText: 'Site Name',
                      hintText: 'Example: Kakinada Road Work',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 3
                            ? 'Enter a valid site name'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: placeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Place',
                      hintText: 'Example: Kakinada',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                            ? 'Enter a valid place'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: adminController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Site Admin Name',
                      hintText: 'Example: Admin Kumar',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 3
                            ? 'Enter site admin name'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: acresController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Acres',
                      hintText: 'Example: 24.5',
                      prefixIcon: Icon(Icons.landscape_outlined),
                    ),
                    validator: (value) {
                      final acres = double.tryParse(value?.trim() ?? '');
                      if (acres == null || acres <= 0) {
                        return 'Enter valid acres';
                      }
                      return null;
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
                          await _workspaceService.createSite(
                            name: nameController.text,
                            place: placeController.text,
                            adminName: adminController.text,
                            acres: double.parse(acresController.text.trim()),
                          );
                          if (!mounted || !sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          setState(() => _future = _loadData());
                        } catch (error) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Create Site'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: _SitesAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSiteSheet,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Create Site'),
      ),
      body: FutureBuilder<_HodSitesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingView();
          }
          if (snapshot.hasError) {
            return _ErrorView(
                onRetry: () => setState(() {
                      _future = _loadData();
                    }));
          }
          final data = snapshot.data ?? const _HodSitesData();
          final sites = _filteredSites(data.sites);

          return RefreshIndicator(
            color: const Color(0xFF1565C0),
            onRefresh: () async {
              setState(() => _future = _loadData());
              await _future;
            },
            child: CustomScrollView(
              slivers: [
                // Header stats card
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _DashboardHeader(
                        siteCount: data.sites.length,
                        pointCount: data.totalPointCount,
                        alertCount: data.alerts.length,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Search bar
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _SearchField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // Section header
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Admin Created Sites',
                      count: sites.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // Site cards — 2-column square grid
                if (sites.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _EmptyState(hasQuery: _query.isNotEmpty),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final site = sites[index];
                          final theme = _siteThemes[index % _siteThemes.length];
                          final alertCount =
                              _siteAlertCount(site.id, data.alerts);
                          return _SiteCard(
                            site: site,
                            theme: theme,
                            alertCount: alertCount,
                            onTap: () => _openSite(site, data.alerts),
                          );
                        },
                        childCount: sites.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────
class _SitesAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Row(
        children: [
          Text(
            '🏗️',
            style: TextStyle(fontSize: 20),
          ),
          SizedBox(width: 8),
          Text(
            'All Sites',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F3460),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    );
  }
}

// ─────────────────────────────────────────────
// Dashboard Header Card
// ─────────────────────────────────────────────
class _DashboardHeader extends StatelessWidget {
  final int siteCount;
  final int pointCount;
  final int alertCount;

  const _DashboardHeader({
    required this.siteCount,
    required this.pointCount,
    required this.alertCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2B55), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3460).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(Icons.domain_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏛️ Classic HOD Site Desk',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Select a site, then manage Thavvu Points.',
                      style: TextStyle(
                        color: Color(0xFFB0C8F0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatPill(label: '🏢 Sites', value: '$siteCount'),
              const SizedBox(width: 8),
              _StatPill(label: '📍 Points', value: '$pointCount'),
              const SizedBox(width: 8),
              _StatPill(
                label: '🔔 Alerts',
                value: '$alertCount',
                highlight: alertCount > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatPill({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFE53935).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? const Color(0xFFFF5252).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: highlight ? const Color(0xFFFF7070) : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB0C8F0),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Search Field
// ─────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A2340),
        ),
        decoration: InputDecoration(
          hintText: 'Search sites, places, IDs…',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child:
                Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFF64748B)),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A2340),
              letterSpacing: -0.3,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F1FB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count shown',
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Site Card (square 1:1 aspect ratio)
// ─────────────────────────────────────────────
class _SiteCard extends StatefulWidget {
  final HodAdminSite site;
  final _SiteTheme theme;
  final int alertCount;
  final VoidCallback onTap;

  const _SiteCard({
    required this.site,
    required this.theme,
    required this.alertCount,
    required this.onTap,
  });

  @override
  State<_SiteCard> createState() => _SiteCardState();
}

class _SiteCardState extends State<_SiteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final s = widget.site;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE0E6F0), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: t.accent.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Tinted wash in top portion
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        color: t.light.withValues(alpha: 0.6),
                      ),
                    ),
                    // Card content
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: t.accent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(t.icon, color: Colors.white, size: 22),
                          ),
                          const Spacer(),
                          // Name
                          Text(
                            s.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A2340),
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${s.place} • ${s.acresLabel}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.accent.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Footer row
                          Row(
                            children: [
                              // ID pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: t.light,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  s.id,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: t.accent,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.account_tree_outlined,
                                  size: 11, color: const Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Text(
                                '${s.activePointCount}pt',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Alert badge
            if (widget.alertCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: _AlertBubble(count: widget.alertCount),
              ),
            // Arrow indicator
            Positioned(
              bottom: 14,
              right: 14,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: t.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Alert Bubble
// ─────────────────────────────────────────────
class _AlertBubble extends StatelessWidget {
  final int count;
  const _AlertBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5252), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E6F0)),
      ),
      child: Column(
        children: [
          Text(
            hasQuery ? '🔍' : '📭',
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 12),
          Text(
            hasQuery
                ? 'No sites match your search.'
                : 'No admin-created sites found.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Loading View
// ─────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF1565C0),
            strokeWidth: 2.5,
          ),
          SizedBox(height: 14),
          Text(
            'Loading sites…',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Error View
// ─────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFE53935), size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load sites',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF1A2340),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                backgroundColor: const Color(0xFFE6F1FB),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Data + Models
// ─────────────────────────────────────────────
class _HodSitesData {
  final List<HodAdminSite> sites;
  final List<HodAlertViewData> alerts;

  const _HodSitesData({this.sites = const [], this.alerts = const []});

  int get totalPointCount =>
      sites.fold<int>(0, (sum, site) => sum + site.activePointCount);
}

class _SiteTheme {
  final Color accent;
  final Color light;
  final IconData icon;

  const _SiteTheme({
    required this.accent,
    required this.light,
    required this.icon,
  });
}
