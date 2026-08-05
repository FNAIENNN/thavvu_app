import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hod_site_models.dart';
import 'auth_service.dart';

class HodSiteWorkspaceService {
  static const _keySites = 'hod_workspace_sites_v2';
  static const _keyPoints = 'hod_workspace_points_v2';
  static const _keySupervisors = 'hod_workspace_supervisors_v2';
  static const _keyActivities = 'hod_workspace_activities_v2';

  static bool _loaded = false;
  static bool _persistenceEnabled = true;

  static final List<HodAdminSite> _adminSites = <HodAdminSite>[
    HodAdminSite(
      id: 'SITE-VJA-001',
      name: 'Vijayawada River Bed',
      place: 'Vijayawada',
      adminName: 'Admin Prakash',
      acres: 48,
      status: 'Ready for HOD planning',
      activePointCount: 2,
      createdAt: DateTime(2026, 6, 14, 10, 30),
    ),
    HodAdminSite(
      id: 'SITE-AKV-002',
      name: 'Akividu Canal Line',
      place: 'Akividu',
      adminName: 'Admin Kavitha',
      acres: 26,
      status: 'Ready for HOD planning',
      activePointCount: 1,
      createdAt: DateTime(2026, 6, 14, 11, 15),
    ),
    HodAdminSite(
      id: 'SITE-RJM-003',
      name: 'Rajahmundry Lift Point',
      place: 'Rajahmundry',
      adminName: 'Admin Suresh',
      acres: 34,
      status: 'Ready for HOD planning',
      activePointCount: 1,
      createdAt: DateTime(2026, 6, 14, 12, 00),
    ),
  ];

  static final List<HodSupervisorAccount> _supervisors = <HodSupervisorAccount>[
    HodSupervisorAccount(
      id: 'THV-SUP-001',
      name: 'Supervisor Rajesh',
      email: 'supervisor@thavvu.com',
      phone: '+91 98765 43210',
      password: 'super123',
      createdAt: DateTime(2026, 6, 14, 12, 30),
    ),
    HodSupervisorAccount(
      id: 'THV-SUP-002',
      name: 'Supervisor Mohan',
      email: 'mohan@thavvu.com',
      phone: '+91 98765 43211',
      password: 'mohan123',
      createdAt: DateTime(2026, 6, 14, 12, 45),
    ),
  ];

  static final List<HodThavvuPoint> _points = <HodThavvuPoint>[
    HodThavvuPoint(
      id: 'TP-VJA-001',
      siteId: 'SITE-VJA-001',
      siteName: 'Vijayawada River Bed',
      pointName: 'East Ramp Loading Point',
      assignedTo: 'Supervisor Rajesh',
      supervisorId: 'THV-SUP-001',
      supervisorName: 'Supervisor Rajesh',
      assignedAcres: 18,
      createdAt: DateTime(2026, 6, 15, 8, 15),
      status: 'Granted',
      grantedAt: DateTime(2026, 6, 15, 8, 20),
    ),
    HodThavvuPoint(
      id: 'TP-VJA-002',
      siteId: 'SITE-VJA-001',
      siteName: 'Vijayawada River Bed',
      pointName: 'River Sand Screening Point',
      assignedTo: 'Supervisor Rajesh',
      supervisorId: 'THV-SUP-001',
      supervisorName: 'Supervisor Rajesh',
      assignedAcres: 12,
      createdAt: DateTime(2026, 6, 15, 9, 00),
      status: 'Granted',
      grantedAt: DateTime(2026, 6, 15, 9, 05),
    ),
    HodThavvuPoint(
      id: 'TP-AKV-001',
      siteId: 'SITE-AKV-002',
      siteName: 'Akividu Canal Line',
      pointName: 'Canal Bund Earthwork Point',
      assignedTo: 'Supervisor Mohan',
      supervisorId: 'THV-SUP-002',
      supervisorName: 'Supervisor Mohan',
      assignedAcres: 10,
      createdAt: DateTime(2026, 6, 15, 9, 30),
      status: 'Granted',
      grantedAt: DateTime(2026, 6, 15, 9, 35),
    ),
  ];

