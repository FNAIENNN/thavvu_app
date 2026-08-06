import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/collapsible_tab_scaffold.dart';
import '../services/attendance_context_service.dart';
import '../services/rental_repository.dart';

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

class RentalLineItem {
  final String name;
  final int quantity;
  final double price;
  final String rentUnit; // 'Per day' or 'Per hour'
  final String equipmentType; // 'Machine Equipment' or 'Work Equipment'
  final String category;

  const RentalLineItem({
    required this.name,
    required this.quantity,
    this.price = 0.0,
    this.rentUnit = 'Per day',
    this.equipmentType = 'Machine Equipment',
    this.category = 'General',
  });

  double amountAt(double rate) => quantity * (price > 0 ? price : rate);
  double get totalPrice => quantity * (price > 0 ? price : 0.0);
}

class RentalPaymentTransaction {
  final String id;
  final String type; // 'cash' | 'advance'
  double amount;
  final String method;
  final DateTime date;
  String status;
  final String? note;
  final String? billImagePath;
  final String? machineId;
  final String? machineName;
  String? paymentProof;
  bool registeredInMachineIdsBook;

  RentalPaymentTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.method,
    required this.date,
    this.status = 'Completed',
    this.note,
    this.billImagePath,
    this.machineId,
    this.machineName,
    this.paymentProof,
    this.registeredInMachineIdsBook = false,
  });
}

class RentalItem {
  final String id;
  final String item;
  final List<RentalLineItem> lineItems;
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
  List<RentalPaymentTransaction> paymentTransactions;
  String? closingProofPath;
  String? openingPhotoPath;
  String? billPhotoPath;
  String siteName;
  String tankId;
  String fieldLabel;
  String operatorName;
  String supplierName;
  String villageName;
  String equipmentType;
  String billingUnit;
  String paymentStatus;

  RentalItem({
    required this.id,
    required this.item,
    List<RentalLineItem>? lineItems,
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
    List<RentalPaymentTransaction>? paymentTransactions,
    this.closingProofPath,
    this.openingPhotoPath,
    this.billPhotoPath,
    this.siteName = 'Site not assigned',
    this.tankId = 'Tank not assigned',
    this.fieldLabel = 'Field not assigned',
    this.operatorName = 'Operator not assigned',
    this.supplierName = 'Direct Supplier',
    this.villageName = 'Local Village',
    this.equipmentType = 'Machine Equipment',
    this.billingUnit = 'Per day',
    this.paymentStatus = 'Paid',
  })  : lineItems = lineItems ?? [RentalLineItem(name: item, quantity: 1)],
        dailyCheckIns = dailyCheckIns ?? [],
        fuelLogs = fuelLogs ?? [],
        paymentTransactions = paymentTransactions ?? [];

  double getEarnedAmount() {
    if (!isActivated || activationDate == null) return 0;
    final endDate = closingDate ?? DateTime.now();
    final days =
        math.max(endDate.difference(activationDate!).inDays, 1).toDouble();
    return days * rate * totalQuantity;
  }

  int get totalQuantity =>
      lineItems.fold(0, (sum, item) => sum + item.quantity);

  double get fuelLogAmountTotal =>
      fuelLogs.fold(0, (sum, log) => sum + log.amount);

  double get fuelLogLitresTotal =>
      fuelLogs.fold(0, (sum, log) => sum + log.litres);

  double get totalFuelCost =>
      fuelLogs.isEmpty ? fuelConsumed : fuelLogAmountTotal;

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
    if (isReturned) return 'Fully Transferred';
    if (isPartial) return 'Partial Transfer';
    return 'Available';
  }
}

class InternalTransferHistoryRecord {
  final String id;
  final DateTime date;
  final String thavvuId; // From Thavvu ID
  final String toThavvuId; // To Thavvu ID
  final String transferType;
  final String itemName;
  final String batchId;
  final String rentalId;
  final int numberOfItems;
  final String transferredTo;
  final String photoPath;
  final String notes;
  final String submittedBy;
  String status; // 'Pending Receive', 'Received', 'Partial', 'Damaged', 'Rejected'
  String? receiverName;
  DateTime? receivedDate;
  String? receiverNotes;
  int? receivedQty;

  InternalTransferHistoryRecord({
    required this.id,
    required this.date,
    required this.thavvuId,
    this.toThavvuId = '',
    required this.transferType,
    required this.itemName,
    required this.batchId,
    required this.rentalId,
    required this.numberOfItems,
    required this.transferredTo,
    this.photoPath = '',
    this.notes = '',
    this.submittedBy = 'Supervisor',
    this.status = 'Pending Receive',
    this.receiverName,
    this.receivedDate,
    this.receiverNotes,
    this.receivedQty,
  });
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


// =========================
// Supplier payment models
// =========================

class SupplierPaymentItem {
  final String id;
  final String supplierName;
  final String transferItemId;
  final String itemName;
  final String batchId;
  final String rentalId;
  final DateTime startDate;
  final int takenQty;
  int closedQty;
  final double ratePerDay;
  String paymentStatus;
  String lastPaymentMethod;

  SupplierPaymentItem({
    required this.id,
    required this.supplierName,
    required this.transferItemId,
    required this.itemName,
    required this.batchId,
    required this.rentalId,
    required this.startDate,
    required this.takenQty,
    this.closedQty = 0,
    required this.ratePerDay,
    this.paymentStatus = 'Open',
    this.lastPaymentMethod = 'Cash',
  });

  int get openQty => math.max(takenQty - closedQty, 0);

  bool get isClosed => openQty == 0;

  bool get isPartial => closedQty > 0 && openQty > 0;

  String get statusLabel {
    if (isClosed) return 'Closed';
    if (isPartial) return 'Partial Open';
    return 'Open';
  }

  double amountFor({
    required int qty,
    required DateTime endDate,
  }) {
    final days = math.max(endDate.difference(startDate).inDays, 1);
    return qty * ratePerDay * days;
  }
}

class SupplierPaymentHistoryRecord {
  final String id;
  final String supplierName;
  final String itemName;
  final String batchId;
  final String rentalId;
  final DateTime startDate;
  final DateTime endDate;
  final int closedQty;
  final int remainingQty;
  final double amount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final String paymentReference;
  final String noteType;
  final String noteDetails;

  const SupplierPaymentHistoryRecord({
    required this.id,
    required this.supplierName,
    required this.itemName,
    required this.batchId,
    required this.rentalId,
    required this.startDate,
    required this.endDate,
    required this.closedQty,
    required this.remainingQty,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.paymentReference = '',
    this.noteType = '',
    this.noteDetails = '',
  });

  int get days => math.max(endDate.difference(startDate).inDays, 1);
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
  bool _isOpening = false;

  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _itemQuantityController =
      TextEditingController(text: '1');
  final TextEditingController _itemPriceController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _villageNameController = TextEditingController();
  String _selectedEquipmentType = 'Machine Equipment';
  String _selectedItemRentUnit = 'Per day';
  String _selectedItemCategory = 'Aeration';
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _fuelController = TextEditingController();
  final TextEditingController _fuelLitresController = TextEditingController();
  final TextEditingController _fuelRemarksController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<RentalLineItem> _draftRentalItems = [];
  bool _rentalFuelEnabled = false;
  bool _enableRentalCashPayment = false;
  bool _enableCashPayment = false;
  String _supplierPaymentNoteType = 'Manual Note';
  final TextEditingController _supplierPaymentNoteController =
      TextEditingController();
  final Set<String> _selectedSupplierPaymentItemIds = <String>{};
  final Map<String, int> _supplierPaymentCloseQtyDraft = <String, int>{};
  final Map<String, Map<String, int>> _pendingSupplierPaymentPlans =
      <String, Map<String, int>>{};
  final Map<String, DateTime> _pendingSupplierPaymentPlanEndDates =
      <String, DateTime>{};
  final Map<String, String> _pendingSupplierPaymentPlanNoteTypes =
      <String, String>{};
  final Map<String, String> _pendingSupplierPaymentPlanNotes =
      <String, String>{};
  Map<String, int> _activeSupplierPaymentPlanQtyById = <String, int>{};
  DateTime? _activeSupplierPaymentPlanEndDate;
  String _activeSupplierPaymentPlanNoteType = 'Manual Note';
  String _activeSupplierPaymentPlanNote = '';
  String _rentalFuelType = 'Diesel';
  String _rentalFuelStockPoint = 'Main Diesel Stock';
  String? _rentalOpeningPhotoPath;
  String? _rentalBillPhotoPath;
  final List<RentalPaymentTransaction> _rentalPaymentLedger = [];

  // ── Supabase backend integration ──────────────────────────────
  final RentalRepository _rentalRepo = RentalRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  RealtimeChannel? _rentalChannel;
  String _rentalSiteId = 'SITE-VJA-001';

  // New advance payment state
  bool _enableAdvancePayment = false;
  String? _selectedAdvanceMode; // 'upi' or 'bank'
  String? _selectedEntryMethod; // 'manual', 'photo', 'voice'
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _advanceAmountController = TextEditingController();
  final double _cashBalance = 50000;
  final double _cashLimit = 25000;

  // Account management
  final List<Map<String, dynamic>> _savedAccounts = [
    {
      'id': 'acc1',
      'upiId': 'aqua.supervisor@okhdfcbank',
      'bankName': 'HDFC Bank',
      'type': 'primary',
    },
    {
      'id': 'acc2',
      'upiId': 'pond.manager@ybl',
      'bankName': 'Yes Bank',
      'type': 'secondary',
    },
  ];
  String? _selectedPaymentAccount;

  final List<Map<String, dynamic>> _savedBankAccounts = [
    {
      'id': 'bank1',
      'bankName': 'State Bank of India',
      'accountNumber': '****1234',
      'ifsc': 'SBIN0001234',
      'holderName': 'Aqua Farm Supervisor',
      'type': 'primary',
    },
  ];
  String? _selectedBankAccount;
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _accNumController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();

  final List<AquaRentalTool> _aquaToolCatalog = [];
  String? _selectedAquaToolId;

  List<RentalItem> _activeRentals = [];
  List<Map<String, dynamic>> _closedRentals = [];

  List<InternalTransferItem> _transferItems = [];
  InternalTransferItem? _selectedTransferItem;
  String? _selectedTransferThavvuId; // From Thavvu ID
  String? _toTransferThavvuId; // To Thavvu ID
  String? _selectedTransferTankId;
  final Set<String> _selectedMachineTransferRentalIds = <String>{};
  final Set<String> _confirmedMachineTransferRentalIds = <String>{};
  String? _machineTransferPhotoPath;
  final Map<String, int> _machineTransferQuantityDraft = <String, int>{};

  String? _selectedWorkEquipmentBatchId;
  String? _selectedWorkEquipmentItemId;
  String? _workEquipmentPhotoPath;
  DateTime? _internalTransferHistoryDateFilter;
  final TextEditingController _workEquipmentQtyController =
      TextEditingController(text: '1');
  final TextEditingController _workEquipmentNotesController =
      TextEditingController();
  final TextEditingController _transferReceiverController =
      TextEditingController(text: 'Supervisor / Department');
  final List<InternalTransferHistoryRecord> _internalTransferHistory = [];

  final List<VehicleCatalogItem> _vehicleCatalog = [];
  late final Map<VehicleBillingType, TextEditingController>
      _vehicleUsageControllers;
  final Map<VehicleBillingType, VehicleCatalogItem?> _selectedVehicles = {};
  final Map<VehicleBillingType, String?> _selectedVehicleThavvuIds = {};
  final List<VehicleRentalEntry> _vehicleEntries = [];


  final List<SupplierPaymentItem> _supplierPaymentItems = [];
  final List<SupplierPaymentHistoryRecord> _supplierPaymentHistory = [];
  String? _selectedPaymentSupplier;
  String _paymentView = 'Open';

  // Supervisor reports filters — adapted from the React Reports pattern.
  DateTime? _reportFromDateFilter;
  DateTime? _reportToDateFilter;
  String? _reportSupplierFilter;
  String _reportSearch = '';
  final TextEditingController _reportSearchController = TextEditingController();

  // ---------- NEW: Custom supplier names ----------
  List<String> _customSupplierNames = [];
  final TextEditingController _newSupplierController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _vehicleUsageControllers = {
      for (final type in VehicleBillingType.values)
        type: TextEditingController(text: _defaultVehicleUsage(type)),
    };
    _loadMockData();
    _seedSupplierPaymentItems();
    _seedVehicleSelections();
    _newSupplierController.addListener(() { /* optional */ });
    _initRentalBackend();
  }

  Future<void> _initRentalBackend() async {
    final siteId = await _contextService.resolveSiteId();
    if (!mounted) return;
    _rentalSiteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
    _rentalChannel = _rentalRepo.watchAll(_rentalSiteId, _loadRentalData);
    await _loadRentalData();
  }

  Future<void> _loadRentalData() async {
    await _loadRentalEntries();
    await _loadRentalPayments();
    await _loadRentalTransfers();
  }

  /// Merges backend rental transfers into the local transfer history so the
  /// History tab shows persisted transfers after restart.
  Future<void> _loadRentalTransfers() async {
    try {
      final transfers = await _rentalRepo.fetchTransfers(siteId: _rentalSiteId);
      if (!mounted) return;
      setState(() {
        for (final t in transfers) {
          final exists =
              _internalTransferHistory.any((h) => h.id == 'ITR-${t.id}');
          if (exists) continue;
          _internalTransferHistory.insert(
            0,
            InternalTransferHistoryRecord(
              id: 'ITR-${t.id}',
              date: t.workDate,
              thavvuId: t.fromThavvuId ?? '',
              toThavvuId: t.toThavvuId ?? '',
              transferType: t.assetKind == 'workEquipment'
                  ? 'Work Equipment'
                  : 'Machine',
              itemName: t.itemName,
              batchId: '',
              rentalId: t.transferNo,
              numberOfItems: 1,
              transferredTo: t.driver ?? 'Supervisor / Department',
              photoPath: t.photoPath ?? '',
              notes: t.notes ?? '',
            ),
          );
        }
      });
    } catch (_) {
      // Best-effort; local history still works.
    }
  }

  Future<void> _loadRentalPayments() async {
    try {
      final payments = await _rentalRepo.fetchPayments(siteId: _rentalSiteId);
      if (!mounted) return;
      setState(() {
        for (final payment in payments) {
          final exists = _rentalPaymentLedger
              .any((txn) => txn.id == 'PAY-${payment.id}');
          if (exists) continue;
          _rentalPaymentLedger.insert(
            0,
            RentalPaymentTransaction(
              id: 'PAY-${payment.id}',
              type: payment.mode == 'cash' ? 'cash' : 'advance',
              amount: payment.amount,
              method: payment.mode,
              date: DateTime.now(),
              status: payment.status == 'paid' ? 'Completed' : 'Pending Review',
              note: payment.note ?? 'Rental payment',
              machineId: '',
              machineName: payment.supplierName,
            ),
          );
        }
      });
    } catch (_) {
      // Payments are best-effort; local ledger still works.
    }
  }

  Future<void> _loadRentalEntries() async {
    try {
      final entries = await _rentalRepo.fetchEntries(siteId: _rentalSiteId);
      if (!mounted) return;
      setState(() {
        for (final entry in entries) {
          final exists = _activeRentals.any(
              (rental) => rental.id == 'ENT-${entry.entryNo}');
          if (exists) continue;
          _activeRentals.insert(
            0,
            RentalItem(
              id: 'ENT-${entry.entryNo}',
              item: entry.vehicleName,
              lineItems: [
                RentalLineItem(
                    name: entry.vehicleName,
                    quantity: entry.units.round(),
                    price: entry.rate,
                    rentUnit: entry.billingType),
              ],
              startDate: entry.workDate,
              rate: entry.rate,
              advance: 0,
              fuelConsumed: entry.fuelCost,
              notes: entry.notes ?? '',
              openingPhotoPath: entry.openingPhotoPath,
              billPhotoPath: entry.billPhotoPath,
              siteName: 'Rental backend entry',
              tankId: entry.tankId ?? 'Tank / pond pending',
              fieldLabel: entry.fromLocation ?? '',
              operatorName: entry.driver ?? '',
              supplierName: 'Direct Supplier',
              villageName: 'Local Village',
              equipmentType: 'Machine Equipment',
              billingUnit: entry.billingType,
              paymentStatus: entry.status == 'approved'
                  ? 'Approved'
                  : (entry.status == 'rejected'
                      ? 'Rejected'
                      : 'Pending Review'),
              isActivated: true,
              activationDate: entry.workDate,
              tankEntryDate: entry.workDate,
            ),
          );
        }
      });
    } catch (_) {
      // Backend is best-effort; local seed data still works.
    }
  }

