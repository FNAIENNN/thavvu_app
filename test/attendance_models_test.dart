import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/models/attendance_models.dart';

void main() {
  group('WorkerProfile', () {
    test('fromJson/toJson round-trip', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'site_id': 'SITE-VJA-001',
        'thavvu_point_id': 'TP-VJA-001',
        'name': 'Ravi Kumar',
        'department': 'Loading Crew',
        'phone': '9876543201',
        'aadhar_number': '9000000001',
        'face_id': 'FACE-ravi',
        'biometric_id': 'BIO-ravi',
        'status': 'active',
        'is_temporary': false,
        'wage': 550,
        'joining_date': '2026-04-01',
      };

      final worker = WorkerProfile.fromJson(json);

      expect(worker.id, '11111111-1111-1111-1111-111111111111');
      expect(worker.siteId, 'SITE-VJA-001');
      expect(worker.name, 'Ravi Kumar');
      expect(worker.faceId, 'FACE-ravi');
      expect(worker.wage, 550);
      expect(worker.joiningDate, DateTime.parse('2026-04-01'));

      final out = worker.toJson();
      expect(out['name'], 'Ravi Kumar');
      expect(out['face_id'], 'FACE-ravi');
      expect(out['joining_date'], '2026-04-01');
    });

    test('fromJson tolerates missing optional fields', () {
      final worker = WorkerProfile.fromJson({
        'id': 'x',
        'name': 'Only Name',
      });
      expect(worker.name, 'Only Name');
      expect(worker.siteId, isNull);
      expect(worker.status, 'active');
      expect(worker.isTemporary, false);
    });
  });

  group('AttendanceRecord', () {
    test('fromJson/toJson round-trip with times', () {
      final json = {
        'id': 'rec-1',
        'site_id': 'SITE-VJA-001',
        'worker_id': 'w-1',
        'attendance_date': '2026-08-01',
        'status': 'Present',
        'check_in_time': '2026-08-01T05:30:00.000Z',
        'check_out_time': '2026-08-01T13:30:00.000Z',
        'check_in_method': 'face',
        'check_in_photo_url': 'user/attendance/2026-08-01/w-1_checkin_1.jpg',
        'food_opt_in': true,
        'hod_approval_status': 'pending',
      };

      final record = AttendanceRecord.fromJson(json);
      expect(record.workerId, 'w-1');
      expect(record.checkInMethod, 'face');
      expect(record.foodOptIn, true);
      expect(record.hodApprovalStatus, 'pending');
      expect(record.checkInTime, DateTime.parse('2026-08-01T05:30:00.000Z'));

      final out = record.toJson();
      expect(out['attendance_date'], '2026-08-01');
      expect(out['check_in_method'], 'face');
      expect(out['food_opt_in'], true);
    });

    test('copyWith updates check-out fields only', () {
      final base = AttendanceRecord(
        workerId: 'w-1',
        attendanceDate: DateTime(2026, 8, 1),
        checkInTime: DateTime(2026, 8, 1, 6),
        checkInMethod: 'manual',
      );
      final updated = base.copyWith(
        checkOutTime: DateTime(2026, 8, 1, 14),
        checkOutMethod: 'manual',
      );
      expect(updated.checkOutTime, DateTime(2026, 8, 1, 14));
      expect(updated.checkInMethod, 'manual');
      expect(updated.checkInTime, base.checkInTime);
    });
  });

  group('OutsideBatch + OutsideBatchWorker', () {
    test('fromJson parses nested workers', () {
      final workers = [
        OutsideBatchWorker.fromJson({
          'id': 'bw-1',
          'batch_id': 'b-1',
          'name': 'Batch Worker A',
          'wage': 450,
          'attendance_status': 'Present',
          'food_opt_in': true,
        }),
        OutsideBatchWorker.fromJson({
          'id': 'bw-2',
          'batch_id': 'b-1',
          'name': 'Batch Worker B',
          'wage': 450,
          'attendance_status': 'Present',
          'food_opt_in': false,
        }),
      ];

      final batch = OutsideBatch.fromJson({
        'id': 'b-1',
        'site_id': 'SITE-VJA-001',
        'attendance_date': '2026-08-01',
        'batch_number': 1,
        'supplier': 'ABC Earth Movers',
        'session_type': 'Morning',
        'shift_state': 'active',
      }, workers: workers);

      expect(batch.supplier, 'ABC Earth Movers');
      expect(batch.workers.length, 2);
      expect(batch.workers[1].foodOptIn, false);
      expect(batch.workers[1].name, 'Batch Worker B');

      final out = batch.toJson();
      expect(out['batch_number'], 1);
      expect(out['shift_state'], 'active');
    });

    test('batch worker toJson includes batch_id', () {
      const w = OutsideBatchWorker(
        batchId: 'b-9',
        name: 'X',
        wage: 400,
        foodOptIn: true,
      );
      final out = w.toJson();
      expect(out['batch_id'], 'b-9');
      expect(out['food_opt_in'], true);
      expect(out['wage'], 400);
    });
  });
}
