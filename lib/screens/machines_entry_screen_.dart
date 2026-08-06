import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/collapsible_tab_scaffold.dart';
import '../models/supplier_model.dart';
import '../services/hod_site_workspace_service.dart';
import '../services/supplier_service.dart';
import '../services/supabase_supplier_repository.dart';
import '../services/attendance_context_service.dart';
import '../services/stock_inventory_repository.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/photo_capture_card.dart';
import '../widgets/advance_payment_request.dart';
import '../widgets/diesel_consumption_table.dart';
import '../features/hod_machine/data/repositories/supabase_hod_machine_repository.dart';
import '../features/hod_machine/domain/models/machine_asset.dart';
import '../features/hod_machine/domain/models/machine_daily_log.dart';
import '../features/hod_machine/domain/models/machine_diesel_line.dart';
import 'daily_data_screen.dart';

class MachineCatalogItem {
  final String id;
  final String machineName;
  final String vehicleNumber;
  final String vehicleType;
  final String operatorName;

  const MachineCatalogItem({
    required this.id,
    required this.machineName,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.operatorName,
  });

  MachineCatalogItem copyWith({
    String? id,
    String? machineName,
    String? vehicleNumber,
    String? vehicleType,
    String? operatorName,
  }) {
    return MachineCatalogItem(
      id: id ?? this.id,
      machineName: machineName ?? this.machineName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      operatorName: operatorName ?? this.operatorName,
    );
  }
}

class DieselEntry {
  final String id;
  final String fuelType;
  final String stockPoint;
  final double liters;
  final double amount;
  final String remarks;
  final DateTime createdAt;

  const DieselEntry({
    required this.id,
    required this.fuelType,
    required this.stockPoint,
    required this.liters,
    required this.amount,
    required this.createdAt,
    this.remarks = '',
  });

