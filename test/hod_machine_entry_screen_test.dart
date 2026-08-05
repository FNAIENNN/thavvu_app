import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_asset.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_daily_log.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_payment_request.dart';
import 'package:thavvu_app/features/hod_machine/domain/models/machine_supplier.dart';
import 'package:thavvu_app/features/hod_machine/domain/services/hod_machine_repository_interface.dart';
import 'package:thavvu_app/screens/hod/modules/hod_machines_entry_screen.dart';

/// In-memory repository so widget tests exercise the real UI without
/// needing a live Supabase connection.
class _FakeMachineRepository implements HodMachineRepository {
  @override
  Future<List<MachineSupplier>> getSuppliers({required String siteId}) async =>
      const [];

  @override
  Future<List<MachineAsset>> getMachines({required String siteId}) async =>
      const [];

  @override
  Future<List<MachinePaymentRequest>> getPaymentRequests(
          {required String siteId, String? status}) async =>
      const [];

  @override
  Future<MachineSupplier> createSupplier({
    required String siteId,
    required String name,
    required String type,
    String? phone,
    double? rating,
    String? notes,
    required String createdBy,
  }) =>
      throw UnimplementedError('not used in widget test');

  @override
  Future<MachineAsset> createMachine({required MachineAsset machine}) =>
      throw UnimplementedError('not used in widget test');

  @override
  Future<void> deactivateMachine(String machineId) async {}

  @override
  Future<List<MachineDailyLog>> getDailyLogs({
    required String siteId,
    String? thavvuPointId,
    String? supervisorId,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async =>
      const [];

  @override
  Future<MachineDailyLog> submitDailyLog(MachineDailyLog log) =>
      throw UnimplementedError('not used in widget test');

  @override
  Future<MachineDailyLog> reviewDailyLog({
    required String logId,
    required String hodId,
    required String status,
    String? hodNote,
  }) =>
      throw UnimplementedError('not used in widget test');

  @override
  Future<MachinePaymentRequest> createPaymentRequest(
          MachinePaymentRequest request) =>
      throw UnimplementedError('not used in widget test');

  @override
  Future<MachinePaymentRequest> approvePaymentByHod({
    required String paymentId,
    required String hodId,
  }) =>
      throw UnimplementedError('not used in widget test');

  @override
  Future<MachinePaymentRequest> submitApprovedPaymentToFinance(
          {required String paymentId}) =>
      throw UnimplementedError('not used in widget test');

  @override
  Future<MachinePaymentRequest> completeFinancePayment({
    required String paymentId,
    required String proofPath,
    required bool registerInIdsBook,
  }) =>
      throw UnimplementedError('not used in widget test');
}

void main() {
  testWidgets('HOD machine module opens dedicated production screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HodMachinesEntryScreen(repository: _FakeMachineRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('HOD Machine Entry'), findsWidgets);
    expect(find.text('Entry'), findsWidgets);
    // Entry form steps render with real data (no Supabase dependency).
    expect(find.text('Payment Approval'), findsOneWidget);
    expect(find.text('Finance'), findsWidgets);
    expect(find.text('Records'), findsOneWidget);
  });

  testWidgets('HOD machine screen shows site context header',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HodMachinesEntryScreen(
        siteId: 'SITE-VJA-001',
        hodId: 'HOD-001',
        thavvuPointId: 'TP-VJA-001',
        supervisorId: 'Supervisor Rajesh',
        siteName: 'Vijayawada River Bed',
        repository: _FakeMachineRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    // Context card: site name, site id, point id, supervisor, hod id.
    expect(find.text('Vijayawada River Bed'), findsOneWidget);
    expect(find.text('SITE-VJA-001'), findsOneWidget);
    expect(find.text('TP-VJA-001'), findsOneWidget);
    expect(find.text('Supervisor Rajesh'), findsOneWidget);
    expect(find.text('HOD-001'), findsOneWidget);
  });
}
