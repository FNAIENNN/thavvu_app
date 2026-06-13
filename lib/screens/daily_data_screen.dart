import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/diesel_consumption_table.dart';

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
  final String? note;
  final String? billImagePath;

  PaymentTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.method,
    required this.date,
    this.note,
    this.billImagePath,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────
class DailyDataScreen extends StatefulWidget {
  const DailyDataScreen({super.key});

  @override
  State<DailyDataScreen> createState() => _DailyDataScreenState();
}

class _DailyDataScreenState extends State<DailyDataScreen> {
  final List<Map<String, String>> _machines = [
    {
      'id': 'MCH-001',
      'name': 'Excavator',
      'type': 'Heavy',
      'location': 'Site A',
      'dieselOption': 'With diesel',
      'isArchived': 'false',
    },
    {
      'id': 'MCH-002',
      'name': 'Loader',
      'type': 'Medium',
      'location': 'Site A',
      'dieselOption': 'With diesel',
      'isArchived': 'false',
    },
    {
      'id': 'MCH-003',
      'name': 'Crane',
      'type': 'Heavy',
      'location': 'Site B',
      'dieselOption': 'With diesel',
      'isArchived': 'false',
    },
    {
      'id': 'MCH-004',
      'name': 'Dump Truck',
      'type': 'Medium',
      'location': 'Site B',
      'dieselOption': 'With diesel',
      'isArchived': 'false',
    },
    {
      'id': 'MCH-005',
      'name': 'Compactor',
      'type': 'Light',
      'location': 'Site C',
      'dieselOption': 'Without diesel',
      'isArchived': 'false',
    },
  ];

  Map<String, MachineSummary> _machineSummaries = {};
  bool _showMachineList = true;
  String? _currentMachineIdForDetail;
  bool _showArchived = false;

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