  @override
  void dispose() {
    _rentalRepo.stopWatching(_rentalChannel);
    _tabController.dispose();
    _itemController.dispose();
    _itemQuantityController.dispose();
    _itemPriceController.dispose();
    _supplierNameController.dispose();
    _villageNameController.dispose();
    _rateController.dispose();
    _fuelController.dispose();
    _fuelLitresController.dispose();
    _fuelRemarksController.dispose();
    _notesController.dispose();
    _cashAmountController.dispose();
    _advanceAmountController.dispose();
    _supplierPaymentNoteController.dispose();
    _ifscController.dispose();
    _accNumController.dispose();
    _bankNameController.dispose();
    _workEquipmentQtyController.dispose();
    _workEquipmentNotesController.dispose();
    _transferReceiverController.dispose();
    _reportSearchController.dispose();
    _newSupplierController.dispose();
    for (final controller in _vehicleUsageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // =========================
  // Mock data (unchanged)
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
          DailyCheckIn(
              date: DateTime(2026, 5, 21),
              note: 'Machine entered Tank 11 and activated.'),
          DailyCheckIn(
              date: DateTime(2026, 5, 22), note: 'Aerator running normally.'),
          DailyCheckIn(
              date: DateTime(2026, 5, 23), note: 'Morning shift completed.'),
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
          DailyCheckIn(
              date: DateTime(2026, 5, 26),
              note: 'Pump installed near exchange bay.'),
          DailyCheckIn(
              date: DateTime(2026, 5, 27), note: 'Second shift continued.'),
          DailyCheckIn(
              date: DateTime(2026, 5, 28), note: 'Outlet line checked.'),
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
          DailyCheckIn(
              date: DateTime(2026, 5, 29),
              note: 'Net issued for harvest trial.'),
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

    _internalTransferHistory.addAll([
      InternalTransferHistoryRecord(
        id: 'ITH-REC-2026-001',
        date: DateTime.now().subtract(const Duration(hours: 3)),
        thavvuId: 'THV-BVRM-01',
        toThavvuId: 'THV-KRS-09',
        transferType: 'Machine Equipment',
        itemName: '2 HP Paddle Wheel Aerator',
        batchId: 'BATCH-REC-101',
        rentalId: 'RNT-AP-2026-0034',
        numberOfItems: 2,
        transferredTo: 'Current Supervisor',
        submittedBy: 'Supervisor Suresh Kumar',
        photoPath: 'transfer_aerator_001.jpg',
        notes: 'Transferred 2 aerator units for pond 9 oxygen support. Checked and operational.',
        status: 'Pending Receive',
      ),
      InternalTransferHistoryRecord(
        id: 'ITH-REC-2026-002',
        date: DateTime.now().subtract(const Duration(days: 1)),
        thavvuId: 'THV-WG-03',
        toThavvuId: 'THV-KRS-09',
        transferType: 'Work Equipment',
        itemName: 'HDPE Aerator Float Set & PVC Hoses',
        batchId: 'WE-BATCH-202',
        rentalId: 'RNT-AP-2026-0035',
        numberOfItems: 8,
        transferredTo: 'Current Supervisor',
        submittedBy: 'Supervisor Ramesh V.',
        photoPath: 'transfer_floats_002.jpg',
        notes: 'Float sets & hose bundle transferred after harvest completion.',
        status: 'Pending Receive',
      ),
      InternalTransferHistoryRecord(
        id: 'ITH-REC-2026-003',
        date: DateTime.now().subtract(const Duration(days: 2)),
        thavvuId: 'THV-KRS-02',
        toThavvuId: 'THV-KRS-09',
        transferType: 'Machine Equipment',
        itemName: 'Diesel Water Pump 5 HP',
        batchId: 'BATCH-REC-103',
        rentalId: 'RNT-AP-2026-0036',
        numberOfItems: 1,
        transferredTo: 'Current Supervisor',
        submittedBy: 'Supervisor Mahesh',
        photoPath: 'transfer_pump_003.jpg',
        notes: 'High volume pump transferred for pond filling cycle.',
        status: 'Received',
        receiverName: 'Supervisor (You)',
        receivedDate: DateTime.now().subtract(const Duration(days: 1)),
        receivedQty: 1,
        receiverNotes: 'Received in excellent working condition. Deployed at Intake Bay.',
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
  // Supplier payment helpers
  // =========================

  void _seedSupplierPaymentItems() {
    _supplierPaymentItems
      ..clear()
      ..addAll(_transferItems.map(_paymentItemFromTransferItem));
    if (_supplierPaymentItems.isNotEmpty) {
      _selectedPaymentSupplier = _supplierPaymentItems.first.supplierName;
    }
  }

  SupplierPaymentItem _paymentItemFromTransferItem(InternalTransferItem item) {
    final now = DateTime.now();
    final ageDays = 3 + (item.id.hashCode.abs() % 18);
    final baseRate = item.kind == TransferAssetKind.material ? 35.0 : 650.0;
    final rateBump = (item.name.hashCode.abs() % 9) * 25.0;
    return SupplierPaymentItem(
      id: 'SPP-${item.id}',
      supplierName: _supplierNameForTransferItem(item),
      transferItemId: item.id,
      itemName: item.name,
      batchId: item.batchId,
      rentalId: item.rentalId,
      startDate: now.subtract(Duration(days: ageDays)),
      takenQty: item.rentedQty,
      closedQty: item.returnedQty,
      ratePerDay: baseRate + rateBump,
      paymentStatus: item.isReturned ? 'Closed' : 'Open',
    );
  }

  String _supplierNameForTransferItem(InternalTransferItem item) {
    final materialSuppliers = [
      'Godavari Aqua Materials',
      'Sri Lakshmi Farm Supplies',
      'Coastal Stock Traders',
    ];
    final equipmentSuppliers = [
      'Bhimavaram Machine Rentals',
      'Delta Work Equipment',
      'AP Aqua Tools & Motors',
    ];
    final source = item.kind == TransferAssetKind.material
        ? materialSuppliers
        : equipmentSuppliers;
    return source[item.id.hashCode.abs() % source.length];
  }

  void _addSupplierPaymentItemForTransfer(InternalTransferItem item) {
    final existingIndex = _supplierPaymentItems.indexWhere(
      (paymentItem) => paymentItem.transferItemId == item.id,
    );
    final paymentItem = _paymentItemFromTransferItem(item);
    if (existingIndex == -1) {
      _supplierPaymentItems.insert(0, paymentItem);
    } else {
      _supplierPaymentItems[existingIndex] = paymentItem;
    }
    _selectedPaymentSupplier ??= paymentItem.supplierName;
  }

  void _syncSupplierPaymentFromTransfer(InternalTransferItem item) {
    final index = _supplierPaymentItems.indexWhere(
      (paymentItem) => paymentItem.transferItemId == item.id,
    );
    if (index == -1) {
      _addSupplierPaymentItemForTransfer(item);
      return;
    }
    final paymentItem = _supplierPaymentItems[index];
    paymentItem.closedQty = item.returnedQty.clamp(0, item.rentedQty);
    paymentItem.paymentStatus = paymentItem.isClosed ? 'Closed' : 'Open';
  }

  // ---------- UPDATED: combine payment items and custom names ----------
  List<String> get _supplierNames {
    final names = <String>{
      ..._supplierPaymentItems.map((item) => item.supplierName),
      ..._customSupplierNames,
    }.where((name) => name.trim().isNotEmpty).toList()
      ..sort();
    return names;
  }

  // ---------- NEW: Add custom supplier ----------
  void _addCustomSupplier(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _customSupplierNames.add(trimmed);
      // Automatically select the newly added supplier
      _selectedPaymentSupplier = trimmed;
    });
    _newSupplierController.clear();
  }

  List<SupplierPaymentItem> get _visibleSupplierPaymentItems {
    final supplier = _selectedPaymentSupplier;
    if (supplier == null || supplier.isEmpty) return _supplierPaymentItems;
    return _supplierPaymentItems
        .where((item) => item.supplierName == supplier)
        .toList()
      ..sort((a, b) {
        final statusCompare = a.statusLabel.compareTo(b.statusLabel);
        if (statusCompare != 0) return statusCompare;
        return a.itemName.compareTo(b.itemName);
      });
  }

  Color _paymentStatusColor(SupplierPaymentItem item) {
    if (item.isClosed) return AppTheme.success;
    if (item.isPartial) return AppTheme.warning;
    return AppTheme.info;
  }

  Color _paymentStatusBg(SupplierPaymentItem item) {
    if (item.isClosed) return AppTheme.successBg;
    if (item.isPartial) return AppTheme.warningBg;
    return AppTheme.info.withOpacity(0.10);
  }

  double get _supplierPaymentOpenAmount {
    final now = DateTime.now();
    return _visibleSupplierPaymentItems.fold<double>(
      0,
      (sum, item) => sum + item.amountFor(qty: item.openQty, endDate: now),
    );
  }

  int get _supplierOpenItemCount =>
      _visibleSupplierPaymentItems.where((item) => !item.isClosed).length;

  int get _supplierClosedItemCount =>
      _visibleSupplierPaymentItems.where((item) => item.isClosed).length;

  bool get _hasActiveSupplierPaymentPlan =>
      _activeSupplierPaymentPlanQtyById.isNotEmpty;

  List<SupplierPaymentItem> get _selectedSupplierPaymentItems {
    final itemsById = {
      for (final item in _visibleSupplierPaymentItems) item.id: item,
    };
    return _selectedSupplierPaymentItemIds
        .where((id) => itemsById.containsKey(id))
        .map((id) => itemsById[id]!)
        .where((item) => !item.isClosed)
        .toList();
  }

  int _draftCloseQtyForSupplierItem(SupplierPaymentItem item) {
    final draft = _supplierPaymentCloseQtyDraft[item.id] ?? item.openQty;
    return draft.clamp(1, item.openQty).toInt();
  }

  double get _supplierPaymentPlanAmount {
    return _selectedSupplierPaymentItems.fold<double>(0, (sum, item) {
      final qty = _draftCloseQtyForSupplierItem(item);
      return sum + item.amountFor(qty: qty, endDate: DateTime.now());
    });
  }

  int get _supplierPaymentPlanQuantity => _selectedSupplierPaymentItems.fold<int>(
      0, (sum, item) => sum + _draftCloseQtyForSupplierItem(item));

  void _clearActiveSupplierPaymentPlan() {
    _activeSupplierPaymentPlanQtyById = <String, int>{};
    _activeSupplierPaymentPlanEndDate = null;
    _activeSupplierPaymentPlanNoteType = 'Manual Note';
    _activeSupplierPaymentPlanNote = '';
  }

  void _clearSupplierPaymentSelection() {
    _selectedSupplierPaymentItemIds.clear();
    _supplierPaymentCloseQtyDraft.clear();
    _supplierPaymentNoteController.clear();
    _supplierPaymentNoteType = 'Manual Note';
  }

  // =========================
  // Business helpers (unchanged)
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


  int get _totalTransferRented =>
      _transferItems.fold(0, (sum, item) => sum + item.rentedQty);

  int get _totalTransferReturned =>
      _transferItems.fold(0, (sum, item) => sum + item.returnedQty);

  int get _totalTransferRemaining =>
      _transferItems.fold(0, (sum, item) => sum + item.remainingQty);

  double _vehicleAmount(VehicleBillingType type) {
    final selected = _selectedVehicles[type];
    if (selected == null) return 0;
    final units =
        double.tryParse(_vehicleUsageControllers[type]?.text ?? '0') ?? 0;
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
    return _vehicleEntries.where((entry) => entry.billingType == type).toList()
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

  int get _vehicleBillingPendingCount => _vehicleEntries
      .where((entry) => entry.status == 'Billing Pending')
      .length;

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

    final lineItems = _currentDraftRentalItems();
    if (lineItems.isEmpty) {
      _showSnackbar(
          'Add at least one rental item with quantity.', AppTheme.warning);
      return;
    }

    if (_rentalFuelEnabled) {
      final amount = double.tryParse(_fuelController.text.trim()) ?? 0;
      final litres = double.tryParse(_fuelLitresController.text.trim()) ?? 0;
      if (amount <= 0 && litres <= 0) {
        _showSnackbar(
            'Enter fuel litres or amount, or turn fuel off.', AppTheme.warning);
        return;
      }
    }

    final cashAmount = _enableRentalCashPayment
        ? (double.tryParse(_cashAmountController.text) ?? 0)
        : 0.0;
    final requestAmount = _enableAdvancePayment
        ? (double.tryParse(_advanceAmountController.text) ?? 0)
        : 0.0;

    if (_enableRentalCashPayment) {
      if (cashAmount <= 0 ||
          cashAmount > _cashLimit ||
          cashAmount > _cashBalance) {
        _showSnackbar('Enter valid rental cash payment within HOD limit.',
            AppTheme.warning);
        return;
      }
    }

    if (_enableAdvancePayment) {
      if (requestAmount <= 0 || _selectedAdvanceMode == null) {
        _showSnackbar('Enter advance request amount and payment method.',
            AppTheme.warning);
        return;
      }
      if (_selectedAdvanceMode == 'bank' && _selectedEntryMethod == null) {
        _showSnackbar('Select bank request entry method.', AppTheme.warning);
        return;
      }
    }

    setState(() => _isOpening = true);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final now = DateTime.now();
      final itemLabel = lineItems.length == 1
          ? lineItems.first.name
          : '${lineItems.length} rental items';
      final fuelAmount = _rentalFuelEnabled
          ? (double.tryParse(_fuelController.text.trim()) ?? 0)
          : 0.0;
      final fuelLitres = _rentalFuelEnabled
          ? (double.tryParse(_fuelLitresController.text.trim()) ?? 0)
          : 0.0;
      final advance = cashAmount + requestAmount;
      final paymentTransactions = <RentalPaymentTransaction>[
        if (cashAmount > 0)
          RentalPaymentTransaction(
            id: 'RCP-${now.millisecondsSinceEpoch}',
            type: 'cash',
            amount: cashAmount,
            method: 'Cash Payment',
            date: now,
            note: 'Rental cash payment completed',
            billImagePath: _rentalBillPhotoPath,
            machineId: 'RNT-${now.millisecondsSinceEpoch}',
            machineName: itemLabel,
          ),
        if (requestAmount > 0)
          RentalPaymentTransaction(
            id: 'RRP-${now.millisecondsSinceEpoch}',
            type: 'advance',
            amount: requestAmount,
            method: _selectedAdvanceMode == 'upi' ? 'UPI' : 'Bank Transfer',
            date: now,
            status: 'Requested',
            note: 'Rental advance request submitted',
            billImagePath: _rentalBillPhotoPath,
            machineId: 'RNT-${now.millisecondsSinceEpoch}',
            machineName: itemLabel,
          ),
      ];

      final supplierNameInput = _supplierNameController.text.trim();
      final villageNameInput = _villageNameController.text.trim();
      final calculatedTotalRate = lineItems.fold<double>(
        0.0,
        (sum, item) => sum + (item.price > 0 ? item.price * item.quantity : 0.0),
      );
      final finalRate = calculatedTotalRate > 0
          ? calculatedTotalRate
          : (double.tryParse(_rateController.text) ?? 0.0);

      final newRental = RentalItem(
        id: 'RNT-${now.millisecondsSinceEpoch}',
        item: itemLabel,
        lineItems: lineItems,
        startDate: now,
        rate: finalRate,
        advance: advance,
        fuelConsumed: fuelAmount,
        notes: _notesController.text.trim(),
        openingPhotoPath: _rentalOpeningPhotoPath,
        billPhotoPath: _rentalBillPhotoPath,
        siteName: _selectedAquaTool?.district == null
            ? 'Aqua site not assigned'
            : '${_selectedAquaTool!.district} Aqua Site',
        tankId: 'Tank / pond pending',
        fieldLabel: 'Field pending',
        operatorName: 'Operator pending',
        supplierName:
            supplierNameInput.isNotEmpty ? supplierNameInput : 'Direct Supplier',
        villageName:
            villageNameInput.isNotEmpty ? villageNameInput : 'Local Village',
        equipmentType: _selectedEquipmentType,
        billingUnit: _selectedItemRentUnit,
        paymentStatus: advance > 0 ? 'Advance Paid' : 'Pending Payment',
        tankEntryDate: now,
        // Activate immediately — days auto-count from the moment machine enters field/tank
        isActivated: true,
        activationDate: now,
        fuelLogs: _rentalFuelEnabled
            ? [
                MachineFuelLog(
                  id: 'FUL-OPEN-${now.millisecondsSinceEpoch}',
                  date: now,
                  type: 'Opening ${_rentalFuelType.toLowerCase()}',
                  litres: fuelLitres,
                  amount: fuelAmount,
                  meterReading: _rentalFuelStockPoint,
                  notes: _fuelRemarksController.text.trim(),
                ),
              ]
            : [],
        paymentTransactions: paymentTransactions,
      );

      setState(() {
        _activeRentals.insert(0, newRental);
        // Advance & payment data always visible in Payments ledger
        _rentalPaymentLedger.insertAll(0, paymentTransactions);
        _isOpening = false;
      });

      _showSnackbar(
        '✅ $itemLabel added to Active Rentals. Days counting from today.',
        AppTheme.success,
      );
      unawaited(_persistRentalEntry(
        entry: newRental,
        fuelLitres: fuelLitres,
        fuelAmount: fuelAmount,
      ));
      _clearOpenForm();
      // Navigate to Active Rentals tab (index 1)
      _tabController.animateTo(1);
    });
  }

  Future<void> _persistRentalEntry({
    required RentalItem entry,
    required double fuelLitres,
    required double fuelAmount,
  }) async {
    try {
      final billing = entry.billingUnit.toLowerCase().contains('hour')
          ? 'HOUR'
          : (entry.billingUnit.toLowerCase().contains('week')
              ? 'WEEKLY'
              : 'DAY');
      final fuelLines = <RentalFuelLine>[
        if (fuelLitres > 0 || fuelAmount > 0)
          RentalFuelLine(
            id: '',
            entryId: '',
            fuelType: _rentalFuelType,
            stockPoint: _rentalFuelStockPoint,
            liters: fuelLitres,
            amount: fuelAmount,
            remarks: _fuelRemarksController.text.trim(),
          ),
      ];
      final saved = await _rentalRepo.createEntry(
        siteId: _rentalSiteId,
        entryNo: 'RTL-${DateTime.now().millisecondsSinceEpoch}',
        vehicleName: entry.item,
        billingType: billing,
        tankId: entry.tankId,
        fromLocation: entry.fieldLabel,
        driver: entry.operatorName,
        workDate: DateTime.now(),
        units:
            entry.lineItems.fold<double>(0, (sum, item) => sum + item.quantity),
        rate: entry.rate,
        fuelCost: fuelAmount,
        driverBata: 0,
        loadingCharge: 0,
        openingPhotoPath: entry.openingPhotoPath,
        billPhotoPath: entry.billPhotoPath,
        notes: entry.notes,
        fuelLines: fuelLines,
        thavvuPointId: await _contextService.resolvePointId(),
      );
      if (!mounted) return;
      _loadRentalEntries();
      if (saved.id.isNotEmpty) {
        _showSnackbar('Rental synced to server for HOD review.',
            AppTheme.success);
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackbar('Rental saved locally; server sync pending: $error',
          AppTheme.warning);
    }
  }

  Future<void> _persistRentalPayment({
    required String supplierName,
    required double amount,
    required String mode,
    String? note,
  }) async {
    try {
      final saved = await _rentalRepo.createPayment(
        siteId: _rentalSiteId,
        supplierName: supplierName,
        amount: amount,
        mode: mode,
        note: note,
      );
      if (!mounted) return;
      _loadRentalPayments();
      if (saved.id.isNotEmpty) {
        _showSnackbar('Payment synced to server for HOD review.',
            AppTheme.success);
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackbar('Payment saved locally; server sync pending: $error',
          AppTheme.warning);
    }
  }

  Future<void> _persistRentalReturn(RentalItem rental) async {
    try {
      await _rentalRepo.createReturn(
        siteId: _rentalSiteId,
        returnNo: 'RET-${DateTime.now().millisecondsSinceEpoch}',
        itemName: rental.item,
        workDate: DateTime.now(),
        quantity: rental.lineItems
            .fold<double>(0, (sum, item) => sum + item.quantity),
        reason: 'Closed rental / returned by supervisor',
        photoPath: rental.closingProofPath,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackbar('Return saved locally; server sync pending: $error',
          AppTheme.warning);
    }
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
      _showSnackbar('Activate the machine before continuing the shift.',
          AppTheme.warning);
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

    unawaited(_persistRentalReturn(rental));

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


  void _clearOpenForm() {
    _itemController.clear();
    _itemQuantityController.text = '1';
    _itemPriceController.clear();
    _supplierNameController.clear();
    _villageNameController.clear();
    _rateController.clear();
    _fuelController.clear();
    _fuelLitresController.clear();
    _fuelRemarksController.clear();
    _notesController.clear();
    _cashAmountController.clear();
    _advanceAmountController.clear();
    _draftRentalItems.clear();
    _billingMode = 'Per day';
    _selectedEquipmentType = 'Machine Equipment';
    _selectedItemRentUnit = 'Per day';
    _enableRentalCashPayment = false;
    _enableCashPayment = false;
    _enableAdvancePayment = false;
    _selectedAdvanceMode = null;
    _selectedEntryMethod = null;
    _selectedPaymentAccount = null;
    _selectedBankAccount = null;
    _ifscController.clear();
    _accNumController.clear();
    _bankNameController.clear();
    _rentalFuelEnabled = false;
    _rentalFuelType = 'Diesel';
    _rentalFuelStockPoint = 'Main Diesel Stock';
    _rentalOpeningPhotoPath = null;
    _rentalBillPhotoPath = null;
    _selectedAquaToolId = null;
    _openRentalFormKey.currentState?.reset();
  }

  List<RentalLineItem> _currentDraftRentalItems() {
    final items = List<RentalLineItem>.from(_draftRentalItems);
    final typedName = _itemController.text.trim();
    final typedQuantity =
        int.tryParse(_itemQuantityController.text.trim()) ?? 0;
    final typedPrice =
        double.tryParse(_itemPriceController.text.trim()) ?? 0.0;
    if (typedName.isNotEmpty && typedQuantity > 0) {
      final existingIndex = items.indexWhere(
        (item) => item.name.toLowerCase() == typedName.toLowerCase(),
      );
      if (existingIndex == -1) {
        items.add(
          RentalLineItem(
            name: typedName,
            quantity: typedQuantity,
            price: typedPrice,
            rentUnit: _selectedItemRentUnit,
            equipmentType: _selectedEquipmentType,
            category: _selectedItemCategory,
          ),
        );
      }
    }
    return items;
  }

  void _addDraftRentalItem() {
    final name = _itemController.text.trim();
    final quantity = int.tryParse(_itemQuantityController.text.trim()) ?? 0;
    final price = double.tryParse(_itemPriceController.text.trim()) ?? 0.0;
    if (name.isEmpty || quantity <= 0) {
      _showSnackbar('Enter item name and quantity.', AppTheme.warning);
      return;
    }
    setState(() {
      final existingIndex = _draftRentalItems.indexWhere(
        (item) =>
            item.name.toLowerCase() == name.toLowerCase() &&
            item.equipmentType == _selectedEquipmentType,
      );
      if (existingIndex == -1) {
        _draftRentalItems.add(
          RentalLineItem(
            name: name,
            quantity: quantity,
            price: price,
            rentUnit: _selectedItemRentUnit,
            equipmentType: _selectedEquipmentType,
            category: _selectedItemCategory,
          ),
        );
      } else {
        final existing = _draftRentalItems[existingIndex];
        _draftRentalItems[existingIndex] = RentalLineItem(
          name: existing.name,
          quantity: existing.quantity + quantity,
          price: price > 0 ? price : existing.price,
          rentUnit: _selectedItemRentUnit,
          equipmentType: _selectedEquipmentType,
          category: _selectedItemCategory,
        );
      }
      _itemController.clear();
      _itemQuantityController.text = '1';
      _itemPriceController.clear();
    });
  }

  void _removeDraftRentalItem(RentalLineItem item) {
    setState(() => _draftRentalItems.remove(item));
  }

  Future<void> _toggleRentalUpload(String type) async {
    final picker = ImagePicker();
    final XFile? shot;
    try {
      shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
    } catch (_) {
      _showSnackbar('Camera is unavailable.', AppTheme.danger);
      return;
    }
    if (shot == null) return;

    final bytes = await shot.readAsBytes();
    final ext = shot.name.contains('.')
        ? shot.name.split('.').last.toLowerCase()
        : 'jpg';
    final context = type == 'opening_photo' ? 'opening' : 'bill';
    final path = await _rentalRepo.uploadPhoto(
        bytes: bytes, extension: ext, context: context);
    if (!mounted) return;
    setState(() {
      if (type == 'opening_photo') {
        _rentalOpeningPhotoPath = path;
      } else {
        _rentalBillPhotoPath = path;
      }
    });
    _showSnackbar(
      path != null
          ? (type == 'opening_photo'
              ? 'Opening photo captured & uploaded'
              : 'Bill photo captured & uploaded')
          : 'Photo upload failed',
      path != null ? AppTheme.success : AppTheme.danger,
    );
  }

  // =========================
  // Internal transfer actions (unchanged)
  // =========================

  void _selectTransferItem(
    InternalTransferItem item, {
    bool showSnack = true,
  }) {
    setState(() {
      _selectedTransferItem = item;
      _selectedTransferThavvuId = _firstId(item.thavvuIds);
      _selectedTransferTankId = _firstId(item.tankIds);
      if (item.kind == TransferAssetKind.workEquipment) {
        _selectedWorkEquipmentBatchId = item.batchId;
        _selectedWorkEquipmentItemId = item.id;
      }
    });

    if (showSnack) {
      _showSnackbar(
        '${item.name} selected. Thavvu ID loaded first for transfer.',
        AppTheme.info,
      );
    }
  }

  List<String> get _allInternalTransferThavvuIds {
    final ids = <String>{};

    for (final item in _transferItems) {
      ids.addAll(item.thavvuIds.where((id) => id.trim().isNotEmpty));
    }

    for (final vehicle in _vehicleCatalog) {
      ids.addAll(vehicle.thavvuIds.where((id) => id.trim().isNotEmpty));
    }

    for (final rental in _activeRentals) {
      if (rental.id.trim().isNotEmpty) {
        ids.add('THV-${rental.id}');
      }
      if (rental.tankId.trim().isNotEmpty) {
        ids.add('THV-${rental.tankId}');
      }
    }

    final sorted = ids.toList()..sort();
    return sorted;
  }

  void _selectPriorityThavvu(String? thavvuId) {
    setState(() {
      _selectedTransferThavvuId = thavvuId;

      final allIds = _allInternalTransferThavvuIds;
      if (_toTransferThavvuId == null ||
          _toTransferThavvuId == thavvuId ||
          !allIds.contains(_toTransferThavvuId)) {
        final targetOptions = allIds.where((id) => id != thavvuId).toList();
        _toTransferThavvuId =
            targetOptions.isEmpty ? null : targetOptions.first;
      }

      final matching = _transferItems.where((item) {
        if (thavvuId == null) return false;
        return item.thavvuIds.contains(thavvuId);
      }).toList();

      if (matching.isNotEmpty) {
        _selectedTransferItem = matching.first;
        _selectedTransferTankId = _firstId(matching.first.tankIds);
      } else {
        _selectedTransferItem = null;
        _selectedTransferTankId = null;
      }

      final weMatch = matching
          .where((item) => item.kind == TransferAssetKind.workEquipment)
          .toList();

      if (weMatch.isNotEmpty) {
        _selectedWorkEquipmentBatchId = weMatch.first.batchId;
        _selectedWorkEquipmentItemId = weMatch.first.id;
      } else {
        _selectedWorkEquipmentBatchId = null;
        _selectedWorkEquipmentItemId = null;
      }
    });
  }

  void _selectToTransferThavvu(String? thavvuId) {
    if (thavvuId != null && thavvuId == _selectedTransferThavvuId) {
      _showSnackbar(
        'From Thavvu ID and To Thavvu ID cannot be the same.',
        AppTheme.warning,
      );
      return;
    }
    setState(() => _toTransferThavvuId = thavvuId);
  }

  List<InternalTransferItem> _transferItemsForKindByThavvu(
    TransferAssetKind kind,
  ) {
    final selectedThavvu = _selectedTransferThavvuId;
    return _transferItems.where((item) {
      if (item.kind != kind) return false;
      if (selectedThavvu == null || selectedThavvu.trim().isEmpty) {
        return true;
      }
      return item.thavvuIds.contains(selectedThavvu);
    }).toList();
  }

  Map<String, List<InternalTransferItem>> _groupTransferItemsByThavvu(
    TransferAssetKind kind,
  ) {
    final grouped = <String, List<InternalTransferItem>>{};
    for (final item in _transferItemsForKindByThavvu(kind)) {
      final key = '${item.batchId}_${item.rentalId}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  List<InternalTransferItem> get _workEquipmentItemsForSelectedThavvu {
    return _transferItemsForKindByThavvu(TransferAssetKind.workEquipment)
      ..sort((a, b) {
        final batchCompare = a.batchId.compareTo(b.batchId);
        if (batchCompare != 0) return batchCompare;
        return a.name.compareTo(b.name);
      });
  }

  List<String> get _workEquipmentBatchIds {
    final batches = _workEquipmentItemsForSelectedThavvu
        .map((item) => item.batchId)
        .toSet()
        .toList()
      ..sort();
    return batches;
  }

  List<InternalTransferItem> get _workEquipmentItemsForSelectedBatch {
    final batches = _workEquipmentBatchIds;
    final selectedBatch = _selectedWorkEquipmentBatchId ??
        (batches.isNotEmpty ? batches.first : null);

    if (selectedBatch == null) return [];

    return _workEquipmentItemsForSelectedThavvu
        .where((item) => item.batchId == selectedBatch)
        .toList();
  }

  InternalTransferItem? get _selectedWorkEquipmentTransferItem {
    final items = _workEquipmentItemsForSelectedBatch;
    if (items.isEmpty) return null;

    for (final item in items) {
      if (item.id == _selectedWorkEquipmentItemId) {
        return item;
      }
    }

    return items.first;
  }

  int get _workEquipmentTransferQty {
    final parsed = int.tryParse(_workEquipmentQtyController.text.trim()) ?? 1;
    return parsed.clamp(1, 999999).toInt();
  }

  void _selectWorkEquipmentBatch(String? batchId) {
    setState(() {
      _selectedWorkEquipmentBatchId = batchId;
      final items = _workEquipmentItemsForSelectedBatch;
      _selectedWorkEquipmentItemId = items.isEmpty ? null : items.first.id;
      _workEquipmentQtyController.text = '1';
      _workEquipmentPhotoPath = null;
      _workEquipmentNotesController.clear();
    });
  }

  void _changeWorkEquipmentTransferQty(int delta) {
    final item = _selectedWorkEquipmentTransferItem;
    if (item == null) return;
    final available = math.max(item.remainingQty, 1);
    final current = _workEquipmentTransferQty;
    final next = (current + delta).clamp(1, available).toInt();
    setState(() => _workEquipmentQtyController.text = next.toString());
  }

  void _attachWorkEquipmentTransferPhoto() {
    setState(() {
      _workEquipmentPhotoPath =
          'we_transfer_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
    _showSnackbar(
      'Photo attached for work equipment transfer.',
      AppTheme.success,
    );
  }

  /// Best-effort persistence of an internal transfer to Supabase so the HOD
  /// review queue sees it. Uses the repo's createTransfer (status submitted);
  /// failures are surfaced but never block the local flow.
  Future<void> _persistTransferToBackend({
    required String assetKind,
    required String itemName,
    String? fromThavvuId,
    String? toThavvuId,
    String? driver,
    String? photoPath,
    String? notes,
  }) async {
    try {
      await _rentalRepo.createTransfer(
        siteId: _rentalSiteId,
        transferNo: 'ITR-${DateTime.now().millisecondsSinceEpoch}',
        assetKind: assetKind,
        itemName: itemName,
        fromThavvuId: fromThavvuId,
        toThavvuId: toThavvuId,
        driver: driver,
        workDate: DateTime.now(),
        photoPath: photoPath,
        notes: notes,
      );
    } catch (e) {
      debugPrint('_persistTransferToBackend failed: $e');
      if (mounted) {
        _showSnackbar(
          'Transfer saved locally, but the HOD sync failed. Check connection.',
          AppTheme.warning,
        );
      }
    }
  }

  void _submitWorkEquipmentTransfer() {
    final thavvuId = _selectedTransferThavvuId;
    final targetThavvu = _toTransferThavvuId;
    final item = _selectedWorkEquipmentTransferItem;

    if (thavvuId == null || thavvuId.trim().isEmpty) {
      _showSnackbar(
        'Select From Thavvu ID first before transferring work equipment.',
        AppTheme.warning,
      );
      return;
    }

    if (targetThavvu == null || targetThavvu.trim().isEmpty) {
      _showSnackbar(
        'Select To Thavvu ID before transferring work equipment.',
        AppTheme.warning,
      );
      return;
    }

    if (thavvuId == targetThavvu) {
      _showSnackbar(
        'From Thavvu ID and To Thavvu ID cannot be the same.',
        AppTheme.warning,
      );
      return;
    }

    if (item == null) {
      _showSnackbar(
        'Select work equipment batch and item.',
        AppTheme.warning,
      );
      return;
    }

    if (_workEquipmentPhotoPath == null || _workEquipmentPhotoPath!.trim().isEmpty) {
      _showSnackbar(
        'Upload photo proof before submitting work equipment transfer.',
        AppTheme.warning,
      );
      return;
    }

    final qty = _workEquipmentTransferQty;
    if (qty <= 0 || qty > item.remainingQty) {
      _showSnackbar(
        'Number of items cannot exceed remaining quantity: ${item.remainingQty}.',
        AppTheme.warning,
      );
      return;
    }

    final receiver = _transferReceiverController.text.trim().isEmpty
        ? 'Supervisor / Department'
        : _transferReceiverController.text.trim();

    // Persist to Supabase so the HOD review queue sees this transfer.
    unawaited(_persistTransferToBackend(
      assetKind: 'workEquipment',
      itemName: item.name,
      fromThavvuId: thavvuId,
      toThavvuId: targetThavvu,
      driver: receiver,
      photoPath: _workEquipmentPhotoPath ?? '',
      notes: _workEquipmentNotesController.text.trim(),
    ));

    setState(() {
      item.returnedQty = (item.returnedQty + qty).clamp(0, item.rentedQty);
      _internalTransferHistory.insert(
        0,
        InternalTransferHistoryRecord(
          id: 'ITH-${DateTime.now().millisecondsSinceEpoch}',
          date: DateTime.now(),
          thavvuId: thavvuId,
          toThavvuId: targetThavvu,
          transferType: 'Work Equipment',
          itemName: item.name,
          batchId: item.batchId,
          rentalId: item.rentalId,
          numberOfItems: qty,
          transferredTo: receiver,
          photoPath: _workEquipmentPhotoPath ?? '',
          notes: _workEquipmentNotesController.text.trim(),
        ),
      );
      _workEquipmentQtyController.text = '1';
      _workEquipmentNotesController.clear();
      _workEquipmentPhotoPath = null;
    });

    _showSnackbar(
      'Submit Transfer completed. Work equipment moved from $thavvuId to $targetThavvu.',
      AppTheme.success,
    );
  }

  List<RentalItem> get _activeMachinesForInternalTransfer {
    return _activeRentals
        .where((rental) => rental.isActivated && rental.closingDate == null)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  int _availableMachineTransferQty(RentalItem rental) {
    return math.max(rental.totalQuantity, 1);
  }

  int _selectedMachineTransferQty(RentalItem rental) {
    final available = _availableMachineTransferQty(rental);
    final draft = _machineTransferQuantityDraft[rental.id] ?? 1;
    return draft.clamp(1, available).toInt();
  }

  void _toggleMachineTransferSelection(RentalItem rental, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedMachineTransferRentalIds.add(rental.id);
        _machineTransferQuantityDraft[rental.id] =
            _selectedMachineTransferQty(rental);
        _confirmedMachineTransferRentalIds.remove(rental.id);
      } else {
        _selectedMachineTransferRentalIds.remove(rental.id);
        _confirmedMachineTransferRentalIds.remove(rental.id);
        _machineTransferQuantityDraft.remove(rental.id);
      }
    });
  }

  void _changeMachineTransferQty(RentalItem rental, int delta) {
    final available = _availableMachineTransferQty(rental);
    final current = _selectedMachineTransferQty(rental);
    setState(() {
      _machineTransferQuantityDraft[rental.id] =
          (current + delta).clamp(1, available).toInt();
      _selectedMachineTransferRentalIds.add(rental.id);
      _confirmedMachineTransferRentalIds.remove(rental.id);
    });
  }

  int get _selectedMachineTransferCount =>
      _selectedMachineTransferRentalIds.length;

  int get _selectedMachineTransferTotalQty {
    return _activeMachinesForInternalTransfer
        .where((rental) => _selectedMachineTransferRentalIds.contains(rental.id))
        .fold<int>(0, (sum, rental) => sum + _selectedMachineTransferQty(rental));
  }

  List<RentalItem> get _selectedMachineTransferRentals {
    return _activeMachinesForInternalTransfer
        .where((rental) => _selectedMachineTransferRentalIds.contains(rental.id))
        .toList()
      ..sort((a, b) => a.item.compareTo(b.item));
  }

  int get _confirmedMachineTransferCount {
    return _selectedMachineTransferRentals
        .where((rental) => _confirmedMachineTransferRentalIds.contains(rental.id))
        .length;
  }

  bool get _allSelectedMachinesConfirmed {
    final selected = _selectedMachineTransferRentals;
    return selected.isNotEmpty &&
        selected.every(
          (rental) => _confirmedMachineTransferRentalIds.contains(rental.id),
        );
  }

  void _toggleMachineTransferConfirmation(RentalItem rental, bool? confirmed) {
    if (!_selectedMachineTransferRentalIds.contains(rental.id)) return;
    setState(() {
      if (confirmed == true) {
        _confirmedMachineTransferRentalIds.add(rental.id);
      } else {
        _confirmedMachineTransferRentalIds.remove(rental.id);
      }
    });
  }

  void _attachMachineTransferPhoto() {
    setState(() {
      _machineTransferPhotoPath =
          'machine_transfer_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
    _showSnackbar(
      'Photo attached for machine transfer.',
      AppTheme.success,
    );
  }

  void _submitMachineTransferSelection() {
    final selectedThavvu = _selectedTransferThavvuId;
    final targetThavvu = _toTransferThavvuId;
    final selectedRentals = _activeMachinesForInternalTransfer
        .where((rental) => _selectedMachineTransferRentalIds.contains(rental.id))
        .toList();

    if (selectedThavvu == null || selectedThavvu.trim().isEmpty) {
      _showSnackbar(
        'Select From Thavvu ID first before submitting machine transfer.',
        AppTheme.warning,
      );
      return;
    }

    if (targetThavvu == null || targetThavvu.trim().isEmpty) {
      _showSnackbar(
        'Select To Thavvu ID before submitting machine transfer.',
        AppTheme.warning,
      );
      return;
    }

    if (selectedThavvu == targetThavvu) {
      _showSnackbar(
        'From Thavvu ID and To Thavvu ID cannot be the same.',
        AppTheme.warning,
      );
      return;
    }

    if (_machineTransferPhotoPath == null || _machineTransferPhotoPath!.trim().isEmpty) {
      _showSnackbar(
        'Upload photo proof before submitting machine transfer.',
        AppTheme.warning,
      );
      return;
    }

    if (selectedRentals.isEmpty) {
      _showSnackbar(
        'Select at least one active machine before submitting transfer.',
        AppTheme.warning,
      );
      return;
    }

    if (!_allSelectedMachinesConfirmed) {
      _showSnackbar(
        'Check and confirm every selected machine in the selected machines table before proceeding.',
        AppTheme.warning,
      );
      return;
    }

    final receiver = _transferReceiverController.text.trim().isEmpty
        ? 'Supervisor / Department'
        : _transferReceiverController.text.trim();

    setState(() {
      for (final rental in selectedRentals) {
        final qty = _selectedMachineTransferQty(rental);
        final existingIndex = _transferItems.indexWhere(
          (item) => item.id == 'MS-${rental.id}',
        );
        final location = _locationForDistrict(
          rental.siteName,
          siteName: rental.siteName,
          address: '${rental.fieldLabel} • ${rental.tankId}',
        );
        final transferItem = InternalTransferItem(
          id: 'MS-${rental.id}',
          name: rental.item,
          kind: TransferAssetKind.workEquipment,
          batchId: 'MS-BATCH-${rental.id}',
          rentalId: rental.id,
          rentedQty: qty,
          returnedQty: 0,
          thavvuIds: [
            selectedThavvu,
            targetThavvu,
            if (rental.tankId.trim().isNotEmpty) 'THV-${rental.tankId}',
          ],
          tankIds: [rental.tankId],
          location: location,
        );

        if (existingIndex == -1) {
          _transferItems.insert(0, transferItem);
        } else {
          _transferItems[existingIndex] = transferItem;
        }

        _internalTransferHistory.insert(
          0,
          InternalTransferHistoryRecord(
            id: 'ITH-MS-${DateTime.now().microsecondsSinceEpoch}',
            date: DateTime.now(),
            thavvuId: selectedThavvu,
            toThavvuId: targetThavvu,
            transferType: 'Machine',
            itemName: rental.item,
            batchId: transferItem.batchId,
            rentalId: rental.id,
            numberOfItems: qty,
            transferredTo: receiver,
            photoPath: _machineTransferPhotoPath ?? '',
            notes: 'Machine selected from Active Rentals and transferred from $selectedThavvu to $targetThavvu for $receiver.',
          ),
        );

        // Persist to Supabase so the HOD review queue sees this transfer.
        unawaited(_persistTransferToBackend(
          assetKind: 'material',
          itemName: rental.item,
          fromThavvuId: selectedThavvu,
          toThavvuId: targetThavvu,
          driver: receiver,
          photoPath: _machineTransferPhotoPath ?? '',
          notes:
              'Machine selected from Active Rentals and transferred from $selectedThavvu to $targetThavvu for $receiver.',
        ));

        _addSupplierPaymentItemForTransfer(transferItem);
      }

      _selectedMachineTransferRentalIds.clear();
      _confirmedMachineTransferRentalIds.clear();
      _machineTransferQuantityDraft.clear();
      _machineTransferPhotoPath = null;
      final batches = _workEquipmentBatchIds;
      _selectedWorkEquipmentBatchId =
          batches.isEmpty ? null : batches.first;
      final items = _workEquipmentItemsForSelectedBatch;
      _selectedWorkEquipmentItemId = items.isEmpty ? null : items.first.id;
    });

    _showSnackbar(
      'Submit Transfer completed. Machines moved from $selectedThavvu to $targetThavvu with photo proof.',
      AppTheme.success,
    );
  }

  bool _isSameHistoryDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  List<InternalTransferHistoryRecord> get _generatedInternalTransferHistory {
    return _transferItems
        .where((item) => item.returnedQty > 0 && item.kind == TransferAssetKind.workEquipment)
        .map((item) {
          final daysAgo = 1 + (item.id.hashCode.abs() % 12);
          return InternalTransferHistoryRecord(
            id: 'ITH-SEED-${item.id}',
            date: DateTime.now().subtract(Duration(days: daysAgo)),
            thavvuId: _firstId(item.thavvuIds) ?? 'Not assigned',
            toThavvuId: item.thavvuIds.length > 1 ? item.thavvuIds[1] : '',
            transferType: 'Work Equipment',
            itemName: item.name,
            batchId: item.batchId,
            rentalId: item.rentalId,
            numberOfItems: item.returnedQty,
            transferredTo: 'Existing Supervisor / Department',
            notes: 'Existing internal transfer record from current rental data.',
          );
        }).toList();
  }

  List<InternalTransferHistoryRecord> get _visibleInternalTransferHistory {
    final dateFilter = _internalTransferHistoryDateFilter;
    final combined = <InternalTransferHistoryRecord>[
      ..._internalTransferHistory,
      ..._generatedInternalTransferHistory,
    ];

    final filtered = combined.where((record) {
      if (dateFilter == null) return true;
      return _isSameHistoryDate(record.date, dateFilter);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  void _changeReturnedCount(InternalTransferItem item, int delta) {
    setState(() {
      final next = item.returnedQty + delta;
      item.returnedQty = next.clamp(0, item.rentedQty);
      _syncSupplierPaymentFromTransfer(item);
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
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
                      subtitle:
                          'Add material or work equipment with Thavvu and tank mapping',
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
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
                              label: 'Transfer count',
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
                          _addSupplierPaymentItemForTransfer(item);
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
                      subtitle:
                          'Add a rentable line under hourly, weekly, trip, or KM billing',
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
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
    final unitsController =
        TextEditingController(text: _defaultVehicleUsage(selectedType));
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
                      subtitle:
                          'Real-world billing with HR, WK, TR, and KM support',
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
                          selectedVehicleId =
                              _selectedVehicles[selectedType]?.id;
                          selectedThavvuId =
                              _selectedVehicleThavvuIds[selectedType];
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
                      validator: (_) =>
                          options.isEmpty ? 'Add a vehicle first' : null,
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
                        hint:
                            'Example: feed bags moved, harvest dispatch, bund repair',
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
                        border: Border.all(
                            color: AppTheme.warning.withOpacity(0.22)),
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
                          thavvuId: selectedThavvuId ??
                              _firstId(chosenVehicle.thavvuIds) ??
                              'THV-VH-NEW',
                          tankId: tankController.text.trim().isEmpty
                              ? 'TNK-AP-NEW'
                              : tankController.text.trim(),
                          fromLocation: fromController.text.trim().isEmpty
                              ? 'Aqua yard'
                              : fromController.text.trim(),
                          toLocation: toController.text.trim().isEmpty
                              ? 'Pond work site'
                              : toController.text.trim(),
                          driverOrOperator:
                              operatorController.text.trim().isEmpty
                                  ? 'Driver / Operator'
                                  : operatorController.text.trim(),
                          workDate: DateTime.now(),
                          units: double.parse(unitsController.text),
                          rate: double.parse(rateController.text),
                          fuelCost: double.tryParse(fuelController.text) ?? 0,
                          driverBata: double.tryParse(bataController.text) ?? 0,
                          loadingCharge:
                              double.tryParse(loadingController.text) ?? 0,
                          status: selectedStatus,
                          notes: notesController.text.trim(),
                        );

                        setState(() {
                          _vehicleEntries.insert(0, entry);
                          _selectedVehicles[selectedType] = chosenVehicle;
                          _selectedVehicleThavvuIds[selectedType] =
                              entry.thavvuId;
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

    _showSnackbar(
        '${entry.vehicleName} marked as completed.', AppTheme.success);
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
    final quantity = math.max(
      _currentDraftRentalItems().fold(0, (sum, item) => sum + item.quantity),
      1,
    );
    final base = _billingMode == 'Per day' ? rate : rate * 8;
    return base * quantity;
  }

  double _calculateUsedAmount() {
    if (!_rentalFuelEnabled) return 0;
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

  Widget _uploadButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final lowerLabel = label.toLowerCase();
    final attached =
        lowerLabel.contains('added') || lowerLabel.contains('captured');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: attached ? AppTheme.successBg : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: attached ? AppTheme.success : color.withOpacity(0.35),
            width: attached ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: attached
                      ? AppTheme.success.withOpacity(0.25)
                      : color.withOpacity(0.22),
                ),
              ),
              child: Icon(icon,
                  size: 20, color: attached ? AppTheme.success : color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: attached ? AppTheme.success : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attached ? 'Tap to replace' : 'Tap to upload',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              attached ? Icons.check_circle : Icons.upload_file_outlined,
              color: attached ? AppTheme.success : color,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // New advance payment helpers
  // =========================

  List<RentalPaymentTransaction> get _cashTransactions =>
      _rentalPaymentLedger.where((entry) => entry.type == 'cash').toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<RentalPaymentTransaction> get _advanceTransactions =>
      _rentalPaymentLedger.where((entry) => entry.type == 'advance').toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Widget _buildPaymentSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cash Payment',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pay via cash (HOD limit applies)'),
                value: _enableCashPayment,
                activeColor: AppTheme.info,
                onChanged: (val) => setState(() => _enableCashPayment = val),
              ),
            ),
            GestureDetector(
              onTap: () => _showTransactionHistorySheet('cash'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long,
                        size: 14, color: AppTheme.info),
                    const SizedBox(width: 4),
                    Text(
                      '${_cashTransactions.length} payment${_cashTransactions.length == 1 ? "" : "s"}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.info),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        if (_enableCashPayment) ...[
          _buildCashPaymentSection(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_enableCashPayment &&
                      (double.tryParse(_cashAmountController.text) ?? 0) > 0)
                  ? _proceedCashPayment
                  : null,
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Proceed Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildCashPaymentTable(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Advance Request',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Request advance from finance'),
                value: _enableAdvancePayment,
                activeColor: AppTheme.success,
                onChanged: (val) => setState(() => _enableAdvancePayment = val),
              ),
            ),
            GestureDetector(
              onTap: () => _showTransactionHistorySheet('advance'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.request_quote_outlined,
                        size: 14, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(
                      '${_advanceTransactions.length} request${_advanceTransactions.length == 1 ? "" : "s"}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        if (_enableAdvancePayment) ...[
          const SizedBox(height: 8),
          _buildAdvancePaymentSection(),
        ],
        const SizedBox(height: 12),
        _buildAdvanceRequestTable(),
      ],
    );
  }

  void _proceedCashPayment() {
    final amount = double.tryParse(_cashAmountController.text) ?? 0;
    if (amount <= 0) {
      _showSnackbar('Enter valid cash amount', AppTheme.warning);
      return;
    }
    if (amount > _cashLimit) {
      _showSnackbar(
        'Cash amount exceeds limit of ₹${_cashLimit.toStringAsFixed(0)}',
        AppTheme.warning,
      );
      return;
    }
    if (amount > _cashBalance) {
      _showSnackbar('Insufficient cash balance', AppTheme.warning);
      return;
    }

    if (_hasActiveSupplierPaymentPlan) {
      final expectedAmount = _activeSupplierPaymentPlanQtyById.entries
          .fold<double>(0, (sum, entry) {
        final item = _supplierPaymentItems.firstWhere(
          (value) => value.id == entry.key,
          orElse: () => SupplierPaymentItem(
            id: '',
            supplierName: '',
            transferItemId: '',
            itemName: '',
            batchId: '',
            rentalId: '',
            startDate: DateTime.now(),
            takenQty: 0,
            ratePerDay: 0,
          ),
        );
        if (item.id.isEmpty) return sum;
        return sum + item.amountFor(
          qty: entry.value,
          endDate: _activeSupplierPaymentPlanEndDate ?? DateTime.now(),
        );
      });

      if ((amount - expectedAmount).abs() > 0.50) {
        _showSnackbar(
          'Cash amount must match selected payment plan: ${_formatMoney(expectedAmount)}',
          AppTheme.warning,
        );
        return;
      }
    }

    final now = DateTime.now();
    final txn = RentalPaymentTransaction(
      id: 'CASH-${now.millisecondsSinceEpoch}',
      type: 'cash',
      amount: amount,
      method: 'Cash',
      date: now,
      status: 'Completed',
      note: _hasActiveSupplierPaymentPlan
          ? 'Supplier payment plan completed by cash'
          : 'Cash payment recorded',
    );

    setState(() {
      _rentalPaymentLedger.insert(0, txn);
    });

    unawaited(_persistRentalPayment(
      supplierName: _selectedPaymentSupplier ?? 'Rental Cash',
      amount: amount,
      mode: 'cash',
      note: txn.note,
    ));

    if (_hasActiveSupplierPaymentPlan) {
      _completeSupplierPaymentPlan(
        qtyById: Map<String, int>.from(_activeSupplierPaymentPlanQtyById),
        endDate: _activeSupplierPaymentPlanEndDate ?? now,
        paymentMethod: 'Cash',
        paymentReference: txn.id,
        noteType: _activeSupplierPaymentPlanNoteType,
        noteDetails: _activeSupplierPaymentPlanNote,
      );
      if (Navigator.canPop(context)) Navigator.pop(context);
    }

    setState(() {
      _cashAmountController.clear();
      _enableCashPayment = false;
      _clearActiveSupplierPaymentPlan();
    });
    _showSnackbar(
      'Cash payment of ₹${amount.toStringAsFixed(0)} recorded',
      AppTheme.success,
    );
  }

  Widget _buildCashPaymentSection() {
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
              Text(
                'Available Balance: ₹${_cashBalance.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: _cashAmountController,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(
            label: 'Cash Amount (₹)',
            hint: 'Max ₹${_cashLimit.toStringAsFixed(0)}',
            icon: Icons.currency_rupee,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _buildCashValidationInfo(),
      ],
    );
  }

  Widget _buildCashValidationInfo() {
    final text = _cashAmountController.text;
    final amount = double.tryParse(text) ?? 0;
    if (text.isEmpty) {
      return _paymentNotice(
        'Balance after payment: ₹${_cashBalance.toStringAsFixed(0)}',
        AppTheme.info,
        Icons.info_outline,
      );
    }
    if (amount > _cashLimit) {
      return _paymentNotice(
        'Exceeds HOD limit of ₹${_cashLimit.toStringAsFixed(0)}. Use advance request for balance.',
        AppTheme.danger,
        Icons.error_outline,
      );
    }
    if (amount > _cashBalance) {
      return _paymentNotice(
        'Insufficient cash balance. Available: ₹${_cashBalance.toStringAsFixed(0)}.',
        AppTheme.danger,
        Icons.warning_amber,
      );
    }
    return _paymentNotice(
      'Valid. Balance after payment: ₹${(_cashBalance - amount).toStringAsFixed(0)}',
      AppTheme.success,
      Icons.check_circle,
    );
  }

  Widget _buildCashPaymentTable() {
    return _buildLedgerTableShell(
      title: 'Cash Payment Table',
      subtitle: 'Amount is auto-filled when payment is completed; use Edit to correct amount',
      color: AppTheme.info,
      icon: Icons.payments_outlined,
      emptyText: 'No cash payments generated yet.',
      child: _cashTransactions.isEmpty
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
                rows: _cashTransactions.map((txn) {
                  return DataRow(
                    cells: [
                      DataCell(Text(txn.id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataCell(Text(_formatCompactDateTime(txn.date), style: const TextStyle(fontSize: 12))),
                      DataCell(Text('₹${txn.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(
                        TextButton.icon(
                          onPressed: () => _showEditCashPaymentSheet(txn),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.info),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildAdvanceRequestTable() {
    return _buildLedgerTableShell(
      title: 'Advance Payment Request Table',
      subtitle: 'Proof and Machine IDs Book unlock only after the requested amount is completed',
      color: AppTheme.success,
      icon: Icons.request_quote_outlined,
      emptyText: 'No advance payment requests generated yet.',
      child: _advanceTransactions.isEmpty
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
                rows: _advanceTransactions.map((txn) {
                  final completed = txn.status == 'Completed';
                  return DataRow(
                    cells: [
                      DataCell(Text(txn.id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataCell(Text(_formatCompactDateTime(txn.date), style: const TextStyle(fontSize: 12))),
                      DataCell(Text('₹${txn.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(
                        completed
                            ? _rentalStatusChip('Completed', AppTheme.success)
                            : TextButton.icon(
                                onPressed: () => _completeRequestedAdvance(txn),
                                icon: const Icon(Icons.verified_outlined, size: 15),
                                label: const Text('Requested'),
                                style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
                              ),
                      ),
                      DataCell(
                        completed
                            ? _rentalProofPreview(txn.paymentProof ?? 'Payment proof')
                            : const Text('Visible after completion', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ),
                      DataCell(
                        completed
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    txn.registeredInMachineIdsBook ? 'Yes' : 'No',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: txn.registeredInMachineIdsBook ? AppTheme.success : AppTheme.textMuted,
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: txn.registeredInMachineIdsBook,
                                    activeColor: AppTheme.success,
                                    onChanged: (value) => _toggleAdvanceMachineBook(txn, value),
                                  ),
                                ],
                              )
                            : const Text('Locked', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildLedgerTableShell({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required String emptyText,
    required Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
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
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (child == null)
            Text(emptyText, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))
          else
            child,
        ],
      ),
    );
  }

  Widget _buildAdvancePaymentSection() {
    final advanceAmount =
        double.tryParse(_advanceAmountController.text) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _advanceAmountController,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(
            label: 'Advance Amount (₹)',
            icon: Icons.request_quote_outlined,
            suffixText: '₹',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        const Text('Payment Method',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _rentalPaymentOption(
                label: 'UPI',
                icon: Icons.qr_code,
                color: AppTheme.success,
                selected: _selectedAdvanceMode == 'upi',
                onTap: () => setState(() {
                  _selectedAdvanceMode = 'upi';
                  _selectedEntryMethod = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _rentalPaymentOption(
                label: 'Bank Transfer',
                icon: Icons.account_balance,
                color: AppTheme.info,
                selected: _selectedAdvanceMode == 'bank',
                onTap: () => setState(() {
                  _selectedAdvanceMode = 'bank';
                  _selectedEntryMethod = null;
                }),
              ),
            ),
          ],
        ),
        if (_selectedAdvanceMode == 'upi') ...[
          const SizedBox(height: 12),
          _buildUpiAccountSelection(),
        ],
        if (_selectedAdvanceMode == 'bank') ...[
          const SizedBox(height: 12),
          _buildBankDetailsSection(),
        ],
        if (advanceAmount > 0 && _selectedAdvanceMode != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitAdvanceRequest,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Submit Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
        if (_selectedAdvanceMode != null) ...[
          const SizedBox(height: 10),
          _paymentNotice(
            'Request will be sent for approval',
            AppTheme.success,
            Icons.info_outline,
          ),
        ],
      ],
    );
  }

  Widget _buildUpiAccountSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Verified UPI Account',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        ..._savedAccounts.map((account) => GestureDetector(
              onTap: () => setState(
                  () => _selectedPaymentAccount = account['id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedPaymentAccount == account['id']
                      ? AppTheme.successBg
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _selectedPaymentAccount == account['id']
                          ? AppTheme.success
                          : AppTheme.border,
                      width: _selectedPaymentAccount == account['id']
                          ? 2
                          : 1),
                ),
                child: Row(
                  children: [
                    Icon(
                        _selectedPaymentAccount == account['id']
                            ? Icons.check_circle
                            : Icons.account_balance_wallet,
                        size: 20,
                        color: _selectedPaymentAccount == account['id']
                            ? AppTheme.success
                            : AppTheme.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account['upiId']!,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _selectedPaymentAccount ==
                                          account['id']
                                      ? AppTheme.success
                                      : AppTheme.textPrimary)),
                          Text(account['bankName']!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    if (account['type'] == 'primary')
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppTheme.infoBg,
                              borderRadius:
                                  BorderRadius.circular(6)),
                          child: const Text('Default',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.info))),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _showAddAccountSheet(
                          existingId: account['id']),
                      color: AppTheme.warning,
                    ),
                  ],
                ),
              ),
            )).toList(),
        TextButton.icon(
          onPressed: _showAddAccountSheet,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add UPI Account'),
          style: TextButton.styleFrom(
              foregroundColor: AppTheme.info),
        ),
      ],
    );
  }

  Widget _buildBankDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_savedBankAccounts.isNotEmpty) ...[
          const Text('Saved Bank Accounts',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ..._savedBankAccounts.map((bank) => GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedBankAccount = bank['id'];
                    _ifscController.text = bank['ifsc']!;
                    _accNumController.text = bank['accountNumber']!
                        .replaceAll('****', '');
                    _bankNameController.text = bank['bankName']!;
                    _selectedEntryMethod = 'manual';
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _selectedBankAccount == bank['id']
                        ? AppTheme.infoBg
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _selectedBankAccount == bank['id']
                            ? AppTheme.info
                            : AppTheme.border,
                        width:
                            _selectedBankAccount == bank['id']
                                ? 2
                                : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          _selectedBankAccount == bank['id']
                              ? Icons.check_circle
                              : Icons.account_balance_outlined,
                          size: 20,
                          color: _selectedBankAccount == bank['id']
                              ? AppTheme.info
                              : AppTheme.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(bank['bankName']!,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _selectedBankAccount ==
                                                bank['id']
                                            ? AppTheme.info
                                            : AppTheme.textPrimary)),
                            Text(
                                'A/C ${bank['accountNumber']}  ·  IFSC: ${bank['ifsc']}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textMuted)),
                            if (bank['holderName'] != null &&
                                bank['holderName']!.isNotEmpty)
                              Text(bank['holderName']!,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color:
                                          AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      if (bank['type'] == 'primary')
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppTheme.infoBg,
                                borderRadius:
                                    BorderRadius.circular(6)),
                            child: const Text('Default',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.info))),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: () => _showAddBankAccountSheet(
                            existingId: bank['id']),
                        color: AppTheme.warning,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              )).toList(),
          TextButton.icon(
            onPressed: _showAddBankAccountSheet,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add New Bank Account'),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.info),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Or enter manually',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
        ],
        const Text('Select Entry Method',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _rentalEntryMethodOption(
                    'manual', 'Manual', Icons.edit_outlined)),
            const SizedBox(width: 8),
            Expanded(
                child: _rentalEntryMethodOption(
                    'photo', 'Photo', Icons.camera_alt_outlined)),
            const SizedBox(width: 8),
            Expanded(
                child: _rentalEntryMethodOption(
                    'voice', 'Voice', Icons.mic_none)),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedEntryMethod == 'manual') ...[
          const Text('Bank Details',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _ifscController,
            decoration: _inputDecoration(
              label: 'IFSC Code',
              icon: Icons.code,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _accNumController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(
              label: 'Account Number',
              icon: Icons.account_balance,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bankNameController,
            decoration: _inputDecoration(
              label: 'Bank Name',
              icon: Icons.business,
            ),
          ),
        ] else if (_selectedEntryMethod == 'photo') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.info.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.camera_alt, color: AppTheme.info),
              SizedBox(width: 8),
              Text('Upload bank screenshot',
                  style: TextStyle(color: AppTheme.info)),
            ]),
          ),
        ] else if (_selectedEntryMethod == 'voice') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.info.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.mic, color: AppTheme.info),
              SizedBox(width: 8),
              Text('Record bank details by voice',
                  style: TextStyle(color: AppTheme.info)),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _rentalEntryMethodOption(String method, String title, IconData icon) {
    final isSelected = _selectedEntryMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedEntryMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.success.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.success : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: isSelected ? AppTheme.success : AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.success : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showAddAccountSheet({String? existingId}) {
    final nameController = TextEditingController();
    final upiController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add UPI Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Bank Name')),
              const SizedBox(height: 8),
              TextField(controller: upiController, decoration: const InputDecoration(labelText: 'UPI ID')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty && upiController.text.isNotEmpty) {
                    setState(() {
                      _savedAccounts.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'upiId': upiController.text,
                        'bankName': nameController.text,
                        'type': 'secondary',
                      });
                    });
                    Navigator.pop(context);
                    _showSnackbar('UPI account added', AppTheme.success);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddBankAccountSheet({String? existingId}) {
    // For brevity, show a placeholder message; implement full form if needed.
    _showSnackbar('Add bank account feature – implement full form as required.', AppTheme.info);
  }

  void _submitAdvanceRequest() {
    final amount = double.tryParse(_advanceAmountController.text) ?? 0;
    if (amount <= 0) {
      _showSnackbar('Enter valid advance amount', AppTheme.warning);
      return;
    }
    if (_selectedAdvanceMode == null) {
      _showSnackbar('Select payment method (UPI or Bank)', AppTheme.warning);
      return;
    }
    if (_selectedAdvanceMode == 'upi' && _selectedPaymentAccount == null) {
      _showSnackbar('Select a UPI account', AppTheme.warning);
      return;
    }
    if (_selectedAdvanceMode == 'bank' && _selectedEntryMethod == null) {
      _showSnackbar('Select bank request entry method', AppTheme.warning);
      return;
    }

    final hadSupplierPaymentPlan = _hasActiveSupplierPaymentPlan;
    final now = DateTime.now();
    final txn = RentalPaymentTransaction(
      id: 'ADV-${now.millisecondsSinceEpoch}',
      type: 'advance',
      amount: amount,
      method: _selectedAdvanceMode == 'upi' ? 'UPI' : 'Bank Transfer',
      date: now,
      status: 'Requested',
      note: _hasActiveSupplierPaymentPlan
          ? 'Supplier payment plan request via ${_selectedAdvanceMode}'
          : 'Advance request via ${_selectedAdvanceMode}',
      registeredInMachineIdsBook: false,
    );

    setState(() {
      _rentalPaymentLedger.insert(0, txn);
      if (_hasActiveSupplierPaymentPlan) {
        _pendingSupplierPaymentPlans[txn.id] =
            Map<String, int>.from(_activeSupplierPaymentPlanQtyById);
        _pendingSupplierPaymentPlanEndDates[txn.id] =
            _activeSupplierPaymentPlanEndDate ?? now;
        _pendingSupplierPaymentPlanNoteTypes[txn.id] =
            _activeSupplierPaymentPlanNoteType;
        _pendingSupplierPaymentPlanNotes[txn.id] = _activeSupplierPaymentPlanNote;
      }
      _advanceAmountController.clear();
      _selectedAdvanceMode = null;
      _selectedEntryMethod = null;
      _selectedPaymentAccount = null;
      _selectedBankAccount = null;
      _clearActiveSupplierPaymentPlan();
    });

    if (hadSupplierPaymentPlan && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    _showSnackbar(
      hadSupplierPaymentPlan
          ? 'Supplier payment request submitted for ₹${amount.toStringAsFixed(0)}'
          : 'Advance request submitted for ₹${amount.toStringAsFixed(0)}',
      AppTheme.success,
    );
  }

  void _completeRequestedAdvance(RentalPaymentTransaction txn) {
    final pendingPlan = _pendingSupplierPaymentPlans.remove(txn.id);
    final pendingEndDate = _pendingSupplierPaymentPlanEndDates.remove(txn.id);
    final pendingNoteType = _pendingSupplierPaymentPlanNoteTypes.remove(txn.id);
    final pendingNote = _pendingSupplierPaymentPlanNotes.remove(txn.id);

    setState(() {
      txn.status = 'Completed';
      txn.paymentProof = 'advance_proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });

    if (pendingPlan != null) {
      _completeSupplierPaymentPlan(
        qtyById: pendingPlan,
        endDate: pendingEndDate ?? DateTime.now(),
        paymentMethod: txn.method,
        paymentReference: txn.id,
        noteType: pendingNoteType ?? 'Manual Note',
        noteDetails: pendingNote ?? '',
      );
      _showSnackbar('Requested supplier payment completed and items closed', AppTheme.success);
      return;
    }

    _showSnackbar('Advance payment completed', AppTheme.success);
  }

  void _toggleAdvanceMachineBook(RentalPaymentTransaction txn, bool value) {
    setState(() => txn.registeredInMachineIdsBook = value);
  }

  void _showEditCashPaymentSheet(RentalPaymentTransaction txn) {
    final controller = TextEditingController(text: txn.amount.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Edit Cash Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Correct Amount (₹)')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final newAmount = double.tryParse(controller.text) ?? 0;
                  if (newAmount > 0) {
                    setState(() => txn.amount = newAmount);
                    Navigator.pop(context);
                    _showSnackbar('Cash payment updated', AppTheme.success);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionHistorySheet(String type) {
    final transactions = type == 'advance' ? _advanceTransactions : _cashTransactions;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: transactions.map((txn) => ListTile(
            title: Text(txn.id),
            subtitle: Text('${_formatCompactDateTime(txn.date)} - ₹${txn.amount.toStringAsFixed(0)}'),
            trailing: Text(txn.status),
          )).toList(),
        ),
      ),
    );
  }

  String _formatCompactDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }


  // =========================
  // Supervisor Reports + Computed Payment Summary
  // =========================

  int _daysBetween(DateTime date) {
    return math.max(1, DateTime.now().difference(date).inDays + 1);
  }

  double _computedRentalTotal(RentalItem rental) {
    if (rental.isActivated && rental.activationDate != null) {
      return rental.getEarnedAmount();
    }
    return rental.rate * rental.totalQuantity * _daysBetween(rental.startDate);
  }

  double _completedPaidForRental(RentalItem rental) {
    return rental.paymentTransactions
        .where((txn) => txn.status == 'Completed')
        .fold<double>(0, (sum, txn) => sum + txn.amount);
  }

  String _computedPaymentStatus({
    required double totalAmount,
    required double paidAmount,
  }) {
    final balance = totalAmount - paidAmount;
    if (balance <= 0) return 'Paid';
    if (paidAmount > 0) return 'Partial';
    return 'Pending';
  }

  Color _computedPaymentStatusColor(String status) {
    switch (status) {
      case 'Paid':
      case 'Completed':
      case 'Closed':
        return AppTheme.success;
      case 'Partial':
      case 'Partial Closed':
      case 'Partial Open':
      case 'Requested':
      case 'Billing Pending':
        return AppTheme.warning;
      default:
        return AppTheme.danger;
    }
  }

  Widget _computedPaymentStatusChip(String status) {
    final color = _computedPaymentStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  String _supplierNameForRental(RentalItem rental) {
    final transfer = _transferItems.where((item) => item.rentalId == rental.id);
    if (transfer.isNotEmpty) return _supplierNameForTransferItem(transfer.first);
    if (rental.operatorName.trim().isNotEmpty &&
        rental.operatorName != 'Operator not assigned') {
      return rental.operatorName;
    }
    return 'Rental Supplier';
  }

  String _supplierNameForClosedRental(Map<String, dynamic> rental) {
    final id = (rental['id'] ?? '').toString();
    final payment = _supplierPaymentItems.where((item) => item.rentalId == id);
    if (payment.isNotEmpty) return payment.first.supplierName;
    return 'Closed Rental Supplier';
  }

  List<String> get _reportSupplierNames {
    final names = <String>{
      ..._activeRentals.map(_supplierNameForRental),
      ..._closedRentals.map(_supplierNameForClosedRental),
      ..._transferItems.map(_supplierNameForTransferItem),
      ..._supplierPaymentHistory.map((record) => record.supplierName),
    }.where((name) => name.trim().isNotEmpty).toList()
      ..sort();
    return names;
  }

  bool _dateInReportRange(DateTime date) {
    final from = _reportFromDateFilter;
    final to = _reportToDateFilter;
    final normalized = DateTime(date.year, date.month, date.day);
    if (from != null) {
      final f = DateTime(from.year, from.month, from.day);
      if (normalized.isBefore(f)) return false;
    }
    if (to != null) {
      final t = DateTime(to.year, to.month, to.day);
      if (normalized.isAfter(t)) return false;
    }
    return true;
  }

  bool _stringDateInReportRange(String value) {
    if (_reportFromDateFilter == null && _reportToDateFilter == null) return true;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return _dateInReportRange(parsed);

    final from = _reportFromDateFilter;
    final to = _reportToDateFilter;
    if (from != null && trimmed == _formatDate(from)) return true;
    if (to != null && trimmed == _formatDate(to)) return true;
    return false;
  }

  bool _matchesReportSupplier(String supplierName) {
    final selected = _reportSupplierFilter;
    if (selected == null || selected == 'All Suppliers') return true;
    return supplierName == selected;
  }

  bool _matchesReportSearch(Iterable<String> values) {
    final query = _reportSearch.trim().toLowerCase();
    if (query.isEmpty) return true;
    return values.any((value) => value.toLowerCase().contains(query));
  }

  List<RentalItem> get _filteredActiveRentalReports {
    return _activeRentals.where((rental) {
      final supplier = _supplierNameForRental(rental);
      return _dateInReportRange(rental.startDate) &&
          _matchesReportSupplier(supplier) &&
          _matchesReportSearch([
            rental.id,
            rental.item,
            supplier,
            rental.siteName,
            rental.tankId,
            rental.operatorName,
          ]);
    }).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  List<InternalTransferHistoryRecord> get _filteredTransferReports {
    return _visibleInternalTransferHistory.where((record) {
      final source = _transferItems.where((item) => item.id == record.id || item.name == record.itemName);
      final supplier = source.isNotEmpty
          ? _supplierNameForTransferItem(source.first)
          : _supplierNameFromRentalId(record.rentalId);
      return _dateInReportRange(record.date) &&
          _matchesReportSupplier(supplier) &&
          _matchesReportSearch([
            record.id,
            record.itemName,
            record.batchId,
            record.rentalId,
            record.thavvuId,
            record.toThavvuId,
            record.transferredTo,
            supplier,
          ]);
    }).toList();
  }

  String _supplierNameFromRentalId(String rentalId) {
    final item = _supplierPaymentItems.where((entry) => entry.rentalId == rentalId);
    if (item.isNotEmpty) return item.first.supplierName;
    final transfer = _transferItems.where((entry) => entry.rentalId == rentalId);
    if (transfer.isNotEmpty) return _supplierNameForTransferItem(transfer.first);
    return 'Rental Supplier';
  }

  List<Map<String, dynamic>> get _filteredReturnReports {
    return _closedRentals.where((record) {
      final supplier = _supplierNameForClosedRental(record);
      final dateText = (record['endDate'] ?? record['startDate'] ?? '').toString();
      return _stringDateInReportRange(dateText) &&
          _matchesReportSupplier(supplier) &&
          _matchesReportSearch([
            (record['id'] ?? '').toString(),
            (record['item'] ?? '').toString(),
            supplier,
            (record['status'] ?? '').toString(),
            (record['payment'] ?? '').toString(),
          ]);
    }).toList();
  }

  List<RentalPaymentTransaction> get _filteredRentalPaymentTransactions {
    return _rentalPaymentLedger.where((txn) {
      final linkedName = txn.machineName ?? '';
      final supplier = linkedName.isEmpty
          ? (_selectedPaymentSupplier ?? 'Rental Supplier')
          : _supplierNameFromLinkedPaymentName(linkedName);
      return _dateInReportRange(txn.date) &&
          _matchesReportSupplier(supplier) &&
          _matchesReportSearch([
            txn.id,
            txn.method,
            txn.status,
            txn.note ?? '',
            linkedName,
            supplier,
          ]);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  String _supplierNameFromLinkedPaymentName(String linkedName) {
    final rental = _activeRentals.where((entry) => entry.item == linkedName || entry.id == linkedName);
    if (rental.isNotEmpty) return _supplierNameForRental(rental.first);
    final history = _supplierPaymentHistory.where((entry) => entry.itemName == linkedName);
    if (history.isNotEmpty) return history.first.supplierName;
    return _selectedPaymentSupplier ?? 'Rental Supplier';
  }

  List<SupplierPaymentHistoryRecord> get _filteredSupplierPaymentReports {
    return _supplierPaymentHistory.where((record) {
      return _dateInReportRange(record.createdAt) &&
          _matchesReportSupplier(record.supplierName) &&
          _matchesReportSearch([
            record.id,
            record.supplierName,
            record.itemName,
            record.batchId,
            record.rentalId,
            record.paymentMethod,
            record.paymentReference,
            record.noteDetails,
          ]);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Widget _buildComputedSupplierPaymentSummaryTable() {
    final visibleItems = _visibleSupplierPaymentItems;
    if (visibleItems.isEmpty) {
      return _buildSectionCard(
        title: 'Computed Payment Summary',
        subtitle: 'Running balance summary appears after supplier items are available.',
        icon: Icons.calculate_outlined,
        color: AppTheme.info,
        child: _buildPaymentEmptyState(
          icon: Icons.table_chart_outlined,
          title: 'No rows to calculate',
          message: 'Internal transfer items create supplier payment rows automatically.',
        ),
      );
    }

    return _buildSectionCard(
      title: 'Computed Payment Summary',
      subtitle:
          'Status is calculated from total amount, amount paid, and running balance. Existing payment methods are unchanged.',
      icon: Icons.table_chart_outlined,
      color: AppTheme.info,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 54,
          dataRowMaxHeight: 68,
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Start')),
            DataColumn(label: Text('Days')),
            DataColumn(label: Text('Qty')),
            DataColumn(label: Text('Rate')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Paid')),
            DataColumn(label: Text('Balance')),
            DataColumn(label: Text('Status')),
          ],
          rows: visibleItems.map((item) {
            final days = _daysBetween(item.startDate);
            final total = item.amountFor(qty: item.takenQty, endDate: DateTime.now());
            final paid = _supplierPaymentHistory
                .where((record) => record.id.contains(item.id) ||
                    (record.itemName == item.itemName && record.rentalId == item.rentalId))
                .fold<double>(0, (sum, record) => sum + record.amount);
            final balance = total - paid;
            final status = _computedPaymentStatus(
              totalAmount: total,
              paidAmount: paid,
            );
            return DataRow(
              cells: [
                DataCell(Text(item.supplierName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataCell(Text(item.itemName, style: const TextStyle(fontSize: 12))),
                DataCell(Text(_formatDate(item.startDate), style: const TextStyle(fontSize: 12))),
                DataCell(Text('$days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                DataCell(Text('${item.takenQty}', style: const TextStyle(fontSize: 12))),
                DataCell(Text(_formatMoney(item.ratePerDay), style: const TextStyle(fontSize: 12))),
                DataCell(Text(_formatMoney(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                DataCell(Text(_formatMoney(paid), style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w800))),
                DataCell(Text(_formatMoney(math.max(balance, 0)), style: TextStyle(fontSize: 12, color: balance > 0 ? AppTheme.danger : AppTheme.success, fontWeight: FontWeight.w900))),
                DataCell(_computedPaymentStatusChip(status)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(
                  emoji: '📊',
                  title: 'Supervisor Reports',
                  subtitle:
                      'Rental, transfer, return, and payment reports with date, supplier, and search filters',
                  accent: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                _buildReportsFilterBar(),
                const SizedBox(height: 16),
                Container(
                  color: AppTheme.surface,
                  child: const TabBar(
                    isScrollable: true,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 2.5,
                    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    tabs: [
                      Tab(text: 'Rental', icon: Icon(Icons.handyman_outlined)),
                      Tab(text: 'Transfer', icon: Icon(Icons.swap_horiz)),
                      Tab(text: 'Return', icon: Icon(Icons.assignment_return_outlined)),
                      Tab(text: 'Payment', icon: Icon(Icons.payments_outlined)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 620,
                  child: TabBarView(
                    children: [
                      _buildRentalReportTable(),
                      _buildTransferReportTable(),
                      _buildReturnReportTable(),
                      _buildPaymentReportTable(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsFilterBar() {
    final suppliers = _reportSupplierNames;
    final selectedSupplier = _reportSupplierFilter ?? 'All Suppliers';
    return _buildSectionCard(
      title: 'Report Filters',
      subtitle: 'Use shared filters exactly like the Reports reference flow.',
      icon: Icons.filter_alt_outlined,
      color: AppTheme.info,
      child: Column(
        children: [
          TextField(
            controller: _reportSearchController,
            onChanged: (value) => setState(() => _reportSearch = value),
            decoration: _inputDecoration(
              label: 'Search supplier, item, receipt, transfer no, reference',
              icon: Icons.search_outlined,
            ).copyWith(
              suffixIcon: _reportSearch.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _reportSearchController.clear();
                        setState(() => _reportSearch = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _reportDateTile(
                  label: 'From Date',
                  value: _reportFromDateFilter == null
                      ? 'Any date'
                      : _formatDate(_reportFromDateFilter!),
                  icon: Icons.date_range_outlined,
                  color: AppTheme.primary,
                  onTap: () async {
                    final picked = await _pickReportDate(_reportFromDateFilter ?? DateTime.now());
                    if (picked != null) setState(() => _reportFromDateFilter = picked);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _reportDateTile(
                  label: 'To Date',
                  value: _reportToDateFilter == null
                      ? 'Any date'
                      : _formatDate(_reportToDateFilter!),
                  icon: Icons.event_available_outlined,
                  color: AppTheme.success,
                  onTap: () async {
                    final picked = await _pickReportDate(_reportToDateFilter ?? DateTime.now());
                    if (picked != null) setState(() => _reportToDateFilter = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedSupplier,
            isExpanded: true,
            decoration: _inputDecoration(
              label: 'Supplier Filter',
              icon: Icons.storefront_outlined,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: 'All Suppliers',
                child: Text('All Suppliers'),
              ),
              ...suppliers.map(
                (supplier) => DropdownMenuItem<String>(
                  value: supplier,
                  child: Text(supplier, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              _reportSupplierFilter = value == 'All Suppliers' ? null : value;
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _reportSearchController.clear();
                setState(() {
                  _reportSearch = '';
                  _reportFromDateFilter = null;
                  _reportToDateFilter = null;
                  _reportSupplierFilter = null;
                });
              },
              icon: const Icon(Icons.clear_all_outlined),
              label: const Text('Clear Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickReportDate(DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
  }

  Widget _reportDateTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportTableShell({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return ListView(
      padding: const EdgeInsets.only(top: 14),
      children: [
        _buildSectionCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          color: color,
          child: child,
        ),
      ],
    );
  }

  Widget _buildRentalReportTable() {
    final rows = _filteredActiveRentalReports;
    return _reportTableShell(
      title: 'Rental Report (${rows.length} records)',
      subtitle: 'Running rental amount = rate × quantity × running days.',
      icon: Icons.handyman_outlined,
      color: AppTheme.danger,
      child: rows.isEmpty
          ? _buildPaymentEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No rental records',
              message: 'No rentals match the selected filters.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 76,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Receipt / ID')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Village / Site')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Running')),
                  DataColumn(label: Text('Daily Rent')),
                  DataColumn(label: Text('Days')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Status')),
                ],
                rows: rows.map((rental) {
                  final supplier = _supplierNameForRental(rental);
                  final total = _computedRentalTotal(rental);
                  final paid = _completedPaidForRental(rental);
                  final payStatus = _computedPaymentStatus(totalAmount: total, paidAmount: paid);
                  return DataRow(cells: [
                    DataCell(Text(rental.id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    DataCell(Text(_formatDate(rental.startDate), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(supplier, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(rental.siteName, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(rental.lineItems.length > 1 ? 'Multiple' : rental.item, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(rental.item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    DataCell(Text('${rental.totalQuantity}', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${rental.totalQuantity}', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_formatMoney(rental.rate), style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${_daysBetween(rental.startDate)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    DataCell(Text(_formatMoney(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                    DataCell(Text(rental.tankId, style: const TextStyle(fontSize: 12))),
                    DataCell(_computedPaymentStatusChip(payStatus)),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildTransferReportTable() {
    final rows = _filteredTransferReports;
    return _reportTableShell(
      title: 'Transfer Report (${rows.length} records)',
      subtitle: 'Internal transfer log with from/to Thavvu point and quantity.',
      icon: Icons.swap_horiz,
      color: AppTheme.info,
      child: rows.isEmpty
          ? _buildPaymentEmptyState(
              icon: Icons.swap_horiz,
              title: 'No transfer records',
              message: 'No transfer history matches the selected filters.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Transfer No')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('From')),
                  DataColumn(label: Text('To')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Supervisor')),
                  DataColumn(label: Text('Reason')),
                ],
                rows: rows.map((record) {
                  final supplier = _supplierNameFromRentalId(record.rentalId);
                  return DataRow(cells: [
                    DataCell(Text(record.id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.info))),
                    DataCell(Text(_formatDate(record.date), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(supplier, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(record.itemName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    DataCell(Text(record.thavvuId, style: const TextStyle(fontSize: 12, color: AppTheme.danger))),
                    DataCell(Text(record.toThavvuId.isEmpty ? record.transferredTo : record.toThavvuId, style: const TextStyle(fontSize: 12, color: AppTheme.success))),
                    DataCell(Text('${record.numberOfItems}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                    DataCell(Text(record.submittedBy, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(record.notes.isEmpty ? '—' : record.notes, style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildReturnReportTable() {
    final rows = _filteredReturnReports;
    return _reportTableShell(
      title: 'Return Report (${rows.length} records)',
      subtitle: 'Closed rentals are shown as return/closure records for supervisor review.',
      icon: Icons.assignment_return_outlined,
      color: AppTheme.success,
      child: rows.isEmpty
          ? _buildPaymentEmptyState(
              icon: Icons.assignment_return_outlined,
              title: 'No return records',
              message: 'Closed rentals matching your filters will appear here.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Receipt')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Return Qty')),
                  DataColumn(label: Text('From Point')),
                  DataColumn(label: Text('Remarks')),
                ],
                rows: rows.map((record) {
                  final supplier = _supplierNameForClosedRental(record);
                  return DataRow(cells: [
                    DataCell(Text((record['endDate'] ?? '—').toString(), style: const TextStyle(fontSize: 12))),
                    DataCell(Text((record['id'] ?? '—').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    DataCell(Text(supplier, style: const TextStyle(fontSize: 12))),
                    DataCell(Text((record['item'] ?? '—').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    DataCell(Text((record['returnQty'] ?? '1').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                    DataCell(Text((record['fromPoint'] ?? 'Closed rental yard').toString(), style: const TextStyle(fontSize: 12))),
                    DataCell(Text('Closed • Payment: ${(record['payment'] ?? 'Pending')}', style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildPaymentReportTable() {
    final supplierRows = _filteredSupplierPaymentReports;
    final txnRows = _filteredRentalPaymentTransactions;
    final totalCount = supplierRows.length + txnRows.length;

    return _reportTableShell(
      title: 'Payment Report ($totalCount records)',
      subtitle: 'Includes supplier payment closures and existing cash/advance request ledger.',
      icon: Icons.payments_outlined,
      color: AppTheme.warning,
      child: totalCount == 0
          ? _buildPaymentEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payment records',
              message: 'Payment records matching your filters will appear here.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 78,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Receipt / Item')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Remarks')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  ...supplierRows.map((record) {
                    return DataRow(cells: [
                      DataCell(Text(_formatDate(record.createdAt), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(record.supplierName, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(record.itemName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataCell(Text(_formatMoney(record.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.success))),
                      DataCell(Text(record.paymentMethod, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(record.paymentReference.isEmpty ? '—' : record.paymentReference, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(record.noteDetails.isEmpty ? record.noteType : record.noteDetails, style: const TextStyle(fontSize: 12))),
                      DataCell(_computedPaymentStatusChip(record.status)),
                    ]);
                  }),
                  ...txnRows.map((txn) {
                    final supplier = _supplierNameFromLinkedPaymentName(txn.machineName ?? '');
                    return DataRow(cells: [
                      DataCell(Text(_formatDate(txn.date), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(supplier, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(txn.machineName ?? txn.id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataCell(Text(_formatMoney(txn.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.success))),
                      DataCell(Text(txn.method, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(txn.id, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(txn.note ?? '—', style: const TextStyle(fontSize: 12))),
                      DataCell(_computedPaymentStatusChip(txn.status)),
                    ]);
                  }),
                ],
              ),
            ),
    );
  }

  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: 'Rental Management',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            controller: _tabController,
            tabs: const [
              Tab(text: 'Open Rental'),
              Tab(text: 'Active Rentals'),
              Tab(text: 'Internal Transfer'),
              Tab(text: 'Payment'),
              Tab(text: 'Closed Rentals'),
              Tab(text: 'Reports'),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOpenRentalTab(),
            _buildActiveRentalsTab(),
            _buildInternalTransferTab(),
            _buildPaymentTab(),
            _buildClosedRentalsTab(),
            _buildReportsTab(),
          ],
        ),
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
            title: 'Advance Payment Option',
            color: AppTheme.primary,
            child: _buildAdvancePayment(),
          ),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 3,
            title: 'Fuel & Additional Notes',
            color: AppTheme.info,
            child: _buildFuelAndNotes(),
          ),
          const SizedBox(height: 20),
          _buildFinancialPreview(),
          const SizedBox(height: 20),
          _buildSubmitButton(
            'Proceed to Active Rentals',
            AppTheme.success,
            _openRental,
            _isOpening,
            Icons.play_circle_fill,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =========================
  // Active rentals (unchanged)
  // =========================

  Widget _buildActiveRentalsTab() {
    final sortedRentals = [..._activeRentals]..sort((a, b) {
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
          subtitle:
              'View machine status, check-ins, tank entry, activation, and fuel logs',
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
                  '${rental.lineItems.length} item(s) • Qty ${rental.totalQuantity}',
                  AppTheme.danger,
                  icon: Icons.inventory_2_outlined,
                ),
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
                      foregroundColor: rental.isActivated
                          ? AppTheme.primary
                          : AppTheme.success,
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
                    onPressed: rental.isActivated
                        ? () => _continueRental(rental)
                        : null,
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
  // Internal transfer (unchanged)
  // =========================

  Widget _buildInternalTransferTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: AppTheme.surface,
            child: const TabBar(
              isScrollable: true,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: [
                Tab(
                  text: 'MS & WE',
                  icon: Icon(Icons.precision_manufacturing_outlined),
                ),
                Tab(
                  text: 'Receiving',
                  icon: Icon(Icons.inbox_outlined),
                ),
                Tab(
                  text: 'Vehicles',
                  icon: Icon(Icons.local_shipping_outlined),
                ),
                Tab(
                  text: 'History',
                  icon: Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMsWeTransferTab(),
                _buildReceivingTab(),
                _buildVehiclesTransferTab(),
                _buildInternalTransferHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivingTab() {
    final incomingTransfers = _internalTransferHistory.where((record) {
      return record.toThavvuId.isNotEmpty ||
          record.status.contains('Receive') ||
          record.status == 'Received';
    }).toList();

    final pendingCount =
        incomingTransfers.where((r) => r.status == 'Pending Receive').length;
    final receivedCount =
        incomingTransfers.where((r) => r.status == 'Received').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          emoji: '📥',
          title: 'Receiving Internal Transfers',
          subtitle:
              'View & confirm machines or work equipment transferred by other supervisors in real-time',
          accent: AppTheme.success,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Pending',
                pendingCount.toString(),
                Icons.hourglass_top_outlined,
                AppTheme.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'Received',
                receivedCount.toString(),
                Icons.check_circle_outline,
                AppTheme.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                'Total',
                incomingTransfers.length.toString(),
                Icons.swap_horiz,
                AppTheme.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (incomingTransfers.isEmpty)
          _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No incoming transfers',
            subtitle:
                'Transfers sent to you by other supervisors will appear here.',
          )
        else
          ...incomingTransfers.map(_buildReceivingCard),
      ],
    );
  }

  Widget _buildReceivingCard(InternalTransferHistoryRecord record) {
    final isPending = record.status == 'Pending Receive';
    final isReceived = record.status == 'Received';

    return GestureDetector(
      onTap: () => _showReceivingDetailSheet(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? AppTheme.warning.withOpacity(0.5)
                : isReceived
                    ? AppTheme.success.withOpacity(0.35)
                    : AppTheme.border,
            width: isPending ? 1.4 : 0.8,
          ),
          boxShadow: AppTheme.mediumShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: status chip + date + tap hint
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending
                        ? AppTheme.warning.withOpacity(0.12)
                        : isReceived
                            ? AppTheme.success.withOpacity(0.12)
                            : AppTheme.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPending
                            ? Icons.hourglass_top_outlined
                            : isReceived
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                        size: 14,
                        color: isPending
                            ? AppTheme.warning
                            : isReceived
                                ? AppTheme.success
                                : AppTheme.info,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPending
                              ? AppTheme.warning
                              : isReceived
                                  ? AppTheme.success
                                  : AppTheme.info,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _formatDate(record.date),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        size: 16, color: AppTheme.textSecondary),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Item icon + name + batch
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    record.transferType == 'Machine Equipment' ||
                            record.transferType == 'Machine'
                        ? Icons.precision_manufacturing_outlined
                        : Icons.handyman_outlined,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.itemName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Batch: ${record.batchId} • Qty: ${record.numberOfItems}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Sender row (compact)
            Row(
              children: [
                const Icon(Icons.person_pin_outlined,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  'From ${record.submittedBy}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward,
                      size: 12, color: AppTheme.textSecondary),
                ),
                Text(
                  record.toThavvuId.isNotEmpty
                      ? record.toThavvuId
                      : 'Your Site',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success),
                ),
              ],
            ),
            if (isReceived && record.receiverName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        size: 14, color: AppTheme.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Received by ${record.receiverName} — ${record.receivedQty ?? record.numberOfItems} items',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showReceivingDetailSheet(record),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.info,
                        side: const BorderSide(color: AppTheme.info),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showConfirmReceiptDialog(record),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Confirm Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReceivingDetailSheet(InternalTransferHistoryRecord record) {
    final isPending = record.status == 'Pending Receive';
    final isReceived = record.status == 'Received';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        record.transferType == 'Machine Equipment' ||
                                record.transferType == 'Machine'
                            ? Icons.precision_manufacturing_outlined
                            : Icons.handyman_outlined,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.itemName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary),
                          ),
                          Text(
                            '${record.transferType} • ${record.batchId}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending
                            ? AppTheme.warning.withOpacity(0.12)
                            : isReceived
                                ? AppTheme.success.withOpacity(0.12)
                                : AppTheme.info.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPending
                              ? AppTheme.warning
                              : isReceived
                                  ? AppTheme.success
                                  : AppTheme.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Transfer info block
                    _buildDetailSection(
                      title: 'Transfer Information',
                      icon: Icons.swap_horiz,
                      color: AppTheme.primary,
                      rows: [
                        _buildDetailRow('Transfer ID', record.id),
                        _buildDetailRow('Transfer Date', _formatDate(record.date)),
                        _buildDetailRow('Transfer Type', record.transferType),
                        _buildDetailRow('Rental ID', record.rentalId),
                        _buildDetailRow('Batch ID', record.batchId),
                        _buildDetailRow('Quantity', '${record.numberOfItems} items'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Sender / route block
                    _buildDetailSection(
                      title: 'Transfer Route',
                      icon: Icons.route_outlined,
                      color: AppTheme.info,
                      rows: [
                        _buildDetailRow('Sent by', record.submittedBy),
                        _buildDetailRow('From Site', record.thavvuId),
                        _buildDetailRow(
                            'To Site',
                            record.toThavvuId.isNotEmpty
                                ? record.toThavvuId
                                : 'Your Site'),
                        _buildDetailRow('Transferred To', record.transferredTo),
                      ],
                    ),
                    if (record.notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection(
                        title: 'Notes / Remarks',
                        icon: Icons.notes_outlined,
                        color: AppTheme.warning,
                        rows: [
                          _buildDetailRow('Remarks', record.notes),
                        ],
                      ),
                    ],
                    if (isReceived && record.receiverName != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection(
                        title: 'Receipt Confirmation',
                        icon: Icons.verified_outlined,
                        color: AppTheme.success,
                        rows: [
                          _buildDetailRow('Received by', record.receiverName!),
                          _buildDetailRow(
                              'Received on',
                              _formatDate(
                                  record.receivedDate ?? record.date)),
                          _buildDetailRow('Quantity Received',
                              '${record.receivedQty ?? record.numberOfItems} items'),
                          if (record.receiverNotes != null &&
                              record.receiverNotes!.isNotEmpty)
                            _buildDetailRow(
                                'Inspection Notes', record.receiverNotes!),
                        ],
                      ),
                    ],
                    if (isPending) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showConfirmReceiptDialog(record);
                          },
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Confirm Receipt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showConfirmReceiptDialog(InternalTransferHistoryRecord record) {
    final receiverNameCtrl = TextEditingController(text: 'Supervisor (You)');
    final qtyCtrl =
        TextEditingController(text: record.numberOfItems.toString());
    final notesCtrl = TextEditingController();
    String selectedCondition = 'Received in Good Condition';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory, color: AppTheme.success),
                            SizedBox(width: 8),
                            Text(
                              'Confirm Receipt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      'Confirming receipt for: ${record.itemName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'Sent by ${record.submittedBy} from ${record.thavvuId}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: receiverNameCtrl,
                      decoration: _inputDecoration(
                        label: 'Receiver Name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'Quantity Received',
                        icon: Icons.numbers,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedCondition,
                      decoration: _inputDecoration(
                        label: 'Condition / Status',
                        icon: Icons.verified_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Received in Good Condition',
                          child: Text('Received in Good Condition'),
                        ),
                        DropdownMenuItem(
                          value: 'Partial Quantity Received',
                          child: Text('Partial Quantity Received'),
                        ),
                        DropdownMenuItem(
                          value: 'Damaged / Defective',
                          child: Text('Damaged / Defective'),
                        ),
                        DropdownMenuItem(
                          value: 'Rejected',
                          child: Text('Rejected'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCondition = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: _inputDecoration(
                        label: 'Inspection Notes / Remarks',
                        hint: 'e.g. Inspected and stored at Pond 9 shed',
                        icon: Icons.note_alt_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final qty = int.tryParse(qtyCtrl.text.trim()) ??
                              record.numberOfItems;
                          setState(() {
                            record.status = selectedCondition == 'Rejected'
                                ? 'Rejected'
                                : 'Received';
                            record.receiverName =
                                receiverNameCtrl.text.trim().isNotEmpty
                                    ? receiverNameCtrl.text.trim()
                                    : 'Supervisor (You)';
                            record.receivedDate = DateTime.now();
                            record.receivedQty = qty;
                            record.receiverNotes = notesCtrl.text.trim();
                          });
                          Navigator.pop(context);
                          _showSnackbar(
                            'Receipt confirmed for ${record.itemName} (${record.status}).',
                            AppTheme.success,
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Submit Confirmation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMsWeTransferTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          emoji: '🔁',
          title: 'MS & WE Internal Transfer',
          subtitle:
              'Select From Thavvu ID → To Thavvu ID, then select machines or work equipment, attach photo, and submit transfer',
          accent: AppTheme.info,
        ),
        const SizedBox(height: 16),
        _buildTransferThavvuPrioritySection(),
        const SizedBox(height: 16),
        _buildActiveMachineTransferTable(),
        const SizedBox(height: 16),
        _buildWorkEquipmentTransferForm(),
        const SizedBox(height: 16),
        _buildWorkEquipmentPlanningSection(),
        const SizedBox(height: 16),
        _buildInternalTransferSummaryCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVehiclesTransferTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          emoji: '🚚',
          title: 'Vehicles',
          subtitle:
              'Vehicle rental information and VRI entries are maintained separately from MS & WE',
          accent: AppTheme.warning,
        ),
        const SizedBox(height: 16),
        _buildVehicleRentalInfoCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTransferThavvuPrioritySection() {
    final thavvuIds = _allInternalTransferThavvuIds;
    final selectedFromThavvu = thavvuIds.contains(_selectedTransferThavvuId)
        ? _selectedTransferThavvuId
        : null;
    final selectedToThavvu = thavvuIds.contains(_toTransferThavvuId)
        ? _toTransferThavvuId
        : null;

    return _buildSectionCard(
      title: '1. From Thavvu ID → To Thavvu ID',
      subtitle:
          'First select the source Thavvu ID, then select the destination Thavvu ID. This is a transfer between Thavvu IDs, not a material return.',
      icon: Icons.compare_arrows_rounded,
      color: AppTheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: selectedFromThavvu,
            isExpanded: true,
            decoration: _inputDecoration(
              label: 'From Thavvu ID',
              icon: Icons.logout_rounded,
            ),
            items: thavvuIds
                .map(
                  (id) => DropdownMenuItem<String>(
                    value: id,
                    child: Text(id, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _selectPriorityThavvu,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedToThavvu,
            isExpanded: true,
            decoration: _inputDecoration(
              label: 'To Thavvu ID',
              icon: Icons.login_rounded,
            ),
            items: thavvuIds
                .where((id) => id != selectedFromThavvu)
                .map(
                  (id) => DropdownMenuItem<String>(
                    value: id,
                    child: Text(id, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _selectToTransferThavvu,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transferReceiverController,
            decoration: _inputDecoration(
              label: 'Receiver Supervisor / Department',
              icon: Icons.supervisor_account_outlined,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.info.withOpacity(0.22)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppTheme.info, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Submit Transfer means items are moved from one Thavvu ID to another Thavvu ID under a supervisor/department. It is not returning items to stock.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkEquipmentTransferForm() {
    final batchIds = _workEquipmentBatchIds;
    final selectedBatch = batchIds.contains(_selectedWorkEquipmentBatchId)
        ? _selectedWorkEquipmentBatchId
        : (batchIds.isNotEmpty ? batchIds.first : null);
    final batchItems = _workEquipmentItemsForSelectedBatch;
    final selectedItem = _selectedWorkEquipmentTransferItem;

    return _buildSectionCard(
      title: '3. WE — Work Equipment Transfer',
      subtitle:
          'Select batch, number of items, upload photo, add notes, then submit transfer',
      icon: Icons.handyman_outlined,
      color: AppTheme.warning,
      child: batchIds.isEmpty
          ? _buildEmptyState(
              icon: Icons.handyman_outlined,
              title: 'No work equipment found',
              subtitle:
                  'Select a different Thavvu ID or submit active machines first.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedBatch,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Batch',
                    icon: Icons.layers_outlined,
                  ),
                  items: batchIds
                      .map(
                        (batch) => DropdownMenuItem<String>(
                          value: batch,
                          child: Text(batch, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _selectWorkEquipmentBatch,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedItem == null ? null : selectedItem.id,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Work Equipment Item',
                    icon: Icons.inventory_2_outlined,
                  ),
                  items: batchItems
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            '${item.name} • Remaining ${item.remainingQty}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedWorkEquipmentItemId = value;
                      _workEquipmentQtyController.text = '1';
                      _workEquipmentPhotoPath = null;
                      _workEquipmentNotesController.clear();
                    });
                  },
                ),
                if (selectedItem != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniMetric(
                          'Total WE',
                          selectedItem.rentedQty.toString(),
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniMetric(
                          'Giving',
                          selectedItem.returnedQty.toString(),
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniMetric(
                          'Remaining',
                          selectedItem.remainingQty.toString(),
                          color: selectedItem.remainingQty == 0
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Number of Items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      _buildCounterButton(
                        icon: Icons.remove,
                        onTap: () => _changeWorkEquipmentTransferQty(-1),
                      ),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _workEquipmentQtyController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      _buildCounterButton(
                        icon: Icons.add,
                        onTap: () => _changeWorkEquipmentTransferQty(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _attachWorkEquipmentTransferPhoto,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _workEquipmentPhotoPath == null
                            ? AppTheme.warning.withOpacity(0.08)
                            : AppTheme.successBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _workEquipmentPhotoPath == null
                              ? AppTheme.warning.withOpacity(0.22)
                              : AppTheme.success.withOpacity(0.28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _workEquipmentPhotoPath == null
                                ? Icons.add_a_photo_outlined
                                : Icons.image_outlined,
                            color: _workEquipmentPhotoPath == null
                                ? AppTheme.warning
                                : AppTheme.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _workEquipmentPhotoPath == null
                                  ? 'Upload photo of selected work equipment items'
                                  : 'Attached: $_workEquipmentPhotoPath',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _workEquipmentPhotoPath == null
                                    ? AppTheme.warning
                                    : AppTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _workEquipmentNotesController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      label: 'Notes',
                      icon: Icons.notes_outlined,
                    ).copyWith(
                      hintText:
                          'Example: transferred to Supervisor Ramesh for Pond-A1 night shift',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selectedItem.remainingQty == 0
                          ? null
                          : _submitWorkEquipmentTransfer,
                      icon: const Icon(Icons.swap_horiz_outlined),
                      label: const Text('Submit Transfer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warning,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildInternalTransferHistoryTab() {
    final records = _visibleInternalTransferHistory;
    final dateFilter = _internalTransferHistoryDateFilter;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          emoji: '📅',
          title: 'Internal Transfer History',
          subtitle:
              'Detailed table of all machine and work equipment transfers from one Thavvu ID to another Thavvu ID',
          accent: AppTheme.primary,
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Calendar / Date Filter',
          subtitle: dateFilter == null
              ? 'Showing all internal transfer records'
              : 'Showing records for ${_formatDate(dateFilter)}',
          icon: Icons.calendar_month_outlined,
          color: AppTheme.primary,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dateFilter ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(DateTime.now().year + 2),
                    );
                    if (picked != null) {
                      setState(() => _internalTransferHistoryDateFilter = picked);
                    }
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    dateFilter == null
                        ? 'Choose Date'
                        : _formatDate(dateFilter),
                  ),
                ),
              ),
              if (dateFilter != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () {
                    setState(() => _internalTransferHistoryDateFilter = null);
                  },
                  icon: const Icon(Icons.close_rounded),
                  color: AppTheme.danger,
                  tooltip: 'Clear date filter',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Transfer Data Table',
          subtitle:
              '${records.length} record(s) • submit transfers are From Thavvu ID → To Thavvu ID, not stock returns',
          icon: Icons.table_chart_outlined,
          color: AppTheme.info,
          child: records.isEmpty
              ? _buildEmptyState(
                  icon: Icons.table_chart_outlined,
                  title: 'No history found',
                  subtitle: 'Try another date or submit a transfer first.',
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 72,
                    columnSpacing: 18,
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('From Thavvu')),
                      DataColumn(label: Text('To Thavvu')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Batch')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Transferred To')),
                      DataColumn(label: Text('Photo')),
                      DataColumn(label: Text('Notes')),
                    ],
                    rows: records.map((record) {
                      return DataRow(
                        cells: [
                          DataCell(Text(
                            _formatDate(record.date),
                            style: const TextStyle(fontSize: 11),
                          )),
                          DataCell(Text(record.thavvuId)),
                          DataCell(Text(record.toThavvuId.trim().isEmpty ? '-' : record.toThavvuId)),
                          DataCell(_buildInfoPill(
                            record.transferType,
                            record.transferType == 'Machine'
                                ? AppTheme.success
                                : AppTheme.warning,
                          )),
                          DataCell(SizedBox(
                            width: 180,
                            child: Text(
                              record.itemName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )),
                          DataCell(Text(record.batchId)),
                          DataCell(Text(
                            record.numberOfItems.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 160,
                            child: Text(
                              record.transferredTo,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Text(
                            record.photoPath.trim().isEmpty ? 'No' : 'Yes',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: record.photoPath.trim().isEmpty
                                  ? AppTheme.textMuted
                                  : AppTheme.success,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 220,
                            child: Text(
                              record.notes.trim().isEmpty ? '-' : record.notes,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildActiveMachineTransferTable() {
    final machines = _activeMachinesForInternalTransfer;

    return _buildSectionCard(
      title: '2. MS — Active Machine Selection',
      subtitle:
          'After From Thavvu ID and To Thavvu ID selection, mark active machines, upload photo proof, and submit transfer',
      icon: Icons.precision_manufacturing_outlined,
      color: AppTheme.success,
      child: machines.isEmpty
          ? _buildEmptyState(
              icon: Icons.precision_manufacturing_outlined,
              title: 'No active machines found',
              subtitle:
                  'Open Rental → Active Rentals → Activate machines first. Active machines will then show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Active Machines',
                        machines.length.toString(),
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniMetric(
                        'Selected',
                        _selectedMachineTransferCount.toString(),
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniMetric(
                        'Transfer Qty',
                        _selectedMachineTransferTotalQty.toString(),
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 44,
                      dataRowMinHeight: 62,
                      dataRowMaxHeight: 74,
                      columnSpacing: 18,
                      columns: const [
                        DataColumn(label: Text('Mark')),
                        DataColumn(label: Text('Rental ID')),
                        DataColumn(label: Text('Machine')),
                        DataColumn(label: Text('Tank / Site')),
                        DataColumn(label: Text('Available')),
                        DataColumn(label: Text('Select Qty')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: machines.map((rental) {
                        final selected = _selectedMachineTransferRentalIds
                            .contains(rental.id);
                        final qty = _selectedMachineTransferQty(rental);
                        final available = _availableMachineTransferQty(rental);
                        return DataRow(
                          selected: selected,
                          cells: [
                            DataCell(
                              Checkbox(
                                value: selected,
                                activeColor: AppTheme.success,
                                onChanged: (value) =>
                                    _toggleMachineTransferSelection(
                                  rental,
                                  value,
                                ),
                              ),
                            ),
                            DataCell(Text(rental.id)),
                            DataCell(
                              SizedBox(
                                width: 190,
                                child: Text(
                                  rental.item,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 170,
                                child: Text(
                                  '${rental.tankId} • ${rental.siteName}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text('$available')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCounterButton(
                                    icon: Icons.remove,
                                    onTap: selected
                                        ? () => _changeMachineTransferQty(
                                              rental,
                                              -1,
                                            )
                                        : () {},
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _buildCounterButton(
                                    icon: Icons.add,
                                    onTap: selected
                                        ? () => _changeMachineTransferQty(
                                              rental,
                                              1,
                                            )
                                        : () {},
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              _buildInfoPill(
                                rental.machineStatus.label,
                                _machineStatusColor(rental),
                                icon: rental.machineStatus.icon,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildSelectedMachineTransferReviewTable(),
                const SizedBox(height: 14),
                _buildMachineTransferPhotoUpload(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _allSelectedMachinesConfirmed
                        ? _submitMachineTransferSelection
                        : null,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      _selectedMachineTransferRentalIds.isEmpty
                          ? 'Select Machines to Submit Transfer'
                          : !_allSelectedMachinesConfirmed
                              ? 'Check Selected Machines to Proceed'
                              : 'Submit Transfer ($_selectedMachineTransferTotalQty machines)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      disabledBackgroundColor: AppTheme.border,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectedMachineTransferReviewTable() {
    final selectedMachines = _selectedMachineTransferRentals;
    if (selectedMachines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.info.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.info.withOpacity(0.20)),
        ),
        child: const Row(
          children: [
            Icon(Icons.fact_check_outlined, color: AppTheme.info, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Selected machines will appear here as a checklist table before transfer submission.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _allSelectedMachinesConfirmed
              ? AppTheme.success.withOpacity(0.28)
              : AppTheme.warning.withOpacity(0.30),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.playlist_add_check_circle_outlined,
                    color: AppTheme.success,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Machines Review Table',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Check each selected machine here. Transfer proceeds only after all selected machines are confirmed. Confirmed: $_confirmedMachineTransferCount/${selectedMachines.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 74,
              columnSpacing: 18,
              columns: const [
                DataColumn(label: Text('Check')),
                DataColumn(label: Text('Rental ID')),
                DataColumn(label: Text('Machine')),
                DataColumn(label: Text('From')),
                DataColumn(label: Text('To')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Tank')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Remove')),
              ],
              rows: selectedMachines.map((rental) {
                final confirmed =
                    _confirmedMachineTransferRentalIds.contains(rental.id);
                final qty = _selectedMachineTransferQty(rental);
                return DataRow(
                  selected: confirmed,
                  cells: [
                    DataCell(
                      Checkbox(
                        value: confirmed,
                        activeColor: AppTheme.success,
                        onChanged: (value) =>
                            _toggleMachineTransferConfirmation(rental, value),
                      ),
                    ),
                    DataCell(Text(rental.id)),
                    DataCell(
                      SizedBox(
                        width: 190,
                        child: Text(
                          rental.item,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    DataCell(Text(_selectedTransferThavvuId ?? '-')),
                    DataCell(Text(_toTransferThavvuId ?? '-')),
                    DataCell(
                      Text(
                        '$qty',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Text(
                          rental.tankId,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      _buildInfoPill(
                        confirmed ? 'Checked' : 'Need check',
                        confirmed ? AppTheme.success : AppTheme.warning,
                        icon: confirmed
                            ? Icons.verified_outlined
                            : Icons.pending_actions_outlined,
                      ),
                    ),
                    DataCell(
                      IconButton(
                        tooltip: 'Remove from selected machines',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppTheme.danger,
                        onPressed: () =>
                            _toggleMachineTransferSelection(rental, false),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _allSelectedMachinesConfirmed
                    ? AppTheme.successBg
                    : AppTheme.warningBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _allSelectedMachinesConfirmed
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: _allSelectedMachinesConfirmed
                        ? AppTheme.success
                        : AppTheme.warning,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _allSelectedMachinesConfirmed
                          ? 'All selected machines checked. You can upload proof and proceed with internal transfer.'
                          : 'Check every selected machine in this table before proceeding with internal transfer.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _allSelectedMachinesConfirmed
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineTransferPhotoUpload() {
    return GestureDetector(
      onTap: _attachMachineTransferPhoto,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _machineTransferPhotoPath == null
              ? AppTheme.success.withOpacity(0.08)
              : AppTheme.successBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _machineTransferPhotoPath == null
                ? AppTheme.success.withOpacity(0.22)
                : AppTheme.success.withOpacity(0.30),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _machineTransferPhotoPath == null
                  ? Icons.add_a_photo_outlined
                  : Icons.image_outlined,
              color: AppTheme.success,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _machineTransferPhotoPath == null
                    ? 'Upload transfer photo proof for selected machines'
                    : 'Attached: $_machineTransferPhotoPath',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkEquipmentPlanningSection() {
    final groups = _groupTransferItemsByThavvu(TransferAssetKind.workEquipment)
        .entries
        .toList();

    return _buildSectionCard(
      title: 'WE — Work Equipment Batch Planning',
      subtitle:
          'Batch-wise view of total WE, giving/transferred quantity, and remaining quantity',
      icon: Icons.handyman_outlined,
      color: AppTheme.warning,
      child: groups.isEmpty
          ? _buildEmptyState(
              icon: Icons.handyman_outlined,
              title: 'No work equipment available',
              subtitle:
                  'Submitted active machines and work equipment will appear here batch wise.',
            )
          : Column(
              children: groups.asMap().entries.map((entry) {
                final index = entry.key;
                final group = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == groups.length - 1 ? 0 : 12,
                  ),
                  child: _buildWorkEquipmentPlanCard(group.key, group.value),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildWorkEquipmentPlanCard(
    String groupKey,
    List<InternalTransferItem> items,
  ) {
    final first = items.first;
    final totalHave = items.fold(0, (sum, item) => sum + item.rentedQty);
    final totalGiving = items.fold(0, (sum, item) => sum + item.returnedQty);
    final totalRemaining = items.fold(0, (sum, item) => sum + item.remainingQty);
    final double progress = totalHave == 0
        ? 0.0
        : (totalGiving / totalHave).clamp(0.0, 1.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ExpansionTile(
        key: PageStorageKey('WE-$groupKey'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.handyman_outlined, color: AppTheme.warning),
        ),
        title: Text(
          'Batch ${first.batchId}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Rental ${first.rentalId} • ${items.length} WE item(s)',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  'Total WE',
                  totalHave.toString(),
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Giving / Transferred',
                  totalGiving.toString(),
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Remaining',
                  totalRemaining.toString(),
                  color: totalRemaining == 0
                      ? AppTheme.success
                      : AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.warning.withOpacity(0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.success),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Giving progress: ${(progress * 100).toStringAsFixed(0)}% • Remaining for us: $totalRemaining',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(_buildTransferItemCard),
        ],
      ),
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
                'Transferred',
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
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
                child: _buildMiniMetric('Transferred', totalReturned.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniMetric(
                  'Chargeable',
                  totalRemaining.toString(),
                  color:
                      totalRemaining == 0 ? AppTheme.success : AppTheme.warning,
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
                    'Transferred',
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
                  'Transfer count',
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
                  ? 'All selected quantity has been transferred.'
                  : '${item.remainingQty} item(s) remain with this supervisor after transfer.',
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


  Widget _buildVehicleRentalInfoCard() {
    return _buildSectionCard(
      title: 'Vehicle Rental Info (VRI)',
      subtitle:
          'Real work entries with HR, WK, TR, and KM billing maintained separately',
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
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
                  onPressed: () =>
                      _showAddVehicleWorkEntrySheet(initialType: type),
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
                    (id) =>
                        DropdownMenuItem<String>(value: id, child: Text(id)),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              subtitle:
                  'Tap Add Work Entry to save actual ${type.label.toLowerCase()} billing.',
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
  // Closed rentals (unchanged)
  // =========================


  // =========================
  // Payment tab — UPDATED ORDER
  // =========================

  Widget _buildPaymentTab() {
    final suppliers = _supplierNames;
    if (_selectedPaymentSupplier == null && suppliers.isNotEmpty) {
      _selectedPaymentSupplier = suppliers.first;
    }
    final visibleItems = _visibleSupplierPaymentItems;
    final openItems = visibleItems.where((item) => !item.isClosed).toList();
    final closedItems = visibleItems.where((item) => item.isClosed).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          emoji: '💳',
          title: 'Supplier Payment',
          subtitle:
              'Select supplier, choose machines/items, close quantities, and pay from one plan',
          accent: AppTheme.success,
        ),
        const SizedBox(height: 16),
        // ---------- Supplier selection moved to TOP ----------
        _buildSupplierSelectionCard(suppliers),
        const SizedBox(height: 16),
        // ---------- Rest of the cards ----------
        _buildPaymentSummaryCard(),
        const SizedBox(height: 16),
        _buildComputedSupplierPaymentSummaryTable(),
        const SizedBox(height: 16),
        _buildPaymentViewSwitch(),
        const SizedBox(height: 16),
        if (_paymentView == 'Open')
          _buildSectionCard(
            title: 'Supplier Machines / Objects',
            subtitle:
                'Select one or more machines/items. For partial closure, edit close quantity before payment.',
            icon: Icons.precision_manufacturing_outlined,
            color: AppTheme.info,
            child: openItems.isEmpty
                ? _buildPaymentEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No open machines/items',
                    message: 'All machines/items for this supplier are closed.',
                  )
                : Column(
                    children: [
                      ...openItems
                          .map((item) => _buildSupplierSelectablePaymentCard(item))
                          .toList(),
                      const SizedBox(height: 10),
                      _buildSupplierPaymentPlanBar(),
                    ],
                  ),
          ),
        if (_paymentView == 'Closed')
          _buildSectionCard(
            title: 'Closed Machines / Objects',
            subtitle: 'Fully or partially closed supplier machines/items.',
            icon: Icons.fact_check_outlined,
            color: AppTheme.success,
            child: closedItems.isEmpty
                ? _buildPaymentEmptyState(
                    icon: Icons.history_toggle_off_outlined,
                    title: 'No closed items yet',
                    message: 'Closed items will appear here after payment closure.',
                  )
                : Column(
                    children: closedItems
                        .map((item) => _buildSupplierSelectablePaymentCard(item))
                        .toList(),
                  ),
          ),
        if (_paymentView == 'History') _buildPaymentHistoryCard(),
        const SizedBox(height: 16),
      ],
    );
  }


  Widget _buildPaymentViewSwitch() {
    const tabs = [
      {'label': 'Open', 'icon': Icons.pending_actions_outlined},
      {'label': 'Closed', 'icon': Icons.fact_check_outlined},
      {'label': 'History', 'icon': Icons.history_edu_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: tabs.map((tab) {
          final label = tab['label'] as String;
          final icon = tab['icon'] as IconData;
          final selected = _paymentView == label;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _paymentView = label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: selected ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _paymentSummaryMetric(
                  'Open Items',
                  '$_supplierOpenItemCount',
                  Icons.pending_actions_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _paymentSummaryMetric(
                  'Closed',
                  '$_supplierClosedItemCount',
                  Icons.verified_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _paymentSummaryMetric(
                  'Payable',
                  _formatMoney(_supplierPaymentOpenAmount),
                  Icons.currency_rupee,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentSummaryMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ---------- UPDATED: Supplier selection card with Add Supplier ----------
  Widget _buildSupplierSelectionCard(List<String> suppliers) {
    return _buildSectionCard(
      title: 'Supplier Name',
      subtitle: 'Select or add a supplier to view their payment items',
      icon: Icons.store_mall_directory_outlined,
      color: AppTheme.primary,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _newSupplierController,
                  decoration: _inputDecoration(
                    label: 'Add new supplier',
                    hint: 'Enter supplier name',
                    icon: Icons.person_add_alt_1_outlined,
                  ),
                  onFieldSubmitted: (_) => _addCustomSupplier(_newSupplierController.text),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _addCustomSupplier(_newSupplierController.text),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (suppliers.isEmpty)
            _buildPaymentEmptyState(
              icon: Icons.storefront_outlined,
              title: 'No suppliers available',
              message: 'Add a supplier using the field above or create transfer entries.',
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedPaymentSupplier,
              isExpanded: true,
              decoration: _inputDecoration(
                label: 'Select Supplier',
                icon: Icons.person_pin_circle_outlined,
              ),
              items: suppliers
                  .map(
                    (supplier) => DropdownMenuItem<String>(
                      value: supplier,
                      child: Text(supplier, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedPaymentSupplier = value;
                  _clearSupplierPaymentSelection();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSupplierSelectablePaymentCard(SupplierPaymentItem item) {
    final color = _paymentStatusColor(item);
    final days = math.max(DateTime.now().difference(item.startDate).inDays, 1);
    final selected = _selectedSupplierPaymentItemIds.contains(item.id);
    final closeQty = _draftCloseQtyForSupplierItem(item);
    final payable = item.amountFor(qty: item.openQty, endDate: DateTime.now());
    final planAmount = item.amountFor(qty: closeQty, endDate: DateTime.now());
    final canEdit = !item.isClosed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppTheme.info.withOpacity(0.06) : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.info : color.withOpacity(0.18),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canEdit)
                Checkbox(
                  value: selected,
                  activeColor: AppTheme.info,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedSupplierPaymentItemIds.add(item.id);
                        _supplierPaymentCloseQtyDraft[item.id] = closeQty;
                      } else {
                        _selectedSupplierPaymentItemIds.remove(item.id);
                        _supplierPaymentCloseQtyDraft.remove(item.id);
                      }
                    });
                  },
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _paymentStatusBg(item),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.check_circle_outline, color: color, size: 22),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.supplierName} • ${item.batchId} • ${item.rentalId}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _paymentStatusBg(item),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _paymentMiniMetric('Came', _formatDate(item.startDate))),
              const SizedBox(width: 8),
              Expanded(child: _paymentMiniMetric('Days', '$days')),
              const SizedBox(width: 8),
              Expanded(child: _paymentMiniMetric('Taken', '${item.takenQty}')),
              const SizedBox(width: 8),
              Expanded(child: _paymentMiniMetric('Open', '${item.openQty}')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rate: ${_formatMoney(item.ratePerDay)}/day • Full open payable: ${_formatMoney(payable)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canEdit && !selected)
                ElevatedButton.icon(
                  onPressed: () => _showCloseSupplierItemSheet(item),
                  icon: const Icon(Icons.payments_outlined, size: 15),
                  label: const Text('Pay This'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else if (canEdit && selected)
                Container(
                  width: 126,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _supplierPaymentCloseQtyDraft[item.id] =
                                math.max(1, closeQty - 1);
                          });
                        },
                        child: const Icon(Icons.remove_circle_outline,
                            size: 20, color: AppTheme.warning),
                      ),
                      Expanded(
                        child: Text(
                          '$closeQty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _supplierPaymentCloseQtyDraft[item.id] =
                                math.min(item.openQty, closeQty + 1);
                          });
                        },
                        child: const Icon(Icons.add_circle_outline,
                            size: 20, color: AppTheme.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 8),
            _paymentNotice(
              'Payment plan: close $closeQty now, keep ${item.openQty - closeQty} running, amount ${_formatMoney(planAmount)}',
              AppTheme.info,
              Icons.playlist_add_check_circle_outlined,
            ),
          ],
        ],
      ),
    );
  }


  Widget _paymentMiniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard() {
    final supplier = _selectedPaymentSupplier;
    final rows = supplier == null
        ? _supplierPaymentHistory
        : _supplierPaymentHistory
            .where((record) => record.supplierName == supplier)
            .toList();

    return _buildSectionCard(
      title: 'Payment History',
      subtitle: 'Start date, end date, amount, days, and closure status.',
      icon: Icons.history_edu_outlined,
      color: AppTheme.warning,
      child: rows.isEmpty
          ? _buildPaymentEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payment history yet',
              message: 'Close an item to create a payment history record.',
            )
          : Column(
              children: rows.map(_buildPaymentHistoryTile).toList(),
            ),
    );
  }

  Widget _buildPaymentHistoryTile(SupplierPaymentHistoryRecord record) {
    final isClosed = record.remainingQty == 0;
    final color = isClosed ? AppTheme.success : AppTheme.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.itemName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                _formatMoney(record.amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${record.batchId} • Qty ${record.closedQty} • ${record.days} days • ${record.paymentMethod}',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDate(record.startDate)} → ${_formatDate(record.endDate)} • ${record.status}',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
          ),
          if (record.paymentReference.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ref: ${record.paymentReference}',
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
            ),
          ],
          if (record.noteDetails.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                '${record.noteType}: ${record.noteDetails}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierPaymentPlanBar() {
    final selectedItems = _selectedSupplierPaymentItems;
    final totalAmount = _supplierPaymentPlanAmount;
    final selectedCount = selectedItems.length;
    final selectedQty = _supplierPaymentPlanQuantity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selectedItems.isEmpty ? AppTheme.surface : AppTheme.successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedItems.isEmpty
              ? AppTheme.border
              : AppTheme.success.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                selectedItems.isEmpty
                    ? Icons.touch_app_outlined
                    : Icons.playlist_add_check_circle_outlined,
                color: selectedItems.isEmpty ? AppTheme.textMuted : AppTheme.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedItems.isEmpty
                      ? 'Select machines/items above to create a payment plan.'
                      : '$selectedCount selected • Close qty $selectedQty • Pay ${_formatMoney(totalAmount)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selectedItems.isEmpty
                        ? AppTheme.textSecondary
                        : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          if (selectedItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showSupplierPaymentPlanSheet,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Continue to Payment Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCloseSupplierItemSheet(SupplierPaymentItem item) {
    setState(() {
      _selectedSupplierPaymentItemIds
        ..clear()
        ..add(item.id);
      _supplierPaymentCloseQtyDraft[item.id] = item.openQty;
    });
    _showSupplierPaymentPlanSheet();
  }

  void _showSupplierPaymentPlanSheet() {
    final selectedItems = _selectedSupplierPaymentItems;
    if (selectedItems.isEmpty) {
      _showSnackbar('Select at least one machine/item to pay.', AppTheme.warning);
      return;
    }

    final planQtyById = <String, int>{
      for (final item in selectedItems) item.id: _draftCloseQtyForSupplierItem(item),
    };
    final endDate = DateTime.now();
    final planAmount = selectedItems.fold<double>(0, (sum, item) {
      final qty = planQtyById[item.id] ?? 0;
      return sum + item.amountFor(qty: qty, endDate: endDate);
    });

    _activeSupplierPaymentPlanQtyById = Map<String, int>.from(planQtyById);
    _activeSupplierPaymentPlanEndDate = endDate;
    _activeSupplierPaymentPlanNoteType = _supplierPaymentNoteType;
    _activeSupplierPaymentPlanNote = _supplierPaymentNoteController.text.trim();
    _cashAmountController.text = planAmount.toStringAsFixed(0);
    _advanceAmountController.text = planAmount.toStringAsFixed(0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, sheetSetState) {
          double amountForPlan() {
            return selectedItems.fold<double>(0, (sum, item) {
              final qty = planQtyById[item.id] ?? 0;
              return sum + item.amountFor(qty: qty, endDate: endDate);
            });
          }

          final totalAmount = amountForPlan();
          final totalQty = planQtyById.values.fold<int>(0, (sum, qty) => sum + qty);

          void syncActivePlan() {
            _activeSupplierPaymentPlanQtyById = Map<String, int>.from(planQtyById);
            _activeSupplierPaymentPlanEndDate = endDate;
            _activeSupplierPaymentPlanNoteType = _supplierPaymentNoteType;
            _activeSupplierPaymentPlanNote = _supplierPaymentNoteController.text.trim();
          }

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
                  _buildSheetHeader(
                    title: 'Supplier Payment Plan',
                    subtitle: 'Confirm machines/items, note details, and complete payment',
                    icon: Icons.payments_outlined,
                    color: AppTheme.success,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.successBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.success.withOpacity(0.20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPaymentSupplier ?? 'Selected supplier',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _paymentMiniMetric('Objects', '${selectedItems.length}')),
                            const SizedBox(width: 8),
                            Expanded(child: _paymentMiniMetric('Close Qty', '$totalQty')),
                            const SizedBox(width: 8),
                            Expanded(child: _paymentMiniMetric('Amount', _formatMoney(totalAmount))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...selectedItems.map((item) {
                    final closeQty = planQtyById[item.id] ?? item.openQty;
                    final amount = item.amountFor(qty: closeQty, endDate: endDate);
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
                          Text(
                            item.itemName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.batchId} • Came ${_formatDate(item.startDate)} • Open ${item.openQty}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _paymentMiniMetric('Pay Qty', '$closeQty')),
                              const SizedBox(width: 8),
                              Expanded(child: _paymentMiniMetric('Keep', '${item.openQty - closeQty}')),
                              const SizedBox(width: 8),
                              Expanded(child: _paymentMiniMetric('Amount', _formatMoney(amount))),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceCard,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: () {
                                        sheetSetState(() {
                                          planQtyById[item.id] = math.max(1, closeQty - 1);
                                          _supplierPaymentCloseQtyDraft[item.id] =
                                              planQtyById[item.id]!;
                                          final updatedAmount = amountForPlan();
                                          _cashAmountController.text =
                                              updatedAmount.toStringAsFixed(0);
                                          _advanceAmountController.text =
                                              updatedAmount.toStringAsFixed(0);
                                          syncActivePlan();
                                        });
                                      },
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () {
                                        sheetSetState(() {
                                          planQtyById[item.id] =
                                              math.min(item.openQty, closeQty + 1);
                                          _supplierPaymentCloseQtyDraft[item.id] =
                                              planQtyById[item.id]!;
                                          final updatedAmount = amountForPlan();
                                          _cashAmountController.text =
                                              updatedAmount.toStringAsFixed(0);
                                          _advanceAmountController.text =
                                              updatedAmount.toStringAsFixed(0);
                                          syncActivePlan();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _supplierPaymentNoteType,
                    decoration: _inputDecoration(
                      label: 'Note Type',
                      icon: Icons.note_alt_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Manual Note', child: Text('Manual Note')),
                      DropdownMenuItem(value: 'Photo Note', child: Text('Photo Note')),
                      DropdownMenuItem(value: 'Voice Note', child: Text('Voice Note')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      sheetSetState(() {
                        _supplierPaymentNoteType = value;
                        syncActivePlan();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _supplierPaymentNoteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _inputDecoration(
                      label: _supplierPaymentNoteType == 'Manual Note'
                          ? 'Machine/object note'
                          : '${_supplierPaymentNoteType} reference / remarks',
                      hint:
                          'Example: Close machine 1, 2, 3 and keep machine 4, 5 running',
                      icon: Icons.edit_note_outlined,
                    ),
                    onChanged: (_) => syncActivePlan(),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentSection(),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _clearActiveSupplierPaymentPlan();
    });
  }

  void _completeSupplierPaymentPlan({
    required Map<String, int> qtyById,
    required DateTime endDate,
    required String paymentMethod,
    required String paymentReference,
    required String noteType,
    required String noteDetails,
  }) {
    final now = DateTime.now();

    setState(() {
      qtyById.forEach((itemId, requestedQty) {
        final index = _supplierPaymentItems.indexWhere((item) => item.id == itemId);
        if (index == -1) return;
        final item = _supplierPaymentItems[index];
        if (item.isClosed) return;

        final actualCloseQty = requestedQty.clamp(1, item.openQty).toInt();
        final amount = item.amountFor(qty: actualCloseQty, endDate: endDate);

        item.closedQty = (item.closedQty + actualCloseQty).clamp(0, item.takenQty);
        item.lastPaymentMethod = paymentMethod;
        item.paymentStatus = item.isClosed ? 'Closed' : 'Partial Open';

        final transferIndex = _transferItems.indexWhere(
          (transferItem) => transferItem.id == item.transferItemId,
        );
        if (transferIndex != -1) {
          _transferItems[transferIndex].returnedQty = item.closedQty;
        }

        _supplierPaymentHistory.insert(
          0,
          SupplierPaymentHistoryRecord(
            id: 'PAY-${now.millisecondsSinceEpoch}-${item.id}',
            supplierName: item.supplierName,
            itemName: item.itemName,
            batchId: item.batchId,
            rentalId: item.rentalId,
            startDate: item.startDate,
            endDate: endDate,
            closedQty: actualCloseQty,
            remainingQty: item.openQty,
            amount: amount,
            paymentMethod: paymentMethod,
            status: item.isClosed ? 'Closed' : 'Partial Closed',
            createdAt: now,
            paymentReference: paymentReference,
            noteType: noteType,
            noteDetails: noteDetails,
          ),
        );
      });

      _clearSupplierPaymentSelection();
    });
  }


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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  // Reusable UI (mostly unchanged)
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
    final draftItems = _currentDraftRentalItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Supplier Name & Village Name fields
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _supplierNameController,
                decoration: _inputDecoration(
                  label: 'Supplier Name',
                  hint: 'Enter supplier name',
                  icon: Icons.person_outline,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _villageNameController,
                decoration: _inputDecoration(
                  label: 'Village Name',
                  hint: 'Enter village location',
                  icon: Icons.location_city_outlined,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Equipment Type Dropdown
        DropdownButtonFormField<String>(
          value: _selectedEquipmentType,
          decoration: _inputDecoration(
            label: 'Equipment Type',
            icon: Icons.category_outlined,
          ),
          items: const [
            DropdownMenuItem(
              value: 'Machine Equipment',
              child: Text('Machine Equipment (MS)'),
            ),
            DropdownMenuItem(
              value: 'Work Equipment',
              child: Text('Work Equipment (WE)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedEquipmentType = val);
            }
          },
        ),
        const SizedBox(height: 16),

        // 3. New Feature for Adding Item (Workflow: Category/Item -> Quantity -> Price -> Day/Hour Rent Option)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.playlist_add, size: 20, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'Add Rental Item & Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _itemController,
                decoration: _inputDecoration(
                  label: 'Rental Item Name / Category',
                  hint: 'Select or enter rental item name',
                  icon: Icons.build_outlined,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _itemQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'Quantity',
                        icon: Icons.numbers,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _itemPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(
                        label: 'Price (₹)',
                        hint: 'Rent rate amount',
                        icon: Icons.currency_rupee,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Rent Unit Option',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedItemRentUnit = 'Per day'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedItemRentUnit == 'Per day'
                              ? AppTheme.primary.withOpacity(0.12)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedItemRentUnit == 'Per day'
                                ? AppTheme.primary
                                : AppTheme.border,
                            width: _selectedItemRentUnit == 'Per day' ? 1.4 : 0.8,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Per Day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _selectedItemRentUnit == 'Per day'
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _selectedItemRentUnit == 'Per day'
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedItemRentUnit = 'Per hour'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedItemRentUnit == 'Per hour'
                              ? AppTheme.primary.withOpacity(0.12)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedItemRentUnit == 'Per hour'
                                ? AppTheme.primary
                                : AppTheme.border,
                            width: _selectedItemRentUnit == 'Per hour' ? 1.4 : 0.8,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Per Hour',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _selectedItemRentUnit == 'Per hour'
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _selectedItemRentUnit == 'Per hour'
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addDraftRentalItem,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (draftItems.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Added Rental Items',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${draftItems.length} items',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...draftItems.map(_buildDraftRentalItemTile),
        ],
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _formatDate(DateTime.now()),
          readOnly: true,
          decoration: _inputDecoration(
            label: 'Check-in Date',
            icon: Icons.calendar_today_outlined,
          ),
        ),
        const SizedBox(height: 12),
        _buildRentalUploadButtons(),
      ],
    );
  }

  Widget _buildDraftRentalItemTile(RentalLineItem item) {
    final hasPrice = item.price > 0;
    final total = item.totalPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.equipmentType == 'Machine Equipment'
                  ? Icons.precision_manufacturing_outlined
                  : Icons.handyman_outlined,
              size: 20,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.equipmentType,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                    Text(
                      'Qty: ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (hasPrice)
                      Text(
                        '• ₹${item.price.toStringAsFixed(0)} / ${item.rentUnit.toLowerCase().replaceAll("per ", "")}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (hasPrice)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
            ),
          IconButton(
            onPressed: () => _removeDraftRentalItem(item),
            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
            tooltip: 'Remove item',
          ),
        ],
      ),
    );
  }

  Widget _buildRentalUploadButtons() {
    return Row(
      children: [
        Expanded(
          child: _uploadButton(
            label: _rentalOpeningPhotoPath == null
                ? 'Upload Photo'
                : 'Photo Added',
            icon: _rentalOpeningPhotoPath == null
                ? Icons.camera_alt_outlined
                : Icons.check_circle_outline,
            color: _rentalOpeningPhotoPath == null
                ? AppTheme.info
                : AppTheme.success,
            onTap: () => _toggleRentalUpload('opening_photo'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _uploadButton(
            label: _rentalBillPhotoPath == null ? 'Add Bill' : 'Bill Added',
            icon: _rentalBillPhotoPath == null
                ? Icons.receipt_long_outlined
                : Icons.check_circle_outline,
            color: _rentalBillPhotoPath == null
                ? AppTheme.warning
                : AppTheme.success,
            onTap: () => _toggleRentalUpload('rental_bill'),
          ),
        ),
      ],
    );
  }


  // This is the main advance payment UI that was replaced
  Widget _buildAdvancePayment() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Advance Request',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Request advance from finance'),
                value: _enableAdvancePayment,
                activeColor: AppTheme.success,
                onChanged: (val) =>
                    setState(() => _enableAdvancePayment = val),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  _showTransactionHistorySheet('advance'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.request_quote_outlined,
                        size: 14, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(
                      '${_advanceTransactions.length} request${_advanceTransactions.length == 1 ? "" : "s"}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        if (_enableAdvancePayment) ...[
          const SizedBox(height: 8),
          _buildAdvancePaymentSection(),
        ],
        const SizedBox(height: 12),
        _buildAdvanceRequestTable(),
      ],
    );
  }

  // Remaining helper widgets (unchanged from original)

  Widget _paymentNotice(String text, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rentalPaymentOption({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: selected ? color : AppTheme.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rentalStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _rentalProofPreview(String proofId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.success.withOpacity(0.25)),
            ),
            child: const Icon(Icons.image_outlined, size: 16, color: AppTheme.success),
          ),
          const SizedBox(width: 6),
          Text(
            proofId,
            style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelAndNotes() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Fuel Entry',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle:
              const Text('Turn on only when this rental has diesel/fuel entry'),
          value: _rentalFuelEnabled,
          activeColor: AppTheme.warning,
          onChanged: (value) => setState(() => _rentalFuelEnabled = value),
        ),
        if (_rentalFuelEnabled) ...[
          const SizedBox(height: 10),
          _buildRentalFuelEntryForm(),
        ],
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

  Widget _buildRentalFuelEntryForm() {
    const fuelTypes = ['Diesel', 'Petrol', 'Oil', 'AdBlue'];
    const stockPoints = [
      'Main Diesel Stock',
      'Site Stock Point',
      'Vehicle Tank',
      'Outside Purchase',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _rentalFuelType,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Type of Fuel',
                    icon: Icons.local_gas_station,
                  ),
                  items: fuelTypes
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _rentalFuelType = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _rentalFuelStockPoint,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Stock Point',
                    icon: Icons.location_on_outlined,
                  ),
                  items: stockPoints
                      .map((point) =>
                          DropdownMenuItem(value: point, child: Text(point)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _rentalFuelStockPoint = value);
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
                  controller: _fuelLitresController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration(
                    label: 'Liters',
                    icon: Icons.straighten,
                    suffixText: 'L',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _fuelController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration(
                    label: 'Amount',
                    icon: Icons.currency_rupee,
                    suffixText: '₹',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fuelRemarksController,
            maxLines: 2,
            decoration: _inputDecoration(
              label: 'Fuel Remarks',
              hint: 'Fuel bill, stock issue, or tank note',
              icon: Icons.notes_outlined,
            ),
          ),
        ],
      ),
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

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

// =========================
// MachineRentalDetailPage (unchanged)
// =========================

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
  State<MachineRentalDetailPage> createState() =>
      _MachineRentalDetailPageState();
}

class _MachineRentalDetailPageState extends State<MachineRentalDetailPage> {
  RentalItem get rental => widget.rental;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatMoney(num value) => '₹${value.toStringAsFixed(0)}';



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
                      subtitle:
                          'Update site, tank, field, operator, and important dates',
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
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
                            validator: (value) =>
                                value == null || value.trim().isEmpty
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
                      color: activationDate == null
                          ? AppTheme.warning
                          : AppTheme.success,
                      onTap: () async {
                        final picked =
                            await _pickDate(activationDate ?? DateTime.now());
                        if (picked != null) {
                          sheetSetState(() => activationDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _dateTile(
                      title: 'Closed date',
                      value: closingDate == null
                          ? 'Not closed yet'
                          : _formatDate(closingDate!),
                      icon: Icons.lock_outline,
                      color: closingDate == null
                          ? AppTheme.textMuted
                          : AppTheme.danger,
                      onTap: () async {
                        final picked =
                            await _pickDate(closingDate ?? DateTime.now());
                        if (picked != null) {
                          sheetSetState(() => closingDate = picked);
                        }
                      },
                      trailing: closingDate == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  sheetSetState(() => closingDate = null),
                            ),
                    ),
                    const SizedBox(height: 18),
                    _submitButton(
                      'Save Machine Flow',
                      AppTheme.primary,
                      Icons.save_outlined,
                      () {
                        if (!(formKey.currentState?.validate() ?? false))
                          return;
                        setState(() {
                          rental.siteName = siteController.text.trim();
                          rental.tankId = tankController.text.trim();
                          rental.fieldLabel =
                              fieldController.text.trim().isEmpty
                                  ? 'Field not assigned'
                                  : fieldController.text.trim();
                          rental.operatorName =
                              operatorController.text.trim().isEmpty
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
      text:
          oldLog == null || oldLog.litres == 0 ? '' : oldLog.litres.toString(),
    );
    final amountController = TextEditingController(
      text:
          oldLog == null || oldLog.amount == 0 ? '' : oldLog.amount.toString(),
    );
    final readingController =
        TextEditingController(text: oldLog?.meterReading ?? '');
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
                      title: editIndex == null
                          ? 'Add Fuel Record'
                          : 'Edit Fuel Record',
                      subtitle:
                          'Track fuel at activation, running refill, shift end, or closing',
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: _inputDecoration(
                              label: 'Fuel used / checked',
                              icon: Icons.opacity_outlined,
                              suffixText: 'L',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty)
                                return null;
                              if (double.tryParse(value) == null)
                                return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: _inputDecoration(
                              label: 'Fuel amount',
                              icon: Icons.currency_rupee,
                              suffixText: '₹',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty)
                                return 'Enter amount';
                              if (double.tryParse(value) == null)
                                return 'Invalid';
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
                      editIndex == null
                          ? 'Add Fuel Record'
                          : 'Save Fuel Record',
                      AppTheme.warning,
                      Icons.save_outlined,
                      () {
                        if (!(formKey.currentState?.validate() ?? false))
                          return;
                        final log = MachineFuelLog(
                          id: oldLog?.id ??
                              'FUL-USER-${DateTime.now().millisecondsSinceEpoch}',
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
                child: Icon(rental.machineStatus.icon,
                    color: Colors.white, size: 28),
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
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
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
              _topMetric(
                  'Rate', _formatMoney(rental.rate), Icons.currency_rupee),
              const SizedBox(width: 8),
              _topMetric('Fuel', _formatMoney(rental.totalFuelCost),
                  Icons.local_gas_station_outlined),
              const SizedBox(width: 8),
              _topMetric('Balance', _formatMoney(balance),
                  Icons.account_balance_wallet_outlined),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                child: _miniMetric(
                  'Activated',
                  rental.activationDate == null
                      ? 'Not activated'
                      : _formatDate(rental.activationDate!),
                  color: rental.activationDate == null
                      ? AppTheme.warning
                      : AppTheme.success,
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
                  rental.closingDate == null
                      ? 'Running / open'
                      : _formatDate(rental.closingDate!),
                  color: rental.closingDate == null
                      ? AppTheme.info
                      : AppTheme.danger,
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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
                    side: BorderSide(
                        color: rental.isActivated
                            ? AppTheme.success
                            : AppTheme.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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
      subtitle:
          'Activation fuel, running refill, shift-end check, and closing fuel check',
      icon: Icons.local_gas_station_outlined,
      color: AppTheme.warning,
      action: OutlinedButton.icon(
        onPressed: () => _showFuelLogSheet(),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.warning,
          side: BorderSide(color: AppTheme.warning),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: logs.isEmpty
          ? _emptyState(
              icon: Icons.local_gas_station_outlined,
              title: 'No fuel records yet',
              subtitle:
                  'Add activation fuel or shift-end fuel check for this machine.',
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
                  final realIndex =
                      rental.fuelLogs.indexWhere((item) => item.id == log.id);
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
                child: const Icon(Icons.local_gas_station_outlined,
                    color: AppTheme.warning, size: 18),
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
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted),
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
              Expanded(
                  child: _miniMetric('Litres', log.litres.toStringAsFixed(1))),
              const SizedBox(width: 8),
              Expanded(
                  child: _miniMetric('Amount', _formatMoney(log.amount),
                      color: AppTheme.warning)),
              const SizedBox(width: 8),
              Expanded(
                  child: _miniMetric('Reading',
                      log.meterReading.isEmpty ? '—' : log.meterReading)),
            ],
          ),
          if (log.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.notes,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _checkInCard() {
    final checks = [...rental.dailyCheckIns]
      ..sort((a, b) => b.date.compareTo(a.date));

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
          side: BorderSide(
              color: rental.isActivated ? AppTheme.info : AppTheme.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: checks.isEmpty
          ? _emptyState(
              icon: Icons.fact_check_outlined,
              title: 'No check-ins recorded',
              subtitle:
                  'Activate or continue the machine to create check-in history.',
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
                            check.submitted
                                ? Icons.check_circle_outline
                                : Icons.pending_actions_outlined,
                            color: check.submitted
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(check.date),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  check.note,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
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
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
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
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
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
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900),
            ),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
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
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
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
                  Text(title,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              const Icon(Icons.edit_calendar_outlined, size: 18),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

// =========================
// HodApprovalBadge (external widget used)
// =========================

class HodApprovalBadge extends StatelessWidget {
  const HodApprovalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.success.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.verified_outlined, size: 14, color: AppTheme.success),
          SizedBox(width: 4),
          Text(
            'HOD Approval',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}