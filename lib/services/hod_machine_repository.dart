import '../models/hod_machine_models.dart';

abstract class HodMachineRepository {
  Future<List<HodMachineSupplier>> suppliers({
    HodSupplierType type = HodSupplierType.all,
  });

  Future<List<HodMachineCatalogItem>> machines({
    required String siteId,
  });

  Future<List<HodMachineEntryRecord>> entries({
    required String siteId,
  });

  Future<List<HodMachineFinanceRequest>> financeRequests({
    required String siteId,
  });

  Future<HodMachineCatalogItem> saveMachine(HodMachineCatalogItem machine);

  Future<HodMachineSupplier> saveSupplier(HodMachineSupplier supplier);

  Future<HodMachineEntryRecord> submitEntry(HodMachineEntryRecord record);

  Future<HodMachineEntryRecord> approveAdvanceAndSubmitToFinance({
    required String entryId,
    required String paymentId,
    required String hodId,
  });

  Future<void> completeFinancePayment({
    required String entryId,
    required String paymentId,
    required String proofPath,
    required bool registerInMachineIdsBook,
  });
}

class HodMachineRepositoryHolder {
  HodMachineRepositoryHolder._();

  static final HodMachineRepository instance = InMemoryHodMachineRepository.instance;
}

class InMemoryHodMachineRepository implements HodMachineRepository {
  static final HodMachineRepository instance = InMemoryHodMachineRepository();

  final List<HodMachineSupplier> _suppliers = <HodMachineSupplier>[];
  final List<HodMachineCatalogItem> _machines = <HodMachineCatalogItem>[];
  final List<HodMachineEntryRecord> _entries = <HodMachineEntryRecord>[];
  final List<HodMachineFinanceRequest> _financeRequests =
      <HodMachineFinanceRequest>[];

  InMemoryHodMachineRepository() {
    final now = DateTime.now();
    _suppliers.addAll([
      const HodMachineSupplier(
        id: 'SUPPLIER-001',
        name: 'ABC Earth Movers',
        type: HodSupplierType.permanent,
        rating: 4.6,
        phone: '9876500011',
        notes: 'Preferred permanent supplier',
      ),
      const HodMachineSupplier(
        id: 'SUPPLIER-002',
        name: 'Delta Machinery Rentals',
        type: HodSupplierType.temporary,
        validUntil: null,
        rating: 4.1,
        phone: '9876500022',
        notes: 'Temporary backup supplier',
      ),
    ]);
    _machines.add(
      HodMachineCatalogItem(
        id: 'MACHINE-001',
        siteId: 'SITE-VJA-001',
        machineName: 'JCB Backhoe 3DX',
        vehicleNumber: 'AP16JC9090',
        vehicleType: 'Backhoe',
        operatorName: 'Mahesh',
        operatorPhone: '9876500999',
        createdByHodId: 'HOD-001',
        createdAt: now,
      ),
    );
  }

  @override
  Future<List<HodMachineSupplier>> suppliers({
    HodSupplierType type = HodSupplierType.all,
  }) async {
    if (type == HodSupplierType.all) {
      return List.unmodifiable(_suppliers);
    }
    return List.unmodifiable(
      _suppliers.where((supplier) => supplier.type == type),
    );
  }

  @override
  Future<List<HodMachineCatalogItem>> machines({
    required String siteId,
  }) async {
    return List.unmodifiable(
      _machines.where((machine) => machine.siteId == siteId),
    );
  }

  @override
  Future<List<HodMachineEntryRecord>> entries({
    required String siteId,
  }) async {
    return List.unmodifiable(
      _entries.where((entry) => entry.siteId == siteId),
    );
  }

  @override
  Future<List<HodMachineFinanceRequest>> financeRequests({
    required String siteId,
  }) async {
    return List.unmodifiable(
      _financeRequests.where((request) => request.siteId == siteId),
    );
  }

  @override
  Future<HodMachineCatalogItem> saveMachine(
    HodMachineCatalogItem machine,
  ) async {
    final existingIndex = _machines.indexWhere((item) => item.id == machine.id);
    if (existingIndex != -1) {
      _machines[existingIndex] = machine;
      return machine;
    }

    final duplicate = _machines.any(
      (item) =>
          item.vehicleNumber.toUpperCase() == machine.vehicleNumber.toUpperCase() &&
          item.id != machine.id,
    );
    if (duplicate) {
      throw StateError('Machine with same vehicle number already exists.');
    }

    _machines.insert(0, machine);
    return machine;
  }

  @override
  Future<HodMachineSupplier> saveSupplier(
    HodMachineSupplier supplier,
  ) async {
    final existingIndex = _suppliers.indexWhere((item) => item.id == supplier.id);
    if (existingIndex != -1) {
      _suppliers[existingIndex] = supplier;
      return supplier;
    }

    final duplicate = _suppliers.any(
      (item) => item.name.toLowerCase() == supplier.name.toLowerCase(),
    );
    if (duplicate) {
      throw StateError('Supplier with same name already exists.');
    }

    _suppliers.insert(0, supplier);
    return supplier;
  }

  @override
  Future<HodMachineEntryRecord> submitEntry(
    HodMachineEntryRecord record,
  ) async {
    final existingIndex = _entries.indexWhere((item) => item.id == record.id);
    if (existingIndex != -1) {
      _entries[existingIndex] = record;
      return record;
    }

    _entries.insert(0, record);
    return record;
  }

  @override
  Future<HodMachineEntryRecord> approveAdvanceAndSubmitToFinance({
    required String entryId,
    required String paymentId,
    required String hodId,
  }) async {
    final entryIndex = _entries.indexWhere((item) => item.id == entryId);
    if (entryIndex == -1) {
      throw StateError('Machine entry not found.');
    }

    final entry = _entries[entryIndex];
    final payment = entry.payments.firstWhere(
      (txn) => txn.id == paymentId,
      orElse: () => throw StateError('Payment transaction not found.'),
    );

    final financeRequest = HodMachineFinanceRequest(
      id: _nextId('FIN'),
      siteId: entry.siteId,
      hodId: hodId,
      machineEntryId: entry.id,
      paymentTransactionId: payment.id,
      title: 'Advance payment for ${entry.machine.machineName}',
      amount: payment.amount,
      paymentMode: payment.paymentMode,
      accountLabel: payment.accountLabel,
      createdAt: DateTime.now(),
    );

    _financeRequests.insert(0, financeRequest);
    final updatedEntry = entry.copyWith(
      status: HodMachineEntryStatus.pendingFinance,
    );
    _entries[entryIndex] = updatedEntry;
    return updatedEntry;
  }

  @override
  Future<void> completeFinancePayment({
    required String entryId,
    required String paymentId,
    required String proofPath,
    required bool registerInMachineIdsBook,
  }) async {
    final requestIndex = _financeRequests.indexWhere(
      (request) =>
          request.machineEntryId == entryId &&
          request.paymentTransactionId == paymentId,
    );
    if (requestIndex == -1) {
      throw StateError('Finance request not found.');
    }

    final existing = _financeRequests[requestIndex];
    _financeRequests[requestIndex] = existing.copyWith(
      completedAt: DateTime.now(),
      proofPath: proofPath,
      status: 'Completed',
    );
  }

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';
}