  DieselEntry copyWith({
    String? id,
    String? fuelType,
    String? stockPoint,
    double? liters,
    double? amount,
    String? remarks,
    DateTime? createdAt,
  }) {
    return DieselEntry(
      id: id ?? this.id,
      fuelType: fuelType ?? this.fuelType,
      stockPoint: stockPoint ?? this.stockPoint,
      liters: liters ?? this.liters,
      amount: amount ?? this.amount,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class VehicleDayRecord {
  final String id;
  final DateTime createdAt;
  final MachineCatalogItem machine;
  final String source;
  final String machineEntryStatus;
  final String billingType;
  final String dieselInclusion;
  final String supplierName;
  final String paymentMethod;
  final double fairAmount;
  final double advanceAmount;
  final String supervisorFuelType;
  final double supervisorFuelLiters;
  final String supervisorStockPoint;
  final String commissionAgentName;
  final double commissionAmount;
  final double betaEligibleHours;
  final double regularBetaAmount;
  final bool extraBetaApprovalEnabled;
  final double extraBetaLimit;
  final String hodPaymentReference;
  final String notes;
  final List<DieselEntry> dieselEntries;

  const VehicleDayRecord({
    required this.id,
    required this.createdAt,
    required this.machine,
    required this.source,
    this.machineEntryStatus = 'Submitted',
    this.billingType = '-',
    this.dieselInclusion = '-',
    this.supplierName = '-',
    this.paymentMethod = '-',
    this.fairAmount = 0,
    this.advanceAmount = 0,
    this.supervisorFuelType = '-',
    this.supervisorFuelLiters = 0,
    this.supervisorStockPoint = '-',
    this.commissionAgentName = '-',
    this.commissionAmount = 0,
    this.betaEligibleHours = 0,
    this.regularBetaAmount = 0,
    this.extraBetaApprovalEnabled = false,
    this.extraBetaLimit = 0,
    this.hodPaymentReference = '-',
    this.notes = '',
    this.dieselEntries = const [],
  });

  double get totalLiters =>
      dieselEntries.fold<double>(0, (sum, e) => sum + e.liters);
  double get totalDieselAmount =>
      dieselEntries.fold<double>(0, (sum, e) => sum + e.amount);
  double get totalAmount => fairAmount + advanceAmount + totalDieselAmount;

  VehicleDayRecord copyWith({
    String? id,
    DateTime? createdAt,
    MachineCatalogItem? machine,
    String? source,
    String? machineEntryStatus,
    String? billingType,
    String? dieselInclusion,
    String? supplierName,
    String? paymentMethod,
    double? fairAmount,
    double? advanceAmount,
    String? supervisorFuelType,
    double? supervisorFuelLiters,
    String? supervisorStockPoint,
    String? commissionAgentName,
    double? commissionAmount,
    double? betaEligibleHours,
    double? regularBetaAmount,
    bool? extraBetaApprovalEnabled,
    double? extraBetaLimit,
    String? hodPaymentReference,
    String? notes,
    List<DieselEntry>? dieselEntries,
  }) {
    return VehicleDayRecord(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      machine: machine ?? this.machine,
      source: source ?? this.source,
      machineEntryStatus: machineEntryStatus ?? this.machineEntryStatus,
      billingType: billingType ?? this.billingType,
      dieselInclusion: dieselInclusion ?? this.dieselInclusion,
      supplierName: supplierName ?? this.supplierName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      fairAmount: fairAmount ?? this.fairAmount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      supervisorFuelType: supervisorFuelType ?? this.supervisorFuelType,
      supervisorFuelLiters: supervisorFuelLiters ?? this.supervisorFuelLiters,
      supervisorStockPoint: supervisorStockPoint ?? this.supervisorStockPoint,
      commissionAgentName: commissionAgentName ?? this.commissionAgentName,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      betaEligibleHours: betaEligibleHours ?? this.betaEligibleHours,
      regularBetaAmount: regularBetaAmount ?? this.regularBetaAmount,
      extraBetaApprovalEnabled:
          extraBetaApprovalEnabled ?? this.extraBetaApprovalEnabled,
      extraBetaLimit: extraBetaLimit ?? this.extraBetaLimit,
      hodPaymentReference: hodPaymentReference ?? this.hodPaymentReference,
      notes: notes ?? this.notes,
      dieselEntries: dieselEntries ?? this.dieselEntries,
    );
  }
}

class HodMachineSubmission {
  final String id;
  final String machineName;
  final String vehicleNumber;
  final String vehicleType;
  final String fuelType;
  final double liters;
  final String stockPoint;
  final String supervisorName;
  final String siteName;
  final DateTime submittedAt;

  const HodMachineSubmission({
    required this.id,
    required this.machineName,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.fuelType,
    required this.liters,
    required this.stockPoint,
    required this.supervisorName,
    required this.siteName,
    required this.submittedAt,
  });
}

class MachinePaymentTransaction {
  final String id;
  final String type; // 'cash' or 'advance'
  final DateTime date;
  double amount;
  String status;
  String? paymentProof;
  bool registeredInMachineIdsBook;

  MachinePaymentTransaction({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    this.status = 'Requested',
    this.paymentProof,
    this.registeredInMachineIdsBook = false,
  });
}

class MachinesEntryScreen extends StatefulWidget {
  final bool isHOD;

  const MachinesEntryScreen({super.key, required this.isHOD});

  @override
  State<MachinesEntryScreen> createState() => _MachinesEntryScreenState();
}

class _MachinesEntryScreenState extends State<MachinesEntryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final SupplierService _supplierService = SupplierService();
  final StockInventoryRepository _stockRepository = StockInventoryRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  static const String _addMachineValue = '__add_machine__';

  bool _isSubmitting = false;
  bool _showDieselEntryForm = false;
  String? _editingDieselEntryId;

  // Common machine selection
  String? _selectedMachineId;
  final TextEditingController _newMachineNameController =
      TextEditingController();
  final TextEditingController _newVehicleNumberController =
      TextEditingController();
  final TextEditingController _newOperatorController = TextEditingController();

  // Diesel entry draft fields
  String? _draftFuelType;
  String? _draftStockPoint;
  final TextEditingController _draftLitersController = TextEditingController();
  final TextEditingController _draftAmountController = TextEditingController();
  final TextEditingController _draftRemarksController = TextEditingController();
  final List<DieselEntry> _draftDieselEntries = [];

  // HOD fields
  final TextEditingController _machineIdController = TextEditingController();
  final TextEditingController _operatorNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _usedAmountController = TextEditingController();
  final TextEditingController _usedAdvanceAmountController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _hodVehicleNumberController =
      TextEditingController();
  final TextEditingController _hodFuelLitersController =
      TextEditingController();
  final TextEditingController _commissionAgentController =
      TextEditingController();
  final TextEditingController _commissionAmountController =
      TextEditingController();
  final TextEditingController _hodAdvanceAmountController =
      TextEditingController();
  final TextEditingController _hodUpiIdController = TextEditingController();
  final TextEditingController _hodBankNameController = TextEditingController();
  final TextEditingController _hodAccountHolderController =
      TextEditingController();
  final TextEditingController _hodAccountNumberController =
      TextEditingController();
  final TextEditingController _hodIfscController = TextEditingController();
  final TextEditingController _betaEligibleHoursController =
      TextEditingController(text: '8');
  final TextEditingController _regularBetaAmountController =
      TextEditingController(text: '0');
  final TextEditingController _extraBetaLimitController =
      TextEditingController(text: '0');
  String? _selectedVehicleType;
  String? _selectedBillingType;
  String? _selectedDieselInclusion;
  String? _selectedSupplierName;
  String? _selectedSupplierType;
  String? _hodFuelType;
  String? _hodStockPoint;
  String? _hodAdvancePaymentMode;
  String? _selectedHodSubmissionId;
  bool _extraBetaApprovalEnabled = false;
  bool _showDieselTable = false;
  String? _selectedUsedPaymentMethod;
  String? _selectedUsedAdvanceMode;
  String? _selectedUsedEntryMethod;
  final double _cashLimit = 50000.0;
  double _dieselRemainingStock = 1250.0;
  final List<MachinePaymentTransaction> _machinePaymentLedger = [];
  final List<String> _completedHodSubmissionIds = [];

  final List<HodMachineSubmission> _hodSubmissions = [
    HodMachineSubmission(
      id: 'HOD-MCH-REQ-001',
      machineName: 'Poclain EX-200',
      vehicleNumber: 'AP39TB1234',
      vehicleType: 'Poclain',
      fuelType: 'Diesel',
      liters: 35,
      stockPoint: 'Main Depot',
      supervisorName: 'Rajesh Kumar',
      siteName: 'Vijayawada River Bed',
      submittedAt: DateTime(2026, 6, 15, 8, 20),
    ),
    HodMachineSubmission(
      id: 'HOD-MCH-REQ-002',
      machineName: 'Farm Tractor 45HP',
      vehicleNumber: 'AP37TR4589',
      vehicleType: 'Tractor',
      fuelType: 'Diesel',
      liters: 18,
      stockPoint: 'Site A',
      supervisorName: 'Mohan Reddy',
      siteName: 'Akividu Canal Line',
      submittedAt: DateTime(2026, 6, 15, 9, 05),
    ),
    HodMachineSubmission(
      id: 'HOD-MCH-REQ-003',
      machineName: 'JCB Backhoe',
      vehicleNumber: 'AP16JC9090',
      vehicleType: 'Backhoe',
      fuelType: 'Diesel',
      liters: 22,
      stockPoint: 'Warehouse 1',
      supervisorName: 'Suresh Babu',
      siteName: 'Rajahmundry Lift Point',
      submittedAt: DateTime(2026, 6, 15, 10, 10),
    ),
  ];

  final List<MachineCatalogItem> _machines = [
    const MachineCatalogItem(
      id: 'MCH-001',
      machineName: 'Poclain EX-200',
      vehicleNumber: 'AP39TB1234',
      vehicleType: 'Poclain',
      operatorName: 'Ravi Kumar',
    ),
    const MachineCatalogItem(
      id: 'MCH-002',
      machineName: 'Farm Tractor 45HP',
      vehicleNumber: 'AP37TR4589',
      vehicleType: 'Tractor',
      operatorName: 'Suresh',
    ),
    const MachineCatalogItem(
      id: 'MCH-003',
      machineName: 'JCB Backhoe',
      vehicleNumber: 'AP16JC9090',
      vehicleType: 'Backhoe',
      operatorName: 'Mahesh',
    ),
  ];

  final List<VehicleDayRecord> _todayVehicleRecords = [];

  final List<Map<String, dynamic>> _suppliers = [
    {
      'name': 'ABC Suppliers',
      'type': 'permanent',
      'validUntil': null,
      'rating': 4.5
    },
    {
      'name': 'XYZ Traders',
      'type': 'permanent',
      'validUntil': null,
      'rating': 4.2
    },
    {
      'name': 'Global Machinery',
      'type': 'temporary',
      'validUntil': '2026-12-31',
      'rating': 3.8
    },
    {
      'name': 'Local Parts Co.',
      'type': 'temporary',
      'validUntil': '2026-09-30',
      'rating': 4.0
    },
    {
      'name': 'Industrial Supplies',
      'type': 'permanent',
      'validUntil': null,
      'rating': 4.7
    },
    {
      'name': 'Metro Equipment',
      'type': 'temporary',
      'validUntil': '2026-10-15',
      'rating': 3.5
    },
  ];

  final List<String> _vehicleTypes = [
    'Poclain',
    'Tractor',
    'Dozer',
    'Excavator',
    'Loader',
    'Crane',
    'Backhoe',
    'Grader',
    'Roller',
    'Dumper',
    'Forklift',
    'Bulldozer',
  ];

  final List<String> _billingTypes = ['TRIP', 'HOUR', 'DAY', 'KM'];
  final List<String> _fuelTypes = ['Diesel', 'Petrol', 'CNG', 'Electric'];
  final List<String> _stockPoints = [
    'Site A — North',
    'Site B — South',
    'Warehouse Main',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hodFuelType = _fuelTypes.first;
    _hodStockPoint = _stockPoints.first;
    _seedTodayRecords();
    unawaited(_loadHodManagedSuppliers());
    unawaited(_loadLiveMachines());
  }

  /// Loads machines registered by the HOD / supervisor from Supabase
  /// (`machine_assets`) and merges them into the catalog ahead of the legacy
  /// seeds, deduped by id. Newly registered machines therefore appear
  /// immediately in the dropdown and flow into the Daily Machine screen.
  Future<void> _loadLiveMachines() async {
    try {
      final siteId = await _contextService.resolveSiteId();
      final assets = await SupabaseHodMachineRepository(null)
          .getMachines(siteId: siteId ?? 'SITE-VJA-001');
      if (!mounted) return;
      final live = assets
          .where((m) => m.isActive)
          .map((m) => MachineCatalogItem(
                id: m.id,
                machineName: m.machineName,
                vehicleNumber: m.vehicleNumber,
                vehicleType: m.vehicleType,
                operatorName: m.operatorName,
              ))
          .toList();
      setState(() {
        for (final machine in live.reversed) {
          if (_machines.any((entry) => entry.id == machine.id)) continue;
          _machines.insert(0, machine);
        }
      });
    } catch (e) {
      debugPrint('_loadLiveMachines failed: $e');
    }
  }

  /// Persists a newly registered machine into Supabase `machine_assets` so
  /// the HOD review screens and the Daily Machine screen (live catalog) see
  /// it immediately. Best-effort: a server failure never blocks the local
  /// entry workflow — the warning snackbar surfaces the real error.
  Future<void> _persistNewMachine(MachineCatalogItem machine) async {
    try {
      final siteId = await _contextService.resolveSiteId();
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      await SupabaseHodMachineRepository(null).createMachine(
        machine: MachineAsset(
          id: machine.id,
          siteId: siteId ?? 'SITE-VJA-001',
          machineName: machine.machineName,
          vehicleNumber: machine.vehicleNumber,
          vehicleType: machine.vehicleType,
          operatorName: machine.operatorName,
          createdBy: uid,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showSnackbar(
            'Machine saved locally; server sync pending: $e',
            AppTheme.warning);
      }
    }
  }

  Future<void> _loadHodManagedSuppliers() async {
    // Enterprise: HOD-created suppliers come from the Supabase catalog.
    final siteId = await _contextService.resolveSiteId();
    var suppliers =
        await SupabaseSupplierRepository().fetchForSupervisor(siteId: siteId);
    if (suppliers.isEmpty) {
      // Fallback to the legacy device-local store.
      suppliers = await _supplierService.usableSuppliersForSupervisor(
        supervisorId: 'THV-SUP-001',
        siteId: 'THV-SITE-CHN-001',
      );
    }
    if (!mounted) return;

    setState(() {
      _suppliers.removeWhere((supplier) => supplier['source'] == 'hod');
      for (final supplier in suppliers.reversed) {
        final duplicateIndex = _suppliers.indexWhere(
          (entry) =>
              entry['name'].toString().toLowerCase() ==
              supplier.name.toLowerCase(),
        );
        final mapped = _supplierMapFromHodSupplier(supplier);
        if (duplicateIndex >= 0) {
          _suppliers[duplicateIndex] = {
            ..._suppliers[duplicateIndex],
            ...mapped,
          };
        } else {
          _suppliers.insert(0, mapped);
        }
      }
    });
  }

  Map<String, dynamic> _supplierMapFromHodSupplier(Supplier supplier) {
    return {
      'name': supplier.name,
      'type': supplier.isTemporary ? 'temporary' : 'permanent',
      'validUntil': supplier.validUntil == null
          ? null
          : _formatDate(supplier.validUntil!),
      'rating': 5.0,
      'phone': supplier.phone,
      'purpose': supplier.usagePurpose,
      'category': supplier.category,
      'siteName': supplier.siteName,
      'supervisorId': supplier.supervisorId,
      'source': 'hod',
    };
  }

  void _seedTodayRecords() {
    final now = DateTime.now();
    _todayVehicleRecords.addAll([
      VehicleDayRecord(
        id: 'REC-${now.millisecondsSinceEpoch}-1',
        createdAt: now.subtract(const Duration(hours: 2)),
        machine: _machines[0],
        source: 'Supervisor Diesel Entry',
        billingType: 'Hourly',
        dieselInclusion: 'With diesel',
        supplierName: 'ABC Suppliers',
        dieselEntries: [
          DieselEntry(
            id: 'DIE-1',
            fuelType: 'Diesel',
            stockPoint: 'Main Depot',
            liters: 35,
            amount: 3400,
            createdAt: now.subtract(const Duration(hours: 2)),
            remarks: 'Morning work refill',
          ),
        ],
      ),
      VehicleDayRecord(
        id: 'REC-${now.millisecondsSinceEpoch}-2',
        createdAt: now.subtract(const Duration(hours: 1)),
        machine: _machines[1],
        source: 'HOD Machine Entry',
        billingType: 'Daily',
        dieselInclusion: 'Without diesel',
        supplierName: 'XYZ Traders',
        fairAmount: 8500,
        advanceAmount: 2000,
        notes: 'Pond bund work',
      ),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newMachineNameController.dispose();
    _newVehicleNumberController.dispose();
    _newOperatorController.dispose();
    _draftLitersController.dispose();
    _draftAmountController.dispose();
    _draftRemarksController.dispose();
    _machineIdController.dispose();
    _operatorNameController.dispose();
    _amountController.dispose();
    _usedAmountController.dispose();
    _usedAdvanceAmountController.dispose();
    _notesController.dispose();
    _hodVehicleNumberController.dispose();
    _hodFuelLitersController.dispose();
    _commissionAgentController.dispose();
    _commissionAmountController.dispose();
    _hodAdvanceAmountController.dispose();
    _hodUpiIdController.dispose();
    _hodBankNameController.dispose();
    _hodAccountHolderController.dispose();
    _hodAccountNumberController.dispose();
    _hodIfscController.dispose();
    _betaEligibleHoursController.dispose();
    _regularBetaAmountController.dispose();
    _extraBetaLimitController.dispose();
    super.dispose();
  }

  MachineCatalogItem? get _selectedMachine {
    if (_selectedMachineId == null) return null;
    return _machineById(_selectedMachineId);
  }

  MachineCatalogItem? _machineById(String? id) {
    if (id == null) return null;
    for (final machine in _machines) {
      if (machine.id == id) return machine;
    }
    return null;
  }

  String _numberForInput(double value) {
    if (value == 0) return '';
    if (value.truncateToDouble() == value) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _machinePrefixForType(String type) {
    final cleaned = type.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (cleaned.length >= 3) return cleaned.substring(0, 3);
    return cleaned.padRight(3, 'X');
  }

  String _generatedMachineIdFor(MachineCatalogItem machine) {
    final type = _selectedVehicleType ?? machine.vehicleType;
    final vehicleNumber = _hodVehicleNumberController.text.trim().isNotEmpty
        ? _hodVehicleNumberController.text.trim()
        : machine.vehicleNumber;
    final suffix =
        vehicleNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final tail =
        suffix.length > 4 ? suffix.substring(suffix.length - 4) : suffix;
    return '${_machinePrefixForType(type)}-$tail';
  }

  String _uniqueGeneratedMachineIdFor(MachineCatalogItem machine) {
    final base = _generatedMachineIdFor(machine);
    final duplicated =
        _machines.any((entry) => entry.id == base && entry.id != machine.id);
    if (!duplicated) return base;
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    return '$base-${suffix.substring(suffix.length - 4)}';
  }

  double get _draftTotalLiters =>
      _draftDieselEntries.fold<double>(0, (sum, e) => sum + e.liters);
  double get _draftTotalAmount =>
      _draftDieselEntries.fold<double>(0, (sum, e) => sum + e.amount);

  Map<String, List<VehicleDayRecord>> get _vehicleWiseTodayRecords {
    final grouped = <String, List<VehicleDayRecord>>{};
    for (final record in _todayVehicleRecords) {
      final key = record.machine.vehicleNumber;
      grouped.putIfAbsent(key, () => []).add(record);
    }
    return grouped;
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _selectMachine(MachineCatalogItem machine) {
    setState(() {
      _selectedMachineId = machine.id;
      _machineIdController.text = machine.id;
      _hodVehicleNumberController.text = machine.vehicleNumber;
      _operatorNameController.text = machine.operatorName;
      _selectedVehicleType = machine.vehicleType;
    });
  }

  List<HodMachineSubmission> get _pendingHodSubmissions => _hodSubmissions
      .where((request) => !_completedHodSubmissionIds.contains(request.id))
      .toList();

  void _loadHodSubmission(HodMachineSubmission request) {
    var machine = _machines.firstWhere(
      (entry) => entry.vehicleNumber == request.vehicleNumber,
      orElse: () {
        final created = MachineCatalogItem(
          id: 'TMP-${request.vehicleNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase()}',
          machineName: request.machineName,
          vehicleNumber: request.vehicleNumber,
          vehicleType: request.vehicleType,
          operatorName: '',
        );
        _machines.add(created);
        return created;
      },
    );

    setState(() {
      _selectedHodSubmissionId = request.id;
      _selectedMachineId = machine.id;
      _machineIdController.text = machine.id;
      _hodVehicleNumberController.text = request.vehicleNumber;
      _hodFuelType = request.fuelType;
      _hodFuelLitersController.text = _numberForInput(request.liters);
      _hodStockPoint = request.stockPoint;
      _selectedVehicleType = request.vehicleType;
      _operatorNameController.text = machine.operatorName;
    });
  }

  String _hodPaymentReference() {
    switch (_hodAdvancePaymentMode) {
      case 'UPI':
        return _hodUpiIdController.text.trim().isEmpty
            ? '-'
            : 'UPI: ${_hodUpiIdController.text.trim()}';
      case 'Bank Transfer':
        return [
          if (_hodAccountHolderController.text.trim().isNotEmpty)
            _hodAccountHolderController.text.trim(),
          if (_hodBankNameController.text.trim().isNotEmpty)
            _hodBankNameController.text.trim(),
          if (_hodAccountNumberController.text.trim().isNotEmpty)
            'A/C ${_hodAccountNumberController.text.trim()}',
          if (_hodIfscController.text.trim().isNotEmpty)
            'IFSC ${_hodIfscController.text.trim()}',
        ].join(' · ');
      case 'Cash':
        return 'Cash approved by HOD';
      default:
        return '-';
    }
  }

  void _showAddMachineSheet() {
    final formKey = GlobalKey<FormState>();
    String selectedType = _vehicleTypes.first;

    _newMachineNameController.clear();
    _newVehicleNumberController.clear();
    _newOperatorController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSheetTitle(
                        title: 'Add Machine / Vehicle',
                        subtitle:
                            'This item will be available in the dropdown immediately.',
                        icon: Icons.add_business_outlined,
                        color: AppTheme.success,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newMachineNameController,
                        decoration: const InputDecoration(
                          labelText: 'Machine Name',
                          hintText: 'Example: Poclain EX-200',
                          prefixIcon:
                              Icon(Icons.precision_manufacturing_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter machine name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newVehicleNumberController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Number',
                          hintText: 'Example: AP39TB1234',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter vehicle number'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Type',
                          prefixIcon: Icon(Icons.agriculture_outlined),
                        ),
                        items: _vehicleTypes
                            .map((type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          sheetSetState(() => selectedType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newOperatorController,
                        decoration: const InputDecoration(
                          labelText: 'Operator Name',
                          hintText: 'Example: Ravi Kumar',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ?? false))
                              return;
                            final machine = MachineCatalogItem(
                              id: 'MCH-${DateTime.now().millisecondsSinceEpoch}',
                              machineName:
                                  _newMachineNameController.text.trim(),
                              vehicleNumber: _newVehicleNumberController.text
                                  .trim()
                                  .toUpperCase(),
                              vehicleType: selectedType,
                              operatorName:
                                  _newOperatorController.text.trim().isEmpty
                                      ? 'Not assigned'
                                      : _newOperatorController.text.trim(),
                            );
                            setState(() {
                              _machines.insert(0, machine);
                              _todayVehicleRecords.insert(
                                0,
                                VehicleDayRecord(
                                  id: 'REC-${DateTime.now().millisecondsSinceEpoch}',
                                  createdAt: DateTime.now(),
                                  machine: machine,
                                  source: 'New Machine Added',
                                  notes: 'Machine created from entry dropdown.',
                                ),
                              );
                              _selectedMachineId = machine.id;
                              _machineIdController.text = machine.id;
                              _operatorNameController.text =
                                  machine.operatorName;
                              _selectedVehicleType = machine.vehicleType;
                            });
                            Navigator.pop(context);
                            // Persist to Supabase so the HOD review + Daily
                            // Machine screens see the new machine instantly.
                            unawaited(_persistNewMachine(machine));
                            _showSnackbar(
                                '${machine.vehicleNumber} added and saved.',
                                AppTheme.success);
                            // Seamlessly continue into the Daily Machine
                            // screen with this machine pre-selected.
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DailyDataScreen(
                                    initialMachineId: machine.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Add and Select'),
                          ),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMachineDropdown({String label = 'Machine / Vehicle'}) {
    return DropdownButtonFormField<String>(
      value: _selectedMachineId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.precision_manufacturing_outlined),
      ),
      items: [
        ..._machines.map(
          (machine) => DropdownMenuItem<String>(
            value: machine.id,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.agriculture_outlined,
                      size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${machine.machineName} • ${machine.vehicleNumber}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${machine.vehicleType} • ${machine.operatorName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const DropdownMenuItem<String>(
          value: _addMachineValue,
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppTheme.success),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enter / Add New Machine',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppTheme.success),
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        if (value == _addMachineValue) {
          _showAddMachineSheet();
          return;
        }
        final machine = _machines.firstWhere((m) => m.id == value);
        _selectMachine(machine);
      },
    );
  }

  void _showDieselFormForNewEntry() {
    setState(() {
      _editingDieselEntryId = null;
      _clearDieselDraftFields();
      _showDieselEntryForm = true;
    });
  }

  void _clearDieselDraftFields() {
    _draftFuelType = null;
    _draftStockPoint = null;
    _draftLitersController.clear();
    _draftAmountController.clear();
    _draftRemarksController.clear();
  }

  void _cancelDieselEntryForm() {
    setState(() {
      _showDieselEntryForm = false;
      _editingDieselEntryId = null;
      _clearDieselDraftFields();
    });
  }

  void _saveDieselDraftEntry() {
    if (_draftFuelType == null) {
      _showSnackbar('Please select fuel type', AppTheme.warning);
      return;
    }
    if (_draftStockPoint == null) {
      _showSnackbar('Please select stock point', AppTheme.warning);
      return;
    }
    final liters = double.tryParse(_draftLitersController.text.trim());
    if (liters == null || liters <= 0) {
      _showSnackbar('Please enter valid liters', AppTheme.danger);
      return;
    }
    final amount = double.tryParse(_draftAmountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackbar('Please enter valid amount', AppTheme.danger);
      return;
    }

    final entry = DieselEntry(
      id: _editingDieselEntryId ??
          'DIE-${DateTime.now().millisecondsSinceEpoch}',
      fuelType: _draftFuelType!,
      stockPoint: _draftStockPoint!,
      liters: liters,
      amount: amount,
      remarks: _draftRemarksController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() {
      if (_editingDieselEntryId == null) {
        _draftDieselEntries.insert(0, entry);
      } else {
        final index = _draftDieselEntries
            .indexWhere((e) => e.id == _editingDieselEntryId);
        if (index != -1) _draftDieselEntries[index] = entry;
      }
      _showDieselEntryForm = false;
      _editingDieselEntryId = null;
      _clearDieselDraftFields();
    });

    _showSnackbar('Diesel information saved.', AppTheme.success);
  }

  void _editDieselEntry(DieselEntry entry) {
    setState(() {
      _editingDieselEntryId = entry.id;
      _draftFuelType = entry.fuelType;
      _draftStockPoint = entry.stockPoint;
      _draftLitersController.text = entry.liters.toStringAsFixed(
          entry.liters.truncateToDouble() == entry.liters ? 0 : 1);
      _draftAmountController.text = entry.amount.toStringAsFixed(
          entry.amount.truncateToDouble() == entry.amount ? 0 : 2);
      _draftRemarksController.text = entry.remarks;
      _showDieselEntryForm = true;
    });
  }

  void _deleteDieselEntry(DieselEntry entry) {
    setState(() => _draftDieselEntries.removeWhere((e) => e.id == entry.id));
    _showSnackbar('Diesel entry removed.', AppTheme.danger);
  }

  Future<void> _submitSupervisorForm() async {
    final machine = _selectedMachine;
    if (machine == null) {
      _showSnackbar(
          'Please select or add a machine / vehicle', AppTheme.danger);
      return;
    }
    if (_draftDieselEntries.isEmpty) {
      _showSnackbar(
          'Please add at least one diesel information entry', AppTheme.warning);
      return;
    }

    setState(() => _isSubmitting = true);
    final submittedLiters = _draftTotalLiters;
    final submissionReference =
        'MACHINE-DIESEL-${DateTime.now().microsecondsSinceEpoch}';
    String? resolvedSiteId;
    try {
      resolvedSiteId = await _contextService.resolveSiteId();
      for (var index = 0; index < _draftDieselEntries.length; index++) {
        final entry = _draftDieselEntries[index];
        final balance = await _stockRepository.findFuelBalance(
          stockPointName: entry.stockPoint,
          fuelType: entry.fuelType,
        );
        await _stockRepository.issueForModule(
          siteId: resolvedSiteId,
          module: 'machines',
          sourceReference: '$submissionReference-$index',
          stockBalanceId: balance.id,
          quantity: entry.liters,
          note: '${machine.machineName} ${machine.vehicleNumber}: '
              '${entry.fuelType} (${entry.remarks})',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackbar('Diesel was not submitted: $error', AppTheme.danger);
      return;
    }
    if (!mounted) return;
    final dieselSnapshot = List<DieselEntry>.from(_draftDieselEntries);

    setState(() {
      _todayVehicleRecords.insert(
        0,
        VehicleDayRecord(
          id: 'REC-${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          machine: machine,
          source: 'Supervisor Diesel Entry',
          billingType: '-',
          dieselInclusion: 'Fuel issued from stock point',
          dieselEntries: dieselSnapshot,
        ),
      );
      _dieselRemainingStock =
          (_dieselRemainingStock - _draftTotalLiters).clamp(0, double.infinity);
      _isSubmitting = false;
      _draftDieselEntries.clear();
      _selectedMachineId = null;
      _showDieselEntryForm = false;
      _editingDieselEntryId = null;
    });

    unawaited(
      HodSiteWorkspaceService().recordSupervisorActivityForCurrentSession(
        module: 'Machines',
        action: 'Diesel entry submitted',
        details:
            '${machine.machineName} ${machine.vehicleNumber} submitted with ${submittedLiters.toStringAsFixed(1)} L diesel.',
      ),
    );
    unawaited(_syncMachineLogToServer(
      siteId: resolvedSiteId,
      machineId: machine.id,
      machineLabel: '${machine.machineName} ${machine.vehicleNumber}',
      supervisorFuelLiters: 0,
      supervisorFuelType: null,
      supervisorStockPoint: null,
      betaAmount: 0,
      extraBetaAmount: 0,
      notes: 'Supervisor diesel entry for ${machine.machineName} '
          '${machine.vehicleNumber} (${submittedLiters.toStringAsFixed(1)} L)',
      dieselEntries: dieselSnapshot,
    ));
    _showSnackbar('Vehicle diesel entry submitted and added to Today Vehicles.',
        AppTheme.success);
    _tabController.animateTo(1);
  }

  Future<void> _submitHODForm() async {
    final machine = _selectedMachine;
    if (machine == null) {
      _showSnackbar(
          'Please select or add a machine / vehicle', AppTheme.danger);
      return;
    }
    if (_hodVehicleNumberController.text.trim().isEmpty) {
      _showSnackbar('Please enter vehicle number', AppTheme.danger);
      return;
    }
    if (_selectedVehicleType == null) {
      _showSnackbar('Please select vehicle type', AppTheme.warning);
      return;
    }
    if (_selectedSupplierName == null) {
      _showSnackbar('Please select supplier name', AppTheme.warning);
      return;
    }
    if (_selectedBillingType == null) {
      _showSnackbar('Please select billing type', AppTheme.warning);
      return;
    }
    if (_selectedDieselInclusion == null) {
      _showSnackbar('Please select diesel inclusion', AppTheme.warning);
      return;
    }
    final vehicleFare = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (vehicleFare <= 0) {
      _showSnackbar('Please enter vehicle fare', AppTheme.danger);
      return;
    }
    final supervisorFuelLiters =
        double.tryParse(_hodFuelLitersController.text.trim()) ?? 0.0;
    if (supervisorFuelLiters < 0) {
      _showSnackbar('Please enter valid fuel litres', AppTheme.danger);
      return;
    }
    final commissionAmount =
        double.tryParse(_commissionAmountController.text.trim()) ?? 0.0;
    if (commissionAmount < 0) {
      _showSnackbar('Please enter valid commission amount', AppTheme.danger);
      return;
    }
    final hodAdvanceAmount =
        double.tryParse(_hodAdvanceAmountController.text.trim()) ?? 0.0;
    if (hodAdvanceAmount < 0) {
      _showSnackbar('Please enter valid advance amount', AppTheme.danger);
      return;
    }
    if (hodAdvanceAmount <= 0 && _hodAdvancePaymentMode != null) {
      _showSnackbar(
          'Enter advance amount for selected payment mode', AppTheme.warning);
      return;
    }
    if (hodAdvanceAmount > 0 && _hodAdvancePaymentMode == null) {
      _showSnackbar('Please select advance payment mode', AppTheme.warning);
      return;
    }
    if (_hodAdvancePaymentMode == 'UPI' &&
        _hodUpiIdController.text.trim().isEmpty) {
      _showSnackbar(
          'Please enter UPI ID for advance payment', AppTheme.warning);
      return;
    }
    if (_hodAdvancePaymentMode == 'Bank Transfer' &&
        (_hodBankNameController.text.trim().isEmpty ||
            _hodAccountHolderController.text.trim().isEmpty ||
            _hodAccountNumberController.text.trim().isEmpty ||
            _hodIfscController.text.trim().isEmpty)) {
      _showSnackbar('Please complete bank transfer details', AppTheme.warning);
      return;
    }
    final betaHours =
        double.tryParse(_betaEligibleHoursController.text.trim()) ?? 0.0;
    if (betaHours <= 0) {
      _showSnackbar('Please enter beta eligible hours', AppTheme.warning);
      return;
    }
    final regularBetaAmount =
        double.tryParse(_regularBetaAmountController.text.trim()) ?? 0.0;
    if (regularBetaAmount < 0) {
      _showSnackbar('Please enter valid regular beta amount', AppTheme.danger);
      return;
    }
    final extraBetaLimit =
        double.tryParse(_extraBetaLimitController.text.trim()) ?? 0.0;
    if (_extraBetaApprovalEnabled && extraBetaLimit <= 0) {
      _showSnackbar('Please enter extra beta limit', AppTheme.warning);
      return;
    }
    final usedCashAmount = _selectedUsedPaymentMethod == 'cash'
        ? (double.tryParse(_usedAmountController.text.trim()) ?? 0.0)
        : 0.0;
    final usedAdvanceAmount = _selectedUsedPaymentMethod == 'advance'
        ? (double.tryParse(_usedAdvanceAmountController.text.trim()) ?? 0.0)
        : 0.0;
    if (_selectedUsedPaymentMethod == 'cash' && usedCashAmount <= 0) {
      _showSnackbar('Please enter used cash amount', AppTheme.danger);
      return;
    }
    if (_selectedUsedPaymentMethod == 'advance' && usedAdvanceAmount <= 0) {
      _showSnackbar(
          'Please enter used advance request amount', AppTheme.danger);
      return;
    }
    if (_selectedUsedPaymentMethod == 'advance' &&
        (_selectedUsedAdvanceMode == null ||
            _selectedUsedEntryMethod == null)) {
      _showSnackbar('Please select used advance payment mode and entry method',
          AppTheme.warning);
      return;
    }
    if (usedCashAmount > _cashLimit * 0.7) {
      _showSnackbar(
          'Used amount exceeds HOD advance limit of ₹${(_cashLimit * 0.7).toStringAsFixed(0)}',
          AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    final hodSubmissionReference =
        'HOD-MACHINE-${DateTime.now().microsecondsSinceEpoch}';
    String? hodSiteId;
    try {
      hodSiteId = await _contextService.resolveSiteId();
      if (supervisorFuelLiters > 0) {
        final balance = await _stockRepository.findFuelBalance(
          stockPointName: _hodStockPoint ?? 'Site A — North',
          fuelType: _hodFuelType ?? 'Diesel',
        );
        await _stockRepository.issueForModule(
          siteId: hodSiteId,
          module: 'machines_hod',
          sourceReference: '$hodSubmissionReference-fuel',
          stockBalanceId: balance.id,
          quantity: supervisorFuelLiters,
          note: 'HOD fuel issue to ${machine.machineName} '
              '${machine.vehicleNumber}',
        );
      }
      for (var index = 0; index < _draftDieselEntries.length; index++) {
        final entry = _draftDieselEntries[index];
        final balance = await _stockRepository.findFuelBalance(
          stockPointName: entry.stockPoint,
          fuelType: entry.fuelType,
        );
        await _stockRepository.issueForModule(
          siteId: hodSiteId,
          module: 'machines_hod',
          sourceReference: '$hodSubmissionReference-$index',
          stockBalanceId: balance.id,
          quantity: entry.liters,
          note: 'HOD diesel entry: ${entry.fuelType} (${entry.remarks})',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackbar('HOD entry was not saved: $error', AppTheme.danger);
      return;
    }
    if (!mounted) return;
    final hodDieselSnapshot = List<DieselEntry>.from(_draftDieselEntries);

    final operatorName = _operatorNameController.text.trim().isEmpty
        ? machine.operatorName
        : _operatorNameController.text.trim();
    final generatedMachineId = _uniqueGeneratedMachineIdFor(machine);
    final paymentReference = _hodPaymentReference();
    final hodNotes = [
      if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
      'Generated Machine ID: $generatedMachineId',
      'Supervisor Vehicle No: ${_hodVehicleNumberController.text.trim()}',
      'Supervisor Fuel: ${_hodFuelType ?? '-'} / ${supervisorFuelLiters.toStringAsFixed(1)} L / ${_hodStockPoint ?? '-'}',
      if (_commissionAgentController.text.trim().isNotEmpty)
        'Commission Agent: ${_commissionAgentController.text.trim()}',
      if (commissionAmount > 0)
        'Commission Amount: ₹${commissionAmount.toStringAsFixed(0)}',
      if (hodAdvanceAmount > 0)
        'Advance Payment: ₹${hodAdvanceAmount.toStringAsFixed(0)} via ${_hodAdvancePaymentMode ?? '-'}',
      'Beta Eligible Hours: ${betaHours.toStringAsFixed(1)}',
      'Regular Beta Amount: ₹${regularBetaAmount.toStringAsFixed(0)}',
      'Extra Beta Approval: ${_extraBetaApprovalEnabled ? 'Enabled' : 'Disabled'}',
      if (_extraBetaApprovalEnabled)
        'Extra Beta Limit: ₹${extraBetaLimit.toStringAsFixed(0)}',
    ].join('\n');

    final updatedMachine = machine.copyWith(
      id: generatedMachineId,
      vehicleNumber: _hodVehicleNumberController.text.trim().toUpperCase(),
      operatorName: operatorName,
      vehicleType: _selectedVehicleType ?? machine.vehicleType,
    );
    setState(() {
      final index = _machines.indexWhere((m) => m.id == machine.id);
      if (index != -1) _machines[index] = updatedMachine;
      final paymentTransactions = <MachinePaymentTransaction>[];
      if (usedCashAmount > 0) {
        paymentTransactions.add(
          MachinePaymentTransaction(
            id: 'MCP-${DateTime.now().millisecondsSinceEpoch + 1}',
            type: 'cash',
            date: DateTime.now(),
            amount: usedCashAmount,
            status: 'Completed',
          ),
        );
      }
      if (usedAdvanceAmount > 0) {
        paymentTransactions.add(
          MachinePaymentTransaction(
            id: 'MAR-${DateTime.now().millisecondsSinceEpoch + 1}',
            type: 'advance',
            date: DateTime.now(),
            amount: usedAdvanceAmount,
          ),
        );
      }
      if (hodAdvanceAmount > 0) {
        paymentTransactions.add(
          MachinePaymentTransaction(
            id: 'HAD-${DateTime.now().millisecondsSinceEpoch + 2}',
            type: 'advance',
            date: DateTime.now(),
            amount: hodAdvanceAmount,
            status:
                _hodAdvancePaymentMode == 'Cash' ? 'Completed' : 'Requested',
            paymentProof: paymentReference == '-' ? null : paymentReference,
          ),
        );
      }
      _machinePaymentLedger.insertAll(0, paymentTransactions);
      if (_selectedHodSubmissionId != null &&
          !_completedHodSubmissionIds.contains(_selectedHodSubmissionId)) {
        _completedHodSubmissionIds.add(_selectedHodSubmissionId!);
      }
      _todayVehicleRecords.insert(
        0,
        VehicleDayRecord(
          id: 'REC-${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          machine: updatedMachine,
          source: 'HOD Machine Entry',
          machineEntryStatus: 'Completed by HOD',
          billingType: _selectedBillingType ?? '-',
          dieselInclusion: _selectedDieselInclusion ?? '-',
          supplierName: _selectedSupplierName ?? '-',
          paymentMethod: _hodAdvancePaymentMode ?? '-',
          fairAmount: vehicleFare,
          advanceAmount: hodAdvanceAmount + usedCashAmount + usedAdvanceAmount,
          supervisorFuelType: _hodFuelType ?? '-',
          supervisorFuelLiters: supervisorFuelLiters,
          supervisorStockPoint: _hodStockPoint ?? '-',
          commissionAgentName: _commissionAgentController.text.trim().isEmpty
              ? '-'
              : _commissionAgentController.text.trim(),
          commissionAmount: commissionAmount,
          betaEligibleHours: betaHours,
          regularBetaAmount: regularBetaAmount,
          extraBetaApprovalEnabled: _extraBetaApprovalEnabled,
          extraBetaLimit: _extraBetaApprovalEnabled ? extraBetaLimit : 0,
          hodPaymentReference: paymentReference,
          notes: hodNotes,
          dieselEntries: List<DieselEntry>.from(_draftDieselEntries),
        ),
      );
      _isSubmitting = false;
      _clearHODForm();
    });

    _showSnackbar('HOD machine entry completed and added to Today Vehicles.',
        AppTheme.success);
    unawaited(_syncMachineLogToServer(
      siteId: hodSiteId,
      machineId: machine.id,
      machineLabel: '${machine.machineName} ${machine.vehicleNumber}',
      supervisorFuelLiters: supervisorFuelLiters,
      supervisorFuelType: _hodFuelType,
      supervisorStockPoint: _hodStockPoint,
      betaAmount: regularBetaAmount,
      extraBetaAmount: _extraBetaApprovalEnabled ? extraBetaLimit : 0,
      notes: hodNotes,
      dieselEntries: hodDieselSnapshot,
    ));
    _tabController.animateTo(1);
  }

  /// Best-effort server sync of a machine entry into machine_daily_logs.
  ///
  /// One daily log per machine per day (first submission creates it, later
  /// submissions append fuel lines). Requires a real machine_assets row for
  /// `machineId` (MCH-001..003 are seeded by migration 00025) and a resolved
  /// thavvu point. Failures never block the local workflow — the stock
  /// deduction is the correctness-critical part and already succeeded.
  Future<void> _syncMachineLogToServer({
    required String? siteId,
    required String machineId,
    required String machineLabel,
    required double supervisorFuelLiters,
    required String? supervisorFuelType,
    required String? supervisorStockPoint,
    required double betaAmount,
    required double extraBetaAmount,
    required String notes,
    required List<DieselEntry> dieselEntries,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final resolvedSiteId = siteId ?? 'SITE-VJA-001';

      String? thavvuPointId;
      try {
        final assignment = await client
            .from('thavvu_point_assignments')
            .select('thavvu_point_id')
            .eq('supervisor_id', user.id)
            .eq('is_active', true)
            .order('assigned_at', ascending: false)
            .limit(1)
            .maybeSingle();
        thavvuPointId = assignment?['thavvu_point_id'] as String?;
      } catch (_) {
        // Fall through to site-level point lookup.
      }
      if (thavvuPointId == null) {
        try {
          final point = await client
              .from('thavvu_points')
              .select('id')
              .eq('site_id', resolvedSiteId)
              .limit(1)
              .maybeSingle();
          thavvuPointId = point?['id'] as String?;
        } catch (_) {
          // No point resolvable — skip server sync.
        }
      }
      if (thavvuPointId == null) return;

      final lines = <MachineDieselLine>[
        for (final entry in dieselEntries)
          MachineDieselLine(
            id:
                'DL-${DateTime.now().microsecondsSinceEpoch}-${dieselEntries.indexOf(entry)}',
            dailyLogId: '',
            fuelType: entry.fuelType,
            stockPoint: entry.stockPoint,
            liters: entry.liters,
            amount: entry.amount,
            remarks: entry.remarks,
          ),
        if (supervisorFuelLiters > 0)
          MachineDieselLine(
            id: 'DL-${DateTime.now().microsecondsSinceEpoch}-sup',
            dailyLogId: '',
            fuelType: supervisorFuelType ?? 'Diesel',
            stockPoint: supervisorStockPoint,
            liters: supervisorFuelLiters,
            amount: 0,
            remarks: 'Supervisor fuel',
          ),
      ];
      if (lines.isEmpty) return;

      final today = DateTime.now();
      final todayKey =
          DateTime(today.year, today.month, today.day).toIso8601String();

      String? existingLogId;
      try {
        final existing = await client
            .from('machine_daily_logs')
            .select('id')
            .eq('machine_id', machineId)
            .eq('log_date', todayKey)
            .not('status', 'in', '("draft","rejected")')
            .limit(1)
            .maybeSingle();
        existingLogId = existing?['id'] as String?;
      } catch (_) {
        // No existing log — create a new one below.
      }

      if (existingLogId != null) {
        await client.from('machine_daily_diesel_lines').insert(
              lines
                  .map((line) => {
                        ...line.toJson(),
                        'id': '${line.id}-$existingLogId',
                        'daily_log_id': existingLogId,
                      })
                  .toList(),
            );
      } else {
        final log = MachineDailyLog(
          id: 'LOG-${DateTime.now().microsecondsSinceEpoch}',
          logDate: today,
          siteId: resolvedSiteId,
          thavvuPointId: thavvuPointId,
          supervisorId: user.id,
          machineId: machineId,
          location: machineLabel,
          dieselOption: 'Fuel issued from stock point',
          workingHours: 0,
          workerCount: 0,
          betaAmount: betaAmount,
          extraBetaAmount: extraBetaAmount,
          notes: notes,
          status: DailyLogStatus.submitted,
          submittedAt: DateTime.now(),
          dieselLines: lines,
        );
        await SupabaseHodMachineRepository(null).submitDailyLog(log);
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackbar('Saved locally; server sync pending: $error',
          AppTheme.warning);
    }
  }

  void _clearHODForm() {
    _machineIdController.clear();
    _operatorNameController.clear();
    _amountController.clear();
    _usedAmountController.clear();
    _usedAdvanceAmountController.clear();
    _notesController.clear();
    _hodVehicleNumberController.clear();
    _hodFuelLitersController.clear();
    _commissionAgentController.clear();
    _commissionAmountController.clear();
    _hodAdvanceAmountController.clear();
    _hodUpiIdController.clear();
    _hodBankNameController.clear();
    _hodAccountHolderController.clear();
    _hodAccountNumberController.clear();
    _hodIfscController.clear();
    _betaEligibleHoursController.text = '8';
    _regularBetaAmountController.text = '0';
    _extraBetaLimitController.text = '0';
    _draftDieselEntries.clear();
    _clearDieselDraftFields();
    setState(() {
      _selectedMachineId = null;
      _selectedVehicleType = null;
      _selectedBillingType = null;
      _selectedDieselInclusion = null;
      _selectedSupplierName = null;
      _selectedSupplierType = null;
      _hodFuelType = _fuelTypes.first;
      _hodStockPoint = _stockPoints.first;
      _hodAdvancePaymentMode = null;
      _selectedHodSubmissionId = null;
      _extraBetaApprovalEnabled = false;
      _selectedUsedPaymentMethod = null;
      _selectedUsedAdvanceMode = null;
      _selectedUsedEntryMethod = null;
      _showDieselTable = false;
      _showDieselEntryForm = false;
      _editingDieselEntryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: widget.isHOD ? 'Machine Registration' : 'Machine Diesel Entry',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
            ),
            controller: _tabController,
            tabs: const [
              Tab(text: 'Entry'),
              Tab(text: 'Today Vehicles'),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            widget.isHOD ? _buildHODEntryTab() : _buildSupervisorEntryTab(),
            _buildTodayVehiclesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorEntryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            emoji: '⛽',
            title: 'Quick Diesel Entry',
            subtitle:
                'Select or add vehicle, then add diesel information as editable mini-cards.',
            color: AppTheme.warning,
          ),
          const SizedBox(height: 16),
          _buildStockBanner(),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '1',
            title: 'Machine / Vehicle',
            color: AppTheme.primary,
            child: Column(
              children: [
                _buildMachineDropdown(label: 'Select or enter machine'),
                if (_selectedMachine != null) ...[
                  const SizedBox(height: 12),
                  _buildMachinePreview(_selectedMachine!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            step: '2',
            title: 'Diesel Information',
            color: AppTheme.warning,
            child: _buildDieselEntryArea(),
          ),
          const SizedBox(height: 16),
          _buildDieselDraftSummary(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitSupervisorForm,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Diesel Entry'),
              ),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHODEntryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            emoji: '🚜',
            title: 'New Machine Registration',
            subtitle:
                'Select existing machine or add one from the dropdown. Submitted records appear vehicle-wise today.',
            color: AppTheme.warning,
          ),
          const SizedBox(height: 16),
          _buildProgressIndicator(),
          const SizedBox(height: 16),
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildStockBanner(),
          const SizedBox(height: 16),
          _buildHodSubmissionQueue(),
          const SizedBox(height: 12),
          _buildStepCard(
            step: '1',
            title: 'Machine Entry',
            color: AppTheme.warning,
            child: Column(
              children: [
                _buildMachineDropdown(label: 'Select machine or enter new'),
                if (_selectedMachine != null) ...[
                  const SizedBox(height: 12),
                  _buildMachinePreview(_selectedMachine!),
                ],
                const SizedBox(height: 10),
                const HodApprovalBadge(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            step: '2',
            title: 'Supervisor Submitted Data',
            color: AppTheme.info,
            child: _buildSupervisorSubmittedDataSection(),
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            step: '3',
            title: 'HOD Entry Detail',
            color: AppTheme.success,
            child: _buildHodEntryDetailSection(),
          ),
          const SizedBox(height: 12),
          if (_showDieselTable) ...[
            _buildStepCard(
                step: '3a',
                title: 'Diesel Consumption Details',
                child: _buildDieselConsumptionTable(),
                color: AppTheme.warning),
            const SizedBox(height: 12),
          ],
          _buildStepCard(
            step: '4',
            title: 'Beta Settings',
            child: _buildBetaSettingsSection(),
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          _buildStepCard(
              step: '5',
              title: 'Payment Ledger',
              child: _buildAdvancePayments(),
              color: AppTheme.danger),
          const SizedBox(height: 12),
          _buildStepCard(
              step: '6',
              title: 'Additional Notes',
              child: _buildNotesField(),
              color: AppTheme.success),
          const SizedBox(height: 12),
          _buildStepCard(
              step: '7',
              title: 'Opening Photo',
              child: _buildPhotoCard(),
              color: AppTheme.warning),
          const SizedBox(height: 16),
          _buildHODSummaryCard(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitHODForm,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_isSubmitting
                    ? 'Submitting...'
                    : 'Complete HOD Machine Entry'),
              ),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDieselEntryArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_draftDieselEntries.isEmpty && !_showDieselEntryForm)
          _buildEmptyDieselPrompt(),
        if (_showDieselEntryForm) _buildDieselEntryForm(),
        if (!_showDieselEntryForm) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showDieselFormForNewEntry,
              icon: const Icon(Icons.add),
              label: Text(_draftDieselEntries.isEmpty
                  ? 'Add Diesel Information'
                  : 'Add Another Diesel Entry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warning,
                side: const BorderSide(color: AppTheme.warning),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
        if (_draftDieselEntries.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Minimised diesel entries',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
              ),
              _buildPill('${_draftDieselEntries.length} entries',
                  AppTheme.warning, Icons.list_alt_outlined),
            ],
          ),
          const SizedBox(height: 8),
          ..._draftDieselEntries.map(_buildMinimisedDieselCard),
        ],
      ],
    );
  }

  Widget _buildEmptyDieselPrompt() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.local_gas_station_outlined, color: AppTheme.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add diesel information. After saving, each entry becomes a small editable card.',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDieselEntryForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPill(
                  _editingDieselEntryId == null ? 'NEW ENTRY' : 'EDIT ENTRY',
                  AppTheme.warning,
                  Icons.local_gas_station),
              const Spacer(),
              IconButton(
                onPressed: _cancelDieselEntryForm,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _draftFuelType,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Type of Fuel',
                prefixIcon: Icon(Icons.local_gas_station)),
            items: _fuelTypes
                .map((type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _draftFuelType = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _draftStockPoint,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Stock Point',
                prefixIcon: Icon(Icons.location_on_outlined)),
            items: _stockPoints
                .map((point) =>
                    DropdownMenuItem<String>(value: point, child: Text(point)))
                .toList(),
            onChanged: (value) => setState(() => _draftStockPoint = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _draftLitersController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Liters', prefixIcon: Icon(Icons.straighten)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _draftAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount ₹',
                      prefixIcon: Icon(Icons.currency_rupee)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _draftRemarksController,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Remarks optional',
                prefixIcon: Icon(Icons.notes_outlined)),
          ),
          const SizedBox(height: 14),
          _buildResponsiveActionButtons(
            secondary: OutlinedButton(
              onPressed: _cancelDieselEntryForm,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.danger),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            primary: ElevatedButton.icon(
              onPressed: _saveDieselDraftEntry,
              icon: const Icon(Icons.check),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                    _editingDieselEntryId == null ? 'Add Entry' : 'Save Edit'),
              ),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimisedDieselCard(DieselEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_gas_station,
              color: AppTheme.warning, size: 20),
        ),
        title: Text(
          '${entry.fuelType} • ${entry.liters.toStringAsFixed(1)} L',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${entry.stockPoint} • ₹${entry.amount.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editDieselEntry(entry),
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.info, size: 19),
              tooltip: 'Edit',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Row(
            children: [
              Expanded(child: _buildMiniMetric('Fuel', entry.fuelType)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMiniMetric(
                      'Liters', '${entry.liters.toStringAsFixed(1)} L')),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMiniMetric(
                      'Amount', '₹${entry.amount.toStringAsFixed(0)}')),
            ],
          ),
          const SizedBox(height: 8),
          _buildMiniMetric('Stock Point', entry.stockPoint),
          if (entry.remarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMiniMetric('Remarks', entry.remarks),
          ],
          const SizedBox(height: 10),
          _buildResponsiveActionButtons(
            secondary: OutlinedButton.icon(
              onPressed: () => _editDieselEntry(entry),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            primary: OutlinedButton.icon(
              onPressed: () => _deleteDieselEntry(entry),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditVehicleRecordSheet(VehicleDayRecord record) {
    final formKey = GlobalKey<FormState>();
    final bool isNewMachineRecord = record.source == 'New Machine Added';
    final bool isSupervisorRecord = record.source == 'Supervisor Diesel Entry';

    // HOD Machine Entry records are intentionally display-only in Today Vehicles.
    // They should be edited from the main HOD entry/approval workflow, not from this list.
    if (!isNewMachineRecord && !isSupervisorRecord) {
      _showSnackbar('HOD Machine Entry is display-only in Today Vehicles.',
          AppTheme.info);
      return;
    }

    String? localMachineId = record.machine.id;
    String? localVehicleType = record.machine.vehicleType;

    final machineNameController =
        TextEditingController(text: record.machine.machineName);
    final vehicleNumberController =
        TextEditingController(text: record.machine.vehicleNumber);
    final operatorController =
        TextEditingController(text: record.machine.operatorName);
    final localDieselEntries = List<DieselEntry>.from(record.dieselEntries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final selectedCatalogMachine = _machineById(localMachineId);
            final machineForPreview = isNewMachineRecord
                ? record.machine.copyWith(
                    machineName: machineNameController.text.trim().isEmpty
                        ? record.machine.machineName
                        : machineNameController.text.trim(),
                    vehicleNumber: vehicleNumberController.text.trim().isEmpty
                        ? record.machine.vehicleNumber
                        : vehicleNumberController.text.trim().toUpperCase(),
                    vehicleType: localVehicleType ?? record.machine.vehicleType,
                    operatorName: operatorController.text.trim().isEmpty
                        ? 'Not assigned'
                        : operatorController.text.trim(),
                  )
                : selectedCatalogMachine;

            final localDieselLiters = localDieselEntries.fold<double>(
              0,
              (sum, entry) => sum + entry.liters,
            );
            final localDieselAmount = localDieselEntries.fold<double>(
              0,
              (sum, entry) => sum + entry.amount,
            );

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSheetTitle(
                        title: isNewMachineRecord
                            ? 'Edit New Machine'
                            : 'Edit Diesel Entry Record',
                        subtitle: isNewMachineRecord
                            ? 'Only the machine details entered while adding are editable here.'
                            : 'Only machine selection and diesel information are editable for this supervisor entry.',
                        icon: Icons.edit_note_outlined,
                        color: AppTheme.info,
                      ),
                      const SizedBox(height: 16),
                      if (isNewMachineRecord) ...[
                        TextFormField(
                          controller: machineNameController,
                          decoration: const InputDecoration(
                            labelText: 'Machine Name',
                            prefixIcon:
                                Icon(Icons.precision_manufacturing_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter machine name'
                                  : null,
                          onChanged: (_) => sheetSetState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: vehicleNumberController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Number',
                            prefixIcon:
                                Icon(Icons.confirmation_number_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter vehicle number'
                                  : null,
                          onChanged: (_) => sheetSetState(() {}),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: localVehicleType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Type',
                            prefixIcon: Icon(Icons.agriculture_outlined),
                          ),
                          items: _vehicleTypes
                              .map((type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              sheetSetState(() => localVehicleType = value),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: operatorController,
                          decoration: const InputDecoration(
                            labelText: 'Operator Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          onChanged: (_) => sheetSetState(() {}),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          value: localMachineId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Machine / Vehicle',
                            prefixIcon:
                                Icon(Icons.precision_manufacturing_outlined),
                          ),
                          items: _machines.map((machine) {
                            return DropdownMenuItem<String>(
                              value: machine.id,
                              child: Text(
                                '${machine.machineName} • ${machine.vehicleNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              sheetSetState(() => localMachineId = value),
                          validator: (value) =>
                              value == null ? 'Select machine / vehicle' : null,
                        ),
                      ],
                      if (machineForPreview != null) ...[
                        const SizedBox(height: 10),
                        _buildMachinePreview(machineForPreview),
                      ],
                      if (isSupervisorRecord) ...[
                        const SizedBox(height: 16),
                        _buildEditableDieselList(
                          localDieselEntries,
                          onAdd: () {
                            _showDieselEntryEditorSheet(
                              onSave: (entry) {
                                sheetSetState(
                                    () => localDieselEntries.insert(0, entry));
                              },
                            );
                          },
                          onEdit: (entry) {
                            _showDieselEntryEditorSheet(
                              initial: entry,
                              onSave: (updated) {
                                sheetSetState(() {
                                  final index = localDieselEntries
                                      .indexWhere((e) => e.id == entry.id);
                                  if (index != -1)
                                    localDieselEntries[index] = updated;
                                });
                              },
                            );
                          },
                          onDelete: (entry) {
                            sheetSetState(() {
                              localDieselEntries
                                  .removeWhere((e) => e.id == entry.id);
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.infoBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.info.withOpacity(0.20)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  child: _buildMiniMetric('Diesel',
                                      '${localDieselLiters.toStringAsFixed(1)} L')),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _buildMiniMetric('Diesel Amt',
                                      '₹${localDieselAmount.toStringAsFixed(0)}')),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ?? false))
                              return;

                            MachineCatalogItem updatedMachine;
                            if (isNewMachineRecord) {
                              updatedMachine = record.machine.copyWith(
                                machineName: machineNameController.text.trim(),
                                vehicleNumber: vehicleNumberController.text
                                    .trim()
                                    .toUpperCase(),
                                vehicleType: localVehicleType ??
                                    record.machine.vehicleType,
                                operatorName:
                                    operatorController.text.trim().isEmpty
                                        ? 'Not assigned'
                                        : operatorController.text.trim(),
                              );
                            } else {
                              final selectedMachine =
                                  _machineById(localMachineId);
                              if (selectedMachine == null) {
                                _showSnackbar('Please select machine / vehicle',
                                    AppTheme.danger);
                                return;
                              }
                              updatedMachine = selectedMachine;
                            }

                            final updatedRecord = record.copyWith(
                              machine: updatedMachine,
                              dieselInclusion: isSupervisorRecord
                                  ? 'Fuel issued from stock point'
                                  : record.dieselInclusion,
                              dieselEntries: isSupervisorRecord
                                  ? List<DieselEntry>.from(localDieselEntries)
                                  : record.dieselEntries,
                            );

                            setState(() {
                              final machineIndex = _machines
                                  .indexWhere((m) => m.id == updatedMachine.id);
                              if (machineIndex != -1)
                                _machines[machineIndex] = updatedMachine;
                              for (var i = 0;
                                  i < _todayVehicleRecords.length;
                                  i++) {
                                if (_todayVehicleRecords[i].machine.id ==
                                    updatedMachine.id) {
                                  _todayVehicleRecords[i] =
                                      _todayVehicleRecords[i]
                                          .copyWith(machine: updatedMachine);
                                }
                              }
                              final recordIndex = _todayVehicleRecords
                                  .indexWhere((r) => r.id == record.id);
                              if (recordIndex != -1)
                                _todayVehicleRecords[recordIndex] =
                                    updatedRecord;
                            });
                            Navigator.pop(context);
                            _showSnackbar('Today vehicle entry updated.',
                                AppTheme.success);
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Save Vehicle Entry'),
                          ),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResponsiveActionButtons({
    required Widget primary,
    required Widget secondary,
    double breakpoint = 360,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth < breakpoint;
        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: secondary),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: primary),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: secondary),
            const SizedBox(width: 10),
            Expanded(child: primary),
          ],
        );
      },
    );
  }

  Widget _buildEditableDieselList(
    List<DieselEntry> entries, {
    required VoidCallback onAdd,
    required ValueChanged<DieselEntry> onEdit,
    required ValueChanged<DieselEntry> onDelete,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Diesel Entries',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warning,
                  side: const BorderSide(color: AppTheme.warning),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text(
              'No diesel entries added for this vehicle record.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else
            ...entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_gas_station,
                            size: 18, color: AppTheme.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${entry.fuelType} • ${entry.stockPoint}',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => onEdit(entry),
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: AppTheme.info),
                          tooltip: 'Edit diesel entry',
                        ),
                        IconButton(
                          onPressed: () => onDelete(entry),
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.danger),
                          tooltip: 'Delete diesel entry',
                        ),
                      ],
                    ),
                    Text(
                      '${entry.liters.toStringAsFixed(1)} L • ₹${entry.amount.toStringAsFixed(0)}${entry.remarks.isEmpty ? '' : ' • ${entry.remarks}'}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDieselEntryEditorSheet({
    DieselEntry? initial,
    required ValueChanged<DieselEntry> onSave,
  }) {
    String? fuelType = initial?.fuelType ?? _fuelTypes.first;
    String? stockPoint = initial?.stockPoint ?? _stockPoints.first;
    final litersController = TextEditingController(
        text: initial == null ? '' : _numberForInput(initial.liters));
    final amountController = TextEditingController(
        text: initial == null ? '' : _numberForInput(initial.amount));
    final remarksController =
        TextEditingController(text: initial?.remarks ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSheetTitle(
                      title: initial == null
                          ? 'Add Diesel Entry'
                          : 'Edit Diesel Entry',
                      subtitle:
                          'This updates only the selected today vehicle record.',
                      icon: Icons.local_gas_station_outlined,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: fuelType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Fuel Type',
                        prefixIcon: Icon(Icons.local_gas_station),
                      ),
                      items: _fuelTypes
                          .map((type) => DropdownMenuItem<String>(
                              value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) =>
                          sheetSetState(() => fuelType = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: stockPoint,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Stock Point',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: _stockPoints
                          .map((point) => DropdownMenuItem<String>(
                              value: point, child: Text(point)))
                          .toList(),
                      onChanged: (value) =>
                          sheetSetState(() => stockPoint = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: litersController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Liters',
                              prefixIcon: Icon(Icons.straighten),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount ₹',
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Remarks optional',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final liters =
                              double.tryParse(litersController.text.trim());
                          final amount =
                              double.tryParse(amountController.text.trim());
                          if (fuelType == null || stockPoint == null) {
                            _showSnackbar('Please select fuel and stock point',
                                AppTheme.warning);
                            return;
                          }
                          if (liters == null || liters <= 0) {
                            _showSnackbar(
                                'Please enter valid liters', AppTheme.danger);
                            return;
                          }
                          if (amount == null || amount <= 0) {
                            _showSnackbar(
                                'Please enter valid amount', AppTheme.danger);
                            return;
                          }

                          onSave(
                            DieselEntry(
                              id: initial?.id ??
                                  'DIE-${DateTime.now().millisecondsSinceEpoch}',
                              fuelType: fuelType!,
                              stockPoint: stockPoint!,
                              liters: liters,
                              amount: amount,
                              remarks: remarksController.text.trim(),
                              createdAt: initial?.createdAt ?? DateTime.now(),
                            ),
                          );
                          Navigator.pop(context);
                          _showSnackbar(
                              'Diesel entry saved.', AppTheme.success);
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(initial == null
                              ? 'Add Diesel Entry'
                              : 'Save Diesel Entry'),
                        ),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warning),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTodayVehiclesTab() {
    final groups = _vehicleWiseTodayRecords.entries.toList()
      ..sort(
          (a, b) => b.value.first.createdAt.compareTo(a.value.first.createdAt));

    final totalLiters =
        _todayVehicleRecords.fold<double>(0, (sum, r) => sum + r.totalLiters);
    final totalAmount =
        _todayVehicleRecords.fold<double>(0, (sum, r) => sum + r.totalAmount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            emoji: '🚛',
            title: 'Today Vehicle-wise Entries',
            subtitle:
                'Every submitted machine/vehicle entry is grouped by vehicle number.',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildKpiCard('Vehicles', '${groups.length}',
                      Icons.directions_car, AppTheme.primary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildKpiCard(
                      'Diesel',
                      '${totalLiters.toStringAsFixed(1)} L',
                      Icons.local_gas_station,
                      AppTheme.warning)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildKpiCard(
                      'Records',
                      '${_todayVehicleRecords.length}',
                      Icons.receipt_long,
                      AppTheme.info)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildKpiCard(
                      'Total',
                      '₹${totalAmount.toStringAsFixed(0)}',
                      Icons.currency_rupee,
                      AppTheme.success)),
            ],
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            _buildEmptyState(
              icon: Icons.directions_car_filled_outlined,
              title: 'No vehicles entered today',
              subtitle:
                  'Submit a diesel or HOD machine entry to see vehicle-wise records here.',
            )
          else
            ...groups
                .map((group) => _buildVehicleGroupCard(group.key, group.value)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVehicleGroupCard(
      String vehicleNumber, List<VehicleDayRecord> records) {
    final first = records.first.machine;
    final totalLiters =
        records.fold<double>(0, (sum, r) => sum + r.totalLiters);
    final totalAmount =
        records.fold<double>(0, (sum, r) => sum + r.totalAmount);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              const Icon(Icons.agriculture_outlined, color: AppTheme.primary),
        ),
        title: Text(
          vehicleNumber,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${first.machineName} • ${records.length} record(s)',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildMiniMetric('Vehicle Type', first.vehicleType)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMiniMetric(
                      'Total Diesel', '${totalLiters.toStringAsFixed(1)} L')),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMiniMetric(
                      'Total Amount', '₹${totalAmount.toStringAsFixed(0)}')),
            ],
          ),
          const SizedBox(height: 12),
          ...records.map(_buildVehicleRecordCard),
        ],
      ),
    );
  }

  Widget _buildVehicleRecordCard(VehicleDayRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.source,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(_formatDateTime(record.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              _buildPill(record.billingType, AppTheme.info,
                  Icons.receipt_long_outlined),
              if (record.source != 'HOD Machine Entry') ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _showEditVehicleRecordSheet(record),
                  icon: const Icon(Icons.edit_note_outlined,
                      color: AppTheme.info, size: 21),
                  tooltip: 'Edit vehicle entry',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(record.machine.operatorName, AppTheme.success,
                  Icons.person_outline),
              _buildPill(record.supplierName, AppTheme.primary,
                  Icons.business_outlined),
              _buildPill(record.dieselInclusion, AppTheme.warning,
                  Icons.local_gas_station_outlined),
              if (record.machineEntryStatus != 'Submitted')
                _buildPill(record.machineEntryStatus, AppTheme.info,
                    Icons.verified_outlined),
            ],
          ),
          if (record.source == 'HOD Machine Entry') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric(
                    'Supervisor Fuel',
                    '${record.supervisorFuelType} ${record.supervisorFuelLiters.toStringAsFixed(1)} L',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Stock Point',
                    record.supervisorStockPoint,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Machine ID',
                    record.machine.id,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric(
                    'Commission',
                    record.commissionAmount > 0
                        ? '₹${record.commissionAmount.toStringAsFixed(0)}'
                        : '-',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Payment',
                    record.paymentMethod,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Beta Limit',
                    '${record.betaEligibleHours.toStringAsFixed(1)} h',
                  ),
                ),
              ],
            ),
            if (record.hodPaymentReference != '-' ||
                record.extraBetaApprovalEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniMetric(
                      'Pay Ref',
                      record.hodPaymentReference,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniMetric(
                      'Regular Beta',
                      '₹${record.regularBetaAmount.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniMetric(
                      'Extra Beta',
                      record.extraBetaApprovalEnabled
                          ? '₹${record.extraBetaLimit.toStringAsFixed(0)}'
                          : 'Off',
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (record.fairAmount > 0 || record.advanceAmount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _buildMiniMetric('Fair Amount',
                        '₹${record.fairAmount.toStringAsFixed(0)}')),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildMiniMetric('Advance',
                        '₹${record.advanceAmount.toStringAsFixed(0)}')),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildMiniMetric(
                        'Total', '₹${record.totalAmount.toStringAsFixed(0)}')),
              ],
            ),
          ],
          if (record.dieselEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Diesel entries',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...record.dieselEntries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_gas_station,
                        size: 17, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.fuelType} • ${entry.stockPoint}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${entry.liters.toStringAsFixed(1)} L  ₹${entry.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (record.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(record.notes,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplierNameField() {
    final filteredSuppliers = _suppliers.where((s) {
      if (_selectedSupplierType == 'permanent') return s['type'] == 'permanent';
      if (_selectedSupplierType == 'temporary') return s['type'] == 'temporary';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSupplierTypeChip('All', null),
              const SizedBox(width: 8),
              _buildSupplierTypeChip('Permanent', 'permanent'),
              const SizedBox(width: 8),
              _buildSupplierTypeChip('Temporary', 'temporary'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedSupplierName,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Select supplier',
            prefixIcon: Icon(_selectedSupplierType == 'temporary'
                ? Icons.access_time
                : Icons.business),
          ),
          items: filteredSuppliers.map((supplier) {
            final isTemp = supplier['type'] == 'temporary';
            final isHodManaged = supplier['source'] == 'hod';
            return DropdownMenuItem<String>(
              value: supplier['name'].toString(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      supplier['name'].toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (isHodManaged) _buildTinyTag('HOD', AppTheme.info),
                  if (isTemp) ...[
                    const SizedBox(width: 5),
                    _buildTinyTag('TEMP', AppTheme.warning),
                  ],
                  const SizedBox(width: 6),
                  const Icon(Icons.star, size: 14, color: AppTheme.warning),
                  const SizedBox(width: 2),
                  Text(supplier['rating'].toString(),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSupplierName = value;
              final supplier = _suppliers.firstWhere((s) => s['name'] == value,
                  orElse: () => {'type': 'permanent'});
              _selectedSupplierType = supplier['type'].toString();
            });
          },
        ),
        if (_selectedSupplierName != null) ...[
          const SizedBox(height: 12),
          _buildSupplierDetailsCard(),
        ],
        const SizedBox(height: 8),
        const HodApprovalBadge(text: 'Supplier list managed by HOD'),
      ],
    );
  }

  Widget _buildHodSubmissionQueue() {
    final pending = _pendingHodSubmissions;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_turned_in_outlined,
                    color: AppTheme.warning),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supervisor Machine Requests',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${pending.length} pending · ${_completedHodSubmissionIds.length} completed today',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            const Text(
              'No pending supervisor machine requests.',
              style: TextStyle(color: AppTheme.textMuted),
            )
          else
            ...pending.map(_buildHodSubmissionTile),
        ],
      ),
    );
  }

  Widget _buildHodSubmissionTile(HodMachineSubmission request) {
    final selected = _selectedHodSubmissionId == request.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.warningBg : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppTheme.warning : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.agriculture_outlined, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.vehicleNumber} · ${request.machineName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${request.supervisorName} · ${request.siteName}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildTinyInfoChip(request.vehicleType, AppTheme.info),
                    _buildTinyInfoChip(
                      '${request.fuelType} ${request.liters.toStringAsFixed(1)} L',
                      AppTheme.success,
                    ),
                    _buildTinyInfoChip(request.stockPoint, AppTheme.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _loadHodSubmission(request),
            child: Text(selected ? 'Loaded' : 'Load'),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSupervisorSubmittedDataSection() {
    final machine = _selectedMachine;
    if (machine != null && _hodVehicleNumberController.text.isEmpty) {
      _hodVehicleNumberController.text = machine.vehicleNumber;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (machine != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.info.withOpacity(0.20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_outlined,
                    color: AppTheme.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Generated Machine ID',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                      Text(
                        _generatedMachineIdFor(machine),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildHodTextField(
          controller: _hodVehicleNumberController,
          label: 'Vehicle Number',
          icon: Icons.pin_outlined,
        ),
        const SizedBox(height: 12),
        _buildHodDropdown(
          label: 'Fuel Type',
          icon: Icons.local_gas_station_outlined,
          value: _hodFuelType,
          values: _fuelTypes,
          onChanged: (value) => setState(() => _hodFuelType = value),
        ),
        const SizedBox(height: 12),
        _buildHodTextField(
          controller: _hodFuelLitersController,
          label: 'No. of Litres',
          icon: Icons.water_drop_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildHodDropdown(
          label: 'Stock Point',
          icon: Icons.warehouse_outlined,
          value: _hodStockPoint,
          values: _stockPoints,
          onChanged: (value) => setState(() => _hodStockPoint = value),
        ),
      ],
    );
  }

  Widget _buildHodEntryDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSupplierNameField(),
        const SizedBox(height: 12),
        _buildOperatorField(),
        const SizedBox(height: 12),
        _buildHodTextField(
          controller: _commissionAgentController,
          label: 'Commission Agent Name',
          icon: Icons.support_agent_outlined,
        ),
        const SizedBox(height: 12),
        _buildHodTextField(
          controller: _commissionAmountController,
          label: 'Commission Amount (₹)',
          icon: Icons.currency_rupee,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildHodTextField(
          controller: _hodAdvanceAmountController,
          label: 'Advance Payment Amount (₹)',
          icon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildHodPaymentModeSelector(),
        const SizedBox(height: 12),
        _buildHodAdvancePaymentDetails(),
        const SizedBox(height: 12),
        _buildVehicleTypeField(),
        const SizedBox(height: 12),
        _buildBillingMode(),
        const SizedBox(height: 12),
        _buildHodTextField(
          controller: _amountController,
          label: 'Vehicle Fare (₹)',
          icon: Icons.receipt_long_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildDieselInclusion(),
      ],
    );
  }

  Widget _buildBetaSettingsSection() {
    return Column(
      children: [
        _buildHodTextField(
          controller: _betaEligibleHoursController,
          label: 'Beta Eligible Limit (Hours)',
          icon: Icons.timer_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildHodTextField(
          controller: _regularBetaAmountController,
          label: 'Regular Beta Amount (₹)',
          icon: Icons.currency_rupee,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _extraBetaApprovalEnabled,
          activeColor: AppTheme.success,
          title: const Text('Extra Beta Approval',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          subtitle: const Text(
              'Supervisor extra beta requests need HOD approval',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          onChanged: (value) =>
              setState(() => _extraBetaApprovalEnabled = value),
        ),
        if (_extraBetaApprovalEnabled) ...[
          const SizedBox(height: 8),
          _buildHodTextField(
            controller: _extraBetaLimitController,
            label: 'Extra Beta Limit (₹)',
            icon: Icons.add_card_outlined,
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }

  Widget _buildHodPaymentModeSelector() {
    final modes = [
      ['Cash', Icons.payments_outlined, AppTheme.success],
      ['UPI', Icons.qr_code_2_outlined, AppTheme.info],
      ['Bank Transfer', Icons.account_balance_outlined, AppTheme.warning],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Mode',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: modes.map((mode) {
            final label = mode[0] as String;
            final icon = mode[1] as IconData;
            final color = mode[2] as Color;
            final selected = _hodAdvancePaymentMode == label;
            return ChoiceChip(
              avatar:
                  Icon(icon, size: 16, color: selected ? Colors.white : color),
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _hodAdvancePaymentMode = label),
              selectedColor: color,
              backgroundColor: AppTheme.surface,
              side: BorderSide(color: selected ? color : AppTheme.border),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHodAdvancePaymentDetails() {
    switch (_hodAdvancePaymentMode) {
      case 'UPI':
        return _buildHodTextField(
          controller: _hodUpiIdController,
          label: 'UPI ID',
          icon: Icons.alternate_email,
        );
      case 'Bank Transfer':
        return Column(
          children: [
            _buildHodTextField(
              controller: _hodAccountHolderController,
              label: 'Account Holder Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _buildHodTextField(
              controller: _hodBankNameController,
              label: 'Bank Name',
              icon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 12),
            _buildHodTextField(
              controller: _hodAccountNumberController,
              label: 'Account Number',
              icon: Icons.numbers_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildHodTextField(
              controller: _hodIfscController,
              label: 'IFSC Code',
              icon: Icons.tag_outlined,
            ),
          ],
        );
      case 'Cash':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.successBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withOpacity(0.20)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cash advance will be recorded against supervisor cash balance.',
                  style: TextStyle(fontSize: 12, color: AppTheme.success),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHodTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildHodDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: values
          .map((item) =>
              DropdownMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSupplierTypeChip(String label, String? type) {
    final isSelected = _selectedSupplierType == type;
    final color = type == 'temporary' ? AppTheme.warning : AppTheme.info;
    return ChoiceChip(
      selected: isSelected,
      showCheckmark: false,
      selectedColor: color,
      backgroundColor: AppTheme.surface,
      side: BorderSide(color: isSelected ? color : AppTheme.border),
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) {
        setState(() {
          _selectedSupplierType = type;
          _selectedSupplierName = null;
        });
      },
    );
  }

  Widget _buildSupplierDetailsCard() {
    final supplier = _suppliers.firstWhere(
        (s) => s['name'] == _selectedSupplierName,
        orElse: () => {});
    if (supplier.isEmpty) return const SizedBox.shrink();
    final isTemp = supplier['type'] == 'temporary';
    final isHodManaged = supplier['source'] == 'hod';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTemp ? AppTheme.warningBg : AppTheme.infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isTemp ? AppTheme.warning : AppTheme.info)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isTemp ? Icons.access_time : Icons.verified,
                  size: 18, color: isTemp ? AppTheme.warning : AppTheme.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTemp ? 'Temporary Supplier' : 'Permanent Supplier',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isTemp ? AppTheme.warning : AppTheme.info),
                ),
              ),
              if (isHodManaged) _buildTinyTag('HOD', AppTheme.info),
            ],
          ),
          if (supplier['purpose'] != null &&
              supplier['purpose'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMiniMetric('Used for', supplier['purpose'].toString()),
          ],
          if (supplier['phone'] != null &&
              supplier['phone'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child:
                      _buildMiniMetric('Phone', supplier['phone'].toString()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Category',
                    supplier['category']?.toString() ?? '-',
                  ),
                ),
              ],
            ),
          ],
          if (supplier['siteName'] != null &&
              supplier['siteName'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMiniMetric('Site', supplier['siteName'].toString()),
          ],
          if (isTemp && supplier['validUntil'] != null) ...[
            const SizedBox(height: 4),
            Text('Valid until: ${supplier['validUntil']}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildOperatorField() {
    return TextField(
      controller: _operatorNameController,
      decoration: const InputDecoration(
        labelText: 'Operator Name (Optional)',
        hintText: 'Enter full operator name if available',
        prefixIcon: Icon(Icons.person_outline),
      ),
    );
  }

  Widget _buildVehicleTypeField() {
    return DropdownButtonFormField<String>(
      value: _selectedVehicleType,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Vehicle Type',
          prefixIcon: Icon(Icons.agriculture_outlined)),
      items: _vehicleTypes
          .map((type) =>
              DropdownMenuItem<String>(value: type, child: Text(type)))
          .toList(),
      onChanged: (value) => setState(() => _selectedVehicleType = value),
    );
  }

  Widget _buildBillingMode() {
    return DropdownButtonFormField<String>(
      value: _selectedBillingType,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Billing Type',
          prefixIcon: Icon(Icons.receipt_long_outlined)),
      items: _billingTypes
          .map((type) =>
              DropdownMenuItem<String>(value: type, child: Text(type)))
          .toList(),
      onChanged: (value) => setState(() => _selectedBillingType = value),
    );
  }

  Widget _buildDieselInclusion() {
    return Row(
      children: [
        Expanded(
          child: _buildSelectionCard(
            label: 'With Diesel',
            icon: Icons.local_gas_station,
            color: AppTheme.success,
            selected: _selectedDieselInclusion == 'With diesel',
            onTap: () => setState(() {
              _selectedDieselInclusion = 'With diesel';
              _showDieselTable = true;
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelectionCard(
            label: 'Without Diesel',
            icon: Icons.ev_station,
            color: AppTheme.danger,
            selected: _selectedDieselInclusion == 'Without diesel',
            onTap: () => setState(() {
              _selectedDieselInclusion = 'Without diesel';
              _showDieselTable = false;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDieselConsumptionTable() {
    return DieselConsumptionTable(
      fuelTypes: _fuelTypes,
      stockPoints: _stockPoints,
      onChanged: (data) => debugPrint('Diesel consumption data: $data'),
    );
  }

  Widget _buildAdvancePayments() {
    final usedLimit = _cashLimit * 0.7;
    final cashTransactions = _machineCashTransactions;
    final advanceTransactions = _machineAdvanceTransactions;
    return Column(
      children: [
        _buildMachinePaymentSwitch(
          title: 'Cash Payment',
          subtitle: 'Used amount payment with HOD limit',
          value: _selectedUsedPaymentMethod == 'cash',
          color: AppTheme.info,
          countLabel:
              '${cashTransactions.length} payment${cashTransactions.length == 1 ? "" : "s"}',
          icon: Icons.receipt_long,
          onChanged: (value) => setState(() {
            _selectedUsedPaymentMethod = value ? 'cash' : null;
            if (value) {
              _selectedUsedAdvanceMode = null;
              _selectedUsedEntryMethod = null;
            } else {
              _usedAmountController.clear();
            }
          }),
        ),
        if (_selectedUsedPaymentMethod == 'cash') ...[
          _buildMachineCashAmountBox(
            controller: _usedAmountController,
            label: 'Used Amount (₹)',
            limit: usedLimit,
          ),
          const SizedBox(height: 8),
          _buildMachineCashValidationInfo(_usedAmountController, usedLimit),
        ],
        const SizedBox(height: 12),
        _buildMachineCashPaymentTable(),
        const SizedBox(height: 12),
        _buildMachinePaymentSwitch(
          title: 'Advance Request',
          subtitle: 'Finance department will process payment',
          value: _selectedUsedPaymentMethod == 'advance',
          color: AppTheme.success,
          countLabel:
              '${advanceTransactions.length} request${advanceTransactions.length == 1 ? "" : "s"}',
          icon: Icons.request_quote_outlined,
          onChanged: (value) => setState(() {
            _selectedUsedPaymentMethod = value ? 'advance' : null;
            if (value) {
              _usedAmountController.clear();
            } else {
              _selectedUsedAdvanceMode = null;
              _selectedUsedEntryMethod = null;
            }
          }),
        ),
        if (_selectedUsedPaymentMethod == 'advance') ...[
          _buildMachineCashAmountBox(
            controller: _usedAdvanceAmountController,
            label: 'Used Advance Amount (₹)',
            limit: usedLimit,
          ),
          const SizedBox(height: 16),
          AdvancePaymentRequest(
            onMethodSelected: (mode, entryMethod) => setState(() {
              _selectedUsedAdvanceMode = mode;
              _selectedUsedEntryMethod = entryMethod;
            }),
          ),
        ],
        const SizedBox(height: 12),
        _buildMachineAdvanceRequestTable(),
      ],
    );
  }

  Widget _buildMachinePaymentSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required String countLabel,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle),
            value: value,
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                countLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMachineCashAmountBox({
    required TextEditingController controller,
    required String label,
    required double limit,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.infoBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  size: 16, color: AppTheme.info),
              const SizedBox(width: 6),
              Text('HOD Limit: ₹${limit.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Max ₹${limit.toStringAsFixed(0)}',
            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildMachineCashValidationInfo(
      TextEditingController controller, double limit) {
    final text = controller.text;
    final amount = double.tryParse(text) ?? 0;
    if (text.isEmpty) {
      return _buildHintBox('Enter amount within HOD limit.', AppTheme.info);
    }
    if (amount > limit) {
      return _buildHintBox('Exceeds HOD limit of ₹${limit.toStringAsFixed(0)}.',
          AppTheme.danger);
    }
    return _buildHintBox(
        'Valid cash payment: ₹${amount.toStringAsFixed(0)}', AppTheme.success);
  }

  List<MachinePaymentTransaction> get _machineCashTransactions =>
      _machinePaymentLedger.where((entry) => entry.type == 'cash').toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<MachinePaymentTransaction> get _machineAdvanceTransactions =>
      _machinePaymentLedger.where((entry) => entry.type == 'advance').toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Widget _buildMachineCashPaymentTable() {
    final rows = _machineCashTransactions;
    return _buildMachinePaymentTableShell(
      title: 'Cash Payment Table',
      subtitle:
          'Amount is auto-filled when payment is completed; use Edit to correct amount',
      color: AppTheme.info,
      icon: Icons.payments_outlined,
      emptyText: 'No machine cash payments generated yet.',
      child: rows.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 62,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Cash Payment ID')),
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Edit')),
                ],
                rows: rows.map((txn) {
                  return DataRow(
                    cells: [
                      DataCell(Text(txn.id,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))),
                      DataCell(Text(_formatDateTime(txn.date),
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text('₹${txn.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(
                        TextButton.icon(
                          onPressed: () =>
                              _showEditMachineCashPaymentSheet(txn),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.info),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildMachineAdvanceRequestTable() {
    final rows = _machineAdvanceTransactions;
    return _buildMachinePaymentTableShell(
      title: 'Advance Payment Request Table',
      subtitle:
          'Proof and Machine IDs Book unlock only after the requested amount is completed',
      color: AppTheme.success,
      icon: Icons.request_quote_outlined,
      emptyText: 'No machine advance payment requests generated yet.',
      child: rows.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 82,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Request Payment ID')),
                  DataColumn(label: Text('Request Time')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Requested Status')),
                  DataColumn(label: Text('Payment Proof')),
                  DataColumn(label: Text('Machine IDs Book')),
                ],
                rows: rows.map((txn) {
                  final completed = txn.status == 'Completed';
                  return DataRow(
                    cells: [
                      DataCell(Text(txn.id,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))),
                      DataCell(Text(_formatDateTime(txn.date),
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text('₹${txn.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(
                        completed
                            ? _buildMachineStatusChip(
                                'Completed', AppTheme.success)
                            : TextButton.icon(
                                onPressed: () =>
                                    _completeMachineAdvanceRequest(txn),
                                icon: const Icon(Icons.verified_outlined,
                                    size: 15),
                                label: const Text('Requested'),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.warning),
                              ),
                      ),
                      DataCell(
                        completed
                            ? _buildMachineProofPreview(
                                txn.paymentProof ?? 'Payment proof')
                            : _buildMachineStatusChip(
                                'Locked', AppTheme.textMuted),
                      ),
                      DataCell(
                        Switch(
                          value: txn.registeredInMachineIdsBook,
                          activeColor: AppTheme.success,
                          onChanged: completed
                              ? (value) => _toggleMachineIdsBook(txn, value)
                              : null,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildMachinePaymentTableShell({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required String emptyText,
    required Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child ??
              Text(emptyText,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMachineStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildMachineProofPreview(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.image_outlined, size: 16, color: AppTheme.success),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.success,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _completeMachineAdvanceRequest(MachinePaymentTransaction txn) {
    setState(() {
      txn.status = 'Completed';
      txn.paymentProof = 'Proof ${txn.id}';
    });
    _showSnackbar('Machine advance request completed.', AppTheme.success);
  }

  void _toggleMachineIdsBook(MachinePaymentTransaction txn, bool value) {
    setState(() => txn.registeredInMachineIdsBook = value);
    _showSnackbar(
      value
          ? 'Registered in Machine IDs Book.'
          : 'Removed from Machine IDs Book.',
      value ? AppTheme.success : AppTheme.warning,
    );
  }

  void _showEditMachineCashPaymentSheet(MachinePaymentTransaction txn) {
    final controller =
        TextEditingController(text: txn.amount.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetTitle(
                title: 'Edit Cash Payment',
                subtitle: txn.id,
                icon: Icons.edit_outlined,
                color: AppTheme.info,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final amount = double.tryParse(controller.text.trim());
                    if (amount == null || amount <= 0) return;
                    setState(() => txn.amount = amount);
                    Navigator.pop(context);
                    _showSnackbar(
                        'Cash payment amount updated.', AppTheme.success);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Amount'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: const InputDecoration(
          labelText: 'Additional Notes',
          hintText: 'Any remarks about this entry',
          prefixIcon: Icon(Icons.notes_outlined)),
    );
  }

  Widget _buildPhotoCard() {
    return const PhotoCaptureCard(
        label: 'Driver + vehicle opening photo', mandatory: true);
  }

  Widget _buildHODSummaryCard() {
    final fairAmount = double.tryParse(_amountController.text) ?? 0;
    final advance = double.tryParse(_hodAdvanceAmountController.text) ?? 0;
    final total = fairAmount + advance + _draftTotalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.warning, AppTheme.warning.withOpacity(0.82)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial Summary',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildWhiteMetric('Fair Amt', '₹${fairAmount.toStringAsFixed(0)}',
                  Icons.monetization_on),
              const SizedBox(width: 8),
              _buildWhiteMetric(
                  'Diesel',
                  '₹${_draftTotalAmount.toStringAsFixed(0)}',
                  Icons.local_gas_station),
              const SizedBox(width: 8),
              _buildWhiteMetric(
                  'Advance', '₹${advance.toStringAsFixed(0)}', Icons.payments),
            ],
          ),
          const Divider(color: Colors.white24, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
              Text('₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(
      {required String emoji,
      required String title,
      required String subtitle,
      required Color color}) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.info.withOpacity(0.10), AppTheme.infoBg]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_gas_station, color: AppTheme.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Diesel Remaining Stock',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    '${_dieselRemainingStock.toStringAsFixed(1)} litres available',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.info)),
              ],
            ),
          ),
          _buildTinyTag(_dieselRemainingStock < 100 ? 'Low' : 'Available',
              _dieselRemainingStock < 100 ? AppTheme.danger : AppTheme.success),
        ],
      ),
    );
  }

  Widget _buildStepCard(
      {required String step,
      required String title,
      required Widget child,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(step,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary))),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMachinePreview(MachineCatalogItem machine) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.info.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${machine.machineName} • ${machine.vehicleNumber}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    '${machine.vehicleType} • Operator: ${machine.operatorName}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDieselDraftSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Expanded(
              child:
                  _buildMiniMetric('Entries', '${_draftDieselEntries.length}')),
          const SizedBox(width: 8),
          Expanded(
              child: _buildMiniMetric(
                  'Liters', '${_draftTotalLiters.toStringAsFixed(1)} L')),
          const SizedBox(width: 8),
          Expanded(
              child: _buildMiniMetric(
                  'Amount', '₹${_draftTotalAmount.toStringAsFixed(0)}')),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final data = [
      ('1', 'Machine'),
      ('2', 'Supplier'),
      ('3', 'Operator'),
      ('4', 'Vehicle'),
      ('5', 'Billing'),
      ('6', 'Diesel'),
      ('7', 'Payment'),
      ('8+', 'More'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: data
            .map((d) => _buildTinyTag('${d.$1} ${d.$2}', AppTheme.warning))
            .toList(),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.warning),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dropdown-based machine entry is enabled. Use “Enter / Add New Machine” when the vehicle is not listed.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(
      {required String label,
      required IconData icon,
      required Color color,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 24,
                color: selected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetTitle(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color}) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildTinyTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _buildHintBox(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildWhiteMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(label,
                style: const TextStyle(fontSize: 9, color: Colors.white60),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
