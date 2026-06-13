import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// =========================
// Existing rental models
// =========================

enum MachineLifecycleStatus { atSite, activeInTank, shiftDone, closed }

extension MachineLifecycleStatusX on MachineLifecycleStatus {
  String get label {
    switch (this) {
      case MachineLifecycleStatus.atSite:
        return 'At Site / Not Activated';
      case MachineLifecycleStatus.activeInTank:
        return 'Active in Tank';
      case MachineLifecycleStatus.shiftDone:
        return 'Shift Done';
      case MachineLifecycleStatus.closed:
        return 'Closed';
    }
  }

  IconData get icon {
    switch (this) {
      case MachineLifecycleStatus.atSite:
        return Icons.location_on_outlined;
      case MachineLifecycleStatus.activeInTank:
        return Icons.play_circle_outline;
      case MachineLifecycleStatus.shiftDone:
        return Icons.task_alt_outlined;
      case MachineLifecycleStatus.closed:
        return Icons.lock_outline;
    }
  }
}

class DailyCheckIn {
  final DateTime date;
  final bool submitted;
  final String note;

  DailyCheckIn({
    required this.date,
    this.submitted = true,
    this.note = 'Daily machine check-in recorded',
  });
}

class MachineFuelLog {
  final String id;
  final DateTime date;
  final String type;
  final double litres;
  final double amount;
  final String meterReading;
  final String notes;

  const MachineFuelLog({
    required this.id,
    required this.date,
    required this.type,
    required this.litres,
    required this.amount,
    this.meterReading = '',
    this.notes = '',
  });

  MachineFuelLog copyWith({
    DateTime? date,
    String? type,
    double? litres,
    double? amount,
    String? meterReading,
    String? notes,
  }) {
    return MachineFuelLog(
      id: id,
      date: date ?? this.date,
      type: type ?? this.type,
      litres: litres ?? this.litres,
      amount: amount ?? this.amount,
      meterReading: meterReading ?? this.meterReading,
      notes: notes ?? this.notes,
    );
  }
}

class RentalItem {
  final String id;
  final String item;
  final DateTime startDate;
  final double rate; // per day
  double advance;
  double fuelConsumed;
  String notes;
  bool isActivated;
  DateTime? activationDate;
  DateTime? closingDate;
  DateTime? tankEntryDate;
  List<DailyCheckIn> dailyCheckIns;
  List<MachineFuelLog> fuelLogs;
  String? closingProofPath;
  String siteName;
  String tankId;
  String fieldLabel;
  String operatorName;

  RentalItem({
    required this.id,
    required this.item,
    required this.startDate,
    required this.rate,
    this.advance = 0,
    this.fuelConsumed = 0,
    this.notes = '',
    this.isActivated = false,
    this.activationDate,
    this.closingDate,
    this.tankEntryDate,
    List<DailyCheckIn>? dailyCheckIns,
    List<MachineFuelLog>? fuelLogs,
    this.closingProofPath,
    this.siteName = 'Site not assigned',
    this.tankId = 'Tank not assigned',
    this.fieldLabel = 'Field not assigned',
    this.operatorName = 'Operator not assigned',
  })  : dailyCheckIns = dailyCheckIns ?? [],
        fuelLogs = fuelLogs ?? [];

  double getEarnedAmount() {
    if (!isActivated || activationDate == null) return 0;
    final endDate = closingDate ?? DateTime.now();
    final days = math.max(endDate.difference(activationDate!).inDays, 1).toDouble();
    return days * rate;
  }

  double get fuelLogAmountTotal =>
      fuelLogs.fold(0, (sum, log) => sum + log.amount);

  double get fuelLogLitresTotal =>
      fuelLogs.fold(0, (sum, log) => sum + log.litres);

  double get totalFuelCost => fuelLogs.isEmpty ? fuelConsumed : fuelLogAmountTotal;

  MachineLifecycleStatus get machineStatus {
    if (closingDate != null) return MachineLifecycleStatus.closed;
    if (isActivated) return MachineLifecycleStatus.activeInTank;
    return MachineLifecycleStatus.atSite;
  }

  bool isTodayChecked() {
    final today = DateTime.now();
    return dailyCheckIns.any(
      (check) =>
          check.date.year == today.year &&
          check.date.month == today.month &&
          check.date.day == today.day,
    );
  }

  void checkToday({String note = 'Daily machine check-in recorded'}) {
    final today = DateTime.now();
    if (!isTodayChecked()) {
      dailyCheckIns.add(DailyCheckIn(date: today, note: note));
    }
  }
}

// =========================
// New internal transfer models
// =========================

enum TransferAssetKind { material, workEquipment }

extension TransferAssetKindX on TransferAssetKind {
  String get label {
    switch (this) {
      case TransferAssetKind.material:
        return 'Materials';
      case TransferAssetKind.workEquipment:
        return 'Work Equipment';
    }
  }

  IconData get icon {
    switch (this) {
      case TransferAssetKind.material:
        return Icons.inventory_2_outlined;
      case TransferAssetKind.workEquipment:
        return Icons.handyman_outlined;
    }
  }
}

class TransferLocation {
  final String siteName;
  final String address;
  final double latitude;
  final double longitude;

  const TransferLocation({
    required this.siteName,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class InternalTransferItem {
  final String id;
  final String name;
  final TransferAssetKind kind;
  final String batchId;
  final String rentalId;
  final int rentedQty;
  int returnedQty;
  final List<String> thavvuIds;
  final List<String> tankIds;
  final TransferLocation location;

  InternalTransferItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.batchId,
    required this.rentalId,
    required this.rentedQty,
    this.returnedQty = 0,
    this.thavvuIds = const [],
    this.tankIds = const [],
    required this.location,
  });

  int get remainingQty => math.max(rentedQty - returnedQty, 0);

  int get chargeableQty => remainingQty;

  bool get isReturned => remainingQty == 0;

  bool get isPartial => returnedQty > 0 && remainingQty > 0;

  String get statusLabel {
    if (isReturned) return 'Returned';
    if (isPartial) return 'Partial';
    return 'Running';
  }
}

// =========================
// New VRI models
// =========================

enum VehicleBillingType { hourly, weekly, trip, km }

extension VehicleBillingTypeX on VehicleBillingType {
  String get label {
    switch (this) {
      case VehicleBillingType.hourly:
        return 'Hourly';
      case VehicleBillingType.weekly:
        return 'Weekly';
      case VehicleBillingType.trip:
        return 'Trip';
      case VehicleBillingType.km:
        return 'KM';
    }
  }

  String get shortLabel {
    switch (this) {
      case VehicleBillingType.hourly:
        return 'HR';
      case VehicleBillingType.weekly:
        return 'WK';
      case VehicleBillingType.trip:
        return 'TR';
      case VehicleBillingType.km:
        return 'KM';
    }
  }

  String get unitLabel {
    switch (this) {
      case VehicleBillingType.hourly:
        return 'hr';
      case VehicleBillingType.weekly:
        return 'week';
      case VehicleBillingType.trip:
        return 'trip';
      case VehicleBillingType.km:
        return 'km';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleBillingType.hourly:
        return Icons.schedule_outlined;
      case VehicleBillingType.weekly:
        return Icons.date_range_outlined;
      case VehicleBillingType.trip:
        return Icons.route_outlined;
      case VehicleBillingType.km:
        return Icons.speed_outlined;
    }
  }
}

class VehicleCatalogItem {
  final String id;
  final String name;
  final VehicleBillingType billingType;
  final double rate;
  final List<String> thavvuIds;

  const VehicleCatalogItem({
    required this.id,
    required this.name,
    required this.billingType,
    required this.rate,
    required this.thavvuIds,
  });
}

class VehicleRentalEntry {
  final String id;
  final String vehicleCatalogId;
  final String vehicleName;
  final VehicleBillingType billingType;
  final String thavvuId;
  final String tankId;
  final String fromLocation;
  final String toLocation;
  final String driverOrOperator;
  final DateTime workDate;
  final double units;
  final double rate;
  final double fuelCost;
  final double driverBata;
  final double loadingCharge;
  final String status;
  final String notes;

  const VehicleRentalEntry({
    required this.id,
    required this.vehicleCatalogId,
    required this.vehicleName,
    required this.billingType,
    required this.thavvuId,
    required this.tankId,
    required this.fromLocation,
    required this.toLocation,
    required this.driverOrOperator,
    required this.workDate,
    required this.units,
    required this.rate,
    this.fuelCost = 0,
    this.driverBata = 0,
    this.loadingCharge = 0,
    this.status = 'Running',
    this.notes = '',
  });

  double get baseAmount => units * rate;

  double get extraAmount => fuelCost + driverBata + loadingCharge;

  double get totalAmount => baseAmount + extraAmount;

  VehicleRentalEntry copyWith({String? status}) {
    return VehicleRentalEntry(
      id: id,
      vehicleCatalogId: vehicleCatalogId,
      vehicleName: vehicleName,
      billingType: billingType,
      thavvuId: thavvuId,
      tankId: tankId,
      fromLocation: fromLocation,
      toLocation: toLocation,
      driverOrOperator: driverOrOperator,
      workDate: workDate,
      units: units,
      rate: rate,
      fuelCost: fuelCost,
      driverBata: driverBata,
      loadingCharge: loadingCharge,
      status: status ?? this.status,
      notes: notes,
    );
  }
}

class AquaRentalTool {
  final String id;
  final String name;
  final String category;
  final String district;
  final String purpose;
  final double suggestedRate;
  final String billingUnit;

  const AquaRentalTool({
    required this.id,
    required this.name,
    required this.category,
    required this.district,
    required this.purpose,
    required this.suggestedRate,
    this.billingUnit = 'day',
  });
}

// =========================
// Screen
// =========================

class RentalScreen extends StatefulWidget {
  const RentalScreen({super.key});

  @override
  State<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<FormState> _openRentalFormKey = GlobalKey<FormState>();

  String _billingMode = 'Per day';
  String _advancePaymentMode = 'Cash';
  bool _isOpening = false;

  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _advanceAmountController =
      TextEditingController();
  final TextEditingController _fuelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<AquaRentalTool> _aquaToolCatalog = [];
  String? _selectedAquaToolId;

  List<RentalItem> _activeRentals = [];
  List<Map<String, dynamic>> _closedRentals = [];

  List<InternalTransferItem> _transferItems = [];
  InternalTransferItem? _selectedTransferItem;
  String? _selectedTransferThavvuId;
  String? _selectedTransferTankId;

