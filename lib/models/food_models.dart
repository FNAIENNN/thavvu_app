/// Domain models for the Thavvu food module.
///
/// These mirror the Supabase tables created in
/// `supabase/migrations/00005_attendance_food.sql`:
///   food_requests, food_submissions.
library;

/// One row in `food_requests` — "who needs food" on a given day.
///
/// Attendance writes these (derived from each worker/batch `food_opt_in`);
/// the food module reads them. Category: regular / outside / machine /
/// guest / other.
class FoodRequest {
  final String? id;
  final String? siteId;
  final String? thavvuPointId;
  final DateTime attendanceDate;
  final String category;
  final String? workerId; // set for regular workers
  final String? batchWorkerId; // set for outside workers
  final String name; // denormalized snapshot for display
  final String status; // pending / submitted / cancelled
  final DateTime? createdAt;

  const FoodRequest({
    this.id,
    this.siteId,
    this.thavvuPointId,
    required this.attendanceDate,
    required this.category,
    this.workerId,
    this.batchWorkerId,
    required this.name,
    this.status = 'pending',
    this.createdAt,
  });

  factory FoodRequest.fromJson(Map<String, dynamic> json) {
    return FoodRequest(
      id: json['id'] as String?,
      siteId: json['site_id'] as String?,
      thavvuPointId: json['thavvu_point_id'] as String?,
      attendanceDate:
          DateTime.tryParse(json['attendance_date'] as String) ??
              DateTime.now(),
      category: json['category'] as String? ?? 'other',
      workerId: json['worker_id'] as String?,
      batchWorkerId: json['batch_worker_id'] as String?,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'thavvu_point_id': thavvuPointId,
      'attendance_date':
          attendanceDate.toIso8601String().substring(0, 10),
      'category': category,
      'worker_id': workerId,
      'batch_worker_id': batchWorkerId,
      'name': name,
      'status': status,
    };
  }

  FoodRequest copyWith({String? status}) {
    return FoodRequest(
      id: id,
      siteId: siteId,
      thavvuPointId: thavvuPointId,
      attendanceDate: attendanceDate,
      category: category,
      workerId: workerId,
      batchWorkerId: batchWorkerId,
      name: name,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

/// One row in `food_submissions` — the daily food count a supervisor
/// sends to the HOD.
class FoodSubmission {
  final String? id;
  final String? siteId;
  final String? thavvuPointId;
  final DateTime attendanceDate;
  final List<String> shifts;
  final int regularWorkerCount;
  final int outsideWorkerCount;
  final int machineWorkerCount;
  final int guestCount;
  final int otherCount;
  final String remarks;
  final dynamic payload; // JSONB — list of entry maps in practice
  final String status; // submitted / approved / rejected
  final String? submittedBy;
  final DateTime? submittedAt;

  const FoodSubmission({
    this.id,
    this.siteId,
    this.thavvuPointId,
    required this.attendanceDate,
    this.shifts = const [],
    this.regularWorkerCount = 0,
    this.outsideWorkerCount = 0,
    this.machineWorkerCount = 0,
    this.guestCount = 0,
    this.otherCount = 0,
    this.remarks = '',
    this.payload,
    this.status = 'submitted',
    this.submittedBy,
    this.submittedAt,
  });

  int get totalPeople =>
      regularWorkerCount +
      outsideWorkerCount +
      machineWorkerCount +
      guestCount +
      otherCount;

  factory FoodSubmission.fromJson(Map<String, dynamic> json) {
    return FoodSubmission(
      id: json['id'] as String?,
      siteId: json['site_id'] as String?,
      thavvuPointId: json['thavvu_point_id'] as String?,
      attendanceDate:
          DateTime.tryParse(json['attendance_date'] as String) ??
              DateTime.now(),
      shifts: (json['shifts'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      regularWorkerCount: json['regular_worker_count'] as int? ?? 0,
      outsideWorkerCount: json['outside_worker_count'] as int? ?? 0,
      machineWorkerCount: json['machine_worker_count'] as int? ?? 0,
      guestCount: json['guest_count'] as int? ?? 0,
      otherCount: json['other_count'] as int? ?? 0,
      remarks: json['remarks'] as String? ?? '',
      payload: json['payload'],
      status: json['status'] as String? ?? 'submitted',
      submittedBy: json['submitted_by'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'thavvu_point_id': thavvuPointId,
      'attendance_date':
          attendanceDate.toIso8601String().substring(0, 10),
      'shifts': shifts,
      'regular_worker_count': regularWorkerCount,
      'outside_worker_count': outsideWorkerCount,
      'machine_worker_count': machineWorkerCount,
      'guest_count': guestCount,
      'other_count': otherCount,
      'remarks': remarks,
      'payload': payload,
      'status': status,
      'submitted_by': submittedBy,
    };
  }

  FoodSubmission copyWith({
    String? status,
    String? remarks,
    List<String>? shifts,
  }) {
    return FoodSubmission(
      id: id,
      siteId: siteId,
      thavvuPointId: thavvuPointId,
      attendanceDate: attendanceDate,
      shifts: shifts ?? this.shifts,
      regularWorkerCount: regularWorkerCount,
      outsideWorkerCount: outsideWorkerCount,
      machineWorkerCount: machineWorkerCount,
      guestCount: guestCount,
      otherCount: otherCount,
      remarks: remarks ?? this.remarks,
      payload: payload,
      status: status ?? this.status,
      submittedBy: submittedBy,
      submittedAt: submittedAt,
    );
  }
}
