/// Domain models for the Thavvu attendance module.
///
/// These mirror the Supabase tables created in
/// `supabase/migrations/00005_attendance_food.sql`:
///   workers, attendance_records, attendance_batches, attendance_batch_workers.
library;

class WorkerProfile {
  final String id;
  final String? siteId;
  final String? thavvuPointId;
  final String name;
  final String? department;
  final String? phone;
  final String? aadharNumber;
  final String? faceId;
  final String? biometricId;
  final String? faceSignature; // 64-bit dHash hex of the enrolled selfie
  final String? workerPhotoUrl;
  final String? aadharPhotoUrl;
  final String? bankBookPhotoUrl;
  final String? referralName;
  final DateTime? joiningDate;
  final double? wage;
  final String status; // active / inactive / leave / closed
  final bool isTemporary;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkerProfile({
    required this.id,
    this.siteId,
    this.thavvuPointId,
    required this.name,
    this.department,
    this.phone,
    this.aadharNumber,
    this.faceId,
    this.biometricId,
    this.faceSignature,
    this.workerPhotoUrl,
    this.aadharPhotoUrl,
    this.bankBookPhotoUrl,
    this.referralName,
    this.joiningDate,
    this.wage,
    this.status = 'active',
    this.isTemporary = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkerProfile.fromJson(Map<String, dynamic> json) {
    return WorkerProfile(
      id: json['id'] as String,
      siteId: json['site_id'] as String?,
      thavvuPointId: json['thavvu_point_id'] as String?,
      name: json['name'] as String,
      department: json['department'] as String?,
      phone: json['phone'] as String?,
      aadharNumber: json['aadhar_number'] as String?,
      faceId: json['face_id'] as String?,
      biometricId: json['biometric_id'] as String?,
      faceSignature: json['face_signature'] as String?,
      workerPhotoUrl: json['worker_photo_url'] as String?,
      aadharPhotoUrl: json['aadhar_photo_url'] as String?,
      bankBookPhotoUrl: json['bank_book_photo_url'] as String?,
      referralName: json['referral_name'] as String?,
      joiningDate: json['joining_date'] != null
          ? DateTime.tryParse(json['joining_date'] as String)
          : null,
      wage: (json['wage'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'active',
      isTemporary: json['is_temporary'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'thavvu_point_id': thavvuPointId,
      'name': name,
      'department': department,
      'phone': phone,
      'aadhar_number': aadharNumber,
      'face_id': faceId,
      'biometric_id': biometricId,
      'face_signature': faceSignature,
      'worker_photo_url': workerPhotoUrl,
      'aadhar_photo_url': aadharPhotoUrl,
      'bank_book_photo_url': bankBookPhotoUrl,
      'referral_name': referralName,
      'joining_date': joiningDate?.toIso8601String().substring(0, 10),
      'wage': wage,
      'status': status,
      'is_temporary': isTemporary,
    };
  }
}

/// One row in `attendance_records` — one worker per day.
class AttendanceRecord {
  final String? id;
  final String? siteId;
  final String? thavvuPointId;
  final String workerId;
  final DateTime attendanceDate;
  final String status; // Present / Absent / Half day / Leave / Not Marked
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInMethod; // face / biometric / manual / manual_photo
  final String? checkOutMethod;
  final String? checkInPhotoUrl;
  final String? checkOutPhotoUrl;
  final String? halfDayPhotoUrl;
  final String? afternoonPhotoUrl;
  final String? geoLocation;
  final bool foodOptIn;
  final String hodApprovalStatus; // pending / approved / rejected
  final String? hodRemark;
  final String? markedBy;

  const AttendanceRecord({
    this.id,
    this.siteId,
    this.thavvuPointId,
    required this.workerId,
    required this.attendanceDate,
    this.status = 'Present',
    this.checkInTime,
    this.checkOutTime,
    this.checkInMethod,
    this.checkOutMethod,
    this.checkInPhotoUrl,
    this.checkOutPhotoUrl,
    this.halfDayPhotoUrl,
    this.afternoonPhotoUrl,
    this.geoLocation,
    this.foodOptIn = true,
    this.hodApprovalStatus = 'pending',
    this.hodRemark,
    this.markedBy,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String?,
      siteId: json['site_id'] as String?,
      thavvuPointId: json['thavvu_point_id'] as String?,
      workerId: json['worker_id'] as String,
      attendanceDate: DateTime.tryParse(json['attendance_date'] as String) ??
          DateTime.now(),
      status: json['status'] as String? ?? 'Present',
      checkInTime: json['check_in_time'] != null
          ? DateTime.tryParse(json['check_in_time'] as String)
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.tryParse(json['check_out_time'] as String)
          : null,
      checkInMethod: json['check_in_method'] as String?,
      checkOutMethod: json['check_out_method'] as String?,
      checkInPhotoUrl: json['check_in_photo_url'] as String?,
      checkOutPhotoUrl: json['check_out_photo_url'] as String?,
      halfDayPhotoUrl: json['half_day_photo_url'] as String?,
      afternoonPhotoUrl: json['afternoon_photo_url'] as String?,
      geoLocation: json['geo_location'] as String?,
      foodOptIn: json['food_opt_in'] as bool? ?? true,
      hodApprovalStatus: json['hod_approval_status'] as String? ?? 'pending',
      hodRemark: json['hod_remark'] as String?,
      markedBy: json['marked_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'thavvu_point_id': thavvuPointId,
      'worker_id': workerId,
      'attendance_date':
          attendanceDate.toIso8601String().substring(0, 10),
      'status': status,
      'check_in_time': checkInTime?.toUtc().toIso8601String(),
      'check_out_time': checkOutTime?.toUtc().toIso8601String(),
      'check_in_method': checkInMethod,
      'check_out_method': checkOutMethod,
      'check_in_photo_url': checkInPhotoUrl,
      'check_out_photo_url': checkOutPhotoUrl,
      'half_day_photo_url': halfDayPhotoUrl,
      'afternoon_photo_url': afternoonPhotoUrl,
      'geo_location': geoLocation,
      'food_opt_in': foodOptIn,
      'hod_approval_status': hodApprovalStatus,
      'hod_remark': hodRemark,
      'marked_by': markedBy,
    };
  }

  AttendanceRecord copyWith({
    String? id,
    DateTime? checkOutTime,
    String? checkOutMethod,
    String? checkOutPhotoUrl,
    String? status,
    String? hodApprovalStatus,
    String? hodRemark,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      siteId: siteId,
      thavvuPointId: thavvuPointId,
      workerId: workerId,
      attendanceDate: attendanceDate,
      status: status ?? this.status,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInMethod: checkInMethod,
      checkOutMethod: checkOutMethod ?? this.checkOutMethod,
      checkInPhotoUrl: checkInPhotoUrl,
      checkOutPhotoUrl: checkOutPhotoUrl ?? this.checkOutPhotoUrl,
      halfDayPhotoUrl: halfDayPhotoUrl,
      afternoonPhotoUrl: afternoonPhotoUrl,
      geoLocation: geoLocation,
      foodOptIn: foodOptIn,
      hodApprovalStatus: hodApprovalStatus ?? this.hodApprovalStatus,
      hodRemark: hodRemark ?? this.hodRemark,
      markedBy: markedBy,
    );
  }
}

/// One row in `attendance_batches` — an outside-worker supplier batch.
class OutsideBatch {
  final String? id;
  final String? siteId;
  final String? thavvuPointId;
  final DateTime attendanceDate;
  final int batchNumber;
  final String supplier;
  final String sessionType;
  final String shiftState;
  final String? photoUrl;
  final String? geoLocation;
  final String? continuationPhotoUrl;
  final String? endShiftPhotoUrl;
  final String? endShiftGeoLocation;
  final String hodApprovalStatus; // pending / approved / rejected
  final String? hodRemark;
  final List<OutsideBatchWorker> workers;
  final String? markedBy;

  const OutsideBatch({
    this.id,
    this.siteId,
    this.thavvuPointId,
    required this.attendanceDate,
    required this.batchNumber,
    required this.supplier,
    required this.sessionType,
    this.shiftState = 'active',
    this.photoUrl,
    this.geoLocation,
    this.continuationPhotoUrl,
    this.endShiftPhotoUrl,
    this.endShiftGeoLocation,
    this.hodApprovalStatus = 'pending',
    this.hodRemark,
    this.workers = const [],
    this.markedBy,
  });

  factory OutsideBatch.fromJson(Map<String, dynamic> json,
      {List<OutsideBatchWorker> workers = const []}) {
    return OutsideBatch(
      id: json['id'] as String?,
      siteId: json['site_id'] as String?,
      thavvuPointId: json['thavvu_point_id'] as String?,
      attendanceDate:
          DateTime.tryParse(json['attendance_date'] as String) ??
              DateTime.now(),
      batchNumber: json['batch_number'] as int? ?? 0,
      supplier: json['supplier'] as String? ?? '',
      sessionType: json['session_type'] as String? ?? '',
      shiftState: json['shift_state'] as String? ?? 'active',
      photoUrl: json['photo_url'] as String?,
      geoLocation: json['geo_location'] as String?,
      continuationPhotoUrl: json['continuation_photo_url'] as String?,
      endShiftPhotoUrl: json['end_shift_photo_url'] as String?,
      endShiftGeoLocation: json['end_shift_geo_location'] as String?,
      hodApprovalStatus: json['hod_approval_status'] as String? ?? 'pending',
      hodRemark: json['hod_remark'] as String?,
      workers: workers,
      markedBy: json['marked_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'thavvu_point_id': thavvuPointId,
      'attendance_date':
          attendanceDate.toIso8601String().substring(0, 10),
      'batch_number': batchNumber,
      'supplier': supplier,
      'session_type': sessionType,
      'shift_state': shiftState,
      'photo_url': photoUrl,
      'geo_location': geoLocation,
      'continuation_photo_url': continuationPhotoUrl,
      'end_shift_photo_url': endShiftPhotoUrl,
      'end_shift_geo_location': endShiftGeoLocation,
      'hod_approval_status': hodApprovalStatus,
      'hod_remark': hodRemark,
      'marked_by': markedBy,
    };
  }
}

/// One row in `attendance_batch_workers` — a worker inside an outside batch.
class OutsideBatchWorker {
  final String? id;
  final String? batchId;
  final String name;
  final double? wage;
  final String attendanceStatus;
  final bool foodOptIn;
  final String? supplier;

  const OutsideBatchWorker({
    this.id,
    this.batchId,
    required this.name,
    this.wage,
    this.attendanceStatus = 'Present',
    this.foodOptIn = true,
    this.supplier,
  });

  factory OutsideBatchWorker.fromJson(Map<String, dynamic> json) {
    return OutsideBatchWorker(
      id: json['id'] as String?,
      batchId: json['batch_id'] as String?,
      name: json['name'] as String? ?? '',
      wage: (json['wage'] as num?)?.toDouble(),
      attendanceStatus: json['attendance_status'] as String? ?? 'Present',
      foodOptIn: json['food_opt_in'] as bool? ?? true,
      supplier: json['supplier'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'batch_id': batchId,
      'name': name,
      'wage': wage,
      'attendance_status': attendanceStatus,
      'food_opt_in': foodOptIn,
      'supplier': supplier,
    };
  }
}
