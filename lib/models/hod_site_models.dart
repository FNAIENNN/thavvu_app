import 'package:flutter/material.dart';

class HodAdminSite {
  final String id;
  final String name;
  final String place;
  final String adminName;
  final double acres;
  final String status;
  final int activePointCount;
  final DateTime createdAt;
  final String createdByHodId;

  HodAdminSite({
    required this.id,
    required this.name,
    required this.place,
    required this.adminName,
    required this.acres,
    required this.status,
    this.activePointCount = 0,
    DateTime? createdAt,
    this.createdByHodId = 'HOD-001',
  }) : createdAt = createdAt ?? DateTime.now();

  factory HodAdminSite.fromJson(Map<String, dynamic> json) {
    return HodAdminSite(
      id: json['id'] as String,
      name: json['name'] as String,
      place: json['place'] as String,
      adminName: json['adminName'] as String? ?? 'HOD Admin',
      acres: (json['acres'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'Ready for HOD planning',
      activePointCount: json['activePointCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      createdByHodId: json['createdByHodId'] as String? ?? 'HOD-001',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'place': place,
        'adminName': adminName,
        'acres': acres,
        'status': status,
        'activePointCount': activePointCount,
        'createdAt': createdAt.toIso8601String(),
        'createdByHodId': createdByHodId,
      };

  String get acresLabel {
    if (acres == acres.roundToDouble()) {
      return '${acres.toStringAsFixed(0)} acres';
    }
    return '${acres.toStringAsFixed(1)} acres';
  }

  HodAdminSite copyWith({
    String? id,
    String? name,
    String? place,
    String? adminName,
    double? acres,
    String? status,
    int? activePointCount,
    DateTime? createdAt,
    String? createdByHodId,
  }) {
    return HodAdminSite(
      id: id ?? this.id,
      name: name ?? this.name,
      place: place ?? this.place,
      adminName: adminName ?? this.adminName,
      acres: acres ?? this.acres,
      status: status ?? this.status,
      activePointCount: activePointCount ?? this.activePointCount,
      createdAt: createdAt ?? this.createdAt,
      createdByHodId: createdByHodId ?? this.createdByHodId,
    );
  }
}

class HodThavvuPoint {
  final String id;
  final String siteId;
  final String siteName;
  final String pointName;
  final String assignedTo;
  final String supervisorId;
  final String supervisorName;
  final double assignedAcres;
  final DateTime createdAt;
  final String status;
  final DateTime? grantedAt;
  final String grantedByHodId;

  HodThavvuPoint({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.pointName,
    required this.assignedTo,
    this.supervisorId = '',
    String? supervisorName,
    this.assignedAcres = 0,
    DateTime? createdAt,
    this.status = 'Draft',
    this.grantedAt,
    this.grantedByHodId = 'HOD-001',
  })  : supervisorName = supervisorName ?? assignedTo,
        createdAt = createdAt ?? DateTime.now();

  factory HodThavvuPoint.fromJson(Map<String, dynamic> json) {
    final assignedTo = json['assignedTo'] as String? ??
        json['supervisorName'] as String? ??
        'Unassigned';
    return HodThavvuPoint(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      siteName: json['siteName'] as String,
      pointName: json['pointName'] as String,
      assignedTo: assignedTo,
      supervisorId: json['supervisorId'] as String? ?? '',
      supervisorName: json['supervisorName'] as String? ?? assignedTo,
      assignedAcres: (json['assignedAcres'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'Active',
      grantedAt: DateTime.tryParse(json['grantedAt'] as String? ?? ''),
      grantedByHodId: json['grantedByHodId'] as String? ?? 'HOD-001',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteId': siteId,
        'siteName': siteName,
        'pointName': pointName,
        'assignedTo': assignedTo,
        'supervisorId': supervisorId,
        'supervisorName': supervisorName,
        'assignedAcres': assignedAcres,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'grantedAt': grantedAt?.toIso8601String(),
        'grantedByHodId': grantedByHodId,
      };

  bool get isGranted => status.toLowerCase() == 'granted' || status == 'Active';

  String get acresLabel {
    if (assignedAcres <= 0) return 'Acres not set';
    if (assignedAcres == assignedAcres.roundToDouble()) {
      return '${assignedAcres.toStringAsFixed(0)} acres';
    }
    return '${assignedAcres.toStringAsFixed(1)} acres';
  }

  HodThavvuPoint copyWith({
    String? id,
    String? siteId,
    String? siteName,
    String? pointName,
    String? assignedTo,
    String? supervisorId,
    String? supervisorName,
    double? assignedAcres,
    DateTime? createdAt,
    String? status,
    DateTime? grantedAt,
    String? grantedByHodId,
  }) {
    return HodThavvuPoint(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      pointName: pointName ?? this.pointName,
      assignedTo: assignedTo ?? this.assignedTo,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      assignedAcres: assignedAcres ?? this.assignedAcres,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      grantedAt: grantedAt ?? this.grantedAt,
      grantedByHodId: grantedByHodId ?? this.grantedByHodId,
    );
  }
}

class HodSupervisorAccount {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password;
  final bool active;
  final DateTime createdAt;
  final String createdByHodId;

  HodSupervisorAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.active = true,
    DateTime? createdAt,
    this.createdByHodId = 'HOD-001',
  }) : createdAt = createdAt ?? DateTime.now();

  factory HodSupervisorAccount.fromJson(Map<String, dynamic> json) {
    return HodSupervisorAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      password: json['password'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      createdByHodId: json['createdByHodId'] as String? ?? 'HOD-001',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        'createdByHodId': createdByHodId,
      };

  bool matchesLogin(String identifier, String candidatePassword) {
    final clean = identifier.trim().toLowerCase();
    return active &&
        password == candidatePassword &&
        (id.toLowerCase() == clean || email.toLowerCase() == clean);
  }
}

class HodSupervisorActivity {
  final String id;
  final String supervisorId;
  final String supervisorName;
  final String siteId;
  final String siteName;
  final String thavvuPointId;
  final String thavvuPointName;
  final String module;
  final String action;
  final String details;
  final DateTime createdAt;

  HodSupervisorActivity({
    required this.id,
    required this.supervisorId,
    required this.supervisorName,
    required this.siteId,
    required this.siteName,
    required this.thavvuPointId,
    required this.thavvuPointName,
    required this.module,
    required this.action,
    required this.details,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory HodSupervisorActivity.fromJson(Map<String, dynamic> json) {
    return HodSupervisorActivity(
      id: json['id'] as String,
      supervisorId: json['supervisorId'] as String,
      supervisorName: json['supervisorName'] as String,
      siteId: json['siteId'] as String,
      siteName: json['siteName'] as String,
      thavvuPointId: json['thavvuPointId'] as String,
      thavvuPointName: json['thavvuPointName'] as String,
      module: json['module'] as String,
      action: json['action'] as String,
      details: json['details'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'supervisorId': supervisorId,
        'supervisorName': supervisorName,
        'siteId': siteId,
        'siteName': siteName,
        'thavvuPointId': thavvuPointId,
        'thavvuPointName': thavvuPointName,
        'module': module,
        'action': action,
        'details': details,
        'createdAt': createdAt.toIso8601String(),
      };
}

class HodWorkHistoryRow {
  final String siteName;
  final String pointName;
  final String module;
  final String assignedTo;
  final String status;
  final DateTime updatedAt;
  final IconData icon;
  final Color color;

  const HodWorkHistoryRow({
    required this.siteName,
    required this.pointName,
    required this.module,
    required this.assignedTo,
    required this.status,
    required this.updatedAt,
    required this.icon,
    required this.color,
  });
}
