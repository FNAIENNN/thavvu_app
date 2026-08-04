import 'dart:async';

import 'package:flutter/material.dart';
import '../services/hod_site_workspace_service.dart';
import '../services/attendance_context_service.dart';
import '../services/stock_inventory_repository.dart';
import '../theme/app_theme.dart';
import 'hod_module_review_screen.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class MachineSummary {
  final String id;
  final String name;
  final String type;
  final String location;
  final String dieselOption; // 'With diesel' or 'Without diesel'
  double hoursWorked;
  double fuelConsumed;
  double amountGiven;
  int workerCount;
  double retrievedFuel; // fuel retrieved when machine closed
  bool isClosed;
  String? closureDieselMode;
  String? retrievedStockPoint;
  double retrievedFuelAmount;
  double retrievedDieselRate;
  String? closureBookIdPhotoPath;

  // Transfer related fields
  bool isTransferred;
  String? transferThavvuId;
  String? transferDestination;
  DateTime? transferredAt;
  List<Map<String, dynamic>> transferHistory; // permanent records
  int transferCount;

  MachineSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.dieselOption,
    this.hoursWorked = 0,
    this.fuelConsumed = 0,
    this.amountGiven = 0,
    this.workerCount = 0,
    this.retrievedFuel = 0,
    this.isClosed = false,
    this.closureDieselMode,
    this.retrievedStockPoint,
    this.retrievedFuelAmount = 0,
    this.retrievedDieselRate = 0,
    this.closureBookIdPhotoPath,
    this.isTransferred = false,
    this.transferThavvuId,
    this.transferDestination,
    this.transferredAt,
    List<Map<String, dynamic>>? transferHistory,
    this.transferCount = 0,
  }) : transferHistory = transferHistory ?? [];

  void updateFromLog(double hours, double fuel, double amount) {
    hoursWorked = hours;
    fuelConsumed = fuel;
    amountGiven = amount;
  }

  void incrementWorkers() => workerCount++;
  void decrementWorkers() {
    if (workerCount > 0) workerCount--;
  }

  void clearWorkers() => workerCount = 0;

  /// Returns how many times the machine has been transferred (excluding re-enters).
  int get transferEventCount =>
      transferHistory.where((e) => e['type'] == 'transfer').length;

  /// Returns how many times the machine has been re-entered.
  int get reenterEventCount =>
      transferHistory.where((e) => e['type'] == 'reenter').length;

  void addTransferEvent(String thavvuId, String destination) {
    isTransferred = true;
    transferThavvuId = thavvuId;
    transferDestination = destination;
    transferredAt = DateTime.now();
    transferHistory.add({
      'type': 'transfer',
      'thavvuId': thavvuId,
      'destination': destination,
      'date': transferredAt!.toIso8601String(),
    });
    transferCount++;
  }

  void addReenterEvent() {
    isTransferred = false;
    transferThavvuId = null;
    transferDestination = null;
    transferredAt = null;
    transferHistory.add({
      'type': 'reenter',
      'date': DateTime.now().toIso8601String(),
    });
    transferCount++;
  }
}

class PaymentTransaction {
  final String id;
  final String type; // 'cash' | 'advance'
  final double amount;
  final String method;
  final DateTime date;
  final String status; // Completed, Cancelled, Requested, Approved, Rejected
  final String? note;
  final String? billImagePath;
  final String? machineId;
  final String? machineName;
  final String? paymentProof;
  final bool registeredInMachineIdsBook;

