import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thavvu_supervisor/providers/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppStore seeds data and persists workflows', () async {
    final store = AppStore();
    await store.init();

    expect(store.users, isNotEmpty);
    expect(store.approvedMachines, isNotEmpty);
    expect(store.stockPoints, isNotEmpty);

    final loginError = await store.login('rajesh@thavvu.com', 'password', remember: true);
    expect(loginError, isNull);
    expect(store.currentUser?.email, 'rajesh@thavvu.com');

    final machine = await store.submitMachine(
      machineId: 'MCH-TEST',
      operatorName: 'Tester',
      vehicleNumber: 'TN-99-ZZ-0001',
      vehicleType: 'Excavator',
      billingType: 'Hourly',
      workingAmount: 1000,
    );
    expect(machine.status, 'pending');
    await store.approveMachine(machine.id);
    expect(store.approvedMachines.any((m) => m.machineId == 'MCH-TEST'), isTrue);

    final beforeStock = store.stockPoints.first.remaining;
    final transfer = await store.initiateTransfer(
      fromPoint: store.stockPoints.first.name,
      toPoint: store.stockPoints[1].name,
      item: 'Diesel',
      quantity: 5,
    );
    expect(transfer, isNotNull);
    expect(store.stockPoints.first.remaining, beforeStock - 5);
    await store.acknowledgeTransfer(transfer!.id);
    expect(store.transfers.first.status, 'completed');

    final rental = await store.openRental(item: 'Mixer', billingMode: 'Per day', rate: 1200);
    expect(store.activeRentals.any((r) => r.id == rental.id), isTrue);
    await store.closeRental(rental.id);
    expect(store.activeRentals.any((r) => r.id == rental.id), isFalse);

    final report = await store.generateReport(
      title: 'Machines Summary',
      format: 'PDF',
      period: 'Monthly',
    );
    expect(store.reports.first.id, report.id);
    expect(report.summary, contains('Machines'));
  });
}