  final List<VehicleCatalogItem> _vehicleCatalog = [];
  late final Map<VehicleBillingType, TextEditingController>
      _vehicleUsageControllers;
  final Map<VehicleBillingType, VehicleCatalogItem?> _selectedVehicles = {};
  final Map<VehicleBillingType, String?> _selectedVehicleThavvuIds = {};
  final List<VehicleRentalEntry> _vehicleEntries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _vehicleUsageControllers = {
      for (final type in VehicleBillingType.values)
        type: TextEditingController(text: _defaultVehicleUsage(type)),
    };
    _loadMockData();
    _seedVehicleSelections();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemController.dispose();
    _rateController.dispose();
    _advanceAmountController.dispose();
    _fuelController.dispose();
    _notesController.dispose();
    for (final controller in _vehicleUsageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // =========================
  // Mock data
  // =========================

  void _loadMockData() {
    _vehicleCatalog.clear();
    _aquaToolCatalog.clear();
    _vehicleEntries.clear();

    _aquaToolCatalog.addAll([
      const AquaRentalTool(
        id: 'AQT-AP-001',
        name: '2 HP Paddle Wheel Aerator',
        category: 'Aeration',
        district: 'Bhimavaram',
        purpose: 'Shrimp pond oxygen support',
        suggestedRate: 1450,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-002',
        name: '1 HP Paddle Wheel Aerator',
        category: 'Aeration',
        district: 'Bhimavaram',
        purpose: 'Small pond aeration',
        suggestedRate: 950,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-003',
        name: 'Diesel Water Pump 5 HP',
        category: 'Pumping',
        district: 'Krishna',
        purpose: 'Water exchange and pond filling',
        suggestedRate: 1800,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-004',
        name: 'Submersible Sludge Pump',
        category: 'Pumping',
        district: 'Eluru',
        purpose: 'Sludge removal after culture cycle',
        suggestedRate: 1650,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-005',
        name: 'DO Meter Kit',
        category: 'Testing',
        district: 'Nellore',
        purpose: 'Dissolved oxygen testing',
        suggestedRate: 450,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-006',
        name: 'pH and Salinity Meter Kit',
        category: 'Testing',
        district: 'Kakinada',
        purpose: 'Water quality verification',
        suggestedRate: 500,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-007',
        name: 'Drag Net / Seine Net',
        category: 'Harvesting',
        district: 'Machilipatnam',
        purpose: 'Fish and shrimp harvest support',
        suggestedRate: 1350,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-008',
        name: 'Cast Net Set',
        category: 'Harvesting',
        district: 'Repalle',
        purpose: 'Sampling and small harvest work',
        suggestedRate: 650,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-009',
        name: 'Feed Tray Set',
        category: 'Feeding',
        district: 'Amalapuram',
        purpose: 'Feed checking in shrimp ponds',
        suggestedRate: 350,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-010',
        name: 'Automatic Feed Blower',
        category: 'Feeding',
        district: 'Bapatla',
        purpose: 'Uniform feed distribution',
        suggestedRate: 1200,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-011',
        name: 'Portable Generator 7.5 kVA',
        category: 'Power',
        district: 'West Godavari',
        purpose: 'Backup power for aerators',
        suggestedRate: 2200,
      ),
      const AquaRentalTool(
        id: 'AQT-AP-012',
        name: 'Digital Weighing Scale',
        category: 'Harvesting',
        district: 'Narasapuram',
        purpose: 'Harvest and feed weighing',
        suggestedRate: 500,
      ),
    ]);

    _activeRentals = [
      RentalItem(
        id: 'RNT-AP-2026-0034',
        item: '2 HP Paddle Wheel Aerator',
        startDate: DateTime(2026, 5, 20),
        rate: 1450,
        advance: 3000,
        fuelConsumed: 850,
        notes: 'Bhimavaram shrimp pond aeration support',
        siteName: 'Bhimavaram Aqua Yard',
        tankId: 'TNK-BVRM-11',
        fieldLabel: 'Vannamei Field A',
        operatorName: 'Ravi Kumar',
        tankEntryDate: DateTime(2026, 5, 20),
        isActivated: true,
        activationDate: DateTime(2026, 5, 21),
        dailyCheckIns: [
          DailyCheckIn(date: DateTime(2026, 5, 21), note: 'Machine entered Tank 11 and activated.'),
          DailyCheckIn(date: DateTime(2026, 5, 22), note: 'Aerator running normally.'),
          DailyCheckIn(date: DateTime(2026, 5, 23), note: 'Morning shift completed.'),
        ],
        fuelLogs: [
          MachineFuelLog(
            id: 'FUL-BVRM-001',
            date: DateTime(2026, 5, 21),
            type: 'Activation fuel',
            litres: 18,
            amount: 850,
            meterReading: 'Start 0001 hr',
            notes: 'Fuel filled before machine activation.',
          ),
          MachineFuelLog(
            id: 'FUL-BVRM-002',
            date: DateTime(2026, 5, 23),
            type: 'Shift-end check',
            litres: 6,
            amount: 290,
            meterReading: 'After 18 hr',
            notes: 'Fuel check after completed shift.',
          ),
        ],
      ),
      RentalItem(
        id: 'RNT-AP-2026-0035',
        item: 'Diesel Water Pump 5 HP',
        startDate: DateTime(2026, 5, 25),
        rate: 1800,
        advance: 2500,
        fuelConsumed: 1100,
        notes: 'Krishna brackish pond water exchange',
        siteName: 'Krishna Brackish Pond',
        tankId: 'TNK-KRS-09',
        fieldLabel: 'Water Exchange Line',
        operatorName: 'Suresh Babu',
        tankEntryDate: DateTime(2026, 5, 25),
        isActivated: true,
        activationDate: DateTime(2026, 5, 26),
        dailyCheckIns: [
          DailyCheckIn(date: DateTime(2026, 5, 26), note: 'Pump installed near exchange bay.'),
          DailyCheckIn(date: DateTime(2026, 5, 27), note: 'Second shift continued.'),
          DailyCheckIn(date: DateTime(2026, 5, 28), note: 'Outlet line checked.'),
        ],
        fuelLogs: [
          MachineFuelLog(
            id: 'FUL-KRS-001',
            date: DateTime(2026, 5, 26),
            type: 'Activation fuel',
            litres: 22,
            amount: 1100,
            meterReading: 'Start 0000 hr',
            notes: 'Diesel filled before pump activation.',
          ),
          MachineFuelLog(
            id: 'FUL-KRS-002',
            date: DateTime(2026, 5, 28),
            type: 'Shift-end check',
            litres: 9,
            amount: 450,
            meterReading: 'After 14 hr',
            notes: 'Fuel checked after water exchange shift.',
          ),
        ],
      ),
      RentalItem(
        id: 'RNT-AP-2026-0036',
        item: 'DO Meter Kit',
        startDate: DateTime(2026, 5, 28),
        rate: 450,
        advance: 500,
        fuelConsumed: 0,
        notes: 'Nellore water quality check',
        siteName: 'Nellore Test Station',
        tankId: 'TNK-NLR-44',
        fieldLabel: 'Water Quality Block',
        operatorName: 'Lab Assistant',
        tankEntryDate: DateTime(2026, 5, 28),
        isActivated: false,
      ),
      RentalItem(
        id: 'RNT-AP-2026-0037',
        item: 'Drag Net / Seine Net',
        startDate: DateTime(2026, 5, 29),
        rate: 1350,
        advance: 1000,
        fuelConsumed: 0,
        notes: 'Machilipatnam harvest preparation',
        siteName: 'Machilipatnam Harvest Point',
        tankId: 'TNK-MTM-18',
        fieldLabel: 'Harvest Field',
        operatorName: 'Mahesh',
        tankEntryDate: DateTime(2026, 5, 29),
        isActivated: true,
        activationDate: DateTime(2026, 5, 29),
        dailyCheckIns: [
          DailyCheckIn(date: DateTime(2026, 5, 29), note: 'Net issued for harvest trial.'),
        ],
      ),
    ];

    _closedRentals = [
      {
        'id': 'RNT-AP-2026-0028',
        'item': 'Portable Generator 7.5 kVA',
        'startDate': '2026-05-01',
        'endDate': '2026-05-07',
        'period': '6 days',
        'rate': 2200,
        'advance': 5000,
        'billing': 13200,
        'balance': 8200,
        'payment': 'Pending',
        'status': 'Closed',
      },
      {
        'id': 'RNT-AP-2026-0029',
        'item': 'Feed Tray Set',
        'startDate': '2026-05-08',
        'endDate': '2026-05-15',
        'period': '7 days',
        'rate': 350,
        'advance': 1000,
        'billing': 2450,
        'balance': 1450,
        'payment': 'Completed',
        'status': 'Closed',
      },
      {
        'id': 'RNT-AP-2026-0030',
        'item': 'pH and Salinity Meter Kit',
        'startDate': '2026-05-12',
        'endDate': '2026-05-17',
        'period': '5 days',
        'rate': 500,
        'advance': 1000,
        'billing': 2500,
        'balance': 1500,
        'payment': 'Completed',
        'status': 'Closed',
      },
    ];

    _transferItems = [
      InternalTransferItem(
        id: 'ITM-AP-001',
        name: 'HDPE Aerator Float Set',
        kind: TransferAssetKind.material,
        batchId: 'MAT-BVRM-1001',
        rentalId: 'RNT-AP-2026-0034',
        rentedQty: 12,
        returnedQty: 8,
        thavvuIds: ['THV-BVRM-01', 'THV-BVRM-02'],
        tankIds: ['TNK-BVRM-11', 'TNK-BVRM-12'],
        location: const TransferLocation(
          siteName: 'Bhimavaram Aqua Yard',
          address: 'Shrimp pond cluster, West Godavari',
          latitude: 16.5449,
          longitude: 81.5212,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-002',
        name: 'Aerator Paddle Blade Set',
        kind: TransferAssetKind.material,
        batchId: 'MAT-BVRM-1001',
        rentalId: 'RNT-AP-2026-0034',
        rentedQty: 24,
        returnedQty: 24,
        thavvuIds: ['THV-BVRM-03'],
        tankIds: ['TNK-BVRM-11'],
        location: const TransferLocation(
          siteName: 'Bhimavaram Aqua Yard',
          address: 'Aerator storage bay',
          latitude: 16.5480,
          longitude: 81.5250,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-003',
        name: 'PVC Air Hose Coil',
        kind: TransferAssetKind.material,
        batchId: 'MAT-KKD-1002',
        rentalId: 'RNT-AP-2026-0036',
        rentedQty: 15,
        returnedQty: 5,
        thavvuIds: ['THV-KKD-01', 'THV-KKD-02'],
        tankIds: ['TNK-KKD-22'],
        location: const TransferLocation(
          siteName: 'Kakinada Pond Block',
          address: 'Water testing shed, Kakinada',
          latitude: 16.9891,
          longitude: 82.2475,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-004',
        name: 'Feed Tray Frames',
        kind: TransferAssetKind.material,
        batchId: 'MAT-AML-1003',
        rentalId: 'RNT-AP-2026-0029',
        rentedQty: 40,
        returnedQty: 32,
        thavvuIds: ['THV-AML-01'],
        tankIds: ['TNK-AML-31', 'TNK-AML-32'],
        location: const TransferLocation(
          siteName: 'Amalapuram Feed Yard',
          address: 'Feed check storage, Konaseema',
          latitude: 16.5787,
          longitude: 82.0061,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-005',
        name: 'Harvest Crates',
        kind: TransferAssetKind.material,
        batchId: 'MAT-MTM-1004',
        rentalId: 'RNT-AP-2026-0037',
        rentedQty: 60,
        returnedQty: 20,
        thavvuIds: ['THV-MTM-01', 'THV-MTM-02'],
        tankIds: ['TNK-MTM-18'],
        location: const TransferLocation(
          siteName: 'Machilipatnam Harvest Point',
          address: 'Landing and harvest lane',
          latitude: 16.1809,
          longitude: 81.1303,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-006',
        name: '2 HP Paddle Wheel Aerator',
        kind: TransferAssetKind.workEquipment,
        batchId: 'WE-BVRM-2010',
        rentalId: 'RNT-AP-2026-0034',
        rentedQty: 4,
        returnedQty: 2,
        thavvuIds: ['THV-WE-BVRM-01'],
        tankIds: ['TNK-BVRM-11', 'TNK-BVRM-12'],
        location: const TransferLocation(
          siteName: 'Bhimavaram Pond 12',
          address: 'Vannamei culture pond',
          latitude: 16.5408,
          longitude: 81.5261,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-007',
        name: 'Diesel Water Pump 5 HP',
        kind: TransferAssetKind.workEquipment,
        batchId: 'WE-KRS-2011',
        rentalId: 'RNT-AP-2026-0035',
        rentedQty: 2,
        returnedQty: 0,
        thavvuIds: ['THV-WE-KRS-01', 'THV-WE-KRS-02'],
        tankIds: ['TNK-KRS-09'],
        location: const TransferLocation(
          siteName: 'Krishna Brackish Pond',
          address: 'Water exchange pump bay',
          latitude: 16.1800,
          longitude: 81.1350,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-008',
        name: 'DO Meter Kit',
        kind: TransferAssetKind.workEquipment,
        batchId: 'WE-NLR-2012',
        rentalId: 'RNT-AP-2026-0036',
        rentedQty: 3,
        returnedQty: 3,
        thavvuIds: ['THV-WE-NLR-01'],
        tankIds: ['TNK-NLR-44'],
        location: const TransferLocation(
          siteName: 'Nellore Test Station',
          address: 'Shrimp pond water lab',
          latitude: 14.4426,
          longitude: 79.9865,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-009',
        name: 'Drag Net / Seine Net',
        kind: TransferAssetKind.workEquipment,
        batchId: 'WE-MTM-2013',
        rentalId: 'RNT-AP-2026-0037',
        rentedQty: 2,
        returnedQty: 1,
        thavvuIds: ['THV-WE-MTM-01'],
        tankIds: ['TNK-MTM-18'],
        location: const TransferLocation(
          siteName: 'Machilipatnam Harvest Point',
          address: 'Harvest loading area',
          latitude: 16.1850,
          longitude: 81.1362,
        ),
      ),
      InternalTransferItem(
        id: 'ITM-AP-010',
        name: 'Portable Generator 7.5 kVA',
        kind: TransferAssetKind.workEquipment,
        batchId: 'WE-WG-2014',
        rentalId: 'RNT-AP-2026-0028',
        rentedQty: 1,
        returnedQty: 0,
        thavvuIds: ['THV-WE-WG-01'],
        tankIds: ['TNK-WG-07'],
        location: const TransferLocation(
          siteName: 'West Godavari Backup Bay',
          address: 'Aerator power support line',
          latitude: 16.7107,
          longitude: 81.0952,
        ),
      ),
    ];

    _vehicleCatalog.addAll([
      const VehicleCatalogItem(
        id: 'VH-HR-AP-01',
        name: 'Mini Tractor with Pond Trailer',
        billingType: VehicleBillingType.hourly,
        rate: 750,
        thavvuIds: ['THV-HR-BVRM-01', 'THV-HR-BVRM-02'],
      ),
      const VehicleCatalogItem(
        id: 'VH-HR-AP-02',
        name: 'JCB Backhoe for Bund Repair',
        billingType: VehicleBillingType.hourly,
        rate: 2100,
        thavvuIds: ['THV-HR-KRS-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-HR-AP-03',
        name: 'Harvest Crane Support',
        billingType: VehicleBillingType.hourly,
        rate: 1850,
        thavvuIds: ['THV-HR-MTM-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-WK-AP-01',
        name: 'Aqua Service Pickup',
        billingType: VehicleBillingType.weekly,
        rate: 14500,
        thavvuIds: ['THV-WK-BVRM-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-WK-AP-02',
        name: 'Diesel Bowser for Aerator Line',
        billingType: VehicleBillingType.weekly,
        rate: 26000,
        thavvuIds: ['THV-WK-WG-01', 'THV-WK-WG-02'],
      ),
      const VehicleCatalogItem(
        id: 'VH-WK-AP-03',
        name: 'Mobile Water Testing Van',
        billingType: VehicleBillingType.weekly,
        rate: 18000,
        thavvuIds: ['THV-WK-NLR-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-TR-AP-01',
        name: 'Feed Transport Lorry',
        billingType: VehicleBillingType.trip,
        rate: 4200,
        thavvuIds: ['THV-TR-AML-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-TR-AP-02',
        name: 'Insulated Fish Transport Van',
        billingType: VehicleBillingType.trip,
        rate: 5600,
        thavvuIds: ['THV-TR-MTM-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-TR-AP-03',
        name: 'Shrimp Harvest Pickup',
        billingType: VehicleBillingType.trip,
        rate: 3600,
        thavvuIds: ['THV-TR-BVRM-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-KM-AP-01',
        name: 'Aqua Technician Bike',
        billingType: VehicleBillingType.km,
        rate: 12,
        thavvuIds: ['THV-KM-NLR-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-KM-AP-02',
        name: 'Service Jeep',
        billingType: VehicleBillingType.km,
        rate: 28,
        thavvuIds: ['THV-KM-KKD-01'],
      ),
      const VehicleCatalogItem(
        id: 'VH-KM-AP-03',
        name: 'Reefer Van',
        billingType: VehicleBillingType.km,
        rate: 42,
        thavvuIds: ['THV-KM-MTM-01', 'THV-KM-MTM-02'],
      ),
      const VehicleCatalogItem(
        id: 'VH-KM-AP-04',
        name: 'Ice Box Pickup',
        billingType: VehicleBillingType.km,
        rate: 35,
        thavvuIds: ['THV-KM-KRS-02'],
      ),
    ]);

    _vehicleEntries.addAll([
      VehicleRentalEntry(
        id: 'VRI-AP-001',
        vehicleCatalogId: 'VH-HR-AP-01',
        vehicleName: 'Mini Tractor with Pond Trailer',
        billingType: VehicleBillingType.hourly,
        thavvuId: 'THV-HR-BVRM-01',
        tankId: 'TNK-BVRM-11',
        fromLocation: 'Bhimavaram Aqua Yard',
        toLocation: 'Pond 12 bund line',
        driverOrOperator: 'Operator Ramesh',
        workDate: DateTime(2026, 5, 29),
        units: 6,
        rate: 750,
        fuelCost: 650,
        driverBata: 300,
        loadingCharge: 0,
        status: 'Running',
        notes: 'Aerator float shifting and bund material movement.',
      ),
      VehicleRentalEntry(
        id: 'VRI-AP-002',
        vehicleCatalogId: 'VH-HR-AP-02',
        vehicleName: 'JCB Backhoe for Bund Repair',
        billingType: VehicleBillingType.hourly,
        thavvuId: 'THV-HR-KRS-01',
        tankId: 'TNK-KRS-09',
        fromLocation: 'Krishna Brackish Pond',
        toLocation: 'South bund repair point',
        driverOrOperator: 'Operator Suresh',
        workDate: DateTime(2026, 5, 28),
        units: 4.5,
        rate: 2100,
        fuelCost: 1800,
        driverBata: 500,
        loadingCharge: 0,
        status: 'Completed',
        notes: 'Bund strengthening before water exchange.',
      ),
      VehicleRentalEntry(
        id: 'VRI-AP-003',
        vehicleCatalogId: 'VH-WK-AP-02',
        vehicleName: 'Diesel Bowser for Aerator Line',
        billingType: VehicleBillingType.weekly,
        thavvuId: 'THV-WK-WG-01',
        tankId: 'TNK-WG-07',
        fromLocation: 'West Godavari Backup Bay',
        toLocation: 'Pond cluster service route',
        driverOrOperator: 'Driver Naresh',
        workDate: DateTime(2026, 5, 24),
        units: 1,
        rate: 26000,
        fuelCost: 0,
        driverBata: 1500,
        loadingCharge: 0,
        status: 'Running',
        notes: 'Weekly support for diesel-powered aerator backup.',
      ),
      VehicleRentalEntry(
        id: 'VRI-AP-004',
        vehicleCatalogId: 'VH-TR-AP-01',
        vehicleName: 'Feed Transport Lorry',
        billingType: VehicleBillingType.trip,
        thavvuId: 'THV-TR-AML-01',
        tankId: 'TNK-AML-31',
        fromLocation: 'Amalapuram feed store',
        toLocation: 'Konaseema shrimp pond block',
        driverOrOperator: 'Driver Prasad',
        workDate: DateTime(2026, 5, 27),
        units: 2,
        rate: 4200,
        fuelCost: 1200,
        driverBata: 700,
        loadingCharge: 450,
        status: 'Billing Pending',
        notes: 'Feed bags transported in two trips.',
      ),
      VehicleRentalEntry(
        id: 'VRI-AP-005',
        vehicleCatalogId: 'VH-TR-AP-02',
        vehicleName: 'Insulated Fish Transport Van',
        billingType: VehicleBillingType.trip,
        thavvuId: 'THV-TR-MTM-01',
        tankId: 'TNK-MTM-18',
        fromLocation: 'Machilipatnam Harvest Point',
        toLocation: 'Cold storage loading bay',
        driverOrOperator: 'Driver Kiran',
        workDate: DateTime(2026, 5, 29),
        units: 1,
        rate: 5600,
        fuelCost: 900,
        driverBata: 500,
        loadingCharge: 600,
        status: 'Completed',
        notes: 'Harvest dispatch with insulated box support.',
      ),
      VehicleRentalEntry(
        id: 'VRI-AP-006',
        vehicleCatalogId: 'VH-KM-AP-02',
        vehicleName: 'Service Jeep',
        billingType: VehicleBillingType.km,
        thavvuId: 'THV-KM-KKD-01',
        tankId: 'TNK-KKD-22',
        fromLocation: 'Kakinada water testing shed',
        toLocation: 'Pond inspection route',
        driverOrOperator: 'Technician Ravi',
        workDate: DateTime(2026, 5, 30),
        units: 68,
        rate: 28,
        fuelCost: 0,
        driverBata: 350,
        loadingCharge: 0,
        status: 'Running',
        notes: 'Water quality kit movement and inspection.',
      ),
      VehicleRentalEntry(
        id: 'VRI-AP-007',
        vehicleCatalogId: 'VH-KM-AP-03',
        vehicleName: 'Reefer Van',
        billingType: VehicleBillingType.km,
        thavvuId: 'THV-KM-MTM-01',
        tankId: 'TNK-MTM-18',
        fromLocation: 'Machilipatnam Harvest Point',
        toLocation: 'Vijayawada buyer pickup point',
        driverOrOperator: 'Driver Mahesh',
        workDate: DateTime(2026, 5, 30),
        units: 82,
        rate: 42,
        fuelCost: 0,
        driverBata: 650,
        loadingCharge: 500,
        status: 'Billing Pending',
        notes: 'Cold-chain harvest transport.',
      ),
    ]);
  }

  void _seedVehicleSelections() {
    for (final type in VehicleBillingType.values) {
      final options =
          _vehicleCatalog.where((item) => item.billingType == type).toList();
      if (options.isNotEmpty) {
        _selectedVehicles[type] = options.first;
        _selectedVehicleThavvuIds[type] = _firstId(options.first.thavvuIds);
      }
    }

    if (_transferItems.isNotEmpty) {
      _selectTransferItem(_transferItems.first, showSnack: false);
    }
  }

  // =========================
  // Business helpers
  // =========================

  String _defaultVehicleUsage(VehicleBillingType type) {
    switch (type) {
      case VehicleBillingType.hourly:
        return '6';
      case VehicleBillingType.weekly:
        return '1';
      case VehicleBillingType.trip:
        return '2';
      case VehicleBillingType.km:
        return '45';
    }
  }

  AquaRentalTool? get _selectedAquaTool {
    for (final tool in _aquaToolCatalog) {
      if (tool.id == _selectedAquaToolId) return tool;
    }
    return null;
  }

  String _usageInputLabel(VehicleBillingType type) {
    switch (type) {
      case VehicleBillingType.hourly:
        return 'Hours used';
      case VehicleBillingType.weekly:
        return 'Weeks rented';
      case VehicleBillingType.trip:
        return 'Trips completed';
      case VehicleBillingType.km:
        return 'Distance covered';
    }
  }

  String _usageMetricLabel(VehicleBillingType type) {
    switch (type) {
      case VehicleBillingType.hourly:
        return 'Hours';
      case VehicleBillingType.weekly:
        return 'Weeks';
      case VehicleBillingType.trip:
        return 'Trips';
      case VehicleBillingType.km:
        return 'KM';
    }
  }

  IconData _toolIcon(String category) {
    switch (category.toLowerCase()) {
      case 'aeration':
        return Icons.air;
      case 'pumping':
        return Icons.water_drop_outlined;
      case 'testing':
        return Icons.science_outlined;
      case 'harvesting':
        return Icons.shopping_bag_outlined;
      case 'feeding':
        return Icons.restaurant_outlined;
      case 'transport':
        return Icons.local_shipping_outlined;
      case 'power':
        return Icons.power_outlined;
      case 'pond maintenance':
        return Icons.construction_outlined;
      default:
        return Icons.handyman_outlined;
    }
  }

  List<String> _splitIds(String raw, String fallbackPrefix) {
    final cleaned = raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (cleaned.isNotEmpty) return cleaned;
    return ['$fallbackPrefix-${DateTime.now().millisecondsSinceEpoch}'];
  }

  TransferLocation _locationForDistrict(
    String district, {
    String? siteName,
    String? address,
  }) {
    double latitude = 16.5449;
    double longitude = 81.5212;

    switch (district.toLowerCase()) {
      case 'bhimavaram':
      case 'west godavari':
        latitude = 16.5449;
        longitude = 81.5212;
        break;
      case 'krishna':
      case 'machilipatnam':
        latitude = 16.1809;
        longitude = 81.1303;
        break;
      case 'eluru':
        latitude = 16.7107;
        longitude = 81.0952;
        break;
      case 'nellore':
        latitude = 14.4426;
        longitude = 79.9865;
        break;
      case 'kakinada':
        latitude = 16.9891;
        longitude = 82.2475;
        break;
      case 'amalapuram':
        latitude = 16.5787;
        longitude = 82.0061;
        break;
      case 'bapatla':
        latitude = 15.9042;
        longitude = 80.4677;
        break;
      case 'repalle':
        latitude = 16.0184;
        longitude = 80.8298;
        break;
      case 'narasapuram':
        latitude = 16.4361;
        longitude = 81.7016;
        break;
    }

    return TransferLocation(
      siteName: siteName?.trim().isNotEmpty == true
          ? siteName!.trim()
          : '$district Aqua Site',
      address: address?.trim().isNotEmpty == true
          ? address!.trim()
          : 'Aqua farming zone, $district',
      latitude: latitude,
      longitude: longitude,
    );
  }

  void _applyAquaTool(AquaRentalTool tool) {
    setState(() {
      _selectedAquaToolId = tool.id;
      _itemController.text = tool.name;
      _rateController.text = tool.suggestedRate.toStringAsFixed(0);
      _billingMode = 'Per day';
      _notesController.text = '${tool.purpose} • ${tool.district}';
    });

    _showSnackbar('${tool.name} added to the rental form.', AppTheme.success);
  }


  String? _firstId(List<String> values) {
    if (values.isEmpty) return null;
    return values.first;
  }

  Map<String, List<InternalTransferItem>> _groupTransferItems(
    TransferAssetKind kind,
  ) {
    final grouped = <String, List<InternalTransferItem>>{};
    for (final item in _transferItems.where((e) => e.kind == kind)) {
      final key = '${item.batchId}_${item.rentalId}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  int get _totalTransferRented =>
      _transferItems.fold(0, (sum, item) => sum + item.rentedQty);

  int get _totalTransferReturned =>
      _transferItems.fold(0, (sum, item) => sum + item.returnedQty);

  int get _totalTransferRemaining =>
      _transferItems.fold(0, (sum, item) => sum + item.remainingQty);

  double _vehicleAmount(VehicleBillingType type) {
    final selected = _selectedVehicles[type];
    if (selected == null) return 0;
    final units = double.tryParse(_vehicleUsageControllers[type]?.text ?? '0') ?? 0;
    return units * selected.rate;
  }

  double get _vehicleGrandTotal {
    return VehicleBillingType.values.fold(
      0,
      (sum, type) => sum + _vehicleAmount(type),
    );
  }

  double get _vehicleLedgerGrandTotal {
    return _vehicleEntries.fold(0.0, (sum, entry) => sum + entry.totalAmount);
  }

  List<VehicleRentalEntry> _vehicleEntriesForType(VehicleBillingType type) {
    return _vehicleEntries
        .where((entry) => entry.billingType == type)
        .toList()
      ..sort((a, b) => b.workDate.compareTo(a.workDate));
  }

  double _vehicleEntryTotal(VehicleBillingType type) {
    return _vehicleEntriesForType(type)
        .fold(0.0, (sum, entry) => sum + entry.totalAmount);
  }

  double _vehicleEntryUnits(VehicleBillingType type) {
    return _vehicleEntriesForType(type)
        .fold(0.0, (sum, entry) => sum + entry.units);
  }

  int get _vehicleRunningCount =>
      _vehicleEntries.where((entry) => entry.status == 'Running').length;

  int get _vehicleBillingPendingCount =>
      _vehicleEntries.where((entry) => entry.status == 'Billing Pending').length;

  Color _vehicleStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppTheme.success;
      case 'Billing Pending':
        return AppTheme.warning;
      case 'Cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.info;
    }
  }

  String _vehicleWorkHint(VehicleBillingType type) {
    switch (type) {
      case VehicleBillingType.hourly:
        return 'Best for JCB, tractor, crane, loading, bund repair, and short pond work.';
      case VehicleBillingType.weekly:
        return 'Best for pickup, diesel bowser, testing van, or vehicle kept at farm for many days.';
      case VehicleBillingType.trip:
        return 'Best for feed transport, harvest dispatch, net/crate movement, and fixed-route lorry work.';
      case VehicleBillingType.km:
        return 'Best for service jeep, technician bike, reefer van, and inspection route billing.';
    }
  }

  String _vehicleUnitText(VehicleRentalEntry entry) {
    final units = entry.units % 1 == 0
        ? entry.units.toStringAsFixed(0)
        : entry.units.toStringAsFixed(1);
    return '$units ${entry.billingType.unitLabel}';
  }

  String _formatMoney(num value) => '₹${value.toStringAsFixed(0)}';

  Color _transferStatusColor(InternalTransferItem item) {
    if (item.isReturned) return AppTheme.success;
    if (item.isPartial) return AppTheme.warning;
    return AppTheme.info;
  }

  Color _transferStatusBg(InternalTransferItem item) {
    if (item.isReturned) return AppTheme.successBg;
    if (item.isPartial) return AppTheme.warningBg;
    return AppTheme.info.withOpacity(0.12);
  }

  Color _machineStatusColor(RentalItem rental) {
    switch (rental.machineStatus) {
      case MachineLifecycleStatus.atSite:
        return AppTheme.warning;
      case MachineLifecycleStatus.activeInTank:
        return AppTheme.success;
      case MachineLifecycleStatus.shiftDone:
        return AppTheme.info;
      case MachineLifecycleStatus.closed:
        return AppTheme.textMuted;
    }
  }

  Color _machineStatusBg(RentalItem rental) {
    switch (rental.machineStatus) {
      case MachineLifecycleStatus.atSite:
        return AppTheme.warningBg;
      case MachineLifecycleStatus.activeInTank:
        return AppTheme.successBg;
      case MachineLifecycleStatus.shiftDone:
        return AppTheme.info.withOpacity(0.12);
      case MachineLifecycleStatus.closed:
        return AppTheme.surface;
    }
  }

  int get _machineActivatedCount =>
      _activeRentals.where((rental) => rental.isActivated).length;

  int get _machineAtSiteCount =>
      _activeRentals.where((rental) => !rental.isActivated).length;

  int get _machineTodayCheckedCount =>
      _activeRentals.where((rental) => rental.isTodayChecked()).length;

  void _openMachineDetail(RentalItem rental) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MachineRentalDetailPage(
          rental: rental,
          onUpdated: () {
            if (mounted) setState(() {});
          },
          onActivate: () => _activateRental(rental),
          onContinue: () => _continueRental(rental),
          onClose: () => _closeRentalWithProof(rental),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // =========================
  // Existing rental actions
  // =========================

  void _openRental() {
    if (!(_openRentalFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isOpening = true);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      final newRental = RentalItem(
        id: 'RNT-${DateTime.now().millisecondsSinceEpoch}',
        item: _itemController.text.trim(),
        startDate: DateTime.now(),
        rate: double.tryParse(_rateController.text) ?? 0,
        advance: double.tryParse(_advanceAmountController.text) ?? 0,
        fuelConsumed: double.tryParse(_fuelController.text) ?? 0,
        notes: _notesController.text.trim(),
        siteName: _selectedAquaTool?.district == null
            ? 'Aqua site not assigned'
            : '${_selectedAquaTool!.district} Aqua Site',
        tankId: 'Tank / pond pending',
        fieldLabel: 'Field pending',
        operatorName: 'Operator pending',
        tankEntryDate: DateTime.now(),
        isActivated: false,
      );

      setState(() {
        _activeRentals.insert(0, newRental);
        _isOpening = false;
      });

      _showSnackbar(
        'Rental record opened for ${_itemController.text.trim()}',
        AppTheme.success,
      );
      _clearOpenForm();
    });
  }

  void _activateRental(RentalItem rental) {
    setState(() {
      rental.isActivated = true;
      rental.activationDate ??= DateTime.now();
      rental.tankEntryDate ??= DateTime.now();
      rental.checkToday(note: 'Machine activated in ${rental.tankId}.');
      if (rental.fuelConsumed > 0 && rental.fuelLogs.isEmpty) {
        rental.fuelLogs.add(
          MachineFuelLog(
            id: 'FUL-ACT-${DateTime.now().millisecondsSinceEpoch}',
            date: DateTime.now(),
            type: 'Activation fuel',
            litres: 0,
            amount: rental.fuelConsumed,
            notes: 'Opening fuel amount captured during activation.',
          ),
        );
      }
    });
    _showSnackbar(
      'Machine ${rental.item} activated in ${rental.tankId}.',
      AppTheme.success,
    );
  }

  void _continueRental(RentalItem rental) {
    if (!rental.isActivated) {
      _showSnackbar('Activate the machine before continuing the shift.', AppTheme.warning);
      return;
    }

    if (!rental.isTodayChecked()) {
      setState(() {
        rental.checkToday(note: 'Shift continued and machine verified.');
      });
      _showSnackbar(
        'Shift continued for ${rental.item}. Daily check-in recorded.',
        AppTheme.success,
      );
    } else {
      _showSnackbar('Today already verified for ${rental.item}', AppTheme.info);
    }
  }

  Future<void> _closeRentalWithProof(RentalItem rental) async {
    final proofMethod = await _showProofDialog();
    if (proofMethod == null || !mounted) return;

    setState(() {
      rental.closingProofPath = 'proof_${rental.id}_$proofMethod';
      rental.closingDate = DateTime.now();
      rental.fuelLogs.add(
        MachineFuelLog(
          id: 'FUL-CLOSE-${DateTime.now().millisecondsSinceEpoch}',
          date: DateTime.now(),
          type: 'Closing fuel check',
          litres: 0,
          amount: 0,
          notes: 'Machine closed with proof: $proofMethod.',
        ),
      );

      final closedRental = {
        'id': rental.id,
        'item': rental.item,
        'startDate': _formatDate(rental.startDate),
        'endDate': _formatDate(rental.closingDate!),
        'period':
            '${rental.closingDate!.difference(rental.startDate).inDays} days',
        'rate': rental.rate,
        'advance': rental.advance,
        'billing': rental.getEarnedAmount(),
        'balance':
            rental.getEarnedAmount() - rental.totalFuelCost - rental.advance,
        'payment':
            rental.getEarnedAmount() <= (rental.advance + rental.totalFuelCost)
                ? 'Completed'
                : 'Pending',
        'status': 'Closed',
      };

      _closedRentals.insert(0, closedRental);
      _activeRentals.remove(rental);
    });

    _showSnackbar('Rental ${rental.item} closed with proof.', AppTheme.success);
  }

  Future<String?> _showProofDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Rental'),
        content: const Text(
          'Choose a proof source to complete rental closure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'camera'),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Camera'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'gallery'),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery'),
          ),
        ],
      ),
    );
  }

  void _showRentalActions(RentalItem rental) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                rental.isActivated
                    ? Icons.play_circle_filled
                    : Icons.play_circle_outline,
                color: AppTheme.success,
              ),
              title: Text(
                rental.isActivated ? 'Rental Active' : 'Activate Rental',
              ),
              subtitle: Text(
                rental.isActivated
                    ? 'Rent counting from ${_formatDate(rental.activationDate!)}'
                    : 'Start rent counting from today',
              ),
              onTap: () {
                Navigator.pop(context);
                if (!rental.isActivated) {
                  _activateRental(rental);
                } else {
                  _showSnackbar('Rental already active', AppTheme.info);
                }
              },
            ),
            if (rental.isActivated)
              ListTile(
                leading: const Icon(Icons.today, color: AppTheme.warning),
                title: const Text('Continue Rental'),
                subtitle: Text(
                  rental.isTodayChecked()
                      ? 'Already verified today'
                      : 'Mark rental as active for today',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _continueRental(rental);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.danger),
              title: const Text('Close Rental'),
              subtitle: const Text('Upload proof and close this rental'),
              onTap: () {
                Navigator.pop(context);
                _closeRentalWithProof(rental);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearOpenForm() {
    _itemController.clear();
    _rateController.clear();
    _advanceAmountController.clear();
    _fuelController.clear();
    _notesController.clear();
    _billingMode = 'Per day';
    _advancePaymentMode = 'Cash';
    _selectedAquaToolId = null;
    _openRentalFormKey.currentState?.reset();
  }

  // =========================
  // New internal transfer actions
  // =========================

  void _selectTransferItem(
    InternalTransferItem item, {
    bool showSnack = true,
  }) {
    setState(() {
      _selectedTransferItem = item;
      _selectedTransferThavvuId = _firstId(item.thavvuIds);
      _selectedTransferTankId = _firstId(item.tankIds);
    });

    if (showSnack) {
      _showSnackbar(
        '${item.name} selected. Thavvu ID and Tank ID loaded.',
        AppTheme.info,
      );
    }
  }

  void _changeReturnedCount(InternalTransferItem item, int delta) {
    setState(() {
      final next = item.returnedQty + delta;
      item.returnedQty = next.clamp(0, item.rentedQty);
    });
  }

  void _setVehicleForType(VehicleBillingType type, VehicleCatalogItem vehicle) {
    setState(() {
      _selectedVehicles[type] = vehicle;
      _selectedVehicleThavvuIds[type] = _firstId(vehicle.thavvuIds);
    });
  }

  void _showAddAquaToolSheet() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final rateController = TextEditingController();
    final purposeController = TextEditingController();
    String selectedCategory = 'Aeration';
    String selectedDistrict = 'Bhimavaram';

    const categories = [
      'Aeration',
      'Pumping',
      'Testing',
      'Harvesting',
      'Feeding',
      'Power',
      'Transport',
      'Pond Maintenance',
    ];

    const districts = [
      'Bhimavaram',
      'West Godavari',
      'Krishna',
      'Eluru',
      'Nellore',
      'Kakinada',
      'Amalapuram',
      'Bapatla',
      'Repalle',
      'Narasapuram',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
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
                  children: [
                    _buildSheetHeader(
                      title: 'Add Aqua Rental Tool',
                      subtitle: 'Create your own AP aqua-farm rental tool',
                      icon: Icons.add_business_outlined,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration(
                        label: 'Tool name',
                        hint: 'Example: 2 HP Paddle Wheel Aerator',
                        icon: Icons.handyman_outlined,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter tool name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: _inputDecoration(
                        label: 'Category',
                        icon: Icons.category_outlined,
                      ),
                      items: categories
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        sheetSetState(() => selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDistrict,
                      decoration: _inputDecoration(
                        label: 'Andhra Pradesh district / aqua hub',
                        icon: Icons.place_outlined,
                      ),
                      items: districts
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        sheetSetState(() => selectedDistrict = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(
                        label: 'Suggested rate',
                        icon: Icons.currency_rupee,
                        suffixText: '/day',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter rate';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter a valid rate';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: purposeController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        label: 'Use / purpose',
                        hint: 'Example: shrimp pond oxygen support',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSubmitButton(
                      'Add Tool',
                      AppTheme.primary,
                      () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }

                        final tool = AquaRentalTool(
                          id: 'AQT-USER-${DateTime.now().millisecondsSinceEpoch}',
                          name: nameController.text.trim(),
                          category: selectedCategory,
                          district: selectedDistrict,
                          purpose: purposeController.text.trim().isEmpty
                              ? 'Aqua farm rental work'
                              : purposeController.text.trim(),
                          suggestedRate: double.parse(rateController.text),
                        );

                        setState(() {
                          _aquaToolCatalog.insert(0, tool);
                        });
                        Navigator.pop(context);
                        _applyAquaTool(tool);
                      },
                      false,
                      Icons.add,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddTransferItemSheet() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final batchController = TextEditingController(text: 'WE-AP-NEW');
    final rentalController = TextEditingController(text: 'RNT-AP-2026-NEW');
    final rentedController = TextEditingController(text: '1');
    final returnedController = TextEditingController(text: '0');
    final thavvuController = TextEditingController(text: 'THV-AP-NEW');
    final tankController = TextEditingController(text: 'TNK-AP-NEW');
    final siteController = TextEditingController();
    final addressController = TextEditingController();
    TransferAssetKind selectedKind = TransferAssetKind.workEquipment;
    String selectedDistrict = 'Bhimavaram';

    const districts = [
      'Bhimavaram',
      'West Godavari',
      'Krishna',
      'Eluru',
      'Nellore',
      'Kakinada',
      'Amalapuram',
      'Bapatla',
      'Repalle',
      'Narasapuram',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
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
                  children: [
                    _buildSheetHeader(
                      title: 'Add Internal Transfer',
                      subtitle: 'Add material or work equipment with Thavvu and tank mapping',
                      icon: Icons.swap_horiz,
                      color: AppTheme.info,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration(
                        label: 'Item name',
                        hint: 'Example: Paddle Wheel Aerator',
                        icon: Icons.inventory_2_outlined,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter item name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TransferAssetKind>(
                      value: selectedKind,
                      decoration: _inputDecoration(
                        label: 'Asset type',
                        icon: Icons.category_outlined,
                      ),
                      items: TransferAssetKind.values
                          .map(
                            (kind) => DropdownMenuItem<TransferAssetKind>(
                              value: kind,
                              child: Text(kind.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        sheetSetState(() => selectedKind = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: batchController,
                            decoration: _inputDecoration(
                              label: 'Batch ID',
                              icon: Icons.layers_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: rentalController,
                            decoration: _inputDecoration(
                              label: 'Rental ID',
                              icon: Icons.confirmation_number_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: rentedController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              label: 'Rented count',
                              icon: Icons.add_box_outlined,
                            ),
                            validator: (value) {
                              final number = int.tryParse(value ?? '');
                              if (number == null || number <= 0) {
                                return 'Enter count';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: returnedController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              label: 'Returned count',
                              icon: Icons.assignment_return_outlined,
                            ),
                            validator: (value) {
                              final number = int.tryParse(value ?? '');
                              if (number == null || number < 0) {
                                return 'Enter returned count';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: thavvuController,
                      decoration: _inputDecoration(
                        label: 'Thavvu IDs',
                        hint: 'Use comma for multiple IDs',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tankController,
                      decoration: _inputDecoration(
                        label: 'Tank IDs',
                        hint: 'Use comma for multiple tank IDs',
                        icon: Icons.propane_tank_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDistrict,
                      decoration: _inputDecoration(
                        label: 'Map district / aqua hub',
                        icon: Icons.map_outlined,
                      ),
                      items: districts
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        sheetSetState(() => selectedDistrict = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: siteController,
                      decoration: _inputDecoration(
                        label: 'Site name',
                        hint: 'Example: Pond 12 / Harvest bay',
                        icon: Icons.place_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: _inputDecoration(
                        label: 'Address / note',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSubmitButton(
                      'Add Transfer Entry',
                      AppTheme.info,
                      () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }

                        final rented = int.parse(rentedController.text);
                        final returned =
                            ((int.tryParse(returnedController.text) ?? 0)
                                    .clamp(0, rented))
                                .toInt();

                        final item = InternalTransferItem(
                          id: 'ITM-USER-${DateTime.now().millisecondsSinceEpoch}',
                          name: nameController.text.trim(),
                          kind: selectedKind,
                          batchId: batchController.text.trim().isEmpty
                              ? 'WE-AP-NEW'
                              : batchController.text.trim(),
                          rentalId: rentalController.text.trim().isEmpty
                              ? 'RNT-AP-2026-NEW'
                              : rentalController.text.trim(),
                          rentedQty: rented,
                          returnedQty: returned,
                          thavvuIds: _splitIds(thavvuController.text, 'THV'),
                          tankIds: _splitIds(tankController.text, 'TNK'),
                          location: _locationForDistrict(
                            selectedDistrict,
                            siteName: siteController.text,
                            address: addressController.text,
                          ),
                        );

                        setState(() {
                          _transferItems.insert(0, item);
                          _selectedTransferItem = item;
                          _selectedTransferThavvuId = _firstId(item.thavvuIds);
                          _selectedTransferTankId = _firstId(item.tankIds);
                        });

                        Navigator.pop(context);
                        _showSnackbar(
                          '${item.name} added to internal transfer.',
                          AppTheme.success,
                        );
                      },
                      false,
                      Icons.add,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddVehicleSheet() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final rateController = TextEditingController();
    final thavvuController = TextEditingController(text: 'THV-VH-NEW');
    VehicleBillingType selectedType = VehicleBillingType.hourly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
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
                  children: [
                    _buildSheetHeader(
                      title: 'Add Vehicle / Tool',
                      subtitle: 'Add a rentable line under hourly, weekly, trip, or KM billing',
                      icon: Icons.local_shipping_outlined,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration(
                        label: 'Vehicle / tool name',
                        hint: 'Example: Feed Transport Lorry',
                        icon: Icons.directions_car_outlined,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<VehicleBillingType>(
                      value: selectedType,
                      decoration: _inputDecoration(
                        label: 'Billing type',
                        icon: Icons.receipt_long_outlined,
                      ),
                      items: VehicleBillingType.values
                          .map(
                            (type) => DropdownMenuItem<VehicleBillingType>(
                              value: type,
                              child: Text('${type.shortLabel} • ${type.label}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        sheetSetState(() => selectedType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(
                        label: 'Rate',
                        icon: Icons.currency_rupee,
                        suffixText: '/${selectedType.unitLabel}',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter rate';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter a valid rate';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: thavvuController,
                      decoration: _inputDecoration(
                        label: 'Thavvu IDs',
                        hint: 'Use comma for multiple IDs',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSubmitButton(
                      'Add Vehicle / Tool',
                      AppTheme.warning,
                      () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }

                        final vehicle = VehicleCatalogItem(
                          id: 'VH-USER-${selectedType.shortLabel}-${DateTime.now().millisecondsSinceEpoch}',
                          name: nameController.text.trim(),
                          billingType: selectedType,
                          rate: double.parse(rateController.text),
                          thavvuIds: _splitIds(thavvuController.text, 'THV-VH'),
                        );

                        setState(() {
                          _vehicleCatalog.insert(0, vehicle);
                          _selectedVehicles[selectedType] = vehicle;
                          _selectedVehicleThavvuIds[selectedType] =
                              _firstId(vehicle.thavvuIds);
                        });

                        Navigator.pop(context);
                        _showSnackbar(
                          '${vehicle.name} added to ${selectedType.label}.',
                          AppTheme.success,
                        );
                      },
                      false,
                      Icons.add,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  void _showAddVehicleWorkEntrySheet({VehicleBillingType? initialType}) {
    final formKey = GlobalKey<FormState>();
    VehicleBillingType selectedType = initialType ?? VehicleBillingType.hourly;
    String? selectedVehicleId = _selectedVehicles[selectedType]?.id;
    String? selectedThavvuId = _selectedVehicleThavvuIds[selectedType];

    final tankController = TextEditingController(text: 'TNK-AP-NEW');
    final fromController = TextEditingController(text: 'Aqua yard');
    final toController = TextEditingController(text: 'Pond work site');
    final operatorController = TextEditingController(text: 'Driver / Operator');
    final unitsController = TextEditingController(text: _defaultVehicleUsage(selectedType));
    final rateController = TextEditingController();
    final fuelController = TextEditingController(text: '0');
    final bataController = TextEditingController(text: '0');
    final loadingController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    String selectedStatus = 'Running';

    VehicleCatalogItem? selectedVehicle() {
      final options = _vehicleCatalog
          .where((item) => item.billingType == selectedType)
          .toList();
      if (options.isEmpty) return null;
      for (final option in options) {
        if (option.id == selectedVehicleId) return option;
      }
      return options.first;
    }

    void syncVehicleDefaults() {
      final vehicle = selectedVehicle();
      selectedVehicleId = vehicle?.id;
      selectedThavvuId = _firstId(vehicle?.thavvuIds ?? const <String>[]);
      if (vehicle != null) {
        rateController.text = vehicle.rate.toStringAsFixed(0);
      }
      unitsController.text = _defaultVehicleUsage(selectedType);
    }

    syncVehicleDefaults();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, sheetSetState) {
          final options = _vehicleCatalog
              .where((item) => item.billingType == selectedType)
              .toList();
          final vehicle = selectedVehicle();
          final thavvuOptions = vehicle?.thavvuIds ?? const <String>[];

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
                    _buildSheetHeader(
                      title: 'Add Vehicle Work Entry',
                      subtitle: 'Real-world billing with HR, WK, TR, and KM support',
                      icon: Icons.assignment_add,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<VehicleBillingType>(
                      value: selectedType,
                      decoration: _inputDecoration(
                        label: 'Billing group',
                        icon: Icons.receipt_long_outlined,
                      ),
                      items: VehicleBillingType.values
                          .map(
                            (type) => DropdownMenuItem<VehicleBillingType>(
                              value: type,
                              child: Text('${type.shortLabel} • ${type.label}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        sheetSetState(() {
                          selectedType = value;
                          selectedVehicleId = _selectedVehicles[selectedType]?.id;
                          selectedThavvuId = _selectedVehicleThavvuIds[selectedType];
                          syncVehicleDefaults();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: vehicle?.id,
                      decoration: _inputDecoration(
                        label: 'Vehicle / work asset',
                        icon: Icons.local_shipping_outlined,
                      ),
                      items: options
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      validator: (_) => options.isEmpty ? 'Add a vehicle first' : null,
                      onChanged: options.isEmpty
                          ? null
                          : (value) {
                              sheetSetState(() {
                                selectedVehicleId = value;
                                final newVehicle = selectedVehicle();
                                selectedThavvuId = _firstId(
                                  newVehicle?.thavvuIds ?? const <String>[],
                                );
                                rateController.text =
                                    newVehicle?.rate.toStringAsFixed(0) ?? '';
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: thavvuOptions.contains(selectedThavvuId)
                          ? selectedThavvuId
                          : _firstId(thavvuOptions),
                      decoration: _inputDecoration(
                        label: 'Thavvu ID',
                        icon: Icons.badge_outlined,
                      ),
                      items: thavvuOptions
                          .map(
                            (id) => DropdownMenuItem<String>(
                              value: id,
                              child: Text(id),
                            ),
                          )
                          .toList(),
                      onChanged: thavvuOptions.isEmpty
                          ? null
                          : (value) {
                              sheetSetState(() => selectedThavvuId = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tankController,
                      decoration: _inputDecoration(
                        label: 'Tank / pond ID',
                        hint: 'Example: TNK-BVRM-11',
                        icon: Icons.propane_tank_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: fromController,
                            decoration: _inputDecoration(
                              label: 'From',
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: toController,
                            decoration: _inputDecoration(
                              label: 'To / work site',
                              icon: Icons.flag_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: operatorController,
                      decoration: _inputDecoration(
                        label: 'Driver / operator',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: unitsController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              label: _usageInputLabel(selectedType),
                              icon: selectedType.icon,
                              suffixText: selectedType.unitLabel,
                            ),
                            validator: (value) {
                              final number = double.tryParse(value ?? '');
                              if (number == null || number <= 0) {
                                return 'Enter ${selectedType.unitLabel}';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: rateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              label: 'Rate',
                              icon: Icons.currency_rupee,
                              suffixText: '/${selectedType.unitLabel}',
                            ),
                            validator: (value) {
                              final number = double.tryParse(value ?? '');
                              if (number == null || number < 0) {
                                return 'Enter rate';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: fuelController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              label: 'Fuel / diesel',
                              icon: Icons.local_gas_station_outlined,
                              suffixText: '₹',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: bataController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              label: 'Driver bata',
                              icon: Icons.payments_outlined,
                              suffixText: '₹',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: loadingController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              label: 'Loading / helper',
                              icon: Icons.inventory_2_outlined,
                              suffixText: '₹',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: _inputDecoration(
                              label: 'Status',
                              icon: Icons.fact_check_outlined,
                            ),
                            items: const [
                              'Running',
                              'Completed',
                              'Billing Pending',
                              'Cancelled',
                            ]
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              sheetSetState(() => selectedStatus = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        label: 'Work note',
                        hint: 'Example: feed bags moved, harvest dispatch, bund repair',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.warning.withOpacity(0.22)),
                      ),
                      child: Text(
                        _vehicleWorkHint(selectedType),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSubmitButton(
                      'Save Vehicle Work Entry',
                      AppTheme.warning,
                      () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }

                        final chosenVehicle = selectedVehicle();
                        if (chosenVehicle == null) return;

                        final entry = VehicleRentalEntry(
                          id: 'VRI-USER-${DateTime.now().millisecondsSinceEpoch}',
                          vehicleCatalogId: chosenVehicle.id,
                          vehicleName: chosenVehicle.name,
                          billingType: selectedType,
                          thavvuId: selectedThavvuId ?? _firstId(chosenVehicle.thavvuIds) ?? 'THV-VH-NEW',
                          tankId: tankController.text.trim().isEmpty
                              ? 'TNK-AP-NEW'
                              : tankController.text.trim(),
                          fromLocation: fromController.text.trim().isEmpty
                              ? 'Aqua yard'
                              : fromController.text.trim(),
                          toLocation: toController.text.trim().isEmpty
                              ? 'Pond work site'
                              : toController.text.trim(),
                          driverOrOperator: operatorController.text.trim().isEmpty
                              ? 'Driver / Operator'
                              : operatorController.text.trim(),
                          workDate: DateTime.now(),
                          units: double.parse(unitsController.text),
                          rate: double.parse(rateController.text),
                          fuelCost: double.tryParse(fuelController.text) ?? 0,
                          driverBata: double.tryParse(bataController.text) ?? 0,
                          loadingCharge: double.tryParse(loadingController.text) ?? 0,
                          status: selectedStatus,
                          notes: notesController.text.trim(),
                        );

                        setState(() {
                          _vehicleEntries.insert(0, entry);
                          _selectedVehicles[selectedType] = chosenVehicle;
                          _selectedVehicleThavvuIds[selectedType] = entry.thavvuId;
                        });

                        Navigator.pop(context);
                        _showSnackbar(
                          '${entry.vehicleName} work entry saved.',
                          AppTheme.success,
                        );
                      },
                      false,
                      Icons.save_outlined,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  void _markVehicleEntryCompleted(VehicleRentalEntry entry) {
    final index = _vehicleEntries.indexWhere((item) => item.id == entry.id);
    if (index == -1) return;

    setState(() {
      _vehicleEntries[index] = entry.copyWith(status: 'Completed');
    });

    _showSnackbar('${entry.vehicleName} marked as completed.', AppTheme.success);
  }

  void _deleteVehicleEntry(VehicleRentalEntry entry) {
    setState(() {
      _vehicleEntries.removeWhere((item) => item.id == entry.id);
    });

    _showSnackbar('${entry.vehicleName} work entry removed.', AppTheme.danger);
  }


  // =========================
  // Utilities
  // =========================

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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  double _calculateEarnedAmount() {
    if (_rateController.text.isEmpty) return 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    return _billingMode == 'Per day' ? rate : rate * 8;
  }

  double _calculateUsedAmount() {
    return double.tryParse(_fuelController.text) ?? 0;
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: AppTheme.surface,
    );
  }

  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Rental Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          isScrollable: true,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Open Rental', icon: Icon(Icons.add_circle_outline)),
            Tab(text: 'Active Rentals', icon: Icon(Icons.playlist_add_check)),
            Tab(text: 'Internal Transfer', icon: Icon(Icons.swap_horiz)),
            Tab(text: 'Closed Rentals', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOpenRentalTab(),
          _buildActiveRentalsTab(),
          _buildInternalTransferTab(),
          _buildClosedRentalsTab(),
        ],
      ),
    );
  }

  // =========================
  // Open rental
  // =========================

  Widget _buildOpenRentalTab() {
    return Form(
      key: _openRentalFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(
            emoji: '🔑',
            title: 'Rental Management',
            subtitle: 'Create a rental record and prepare billing details',
            accent: AppTheme.danger,
          ),
          const SizedBox(height: 16),
          _buildAutoIdCard(),
          const SizedBox(height: 16),
          _buildAquaToolCatalogCard(),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 1,
            title: 'Item & Check-in Details',
            color: AppTheme.danger,
            child: _buildItemDetails(),
          ),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 2,
            title: 'Rate & Billing Configuration',
            color: AppTheme.warning,
            child: _buildRateAndBilling(),
          ),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 3,
            title: 'Advance Payment Option',
            color: AppTheme.primary,
            child: _buildAdvancePayment(),
          ),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 4,
            title: 'Fuel & Additional Notes',
            color: AppTheme.info,
            child: _buildFuelAndNotes(),
          ),
          const SizedBox(height: 20),
          _buildFinancialPreview(),
          const SizedBox(height: 20),
          _buildSubmitButton(
            'Open Rental Record',
            AppTheme.danger,
            _openRental,
            _isOpening,
            Icons.add,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =========================
  // Active rentals
  // =========================

  Widget _buildActiveRentalsTab() {
    final sortedRentals = [..._activeRentals]
      ..sort((a, b) {
        final aRank = a.isActivated ? 0 : 1;
        final bRank = b.isActivated ? 0 : 1;
        if (aRank != bRank) return aRank.compareTo(bRank);
        return b.startDate.compareTo(a.startDate);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          emoji: '🟢',
          title: 'Machine Rentals',
          subtitle: 'View machine status, check-ins, tank entry, activation, and fuel logs',
          accent: AppTheme.success,
        ),
        const SizedBox(height: 16),
        _buildActiveMachineSummary(),
        const SizedBox(height: 16),
        _buildMachineListHeader(),
        const SizedBox(height: 12),
        if (_activeRentals.isEmpty)
          _buildEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No machines available',
            subtitle: 'Open a rental first to see machine workflow here.',
          )
        else
          ...sortedRentals.map(_buildActiveRentalCard),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActiveMachineSummary() {
    final fuelTotal = _activeRentals.fold<double>(
      0,
      (sum, rental) => sum + rental.totalFuelCost,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.success, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Machine Workflow Snapshot',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem(
                'Machines',
                _activeRentals.length.toString(),
                Icons.precision_manufacturing_outlined,
                Colors.white,
              ),
              _buildStatItem(
                'Active',
                _machineActivatedCount.toString(),
                Icons.play_circle_outline,
                Colors.greenAccent,
              ),
              _buildStatItem(
                'At Site',
                _machineAtSiteCount.toString(),
                Icons.location_on_outlined,
                Colors.orangeAccent,
              ),
              _buildStatItem(
                'Fuel',
                '₹${fuelTotal.toStringAsFixed(0)}',
                Icons.local_gas_station_outlined,
                Colors.cyanAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Today check-ins: $_machineTodayCheckedCount / ${_activeRentals.length}. Tap any machine to open the complete machine page.',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineListHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Machine List & Check-ins',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'At site, active in tank, shift done, and fuel status are shown here.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        _buildInfoPill(
          'Tap to open',
          AppTheme.primary,
          icon: Icons.touch_app_outlined,
        ),
      ],
    );
  }

  Widget _buildActiveRentalCard(RentalItem rental) {
    final earned = rental.getEarnedAmount();
    final balance = earned - rental.totalFuelCost - rental.advance;
    final isTodayChecked = rental.isTodayChecked();
    final statusColor = _machineStatusColor(rental);

    return InkWell(
      onTap: () => _openMachineDetail(rental),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _machineStatusBg(rental),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    rental.machineStatus.icon,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rental.item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rental.id} • ${rental.tankId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _machineStatusBg(rental),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rental.machineStatus.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoPill(
                  rental.siteName,
                  AppTheme.success,
                  icon: Icons.place_outlined,
                ),
                _buildInfoPill(
                  rental.fieldLabel,
                  AppTheme.info,
                  icon: Icons.agriculture_outlined,
                ),
                _buildInfoPill(
                  rental.operatorName,
                  AppTheme.primary,
                  icon: Icons.person_outline,
                ),
                _buildInfoPill(
                  isTodayChecked ? 'Checked Today' : 'Check Pending',
                  isTodayChecked ? AppTheme.success : AppTheme.danger,
                  icon: isTodayChecked
                      ? Icons.check_circle_outline
                      : Icons.pending_actions_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric(
                    'Tank Entry',
                    rental.tankEntryDate == null
                        ? 'Pending'
                        : _formatDate(rental.tankEntryDate!),
                    color: rental.tankEntryDate == null
                        ? AppTheme.warning
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Activated',
                    rental.activationDate == null
                        ? 'Not activated'
                        : _formatDate(rental.activationDate!),
                    color: rental.activationDate == null
                        ? AppTheme.warning
                        : AppTheme.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Check-ins',
                    rental.dailyCheckIns.length.toString(),
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric(
                    'Fuel Cost',
                    '₹${rental.totalFuelCost.toStringAsFixed(0)}',
                    color: AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Earned',
                    '₹${earned.toStringAsFixed(0)}',
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Balance',
                    '₹${balance.toStringAsFixed(0)}',
                    color: balance < 0 ? AppTheme.danger : AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCheckInStrip(rental),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: rental.isActivated
                        ? () => _openMachineDetail(rental)
                        : () => _activateRental(rental),
                    icon: Icon(
                      rental.isActivated
                          ? Icons.visibility_outlined
                          : Icons.play_arrow_outlined,
                      size: 18,
                    ),
                    label: Text(rental.isActivated ? 'Open' : 'Activate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          rental.isActivated ? AppTheme.primary : AppTheme.success,
                      side: BorderSide(
                        color: rental.isActivated
                            ? AppTheme.primary
                            : AppTheme.success,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        rental.isActivated ? () => _continueRental(rental) : null,
                    icon: const Icon(Icons.update, size: 18),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      disabledBackgroundColor: AppTheme.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInStrip(RentalItem rental) {
    if (rental.dailyCheckIns.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warningBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
        ),
        child: const Text(
          'No check-ins yet. Activate the machine or tap Continue after work starts.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.warning,
          ),
        ),
      );
    }

    final checks = rental.dailyCheckIns.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Check-in History',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: checks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final check = checks[index];
              return _buildInfoPill(
                _formatDate(check.date),
                AppTheme.info,
                icon: Icons.calendar_today_outlined,
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================
  // Internal transfer
  // =========================

  Widget _buildInternalTransferTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          emoji: '🔁',
          title: 'Internal Transfer',
          subtitle:
              'Transfer aqua-farm assets, reconcile returns, map locations, and manage VRI',
          accent: AppTheme.info,
        ),
        const SizedBox(height: 16),
        _buildInternalTransferSummaryCard(),
        const SizedBox(height: 16),
        _buildSelectedTransferCard(),
        const SizedBox(height: 16),
        _buildTransferBatchSection(TransferAssetKind.material),
        const SizedBox(height: 16),
        _buildTransferBatchSection(TransferAssetKind.workEquipment),
        const SizedBox(height: 16),
        _buildTransferMapCard(),
        const SizedBox(height: 16),
        _buildVehicleRentalInfoCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInternalTransferSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.info, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transfer Snapshot',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showAddTransferItemSheet,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem(
                'Rented',
                _totalTransferRented.toString(),
                Icons.shopping_bag_outlined,
                Colors.orange,
              ),
              _buildStatItem(
                'Returned',
                _totalTransferReturned.toString(),
                Icons.assignment_return_outlined,
                Colors.green,
              ),
              _buildStatItem(
                'Chargeable',
                _totalTransferRemaining.toString(),
                Icons.sync_outlined,
                Colors.cyan,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedTransferItem == null
                  ? 'No item selected. Add or tap an item to bind Thavvu ID and Tank ID.'
                  : 'Selected: ${_selectedTransferItem!.name} • Batch ${_selectedTransferItem!.batchId} • Rental ${_selectedTransferItem!.rentalId}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTransferCard() {
    final item = _selectedTransferItem;

    return _buildSectionCard(
      title: 'Selected Transfer',
      subtitle: 'Tap an equipment row to bind Thavvu ID and Tank ID',
      icon: Icons.badge_outlined,
      color: AppTheme.primary,
      child: item == null
          ? _buildEmptyState(
              icon: Icons.touch_app_outlined,
              title: 'No equipment selected',
              subtitle: 'Select any transfer equipment to load IDs and details.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoPill(
                      item.name,
                      AppTheme.primary,
                      icon: Icons.inventory_2_outlined,
                    ),
                    _buildInfoPill(
                      'Batch ${item.batchId}',
                      AppTheme.info,
                      icon: Icons.layers_outlined,
                    ),
                    _buildInfoPill(
                      'Rental ${item.rentalId}',
                      AppTheme.success,
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedTransferThavvuId,
                  decoration: _inputDecoration(
                    label: 'Thavvu ID',
                    icon: Icons.badge_outlined,
                  ),
                  items: item.thavvuIds
                      .map(
                        (id) =>
                            DropdownMenuItem<String>(value: id, child: Text(id)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedTransferThavvuId = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedTransferTankId,
                  decoration: _inputDecoration(
                    label: 'Tank ID',
                    icon: Icons.propane_tank_outlined,
                  ),
                  items: item.tankIds
                      .map(
                        (id) =>
                            DropdownMenuItem<String>(value: id, child: Text(id)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedTransferTankId = value);
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.remainingQty == 0
                        ? AppTheme.successBg
                        : AppTheme.warningBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.remainingQty == 0
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ),
                  child: Text(
                    item.remainingQty == 0
                        ? 'Return tally matched. This item is fully returned.'
                        : 'Returned count does not fully tally. ${item.remainingQty} item(s) continue by default and stay chargeable.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.remainingQty == 0
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTransferBatchSection(TransferAssetKind kind) {
    final groups = _groupTransferItems(kind).entries.toList();

    return _buildSectionCard(
      title: '${kind.label} by Batch',
      subtitle: 'Grouped by batch and linked rental ID',
      icon: kind.icon,
      color: kind == TransferAssetKind.material
          ? AppTheme.info
          : AppTheme.warning,
      child: groups.isEmpty
          ? _buildEmptyState(
              icon: kind.icon,
              title: 'No ${kind.label.toLowerCase()}',
              subtitle: 'Nothing is available in this section.',
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final entry = groups[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == groups.length - 1 ? 0 : 12,
                  ),
                  child: _buildTransferBatchGroupCard(entry.key, entry.value),
                );
              },
            ),
    );
  }

  Widget _buildTransferBatchGroupCard(
    String groupKey,
    List<InternalTransferItem> items,
  ) {
    final first = items.first;
    final totalRented = items.fold(0, (sum, item) => sum + item.rentedQty);
    final totalReturned = items.fold(0, (sum, item) => sum + item.returnedQty);
    final totalRemaining =
        items.fold(0, (sum, item) => sum + item.remainingQty);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ExpansionTile(
        key: PageStorageKey(groupKey),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: first.kind == TransferAssetKind.material
                ? AppTheme.info.withOpacity(0.12)
                : AppTheme.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            first.kind.icon,
            color: first.kind == TransferAssetKind.material
                ? AppTheme.info
                : AppTheme.warning,
          ),
        ),
        title: Text(
          'Batch ${first.batchId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Rental ${first.rentalId} • ${first.kind.label}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric('Rented', totalRented.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric('Returned', totalReturned.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Chargeable',
                  totalRemaining.toString(),
                  color: totalRemaining == 0
                      ? AppTheme.success
                      : AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(_buildTransferItemCard),
        ],
      ),
    );
  }

  Widget _buildTransferItemCard(InternalTransferItem item) {
    final isSelected = _selectedTransferItem?.id == item.id;
    final statusColor = _transferStatusColor(item);

    return InkWell(
      onTap: () => _selectTransferItem(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.08)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
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
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.id,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _transferStatusBg(item),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoPill(
                  'Batch ${item.batchId}',
                  AppTheme.info,
                  icon: Icons.layers_outlined,
                ),
                _buildInfoPill(
                  'Rental ${item.rentalId}',
                  AppTheme.primary,
                  icon: Icons.confirmation_number_outlined,
                ),
                _buildInfoPill(
                  item.location.siteName,
                  AppTheme.success,
                  icon: Icons.place_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric('Rented', item.rentedQty.toString()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Returned',
                    item.returnedQty.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Chargeable',
                    item.chargeableQty.toString(),
                    color: item.chargeableQty == 0
                        ? AppTheme.success
                        : AppTheme.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Returned count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                _buildCounterButton(
                  icon: Icons.remove,
                  onTap: () => _changeReturnedCount(item, -1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${item.returnedQty}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildCounterButton(
                  icon: Icons.add,
                  onTap: () => _changeReturnedCount(item, 1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.remainingQty == 0
                  ? 'Tally matched, fully returned.'
                  : '${item.remainingQty} item(s) continue by default and remain payable.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: item.remainingQty == 0
                    ? AppTheme.success
                    : AppTheme.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferMapCard() {
    final items = _transferItems;

    return _buildSectionCard(
      title: 'Location Map',
      subtitle: 'Map-ready item locations with tap-to-select markers',
      icon: Icons.map_outlined,
      color: AppTheme.success,
      child: items.isEmpty
          ? _buildEmptyState(
              icon: Icons.map_outlined,
              title: 'No map items available',
              subtitle: 'Transfer items will appear here when loaded.',
            )
          : Column(
              children: [
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final latitudes =
                          items.map((e) => e.location.latitude).toList();
                      final longitudes =
                          items.map((e) => e.location.longitude).toList();

                      final minLat = latitudes.reduce(math.min);
                      final maxLat = latitudes.reduce(math.max);
                      final minLng = longitudes.reduce(math.min);
                      final maxLng = longitudes.reduce(math.max);

                      final latRange =
                          (maxLat - minLat).abs() < 0.000001 ? 1.0 : maxLat - minLat;
                      final lngRange =
                          (maxLng - minLng).abs() < 0.000001 ? 1.0 : maxLng - minLng;

                      return Stack(
                        children: [
                          const Positioned.fill(
                            child: CustomPaint(painter: _MapGridPainter()),
                          ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: _buildInfoPill(
                              'Location Board',
                              AppTheme.primary,
                              icon: Icons.layers_outlined,
                            ),
                          ),
                          ...items.map((item) {
                            final dx = 20 +
                                ((item.location.longitude - minLng) / lngRange) *
                                    (constraints.maxWidth - 80);
                            final dy = 35 +
                                ((maxLat - item.location.latitude) / latRange) *
                                    (constraints.maxHeight - 95);

                            final left = dx
                                .clamp(12.0, constraints.maxWidth - 90.0)
                                .toDouble();
                            final top = dy
                                .clamp(18.0, constraints.maxHeight - 70.0)
                                .toDouble();

                            final isSelected =
                                _selectedTransferItem?.id == item.id;

                            return Positioned(
                              left: left,
                              top: top,
                              child: GestureDetector(
                                onTap: () => _selectTransferItem(item),
                                child: Column(
                                  children: [
                                    Container(
                                      width: isSelected ? 18 : 14,
                                      height: isSelected ? 18 : 14,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.danger
                                            : AppTheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 88,
                                      child: Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppTheme.danger
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedTransferItem != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTransferItem!.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_selectedTransferItem!.location.siteName} • ${_selectedTransferItem!.location.address}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildInfoPill(
                              'Lat ${_selectedTransferItem!.location.latitude.toStringAsFixed(4)}',
                              AppTheme.info,
                              icon: Icons.north_east_outlined,
                            ),
                            _buildInfoPill(
                              'Lng ${_selectedTransferItem!.location.longitude.toStringAsFixed(4)}',
                              AppTheme.success,
                              icon: Icons.place_outlined,
                            ),
                            if (_selectedTransferThavvuId != null)
                              _buildInfoPill(
                                _selectedTransferThavvuId!,
                                AppTheme.primary,
                                icon: Icons.badge_outlined,
                              ),
                            if (_selectedTransferTankId != null)
                              _buildInfoPill(
                                _selectedTransferTankId!,
                                AppTheme.warning,
                                icon: Icons.propane_tank_outlined,
                              ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Tap any map marker or equipment row to view location details.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
              ],
            ),
    );
  }

  Widget _buildVehicleRentalInfoCard() {
    return _buildSectionCard(
      title: 'Vehicle Rental Info (VRI)',
      subtitle: 'Real work entries with HR, WK, TR, and KM billing maintained separately',
      icon: Icons.local_shipping_outlined,
      color: AppTheme.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoPill(
                '${_vehicleCatalog.length} vehicle masters',
                AppTheme.warning,
                icon: Icons.list_alt_outlined,
              ),
              _buildInfoPill(
                '${_vehicleEntries.length} work entries',
                AppTheme.info,
                icon: Icons.assignment_outlined,
              ),
              _buildInfoPill(
                'Running $_vehicleRunningCount',
                AppTheme.primary,
                icon: Icons.sync_outlined,
              ),
              _buildInfoPill(
                'Pending $_vehicleBillingPendingCount',
                AppTheme.danger,
                icon: Icons.pending_actions_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAddVehicleSheet,
                  icon: const Icon(Icons.add_business_outlined, size: 18),
                  label: const Text('Add Master'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    side: BorderSide(color: AppTheme.warning),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddVehicleWorkEntrySheet(),
                  icon: const Icon(Icons.assignment_add, size: 18),
                  label: const Text('Add Work'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.warning.withOpacity(0.20)),
            ),
            child: const Text(
              'Use Add Master for vehicle list entries. Use Add Work for actual site billing: tank, route, driver/operator, hours/weeks/trips/km, rate, diesel, bata, loading, status, and notes.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  'Quick estimate',
                  _formatMoney(_vehicleGrandTotal),
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Work ledger',
                  _formatMoney(_vehicleLedgerGrandTotal),
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Billing groups',
                  'HR • WK • TR • KM',
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...VehicleBillingType.values.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildVehicleCategoryTile(type),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Real VRI ledger grand total',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatMoney(_vehicleLedgerGrandTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCategoryTile(VehicleBillingType type) {
    final options =
        _vehicleCatalog.where((item) => item.billingType == type).toList();
    final selected = _selectedVehicles[type];
    final controller = _vehicleUsageControllers[type]!;
    final amount = _vehicleAmount(type);
    final entries = _vehicleEntriesForType(type);
    final ledgerTotal = _vehicleEntryTotal(type);
    final totalUnits = _vehicleEntryUnits(type);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ExpansionTile(
        key: PageStorageKey('vri_${type.name}'),
        initiallyExpanded: type == VehicleBillingType.hourly,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(type.icon, color: AppTheme.warning, size: 20),
        ),
        title: Text(
          '${type.shortLabel} • ${type.label}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${entries.length} work entries • ${_formatMoney(ledgerTotal)} ledger • ${_usageMetricLabel(type)} ${totalUnits.toStringAsFixed(totalUnits % 1 == 0 ? 0 : 1)}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              _vehicleWorkHint(type),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddVehicleWorkEntrySheet(initialType: type),
                  icon: const Icon(Icons.assignment_add, size: 18),
                  label: const Text('Add Work Entry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    side: BorderSide(color: AppTheme.warning),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: _showAddVehicleSheet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Master'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (options.isEmpty)
            _buildEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No vehicle masters',
              subtitle: 'Add a vehicle master first, then create work entries.',
            )
          else ...[
            DropdownButtonFormField<String>(
              value: selected?.id,
              decoration: _inputDecoration(
                label: 'Quick estimate vehicle / tool',
                icon: Icons.directions_car_outlined,
              ),
              items: options
                  .map(
                    (vehicle) => DropdownMenuItem<String>(
                      value: vehicle.id,
                      child: Text(vehicle.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final vehicle = options.firstWhere((e) => e.id == value);
                _setVehicleForType(type, vehicle);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedVehicleThavvuIds[type],
              decoration: _inputDecoration(
                label: 'Thavvu ID',
                icon: Icons.badge_outlined,
              ),
              items: (selected?.thavvuIds ?? const <String>[])
                  .map(
                    (id) => DropdownMenuItem<String>(value: id, child: Text(id)),
                  )
                  .toList(),
              onChanged: selected == null
                  ? null
                  : (value) {
                      setState(() => _selectedVehicleThavvuIds[type] = value);
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration(
                label: _usageInputLabel(type),
                icon: type.icon,
                suffixText: type.unitLabel,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric(
                    'Rate',
                    selected == null
                        ? '—'
                        : '${_formatMoney(selected.rate)}/${type.unitLabel}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    _usageMetricLabel(type),
                    controller.text.isEmpty ? '0' : controller.text,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'Estimate',
                    _formatMoney(amount),
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  'Real entries',
                  entries.length.toString(),
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Ledger units',
                  totalUnits.toStringAsFixed(totalUnits % 1 == 0 ? 0 : 1),
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Ledger total',
                  _formatMoney(ledgerTotal),
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            _buildEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No real work entries yet',
              subtitle: 'Tap Add Work Entry to save actual ${type.label.toLowerCase()} billing.',
            )
          else
            ...entries.map(_buildVehicleWorkEntryCard),
        ],
      ),
    );
  }

  Widget _buildVehicleWorkEntryCard(VehicleRentalEntry entry) {
    final statusColor = _vehicleStatusColor(entry.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.billingType.icon, color: AppTheme.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.vehicleName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${entry.id} • ${_formatDate(entry.workDate)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.status,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoPill(
                entry.thavvuId,
                AppTheme.primary,
                icon: Icons.badge_outlined,
              ),
              _buildInfoPill(
                entry.tankId,
                AppTheme.warning,
                icon: Icons.propane_tank_outlined,
              ),
              _buildInfoPill(
                entry.driverOrOperator,
                AppTheme.info,
                icon: Icons.person_outline,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${entry.fromLocation} → ${entry.toLocation}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (entry.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.notes,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  _usageMetricLabel(entry.billingType),
                  _vehicleUnitText(entry),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Base',
                  _formatMoney(entry.baseAmount),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Total',
                  _formatMoney(entry.totalAmount),
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  'Diesel',
                  _formatMoney(entry.fuelCost),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Bata',
                  _formatMoney(entry.driverBata),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Loading',
                  _formatMoney(entry.loadingCharge),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (entry.status != 'Completed')
                TextButton.icon(
                  onPressed: () => _markVehicleEntryCompleted(entry),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Complete'),
                ),
              TextButton.icon(
                onPressed: () => _deleteVehicleEntry(entry),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // Closed rentals
  // =========================

  Widget _buildClosedRentalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          emoji: '📘',
          title: 'Closed Rentals',
          subtitle: 'Review completed rental history and balances',
          accent: AppTheme.primary,
        ),
        const SizedBox(height: 16),
        _buildClosedRentalsStats(),
        const SizedBox(height: 16),
        ..._closedRentals.map(_buildClosedRentalCard),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildClosedRentalsStats() {
    final totalRevenue = _closedRentals.fold<double>(
      0,
      (sum, item) => sum + (item['billing'] as num).toDouble(),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Closed Rentals Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem(
                'Total',
                _closedRentals.length.toString(),
                Icons.history,
                Colors.white,
              ),
              _buildStatItem(
                'Completed',
                _closedRentals
                    .where((r) => r['payment'] == 'Completed')
                    .length
                    .toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatItem(
                'Revenue',
                '₹${totalRevenue.toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClosedRentalCard(Map<String, dynamic> rental) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rental['item'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      rental['id'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Closed',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem('Start', rental['startDate']),
              _buildDetailItem('End', rental['endDate']),
              _buildDetailItem('Period', rental['period']),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem('Billing', '₹${rental['billing']}'),
              _buildDetailItem('Balance', '₹${rental['balance']}'),
              _buildDetailItem('Payment', rental['payment']),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // Reusable UI
  // =========================

  Widget _buildHeader({
    required String emoji,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withOpacity(0.15), accent.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.20)),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoIdCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.dangerBg, AppTheme.dangerBg],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.danger.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_fix_high,
              color: AppTheme.danger,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-generated Rental ID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.danger,
                  ),
                ),
                Text(
                  'Will be assigned after opening',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.danger,
                  ),
                ),
                SizedBox(height: 4),
                HodApprovalBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalCard({
    required int step,
    required String title,
    required Color color,
    required Widget child,
  }) {
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
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.80)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAquaToolCatalogCard() {
    return _buildSectionCard(
      title: 'AP Aqua Rental Tools',
      subtitle: 'Tap a tool to auto-fill rental item and day rate',
      icon: Icons.water_drop_outlined,
      color: AppTheme.primary,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_aquaToolCatalog.length} mock tools from Andhra Pradesh aqua-farming workflows',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showAddAquaToolSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _aquaToolCatalog.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _buildAquaToolTile(_aquaToolCatalog[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAquaToolTile(AquaRentalTool tool) {
    final isSelected = _selectedAquaToolId == tool.id;

    return InkWell(
      onTap: () => _applyAquaTool(tool),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 246,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.08)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.4 : 0.8,
          ),
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
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _toolIcon(tool.category),
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tool.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              tool.purpose,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildInfoPill(
                  tool.category,
                  AppTheme.info,
                  icon: Icons.category_outlined,
                ),
                _buildInfoPill(
                  tool.district,
                  AppTheme.success,
                  icon: Icons.place_outlined,
                ),
                _buildInfoPill(
                  '₹${tool.suggestedRate.toStringAsFixed(0)}/${tool.billingUnit}',
                  AppTheme.warning,
                  icon: Icons.currency_rupee,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetails() {
    return Column(
      children: [
        TextFormField(
          controller: _itemController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter item name';
            }
            return null;
          },
          decoration: _inputDecoration(
            label: 'Item Name',
            hint: 'Enter rented equipment name',
            icon: Icons.build_outlined,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _formatDate(DateTime.now()),
          readOnly: true,
          decoration: _inputDecoration(
            label: 'Check-in Date',
            icon: Icons.calendar_today_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildRateAndBilling() {
    const billingModes = ['Per day', 'Per hour'];

    return Column(
      children: [
        const Text(
          'Billing Mode',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: billingModes.map((mode) {
            final isSelected = _billingMode == mode;
            final isLast = mode == billingModes.last;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: GestureDetector(
                  onTap: () => setState(() => _billingMode = mode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppTheme.danger,
                                AppTheme.danger.withOpacity(0.80),
                              ],
                            )
                          : null,
                      color: isSelected ? null : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.danger : AppTheme.border,
                        width: isSelected ? 0 : 0.8,
                      ),
                    ),
                    child: Text(
                      mode,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _rateController,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter rate';
            }
            if (double.tryParse(value) == null) {
              return 'Enter a valid number';
            }
            return null;
          },
          decoration: _inputDecoration(
            label:
                'Rate per ${_billingMode == 'Per day' ? 'day' : 'hour'} (₹)',
            icon: Icons.currency_rupee,
            suffixText: _billingMode == 'Per day' ? '/day' : '/hour',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildAdvancePayment() {
    const modes = ['UPI', 'Cash', 'Digital'];

    IconData iconForMode(String mode) {
      switch (mode) {
        case 'UPI':
          return Icons.qr_code;
        case 'Cash':
          return Icons.money;
        case 'Digital':
          return Icons.phone_android;
      }
      return Icons.payments;
    }

    return Column(
      children: [
        TextFormField(
          controller: _advanceAmountController,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter advance amount';
            }
            if (double.tryParse(value) == null) {
              return 'Enter a valid number';
            }
            return null;
          },
          decoration: _inputDecoration(
            label: 'Advance Amount (₹)',
            hint: 'Enter advance payment received',
            icon: Icons.payments_outlined,
            suffixText: '₹',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const Text(
          'Advance Payment Mode',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: modes.map((mode) {
            final isSelected = _advancePaymentMode == mode;
            final isLast = mode == modes.last;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: GestureDetector(
                  onTap: () => setState(() => _advancePaymentMode = mode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withOpacity(0.15)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? AppTheme.primary : AppTheme.border,
                        width: isSelected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          iconForMode(mode),
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFuelAndNotes() {
    return Column(
      children: [
        TextFormField(
          controller: _fuelController,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(
            label: 'Fuel Consumed (₹)',
            hint: 'Diesel/petrol as running total',
            icon: Icons.local_gas_station_outlined,
            suffixText: '₹',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: _inputDecoration(
            label: 'Additional Notes',
            hint: 'Conditions, remarks, observations...',
            icon: Icons.notes_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialPreview() {
    final earned = _calculateEarnedAmount();
    final used = _calculateUsedAmount();
    final advance = double.tryParse(_advanceAmountController.text) ?? 0;
    final remaining = earned - used - advance;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Preview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPreviewItem(
                'Earned',
                '₹${earned.toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.green,
              ),
              const SizedBox(width: 8),
              _buildPreviewItem(
                'Advance',
                '₹${advance.toStringAsFixed(0)}',
                Icons.payments,
                Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildPreviewItem(
                'Used',
                '₹${used.toStringAsFixed(0)}',
                Icons.shopping_cart,
                Colors.red,
              ),
              const SizedBox(width: 8),
              _buildPreviewItem(
                'Balance',
                '₹${remaining.toStringAsFixed(0)}',
                Icons.account_balance_wallet,
                Colors.cyan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 8, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(
    String label,
    Color color,
    VoidCallback onPressed,
    bool isLoading,
    IconData icon,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMiniMetric(
    String label,
    String value, {
    Color? color,
  }) {
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
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(
    String text,
    Color color, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 16, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white60),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class MachineRentalDetailPage extends StatefulWidget {
  final RentalItem rental;
  final VoidCallback onUpdated;
  final VoidCallback onActivate;
  final VoidCallback onContinue;
  final Future<void> Function() onClose;

  const MachineRentalDetailPage({
    super.key,
    required this.rental,
    required this.onUpdated,
    required this.onActivate,
    required this.onContinue,
    required this.onClose,
  });

  @override
  State<MachineRentalDetailPage> createState() => _MachineRentalDetailPageState();
}

class _MachineRentalDetailPageState extends State<MachineRentalDetailPage> {
  RentalItem get rental => widget.rental;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatMoney(num value) => '₹${value.toStringAsFixed(0)}';

  Color _statusColor() {
    switch (rental.machineStatus) {
      case MachineLifecycleStatus.atSite:
        return AppTheme.warning;
      case MachineLifecycleStatus.activeInTank:
        return AppTheme.success;
      case MachineLifecycleStatus.shiftDone:
        return AppTheme.info;
      case MachineLifecycleStatus.closed:
        return AppTheme.textMuted;
    }
  }

  Color _statusBg() {
    switch (rental.machineStatus) {
      case MachineLifecycleStatus.atSite:
        return AppTheme.warningBg;
      case MachineLifecycleStatus.activeInTank:
        return AppTheme.successBg;
      case MachineLifecycleStatus.shiftDone:
        return AppTheme.info.withOpacity(0.12);
      case MachineLifecycleStatus.closed:
        return AppTheme.surface;
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: AppTheme.surface,
    );
  }

  Future<DateTime?> _pickDate(DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
  }

  void _refresh() {
    widget.onUpdated();
    setState(() {});
  }

  void _activateMachine() {
    widget.onActivate();
    _refresh();
  }

  void _continueMachine() {
    widget.onContinue();
    _refresh();
  }

  Future<void> _closeMachine() async {
    await widget.onClose();
    if (mounted) {
      Navigator.maybePop(context);
    }
  }

  void _showEditLifecycleSheet() {
    final formKey = GlobalKey<FormState>();
    final siteController = TextEditingController(text: rental.siteName);
    final tankController = TextEditingController(text: rental.tankId);
    final fieldController = TextEditingController(text: rental.fieldLabel);
    final operatorController = TextEditingController(text: rental.operatorName);
    DateTime tankEntryDate = rental.tankEntryDate ?? rental.startDate;
    DateTime? activationDate = rental.activationDate;
    DateTime? closingDate = rental.closingDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
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
                  children: [
                    _sheetHeader(
                      title: 'Edit Machine Flow',
                      subtitle: 'Update site, tank, field, operator, and important dates',
                      icon: Icons.edit_note_outlined,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: siteController,
                      decoration: _inputDecoration(
                        label: 'Site name',
                        hint: 'Example: Bhimavaram Aqua Yard',
                        icon: Icons.place_outlined,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter site name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: tankController,
                            decoration: _inputDecoration(
                              label: 'Tank / Pond ID',
                              icon: Icons.propane_tank_outlined,
                            ),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Enter tank ID'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: fieldController,
                            decoration: _inputDecoration(
                              label: 'Field / Line',
                              icon: Icons.agriculture_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: operatorController,
                      decoration: _inputDecoration(
                        label: 'Operator / worker',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _dateTile(
                      title: 'Machine entered tank',
                      value: _formatDate(tankEntryDate),
                      icon: Icons.login_outlined,
                      color: AppTheme.info,
                      onTap: () async {
                        final picked = await _pickDate(tankEntryDate);
                        if (picked != null) {
                          sheetSetState(() => tankEntryDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _dateTile(
                      title: 'Activated date',
                      value: activationDate == null
                          ? 'Not activated yet'
                          : _formatDate(activationDate!),
                      icon: Icons.play_circle_outline,
                      color: activationDate == null ? AppTheme.warning : AppTheme.success,
                      onTap: () async {
                        final picked = await _pickDate(activationDate ?? DateTime.now());
                        if (picked != null) {
                          sheetSetState(() => activationDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _dateTile(
                      title: 'Closed date',
                      value: closingDate == null ? 'Not closed yet' : _formatDate(closingDate!),
                      icon: Icons.lock_outline,
                      color: closingDate == null ? AppTheme.textMuted : AppTheme.danger,
                      onTap: () async {
                        final picked = await _pickDate(closingDate ?? DateTime.now());
                        if (picked != null) {
                          sheetSetState(() => closingDate = picked);
                        }
                      },
                      trailing: closingDate == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => sheetSetState(() => closingDate = null),
                            ),
                    ),
                    const SizedBox(height: 18),
                    _submitButton(
                      'Save Machine Flow',
                      AppTheme.primary,
                      Icons.save_outlined,
                      () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setState(() {
                          rental.siteName = siteController.text.trim();
                          rental.tankId = tankController.text.trim();
                          rental.fieldLabel = fieldController.text.trim().isEmpty
                              ? 'Field not assigned'
                              : fieldController.text.trim();
                          rental.operatorName = operatorController.text.trim().isEmpty
                              ? 'Operator not assigned'
                              : operatorController.text.trim();
                          rental.tankEntryDate = tankEntryDate;
                          rental.activationDate = activationDate;
                          rental.isActivated = activationDate != null;
                          rental.closingDate = closingDate;
                        });
                        widget.onUpdated();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFuelLogSheet({int? editIndex}) {
    final formKey = GlobalKey<FormState>();
    final oldLog = editIndex == null ? null : rental.fuelLogs[editIndex];
    final litreController = TextEditingController(
      text: oldLog == null || oldLog.litres == 0 ? '' : oldLog.litres.toString(),
    );
    final amountController = TextEditingController(
      text: oldLog == null || oldLog.amount == 0 ? '' : oldLog.amount.toString(),
    );
    final readingController = TextEditingController(text: oldLog?.meterReading ?? '');
    final notesController = TextEditingController(text: oldLog?.notes ?? '');
    DateTime selectedDate = oldLog?.date ?? DateTime.now();
    String selectedType = oldLog?.type ?? 'Activation fuel';

    const fuelTypes = [
      'Activation fuel',
      'Running refill',
      'Shift-end check',
      'Closing fuel check',
      'Diesel balance note',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
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
                  children: [
                    _sheetHeader(
                      title: editIndex == null ? 'Add Fuel Record' : 'Edit Fuel Record',
                      subtitle: 'Track fuel at activation, running refill, shift end, or closing',
                      icon: Icons.local_gas_station_outlined,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: _inputDecoration(
                        label: 'Fuel record type',
                        icon: Icons.receipt_long_outlined,
                      ),
                      items: fuelTypes
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        sheetSetState(() => selectedType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _dateTile(
                      title: 'Fuel date',
                      value: _formatDate(selectedDate),
                      icon: Icons.calendar_today_outlined,
                      color: AppTheme.info,
                      onTap: () async {
                        final picked = await _pickDate(selectedDate);
                        if (picked != null) {
                          sheetSetState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: litreController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecoration(
                              label: 'Fuel used / checked',
                              icon: Icons.opacity_outlined,
                              suffixText: 'L',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return null;
                              if (double.tryParse(value) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecoration(
                              label: 'Fuel amount',
                              icon: Icons.currency_rupee,
                              suffixText: '₹',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Enter amount';
                              if (double.tryParse(value) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: readingController,
                      decoration: _inputDecoration(
                        label: 'Meter / hour reading',
                        hint: 'Example: Start 0001 hr or After 12 hr',
                        icon: Icons.speed_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        label: 'Fuel notes',
                        hint: 'Example: fuel checked after shift was done',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _submitButton(
                      editIndex == null ? 'Add Fuel Record' : 'Save Fuel Record',
                      AppTheme.warning,
                      Icons.save_outlined,
                      () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        final log = MachineFuelLog(
                          id: oldLog?.id ?? 'FUL-USER-${DateTime.now().millisecondsSinceEpoch}',
                          date: selectedDate,
                          type: selectedType,
                          litres: double.tryParse(litreController.text) ?? 0,
                          amount: double.tryParse(amountController.text) ?? 0,
                          meterReading: readingController.text.trim(),
                          notes: notesController.text.trim(),
                        );

                        setState(() {
                          if (editIndex == null) {
                            rental.fuelLogs.insert(0, log);
                          } else {
                            rental.fuelLogs[editIndex] = log;
                          }
                        });
                        widget.onUpdated();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final earned = rental.getEarnedAmount();
    final balance = earned - rental.totalFuelCost - rental.advance;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Machine Rental Details'),
        actions: [
          IconButton(
            onPressed: _showEditLifecycleSheet,
            icon: const Icon(Icons.edit_note_outlined),
            tooltip: 'Edit machine flow',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(balance),
          const SizedBox(height: 16),
          _lifeCycleCard(),
          const SizedBox(height: 16),
          _actionCard(),
          const SizedBox(height: 16),
          _fuelCard(),
          const SizedBox(height: 16),
          _checkInCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _headerCard(double balance) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(rental.machineStatus.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rental.item,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rental.id} • ${rental.tankId}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _whitePill(rental.machineStatus.label, Icons.info_outline),
              _whitePill(rental.siteName, Icons.place_outlined),
              _whitePill(rental.fieldLabel, Icons.agriculture_outlined),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _topMetric('Rate', _formatMoney(rental.rate), Icons.currency_rupee),
              const SizedBox(width: 8),
              _topMetric('Fuel', _formatMoney(rental.totalFuelCost), Icons.local_gas_station_outlined),
              const SizedBox(width: 8),
              _topMetric('Balance', _formatMoney(balance), Icons.account_balance_wallet_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lifeCycleCard() {
    return _sectionCard(
      title: 'Machine Flow',
      subtitle: 'Tank entry, activation, closure, and current status',
      icon: Icons.timeline_outlined,
      color: AppTheme.primary,
      action: OutlinedButton.icon(
        onPressed: _showEditLifecycleSheet,
        icon: const Icon(Icons.edit, size: 16),
        label: const Text('Edit'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: BorderSide(color: AppTheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _miniMetric('Site', rental.siteName)),
              const SizedBox(width: 8),
              Expanded(child: _miniMetric('Tank / Pond', rental.tankId)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniMetric('Field', rental.fieldLabel)),
              const SizedBox(width: 8),
              Expanded(child: _miniMetric('Operator', rental.operatorName)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  'Entered Tank',
                  rental.tankEntryDate == null ? 'Pending' : _formatDate(rental.tankEntryDate!),
                  color: rental.tankEntryDate == null ? AppTheme.warning : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  'Activated',
                  rental.activationDate == null ? 'Not activated' : _formatDate(rental.activationDate!),
                  color: rental.activationDate == null ? AppTheme.warning : AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  'Closed',
                  rental.closingDate == null ? 'Running / open' : _formatDate(rental.closingDate!),
                  color: rental.closingDate == null ? AppTheme.info : AppTheme.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  'Check-ins',
                  rental.dailyCheckIns.length.toString(),
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard() {
    return _sectionCard(
      title: 'Machine Actions',
      subtitle: 'Activate, continue shift, add fuel, or close rental',
      icon: Icons.touch_app_outlined,
      color: AppTheme.success,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: rental.isActivated ? null : _activateMachine,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    disabledBackgroundColor: AppTheme.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: rental.isActivated ? _continueMachine : null,
                  icon: const Icon(Icons.update),
                  label: const Text('Continue'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.success,
                    side: BorderSide(color: rental.isActivated ? AppTheme.success : AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showFuelLogSheet(),
                  icon: const Icon(Icons.local_gas_station_outlined),
                  label: const Text('Add Fuel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    side: BorderSide(color: AppTheme.warning),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _closeMachine,
                  icon: const Icon(Icons.close),
                  label: const Text('Close Rental'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: BorderSide(color: AppTheme.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fuelCard() {
    final logs = [...rental.fuelLogs]..sort((a, b) => b.date.compareTo(a.date));

    return _sectionCard(
      title: 'Machine Fuel Ledger',
      subtitle: 'Activation fuel, running refill, shift-end check, and closing fuel check',
      icon: Icons.local_gas_station_outlined,
      color: AppTheme.warning,
      action: OutlinedButton.icon(
        onPressed: () => _showFuelLogSheet(),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.warning,
          side: BorderSide(color: AppTheme.warning),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: logs.isEmpty
          ? _emptyState(
              icon: Icons.local_gas_station_outlined,
              title: 'No fuel records yet',
              subtitle: 'Add activation fuel or shift-end fuel check for this machine.',
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _miniMetric(
                        'Total Litres',
                        rental.fuelLogLitresTotal.toStringAsFixed(1),
                        color: AppTheme.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniMetric(
                        'Fuel Amount',
                        _formatMoney(rental.totalFuelCost),
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...logs.map((log) {
                  final realIndex = rental.fuelLogs.indexWhere((item) => item.id == log.id);
                  return _fuelLogTile(log, realIndex);
                }),
              ],
            ),
    );
  }

  Widget _fuelLogTile(MachineFuelLog log, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_gas_station_outlined, color: AppTheme.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.type,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _formatDate(log.date),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showFuelLogSheet(editIndex: index),
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppTheme.primary,
              ),
              IconButton(
                onPressed: () {
                  setState(() => rental.fuelLogs.removeAt(index));
                  widget.onUpdated();
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppTheme.danger,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniMetric('Litres', log.litres.toStringAsFixed(1))),
              const SizedBox(width: 8),
              Expanded(child: _miniMetric('Amount', _formatMoney(log.amount), color: AppTheme.warning)),
              const SizedBox(width: 8),
              Expanded(child: _miniMetric('Reading', log.meterReading.isEmpty ? '—' : log.meterReading)),
            ],
          ),
          if (log.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.notes,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _checkInCard() {
    final checks = [...rental.dailyCheckIns]..sort((a, b) => b.date.compareTo(a.date));

    return _sectionCard(
      title: 'Check-in & Continue History',
      subtitle: 'Every continue/verification date for this machine',
      icon: Icons.fact_check_outlined,
      color: AppTheme.info,
      action: OutlinedButton.icon(
        onPressed: rental.isActivated ? _continueMachine : null,
        icon: const Icon(Icons.add_task_outlined, size: 16),
        label: const Text('Continue'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.info,
          side: BorderSide(color: rental.isActivated ? AppTheme.info : AppTheme.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: checks.isEmpty
          ? _emptyState(
              icon: Icons.fact_check_outlined,
              title: 'No check-ins recorded',
              subtitle: 'Activate or continue the machine to create check-in history.',
            )
          : Column(
              children: checks
                  .map(
                    (check) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            check.submitted ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                            color: check.submitted ? AppTheme.success : AppTheme.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(check.date),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  check.note,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
    Widget? action,
  }) {
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, {Color? color}) {
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
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _whitePill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _sheetHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing else const Icon(Icons.edit_calendar_outlined, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _submitButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    const gap = 28.0;

    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
