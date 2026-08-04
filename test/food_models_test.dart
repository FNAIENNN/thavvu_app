import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/models/food_models.dart';

void main() {
  group('FoodRequest', () {
    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'fr-1',
        'site_id': 'SITE-VJA-001',
        'attendance_date': '2026-08-01',
        'category': 'regular',
        'worker_id': 'w-1',
        'name': 'Ravi Kumar',
        'status': 'pending',
      };

      final request = FoodRequest.fromJson(json);
      expect(request.category, 'regular');
      expect(request.workerId, 'w-1');
      expect(request.name, 'Ravi Kumar');
      expect(request.status, 'pending');
      expect(request.attendanceDate, DateTime.parse('2026-08-01'));

      final out = request.toJson();
      expect(out['attendance_date'], '2026-08-01');
      expect(out['category'], 'regular');
      expect(out['worker_id'], 'w-1');
    });

    test('copyWith changes status only', () {
      final r = FoodRequest(
        attendanceDate: DateTime(2026, 8, 1),
        category: 'outside',
        batchWorkerId: 'bw-9',
        name: 'Batch Worker',
      );
      final submitted = r.copyWith(status: 'submitted');
      expect(submitted.status, 'submitted');
      expect(submitted.category, 'outside');
      expect(submitted.batchWorkerId, 'bw-9');
    });
  });

  group('FoodSubmission', () {
    test('fromJson/toJson round-trip with counts and shifts', () {
      final json = {
        'id': 'fs-1',
        'site_id': 'SITE-VJA-001',
        'attendance_date': '2026-08-01',
        'shifts': ['Morning', 'Evening'],
        'regular_worker_count': 4,
        'outside_worker_count': 2,
        'machine_worker_count': 1,
        'guest_count': 0,
        'other_count': 1,
        'remarks': '2 extra for machine crew',
        'status': 'submitted',
        'submitted_at': '2026-08-01T05:45:00.000Z',
      };

      final submission = FoodSubmission.fromJson(json);
      expect(submission.regularWorkerCount, 4);
      expect(submission.outsideWorkerCount, 2);
      expect(submission.totalPeople, 8);
      expect(submission.shifts, ['Morning', 'Evening']);
      expect(submission.status, 'submitted');

      final out = submission.toJson();
      expect(out['regular_worker_count'], 4);
      expect(out['shifts'], ['Morning', 'Evening']);
      expect(out['attendance_date'], '2026-08-01');
    });

    test('totalPeople sums all categories', () {
      final s = FoodSubmission(
        attendanceDate: DateTime(2026, 8, 1),
        regularWorkerCount: 3,
        outsideWorkerCount: 2,
        machineWorkerCount: 1,
        guestCount: 1,
        otherCount: 2,
      );
      expect(s.totalPeople, 9);
    });

    test('copyWith updates status', () {
      final s = FoodSubmission(
        attendanceDate: DateTime(2026, 8, 1),
        regularWorkerCount: 5,
      );
      final approved = s.copyWith(status: 'approved');
      expect(approved.status, 'approved');
      expect(approved.regularWorkerCount, 5);
    });
  });
}
