enum ThavvuRole {
  hod,
  supervisor,
  finance,
  admin,
}

enum ApprovalStatus {
  pending,
  approved,
  rejected,
  revisionRequested,
  cancelled,
}

ThavvuRole thavvuRoleFromJson(String value) {
  return ThavvuRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => ThavvuRole.supervisor,
  );
}

ApprovalStatus approvalStatusFromJson(String value) {
  return ApprovalStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => ApprovalStatus.pending,
  );
}

class ThavvuUser {
  final String id;
  final String name;
  final ThavvuRole role;
  final List<String> assignedSiteIds;
  final bool active;

  const ThavvuUser({
    required this.id,
    required this.name,
    required this.role,
    required this.assignedSiteIds,
    this.active = true,
  });

  factory ThavvuUser.fromJson(Map<String, dynamic> json) {
    return ThavvuUser(
      id: json['id'] as String,
      name: json['name'] as String,
      role: thavvuRoleFromJson(json['role'] as String? ?? 'supervisor'),
      assignedSiteIds: (json['assignedSiteIds'] as List<dynamic>? ?? const [])
          .map((value) => value as String)
          .toList(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'assignedSiteIds': assignedSiteIds,
        'active': active,
      };

  bool canAccessSite(String siteId) => assignedSiteIds.contains(siteId);
}

class ThavvuSite {
  final String id;
  final String name;
  final String place;
  final bool active;

  const ThavvuSite({
    required this.id,
    required this.name,
    required this.place,
    this.active = true,
  });

  factory ThavvuSite.fromJson(Map<String, dynamic> json) {
    return ThavvuSite(
      id: json['id'] as String,
      name: json['name'] as String,
      place: json['place'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'place': place,
        'active': active,
      };
}

class ApprovalRequestRecord {
  final String id;
  final String module;
  final String title;
  final String siteId;
  final String supervisorId;
  final ApprovalStatus status;
  final DateTime createdAt;
  final String? actedById;
  final DateTime? actedAt;
  final String? actionNote;
  final Map<String, dynamic> payload;

  const ApprovalRequestRecord({
    required this.id,
    required this.module,
    required this.title,
    required this.siteId,
    required this.supervisorId,
    required this.status,
    required this.createdAt,
    this.actedById,
    this.actedAt,
    this.actionNote,
    this.payload = const {},
  });

  factory ApprovalRequestRecord.fromJson(Map<String, dynamic> json) {
    return ApprovalRequestRecord(
      id: json['id'] as String,
      module: json['module'] as String,
      title: json['title'] as String,
      siteId: json['siteId'] as String,
      supervisorId: json['supervisorId'] as String,
      status: approvalStatusFromJson(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      actedById: json['actedById'] as String?,
      actedAt: json['actedAt'] == null
          ? null
          : DateTime.parse(json['actedAt'] as String),
      actionNote: json['actionNote'] as String?,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'module': module,
        'title': title,
        'siteId': siteId,
        'supervisorId': supervisorId,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'actedById': actedById,
        'actedAt': actedAt?.toIso8601String(),
        'actionNote': actionNote,
        'payload': payload,
      };

  ApprovalRequestRecord copyWith({
    ApprovalStatus? status,
    String? actedById,
    DateTime? actedAt,
    String? actionNote,
    Map<String, dynamic>? payload,
  }) {
    return ApprovalRequestRecord(
      id: id,
      module: module,
      title: title,
      siteId: siteId,
      supervisorId: supervisorId,
      status: status ?? this.status,
      createdAt: createdAt,
      actedById: actedById ?? this.actedById,
      actedAt: actedAt ?? this.actedAt,
      actionNote: actionNote ?? this.actionNote,
      payload: payload ?? this.payload,
    );
  }
}

class HodMapUploadRecord {
  final String id;
  final String siteId;
  final String? thavvuPointId;
  final String uploadedById;
  final String title;
  final String note;
  final String fileName;
  final String fileType;
  final String filePath;
  final DateTime uploadedAt;

  const HodMapUploadRecord({
    required this.id,
    required this.siteId,
    this.thavvuPointId,
    required this.uploadedById,
    required this.title,
    required this.note,
    required this.fileName,
    required this.fileType,
    required this.filePath,
    required this.uploadedAt,
  });

  factory HodMapUploadRecord.fromJson(Map<String, dynamic> json) {
    return HodMapUploadRecord(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      thavvuPointId: json['thavvuPointId'] as String?,
      uploadedById: json['uploadedById'] as String,
      title: json['title'] as String,
      note: json['note'] as String? ?? '',
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String,
      filePath: json['filePath'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteId': siteId,
        'uploadedById': uploadedById,
        'title': title,
        'note': note,
        'fileName': fileName,
        'fileType': fileType,
        'filePath': filePath,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  bool get isPdf => fileType.toLowerCase() == 'pdf';
  bool get isImage => {'jpg', 'jpeg', 'png'}.contains(fileType.toLowerCase());
}

class SupervisorActionRecord {
  final String id;
  final String supervisorId;
  final String siteId;
  final String module;
  final String action;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  const SupervisorActionRecord({
    required this.id,
    required this.supervisorId,
    required this.siteId,
    required this.module,
    required this.action,
    required this.description,
    required this.createdAt,
    this.payload = const {},
  });

  factory SupervisorActionRecord.fromJson(Map<String, dynamic> json) {
    return SupervisorActionRecord(
      id: json['id'] as String,
      supervisorId: json['supervisorId'] as String,
      siteId: json['siteId'] as String,
      module: json['module'] as String,
      action: json['action'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'supervisorId': supervisorId,
        'siteId': siteId,
        'module': module,
        'action': action,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'payload': payload,
      };
}

class HodDashboardSummary {
  final int totalRequests;
  final int pendingRequests;
  final Map<ApprovalStatus, int> statusCounts;
  final Map<String, int> moduleCounts;
  final Map<String, int> supervisorCounts;
  final List<ApprovalRequestRecord> recentRequests;
  final List<SupervisorActionRecord> recentSupervisorActions;

  const HodDashboardSummary({
    required this.totalRequests,
    required this.pendingRequests,
    required this.statusCounts,
    required this.moduleCounts,
    required this.supervisorCounts,
    required this.recentRequests,
    required this.recentSupervisorActions,
  });
}

class AuditLogRecord {
  final String id;
  final String actorId;
  final String entityType;
  final String entityId;
  final String action;
  final String oldValue;
  final String newValue;
  final String? note;
  final DateTime createdAt;

  const AuditLogRecord({
    required this.id,
    required this.actorId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.oldValue,
    required this.newValue,
    required this.createdAt,
    this.note,
  });

  factory AuditLogRecord.fromJson(Map<String, dynamic> json) {
    return AuditLogRecord(
      id: json['id'] as String,
      actorId: json['actorId'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      action: json['action'] as String,
      oldValue: json['oldValue'] as String,
      newValue: json['newValue'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'actorId': actorId,
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'oldValue': oldValue,
        'newValue': newValue,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };
}