  // Beta
  bool _isBetaEligible = false;
  final TextEditingController _betaController = TextEditingController();
  double _totalWorkingHours = 0.0;
  final double _betaRequiredHours = 8.0;
  final List<String> _betaEligibleMachines = ['MCH-001', 'MCH-003', 'MCH-005'];

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
      note: 'Operator advance',
    ),
  ];

  final List<String> _stockPoints = [
    'Main Depot',
    'Site A',
    'Site B',
    'Warehouse 1',
    'Fuel Station 3',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _advanceAmountController.dispose();
    _dieselController.dispose();
    _betaController.dispose();
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

  // ── Machine-list actions ──────────────────────────────────────────────────

  // ── FIX 2: Block worker increment when machine is in transferred state ──
  void _incrementWorkerCount(String machineId) {
    final summary = _machineSummaries[machineId];
    if (summary == null || summary.isTransferred) return;
    setState(() => summary.incrementWorkers());
    _showSnackbar('Worker count increased', AppTheme.success);
  }

  void _showMachineOptions(String machineId) {
    final machine = _machines.firstWhere((m) => m['id'] == machineId);
    final isArchived = machine['isArchived'] == 'true';
    final summary = _machineSummaries[machineId]!;
    final isClosed = summary.retrievedFuel > 0;
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
                enabled: !isTransferred,
                onTap: isTransferred
                    ? null
                    : () {
                        Navigator.pop(context);
                        _openLogDetail(machineId);
                      },
              ),
              if (isClosed) ...[
                const Divider(),
                ListTile(
                  leading:
                      const Icon(Icons.lock_open, color: AppTheme.success),
                  title: const Text('Reopen Machine'),
                  subtitle: const Text('Allow operations again'),
                  onTap: () {
                    Navigator.pop(context);
                    _reopenMachine(machineId);
                  },
                ),
              ],
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
              if (!isTransferred) ...[
                const Divider(),
                ListTile(
                  leading:
                      const Icon(Icons.swap_horiz, color: AppTheme.info),
                  title: const Text('Transfer Machine'),
                  subtitle: const Text(
                      'Move to another site (Thavvu ID required)'),
                  onTap: () {
                    Navigator.pop(context);
                    _showTransferSheet(machineId);
                  },
                ),
              ] else ...[
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
                leading:
                    const Icon(Icons.person_remove, color: AppTheme.danger),
                title: const Text('Remove Workers'),
                subtitle: const Text('Clear all workers'),
                onTap: () {
                  Navigator.pop(context);
                  _removeWorkers(machineId);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.archive_outlined,
                    color: AppTheme.textSecondary),
                title: const Text('Archive Machine'),
                subtitle:
                    const Text('Move to archive (can be restored later)'),
                onTap: () {
                  Navigator.pop(context);
                  _archiveMachine(machineId);
                },
              ),
            ] else ...[
              ListTile(
                leading:
                    const Icon(Icons.unarchive, color: AppTheme.success),
                title: const Text('Reactivate Machine'),
                subtitle: const Text('Move back to active list'),
                onTap: () {
                  Navigator.pop(context);
                  _reactivateMachine(machineId);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever,
                    color: AppTheme.danger),
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
    setState(() {
      _machines.firstWhere((m) => m['id'] == machineId)['isArchived'] = 'true';
    });
    _showSnackbar('Machine archived', AppTheme.info);
  }

  void _reactivateMachine(String machineId) {
    setState(() {
      _machines.firstWhere((m) => m['id'] == machineId)['isArchived'] =
          'false';
    });
    _showSnackbar('Machine reactivated', AppTheme.success);
  }

  void _reopenMachine(String machineId) {
    setState(() => _machineSummaries[machineId]?.retrievedFuel = 0);
    _showSnackbar('Machine reopened and ready for operations', AppTheme.success);
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
    final thavvuCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transfer Machine',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: thavvuCtrl,
              decoration: InputDecoration(
                labelText: 'Thavvu ID *',
                hintText: 'e.g., THV-2025',
                prefixIcon: const Icon(Icons.credit_card),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: destCtrl,
              decoration: InputDecoration(
                labelText: 'Destination / Remarks',
                prefixIcon: const Icon(Icons.location_on),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
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
                  setState(() {
                    _machineSummaries[machineId]?.addTransferEvent(
                      thavvuCtrl.text.trim(),
                      destCtrl.text.trim().isEmpty
                          ? 'Not specified'
                          : destCtrl.text.trim(),
                    );
                  });
                  Navigator.pop(ctx);
                  _showSnackbar(
                      'Machine transferred successfully', AppTheme.success);
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
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _reenterMachine(String machineId) {
    setState(() => _machineSummaries[machineId]?.addReenterEvent());
    _showSnackbar('Machine re-entered to site', AppTheme.success);
  }

  void _openLogDetail(String machineId) {
    setState(() {
      _currentMachineIdForDetail = machineId;
      _showMachineList = false;
      _resetFormFields();
      _dieselOption = _machineSummaries[machineId]!.dieselOption;
      _currentWorkerCount = _machineSummaries[machineId]!.workerCount;
      _calculateWorkingHours();
      _checkBetaEligibility();
    });
  }

  void _showCloseMachineSheet(String machineId) {
    final retrievedController = TextEditingController();
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
            const SizedBox(height: 16),
            const Text('Close Machine - Retrieved Fuel',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: retrievedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Retrieved Fuel Amount (litres)',
                prefixIcon: const Icon(Icons.local_gas_station),
                suffixText: 'litres',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount =
                      double.tryParse(retrievedController.text) ?? 0;
                  if (amount > 0) {
                    setState(() =>
                        _machineSummaries[machineId]!.retrievedFuel = amount);
                    Navigator.pop(context);
                    _showSnackbar(
                        'Machine closed. Retrieved $amount litres of fuel.',
                        AppTheme.success);
                  } else {
                    _showSnackbar(
                        'Please enter a valid fuel amount', AppTheme.warning);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit Closure',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _removeWorkers(String machineId) {
    setState(() => _machineSummaries[machineId]?.clearWorkers());
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
    _betaController.clear();
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
      final startMinutes =
          block.startTime.hour * 60 + block.startTime.minute;
      final endMinutes = block.endTime.hour * 60 + block.endTime.minute;
      if (endMinutes > startMinutes) {
        totalHours += (endMinutes - startMinutes) / 60.0;
      }
    }
    setState(() => _totalWorkingHours = totalHours);
  }

  void _checkBetaEligibility() {
    _isBetaEligible = _totalWorkingHours >= _betaRequiredHours &&
        _currentMachineIdForDetail != null &&
        _betaEligibleMachines.contains(_currentMachineIdForDetail);
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
    final cashTxn = PaymentTransaction(
      id: 'TXN-${DateTime.now().millisecondsSinceEpoch}',
      type: 'cash',
      amount: cashAmount,
      method: 'Cash',
      date: DateTime.now(),
      note: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    setState(() {
      _cashBalance -= cashAmount;
      _cashTransactions.insert(0, cashTxn);
      _cashAmountController.clear();
      _enableCashPayment = false;
    });
    _showSnackbar(
        'Cash payment of ₹${cashAmount.toStringAsFixed(0)} processed. Remaining balance: ₹${_cashBalance.toStringAsFixed(0)}',
        AppTheme.success);
  }

  // ── Advance request ───────────────────────────────────────────────────────
  void _submitAdvanceRequest() {
    if (!_enableAdvancePayment) return;
    final advanceAmount =
        double.tryParse(_advanceAmountController.text) ?? 0;
    if (advanceAmount <= 0) {
      _showSnackbar('Enter a valid advance amount', AppTheme.warning);
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
    final advMethod = _selectedAdvanceMode == 'upi'
        ? 'UPI'
        : (_selectedBankAccount != null ? 'Bank (saved)' : 'Bank (manual)');
    final advTxn = PaymentTransaction(
      id: 'ADV-${DateTime.now().millisecondsSinceEpoch}',
      type: 'advance',
      amount: advanceAmount,
      method: advMethod,
      date: DateTime.now(),
    );
    setState(() {
      _advanceTransactions.insert(0, advTxn);
      _advanceAmountController.clear();
      _enableAdvancePayment = false;
      _selectedAdvanceMode = null;
      _selectedEntryMethod = null;
      _selectedBankAccount = null;
    });
    _showSnackbar(
        'Advance request for ₹${advanceAmount.toStringAsFixed(0)} submitted to finance.',
        AppTheme.success);
  }

  // ── Submit log ────────────────────────────────────────────────────────────
  void _submitLog() {
    if (_currentMachineIdForDetail == null) {
      _showSnackbar('No machine selected', AppTheme.danger);
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
      final advanceAmount =
          double.tryParse(_advanceAmountController.text) ?? 0;
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
          _showSnackbar(
              'Please select an entry method for bank details',
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
    final dieselAmount = _dieselOption == 'With diesel'
        ? (double.tryParse(_dieselController.text) ?? 0)
        : 0.0;
    final betaAmount = double.tryParse(_betaController.text) ?? 0;
    final totalAmount = cashAmount + advanceAmount + dieselAmount + betaAmount;

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _machineSummaries[_currentMachineIdForDetail]?.updateFromLog(
            _totalWorkingHours, dieselAmount, totalAmount);
        _machineSummaries[_currentMachineIdForDetail]?.workerCount =
            _currentWorkerCount;
        _showSnackbar(
            'Daily log saved for machine ${_currentMachineDetail!['name']}!',
            AppTheme.success);
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final title =
        isCash ? 'Cash Payment History' : 'Advance Request History';

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
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
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
                                color:
                                    AppTheme.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text('No transactions yet',
                                style:
                                    TextStyle(color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
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
                              border: Border.all(
                                  color: color.withOpacity(0.15)),
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
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                              color:
                                                  color.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text(txn.method,
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: color)),
                                        ),
                                      ]),
                                      const SizedBox(height: 3),
                                      if (txn.note != null &&
                                          txn.note!.isNotEmpty)
                                        Text(txn.note!,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme
                                                    .textSecondary)),
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
      final acc =
          _savedAccounts.firstWhere((a) => a['id'] == existingId);
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
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
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
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
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
      final b =
          _savedBankAccounts.firstWhere((b) => b['id'] == existingId);
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
                  existingId != null
                      ? 'Edit Bank Account'
                      : 'Add Bank Account',
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
                    if (accCtrl.text.length >= 4 &&
                        bankCtrl.text.isNotEmpty) {
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
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(_showMachineList
            ? (_showArchived ? 'Archived Machines' : 'Machines Daily Data')
            : 'Log Data - ${_currentMachineDetail?['name'] ?? ''}'),
        leading: IconButton(
          icon: Icon(_showMachineList
              ? Icons.arrow_back
              : Icons.arrow_back_ios),
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
      ),
      body: _showMachineList ? _buildMachineList() : _buildDetailForm(),
    );
  }

  // ── Machine list view ─────────────────────────────────────────────────────
  Widget _buildMachineList() {
    final displayed = _machines
        .where(
            (m) => m['isArchived'] == (_showArchived ? 'true' : 'false'))
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListHeader(),
          const SizedBox(height: 16),
          if (displayed.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(
                      _showArchived
                          ? Icons.archive
                          : Icons.inventory_2,
                      size: 64,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _showArchived
                          ? 'No archived machines'
                          : 'No machines available',
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

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _showArchived
                ? 'Archived Machines'
                : 'Today\'s Machine Summary',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white),
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
    final bool isClosed = summary.retrievedFuel > 0;
    final bool isTransferred = summary.isTransferred;

    // ── FIX 1: compute re-enter count from transfer history ──────────────
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
                // Machine icon
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
                  child: Icon(Icons.construction,
                      color: AppTheme.info, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(machine['name']!,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(
                          '${machine['id']} • ${machine['type']} • ${machine['location']}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                // ── FIX 2: Worker add button is disabled while transferred ──
                if (!_showArchived)
                  GestureDetector(
                    onTap: isTransferred
                        ? null
                        : () => _incrementWorkerCount(machine['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isTransferred
                            ? AppTheme.textMuted.withOpacity(0.08)
                            : AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isTransferred
                              ? AppTheme.textMuted.withOpacity(0.2)
                              : AppTheme.success.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_add,
                              size: 16,
                              color: isTransferred
                                  ? AppTheme.textMuted
                                  : AppTheme.success),
                          const SizedBox(width: 4),
                          Text(
                            '${summary.workerCount}',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isTransferred
                                    ? AppTheme.textMuted
                                    : AppTheme.success),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── Status badges ────────────────────────────────────────────
            if (!_showArchived) ...[
              if (isTransferred) ...[
                // Active transfer badge
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.info.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_horiz,
                            size: 14, color: AppTheme.info),
                        const SizedBox(width: 4),
                        Text(
                          'TRANSFERRED (x${summary.transferEventCount})',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.info),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (hasBeenReentered) ...[
                // ── FIX 1: Re-entered badge with count ──────────────────
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment_return,
                            size: 14, color: AppTheme.success),
                        const SizedBox(width: 4),
                        Text(
                          'RE-ENTERED (x$reenterCount)',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (isClosed) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.danger.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: AppTheme.danger),
                        SizedBox(width: 4),
                        Text('MACHINE CLOSED',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.danger)),
                      ],
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 14),
            Row(
              children: [
                _buildListStat('Hours',
                    '${summary.hoursWorked.toStringAsFixed(1)}h',
                    Icons.access_time, AppTheme.warning),
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
            if (summary.retrievedFuel > 0 && !_showArchived) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.recycling,
                      size: 14, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Text(
                      'Retrieved: ${summary.retrievedFuel.toStringAsFixed(1)} L',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.warning)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.touch_app,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                const Text('Tap for options',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
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
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
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
          // Step 1 — Machine Info
          _buildStepCard('1', 'Machine Info', _buildMachineDetailDisplay(),
              color: AppTheme.info),
          const SizedBox(height: 12),
          // Step 2 — Working Time Blocks
          _buildStepCard('2', 'Working Time Blocks',
              _buildTimeBlocksSection(),
              color: AppTheme.warning),
          const SizedBox(height: 12),
          // Step 3 — Payment Details
          _buildStepCard('3', 'Payment Details', _buildPaymentSection(),
              color: AppTheme.success),
          const SizedBox(height: 12),
          // Step 4 — Diesel
          _buildStepCard(
              '4',
              _dieselOption == 'With diesel'
                  ? 'Advance Diesel'
                  : 'Diesel Consumption',
              _buildDieselSection(),
              color: AppTheme.warning),
          if (_isBetaEligible) ...[
            const SizedBox(height: 12),
            // Step 5 — Beta Incentive (conditional)
            _buildStepCard('5', 'Beta Incentive', _buildBetaAmount(),
                color: AppTheme.success),
          ],
          const SizedBox(height: 12),
          // Step 6 — Workers
          _buildStepCard('6', 'Workers', _buildWorkersSection(),
              color: AppTheme.info),
          const SizedBox(height: 12),
          // ── FIX 3: Bill Upload placed RIGHT AFTER Workers ──────────────
          _buildStepCard('7', 'Bill Upload', _buildBillUploadSection(),
              color: AppTheme.warning),
          const SizedBox(height: 12),
          // Step 8 — Additional Notes
          _buildStepCard('8', 'Additional Notes', _buildNotesField(),
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
                subtitle:
                    const Text('Pay via cash (HOD limit applies)'),
                value: _enableCashPayment,
                activeColor: AppTheme.info,
                onChanged: (val) =>
                    setState(() => _enableCashPayment = val),
              ),
            ),
            GestureDetector(
              onTap: () => _showTransactionHistorySheet('cash'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.info.withOpacity(0.3)),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
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
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          TextField(
            controller: _cashAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cash Amount (₹)',
              hintText: 'Max ₹${_cashLimit.toStringAsFixed(0)}',
              prefixIcon:
                  const Icon(Icons.currency_rupee, size: 18),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
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
                      (double.tryParse(
                                  _cashAmountController.text) ??
                              0) >
                          0)
                  ? _proceedCashPayment
                  : null,
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Proceed Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.info,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // ── Advance Request toggle ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Advance Request',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    const Text('Request advance from finance'),
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
      ],
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
          border:
              Border.all(color: AppTheme.info.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppTheme.info),
            const SizedBox(width: 8),
            Text('Balance after payment: ₹$_cashBalance',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.info)),
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
          border: Border.all(
              color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                size: 16, color: AppTheme.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Exceeds HOD limit of ₹${_cashLimit.toStringAsFixed(0)}. Please reduce or request advance.',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.danger),
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
          border: Border.all(
              color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber,
                size: 16, color: AppTheme.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Insufficient cash balance (avail: ₹${_cashBalance.toStringAsFixed(0)}).',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.danger),
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
          border: Border.all(
              color: AppTheme.success.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                size: 16, color: AppTheme.success),
            const SizedBox(width: 8),
            Text(
                'Valid. Balance after payment: ₹${remaining.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.success)),
          ],
        ),
      );
    }
  }

  Widget _buildAdvancePaymentSection() {
    final advanceAmount =
        double.tryParse(_advanceAmountController.text) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _advanceAmountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Advance Amount (₹)',
            prefixIcon:
                const Icon(Icons.request_quote, size: 18),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedAdvanceMode == 'upi'
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _selectedAdvanceMode == 'upi'
                            ? AppTheme.success
                            : AppTheme.border,
                        width:
                            _selectedAdvanceMode == 'upi' ? 2 : 1),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedAdvanceMode == 'bank'
                        ? AppTheme.info.withOpacity(0.1)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _selectedAdvanceMode == 'bank'
                            ? AppTheme.info
                            : AppTheme.border,
                        width:
                            _selectedAdvanceMode == 'bank' ? 2 : 1),
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
        if (_selectedAdvanceMode == 'upi')
          _buildUpiAccountSelection(),
        if (_selectedAdvanceMode == 'bank')
          _buildBankDetailsSection(),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
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
    final upiAccounts = _savedAccounts
        .where((a) => a['upiId']!.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Verified UPI Account',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        ...upiAccounts.map((account) => GestureDetector(
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
                child: _buildEntryMethodOption(
                    'manual', 'Manual', Icons.edit_outlined)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildEntryMethodOption(
                    'photo', 'Photo', Icons.camera_alt_outlined)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildEntryMethodOption(
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
        if (_selectedEntryMethod != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.success.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline,
                  size: 16, color: AppTheme.success),
              SizedBox(width: 8),
              Expanded(
                child: Text('Request will be sent to Finance Department',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.success)),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildEntryMethodOption(
      String method, String title, IconData icon) {
    final isSelected = _selectedEntryMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedEntryMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.success.withOpacity(0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? AppTheme.success : AppTheme.border,
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: isSelected
                    ? AppTheme.success
                    : AppTheme.textSecondary),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _dieselOption == 'With diesel'
                ? AppTheme.infoBg
                : AppTheme.warningBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _dieselOption == 'With diesel'
                ? 'Advance Diesel'
                : 'Diesel Consumption',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _dieselOption == 'With diesel'
                  ? AppTheme.info
                  : AppTheme.warning,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_dieselOption == 'With diesel') ...[
          TextField(
            controller: _dieselController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Advance Diesel Quantity (litres)',
              hintText: 'Enter litres',
              prefixIcon: const Icon(Icons.local_gas_station_outlined,
                  size: 18),
              suffixText: 'litres',
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
        ],
        DieselConsumptionTable(
          fuelTypes: fuelTypes,
          stockPoints: _stockPoints,
          onChanged: (data) {
            debugPrint('Diesel consumption data: $data');
          },
        ),
      ],
    );
  }

  // ── Workers section ───────────────────────────────────────────────────────
  Widget _buildWorkersSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Workers on site',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.danger),
                  onPressed: () {
                    setState(() {
                      if (_currentWorkerCount > 0)
                        _currentWorkerCount--;
                    });
                  },
                ),
                Text('$_currentWorkerCount',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.success),
                  onPressed: () =>
                      setState(() => _currentWorkerCount++),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _currentWorkerCount > 0
                ? () {
                    setState(() => _currentWorkerCount = 0);
                    _showSnackbar(
                        'All workers cleared for this machine.',
                        AppTheme.success);
                  }
                : null,
            icon: const Icon(Icons.person_remove, size: 16),
            label: const Text('Clear All Workers'),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.danger),
          ),
        ),
      ],
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
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warning),
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
                            fontSize: 11,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppTheme.danger),
                      onPressed: () => setState(
                          () => _generalBillFileName = null),
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
              border: Border.all(
                  color: AppTheme.warning.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppTheme.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Optional: attach a bill or receipt for this daily log.',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.warning),
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
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
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
          child:
              const Text('🔄', style: TextStyle(fontSize: 28)),
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
                      fontSize: 13,
                      color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
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
            child: const Icon(Icons.info_outline,
                color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Log Entry',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                    'Record machine hours, fuel consumption, and payments.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard() {
    final hours = _totalWorkingHours.toStringAsFixed(1);
    final isQualified = _totalWorkingHours >= _betaRequiredHours;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.warning.withOpacity(0.25)),
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
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isQualified ? AppTheme.successBg : AppTheme.dangerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isQualified
                  ? 'Beta Eligible'
                  : 'Min ${_betaRequiredHours.toStringAsFixed(0)}h needed',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isQualified
                      ? AppTheme.success
                      : AppTheme.danger),
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
                    gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.8)]),
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
    final isBetaMachine =
        _betaEligibleMachines.contains(machine['id']);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('${machine['type']} • ${machine['location']}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (isBetaMachine)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
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
            .map((entry) =>
                _buildTimeBlockCard(entry.value, entry.key)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _addTimeBlock,
          icon:
              const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Shift Block'),
          style: TextButton.styleFrom(
              foregroundColor: AppTheme.warning),
        ),
      ],
    );
  }

  Widget _buildTimeBlockCard(TimeBlock block, int index) {
    final startMinutes =
        block.startTime.hour * 60 + block.startTime.minute;
    final endMinutes =
        block.endTime.hour * 60 + block.endTime.minute;
    final hours = endMinutes > startMinutes
        ? (endMinutes - startMinutes) / 60.0
        : 0.0;
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
              if (_timeBlocks.length > 1)
                IconButton(
                  onPressed: () => _removeTimeBlock(block.id),
                  icon: const Icon(Icons.close,
                      size: 18, color: AppTheme.danger),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildTimePickerField('Start Time',
                      block.startTime,
                      () => _selectTime(context, block, true))),
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward,
                    size: 18, color: AppTheme.textMuted),
              ),
              Expanded(
                  child: _buildTimePickerField('End Time',
                      block.endTime,
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
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textMuted)),
            const SizedBox(height: 2),
            Text(time.format(context),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBetaAmount() {
    if (!_isBetaEligible) return const SizedBox.shrink();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.success.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.auto_awesome,
                size: 20, color: AppTheme.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Beta Eligible!',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success)),
                  Text(
                      'Completed ${_totalWorkingHours.toStringAsFixed(1)}h (min ${_betaRequiredHours.toStringAsFixed(0)}h required)',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _betaController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Beta Amount',
            hintText: 'Incentive payment amount',
            prefixIcon:
                const Icon(Icons.attach_money, size: 18),
            suffixText: '₹',
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
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
    final dieselAmount = _dieselOption == 'With diesel'
        ? (double.tryParse(_dieselController.text) ?? 0)
        : 0.0;
    final betaAmount =
        double.tryParse(_betaController.text) ?? 0;
    final total =
        cashAmount + advanceAmount + dieselAmount + betaAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent]),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today\'s Summary',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_enableCashPayment) ...[
                _buildSummaryItem('Cash',
                    '₹${cashAmount.toStringAsFixed(0)}',
                    Icons.money),
                const SizedBox(width: 8),
              ],
              if (_enableAdvancePayment) ...[
                _buildSummaryItem('Advance',
                    '₹${advanceAmount.toStringAsFixed(0)}',
                    Icons.request_quote),
                const SizedBox(width: 8),
              ],
              if (_dieselOption == 'With diesel') ...[
                _buildSummaryItem('Diesel',
                    '₹${dieselAmount.toStringAsFixed(0)}',
                    Icons.local_gas_station),
                const SizedBox(width: 8),
              ],
              if (_isBetaEligible) ...[
                _buildSummaryItem('Beta',
                    '₹${betaAmount.toStringAsFixed(0)}',
                    Icons.auto_awesome),
                const SizedBox(width: 8),
              ],
              _buildSummaryItem('Total',
                  '₹${total.toStringAsFixed(0)}', Icons.calculate),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hours',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white70)),
              Text('${_totalWorkingHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon) {
    return Expanded(
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
              style: const TextStyle(
                  fontSize: 9, color: Colors.white60)),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
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
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

// ── TimeBlock model ───────────────────────────────────────────────────────────
class TimeBlock {
  final String id;
  TimeOfDay startTime;
  TimeOfDay endTime;

  TimeBlock(
      {required this.id,
      required this.startTime,
      required this.endTime});
}