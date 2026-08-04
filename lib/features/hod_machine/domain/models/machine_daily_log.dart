import 'machine_diesel_line.dart';

/// Status of a daily machine log in the HOD review workflow.
enum DailyLogStatus {
  draft,
  submitted,
  approved,
  revisionRequested,
  rejected;

  String get apiValue {
    switch (this) {
      case DailyLogStatus.draft:
        return 'draft';
      case DailyLogStatus.submitted:
        return 'submitted';
      case DailyLogStatus.approved:
        return 'approved';
      case DailyLogStatus.revisionRequested:
        return 'revision_requested';
      case DailyLogStatus.rejected:
        return 'rejected';
    }
  }

  static DailyLogStatus fromApi(String value) {
    switch (value) {
      case 'draft':
        return DailyLogStatus.draft;
      case 'submitted':
        return DailyLogStatus.submitted;
      case 'approved':
        return DailyLogStatus.approved;
      case 'revision_requested':
        return DailyLogStatus.revisionRequested;
      case 'rejected':
        return DailyLogStatus.rejected;
      default:
        return DailyLogStatus.draft;
    }
  }

  String get displayLabel {
    switch (this) {
      case DailyLogStatus.draft:
        return 'Draft';
      case DailyLogStatus.submitted:
        return 'Pending Review';
      case DailyLogStatus.approved:
        return 'Approved';
      case DailyLogStatus.revisionRequested:
        return 'Revision Needed';
      case DailyLogStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Daily machine log — mirrors `machine_daily_logs` table.
class MachineDailyLog {
  final String id;
  final DateTime logDate;
  final String siteId;
  final String thavvuPointId;
  final String supervisorId;
  final String machineId;
  final String? machineAssignmentId;
  final String? location;
  final String? dieselOption;
  final double workingHours;
  final int workerCount;
  final double betaAmount;
  final double extraBetaAmount;
  final String? notes;
  final String? billFilePath;
  final DailyLogStatus status;
  final String? hodId;
  final String? hodNote;
  final DateTime? reviewedAt;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MachineDieselLine> dieselLines;

  MachineDailyLog({
    required this.id,
    required this.logDate,
    required this.siteId,
    required this.thavvuPointId,
    required this.supervisorId,
    required this.machineId,
    this.machineAssignmentId,
    this.location,
    this.dieselOption,
    this.workingHours = 0,
    this.workerCount = 0,
    this.betaAmount = 0,
    this.extraBetaAmount = 0,
    this.notes,
    this.billFilePath,
    this.status = DailyLogStatus.draft,
    this.hodId,
    this.hodNote,
    this.reviewedAt,
    this.submittedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.dieselLines = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get dieselLiters =>
      dieselLines.fold<double>(0, (s, l) => s + l.liters);

  double get dieselAmount =>
      dieselLines.fold<double>(0, (s, l) => s + l.amount);

  factory MachineDailyLog.fromJson(Map<String, dynamic> json) {
    return MachineDailyLog(
      id: json['id'] as String,
      logDate: DateTime.parse(json['log_date'] as String),
      siteId: json['site_id'] as String,
      thavvuPointId: json['thavvu_point_id'] as String,
      supervisorId: json['supervisor_id'] as String,
      machineId: json['machine_id'] as String,
      machineAssignmentId: json['machine_assignment_id'] as String?,
      location: json['location'] as String?,
      dieselOption: json['diesel_option'] as String?,
      workingHours: (json['working_hours'] as num?)?.toDouble() ?? 0,
      workerCount: (json['worker_count'] as int?) ?? 0,
      betaAmount: (json['beta_amount'] as num?)?.toDouble() ?? 0,
      extraBetaAmount: (json['extra_beta_amount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      billFilePath: json['bill_file_path'] as String?,
      status: DailyLogStatus.fromApi(json['status'] as String? ?? 'draft'),
      hodId: json['hod_id'] as String?,
      hodNote: json['hod_note'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      dieselLines: (json['diesel_lines'] as List<dynamic>?)
              ?.map(
                  (e) => MachineDieselLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'log_date': logDate.toIso8601String(),
    'site_id': siteId,
    'thavvu_point_id': thavvuPointId,
    'supervisor_id': supervisorId,
    'machine_id': machineId,
    'machine_assignment_id': machineAssignmentId,
    'location': location,
    'diesel_option': dieselOption,
    'working_hours': workingHours,
    'worker_count': workerCount,
    'beta_amount': betaAmount,
    'extra_beta_amount': extraBetaAmount,
    'notes': notes,
    'bill_file_path': billFilePath,
    'status': status.apiValue,
    'hod_id': hodId,
    'hod_note': hodNote,
    'reviewed_at': reviewedAt?.toIso8601String(),
    'submitted_at': submittedAt?.toIso8601String(),
  };

  MachineDailyLog copyWith({
    String? hodId,
    String? hodNote,
    DateTime? reviewedAt,
    DailyLogStatus? status,
    List<MachineDieselLine>? dieselLines,
  }) {
    return MachineDailyLog(
      id: id,
      logDate: logDate,
      siteId: siteId,
      thavvuPointId: thavvuPointId,
      supervisorId: supervisorId,
      machineId: machineId,
      machineAssignmentId: machineAssignmentId,
      location: location,
      dieselOption: dieselOption,
      workingHours: workingHours,
      workerCount: workerCount,
      betaAmount: betaAmount,
      extraBetaAmount: extraBetaAmount,
      notes: notes,
      billFilePath: billFilePath,
      status: status ?? this.status,
      hodId: hodId ?? this.hodId,
      hodNote: hodNote ?? this.hodNote,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      submittedAt: submittedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      dieselLines: dieselLines ?? this.dieselLines,
    );
  }
}
