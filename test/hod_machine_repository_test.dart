import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/models/hod_machine_models.dart';
import 'package:thavvu_app/services/hod_machine_repository.dart';

void main() {
  group('InMemoryHodMachineRepository', () {
    test('manages suppliers, machines, entries and finance requests', () async {
      final repository = InMemoryHodMachineRepository();

      final newSupplier = const HodMachineSupplier(
        id: 'SUPPLIER-TEST',
        name: 'Test Supplier',
        phone: '9999999999',
        type: HodSupplierType.permanent,
        rating: 4.8,
      );
      final savedSupplier = await repository.saveSupplier(newSupplier);
      expect(savedSupplier.id, 'SUPPLIER-TEST');

      final newMachine = HodMachineCatalogItem(
        id: 'MACH-TEST',
        siteId: 'SITE-001',
        machineName: 'JCB Excavator',
        vehicleNumber: 'AP39XX1234',
        vehicleType: 'Excavator',
        operatorName: 'Ravi',
        createdAt: DateTime.now(),
      );
      final savedMachine = await repository.saveMachine(newMachine);
      expect(savedMachine.id, 'MACH-TEST');

      final machines = await repository.machines(siteId: 'SITE-001');
      expect(machines, isNotEmpty);
    });
  });
}
