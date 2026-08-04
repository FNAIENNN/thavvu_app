import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<List<HodAdminSite>> adminCreatedSites() async {
    await _ensureLoaded();
    return _adminSites
        .map((site) => site.copyWith(
              activePointCount:
                  _points.where((point) => point.siteId == site.id).length,
            ))
        .toList(growable: false);
  }

  Future<List<HodSupervisorAccount>> supervisors() async {
    await _ensureLoaded();
    return List<HodSupervisorAccount>.unmodifiable(_supervisors);
  }

  Future<List<HodThavvuPoint>> thavvuPointsForSite(String siteId) async {
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

  Future<HodSupervisorAccount> createSupervisor({
    required String name,
    required String email,
    required String phone,
    required String password,
    String createdByHodId = 'HOD-001',
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

    final supervisor = HodSupervisorAccount(
      id: 'THV-SUP-${(_supervisors.length + 1).toString().padLeft(3, '0')}',
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

    final prefix = cleanPlace
        .replaceAll(RegExp(r'[^A-Za-z]'), '')
        .toUpperCase()
        .padRight(3, 'X')
        .substring(0, 3);
    final site = HodAdminSite(
      id: 'SITE-$prefix-${(_adminSites.length + 1).toString().padLeft(3, '0')}',
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

    final prefix = site.place
        .replaceAll(RegExp(r'[^A-Za-z]'), '')
        .toUpperCase()
        .padRight(3, 'X')
        .substring(0, 3);
    final point = HodThavvuPoint(
      id: 'TP-$prefix-${(_points.length + 1).toString().padLeft(3, '0')}',
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

  Future<HodThavvuPoint> grantThavvuPoint(String pointId) async {
    await _ensureLoaded();
    final index = _points.indexWhere((point) => point.id == pointId);
    if (index == -1) {
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