  static final List<HodSupervisorActivity> _activities =
      <HodSupervisorActivity>[
    HodSupervisorActivity(
      id: 'ACT-001',
      supervisorId: 'THV-SUP-001',
      supervisorName: 'Supervisor Rajesh',
      siteId: 'SITE-VJA-001',
      siteName: 'Vijayawada River Bed',
      thavvuPointId: 'TP-VJA-001',
      thavvuPointName: 'East Ramp Loading Point',
      module: 'Machines',
      action: 'Diesel entry submitted',
      details: 'Vehicle diesel and opening stock entered for HOD review.',
      createdAt: DateTime(2026, 6, 15, 10, 10),
    ),
    HodSupervisorActivity(
      id: 'ACT-002',
      supervisorId: 'THV-SUP-002',
      supervisorName: 'Supervisor Mohan',
      siteId: 'SITE-AKV-002',
      siteName: 'Akividu Canal Line',
      thavvuPointId: 'TP-AKV-001',
      thavvuPointName: 'Canal Bund Earthwork Point',
      module: 'Cash',
      action: 'Cash request raised',
      details: 'Supervisor requested cash for active site expenses.',
      createdAt: DateTime(2026, 6, 15, 10, 25),
    ),
  ];

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (!_persistenceEnabled) {
      _loaded = true;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      final sitesJson = prefs.getString(_keySites);
      final pointsJson = prefs.getString(_keyPoints);
      final supervisorsJson = prefs.getString(_keySupervisors);
      final activitiesJson = prefs.getString(_keyActivities);

      if (sitesJson != null &&
          pointsJson != null &&
          supervisorsJson != null &&
          activitiesJson != null) {
        _adminSites
          ..clear()
          ..addAll((jsonDecode(sitesJson) as List).map((item) =>
              HodAdminSite.fromJson(Map<String, dynamic>.from(item))));
        _points
          ..clear()
          ..addAll((jsonDecode(pointsJson) as List).map((item) =>
              HodThavvuPoint.fromJson(Map<String, dynamic>.from(item))));
        _supervisors
          ..clear()
          ..addAll((jsonDecode(supervisorsJson) as List).map((item) =>
              HodSupervisorAccount.fromJson(Map<String, dynamic>.from(item))));
        _activities
          ..clear()
          ..addAll((jsonDecode(activitiesJson) as List).map((item) =>
              HodSupervisorActivity.fromJson(Map<String, dynamic>.from(item))));
      } else {
        await _persist();
      }
    } catch (_) {
      await _persist();
    }

