import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/hod_machine/data/repositories/supabase_assignment_repository.dart';
import '../../models/hod_site_models.dart';
import '../../services/hod_site_workspace_service.dart';
import 'hod_site_modules_screen.dart';
import '../../theme/app_theme.dart';

class HodThavvuPointsScreen extends StatefulWidget {
  final HodAdminSite site;
  final Map<String, int> moduleAlertCounts;

  const HodThavvuPointsScreen({
    super.key,
    required this.site,
    this.moduleAlertCounts = const {},
  });

  @override
  State<HodThavvuPointsScreen> createState() => _HodThavvuPointsScreenState();
}

class _HodThavvuPointsScreenState extends State<HodThavvuPointsScreen> {
  final HodSiteWorkspaceService _workspaceService = HodSiteWorkspaceService();
  // Lazy: never touches Supabase.instance until the repo is actually used,
  // so widget tests that build this screen don't need a Supabase init.
  final SupabaseAssignmentRepository _assignmentRepo =
      SupabaseAssignmentRepository(null);
  late Future<_ThavvuPointData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ThavvuPointData> _loadData() async {
    final points = await _workspaceService.thavvuPointsForSite(widget.site.id);
    final supervisors = await _workspaceService.supervisors();
    final activityEntries = await Future.wait(
      points.map(
        (point) async => MapEntry(
          point.id,
          await _workspaceService.activitiesForPoint(point.id),
        ),
      ),
    );
    return _ThavvuPointData(
      points: points,
      supervisors: supervisors,
      activitiesByPointId: Map<String, List<HodSupervisorActivity>>.fromEntries(
        activityEntries,
      ),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _showCreatePointSheet() async {
    final formKey = GlobalKey<FormState>();
    final pointController = TextEditingController();
    final acresController = TextEditingController();
    final data = await _dataFuture;
    if (!mounted) return;
    String? selectedSupervisorId =
        data.supervisors.isEmpty ? null : data.supervisors.first.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
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
                          const _ClassicIconBox(
                            icon: Icons.add_location_alt_rounded,
                            color: Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Create Thavvu Point',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  '${widget.site.name} • ${widget.site.acresLabel}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
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
                        controller: pointController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Thavvu Point Name',
                          hintText: 'Example: North Silt Loading Point',
                          prefixIcon: Icon(Icons.add_location_alt_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Enter a valid Thavvu Point name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedSupervisorId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Worker / Supervisor',
                          prefixIcon: Icon(Icons.engineering_outlined),
                        ),
                        items: data.supervisors
                            .map(
                              (supervisor) => DropdownMenuItem<String>(
                                value: supervisor.id,
                                child: Text(
                                  '${supervisor.name} • ${supervisor.id}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setSheetState(() => selectedSupervisorId = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Select a supervisor';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: acresController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Supervisor Lead Acres',
                          hintText: 'Example: 8.5',
                          prefixIcon: Icon(Icons.landscape_outlined),
                        ),
                        validator: (value) {
                          final acres = double.tryParse(value?.trim() ?? '');
                          if (acres == null || acres <= 0) {
                            return 'Enter valid supervisor acres';
                          }
                          if (acres > widget.site.acres) {
                            return 'Cannot exceed ${widget.site.acresLabel}';
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
                              // The service is backend-first: when Supabase
                              // is available it creates the point + active
                              // assignment + site membership atomically via
                              // the tenant-scoped admin_create_thavvu_point
                              // RPC, then mirrors locally for offline/tests.
                              await _workspaceService.createThavvuPoint(
                                site: widget.site,
                                pointName: pointController.text,
                                supervisorId: selectedSupervisorId!,
                                assignedAcres:
                                    double.parse(acresController.text.trim()),
                              );
                              if (!mounted || !sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              await _reload();
                            } catch (error) {
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                          icon:
                              const Icon(Icons.check_circle_rounded, size: 20),
                          label: const Text('Create Draft Point'),
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
      },
    );
  }

  void _openModules(HodThavvuPoint point) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HodSiteModulesScreen(
          siteName: widget.site.name,
          siteId: widget.site.id,
          thavvuPointName: point.pointName,
          thavvuPointId: point.id,
          assignedTo: point.assignedTo,
          supervisorId: point.supervisorId,
          moduleAlertCounts: widget.moduleAlertCounts,
        ),
      ),
    );
  }

  Future<void> _grantPoint(HodThavvuPoint point) async {
    try {
      await _workspaceService.grantThavvuPoint(point.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${point.pointName} granted to ${point.supervisorName}'),
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reassignPoint(HodThavvuPoint point) async {
    final data = await _dataFuture;
    final supervisors = data.supervisors.where((item) => item.active).toList();
    String? selectedSupervisorId = point.supervisorId;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedSupervisor = supervisors.where(
              (supervisor) => supervisor.id == selectedSupervisorId,
            );
            final selectedName = selectedSupervisor.isEmpty
                ? 'Select a supervisor'
                : selectedSupervisor.first.name;
            final isChangingSupervisor =
                selectedSupervisorId != null && selectedSupervisorId != point.supervisorId;

            return SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6FC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF0F3460)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1565C0).withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reassign Supervisor',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A2340),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  point.pointName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
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
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDDE7F5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F1FB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF1565C0),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CURRENT SUPERVISOR',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${point.supervisorName} · ${point.supervisorId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1A2340),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedSupervisorId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'New supervisor',
                          helperText: isChangingSupervisor
                              ? 'This point will be assigned to $selectedName.'
                              : 'Choose another active supervisor.',
                          prefixIcon: const Icon(Icons.engineering_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDDE7F5)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDDE7F5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                          ),
                        ),
                        items: supervisors
                            .map(
                              (supervisor) => DropdownMenuItem<String>(
                                value: supervisor.id,
                                child: Text(
                                  '${supervisor.name} · ${supervisor.id}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) => setSheetState(
                                  () => selectedSupervisorId = value,
                                ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1565C0), Color(0xFF0F3460)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1565C0).withOpacity(0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: !isChangingSupervisor || isSubmitting
                                    ? null
                                    : () async {
                                        setSheetState(() => isSubmitting = true);
                                        try {
                                          // Resolve the acting HOD (Supabase auth uid if available).
                                          final supabaseUid = Supabase
                                              .instance
                                              .client
                                              .auth
                                              .currentUser
                                              ?.id;

                                          // 1. Supabase is the source of truth — only when a
                                          //    real authenticated HOD uid exists. Otherwise we
                                          //    fall back to the local workspace so the offline
                                          //    demo flow still works (no fake UUID in the DB).
                                          if (supabaseUid != null) {
                                            await _assignmentRepo.reassign(
                                              thavvuPointId: point.id,
                                              newSupervisorId: selectedSupervisorId!,
                                              siteId: point.siteId,
                                              assignedBy: supabaseUid,
                                              reason: 'Reassigned via HOD Thavvu Points screen',
                                            );
                                          }

                                          // 2. Mirror to local workspace so the supervisor
                                          //    banner reflects the change immediately, even
                                          //    if they are already signed in.
                                          await _workspaceService
                                              .reassignThavvuPoint(
                                            point.id,
                                            selectedSupervisorId!,
                                          );

                                          if (!mounted) return;
                                          Navigator.of(sheetContext).pop();
                                          _showSnackbar(
                                            '${point.pointName} reassigned to $selectedName.',
                                            AppTheme.success,
                                          );
                                          await _reload();
                                        } catch (error) {
                                          if (mounted) {
                                            _showSnackbar(
                                              'Unable to reassign supervisor: $error',
                                              AppTheme.danger,
                                            );
                                          }
                                          if (sheetContext.mounted) {
                                            setSheetState(() => isSubmitting = false);
                                          }
                                        }
                                      },
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_rounded, size: 19),
                                label: Text(
                                  isSubmitting ? 'Reassigning…' : 'Confirm Reassignment',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.transparent,
                                  disabledForegroundColor: Colors.white70,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: const Text('Thavvu Points'),
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: const Color(0xFF0F3460).withOpacity(0.3),
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
      ),
      body: FutureBuilder<_ThavvuPointData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const _ThavvuPointData();
          final points = data.points;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SiteHeroCard(site: widget.site, pointsCount: points.length),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showCreatePointSheet,
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Create Thavvu Point'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: const Color(0xFF1565C0).withOpacity(0.3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Points in this site',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState != ConnectionState.done)
                const Center(child: CircularProgressIndicator())
              else if (points.isEmpty)
                const _EmptyPointCard()
              else
                ...points.map(
                  (point) => _ThavvuPointCard(
                    point: point,
                    activities: data.activitiesByPointId[point.id] ??
                        const <HodSupervisorActivity>[],
                    onGrant: point.isGranted ? null : () => _grantPoint(point),
                    onReassign: () => _reassignPoint(point),
                    onTap: () => _openModules(point),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SiteHeroCard extends StatelessWidget {
  final HodAdminSite site;
  final int pointsCount;

  const _SiteHeroCard({required this.site, required this.pointsCount});

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
            color: const Color(0xFF0F3460).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${site.place} · ${site.id} · ${site.acresLabel}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pointsCount Thavvu point${pointsCount == 1 ? '' : 's'} assigned',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointPill extends StatelessWidget {
  final String text;
  final Color color;

  const _PointPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ThavvuPointData {
  final List<HodThavvuPoint> points;
  final List<HodSupervisorAccount> supervisors;
  final Map<String, List<HodSupervisorActivity>> activitiesByPointId;

  const _ThavvuPointData({
    this.points = const [],
    this.supervisors = const [],
    this.activitiesByPointId = const {},
  });
}

class _ThavvuPointCard extends StatelessWidget {
  final HodThavvuPoint point;
  final List<HodSupervisorActivity> activities;
  final VoidCallback? onGrant;
  final VoidCallback onReassign;
  final VoidCallback onTap;

  const _ThavvuPointCard({
    required this.point,
    required this.activities,
    required this.onTap,
    this.onGrant,
    required this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E4F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _ClassicIconBox(
                icon: Icons.account_tree_rounded,
                color: Color(0xFF1565C0),
                emoji:
                    '📍', // kept but ignored inside widget; decorative emoji is added in title text
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.pointName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assigned to ${point.assignedTo}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _PointPill(
                          text: point.status,
                          color: point.isGranted
                              ? const Color(0xFF0FA37A)
                              : const Color(0xFFD97706),
                        ),
                        _PointPill(
                          text: point.acresLabel,
                          color: const Color(0xFF1565C0),
                        ),
                        _PointPill(
                          text:
                              '${activities.length} action${activities.length == 1 ? '' : 's'}',
                          color: const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                    if (activities.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${activities.first.module}: ${activities.first.action}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1D6FCE), Color(0xFF0F3460)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1565C0).withOpacity(0.24),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton.icon(
                            onPressed: onReassign,
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 17,
                            ),
                            label: const Text('Reassign'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (onGrant != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: onGrant,
                            icon: const Icon(Icons.verified_rounded, size: 17),
                            label: const Text('Grant'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF0FA37A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPointCard extends StatelessWidget {
  const _EmptyPointCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E4F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        'No Thavvu Points created yet.\nCreate one to assign work and open modules.',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ClassicIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String emoji; // not used visually, kept for flexibility

  const _ClassicIconBox({
    required this.icon,
    required this.color,
    this.emoji = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
