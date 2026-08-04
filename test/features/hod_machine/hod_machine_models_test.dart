import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/features/hod_machine/data/repositories/supabase_assignment_repository.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_asset.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_daily_log.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_diesel_line.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_payment_request.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_supplier.dart';

void main() {
  group('MachineSupplier serialization', () {
    test('round-trips from JSON', () {
      final json = {
        'id': 'SUPPLIER-001',
        'site_id': 'SITE-VJA-001',
        'name': 'ABC Earth Movers',
        'type': 'permanent',
        'phone': '9876500011',
        'rating': 4.6,
        'notes': 'Preferred supplier',
        'is_active': true,
        'created_by': 'user-uuid',
        'created_at': '2026-06-14T10:30:00.000Z',
        'updated_at': '2026-06-14T10:30:00.000Z',
      };

      final model = MachineSupplier.fromJson(json);

      expect(model.id, 'SUPPLIER-001');
      expect(model.siteId, 'SITE-VJA-001');
      expect(model.name, 'ABC Earth Movers');
      expect(model.type, 'permanent');
      expect(model.isTemporary, isFalse);
      expect(model.rating, 4.6);
      expect(model.isActive, isTrue);

      final roundTrip = MachineSupplier.fromJson(model.toJson());
      expect(roundTrip.id, model.id);
      expect(roundTrip.name, model.name);
      expect(roundTrip.siteId, model.siteId);
    });
  });

  group('MachineAsset serialization', () {
    test('round-trips from JSON', () {
      final json = {
        'id': 'MACHINE-001',
        'site_id': 'SITE-VJA-001',
        'machine_name': 'JCB Backhoe 3DX',
        'vehicle_number': 'AP16JC9090',
        'vehicle_type': 'Backhoe',
        'operator_name': 'Mahesh',
        'operator_phone': '9876500999',
        'is_active': true,
        'created_by': 'user-uuid',
        'created_at': '2026-06-14T10:30:00.000Z',
        'updated_at': '2026-06-14T10:30:00.000Z',
      };

      final model = MachineAsset.fromJson(json);

      expect(model.id, 'MACHINE-001');
      expect(model.vehicleNumber, 'AP16JC9090');
      expect(model.operatorName, 'Mahesh');
      expect(model.isActive, isTrue);

      final roundTrip = MachineAsset.fromJson(model.toJson());
      expect(roundTrip.vehicleNumber, model.vehicleNumber);
    });
  });

  group('MachineDieselLine serialization', () {
    test('round-trips from JSON', () {
      final json = {
        'id': 'a1b2c3d4',
        'daily_log_id': 'log-1',
        'fuel_type': 'Diesel',
        'stock_point': 'Main Depot',
        'liters': 35.0,
        'amount': 3378.0,
        'remarks': 'Morning refill',
        'created_at': '2026-06-15T08:00:00.000Z',
      };

      final model = MachineDieselLine.fromJson(json);

      expect(model.liters, 35.0);
      expect(model.amount, 3378.0);
      expect(model.fuelType, 'Diesel');

      final roundTrip = MachineDieselLine.fromJson(model.toJson());
      expect(roundTrip.liters, model.liters);
    });
  });

  group('MachineDailyLog serialization', () {
    test('maps status strings to enum and back', () {
      expect(DailyLogStatus.fromApi('draft'), DailyLogStatus.draft);
      expect(DailyLogStatus.fromApi('submitted'), DailyLogStatus.submitted);
      expect(DailyLogStatus.fromApi('approved'), DailyLogStatus.approved);
      expect(
        DailyLogStatus.fromApi('revision_requested'),
        DailyLogStatus.revisionRequested,
      );
      expect(DailyLogStatus.fromApi('rejected'), DailyLogStatus.rejected);
      expect(DailyLogStatus.fromApi('unknown'), DailyLogStatus.draft);

      expect(DailyLogStatus.approved.apiValue, 'approved');
      expect(
        DailyLogStatus.revisionRequested.apiValue,
        'revision_requested',
      );
    });

    test('round-trips from JSON with nested diesel lines', () {
      final json = {
        'id': 'log-1',
        'log_date': '2026-06-15T00:00:00.000Z',
        'site_id': 'SITE-VJA-001',
        'thavvu_point_id': 'TP-VJA-001',
        'supervisor_id': 'sup-uuid',
        'machine_id': 'MACHINE-001',
        'location': 'Site A',
        'diesel_option': 'With diesel',
        'working_hours': 8.5,
        'worker_count': 3,
        'beta_amount': 700,
        'extra_beta_amount': 250,
        'status': 'submitted',
        'hod_note': null,
        'created_at': '2026-06-15T08:00:00.000Z',
        'updated_at': '2026-06-15T08:00:00.000Z',
        'diesel_lines': [
          {
            'id': 'die-1',
            'daily_log_id': 'log-1',
            'fuel_type': 'Diesel',
            'stock_point': 'Main Depot',
            'liters': 35,
            'amount': 3378,
            'created_at': '2026-06-15T08:00:00.000Z',
          }
        ],
      };

      final model = MachineDailyLog.fromJson(json);

      expect(model.status, DailyLogStatus.submitted);
      expect(model.dieselLiters, 35.0);
      expect(model.dieselAmount, 3378.0);
      expect(model.dieselLines, hasLength(1));
      expect(model.workerCount, 3);
    });
  });

  group('MachinePaymentRequest serialization', () {
    test('maps payment status strings', () {
      expect(PaymentStatus.fromApi('draft'), PaymentStatus.draft);
      expect(PaymentStatus.fromApi('hod_approved'), PaymentStatus.hodApproved);
      expect(PaymentStatus.fromApi('hod_rejected'), PaymentStatus.hodRejected);
      expect(
        PaymentStatus.fromApi('submitted_to_finance'),
        PaymentStatus.submittedToFinance,
      );
      expect(PaymentStatus.fromApi('finance_processing'),
          PaymentStatus.financeProcessing);
      expect(PaymentStatus.fromApi('paid'), PaymentStatus.paid);
      expect(PaymentStatus.fromApi('closed'), PaymentStatus.closed);

      expect(PaymentKind.fromApi('advance'), PaymentKind.advance);
      expect(PaymentKind.fromApi('cash'), PaymentKind.cash);
    });

    test('round-trips from JSON', () {
      final json = {
        'id': 'pay-1',
        'daily_log_id': 'log-1',
        'site_id': 'SITE-VJA-001',
        'thavvu_point_id': 'TP-VJA-001',
        'kind': 'advance',
        'amount': 15000,
        'payment_mode': 'UPI',
        'entry_method': 'Manual',
        'account_label': 'abc@upi',
        'status': 'hod_approved',
        'hod_approved_at': '2026-06-15T09:00:00.000Z',
        'hod_approved_by': 'hod-uuid',
        'created_by': 'hod-uuid',
        'created_at': '2026-06-15T08:00:00.000Z',
        'updated_at': '2026-06-15T09:00:00.000Z',
      };

      final model = MachinePaymentRequest.fromJson(json);

      expect(model.isAdvance, isTrue);
      expect(model.amount, 15000);
      expect(model.status, PaymentStatus.hodApproved);
      expect(model.hodApprovedBy, 'hod-uuid');

      final roundTrip = MachinePaymentRequest.fromJson(model.toJson());
      expect(roundTrip.amount, model.amount);
      expect(roundTrip.status, model.status);
    });
  });

  group('ThavvuPointAssignment serialization', () {
    test('round-trips from JSON', () {
      final json = {
        'id': 'assign-1',
        'thavvu_point_id': 'TP-VJA-001',
        'supervisor_id': 'sup-uuid',
        'site_id': 'SITE-VJA-001',
        'assigned_by': 'hod-uuid',
        'is_active': true,
        'assigned_at': '2026-06-15T08:00:00.000Z',
        'ended_at': null,
        'reason': null,
      };

      final model = ThavvuPointAssignment.fromJson(json);

      expect(model.thavvuPointId, 'TP-VJA-001');
      expect(model.supervisorId, 'sup-uuid');
      expect(model.isActive, isTrue);

      final endedJson = {
        ...json,
        'is_active': false,
        'ended_at': '2026-06-20T08:00:00.000Z',
      };
      final ended = ThavvuPointAssignment.fromJson(endedJson);
      expect(ended.isActive, isFalse);
      expect(ended.endedAt, isNotNull);
    });
  });
}