    _loaded = true;
  }

  Future<void> _persist() async {
    if (!_persistenceEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySites,
      jsonEncode(_adminSites.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _keyPoints,
      jsonEncode(_points.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _keySupervisors,
      jsonEncode(_supervisors.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _keyActivities,
      jsonEncode(_activities.map((item) => item.toJson()).toList()),
    );
  }

  /// Real Supabase `profiles.id` UUIDs for supervisors, keyed by emp_id.
  /// Populated by [supervisors] when the backend is available; used to feed
  /// UUID-typed RPC params in [createThavvuPoint].
  final Map<String, String> _supervisorUuidByEmpId = {};

  /// Sites from the live backend (source of truth for a signed-in HOD),
  /// falling back to the local mirror only when Supabase is unavailable.
  Future<List<HodAdminSite>> adminCreatedSites() async {
    if (_supabaseReady()) {
      try {
        final rows = await Supabase.instance.client
            .from('sites')
            .select('*, thavvu_points(count)')
            .order('created_at', ascending: false);
        return rows
            .map((row) => HodAdminSite.fromDb(row))
            .toList(growable: false);
      } catch (_) {
        // Offline / dev — fall through to the local mirror below.
      }
    }
    await _ensureLoaded();
    return _adminSites
        .map((site) => site.copyWith(
              activePointCount:
                  _points.where((point) => point.siteId == site.id).length,
            ))
        .toList(growable: false);
  }

  /// Supervisors from the live backend (tenant-scoped by RLS on profiles),
  /// falling back to the local demo list only when Supabase is unavailable.
  Future<List<HodSupervisorAccount>> supervisors() async {
    if (_supabaseReady()) {
      try {
        final rows = await Supabase.instance.client
            .from('profiles')
            .select(
                'id, emp_id, full_name, email, phone, is_active, created_at')
            .eq('role', 'supervisor')
            .order('created_at', ascending: false);
        final supervisors =
            rows.map((row) => HodSupervisorAccount.fromDb(row)).toList();
        _supervisorUuidByEmpId.clear();
        for (final supervisor in supervisors) {
          if (supervisor.uuid.isNotEmpty && supervisor.id.isNotEmpty) {
            _supervisorUuidByEmpId[supervisor.id] = supervisor.uuid;
          }
        }
        return supervisors;
      } catch (_) {
        // Offline / dev — fall through to the local mirror below.
      }
    }
    await _ensureLoaded();
    return List<HodSupervisorAccount>.unmodifiable(_supervisors);
  }

  /// Thavvu Points for a site from the live backend (with the active
  /// assignment's supervisor and the owning site name embedded), falling
  /// back to the local mirror only when Supabase is unavailable.
  Future<List<HodThavvuPoint>> thavvuPointsForSite(String siteId) async {
    if (_supabaseReady()) {
      try {
        final rows = await Supabase.instance.client
            .from('thavvu_points')
            .select(
                '*, sites(name), thavvu_point_assignments!thavvu_point_assignments_thavvu_point_id_fkey(supervisor_id, is_active, profiles!thavvu_point_assignments_supervisor_id_fkey(full_name))')
            .eq('site_id', siteId)
            .order('created_at', ascending: true);
        return rows
            .map((row) => HodThavvuPoint.fromDb(row))
            .toList(growable: false);
      } catch (_) {
        // Offline / dev — fall through to the local mirror below.
      }
    }
    await _ensureLoaded();
    return _points
        .where((point) => point.siteId == siteId)
        .toList(growable: false);
  }

  Future<List<HodThavvuPoint>> grantedPointsForSupervisor(
    String supervisorId,
  ) async {
    await _ensureLoaded();
    return _points
        .where((point) => point.supervisorId == supervisorId && point.isGranted)
        .toList(growable: false);
  }

  Future<List<HodSupervisorActivity>> activitiesForPoint(String pointId) async {
    await _ensureLoaded();
    return _activities
        .where((activity) => activity.thavvuPointId == pointId)
        .toList(growable: false);
  }

  Future<List<HodSupervisorActivity>> activitiesForSupervisor(
    String supervisorId,
  ) async {
    await _ensureLoaded();
    return _activities
        .where((activity) => activity.supervisorId == supervisorId)
        .toList(growable: false);
  }

  Future<HodSupervisorAccount?> authenticateSupervisor({
    required String identifier,
    required String password,
  }) async {
    await _ensureLoaded();
    for (final supervisor in _supervisors) {
      if (supervisor.matchesLogin(identifier, password)) {
        return supervisor;
      }
    }
    return null;
  }

  /// True when the Supabase singleton has been initialized (production).
  /// Widget tests and early startup leave it uninitialized; callers then
  /// fall back to local-only behaviour instead of crashing.
  bool _supabaseReady() {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<HodSupervisorAccount> createSupervisor({
    required String name,
    required String email,
    required String phone,
    required String password,
    String createdByHodId = 'HOD-001',
    String? siteId,
    String? pointId,
  }) async {
    await _ensureLoaded();
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();
    final cleanPassword = password.trim();

    if (cleanName.length < 3) {
      throw ArgumentError('Enter a valid supervisor name.');
    }
    if (!cleanEmail.contains('@') || cleanEmail.length < 6) {
      throw ArgumentError('Enter a valid supervisor email.');
    }
    if (cleanPhone.length < 8) {
      throw ArgumentError('Enter a valid supervisor phone number.');
    }
    if (cleanPassword.length < 6) {
      throw ArgumentError('Password must be at least 6 characters.');
    }
    final duplicate = _supervisors.any(
      (item) => item.email.toLowerCase() == cleanEmail,
    );
    if (duplicate) {
      throw StateError('A supervisor already exists with this email.');
    }

    // ── REAL account provisioning (workflow fix) ────────────────────────
    // The created credentials must work on the actual login screen, which
    // authenticates against Supabase Auth. When Supabase is available we
    // create a real, email-confirmed auth user (+ identity + profile + the
    // optional site/point assignment) via the admin_create_supervisor RPC.
    // Only when Supabase is unavailable (widget tests, early startup) do we
    // fall back to the old local-only record so previews/tests keep working.
    String empId = 'THV-SUP-${(_supervisors.length + 1).toString().padLeft(3, '0')}';
    if (_supabaseReady()) {
      try {
        final response = await Supabase.instance.client
            .rpc('admin_create_supervisor', params: {
          'p_name': cleanName,
          'p_email': cleanEmail,
          'p_phone': cleanPhone,
          'p_password': cleanPassword,
          'p_site_id': siteId,
          'p_point_id': pointId,
        });
        final map = Map<String, dynamic>.from(response as Map);
        final createdEmpId = map['emp_id']?.toString().trim();
        if (createdEmpId != null && createdEmpId.isNotEmpty) {
          empId = createdEmpId;
        }
      } catch (e) {
        // Never silently create a phantom account: surface the real error
        // so the HOD knows the login was NOT provisioned.
        throw StateError(
          'Could not create the Supabase login. '
          '${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }

    final supervisor = HodSupervisorAccount(
      id: empId,
      name: cleanName,
      email: cleanEmail,
      phone: cleanPhone,
      password: cleanPassword,
      createdByHodId: createdByHodId,
    );
    _supervisors.insert(0, supervisor);
    await _persist();
    return supervisor;
  }

  Future<HodAdminSite> createSite({
    required String name,
    required String place,
    required String adminName,
    required double acres,
    String createdByHodId = 'HOD-001',
  }) async {
    await _ensureLoaded();
    final cleanName = name.trim();
    final cleanPlace = place.trim();
    final cleanAdminName = adminName.trim();

    if (cleanName.length < 3) {
      throw ArgumentError('Enter a valid site name.');
    }
    if (cleanPlace.length < 2) {
      throw ArgumentError('Enter a valid site place.');
    }
    if (cleanAdminName.length < 3) {
      throw ArgumentError('Enter the site admin name.');
    }
    if (acres <= 0) {
      throw ArgumentError('Site acres must be greater than zero.');
    }
    final duplicate = _adminSites.any(
      (site) => site.name.toLowerCase() == cleanName.toLowerCase(),
    );
    if (duplicate) {
      throw StateError('This site already exists.');
    }

    // ── REAL backend insert (enterprise) ────────────────────────────────
    // Creates a live `sites` row inside the caller's tenant via the
    // tenant-scoped admin_create_site RPC. RPC errors are rethrown so the
    // app never silently creates a phantom local-only site. When Supabase
    // is unavailable (widget tests, offline demo) we fall back to the old
    // local-only record so previews/tests keep working.
    String siteId = '';
    if (_supabaseReady()) {
      try {
        final response = await Supabase.instance.client.rpc(
          'admin_create_site',
          params: {
            'p_name': cleanName,
            'p_place': cleanPlace,
            'p_admin_name': cleanAdminName,
            'p_acres': acres,
          },
        );
        final map = Map<String, dynamic>.from(response as Map);
        siteId = map['id']?.toString() ?? '';
      } catch (e) {
        throw StateError(
          'Could not create the site. '
          '${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }

    final prefix = cleanPlace
        .replaceAll(RegExp(r'[^A-Za-z]'), '')
        .toUpperCase()
        .padRight(3, 'X')
        .substring(0, 3);
    final site = HodAdminSite(
      id: siteId.isNotEmpty
          ? siteId
          : 'SITE-$prefix-${(_adminSites.length + 1).toString().padLeft(3, '0')}',
      name: cleanName,
      place: cleanPlace,
      adminName: cleanAdminName,
      acres: acres,
      status: 'Ready for HOD planning',
      createdByHodId: createdByHodId,
    );
    _adminSites.insert(0, site);
    await _persist();
    return site;
  }

  Future<HodThavvuPoint> createThavvuPoint({
    required HodAdminSite site,
    required String pointName,
    required String supervisorId,
    required double assignedAcres,
  }) async {
    await _ensureLoaded();
    final cleanPointName = pointName.trim();

    if (cleanPointName.length < 3) {
      throw ArgumentError('Enter a valid Thavvu Point name.');
    }
    if (assignedAcres <= 0) {
      throw ArgumentError('Supervisor acres must be greater than zero.');
    }
    if (assignedAcres > site.acres) {
      throw ArgumentError('Supervisor acres cannot exceed site acres.');
    }
    HodSupervisorAccount? supervisor;
    for (final item in _supervisors) {
      if (item.id == supervisorId && item.active) {
        supervisor = item;
        break;
      }
    }
    if (supervisor == null) {
      throw ArgumentError('Select an active supervisor.');
    }

    final duplicate = _points.any(
      (point) =>
          point.siteId == site.id &&
          point.pointName.toLowerCase() == cleanPointName.toLowerCase(),
    );
    if (duplicate) {
      throw StateError(
          'This Thavvu Point already exists for the selected site.');
    }

    // ── REAL backend insert (enterprise) ────────────────────────────────
    // Creates a live `thavvu_points` row + active assignment + site
    // membership inside the caller's tenant via the tenant-scoped
    // admin_create_thavvu_point RPC. The supervisor must be resolved to
    // their real `profiles.id` UUID first. RPC errors are rethrown so no
    // phantom local-only point is created. When Supabase is unavailable
    // (widget tests, offline demo) we fall back to local-only behaviour.
    String pointId = '';
    if (_supabaseReady()) {
      final supervisorUuid = await _resolveSupervisorUuid(supervisorId);
      if (supervisorUuid == null) {
        throw StateError(
          'Supervisor profile not found in the backend. '
          'Create the supervisor login first.',
        );
      }
      try {
        final response = await Supabase.instance.client.rpc(
          'admin_create_thavvu_point',
          params: {
            'p_site_id': site.id,
            'p_point_name': cleanPointName,
            'p_assigned_acres': assignedAcres,
            'p_supervisor_id': supervisorUuid,
          },
        );
        final map = Map<String, dynamic>.from(response as Map);
        pointId = map['id']?.toString() ?? '';
      } catch (e) {
        throw StateError(
          'Could not create the Thavvu Point. '
          '${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }

    final prefix = site.place
        .replaceAll(RegExp(r'[^A-Za-z]'), '')
        .toUpperCase()
        .padRight(3, 'X')
        .substring(0, 3);
    final point = HodThavvuPoint(
      id: pointId.isNotEmpty
          ? pointId
          : 'TP-$prefix-${(_points.length + 1).toString().padLeft(3, '0')}',
      siteId: site.id,
      siteName: site.name,
      pointName: cleanPointName,
      assignedTo: supervisor.name,
      supervisorId: supervisor.id,
      supervisorName: supervisor.name,
      assignedAcres: assignedAcres,
      status: 'Draft',
    );
    _points.insert(0, point);
    await _persist();
    return point;
  }

  /// Resolves [idOrUuid] (a `profiles.id` UUID or a human-readable emp_id
  /// such as `THV-SUP-001`) to the real `profiles.id` UUID. Checks the
  /// cached emp_id map first (populated by [supervisors]), then queries
  /// `profiles` directly. Returns null when the profile cannot be found.
  Future<String?> _resolveSupervisorUuid(String idOrUuid) async {
    if (idOrUuid.isEmpty) return null;
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidPattern.hasMatch(idOrUuid)) return idOrUuid;
    final cached = _supervisorUuidByEmpId[idOrUuid];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('emp_id', idOrUuid)
          .limit(1);
      if (rows.isNotEmpty) {
        final id = rows.first['id'] as String?;
        if (id != null && id.isNotEmpty) {
          _supervisorUuidByEmpId[idOrUuid] = id;
          return id;
        }
      }
    } catch (_) {
      // Offline — the caller decides how to surface this.
    }
    return null;
  }

  Future<HodThavvuPoint> grantThavvuPoint(String pointId) async {
    await _ensureLoaded();

    // ── REAL backend grant (enterprise) ─────────────────────────────────
    // Flips the live `thavvu_points.status` draft → granted with
    // granted_at/granted_by via the tenant-scoped admin_grant_thavvu_point
    // RPC. RPC errors are rethrown so the UI never shows a false success.
    if (_supabaseReady()) {
      try {
        await Supabase.instance.client.rpc(
          'admin_grant_thavvu_point',
          params: {'p_point_id': pointId},
        );
      } catch (e) {
        throw StateError(
          'Could not grant the Thavvu Point. '
          '${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }

    final index = _points.indexWhere((point) => point.id == pointId);
    if (index == -1) {
      if (_supabaseReady()) {
        // Backend-loaded point that has no local mirror row. The backend
        // grant already succeeded; return a status-carrying value so the
        // caller's reload (which refetches from Supabase) shows it granted.
        return HodThavvuPoint(
          id: pointId,
          siteId: '',
          siteName: '',
          pointName: '',
          assignedTo: '',
          status: 'Granted',
          grantedAt: DateTime.now(),
        );
      }
      throw StateError('Thavvu Point not found.');
    }
    final point = _points[index].copyWith(
      status: 'Granted',
      grantedAt: DateTime.now(),
      grantedByHodId: 'HOD-001',
    );
    _points[index] = point;
    _activities.insert(
      0,
      HodSupervisorActivity(
        id: 'ACT-${(_activities.length + 1).toString().padLeft(3, '0')}',
        supervisorId: point.supervisorId,
        supervisorName: point.supervisorName,
        siteId: point.siteId,
        siteName: point.siteName,
        thavvuPointId: point.id,
        thavvuPointName: point.pointName,
        module: 'Planning',
        action: 'Thavvu Point granted',
        details:
            '${point.acresLabel} granted to ${point.supervisorName} by HOD.',
      ),
    );
    await _persist();
    return point;
  }

  Future<HodThavvuPoint> reassignThavvuPoint(
      String pointId, String newSupervisorId) async {
    await _ensureLoaded();
    final index = _points.indexWhere((point) => point.id == pointId);
    if (index == -1) {
      throw StateError('Thavvu Point not found.');
    }

    final newSupervisor = _supervisors.firstWhere(
      (s) => s.id == newSupervisorId,
      orElse: () => throw ArgumentError('Supervisor not found.'),
    );

    final oldSupervisorName = _points[index].supervisorName;
    final point = _points[index].copyWith(
      supervisorId: newSupervisor.id,
      supervisorName: newSupervisor.name,
      assignedTo: newSupervisor.name,
    );

    _points[index] = point;

    _activities.insert(
      0,
      HodSupervisorActivity(
        id: 'ACT-${(_activities.length + 1).toString().padLeft(3, '0')}',
        supervisorId: newSupervisor.id,
        supervisorName: newSupervisor.name,
        siteId: point.siteId,
        siteName: point.siteName,
        thavvuPointId: point.id,
        thavvuPointName: point.pointName,
        module: 'Planning',
        action: 'Thavvu Point reassigned',
        details: 'Reassigned from $oldSupervisorName to ${newSupervisor.name} by HOD.',
      ),
    );
    await _persist();
    return point;
  }

  Future<void> recordSupervisorActivityForCurrentSession({
    required String module,
    required String action,
    required String details,
  }) async {
    final userData = await AuthService.getUserData();
    final supervisorId = userData['empId'] ?? '';
    if (supervisorId.isEmpty) return;

    final points = await grantedPointsForSupervisor(supervisorId);
    if (points.isEmpty) return;

    await recordSupervisorActivity(
      point: points.first,
      module: module,
      action: action,
      details: details,
    );
  }

  Future<void> recordSupervisorActivity({
    required HodThavvuPoint point,
    required String module,
    required String action,
    required String details,
  }) async {
    await _ensureLoaded();
    _activities.insert(
      0,
      HodSupervisorActivity(
        id: 'ACT-${(_activities.length + 1).toString().padLeft(3, '0')}',
        supervisorId: point.supervisorId,
        supervisorName: point.supervisorName,
        siteId: point.siteId,
        siteName: point.siteName,
        thavvuPointId: point.id,
        thavvuPointName: point.pointName,
        module: module.trim().isEmpty ? 'General' : module.trim(),
        action: action.trim().isEmpty ? 'Updated work data' : action.trim(),
        details: details.trim().isEmpty
            ? 'Supervisor activity captured for HOD review.'
            : details.trim(),
      ),
    );
    await _persist();
  }

  Future<List<HodWorkHistoryRow>> workHistoryRows() async {
    await _ensureLoaded();
    final rows = <HodWorkHistoryRow>[
      ..._activities.take(12).map(
            (activity) => HodWorkHistoryRow(
              siteName: activity.siteName,
              pointName: activity.thavvuPointName,
              module: activity.module,
              assignedTo: activity.supervisorName,
              status: activity.action,
              updatedAt: activity.createdAt,
              icon: _iconForModule(activity.module),
              color: _colorForModule(activity.module),
            ),
          ),
      ..._points.take(5).map(
            (point) => HodWorkHistoryRow(
              siteName: point.siteName,
              pointName: point.pointName,
              module: 'Planning',
              assignedTo: point.supervisorName,
              status: point.status,
              updatedAt: point.grantedAt ?? point.createdAt,
              icon: Icons.account_tree_rounded,
              color: const Color(0xFF1565C0),
            ),
          ),
    ];
    return rows;
  }

  IconData _iconForModule(String module) {
    switch (module.toLowerCase()) {
      case 'machines':
        return Icons.construction_rounded;
      case 'cash':
        return Icons.account_balance_wallet_outlined;
      case 'food':
        return Icons.restaurant_menu_outlined;
      case 'tasks':
        return Icons.task_alt_outlined;
      case 'daily data':
        return Icons.edit_calendar_rounded;
      default:
        return Icons.account_tree_rounded;
    }
  }

  Color _colorForModule(String module) {
    switch (module.toLowerCase()) {
      case 'machines':
        return const Color(0xFFD97706);
      case 'cash':
        return const Color(0xFF0FA37A);
      case 'food':
        return const Color(0xFFE6A817);
      case 'tasks':
        return const Color(0xFF0FA37A);
      case 'daily data':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFF1565C0);
    }
  }

  static void resetForTests() {
    _persistenceEnabled = false;
    _loaded = true;
    _adminSites
      ..clear()
      ..addAll([
        HodAdminSite(
          id: 'SITE-VJA-001',
          name: 'Vijayawada River Bed',
          place: 'Vijayawada',
          adminName: 'Admin Prakash',
          acres: 48,
          status: 'Ready for HOD planning',
          activePointCount: 2,
          createdAt: DateTime(2026, 6, 14, 10, 30),
        ),
        HodAdminSite(
          id: 'SITE-AKV-002',
          name: 'Akividu Canal Line',
          place: 'Akividu',
          adminName: 'Admin Kavitha',
          acres: 26,
          status: 'Ready for HOD planning',
          activePointCount: 1,
          createdAt: DateTime(2026, 6, 14, 11, 15),
        ),
      ]);
    _supervisors
      ..clear()
      ..addAll([
        HodSupervisorAccount(
          id: 'THV-SUP-001',
          name: 'Supervisor Rajesh',
          email: 'supervisor@thavvu.com',
          phone: '+91 98765 43210',
          password: 'super123',
          createdAt: DateTime(2026, 6, 14, 12, 30),
        ),
        HodSupervisorAccount(
          id: 'THV-SUP-002',
          name: 'Supervisor Mohan',
          email: 'mohan@thavvu.com',
          phone: '+91 98765 43211',
          password: 'mohan123',
          createdAt: DateTime(2026, 6, 14, 12, 45),
        ),
      ]);
    _points
      ..clear()
      ..addAll([
        HodThavvuPoint(
          id: 'TP-VJA-001',
          siteId: 'SITE-VJA-001',
          siteName: 'Vijayawada River Bed',
          pointName: 'East Ramp Loading Point',
          assignedTo: 'Supervisor Rajesh',
          supervisorId: 'THV-SUP-001',
          supervisorName: 'Supervisor Rajesh',
          assignedAcres: 18,
          createdAt: DateTime(2026, 6, 15, 8, 15),
          status: 'Granted',
          grantedAt: DateTime(2026, 6, 15, 8, 20),
        ),
        HodThavvuPoint(
          id: 'TP-AKV-001',
          siteId: 'SITE-AKV-002',
          siteName: 'Akividu Canal Line',
          pointName: 'Canal Bund Earthwork Point',
          assignedTo: 'Supervisor Mohan',
          supervisorId: 'THV-SUP-002',
          supervisorName: 'Supervisor Mohan',
          assignedAcres: 10,
          createdAt: DateTime(2026, 6, 15, 9, 30),
          status: 'Granted',
          grantedAt: DateTime(2026, 6, 15, 9, 35),
        ),
      ]);
    _activities
      ..clear()
      ..addAll([
        HodSupervisorActivity(
          id: 'ACT-001',
          supervisorId: 'THV-SUP-001',
          supervisorName: 'Supervisor Rajesh',
          siteId: 'SITE-VJA-001',
          siteName: 'Vijayawada River Bed',
          thavvuPointId: 'TP-VJA-001',
          thavvuPointName: 'East Ramp Loading Point',
          module: 'Machines',
          action: 'Diesel entry submitted',
          details: 'Vehicle diesel and opening stock entered for HOD review.',
          createdAt: DateTime(2026, 6, 15, 10, 10),
        ),
      ]);
  }
}
