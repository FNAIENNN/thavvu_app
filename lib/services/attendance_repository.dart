import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_models.dart';

/// Supabase-backed repository for the attendance module.
///
/// Follows the existing `SupabaseTasksRepository` pattern: thin CRUD over
/// the Supabase client, graceful `false`/empty-list on error.
class AttendanceRepository {
  AttendanceRepository({SupabaseClient? client}) : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first query.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const _workersTable = 'workers';
  static const _recordsTable = 'attendance_records';
  static const _batchesTable = 'attendance_batches';
  static const _batchWorkersTable = 'attendance_batch_workers';

  // ==========================================================
  // WORKERS (master data)
  // ==========================================================

  /// Fetch all workers for a site (HODs pass their site id; supervisors
  /// resolve theirs via `AttendanceContextService`).
  Future<List<WorkerProfile>> fetchWorkers({String? siteId}) async {
    try {
      var query = _client.from(_workersTable).select();
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response = await query.order('name', ascending: true);
      return (response as List)
          .map((json) => WorkerProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching workers: $e');
      return [];
    }
  }

  /// Fetch a worker by enrolled face ID (used by the Face tab).
  Future<WorkerProfile?> fetchWorkerByFaceId(String faceId) async {
    try {
      final response = await _client
          .from(_workersTable)
          .select()
          .eq('face_id', faceId)
          .maybeSingle();
      if (response == null) return null;
      return WorkerProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching worker by face id: $e');
      return null;
    }
  }

  /// Create a worker (HOD/admin registration flow).
  Future<WorkerProfile?> createWorker(WorkerProfile worker) async {
    try {
      final response = await _client
          .from(_workersTable)
          .insert(worker.toJson())
          .select()
          .single();
      return WorkerProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error creating worker: $e');
      return null;
    }
  }

  // ==========================================================
  // ATTENDANCE RECORDS (one row per worker per day)
  // ==========================================================

  /// Fetch a single worker's record for a given date.
  Future<AttendanceRecord?> fetchRecord(
      String workerId, DateTime day) async {
    try {
      final response = await _client
          .from(_recordsTable)
          .select()
          .eq('worker_id', workerId)
          .eq('attendance_date', _dateOnly(day))
          .maybeSingle();
      if (response == null) return null;
      return AttendanceRecord.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching attendance record: $e');
      return null;
    }
  }

  /// Upsert a record (check-in or status change). Inserts when missing,
  /// updates the existing row on `(worker_id, attendance_date)` conflict.
  Future<AttendanceRecord?> upsertRecord(AttendanceRecord record) async {
    try {
      final json = record.toJson();
      if (record.id != null) {
        json['id'] = record.id;
      }
      final response = await _client
          .from(_recordsTable)
          .upsert(json, onConflict: 'worker_id,attendance_date')
          .select()
          .single();
      return AttendanceRecord.fromJson(response);
    } catch (e) {
      debugPrint('Error upserting attendance record: $e');
      return null;
    }
  }

  /// Mark check-out on the worker's record for [day].
  Future<AttendanceRecord?> upsertCheckOut(
    String workerId,
    DateTime day, {
    required DateTime checkOutTime,
    String? method,
    String? photoUrl,
  }) async {
    final existing = await fetchRecord(workerId, day);
    if (existing == null) return null;
    return upsertRecord(existing.copyWith(
      checkOutTime: checkOutTime,
      checkOutMethod: method,
      checkOutPhotoUrl: photoUrl,
    ));
  }

  /// Fetch all attendance records for a site on a day (HOD view).
  Future<List<AttendanceRecord>> fetchAttendance(
    DateTime day, {
    String? siteId,
  }) async {
    try {
      var query = _client
          .from(_recordsTable)
          .select()
          .eq('attendance_date', _dateOnly(day));
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response = await query.order('check_in_time', ascending: true);
      return (response as List)
          .map((json) =>
              AttendanceRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
      return [];
    }
  }

  /// HOD approval of a record.
  Future<bool> approveRecord(
    String recordId, {
    required String status, // approved / rejected
    String? remark,
  }) async {
    try {
      await _client.from(_recordsTable).update({
        'hod_approval_status': status,
        if (remark != null) 'hod_remark': remark,
      }).eq('id', recordId);
      return true;
    } catch (e) {
      debugPrint('Error approving attendance record: $e');
      return false;
    }
  }

  // ==========================================================
  // OUTSIDE WORKER BATCHES
  // ==========================================================

  /// Fetch batches (with their workers) for a day/site.
  Future<List<OutsideBatch>> fetchBatches(
    DateTime day, {
    String? siteId,
  }) async {
    try {
      var query = _client
          .from(_batchesTable)
          .select('*, attendance_batch_workers(*)')
          .eq('attendance_date', _dateOnly(day));
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response =
          await query.order('batch_number', ascending: true);
      return (response as List).map((json) {
        final map = json as Map<String, dynamic>;
        final workers = (map['attendance_batch_workers'] as List? ?? [])
            .map((w) => OutsideBatchWorker.fromJson(w as Map<String, dynamic>))
            .toList();
        return OutsideBatch.fromJson(map, workers: workers);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching batches: $e');
      return [];
    }
  }

  /// Create a batch and its worker rows in one call.
  /// Returns the created batch (with id and DB worker ids) or null on error.
  Future<OutsideBatch?> createBatch(OutsideBatch batch) async {
    try {
      final response = await _client
          .from(_batchesTable)
          .insert(batch.toJson())
          .select()
          .single();
      final created = OutsideBatch.fromJson(response);

      if (batch.workers.isNotEmpty) {
        final rows = batch.workers
            .map((w) => w.copyWithForBatch(created.id!))
            .map((w) => w.toJson())
            .toList();
        await _client.from(_batchWorkersTable).insert(rows);

        // Re-fetch the inserted worker rows so callers get real DB ids
        // (needed for food_requests FK references and status updates).
        final inserted = await _client
            .from(_batchWorkersTable)
            .select('id,name,wage,attendance_status,food_opt_in,supplier')
            .eq('batch_id', created.id!);
        final createdWorkers = (inserted as List)
            .map((j) =>
                OutsideBatchWorker.fromJson(j as Map<String, dynamic>))
            .toList();
        return OutsideBatch.fromJson(response, workers: createdWorkers);
      }
      return created;
    } catch (e) {
      debugPrint('Error creating batch: $e');
      return null;
    }
  }

  /// Update a worker's enrolled face signature (professional face ID).
  Future<bool> updateWorkerFaceSignature(
      String workerId, String signature) async {
    try {
      await _client.from(_workersTable).update({
        'face_signature': signature,
      }).eq('id', workerId);
      return true;
    } catch (e) {
      debugPrint('Error updating worker face signature: $e');
      return false;
    }
  }

  /// Update a worker's status (active / inactive / leave / closed).
  Future<bool> updateWorkerStatus(String workerId, String status) async {
    try {
      await _client
          .from(_workersTable)
          .update({'status': status}).eq('id', workerId);
      return true;
    } catch (e) {
      debugPrint('Error updating worker status: $e');
      return false;
    }
  }

  /// Update an outside worker's attendance status inside a batch.
  Future<bool> updateBatchWorkerStatus(
      String workerId, String status) async {
    try {
      await _client
          .from(_batchWorkersTable)
          .update({'attendance_status': status}).eq('id', workerId);
      return true;
    } catch (e) {
      debugPrint('Error updating batch worker status: $e');
      return false;
    }
  }

  /// Update batch-level fields (shift state, continuation/end photos).
  /// HOD approval fields are intentionally NOT updated here — supervisors
  /// must never overwrite HOD decisions.
  Future<bool> updateBatch(OutsideBatch batch) async {
    try {
      if (batch.id == null) return false;
      final json = batch.toJson()..remove('hod_approval_status')
        ..remove('hod_remark');
      await _client
          .from(_batchesTable)
          .update(json)
          .eq('id', batch.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating batch: $e');
      return false;
    }
  }

  /// HOD approve/reject an outside-worker batch.
  Future<bool> approveBatch(
    String batchId, {
    required String status, // approved / rejected
    String? remark,
  }) async {
    try {
      await _client.from(_batchesTable).update({
        'hod_approval_status': status,
        if (remark != null) 'hod_remark': remark,
      }).eq('id', batchId);
      return true;
    } catch (e) {
      debugPrint('Error approving batch: $e');
      return false;
    }
  }

  String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);
}

extension _BatchWorkerCopy on OutsideBatchWorker {
  OutsideBatchWorker copyWithForBatch(String batchId) {
    return OutsideBatchWorker(
      id: id,
      batchId: batchId,
      name: name,
      wage: wage,
      attendanceStatus: attendanceStatus,
      foodOptIn: foodOptIn,
      supplier: supplier,
    );
  }
}