  PaymentTransaction({
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

  PaymentTransaction copyWith({
    String? id,
    String? type,
    double? amount,
    String? method,
    DateTime? date,
    String? status,
    String? note,
    String? billImagePath,
    String? machineId,
    String? machineName,
    String? paymentProof,
    bool? registeredInMachineIdsBook,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      date: date ?? this.date,
      status: status ?? this.status,
      note: note ?? this.note,
      billImagePath: billImagePath ?? this.billImagePath,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      paymentProof: paymentProof ?? this.paymentProof,
      registeredInMachineIdsBook:
          registeredInMachineIdsBook ?? this.registeredInMachineIdsBook,
    );
  }
}

class MachineLogRecord {
  final String id;
  final DateTime date;
  final String machineId;
  final String machineName;
  final String type;
  final String status;
  final double amount;
  final Map<String, String> details;

  const MachineLogRecord({
    required this.id,
    required this.date,
    required this.machineId,
    required this.machineName,
    required this.type,
    required this.status,
    required this.amount,
    required this.details,
  });
}

class DieselLogEntry {
  final String id;
  final String fuelType;
  final String stockPoint;
  final double liters;
  final String remarks;
  final DateTime createdAt;

  const DieselLogEntry({
    required this.id,
    required this.fuelType,
    required this.stockPoint,
    required this.liters,
    required this.createdAt,
    this.remarks = '',
  });

  DieselLogEntry copyWith({
    String? id,
    String? fuelType,
    String? stockPoint,
    double? liters,
    String? remarks,
    DateTime? createdAt,
  }) {
    return DieselLogEntry(
      id: id ?? this.id,
      fuelType: fuelType ?? this.fuelType,
      stockPoint: stockPoint ?? this.stockPoint,
      liters: liters ?? this.liters,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class DailyDataScreen extends StatefulWidget {
  final bool isHOD;

  const DailyDataScreen({super.key, this.isHOD = false});

  @override
  State<DailyDataScreen> createState() => _DailyDataScreenState();
}

class _DailyDataScreenState extends State<DailyDataScreen>
    with SingleTickerProviderStateMixin {
  final StockInventoryRepository _stockRepository = StockInventoryRepository();
  final AttendanceContextService _contextService = AttendanceContextService();

  final List<Map<String, String>> _machines = [
    {
      'id': 'MCH-001',
      'name': 'Excavator',
      'type': 'Heavy',
      'location': 'Site A',
      'dieselOption': 'With diesel',
      'isArchived': 'false',
      'betaEnabled': 'true',
      'betaRequiredHours': '8',
    },
    {
      'id': 'MCH-002',
      'name': 'Loader',
      'type': 'Medium',
      'location': 'Site A',
      'dieselOption': 'With diesel',
      'isArchived': 'false',
      'betaEnabled': 'true',
      'betaRequiredHours': '8',
    },
    {
      'id': 'MCH-003',
      'name': 'Crane',
      'type': 'Heavy',
      'location': 'Site B',
      'dieselOption': 'With diesel',
      'isArchived': 'false',
      'betaEnabled': 'true',
      'betaRequiredHours': '8',
    },
    {
      'id': 'MCH-004',
      'name': 'Dump Truck',
      'type': 'Medium',
      'location': 'Site B',
      'dieselOption': 'With diesel',
      'isArchived': 'false',
      'betaEnabled': 'true',
      'betaRequiredHours': '8',
    },
    {
      'id': 'MCH-005',
      'name': 'Compactor',
      'type': 'Light',
      'location': 'Site C',
      'dieselOption': 'Without diesel',
      'isArchived': 'false',
      'betaEnabled': 'true',
      'betaRequiredHours': '8',
    },
  ];

  Map<String, MachineSummary> _machineSummaries = {};
  bool _showMachineList = true;
  String? _currentMachineIdForDetail;
  bool _showArchived = false;
  late final TabController _mainTabController;
  final TextEditingController _machineSearchController =
      TextEditingController();
  final TextEditingController _historySearchController =
      TextEditingController();
  String _historyTypeFilter = 'All';
  String _historyDateFilter = 'All';

  // Detail form state
  final List<TimeBlock> _timeBlocks = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  // Cash payment
  bool _enableCashPayment = false;
  final TextEditingController _cashAmountController = TextEditingController();
  final double _cashLimit = 50000.0;
  double _cashBalance = 200000.0;

  // Advance payment
  bool _enableAdvancePayment = false;
  final TextEditingController _advanceAmountController =
      TextEditingController();
  String? _selectedAdvanceMode;
  String? _selectedEntryMethod;

  // Bank manual details
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _accNumController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();

  // Saved UPI accounts
  final List<Map<String, String>> _savedAccounts = [
    {
      'id': '1',
      'accountNumber': '****7890',
      'upiId': 'machine@bank',
      'bankName': 'State Bank',
      'ifsc': 'SBIN0001234',
      'type': 'primary',
    },
    {
      'id': '2',
      'accountNumber': '****5432',
      'upiId': 'operator@upi',
      'bankName': 'HDFC Bank',
      'ifsc': 'HDFC0004321',
      'type': 'secondary',
    },
  ];
  String? _selectedPaymentAccount;

  // Saved bank accounts
  final List<Map<String, String>> _savedBankAccounts = [
    {
      'id': 'B1',
      'accountNumber': '****4567',
      'bankName': 'State Bank of India',
      'ifsc': 'SBIN0001234',
      'holderName': 'Ravi Kumar',
      'type': 'primary',
    },
    {
      'id': 'B2',
      'accountNumber': '****8901',
      'bankName': 'HDFC Bank',
      'ifsc': 'HDFC0004321',
      'holderName': 'Site Operator',
      'type': 'secondary',
    },
  ];
  String? _selectedBankAccount;

  // Diesel
  late String _dieselOption;
  final TextEditingController _dieselController = TextEditingController();
  dynamic _dieselConsumptionData;
  final List<DieselLogEntry> _dieselLogEntries = [];

  // Editable diesel-entry form state
  String? _selectedDieselFuelType;
  String? _selectedDieselStockPoint;
  final TextEditingController _dieselLitresEntryController =
      TextEditingController();
  final TextEditingController _dieselRemarksEntryController =
      TextEditingController();
  String? _editingDieselEntryId;

  // Beta
  bool _isBetaEligible = false;
  bool _enableExtraBeta = false;
  final TextEditingController _betaController = TextEditingController();
  final TextEditingController _extraBetaController = TextEditingController();
  final TextEditingController _extraBetaNoteController =
      TextEditingController();
  double _totalWorkingHours = 0.0;
  final double _betaRequiredHours = 8.0;
  final Set<String> _betaEligibleMachines = {
    'MCH-001',
    'MCH-002',
    'MCH-003',
    'MCH-004',
    'MCH-005'
  };

  // Workers
  int _currentWorkerCount = 0;

  // ── FIX 3: Single general bill upload — placed after Workers section ──
  String? _generalBillFileName;

  // Payment transaction history
  final List<PaymentTransaction> _cashTransactions = [
    PaymentTransaction(
      id: 'TXN-001',
      type: 'cash',
      amount: 5000,
      method: 'Cash',
      date: DateTime.now().subtract(const Duration(days: 2)),
      note: 'Daily wages',
    ),
    PaymentTransaction(
      id: 'TXN-002',
      type: 'cash',
      amount: 8000,
      method: 'Cash',
      date: DateTime.now().subtract(const Duration(days: 1)),
      note: 'Material purchase',
    ),
  ];
  final List<PaymentTransaction> _advanceTransactions = [
    PaymentTransaction(
      id: 'ADV-001',
      type: 'advance',
      amount: 15000,
      method: 'UPI',
      date: DateTime.now().subtract(const Duration(days: 3)),
      status: 'Requested',
      note: 'Operator advance',
    ),
  ];

  final List<MachineLogRecord> _historyLogs = [];

  final List<String> _historyTypeOptions = const [
    'All',
    'Daily Log',
    'Cash Payment',
    'Advance Request',
    'Machine Transfer',
    'Machine Re-enter',
    'Machine Closure',
    'Machine Reopen',
    'Machine Archive',
    'Machine Reactivate',
    'Worker Update',
    'Bill Upload',
  ];

  final List<String> _stockPoints = [
    'Site A — North',
    'Site B — South',
    'Warehouse Main',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _machineSearchController.addListener(() => setState(() {}));
    _historySearchController.addListener(() => setState(() {}));
    for (var machine in _machines) {
      _machineSummaries[machine['id']!] = MachineSummary(
        id: machine['id']!,
        name: machine['name']!,
        type: machine['type']!,
        location: machine['location']!,
        dieselOption: machine['dieselOption']!,
      );
    }
    _timeBlocks.add(TimeBlock(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: const TimeOfDay(hour: 8, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ));
    _seedInitialHistoryLogs();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _machineSearchController.dispose();
    _historySearchController.dispose();
    _cashAmountController.dispose();
    _advanceAmountController.dispose();
    _dieselController.dispose();
    _dieselLitresEntryController.dispose();
    _dieselRemarksEntryController.dispose();
    _betaController.dispose();
    _extraBetaController.dispose();
    _extraBetaNoteController.dispose();
    _notesController.dispose();
    _ifscController.dispose();
    _accNumController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Map<String, String>? get _currentMachineDetail {
    if (_currentMachineIdForDetail == null) return null;
    return _machines.firstWhere((m) => m['id'] == _currentMachineIdForDetail);
  }

  void _seedInitialHistoryLogs() {
    if (_historyLogs.isNotEmpty) return;
    for (final txn in _cashTransactions) {
      _historyLogs.add(
        MachineLogRecord(
          id: 'LOG-${txn.id}',
          date: txn.date,
          machineId: txn.machineId ?? '-',
          machineName: txn.machineName ?? 'Previous cash entry',
          type: 'Cash Payment',
          status: txn.status,
          amount: txn.amount,
          details: {
            'Cash Payment ID': txn.id,
            'Method': txn.method,
            'Status': txn.status,
            'Note': txn.note ?? '-',
          },
        ),
      );
    }
    for (final txn in _advanceTransactions) {
      _historyLogs.add(
        MachineLogRecord(
          id: 'LOG-${txn.id}',
          date: txn.date,
          machineId: txn.machineId ?? '-',
          machineName: txn.machineName ?? 'Previous advance request',
          type: 'Advance Request',
          status: txn.status,
          amount: txn.amount,
          details: {
            'Request Payment ID': txn.id,
            'Method': txn.method,
            'Status': txn.status,
            'Payment Proof': txn.paymentProof ?? 'Auto proof pending',
            'Registered in Machine IDs Book':
                txn.registeredInMachineIdsBook ? 'Yes' : 'No',
            'Note': txn.note ?? '-',
          },
        ),
      );
    }
    _historyLogs.sort((a, b) => b.date.compareTo(a.date));
  }

  String _formatCompactDateTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  String _formatTimeOnly(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  String _machineDisplayName(String? machineId) {
    if (machineId == null || machineId == '-') return 'No machine linked';
    final machine = _machines.firstWhere(
      (m) => m['id'] == machineId,
      orElse: () => const <String, String>{},
    );
    if (machine.isEmpty) return machineId;
    return '${machine['name']} (${machine['id']})';
  }

  String _dateKey(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _historyDateTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(date.year, date.month, date.day);
    if (logDay == today) return 'Today';
    if (logDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return _dateKey(date);
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Map<DateTime, List<MachineLogRecord>> _groupLogsByDate(
      List<MachineLogRecord> logs) {
    final grouped = <DateTime, List<MachineLogRecord>>{};
    for (final log in logs) {
      final key = _dayOnly(log.date);
      grouped.putIfAbsent(key, () => <MachineLogRecord>[]).add(log);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }
    return grouped;
  }

  double get _dieselConsumptionTotalLitres {
    return _dieselLogEntries.fold<double>(
        0, (sum, entry) => sum + entry.liters);
  }

  String get _dieselLogRowsText {
    if (_dieselLogEntries.isEmpty) return '-';
    return _dieselLogEntries
        .map((entry) =>
            '${entry.fuelType} • ${entry.stockPoint} • ${entry.liters.toStringAsFixed(1)} litres${entry.remarks.isEmpty ? '' : ' • ${entry.remarks}'}')
        .join(' | ');
  }

  double _dieselRateForStockPoint(String? stockPoint) {
    switch (stockPoint) {
      case 'Main Depot':
        return 96.50;
      case 'Site A':
        return 97.00;
      case 'Site B':
        return 98.25;
      case 'Warehouse 1':
        return 95.75;
      case 'Fuel Station 3':
        return 99.00;
      default:
        return 96.50;
    }
  }

  String _numberText(double value) {
    if (value.truncateToDouble() == value) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  void _addHistoryLog({
    required String type,
    required String status,
    required double amount,
    required Map<String, String> details,
    String? machineId,
    String? machineName,
    DateTime? date,
  }) {
    final logDate = date ?? DateTime.now();
    final resolvedMachineId = machineId ?? _currentMachineIdForDetail ?? '-';
    final resolvedMachineName = machineName ??
        _currentMachineDetail?['name'] ??
        _machineDisplayName(resolvedMachineId);
    _historyLogs.insert(
      0,
      MachineLogRecord(
        id: 'LOG-${logDate.microsecondsSinceEpoch}',
        date: logDate,
        machineId: resolvedMachineId,
        machineName: resolvedMachineName,
        type: type,
        status: status,
        amount: amount,
        details: details,
      ),
    );
  }

  PaymentTransaction _createCashPaymentTransaction(double cashAmount,
      {String? note}) {
    final now = DateTime.now();
    final txn = PaymentTransaction(
      id: 'CSH-${now.millisecondsSinceEpoch}',
      type: 'cash',
      amount: cashAmount,
      method: 'Cash',
      date: now,
      status: 'Completed',
      note: note,
      machineId: _currentMachineIdForDetail,
      machineName: _currentMachineDetail?['name'],
    );
    _cashTransactions.insert(0, txn);
    _cashBalance -= cashAmount;
    _addHistoryLog(
      type: 'Cash Payment',
      status: txn.status,
      amount: txn.amount,
      machineId: txn.machineId,
      machineName: txn.machineName,
      date: txn.date,
      details: {
        'Cash Payment ID': txn.id,
        'Payment Time': _formatCompactDateTime(txn.date),
        'Amount': '₹${txn.amount.toStringAsFixed(0)}',
        'Method': txn.method,
        'Machine': txn.machineName ?? '-',
        'Note': txn.note ?? '-',
      },
    );
    return txn;
  }

  PaymentTransaction _createAdvanceRequestTransaction(double advanceAmount,
      {String? note}) {
    final now = DateTime.now();
    final advMethod = _selectedAdvanceMode == 'upi'
        ? 'UPI'
        : (_selectedBankAccount != null ? 'Bank (saved)' : 'Bank (manual)');
    final txn = PaymentTransaction(
      id: 'REQ-${now.millisecondsSinceEpoch}',
      type: 'advance',
      amount: advanceAmount,
      method: advMethod,
      date: now,
      status: 'Requested',
      note: note,
      machineId: _currentMachineIdForDetail,
      machineName: _currentMachineDetail?['name'],
      registeredInMachineIdsBook: false,
    );
    _advanceTransactions.insert(0, txn);
    _addHistoryLog(
      type: 'Advance Request',
      status: txn.status,
      amount: txn.amount,
      machineId: txn.machineId,
      machineName: txn.machineName,
      date: txn.date,
      details: {
        'Request Payment ID': txn.id,
        'Payment Request Time': _formatCompactDateTime(txn.date),
        'Amount': '₹${txn.amount.toStringAsFixed(0)}',
        'Payment Status': txn.status,
        'Payment Proof': 'Visible after request completion',
        'Registered in Machine IDs Book': 'Available after request completion',
        'Method': txn.method,
        'Machine': txn.machineName ?? '-',
        'Note': txn.note ?? '-',
      },
    );
    return txn;
  }

  void _showEditCashPaymentSheet(PaymentTransaction txn) {
    final amountController = TextEditingController(
      text: txn.amount
          .toStringAsFixed(txn.amount.truncateToDouble() == txn.amount ? 0 : 2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Edit Cash Amount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${txn.id} • ${_formatCompactDateTime(txn.date)}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cash Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final newAmount =
                        double.tryParse(amountController.text.trim()) ?? 0;
                    if (newAmount <= 0) {
                      _showSnackbar(
                          'Enter a valid cash amount', AppTheme.warning);
                      return;
                    }
                    if (newAmount > _cashLimit) {
                      _showSnackbar(
                        'Amount exceeds HOD cash limit (₹${_cashLimit.toStringAsFixed(0)})',
                        AppTheme.danger,
                      );
                      return;
                    }
                    final difference = newAmount - txn.amount;
                    if (difference > _cashBalance) {
                      _showSnackbar('Insufficient cash balance for this edit',
                          AppTheme.danger);
                      return;
                    }
                    setState(() {
                      final index =
                          _cashTransactions.indexWhere((t) => t.id == txn.id);
                      if (index != -1) {
                        _cashTransactions[index] =
                            txn.copyWith(amount: newAmount);
                        _cashBalance -= difference;
                      }
                      _addHistoryLog(
                        type: 'Cash Payment',
                        status: 'Edited',
                        amount: newAmount,
                        machineId: txn.machineId,
                        machineName: txn.machineName,
                        details: {
                          'Cash Payment ID': txn.id,
                          'Edited Time': _formatCompactDateTime(DateTime.now()),
                          'Old Amount': '₹${txn.amount.toStringAsFixed(0)}',
                          'New Amount': '₹${newAmount.toStringAsFixed(0)}',
                          'Method': txn.method,
                          'Machine': txn.machineName ?? '-',
                        },
                      );
                    });
                    Navigator.pop(context);
                    _showSnackbar(
                        'Cash payment amount updated.', AppTheme.success);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Amount'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppTheme.info),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _completeRequestedAdvance(PaymentTransaction txn) {
    if (txn.status == 'Completed') return;
    final now = DateTime.now();
    final proof = 'FIN-PROOF-${txn.id}-${now.millisecondsSinceEpoch}';
    setState(() {
      final index = _advanceTransactions.indexWhere((t) => t.id == txn.id);
      if (index != -1) {
        _advanceTransactions[index] = txn.copyWith(
          status: 'Completed',
          paymentProof: proof,
        );
      }
      _addHistoryLog(
        type: 'Advance Request',
        status: 'Request Completed',
        amount: txn.amount,
        machineId: txn.machineId,
        machineName: txn.machineName,
        details: {
          'Request Payment ID': txn.id,
          'Request Completion Time': _formatCompactDateTime(now),
          'Amount': '₹${txn.amount.toStringAsFixed(0)}',
          'Payment Proof': proof,
          'Registered in Machine IDs Book':
              txn.registeredInMachineIdsBook ? 'Yes' : 'No',
          'Method': txn.method,
          'Machine': txn.machineName ?? '-',
        },
      );
    });
    _showSnackbar('Request ${txn.id} marked as completed.', AppTheme.success);
  }

  void _toggleAdvanceMachineBook(PaymentTransaction txn, bool value) {
    if (txn.status != 'Completed') {
      _showSnackbar(
          'Machine IDs Book can be updated only after request completion.',
          AppTheme.warning);
      return;
    }
    setState(() {
      final index = _advanceTransactions.indexWhere((t) => t.id == txn.id);
      if (index != -1) {
        final current = _advanceTransactions[index];
        _advanceTransactions[index] =
            current.copyWith(registeredInMachineIdsBook: value);
        _addHistoryLog(
          type: 'Advance Request',
          status: 'Book Updated',
          amount: current.amount,
          machineId: current.machineId,
          machineName: current.machineName,
          details: {
            'Request Payment ID': current.id,
            'Registered in Machine IDs Book': value ? 'Yes' : 'No',
            'Payment Status': current.status,
            'Payment Proof': current.paymentProof ?? 'Request proof pending',
          },
        );
      }
    });
  }

  // ── Machine-list actions ──────────────────────────────────────────────────

  // ── FIX 2: Block worker increment when machine is in transferred state ──
  void _incrementWorkerCount(String machineId) {
    final summary = _machineSummaries[machineId];
    if (summary == null) return;
    if (summary.isClosed) {
      _showSnackbar('Machine is closed. Reopen it before adding workers.',
          AppTheme.warning);
      return;
    }
    if (summary.isTransferred) {
      _showSnackbar(
          'Machine is transferred. Re-enter it before adding workers.',
          AppTheme.warning);
      return;
    }
    setState(() {
      summary.incrementWorkers();
      _addHistoryLog(
        type: 'Worker Update',
        status: 'Worker Added',
        amount: 0,
        machineId: machineId,
        machineName: summary.name,
        details: {
          'Machine ID': machineId,
          'Worker Count': summary.workerCount.toString(),
          'Action': 'Added from machine card',
        },
      );
    });
  }

  void _decrementWorkerCount(String machineId) {
    final summary = _machineSummaries[machineId];
    if (summary == null) return;
    if (summary.isClosed) {
      _showSnackbar('Machine is closed. Reopen it before removing workers.',
          AppTheme.warning);
      return;
    }
    if (summary.isTransferred) {
      _showSnackbar(
          'Machine is transferred. Re-enter it before removing workers.',
          AppTheme.warning);
      return;
    }
    if (summary.workerCount <= 0) return;
    setState(() {
      summary.decrementWorkers();
      _addHistoryLog(
        type: 'Worker Update',
        status: 'Worker Removed',
        amount: 0,
        machineId: machineId,
        machineName: summary.name,
        details: {
          'Machine ID': machineId,
          'Worker Count': summary.workerCount.toString(),
          'Action': 'Removed from machine card',
        },
      );
    });
  }

  void _showMachineOptions(String machineId) {
    final machine = _machines.firstWhere((m) => m['id'] == machineId);
    final isArchived = machine['isArchived'] == 'true';
    final summary = _machineSummaries[machineId]!;
    final isClosed = summary.isClosed;
    final isTransferred = summary.isTransferred;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isArchived) ...[
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: AppTheme.info),
                title: const Text('Log Data Entry'),
                subtitle: const Text('Record hours, fuel & payments'),
                enabled: !isTransferred && !isClosed,
                onTap: (isTransferred || isClosed)
                    ? null
                    : () {
                        Navigator.pop(context);
                        _openLogDetail(machineId);
                      },
              ),
              if (isClosed) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock_open, color: AppTheme.success),
                  title: const Text('Reopen Machine'),
                  subtitle: const Text('Allow operations again'),
                  onTap: () {
                    Navigator.pop(context);
                    _reopenMachine(machineId);
                  },
                ),
              ] else ...[
                const Divider(),
                ListTile(
                  leading:
                      const Icon(Icons.lock_outline, color: AppTheme.warning),
                  title: const Text('Close Machine'),
                  subtitle: const Text('Retrieve fuel & end operations'),
                  enabled: !isTransferred,
                  onTap: isTransferred
                      ? null
                      : () {
                          Navigator.pop(context);
                          _showCloseMachineSheet(machineId);
                        },
                ),
              ],
              if (!isTransferred && !isClosed) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: AppTheme.info),
                  title: const Text('Transfer Machine'),
                  subtitle:
                      const Text('Move to another site (Thavvu ID required)'),
                  onTap: () {
                    Navigator.pop(context);
                    _showTransferSheet(machineId);
                  },
                ),
              ],
              if (isTransferred) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.assignment_return,
                      color: AppTheme.success),
                  title: const Text('Re-enter Machine'),
                  subtitle: const Text('Machine has returned to site'),
                  onTap: () {
                    Navigator.pop(context);
                    _reenterMachine(machineId);
                  },
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.archive_outlined,
                    color: AppTheme.textSecondary),
                title: const Text('Archive Machine'),
                subtitle: const Text('Move to archive (can be restored later)'),
                onTap: () {
                  Navigator.pop(context);
                  _archiveMachine(machineId);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.unarchive, color: AppTheme.success),
                title: const Text('Reactivate Machine'),
                subtitle: const Text('Move back to active list'),
                onTap: () {
                  Navigator.pop(context);
                  _reactivateMachine(machineId);
                },
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.delete_forever, color: AppTheme.danger),
                title: const Text('Delete Permanently'),
                subtitle: const Text('This action cannot be undone'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMachine(machineId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _archiveMachine(String machineId) {
    final summary = _machineSummaries[machineId];
    setState(() {
      _machines.firstWhere((m) => m['id'] == machineId)['isArchived'] = 'true';
      _addHistoryLog(
        type: 'Machine Archive',
        status: 'Archived',
        amount: 0,
        machineId: machineId,
        machineName: summary?.name,
        details: {'Machine ID': machineId, 'Action': 'Archived'},
      );
    });
    _showSnackbar('Machine archived', AppTheme.info);
  }

  void _reactivateMachine(String machineId) {
    final summary = _machineSummaries[machineId];
    setState(() {
      _machines.firstWhere((m) => m['id'] == machineId)['isArchived'] = 'false';
      _addHistoryLog(
        type: 'Machine Reactivate',
        status: 'Reactivated',
        amount: 0,
        machineId: machineId,
        machineName: summary?.name,
        details: {'Machine ID': machineId, 'Action': 'Reactivated'},
      );
    });
    _showSnackbar('Machine reactivated', AppTheme.success);
  }

  void _reopenMachine(String machineId) {
    final summary = _machineSummaries[machineId];
    setState(() {
      final item = _machineSummaries[machineId];
      if (item != null) {
        item.isClosed = false;
        item.retrievedFuel = 0;
        item.retrievedFuelAmount = 0;
        item.retrievedDieselRate = 0;
        item.retrievedStockPoint = null;
        item.closureBookIdPhotoPath = null;
        item.closureDieselMode = null;
      }
      _addHistoryLog(
        type: 'Machine Reopen',
        status: 'Reopened',
        amount: 0,
        machineId: machineId,
        machineName: summary?.name,
        details: {'Machine ID': machineId, 'Action': 'Reopened'},
      );
    });
    _showSnackbar(
        'Machine reopened and ready for operations', AppTheme.success);
  }

  void _confirmDeleteMachine(String machineId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Machine?'),
        content: const Text(
            'This will permanently remove the machine and all its data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMachinePermanently(machineId);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteMachinePermanently(String machineId) {
    setState(() {
      _machines.removeWhere((m) => m['id'] == machineId);
      _machineSummaries.remove(machineId);
    });
    _showSnackbar('Machine permanently deleted', AppTheme.danger);
  }

  void _showTransferSheet(String machineId) {
    final machine = _machines.firstWhere((m) => m['id'] == machineId);
    final thavvuCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final transferLitresCtrl = TextEditingController(text: '0');
    String dieselMode = 'With diesel';
    String? selectedStockPoint =
        _stockPoints.isNotEmpty ? _stockPoints.first : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, sheetSetState) {
          final transferLitres =
              double.tryParse(transferLitresCtrl.text.trim()) ?? 0;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transfer Machine',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBg,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppTheme.info.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Machine ID',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                                '${machine['id']} • ${machine['name']} • ${machine['type']}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800)),
                            Text(machine['location'] ?? '-',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: thavvuCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Thavvu ID *',
                          hintText: 'e.g., THV-2026',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: destCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Destination / Remarks',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDieselModeCard(
                              title: 'With diesel',
                              subtitle: 'No retrieval details needed',
                              icon: Icons.local_gas_station,
                              color: AppTheme.info,
                              selected: dieselMode == 'With diesel',
                              onTap: () => sheetSetState(
                                  () => dieselMode = 'With diesel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDieselModeCard(
                              title: 'Without diesel',
                              subtitle: 'Enter retrieved diesel details',
                              icon: Icons.block_outlined,
                              color: AppTheme.warning,
                              selected: dieselMode == 'Without diesel',
                              onTap: () => sheetSetState(
                                  () => dieselMode = 'Without diesel'),
                            ),
                          ),
                        ],
                      ),
                      if (dieselMode == 'Without diesel') ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.warning.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Retrieved diesel details',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.warning)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: selectedStockPoint,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Stock Point',
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                ),
                                items: _stockPoints
                                    .map((point) => DropdownMenuItem<String>(
                                        value: point, child: Text(point)))
                                    .toList(),
                                onChanged: (value) => sheetSetState(
                                    () => selectedStockPoint = value),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: transferLitresCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'No. of litres',
                                  prefixIcon: Icon(Icons.opacity_outlined),
                                  suffixText: 'litres',
                                ),
                                onChanged: (_) => sheetSetState(() {}),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  'Retrieved: ${transferLitres.toStringAsFixed(1)} litres',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (thavvuCtrl.text.trim().isEmpty) {
                              _showSnackbar(
                                  'Thavvu ID is required', AppTheme.warning);
                              return;
                            }
                            if (dieselMode == 'Without diesel' &&
                                transferLitres < 0) {
                              _showSnackbar(
                                  'Retrieved diesel litres cannot be negative',
                                  AppTheme.warning);
                              return;
                            }
                            setState(() {
                              final destination = destCtrl.text.trim().isEmpty
                                  ? 'Not specified'
                                  : destCtrl.text.trim();
                              _machineSummaries[machineId]?.addTransferEvent(
                                  thavvuCtrl.text.trim(), destination);
                              _addHistoryLog(
                                type: 'Machine Transfer',
                                status: 'Transferred',
                                amount: 0,
                                machineId: machineId,
                                machineName: _machineSummaries[machineId]?.name,
                                details: {
                                  'Machine ID': machineId,
                                  'Thavvu ID': thavvuCtrl.text.trim(),
                                  'Destination': destination,
                                  'Diesel Mode': dieselMode,
                                  'Retrieved Diesel': dieselMode ==
                                          'Without diesel'
                                      ? '${transferLitres.toStringAsFixed(1)} litres'
                                      : '-',
                                  'Stock Point': dieselMode == 'Without diesel'
                                      ? (selectedStockPoint ?? '-')
                                      : '-',
                                  'Transfer Time':
                                      _formatCompactDateTime(DateTime.now()),
                                },
                              );
                            });
                            Navigator.pop(ctx);
                            _showSnackbar('Machine transferred successfully',
                                AppTheme.success);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.info,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Confirm Transfer',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _reenterMachine(String machineId) {
    final summary = _machineSummaries[machineId];
    setState(() {
      _machineSummaries[machineId]?.addReenterEvent();
      _addHistoryLog(
        type: 'Machine Re-enter',
        status: 'Re-entered',
        amount: 0,
        machineId: machineId,
        machineName: summary?.name,
        details: {
          'Machine ID': machineId,
          'Re-enter Time': _formatCompactDateTime(DateTime.now()),
        },
      );
    });
    _showSnackbar('Machine re-entered to site', AppTheme.success);
  }

  void _openLogDetail(String machineId) {
    final summary = _machineSummaries[machineId];
    if (summary == null) return;
    if (summary.isClosed) {
      _showSnackbar('Machine is closed. Reopen it before entering log data.',
          AppTheme.warning);
      return;
    }
    if (summary.isTransferred) {
      _showSnackbar(
          'Machine is transferred. Re-enter it before entering log data.',
          AppTheme.warning);
      return;
    }
    setState(() {
      _currentMachineIdForDetail = machineId;
      _showMachineList = false;
      _resetFormFields();
      _dieselOption = summary.dieselOption;
      _currentWorkerCount = summary.workerCount;
      _calculateWorkingHours();
      _checkBetaEligibility();
    });
  }

  void _showCloseMachineSheet(String machineId) {
    final machine = _machines.firstWhere((m) => m['id'] == machineId);
    final summary = _machineSummaries[machineId];
    final retrievedController = TextEditingController(text: '0');
    String dieselMode = summary?.dieselOption ?? 'With diesel';
    String? selectedStockPoint =
        _stockPoints.isNotEmpty ? _stockPoints.first : null;
    String? bookIdPhotoPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, sheetSetState) {
          final litres = double.tryParse(retrievedController.text.trim()) ?? 0;
          final rate = _dieselRateForStockPoint(selectedStockPoint);
          final amount = dieselMode == 'With diesel' ? litres * rate : 0.0;

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Retrieve Fuel',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${machine['id']} • ${machine['name']} • ${machine['location']}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDieselModeCard(
                              title: 'With diesel',
                              subtitle:
                                  'Show stock, rate, INR and book ID photo',
                              icon: Icons.local_gas_station,
                              color: AppTheme.info,
                              selected: dieselMode == 'With diesel',
                              onTap: () => sheetSetState(
                                  () => dieselMode = 'With diesel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDieselModeCard(
                              title: 'Without diesel',
                              subtitle: 'Stock point and retrieved litres',
                              icon: Icons.block_outlined,
                              color: AppTheme.warning,
                              selected: dieselMode == 'Without diesel',
                              onTap: () => sheetSetState(
                                  () => dieselMode = 'Without diesel'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedStockPoint,
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
                            sheetSetState(() => selectedStockPoint = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: retrievedController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'No. of litres retrieved',
                          prefixIcon: Icon(Icons.opacity_outlined),
                          suffixText: 'litres',
                        ),
                        onChanged: (_) => sheetSetState(() {}),
                      ),
                      if (dieselMode == 'With diesel') ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.infoBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.info.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Retrieved diesel value',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.info),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildTinyMetric('Fuel',
                                          '${litres.toStringAsFixed(1)} litres')),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _buildTinyMetric('Bought Rate',
                                          '₹${rate.toStringAsFixed(2)}/L')),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _buildTinyMetric('Amount',
                                          '₹${amount.toStringAsFixed(0)}')),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Rate is taken from the selected stock point purchase price.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            sheetSetState(() {
                              bookIdPhotoPath =
                                  'book_id_${machineId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            });
                          },
                          icon: Icon(bookIdPhotoPath == null
                              ? Icons.camera_alt_outlined
                              : Icons.check_circle_outline),
                          label: Text(bookIdPhotoPath == null
                              ? 'Capture Book ID Photo'
                              : 'Book ID Photo Captured'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: bookIdPhotoPath == null
                                ? AppTheme.info
                                : AppTheme.success,
                            side: BorderSide(
                                color: bookIdPhotoPath == null
                                    ? AppTheme.info
                                    : AppTheme.success),
                            padding: const EdgeInsets.symmetric(
                                vertical: 13, horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.warning.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Retrieved fuel record',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.warning),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildTinyMetric('Stock Point',
                                          selectedStockPoint ?? '-')),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _buildTinyMetric('Fuel',
                                          '${litres.toStringAsFixed(1)} litres')),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Without-diesel closure stores stock point and retrieved litres only. No INR amount or book ID photo is required.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final retrievedLitres = double.tryParse(
                                    retrievedController.text.trim()) ??
                                0;
                            if (retrievedLitres < 0) {
                              _showSnackbar(
                                  'Retrieved litres cannot be negative',
                                  AppTheme.warning);
                              return;
                            }
                            if (dieselMode == 'With diesel' &&
                                bookIdPhotoPath == null) {
                              _showSnackbar(
                                  'Capture Book ID photo for with-diesel machine closure',
                                  AppTheme.warning);
                              return;
                            }
                            setState(() {
                              final item = _machineSummaries[machineId]!;
                              item.isClosed = true;
                              item.retrievedFuel = retrievedLitres;
                              item.closureDieselMode = dieselMode;
                              item.retrievedStockPoint = selectedStockPoint;
                              item.retrievedDieselRate =
                                  dieselMode == 'With diesel' ? rate : 0;
                              item.retrievedFuelAmount = amount;
                              item.closureBookIdPhotoPath = bookIdPhotoPath;
                              _addHistoryLog(
                                type: 'Machine Closure',
                                status: 'Closed',
                                amount: amount,
                                machineId: machineId,
                                machineName: item.name,
                                details: {
                                  'Machine ID': machineId,
                                  'Machine': item.name,
                                  'Diesel Mode': dieselMode,
                                  'Stock Point': selectedStockPoint ?? '-',
                                  'Retrieved Fuel':
                                      '${retrievedLitres.toStringAsFixed(1)} litres',
                                  'Bought Rate': dieselMode == 'With diesel'
                                      ? '₹${rate.toStringAsFixed(2)}/L'
                                      : '-',
                                  'Retrieved Amount':
                                      dieselMode == 'With diesel'
                                          ? '₹${amount.toStringAsFixed(0)}'
                                          : '-',
                                  'Book ID Photo': bookIdPhotoPath ?? '-',
                                  'Closure Time':
                                      _formatCompactDateTime(DateTime.now()),
                                },
                              );
                            });
                            Navigator.pop(context);
                            _showSnackbar(
                                'Machine closed. Retrieved ${retrievedLitres.toStringAsFixed(1)} litres recorded.',
                                AppTheme.success);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warning,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Submit Closure',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _removeWorkers(String machineId) {
    final summary = _machineSummaries[machineId];
    setState(() {
      _machineSummaries[machineId]?.clearWorkers();
      _addHistoryLog(
        type: 'Worker Update',
        status: 'Workers Removed',
        amount: 0,
        machineId: machineId,
        machineName: summary?.name,
        details: {'Machine ID': machineId, 'Worker Count': '0'},
      );
    });
    _showSnackbar('Workers removed. Food module updated.', AppTheme.success);
  }

  // ── Form reset & navigation ───────────────────────────────────────────────
  void _closeDetail() {
    setState(() {
      _showMachineList = true;
      _currentMachineIdForDetail = null;
      _resetFormFields();
    });
  }

  void _resetFormFields() {
    _cashAmountController.clear();
    _advanceAmountController.clear();
    _dieselController.clear();
    _dieselConsumptionData = null;
    _dieselLogEntries.clear();
    _selectedDieselFuelType = null;
    _selectedDieselStockPoint = null;
    _dieselLitresEntryController.clear();
    _dieselRemarksEntryController.clear();
    _editingDieselEntryId = null;
    _betaController.clear();
    _extraBetaController.clear();
    _extraBetaNoteController.clear();
    _enableExtraBeta = false;
    _notesController.clear();
    _ifscController.clear();
    _accNumController.clear();
    _bankNameController.clear();
    _enableCashPayment = false;
    _enableAdvancePayment = false;
    _selectedAdvanceMode = null;
    _selectedEntryMethod = null;
    _selectedPaymentAccount = null;
    _selectedBankAccount = null;
    _generalBillFileName = null;
    _totalWorkingHours = 0.0;
    _isBetaEligible = false;
    _timeBlocks.clear();
    _timeBlocks.add(TimeBlock(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: const TimeOfDay(hour: 8, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ));
  }

  // ── Time-block logic ─────────────────────────────────────────────────────
  void _addTimeBlock() {
    setState(() {
      _timeBlocks.add(TimeBlock(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 13, minute: 0),
      ));
    });
  }

  void _removeTimeBlock(String id) {
    if (_timeBlocks.length > 1) {
      setState(() {
        _timeBlocks.removeWhere((block) => block.id == id);
        _calculateWorkingHours();
        _checkBetaEligibility();
      });
    }
  }

  Future<void> _selectTime(
      BuildContext context, TimeBlock block, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? block.startTime : block.endTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppTheme.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          block.startTime = picked;
        } else {
          block.endTime = picked;
        }
        _calculateWorkingHours();
        _checkBetaEligibility();
      });
    }
  }

  void _calculateWorkingHours() {
    double totalHours = 0.0;
    for (var block in _timeBlocks) {
      final startMinutes = block.startTime.hour * 60 + block.startTime.minute;
      final endMinutes = block.endTime.hour * 60 + block.endTime.minute;
      if (endMinutes > startMinutes) {
        totalHours += (endMinutes - startMinutes) / 60.0;
      }
    }
    setState(() => _totalWorkingHours = totalHours);
  }

  void _checkBetaEligibility() {
    if (_currentMachineIdForDetail == null) {
      _isBetaEligible = false;
      return;
    }
    final machine = _machines.firstWhere(
      (m) => m['id'] == _currentMachineIdForDetail,
      orElse: () => const <String, String>{},
    );
    final betaEnabled = machine['betaEnabled'] == 'true';
    final requiredHours =
        double.tryParse(machine['betaRequiredHours'] ?? '8') ?? 8.0;
    _isBetaEligible = betaEnabled && _totalWorkingHours >= requiredHours;
  }

  // ── General bill upload (step after Workers) ──────────────────────────────
  Future<void> _pickGeneralBill() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach Bill / Receipt'),
        content: const Text('Choose bill to upload'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _generalBillFileName =
                    'bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
                _addHistoryLog(
                  type: 'Bill Upload',
                  status: 'Attached',
                  amount: 0,
                  details: {
                    'Bill File': _generalBillFileName ?? '-',
                    'Machine': _currentMachineDetail?['name'] ?? '-',
                  },
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Select Bill'),
          ),
        ],
      ),
    );
  }

  // ── Cash payment ─────────────────────────────────────────────────────────
  void _proceedCashPayment() {
    if (!_enableCashPayment) return;
    final cashAmount = double.tryParse(_cashAmountController.text) ?? 0;
    if (cashAmount <= 0) {
      _showSnackbar('Enter a valid cash amount', AppTheme.warning);
      return;
    }
    if (cashAmount > _cashLimit) {
      _showSnackbar(
          'Amount exceeds HOD cash limit (₹${_cashLimit.toStringAsFixed(0)})',
          AppTheme.danger);
      return;
    }
    if (cashAmount > _cashBalance) {
      _showSnackbar('Insufficient cash balance', AppTheme.danger);
      return;
    }
    _showSnackbar('Cash amount is valid. It will be saved with the daily log.',
        AppTheme.success);
  }

  // ── Advance request ───────────────────────────────────────────────────────
  void _submitAdvanceRequest() {
    if (!_enableAdvancePayment) return;
    final advanceAmount = double.tryParse(_advanceAmountController.text) ?? 0;
    if (advanceAmount <= 0) {
      _showSnackbar('Enter a valid eRequested amount', AppTheme.warning);
      return;
    }
    if (_selectedAdvanceMode == null) {
      _showSnackbar(
          'Please select a payment method (UPI/Bank)', AppTheme.warning);
      return;
    }
    if (_selectedAdvanceMode == 'bank' && _selectedEntryMethod == null) {
      _showSnackbar(
          'Select an entry method for bank details', AppTheme.warning);
      return;
    }
    _showSnackbar(
        'eRequested amount is ready. It will be saved with the daily log.',
        AppTheme.success);
  }

  // ── Submit log ────────────────────────────────────────────────────────────
  Future<void> _submitLog() async {
    if (_currentMachineIdForDetail == null) {
      _showSnackbar('No machine selected', AppTheme.danger);
      return;
    }
    final currentSummary = _machineSummaries[_currentMachineIdForDetail!];
    if (currentSummary?.isClosed == true) {
      _showSnackbar('Machine is closed. Reopen it before saving log data.',
          AppTheme.warning);
      return;
    }
    if (currentSummary?.isTransferred == true) {
      _showSnackbar(
          'Machine is transferred. Re-enter it before saving log data.',
          AppTheme.warning);
      return;
    }
    if (_enableCashPayment) {
      final cashAmount = double.tryParse(_cashAmountController.text) ?? 0;
      if (cashAmount <= 0) {
        _showSnackbar('Please enter a valid cash amount', AppTheme.warning);
        return;
      }
      if (cashAmount > _cashLimit) {
        _showSnackbar(
            'Amount exceeds HOD cash limit (₹${_cashLimit.toStringAsFixed(0)})',
            AppTheme.danger);
        return;
      }
      if (cashAmount > _cashBalance) {
        _showSnackbar('Insufficient cash balance available', AppTheme.danger);
        return;
      }
    }
    if (_enableAdvancePayment) {
      final advanceAmount = double.tryParse(_advanceAmountController.text) ?? 0;
      if (advanceAmount <= 0) {
        _showSnackbar('Please enter advance amount', AppTheme.warning);
        return;
      }
      if (_selectedAdvanceMode == null) {
        _showSnackbar(
            'Please select UPI or Bank for advance', AppTheme.warning);
        return;
      }
      if (_selectedAdvanceMode == 'bank') {
        if (_selectedEntryMethod == 'manual') {
          if (_ifscController.text.isEmpty ||
              _accNumController.text.isEmpty ||
              _bankNameController.text.isEmpty) {
            _showSnackbar('Please fill all bank details', AppTheme.warning);
            return;
          }
        }
        if (_selectedEntryMethod == null) {
          _showSnackbar('Please select an entry method for bank details',
              AppTheme.warning);
          return;
        }
      } else if (_selectedAdvanceMode == 'upi') {
        if (_selectedPaymentAccount == null) {
          _showSnackbar(
              'Please select a verified UPI account', AppTheme.warning);
          return;
        }
      }
    }
    if (_timeBlocks.isEmpty) {
      _showSnackbar('Please add at least one time block', AppTheme.danger);
      return;
    }

    final cashAmount = _enableCashPayment
        ? (double.tryParse(_cashAmountController.text) ?? 0)
        : 0.0;
    final advanceAmount = _enableAdvancePayment
        ? (double.tryParse(_advanceAmountController.text) ?? 0)
        : 0.0;
    final dieselLitres = _dieselConsumptionTotalLitres;
    final dieselAmount = _dieselTotalAmount;
    final betaAmount =
        _isBetaEligible ? (double.tryParse(_betaController.text) ?? 0) : 0.0;
    final extraBetaAmount = _enableExtraBeta
        ? (double.tryParse(_extraBetaController.text) ?? 0)
        : 0.0;
    final totalAmount = cashAmount +
        advanceAmount +
        dieselAmount +
        betaAmount +
        extraBetaAmount;

    final machineId = _currentMachineIdForDetail!;
    final machineName = _currentMachineDetail?['name'] ?? machineId;
    final workerCount = _machineSummaries[machineId]?.workerCount ?? 0;
    final timeBlockText = _timeBlocks
        .map((block) =>
            '${block.startTime.format(context)} - ${block.endTime.format(context)}')
        .join(', ');
    final notesText = _notesController.text.trim();
    final billFile = _generalBillFileName;

    setState(() => _isSubmitting = true);
    try {
      final siteId = await _contextService.resolveSiteId();
      for (final entry in _dieselLogEntries) {
        if (entry.liters <= 0) continue;
        final balance = await _stockRepository.findFuelBalance(
          stockPointName: entry.stockPoint,
          fuelType: entry.fuelType,
        );
        await _stockRepository.issueForModule(
          siteId: siteId,
          module: 'daily_machine_log',
          sourceReference: 'DAILY-DIESEL-$machineId-${entry.id}',
          stockBalanceId: balance.id,
          quantity: entry.liters,
          note: '$machineName: ${entry.fuelType} (${entry.remarks})',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackbar('Daily log was not saved: $error', AppTheme.danger);
      return;
    }
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _machineSummaries[machineId]
              ?.updateFromLog(_totalWorkingHours, dieselLitres, totalAmount);
          PaymentTransaction? cashTxn;
          PaymentTransaction? advanceTxn;
          if (cashAmount > 0) {
            cashTxn = _createCashPaymentTransaction(cashAmount,
                note: notesText.isEmpty ? null : notesText);
          }
          if (advanceAmount > 0) {
            advanceTxn = _createAdvanceRequestTransaction(advanceAmount,
                note: notesText.isEmpty ? null : notesText);
          }
          _addHistoryLog(
            type: 'Daily Log',
            status: 'Saved',
            amount: totalAmount,
            machineId: machineId,
            machineName: machineName,
            details: {
              'Machine ID': machineId,
              'Machine Name': machineName,
              'Working Time Blocks': timeBlockText,
              'Total Working Hours':
                  '${_totalWorkingHours.toStringAsFixed(2)} h',
              'Cash Payment ID': cashTxn?.id ?? '-',
              'Cash Amount': '₹${cashAmount.toStringAsFixed(0)}',
              'Cash Method': cashTxn?.method ?? '-',
              'Cash Balance After Payment':
                  '₹${_cashBalance.toStringAsFixed(0)}',
              'Advance Request ID': advanceTxn?.id ?? '-',
              'Advance Amount': '₹${advanceAmount.toStringAsFixed(0)}',
              'Advance Method': advanceTxn?.method ?? '-',
              'Advance Status': advanceTxn?.status ?? '-',
              'Advance Proof': advanceTxn?.paymentProof ?? '-',
              'Diesel Option': _dieselOption,
              'Diesel Litres': '${dieselLitres.toStringAsFixed(1)} litres',
              'Diesel Amount': '₹${dieselAmount.toStringAsFixed(0)}',
              'Diesel Rows': _dieselLogRowsText,
              'Regular Beta Eligible': _isBetaEligible ? 'Yes' : 'No',
              'Beta Amount': '₹${betaAmount.toStringAsFixed(0)}',
              'Extra Beta': _enableExtraBeta
                  ? '₹${extraBetaAmount.toStringAsFixed(0)}'
                  : '-',
              'Extra Beta HOD Note': _enableExtraBeta &&
                      _extraBetaNoteController.text.trim().isNotEmpty
                  ? _extraBetaNoteController.text.trim()
                  : '-',
              'Workers On Machine Card': workerCount.toString(),
              'Bill Upload': billFile ?? '-',
              'Notes': notesText.isEmpty ? '-' : notesText,
              'Total Amount': '₹${totalAmount.toStringAsFixed(0)}',
            },
          );
        });
        unawaited(
          HodSiteWorkspaceService().recordSupervisorActivityForCurrentSession(
            module: 'Daily Data',
            action: 'Daily log saved',
            details:
                '$machineName saved ${_totalWorkingHours.toStringAsFixed(2)} h, ${dieselLitres.toStringAsFixed(1)} L diesel, total ₹${totalAmount.toStringAsFixed(0)}.',
          ),
        );
        _showSnackbar(
            'Daily log saved for machine $machineName!', AppTheme.success);
        _closeDetail();
      }
    });
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Transaction history sheet ─────────────────────────────────────────────
  void _showTransactionHistorySheet(String type) {
    final isCash = type == 'cash';
    final transactions = isCash ? _cashTransactions : _advanceTransactions;
    final color = isCash ? AppTheme.info : AppTheme.success;
    final title = isCash ? 'Cash Payment History' : 'Advance Request History';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(
                        isCash
                            ? Icons.payments_outlined
                            : Icons.request_quote_outlined,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary)),
                          Text(
                              '${transactions.length} transaction${transactions.length == 1 ? "" : "s"}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '₹${transactions.fold(0.0, (s, t) => s + t.amount).toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 48,
                                color: AppTheme.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text('No transactions yet',
                                style: TextStyle(color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final txn = transactions[i];
                          final isToday = txn.date.day == DateTime.now().day &&
                              txn.date.month == DateTime.now().month;
                          final dateLabel = isToday
                              ? 'Today ${txn.date.hour.toString().padLeft(2, "0")}:${txn.date.minute.toString().padLeft(2, "0")}'
                              : '${txn.date.day}/${txn.date.month}/${txn.date.year}';
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: color.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Text('₹',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: color)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(txn.id,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: color)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text(txn.method,
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: color)),
                                        ),
                                      ]),
                                      const SizedBox(height: 3),
                                      if (txn.note != null &&
                                          txn.note!.isNotEmpty)
                                        Text(txn.note!,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary)),
                                      Text(dateLabel,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                Text('₹${txn.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: color)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Add/Edit UPI account sheet ────────────────────────────────────────────
  void _showAddAccountSheet({String? existingId}) {
    final accCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    if (existingId != null) {
      final acc = _savedAccounts.firstWhere((a) => a['id'] == existingId);
      accCtrl.text = acc['accountNumber']?.replaceAll('****', '') ?? '';
      upiCtrl.text = acc['upiId'] ?? '';
      bankCtrl.text = acc['bankName'] ?? '';
      ifscCtrl.text = acc['ifsc'] ?? '';
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
                existingId != null
                    ? 'Edit Payment Account'
                    : 'Add Payment Account',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: accCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Account Number',
                  prefixIcon: const Icon(Icons.account_balance),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: upiCtrl,
              decoration: InputDecoration(
                  labelText: 'UPI ID',
                  prefixIcon: const Icon(Icons.qr_code),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bankCtrl,
              decoration: InputDecoration(
                  labelText: 'Bank Name',
                  prefixIcon: const Icon(Icons.business),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ifscCtrl,
              decoration: InputDecoration(
                  labelText: 'IFSC Code',
                  prefixIcon: const Icon(Icons.code),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (accCtrl.text.isNotEmpty && bankCtrl.text.isNotEmpty) {
                    final newAcc = {
                      'id': existingId ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      'accountNumber':
                          '****${accCtrl.text.substring(accCtrl.text.length - 4)}',
                      'upiId': upiCtrl.text,
                      'bankName': bankCtrl.text,
                      'ifsc': ifscCtrl.text,
                      'type': existingId != null ? 'edited' : 'added',
                    };
                    setState(() {
                      if (existingId != null) {
                        final idx = _savedAccounts
                            .indexWhere((a) => a['id'] == existingId);
                        if (idx >= 0) _savedAccounts[idx] = newAcc;
                      } else {
                        _savedAccounts.add(newAcc);
                      }
                      _selectedPaymentAccount = newAcc['id'];
                    });
                    Navigator.pop(context);
                    _showSnackbar(
                        existingId != null
                            ? 'Account updated!'
                            : 'Account added!',
                        AppTheme.success);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Account',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Add/Edit saved bank account sheet ────────────────────────────────────
  void _showAddBankAccountSheet({String? existingId}) {
    final accCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    if (existingId != null) {
      final b = _savedBankAccounts.firstWhere((b) => b['id'] == existingId);
      accCtrl.text = b['accountNumber']?.replaceAll('****', '') ?? '';
      ifscCtrl.text = b['ifsc'] ?? '';
      bankCtrl.text = b['bankName'] ?? '';
      holderCtrl.text = b['holderName'] ?? '';
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                  existingId != null ? 'Edit Bank Account' : 'Add Bank Account',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: holderCtrl,
                decoration: InputDecoration(
                    labelText: 'Account Holder Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Account Number',
                    prefixIcon: const Icon(Icons.account_balance),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankCtrl,
                decoration: InputDecoration(
                    labelText: 'Bank Name',
                    prefixIcon: const Icon(Icons.business),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ifscCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                    labelText: 'IFSC Code',
                    prefixIcon: const Icon(Icons.code),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (accCtrl.text.length >= 4 && bankCtrl.text.isNotEmpty) {
                      final newBank = {
                        'id': existingId ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        'accountNumber':
                            '****${accCtrl.text.substring(accCtrl.text.length - 4)}',
                        'bankName': bankCtrl.text,
                        'ifsc': ifscCtrl.text,
                        'holderName': holderCtrl.text,
                        'type': existingId != null ? 'edited' : 'added',
                      };
                      setState(() {
                        if (existingId != null) {
                          final idx = _savedBankAccounts
                              .indexWhere((b) => b['id'] == existingId);
                          if (idx >= 0) _savedBankAccounts[idx] = newBank;
                        } else {
                          _savedBankAccounts.add(newBank);
                        }
                        _selectedBankAccount = newBank['id'];
                        _ifscController.text = ifscCtrl.text;
                        _accNumController.text = accCtrl.text;
                        _bankNameController.text = bankCtrl.text;
                        _selectedEntryMethod = 'manual';
                      });
                      Navigator.pop(context);
                      _showSnackbar(
                          existingId != null
                              ? 'Bank account updated!'
                              : 'Bank account saved!',
                          AppTheme.success);
                    } else {
                      _showSnackbar(
                          'Please enter a valid account number and bank name',
                          AppTheme.warning);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.info,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Bank Account',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (widget.isHOD) {
      return const HodModuleReviewScreen(
        title: 'HOD Admin: Machines Review',
        moduleFilter: 'Daily Machine',
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(_showMachineList
            ? (_showArchived ? 'Archived Machines' : 'Machines Daily Data')
            : 'Log Data - ${_currentMachineDetail?['name'] ?? ''}'),
        leading: IconButton(
          icon:
              Icon(_showMachineList ? Icons.arrow_back : Icons.arrow_back_ios),
          onPressed: () {
            if (_showMachineList) {
              if (_showArchived) {
                setState(() => _showArchived = false);
              } else {
                Navigator.pop(context);
              }
            } else {
              _closeDetail();
            }
          },
        ),
        actions: _showMachineList && !_showArchived
            ? [
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'View Archived Machines',
                  onPressed: () => setState(() => _showArchived = true),
                ),
              ]
            : null,
        bottom: _showMachineList && !_showArchived
            ? TabBar(
                controller: _mainTabController,
                tabs: const [
                  Tab(
                      text: 'Machines',
                      icon: Icon(Icons.construction_outlined)),
                  Tab(
                      text: 'History',
                      icon: Icon(Icons.manage_search_outlined)),
                ],
              )
            : null,
      ),
      body: _showMachineList
          ? (_showArchived
              ? _buildMachineList()
              : TabBarView(
                  controller: _mainTabController,
                  children: [
                    _buildMachineList(),
                    _buildHistoryTab(),
                  ],
                ))
          : _buildDetailForm(),
    );
  }

  // ignore: unused_element
  Widget _buildHODAdminView() {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('HOD Admin: Machines Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings,
                size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text(
              'HOD Machines Admin Panel',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pending Approvals, Closures, and Machine Logs will be reviewed here.',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Switch back to supervisor view for testing/preview purposes if needed,
                // but usually HOD stays here.
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: const Text('Review Pending Machine Transfers'),
            )
          ],
        ),
      ),
    );
  }

  // ── Machine list view ─────────────────────────────────────────────────────
  Widget _buildMachineList() {
    final query = _machineSearchController.text.trim().toLowerCase();
    final displayed = _machines.where((m) {
      final archivedMatches =
          m['isArchived'] == (_showArchived ? 'true' : 'false');
      if (!archivedMatches) return false;
      if (query.isEmpty) return true;
      final searchable = [
        m['id'],
        m['name'],
        m['type'],
        m['location'],
        m['dieselOption'],
      ].whereType<String>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListHeader(),
          const SizedBox(height: 12),
          _buildMachineSearchBar(),
          const SizedBox(height: 16),
          if (displayed.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(
                      _showArchived ? Icons.archive : Icons.inventory_2,
                      size: 64,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      query.isNotEmpty
                          ? 'No machines matched your search'
                          : (_showArchived
                              ? 'No archived machines'
                              : 'No machines available'),
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayed.map(_buildMachineCard).toList(),
        ],
      ),
    );
  }

  Widget _buildMachineSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextField(
        controller: _machineSearchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search machine by ID, name, type, location...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _machineSearchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _machineSearchController.clear(),
                ),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _showArchived ? 'Archived Machines' : 'Today\'s Machine Summary',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _showArchived
                ? 'Reactivate or permanently delete machines'
                : 'Tap any machine for options',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineCard(Map<String, String> machine) {
    final summary = _machineSummaries[machine['id']!]!;
    final bool isClosed = summary.isClosed;
    final bool isTransferred = summary.isTransferred;
    final int reenterCount = summary.reenterEventCount;
    final bool hasBeenReentered = !isTransferred && reenterCount > 0;

    return GestureDetector(
      onTap: () => _showMachineOptions(machine['id']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTransferred
                ? AppTheme.info.withOpacity(0.5)
                : (isClosed
                    ? AppTheme.danger.withOpacity(0.5)
                    : AppTheme.border),
            width: 1.5,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppTheme.info.withOpacity(0.2),
                      AppTheme.info.withOpacity(0.05),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.construction,
                      color: AppTheme.info, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(machine['name']!,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                          '${machine['id']} • ${machine['type']} • ${machine['location']}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            if (!_showArchived) ...[
              const SizedBox(height: 12),
              _buildMachineWorkerControl(
                  machine['id']!, summary, isTransferred || isClosed),
              if (isTransferred) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(
                      'TRANSFERRED (x${summary.transferEventCount})',
                      Icons.swap_horiz,
                      AppTheme.info),
                ),
              ] else if (hasBeenReentered) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge('RE-ENTERED (x$reenterCount)',
                      Icons.assignment_return, AppTheme.success),
                ),
              ] else if (isClosed) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(
                      'MACHINE CLOSED', Icons.lock, AppTheme.danger),
                ),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _buildListStat(
                    'Hours',
                    '${summary.hoursWorked.toStringAsFixed(1)}h',
                    Icons.access_time,
                    AppTheme.warning),
                const SizedBox(width: 8),
                _buildListStat(
                    'Fuel',
                    '${summary.fuelConsumed.toStringAsFixed(1)}L',
                    Icons.local_gas_station,
                    AppTheme.info),
                const SizedBox(width: 8),
                _buildListStat(
                    'Amount',
                    '₹${summary.amountGiven.toStringAsFixed(0)}',
                    Icons.currency_rupee,
                    AppTheme.success),
              ],
            ),
            if (summary.isClosed && !_showArchived) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.recycling,
                      size: 14, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Retrieved: ${summary.retrievedFuel.toStringAsFixed(1)} L${summary.retrievedFuelAmount > 0 ? ' • ₹${summary.retrievedFuelAmount.toStringAsFixed(0)}' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.touch_app, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                const Text('Tap for options',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineWorkerControl(
      String machineId, MachineSummary summary, bool isBlocked) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isBlocked
            ? AppTheme.textMuted.withOpacity(0.06)
            : AppTheme.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isBlocked
                ? AppTheme.textMuted.withOpacity(0.18)
                : AppTheme.success.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_outlined,
              size: 18,
              color: isBlocked ? AppTheme.textMuted : AppTheme.success),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Workers',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            onPressed:
                isBlocked ? null : () => _decrementWorkerCount(machineId),
            icon: Icon(Icons.remove_circle_outline,
                color: isBlocked ? AppTheme.textMuted : AppTheme.danger),
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove worker',
          ),
          Container(
            width: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text('${summary.workerCount}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          IconButton(
            onPressed:
                isBlocked ? null : () => _incrementWorkerCount(machineId),
            icon: Icon(Icons.add_circle_outline,
                color: isBlocked ? AppTheme.textMuted : AppTheme.success),
            visualDensity: VisualDensity.compact,
            tooltip: 'Add worker',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildListStat(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  List<MachineLogRecord> get _filteredHistoryLogs {
    final query = _historySearchController.text.trim().toLowerCase();
    return _historyLogs.where((log) {
      final typeMatches =
          _historyTypeFilter == 'All' || log.type == _historyTypeFilter;
      if (!typeMatches) return false;
      if (!_historyDateMatches(log.date)) return false;
      if (query.isEmpty) return true;
      final searchable = [
        log.id,
        log.machineId,
        log.machineName,
        log.type,
        log.status,
        log.amount.toStringAsFixed(0),
        ...log.details.entries.map((e) => '${e.key} ${e.value}'),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  bool _historyDateMatches(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(date.year, date.month, date.day);
    switch (_historyDateFilter) {
      case 'Today':
        return logDay == today;
      case 'Yesterday':
        return logDay == today.subtract(const Duration(days: 1));
      case 'Last 7 Days':
        return !logDay.isBefore(today.subtract(const Duration(days: 6)));
      default:
        return true;
    }
  }

  Widget _buildHistoryTab() {
    final logs = _filteredHistoryLogs;
    final grouped = _groupLogsByDate(logs).entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final totalAmount = logs.fold<double>(0, (sum, log) => sum + log.amount);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.history, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date-wise Machine History',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${logs.length} log(s) • ₹${totalAmount.toStringAsFixed(0)} filtered amount',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildHistoryFilters(),
          const SizedBox(height: 14),
          if (grouped.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.manage_search_outlined,
                      size: 48, color: AppTheme.textMuted),
                  SizedBox(height: 10),
                  Text('No history logs found',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text('Try changing the search, date or filter option.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          else
            ...grouped
                .map((entry) => _buildHistoryDateCard(entry.key, entry.value)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHistoryDateCard(DateTime date, List<MachineLogRecord> logs) {
    final totalAmount = logs.fold<double>(0, (sum, log) => sum + log.amount);
    final machines =
        logs.map((e) => e.machineId).where((id) => id != '-').toSet().length;
    final cashCount = logs.where((e) => e.type == 'Cash Payment').length;
    final advanceCount = logs.where((e) => e.type == 'Advance Request').length;
    return GestureDetector(
      onTap: () => _openHistoryDatePage(date, logs),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calendar_month_outlined,
                      color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _historyDateTitle(date),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_dateKey(date)} • ${logs.length} log(s)',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildHistoryMini('Machines', machines.toString())),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildHistoryMini('Cash', cashCount.toString())),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        _buildHistoryMini('Advance', advanceCount.toString())),
              ],
            ),
            const SizedBox(height: 8),
            _buildHistoryMini(
                'Day Total', '₹${totalAmount.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  void _openHistoryDatePage(DateTime date, List<MachineLogRecord> logs) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryDateDetailPage(
          date: date,
          logs: List<MachineLogRecord>.from(logs),
          formatDateTime: _formatCompactDateTime,
        ),
      ),
    );
  }

  Widget _buildHistoryFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          TextField(
            controller: _historySearchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search logs by machine, ID, amount, notes...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _historySearchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _historySearchController.clear(),
                    ),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _historyTypeFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter by log type',
              prefixIcon: Icon(Icons.filter_list_outlined),
            ),
            items: _historyTypeOptions
                .map((type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) =>
                setState(() => _historyTypeFilter = value ?? 'All'),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['All', 'Today', 'Yesterday', 'Last 7 Days'].map((filter) {
                final selected = _historyDateFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(filter),
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(
                        color: selected ? AppTheme.primary : AppTheme.border),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppTheme.textSecondary,
                    ),
                    onSelected: (_) =>
                        setState(() => _historyDateFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryLogCard(MachineLogRecord log) {
    final color = switch (log.type) {
      'Cash Payment' => AppTheme.info,
      'Advance Request' => AppTheme.success,
      'Machine Transfer' => AppTheme.primary,
      'Machine Closure' => AppTheme.warning,
      'Daily Log' => AppTheme.warning,
      _ => AppTheme.textSecondary,
    };
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
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_historyIconFor(log.type), color: color),
        ),
        title: Text(
          log.type,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${log.machineName} • ${_formatCompactDateTime(log.date)}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (log.amount > 0)
              Text('₹${log.amount.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 3),
            _buildStatusChip(log.status, color),
          ],
        ),
        children: [
          Row(
            children: [
              Expanded(child: _buildHistoryMini('Log ID', log.id)),
              const SizedBox(width: 8),
              Expanded(child: _buildHistoryMini('Machine ID', log.machineId)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildHistoryMini('Time', _formatTimeOnly(log.date))),
            ],
          ),
          const SizedBox(height: 10),
          ...log.details.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600),
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

  Widget _buildHistoryMini(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(9),
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
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  IconData _historyIconFor(String type) {
    switch (type) {
      case 'Cash Payment':
        return Icons.payments_outlined;
      case 'Advance Request':
        return Icons.request_quote_outlined;
      case 'Machine Transfer':
        return Icons.swap_horiz;
      case 'Machine Closure':
        return Icons.lock_outline;
      case 'Daily Log':
        return Icons.edit_note_outlined;
      case 'Worker Update':
        return Icons.groups_outlined;
      case 'Bill Upload':
        return Icons.receipt_long_outlined;
      default:
        return Icons.history;
    }
  }

  // ── Detail form ───────────────────────────────────────────────────────────
  Widget _buildDetailForm() {
    if (_currentMachineIdForDetail == null) return const SizedBox();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailHeader(),
          const SizedBox(height: 16),
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildWorkingHoursCard(),
          const SizedBox(height: 16),
          _buildStepCard('1', 'Machine Info', _buildMachineDetailDisplay(),
              color: AppTheme.info),
          const SizedBox(height: 12),
          _buildStepCard('2', 'Working Time Blocks', _buildTimeBlocksSection(),
              color: AppTheme.warning),
          const SizedBox(height: 12),
          _buildStepCard('3', 'Payment Details', _buildPaymentSection(),
              color: AppTheme.success),
          const SizedBox(height: 12),
          _buildStepCard(
            '4',
            _dieselOption == 'With diesel'
                ? 'Diesel Entry'
                : 'Diesel Consumption',
            _buildDieselSection(),
            color: AppTheme.warning,
          ),
          const SizedBox(height: 12),
          _buildStepCard('5', 'Beta Incentive', _buildBetaAmount(),
              color:
                  _isBetaEligible ? AppTheme.success : AppTheme.textSecondary),
          const SizedBox(height: 12),
          _buildStepCard('6', 'Bill Upload', _buildBillUploadSection(),
              color: AppTheme.warning),
          const SizedBox(height: 12),
          _buildStepCard('7', 'Additional Notes', _buildNotesField(),
              color: AppTheme.info),
          const SizedBox(height: 20),
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildSubmitButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Payment section ───────────────────────────────────────────────────────
  Widget _buildPaymentSection() {
    return Column(
      children: [
        // ── Cash Payment toggle ─────────────────────────────────────────
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
                Text('Available Balance: ₹${_cashBalance.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          TextField(
            controller: _cashAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cash Amount (₹)',
              hintText: 'Max ₹${_cashLimit.toStringAsFixed(0)}',
              prefixIcon: const Icon(Icons.currency_rupee, size: 18),
              filled: true,
              fillColor: AppTheme.surface,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          _buildCashValidationInfo(),
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
        // ── Advance Request toggle ──────────────────────────────────────
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
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
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

  Widget _buildCashPaymentTable() {
    return _buildLedgerTableShell(
      title: 'Cash Payment Table',
      subtitle:
          'Amount is auto-filled when payment is completed; use Edit to correct amount',
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
                      DataCell(Text(txn.id,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))),
                      DataCell(Text(_formatCompactDateTime(txn.date),
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text('₹${txn.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(
                        TextButton.icon(
                          onPressed: () => _showEditCashPaymentSheet(txn),
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

  Widget _buildAdvanceRequestTable() {
    return _buildLedgerTableShell(
      title: 'Advance Payment Request Table',
      subtitle:
          'Proof and Machine IDs Book unlock only after the requested amount is completed',
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
                      DataCell(Text(txn.id,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))),
                      DataCell(Text(_formatCompactDateTime(txn.date),
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text('₹${txn.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(
                        completed
                            ? _buildStatusChip('Completed', AppTheme.success)
                            : TextButton.icon(
                                onPressed: () => _completeRequestedAdvance(txn),
                                icon: const Icon(Icons.verified_outlined,
                                    size: 15),
                                label: const Text('Requested'),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.warning),
                              ),
                      ),
                      DataCell(
                        completed
                            ? _buildProofPreview(
                                txn.paymentProof ?? 'Payment proof')
                            : const Text('Visible after completion',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted)),
                      ),
                      DataCell(
                        completed
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    txn.registeredInMachineIdsBook
                                        ? 'Yes'
                                        : 'No',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: txn.registeredInMachineIdsBook
                                          ? AppTheme.success
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: txn.registeredInMachineIdsBook,
                                    activeColor: AppTheme.success,
                                    onChanged: (value) =>
                                        _toggleAdvanceMachineBook(txn, value),
                                  ),
                                ],
                              )
                            : const Text('Locked',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildProofPreview(String proofId) {
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
            child: const Icon(Icons.image_outlined,
                size: 16, color: AppTheme.success),
          ),
          const SizedBox(width: 6),
          Text(
            proofId,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.success,
                fontWeight: FontWeight.w700),
          ),
        ],
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
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (child == null)
            Text(emptyText,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))
          else
            child,
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildCashValidationInfo() {
    final text = _cashAmountController.text;
    final amount = double.tryParse(text) ?? 0;
    if (text.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.infoBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.info.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppTheme.info),
            const SizedBox(width: 8),
            Text('Balance after payment: ₹$_cashBalance',
                style: const TextStyle(fontSize: 11, color: AppTheme.info)),
          ],
        ),
      );
    }
    if (amount > _cashLimit) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.dangerBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppTheme.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Exceeds HOD limit of ₹${_cashLimit.toStringAsFixed(0)}. Please reduce or request advance.',
                style: const TextStyle(fontSize: 11, color: AppTheme.danger),
              ),
            ),
          ],
        ),
      );
    } else if (amount > _cashBalance) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.dangerBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, size: 16, color: AppTheme.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Insufficient cash balance (avail: ₹${_cashBalance.toStringAsFixed(0)}).',
                style: const TextStyle(fontSize: 11, color: AppTheme.danger),
              ),
            ),
          ],
        ),
      );
    } else {
      final remaining = _cashBalance - amount;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.successBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.success.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
            const SizedBox(width: 8),
            Text(
                'Valid. Balance after payment: ₹${remaining.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.success)),
          ],
        ),
      );
    }
  }

  Widget _buildAdvancePaymentSection() {
    final advanceAmount = double.tryParse(_advanceAmountController.text) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _advanceAmountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Advance Amount (₹)',
            prefixIcon: const Icon(Icons.request_quote, size: 18),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedAdvanceMode = 'upi';
                  _selectedEntryMethod = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedAdvanceMode == 'upi'
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _selectedAdvanceMode == 'upi'
                            ? AppTheme.success
                            : AppTheme.border,
                        width: _selectedAdvanceMode == 'upi' ? 2 : 1),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code,
                          size: 28,
                          color: _selectedAdvanceMode == 'upi'
                              ? AppTheme.success
                              : AppTheme.textSecondary),
                      const SizedBox(height: 4),
                      Text('UPI',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedAdvanceMode == 'upi'
                                  ? AppTheme.success
                                  : AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedAdvanceMode = 'bank';
                  _selectedEntryMethod = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedAdvanceMode == 'bank'
                        ? AppTheme.info.withOpacity(0.1)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _selectedAdvanceMode == 'bank'
                            ? AppTheme.info
                            : AppTheme.border,
                        width: _selectedAdvanceMode == 'bank' ? 2 : 1),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.account_balance,
                          size: 28,
                          color: _selectedAdvanceMode == 'bank'
                              ? AppTheme.info
                              : AppTheme.textSecondary),
                      const SizedBox(height: 4),
                      Text('Bank Transfer',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedAdvanceMode == 'bank'
                                  ? AppTheme.info
                                  : AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedAdvanceMode == 'upi') _buildUpiAccountSelection(),
        if (_selectedAdvanceMode == 'bank') _buildBankDetailsSection(),
        if (advanceAmount > 0) ...[
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
      ],
    );
  }

  Widget _buildUpiAccountSelection() {
    final upiAccounts =
        _savedAccounts.where((a) => a['upiId']!.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Verified UPI Account',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        ...upiAccounts
            .map((account) => GestureDetector(
                  onTap: () =>
                      setState(() => _selectedPaymentAccount = account['id']),
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
                          width:
                              _selectedPaymentAccount == account['id'] ? 2 : 1),
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
                                      fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        if (account['type'] == 'primary')
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppTheme.infoBg,
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('Default',
                                  style: TextStyle(
                                      fontSize: 9, color: AppTheme.info))),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () =>
                              _showAddAccountSheet(existingId: account['id']),
                          color: AppTheme.warning,
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
        TextButton.icon(
          onPressed: _showAddAccountSheet,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add UPI Account'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.info),
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
          ..._savedBankAccounts
              .map((bank) => GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBankAccount = bank['id'];
                        _ifscController.text = bank['ifsc']!;
                        _accNumController.text =
                            bank['accountNumber']!.replaceAll('****', '');
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
                            width: _selectedBankAccount == bank['id'] ? 2 : 1),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bank['bankName']!,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            _selectedBankAccount == bank['id']
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
                                          color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          if (bank['type'] == 'primary')
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppTheme.infoBg,
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Text('Default',
                                    style: TextStyle(
                                        fontSize: 9, color: AppTheme.info))),
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
                  ))
              .toList(),
          TextButton.icon(
            onPressed: _showAddBankAccountSheet,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add New Bank Account'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.info),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Or enter manually',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                child: _buildEntryMethodOption(
                    'manual', 'Manual', Icons.edit_outlined)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildEntryMethodOption(
                    'photo', 'Photo', Icons.camera_alt_outlined)),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _buildEntryMethodOption('voice', 'Voice', Icons.mic_none)),
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
          TextField(
            controller: _ifscController,
            decoration: InputDecoration(
                labelText: 'IFSC Code',
                prefixIcon: const Icon(Icons.code),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _accNumController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'Account Number',
                prefixIcon: const Icon(Icons.account_balance),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bankNameController,
            decoration: InputDecoration(
                labelText: 'Bank Name',
                prefixIcon: const Icon(Icons.business),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ] else if (_selectedEntryMethod == 'photo') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.info.withOpacity(0.2)),
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
              border: Border.all(color: AppTheme.info.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.mic, color: AppTheme.info),
              SizedBox(width: 8),
              Text('Record bank details by voice',
                  style: TextStyle(color: AppTheme.info)),
            ]),
          ),
        ],
        if (_selectedEntryMethod != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.success.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.success),
              SizedBox(width: 8),
              Expanded(
                child: Text('Request will be sent for approval',
                    style: TextStyle(fontSize: 11, color: AppTheme.success)),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildEntryMethodOption(String method, String title, IconData icon) {
    final isSelected = _selectedEntryMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedEntryMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.success.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? AppTheme.success : AppTheme.border,
              width: isSelected ? 2 : 1),
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
                    color: isSelected
                        ? AppTheme.success
                        : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Diesel section ────────────────────────────────────────────────────────
  Widget _buildDieselSection() {
    final fuelTypes = _dieselOption == 'With diesel'
        ? ['Petrol', 'CNG', 'Power Diesel', 'Premium Diesel']
        : ['Diesel', 'Petrol', 'CNG', 'Power Diesel', 'Premium Diesel'];

    final selectedFuel = _activeDieselFuelType(fuelTypes);
    final selectedStock = _activeDieselStockPoint();
    final inputLitres =
        double.tryParse(_dieselLitresEntryController.text.trim()) ?? 0;
    final inputAmount = inputLitres * _dieselRateForStockPoint(selectedStock);
    final isEditing = _editingDieselEntryId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _dieselOption == 'With diesel'
                ? AppTheme.infoBg
                : AppTheme.warningBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _dieselOption == 'With diesel'
                ? 'Diesel Entry'
                : 'Diesel Consumption',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _dieselOption == 'With diesel'
                  ? AppTheme.info
                  : AppTheme.warning,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildDieselEntryForm(
          fuelTypes: fuelTypes,
          selectedFuel: selectedFuel,
          selectedStock: selectedStock,
          inputAmount: inputAmount,
          isEditing: isEditing,
        ),
        const SizedBox(height: 12),
        _buildDieselRowsDataTable(fuelTypes),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.infoBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.info.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_chart_outlined,
                  size: 16, color: AppTheme.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diesel rows captured from table: ${_dieselConsumptionTotalLitres.toStringAsFixed(1)} litres',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.info,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '₹${_dieselTotalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _activeDieselFuelType(List<String> fuelTypes) {
    if (_selectedDieselFuelType != null &&
        fuelTypes.contains(_selectedDieselFuelType)) {
      return _selectedDieselFuelType!;
    }
    return fuelTypes.isNotEmpty ? fuelTypes.first : 'Diesel';
  }

  String _activeDieselStockPoint() {
    if (_selectedDieselStockPoint != null &&
        _stockPoints.contains(_selectedDieselStockPoint)) {
      return _selectedDieselStockPoint!;
    }
    return _stockPoints.isNotEmpty ? _stockPoints.first : 'Main Depot';
  }

  double get _dieselTotalAmount {
    return _dieselLogEntries.fold<double>(
      0,
      (sum, entry) => sum + _dieselEntryAmount(entry),
    );
  }

  double _dieselEntryAmount(DieselLogEntry entry) {
    return entry.liters * _dieselRateForStockPoint(entry.stockPoint);
  }

  void _refreshDieselConsumptionDataFromRows() {
    _dieselConsumptionData = _dieselLogEntries
        .map(
          (entry) => {
            'id': entry.id,
            'fuelType': entry.fuelType,
            'stockPoint': entry.stockPoint,
            'litres': entry.liters,
            'liters': entry.liters,
            'remarks': entry.remarks,
            'amount': _dieselEntryAmount(entry),
          },
        )
        .toList();
  }

  Widget _buildDieselEntryForm({
    required List<String> fuelTypes,
    required String selectedFuel,
    required String selectedStock,
    required double inputAmount,
    required bool isEditing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;
              final fuelDropdown = DropdownButtonFormField<String>(
                value: selectedFuel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Fuel Type',
                  prefixIcon: Icon(Icons.local_gas_station),
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
                  setState(() => _selectedDieselFuelType = value);
                },
              );

              final stockDropdown = DropdownButtonFormField<String>(
                value: selectedStock,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Stock Point',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: _stockPoints
                    .map(
                      (point) => DropdownMenuItem<String>(
                        value: point,
                        child: Text(point),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedDieselStockPoint = value);
                },
              );

              final litresField = TextField(
                controller: _dieselLitresEntryController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'No. of Litres',
                  prefixIcon: Icon(Icons.opacity_outlined),
                  suffixText: 'litres',
                ),
                onChanged: (_) => setState(() {}),
              );

              final amountBox = Container(
                height: 56,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '₹${inputAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              );

              final enterButton = SizedBox(
                height: 56,
                width: isNarrow ? double.infinity : 128,
                child: ElevatedButton.icon(
                  onPressed: () => _enterOrUpdateDieselRow(fuelTypes),
                  icon: Icon(
                    isEditing ? Icons.save_outlined : Icons.keyboard_return,
                    size: 18,
                  ),
                  label: Text(isEditing ? 'Update' : 'Enter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isEditing ? AppTheme.info : AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    fuelDropdown,
                    const SizedBox(height: 10),
                    stockDropdown,
                    const SizedBox(height: 10),
                    litresField,
                    const SizedBox(height: 10),
                    amountBox,
                    const SizedBox(height: 10),
                    enterButton,
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: fuelDropdown),
                      const SizedBox(width: 10),
                      Expanded(child: stockDropdown),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: litresField),
                      const SizedBox(width: 10),
                      Expanded(child: amountBox),
                      const SizedBox(width: 10),
                      enterButton,
                    ],
                  ),
                ],
              );
            },
          ),
          if (isEditing) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.edit_note_outlined,
                    size: 16, color: AppTheme.info),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Editing existing diesel row. Press Update to save changes everywhere.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _clearDieselEntryForm,
                  child: const Text('Cancel Edit'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _enterOrUpdateDieselRow(List<String> fuelTypes) {
    final litres = double.tryParse(_dieselLitresEntryController.text.trim());

    if (litres == null || litres < 0) {
      _showSnackbar('Enter valid litres', AppTheme.warning);
      return;
    }

    final fuelType = _activeDieselFuelType(fuelTypes);
    final stockPoint = _activeDieselStockPoint();
    final remarks = _dieselRemarksEntryController.text.trim();
    final editingId = _editingDieselEntryId;

    setState(() {
      if (editingId == null) {
        _dieselLogEntries.add(
          DieselLogEntry(
            id: 'DSL-${DateTime.now().microsecondsSinceEpoch}',
            fuelType: fuelType,
            stockPoint: stockPoint,
            liters: litres,
            remarks: remarks,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        final index = _dieselLogEntries.indexWhere(
          (entry) => entry.id == editingId,
        );
        if (index != -1) {
          _dieselLogEntries[index] = _dieselLogEntries[index].copyWith(
            fuelType: fuelType,
            stockPoint: stockPoint,
            liters: litres,
            remarks: remarks,
          );
        }
      }
      _refreshDieselConsumptionDataFromRows();
      _clearDieselEntryForm(resetStateOnly: true);
    });

    _showSnackbar(
      editingId == null ? 'Diesel row entered.' : 'Diesel row updated.',
      AppTheme.success,
    );
  }

  void _loadDieselRowForEdit(DieselLogEntry entry) {
    setState(() {
      _editingDieselEntryId = entry.id;
      _selectedDieselFuelType = entry.fuelType;
      _selectedDieselStockPoint = entry.stockPoint;
      _dieselLitresEntryController.text = _numberText(entry.liters);
      _dieselRemarksEntryController.text = entry.remarks;
    });
    _showSnackbar(
      'Diesel row loaded. Update the values and press Update.',
      AppTheme.info,
    );
  }

  void _deleteDieselRow(DieselLogEntry entry) {
    setState(() {
      _dieselLogEntries.removeWhere((row) => row.id == entry.id);
      if (_editingDieselEntryId == entry.id) {
        _clearDieselEntryForm(resetStateOnly: true);
      }
      _refreshDieselConsumptionDataFromRows();
    });
    _showSnackbar('Diesel row deleted.', AppTheme.warning);
  }

  void _clearDieselEntryForm({bool resetStateOnly = false}) {
    void clearValues() {
      _editingDieselEntryId = null;
      _dieselLitresEntryController.clear();
      _dieselRemarksEntryController.clear();
    }

    if (resetStateOnly) {
      clearValues();
    } else {
      setState(clearValues);
    }
  }

  Widget _buildDieselRowsDataTable(List<String> fuelTypes) {
    if (_dieselLogEntries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Text(
          'Enter diesel details above and press Enter. The row will appear here with Edit and Delete options.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Fuel Type')),
            DataColumn(label: Text('Stock Point')),
            DataColumn(label: Text('No. of Litres')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Action')),
          ],
          rows: _dieselLogEntries.map((entry) {
            final amount = _dieselEntryAmount(entry);
            final isEditing = _editingDieselEntryId == entry.id;
            return DataRow(
              selected: isEditing,
              onSelectChanged: (_) => _loadDieselRowForEdit(entry),
              cells: [
                DataCell(Text(entry.fuelType)),
                DataCell(Text(entry.stockPoint)),
                DataCell(Text('${entry.liters.toStringAsFixed(1)}')),
                DataCell(Text('₹${amount.toStringAsFixed(2)}')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _loadDieselRowForEdit(entry),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.info,
                          size: 20,
                        ),
                        tooltip: 'Edit row',
                      ),
                      IconButton(
                        onPressed: () => _deleteDieselRow(entry),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.danger,
                          size: 20,
                        ),
                        tooltip: 'Delete row',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Workers section ───────────────────────────────────────────────────────
  // ── Workers section removed from log data; workers are controlled on machine cards ──
  Widget _buildWorkersSection() {
    final summary = _currentMachineIdForDetail == null
        ? null
        : _machineSummaries[_currentMachineIdForDetail];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withOpacity(0.2)),
      ),
      child: Text(
        'Workers are controlled from the machine card before opening log data. Current workers: ${summary?.workerCount ?? 0}',
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.info),
      ),
    );
  }

  // ── FIX 3: Bill upload section — standalone step after Workers ────────────
  Widget _buildBillUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attach Bill / Receipt for this log entry',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickGeneralBill,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Upload Bill'),
              style:
                  OutlinedButton.styleFrom(foregroundColor: AppTheme.warning),
            ),
            if (_generalBillFileName != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.warning.withOpacity(0.3)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.description,
                          color: AppTheme.warning, size: 28),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _generalBillFileName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppTheme.danger),
                      onPressed: () =>
                          setState(() => _generalBillFileName = null),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (_generalBillFileName == null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warningBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Optional: attach a bill or receipt for this daily log.',
                    style: TextStyle(fontSize: 11, color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Notes field ───────────────────────────────────────────────────────────
  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Notes',
        hintText: 'Any special events or remarks for today...',
        prefixIcon: const Icon(Icons.notes_outlined, size: 18),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ── Remaining detail-form widgets ─────────────────────────────────────────
  Widget _buildDetailHeader() {
    final machine = _currentMachineDetail!;
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.info.withOpacity(0.15),
              AppTheme.info.withOpacity(0.05),
            ]),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: const Text('🔄', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${machine['name']} (${machine['id']})',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${machine['type']} • ${machine['location']}',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDieselModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? color : AppTheme.border,
              width: selected ? 1.4 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: selected ? color : AppTheme.textSecondary, size: 22),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTinyMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.info.withOpacity(0.1), AppTheme.infoBg]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child:
                const Icon(Icons.info_outline, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Log Entry',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Record machine hours, fuel consumption, and payments.',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard() {
    final hours = _totalWorkingHours.toStringAsFixed(1);
    final machine = _currentMachineDetail ?? const <String, String>{};
    final requiredHours =
        double.tryParse(machine['betaRequiredHours'] ?? '8') ?? 8.0;
    final isQualified = _totalWorkingHours >= requiredHours;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.access_time,
                color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Working Hours',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$hours hours today',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.warning)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isQualified ? AppTheme.successBg : AppTheme.dangerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isQualified
                  ? 'Beta Eligible'
                  : 'Min ${requiredHours.toStringAsFixed(0)}h needed',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isQualified ? AppTheme.success : AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String step, String title, Widget child,
      {required Color color}) {
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
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(step,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMachineDetailDisplay() {
    final machine = _currentMachineDetail!;
    final isBetaMachine = machine['betaEnabled'] == 'true';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          color: AppTheme.surface),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${machine['name']} (${machine['id']})',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${machine['type']} • ${machine['location']}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (isBetaMachine)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('BETA',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success)),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeBlocksSection() {
    return Column(
      children: [
        ..._timeBlocks
            .asMap()
            .entries
            .map((entry) => _buildTimeBlockCard(entry.value, entry.key)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _addTimeBlock,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Shift Block'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
        ),
      ],
    );
  }

  Widget _buildTimeBlockCard(TimeBlock block, int index) {
    final startMinutes = block.startTime.hour * 60 + block.startTime.minute;
    final endMinutes = block.endTime.hour * 60 + block.endTime.minute;
    final hours =
        endMinutes > startMinutes ? (endMinutes - startMinutes) / 60.0 : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warning)),
                ),
                const SizedBox(width: 10),
                Text('Shift ${index + 1}: ${hours.toStringAsFixed(1)}h',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              if (_timeBlocks.length > 1)
                IconButton(
                  onPressed: () => _removeTimeBlock(block.id),
                  icon:
                      const Icon(Icons.close, size: 18, color: AppTheme.danger),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildTimePickerField('Start Time', block.startTime,
                      () => _selectTime(context, block, true))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward,
                    size: 18, color: AppTheme.textMuted),
              ),
              Expanded(
                  child: _buildTimePickerField('End Time', block.endTime,
                      () => _selectTime(context, block, false))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerField(
      String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            const SizedBox(height: 2),
            Text(time.format(context),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBetaAmount() {
    final machine = _currentMachineDetail ?? const <String, String>{};
    final betaEnabled = machine['betaEnabled'] == 'true';
    final requiredHours =
        double.tryParse(machine['betaRequiredHours'] ?? '8') ?? 8.0;
    final eligibleText = _isBetaEligible
        ? 'Beta eligible: completed ${_totalWorkingHours.toStringAsFixed(1)}h.'
        : betaEnabled
            ? 'Regular beta locked: ${_totalWorkingHours.toStringAsFixed(1)}h completed, ${requiredHours.toStringAsFixed(0)}h required.'
            : 'Regular beta disabled for this machine. Extra Beta can still be requested for HOD review.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isBetaEligible ? AppTheme.successBg : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _isBetaEligible
                    ? AppTheme.success.withOpacity(0.3)
                    : AppTheme.border),
          ),
          child: Row(children: [
            Icon(
                _isBetaEligible
                    ? Icons.auto_awesome
                    : Icons.lock_clock_outlined,
                size: 20,
                color: _isBetaEligible ? AppTheme.success : AppTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                eligibleText,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isBetaEligible
                        ? AppTheme.success
                        : AppTheme.textSecondary),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _betaController,
          enabled: _isBetaEligible,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Regular Beta Amount ₹',
            hintText: _isBetaEligible
                ? 'Enter incentive amount'
                : 'Regular beta not eligible yet',
            prefixIcon: const Icon(Icons.attach_money, size: 18),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Extra Beta',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    const Text('Always visible in HOD app for approval/review'),
                value: _enableExtraBeta,
                activeColor: AppTheme.success,
                onChanged: (value) => setState(() => _enableExtraBeta = value),
              ),
              if (_enableExtraBeta) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _extraBetaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Extra Beta Amount ₹',
                    prefixIcon: Icon(Icons.add_card_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _extraBetaNoteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Extra Beta Reason / HOD Note',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final cashAmount = _enableCashPayment
        ? (double.tryParse(_cashAmountController.text) ?? 0)
        : 0.0;
    final advanceAmount = _enableAdvancePayment
        ? (double.tryParse(_advanceAmountController.text) ?? 0)
        : 0.0;
    final dieselLitres = _dieselConsumptionTotalLitres;
    final dieselAmount = _dieselTotalAmount;
    final betaAmount =
        _isBetaEligible ? (double.tryParse(_betaController.text) ?? 0) : 0.0;
    final extraBetaAmount = _enableExtraBeta
        ? (double.tryParse(_extraBetaController.text) ?? 0)
        : 0.0;
    final total = cashAmount +
        advanceAmount +
        dieselAmount +
        betaAmount +
        extraBetaAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text("Today's Summary",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70)),
              ),
              Text('${_totalWorkingHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
              'Cash', '₹${cashAmount.toStringAsFixed(0)}'),
          _buildSummaryRow(
              'Advance', '₹${advanceAmount.toStringAsFixed(0)}'),
          _buildSummaryRow(
              'Diesel',
              '${dieselLitres.toStringAsFixed(1)} L · '
              '₹${dieselAmount.toStringAsFixed(0)}'),
          _buildSummaryRow('Beta', '₹${betaAmount.toStringAsFixed(0)}'),
          _buildSummaryRow(
              'Extra Beta', '₹${extraBetaAmount.toStringAsFixed(0)}'),
          _buildSummaryRow('Fuel Lines', _dieselLogEntries.length.toString()),
          _buildSummaryRow(
              'Workers',
              '${_currentMachineIdForDetail == null ? 0 : (_machineSummaries[_currentMachineIdForDetail!]?.workerCount ?? 0)}'),
          const Divider(color: Colors.white24, height: 20),
          _buildSummaryRow(
              'Pay Total', '₹${total.toStringAsFixed(0)}', emphasized: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool emphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 13 : 12,
              fontWeight:
                  emphasized ? FontWeight.w700 : FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.info,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Save Daily Log',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

class HistoryDateDetailPage extends StatefulWidget {
  final DateTime date;
  final List<MachineLogRecord> logs;
  final String Function(DateTime) formatDateTime;

  const HistoryDateDetailPage({
    super.key,
    required this.date,
    required this.logs,
    required this.formatDateTime,
  });

  @override
  State<HistoryDateDetailPage> createState() => _HistoryDateDetailPageState();
}

class _HistoryDateDetailPageState extends State<HistoryDateDetailPage> {
  String _typeFilter = 'All';

  List<String> get _types => ['All', ...widget.logs.map((e) => e.type).toSet()];

  List<MachineLogRecord> get _visibleLogs {
    final logs = _typeFilter == 'All'
        ? widget.logs
        : widget.logs.where((log) => log.type == _typeFilter).toList();
    return logs..sort((a, b) => b.date.compareTo(a.date));
  }

  String _dateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'Cash Payment':
        return AppTheme.info;
      case 'Advance Request':
        return AppTheme.success;
      case 'Daily Log':
        return AppTheme.warning;
      case 'Machine Transfer':
        return AppTheme.primary;
      case 'Machine Closure':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'Cash Payment':
        return Icons.payments_outlined;
      case 'Advance Request':
        return Icons.request_quote_outlined;
      case 'Daily Log':
        return Icons.edit_note_outlined;
      case 'Machine Transfer':
        return Icons.swap_horiz;
      case 'Machine Closure':
        return Icons.lock_outline;
      case 'Worker Update':
        return Icons.groups_outlined;
      case 'Bill Upload':
        return Icons.receipt_long_outlined;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _visibleLogs;
    final total = logs.fold<double>(0, (sum, log) => sum + log.amount);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('History • ${_dateLabel(widget.date)}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date-wise Entry View',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${logs.length} log(s) • ₹${total.toStringAsFixed(0)} total',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _types.map((type) {
                  final selected = _typeFilter == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      label: Text(type),
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surfaceCard,
                      side: BorderSide(
                          color: selected ? AppTheme.primary : AppTheme.border),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppTheme.textSecondary,
                      ),
                      onSelected: (_) => setState(() => _typeFilter = type),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (logs.isEmpty)
              _emptyState()
            else
              ...logs.map(_buildEntryStyleLogCard),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_outlined, size: 44, color: AppTheme.textMuted),
          SizedBox(height: 8),
          Text('No logs for this filter',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildEntryStyleLogCard(MachineLogRecord log) {
    final color = _colorFor(log.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconFor(log.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.type,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        '${log.machineName} • ${widget.formatDateTime(log.date)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (log.amount > 0)
                Text('₹${log.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
            ],
          ),
          const SizedBox(height: 14),
          _entryStep('1', 'Machine Info', color, {
            'Machine ID': log.machineId,
            'Machine Name': log.machineName,
            'Log ID': log.id,
            'Status': log.status,
          }),
          const SizedBox(height: 10),
          _entryStep('2', _sectionTitleFor(log.type), color, log.details),
        ],
      ),
    );
  }

  String _sectionTitleFor(String type) {
    switch (type) {
      case 'Daily Log':
        return 'Saved Daily Data';
      case 'Cash Payment':
        return 'Cash Payment Details';
      case 'Advance Request':
        return 'Advance Request Details';
      case 'Machine Transfer':
        return 'Transfer Details';
      case 'Machine Closure':
        return 'Closure Details';
      default:
        return 'Entered Details';
    }
  }

  Widget _entryStep(
      String step, String title, Color color, Map<String, String> values) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(step,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ...values.entries.map((entry) => _detailRow(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── TimeBlock model ───────────────────────────────────────────────────────────
class TimeBlock {
  final String id;
  TimeOfDay startTime;
  TimeOfDay endTime;

  TimeBlock({required this.id, required this.startTime, required this.endTime});
}
