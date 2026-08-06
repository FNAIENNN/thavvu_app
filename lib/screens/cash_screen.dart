import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cash_allocation_model.dart';
import '../models/supervisor_cash_expense_model.dart';
import '../services/auth_service.dart';
import '../services/cash_allocation_service.dart';
import '../services/attendance_context_service.dart';
import '../services/cash_repository.dart' as cash_repo;
import '../services/hod_site_workspace_service.dart';
import '../services/pending_writes_store.dart';
import '../services/supervisor_cash_expense_service.dart';
import '../theme/app_theme.dart';
import '../widgets/collapsible_tab_scaffold.dart';
import 'hod_module_review_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class Site {
  final String id;
  final String name;
  Site({required this.id, required this.name});
}

class CashTransaction {
  final String id;
  final String reason;
  final DateTime dateTime;
  final double amount;
  final String? siteId;
  final String category; // 'food', 'assets', 'others', 'transport'
  final String? paymentMethod;
  final String? thavvuId;
  final String? invoiceBillPath;
  final String? vehiclePhotoPath;
  final List<CashExpenseItem> items;

  CashTransaction({
    required this.id,
    required this.reason,
    required this.dateTime,
    required this.amount,
    this.siteId,
    this.category = 'others',
    this.paymentMethod,
    this.thavvuId,
    this.invoiceBillPath,
    this.vehiclePhotoPath,
    this.items = const [],
  });
}

class CashExpenseItem {
  final String name;
  final int quantity;
  final double amount;
  final String category;
  final bool transportEnabled;
  final String? vehicleType;
  final double transportAmount;

  const CashExpenseItem({
    required this.name,
    required this.quantity,
    required this.amount,
    this.category = 'others',
    this.transportEnabled = false,
    this.vehicleType,
    this.transportAmount = 0,
  });

  CashExpenseItem copyWith({
    String? name,
    int? quantity,
    double? amount,
    String? category,
    bool? transportEnabled,
    String? vehicleType,
    double? transportAmount,
  }) {
    return CashExpenseItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      transportEnabled: transportEnabled ?? this.transportEnabled,
      vehicleType: vehicleType ?? this.vehicleType,
      transportAmount: transportAmount ?? this.transportAmount,
    );
  }

  double get baseTotal => quantity * amount;

  double get total => baseTotal + (transportEnabled ? transportAmount : 0);

  String get transportSummary {
    if (!transportEnabled) return 'No transport';
    final vehicle =
        vehicleType == null || vehicleType!.isEmpty ? 'Vehicle' : vehicleType!;
    return '$vehicle • ₹${transportAmount.toStringAsFixed(0)}';
  }
}

class FinanceRequest {
  final String id;
  final String reason;
  final double amount;
  final String paymentMode;
  final bool isPaid;
  final DateTime requestDate;
  final DateTime? paidDate;
  final String thavvuId;
  final String requestType; // 'food', 'assets', 'others'
  final String? upiId;
  final String? bankHolderName;
  final String? bankAccountNo;
  final String? bankIfscCode;
  final String? photoPath;
  final String? voicePath;
  final String? invoiceBillPath;
  final String? vehiclePhotoPath;
  final List<CashExpenseItem> items;
  // ── Optional: reference to the saved account used ──
  final String? paymentAccountId;

  FinanceRequest({
    required this.id,
    required this.reason,
    required this.amount,
    required this.paymentMode,
    required this.isPaid,
    required this.requestDate,
    this.paidDate,
    required this.thavvuId,
    required this.requestType,
    this.upiId,
    this.bankHolderName,
    this.bankAccountNo,
    this.bankIfscCode,
    this.photoPath,
    this.voicePath,
    this.invoiceBillPath,
    this.vehiclePhotoPath,
    this.items = const [],
    this.paymentAccountId,
  });

  FinanceRequest copyWith({
    String? reason,
    double? amount,
    String? paymentMode,
    bool? isPaid,
    DateTime? paidDate,
    String? thavvuId,
    String? requestType,
    String? upiId,
    String? bankHolderName,
    String? bankAccountNo,
    String? bankIfscCode,
    String? photoPath,
    String? voicePath,
    String? invoiceBillPath,
    String? vehiclePhotoPath,
    List<CashExpenseItem>? items,
    String? paymentAccountId,
  }) {
    return FinanceRequest(
      id: id,
      reason: reason ?? this.reason,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      isPaid: isPaid ?? this.isPaid,
      requestDate: requestDate,
      paidDate: paidDate ?? this.paidDate,
      thavvuId: thavvuId ?? this.thavvuId,
      requestType: requestType ?? this.requestType,
      upiId: upiId ?? this.upiId,
      bankHolderName: bankHolderName ?? this.bankHolderName,
      bankAccountNo: bankAccountNo ?? this.bankAccountNo,
      bankIfscCode: bankIfscCode ?? this.bankIfscCode,
      photoPath: photoPath ?? this.photoPath,
      voicePath: voicePath ?? this.voicePath,
      invoiceBillPath: invoiceBillPath ?? this.invoiceBillPath,
      vehiclePhotoPath: vehiclePhotoPath ?? this.vehiclePhotoPath,
      items: items ?? this.items,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
    );
  }
}

class ContraRequest {
  final String id;
  final String fromId;
  final String toId;
  final double amount;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime requestDate;
  DateTime? responseDate;

  ContraRequest({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.amount,
    required this.status,
    required this.requestDate,
    this.responseDate,
  });

  ContraRequest copyWith({
    String? fromId,
    String? toId,
    double? amount,
    String? status,
    DateTime? responseDate,
  }) {
    return ContraRequest(
      id: id,
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      requestDate: requestDate,
      responseDate: responseDate ?? this.responseDate,
    );
  }
}

class HistoryItem {
  final DateTime date;
  final String transactionType;
  final String thavvuId;
  final double amount;
  final bool isCredit; // true for credit (incoming), false for debit (outgoing)
  final String details;

  HistoryItem({
    required this.date,
    required this.transactionType,
    required this.thavvuId,
    required this.amount,
    required this.isCredit,
    required this.details,
  });
}

class TransportSplitLine {
  final String thavvuId;
  final String thavvuName;
  final double amount;

  TransportSplitLine({
    required this.thavvuId,
    required this.thavvuName,
    required this.amount,
  });

  TransportSplitLine copyWith({
    String? thavvuId,
    String? thavvuName,
    double? amount,
  }) {
    return TransportSplitLine(
      thavvuId: thavvuId ?? this.thavvuId,
      thavvuName: thavvuName ?? this.thavvuName,
      amount: amount ?? this.amount,
    );
  }
}

class TransportSplitBill {
  final String id;
  final DateTime dateTime;
  final double totalAmount;
  final String splitMode; // 'equal' or 'manual'
  final String remarks;
  final List<TransportSplitLine> lines;
  final String? vehiclePhotoPath;
  final String? invoiceBillPath;

  TransportSplitBill({
    required this.id,
    required this.dateTime,
    required this.totalAmount,
    required this.splitMode,
    required this.remarks,
    required this.lines,
    this.vehiclePhotoPath,
    this.invoiceBillPath,
  });

  TransportSplitBill copyWith({
    double? totalAmount,
    String? splitMode,
    String? remarks,
    List<TransportSplitLine>? lines,
    String? vehiclePhotoPath,
    String? invoiceBillPath,
  }) {
    return TransportSplitBill(
      id: id,
      dateTime: dateTime,
      totalAmount: totalAmount ?? this.totalAmount,
      splitMode: splitMode ?? this.splitMode,
      remarks: remarks ?? this.remarks,
      lines: lines ?? this.lines,
      vehiclePhotoPath: vehiclePhotoPath ?? this.vehiclePhotoPath,
      invoiceBillPath: invoiceBillPath ?? this.invoiceBillPath,
    );
  }
}

class SlantArrow extends StatelessWidget {
  final bool isCredit;
  final Color color;
  final double size;

  const SlantArrow({
    super.key,
    required this.isCredit,
    required this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (isCredit) {
      return Transform.rotate(
        angle: 45 * 3.14159 / 180,
        child: Icon(Icons.arrow_downward, color: color, size: size),
      );
    } else {
      return Transform.rotate(
        angle: 45 * 3.14159 / 180,
        child: Icon(Icons.arrow_upward, color: color, size: size),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class CashModuleScreen extends StatefulWidget {
  final bool isHOD;
  final String? supervisorId;
  final String? supervisorName;

  const CashModuleScreen({
    super.key,
    this.isHOD = false,
    this.supervisorId,
    this.supervisorName,
  });

  @override
  State<CashModuleScreen> createState() => _CashModuleScreenState();
}

class _CashModuleScreenState extends State<CashModuleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CashAllocationService _cashAllocationService = CashAllocationService();
  final SupervisorCashExpenseService _cashExpenseService =
      SupervisorCashExpenseService();

  double _totalCashIssued = 0;
  final List<CashAllocation> _hodCashAllocations = [];
  final List<SupervisorCashExpense> _supervisorCashExpenses = [];

  // Cash Pay - Form fields
  String _selectedCategory = 'food';
  String? _selectedThavvuId;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  final List<String> _vehicleTypes = const [
    'Auto',
    'Tractor',
    'Pickup',
    'Lorry',
    'JCB',
    'Crane',
    'Bike',
    'Other Vehicle',
  ];

  // Cash Pay - reusable item fields for food, assets, and others
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemQuantityController =
      TextEditingController(text: '1');
  final TextEditingController _itemAmountController = TextEditingController();
  final TextEditingController _cashPayTransportAmountController =
      TextEditingController();
  bool _cashPayTransportEnabled = false;
  String? _selectedCashPayVehicleType;
  final List<CashExpenseItem> _cashPayItems = [];
  String? _cashPayInvoiceBillPath;
  String? _cashPayVehiclePhotoPath;

  // ==================== TRANSPORT SPLIT FIELDS ====================
  List<String> _selectedSplitThavvuIds = [];
  String _splitMode = 'equal'; // 'equal' or 'manual'
  Map<String, double> _splitAmounts = {};
  final TextEditingController _transportTotalController =
      TextEditingController();
  final TextEditingController _transportRemarkController =
      TextEditingController();
  final List<TransportSplitBill> _transportSplitBills = [];
  String? _transportVehiclePhotoPath;
  String? _transportInvoiceBillPath;
  // ================================================================

  // Request Pay - Form fields
  String _requestSelectedCategory = 'food';
  String? _requestSelectedThavvuId;
  String? _requestPaymentMethod;
  String? _selectedRequestOption;

  final TextEditingController _requestItemNameController =
      TextEditingController();
  final TextEditingController _requestItemQuantityController =
      TextEditingController(text: '1');
  final TextEditingController _requestItemAmountController =
      TextEditingController();
  final TextEditingController _requestTransportAmountController =
      TextEditingController();
  bool _requestTransportEnabled = false;
  String? _selectedRequestVehicleType;
  final List<CashExpenseItem> _requestPayItems = [];

  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _bankHolderNameController =
      TextEditingController();
  final TextEditingController _bankAccountNoController =
      TextEditingController();
  final TextEditingController _bankIfscCodeController = TextEditingController();
  final TextEditingController _requestAmountController =
      TextEditingController();
  final TextEditingController _requestReasonController =
      TextEditingController();

  String? _requestPhotoPath;
  String? _requestVoicePath;
  String? _requestInvoiceBillPath;
  String? _requestVehiclePhotoPath;

  // ── NEW: Saved payment accounts (same as DailyDataScreen) ──────────────
  final List<Map<String, String>> _savedUPIAccounts = [
    {
      'id': 'upi_1',
      'accountNumber': '****7890',
      'upiId': 'machine@bank',
      'bankName': 'State Bank',
      'ifsc': 'SBIN0001234',
      'type': 'primary',
    },
    {
      'id': 'upi_2',
      'accountNumber': '****5432',
      'upiId': 'operator@upi',
      'bankName': 'HDFC Bank',
      'ifsc': 'HDFC0004321',
      'type': 'secondary',
    },
  ];
  String? _selectedUPIAccount;

  final List<Map<String, String>> _savedBankAccounts = [
    {
      'id': 'bank_1',
      'accountNumber': '****4567',
      'bankName': 'State Bank of India',
      'ifsc': 'SBIN0001234',
      'holderName': 'Ravi Kumar',
      'type': 'primary',
    },
    {
      'id': 'bank_2',
      'accountNumber': '****8901',
      'bankName': 'HDFC Bank',
      'ifsc': 'HDFC0004321',
      'holderName': 'Site Operator',
      'type': 'secondary',
    },
  ];
  String? _selectedBankAccount;

  String _currentSupervisorId = 'THV-SUP-001';
  String _currentSupervisorName = 'Rajesh Kumar';

  // Contra Tab fields
  String? _contraSelectedToId;
  final TextEditingController _contraAmountController = TextEditingController();
  String _contraSubTab = 'request';

  final List<Map<String, String>> _recipientIds = [
    {'id': 'THV-SUP-001', 'name': 'Supervisor - Rajesh (Cash)'},
    {'id': 'THV-SUP-002', 'name': 'Supervisor - Kumar (Cash)'},
    {'id': 'THV-HOD-042', 'name': 'HOD - Senior (Main)'},
    {'id': 'THV-CASH-001', 'name': 'Cash Manager - Arun'},
    {'id': 'THV-CASH-002', 'name': 'Cash Manager - Priya'},
  ];

  List<ContraRequest> _contraRequests = [];

  final List<Map<String, String>> _thavvuIds = [
    {'id': 'THV-SUP-001', 'name': 'Supervisor - Rajesh'},
    {'id': 'THV-SUP-002', 'name': 'Supervisor - Kumar'},
    {'id': 'THV-HOD-042', 'name': 'HOD - Senior'},
    {'id': 'THV-SITE-001', 'name': 'Site Manager - North'},
  ];

  final List<CashTransaction> _allTransactions = [];
  final List<FinanceRequest> _financeRequests = [];

  // ── Supabase backend integration ──────────────────────────────
  final cash_repo.CashRepository _cashRepo = cash_repo.CashRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  RealtimeChannel? _cashChannel;
  String _cashSiteId = 'SITE-VJA-001';
  double? _supabaseSpentByMe;

  // History Tab - Filter (updated with Transport)
  String _selectedCategoryFilter = 'All';
  final List<String> _categoryFilters = [
    'All',
    'Credit',
    'Debit',
    'THV-SUP-001',
    'THV-SUP-002',
    'THV-HOD-042',
    'Food wise',
    'Assets',
    'Transport', // NEW
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    unawaited(_bootstrapSupervisorCash());
    unawaited(_initCashBackend());
  }

  Future<void> _initCashBackend() async {
    final siteId = await _contextService.resolveSiteId();
    if (!mounted) return;
    _cashSiteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
    _cashChannel = _cashRepo.watchAll(_cashSiteId, () {
      // Realtime: refresh both the ledger (spent) and the allocations
      // (issued) so the Cash Summary stays live.
      _loadCashTransactions();
      _loadSupervisorCashData();
    });
    await _loadCashTransactions();
    await _loadSupervisorCashData();
  }

  String? get _currentUid =>
      Supabase.instance.client.auth.currentUser?.id;

  Future<void> _loadCashTransactions() async {
    try {
      final transactions =
          await _cashRepo.fetchTransactions(siteId: _cashSiteId);
      if (!mounted) return;
      final uid = _currentUid;
      // My own spend = transactions I created (Supabase cash_transactions
      // carry created_by = profile uuid). Null uid (offline/test) scopes
      // to the whole site as a safe fallback.
      final mine = uid == null
          ? transactions
          : transactions.where((t) => t.createdBy == uid).toList();
      final spent = mine.fold<double>(0, (sum, t) => sum + t.amount);
      setState(() {
        _supabaseSpentByMe = spent;
        for (final record in transactions) {
          final exists = _allTransactions
              .any((txn) => txn.id == 'CASH-${record.txnNo}');
          if (exists) continue;
          _allTransactions.insert(
            0,
            CashTransaction(
              id: 'CASH-${record.txnNo}',
              reason: record.note ?? record.type,
              dateTime: record.createdAt ?? DateTime.now(),
              amount: record.amount,
              siteId: record.siteId,
              category: record.type,
              paymentMethod: record.method,
            ),
          );
        }
      });
      // Migrate any local-only expenses (submitted before this fix or
      // while offline) into Supabase so HOD/Reports see them too.
      unawaited(_migrateLocalExpensesToSupabase());
    } catch (_) {
      // Backend is best-effort; local ledger still works.
    }
  }

  /// Pushes local cash-pay expenses into Supabase cash_transactions so the
  /// HOD and Reports always see the supervisor's spending. Idempotent:
  /// txn_no is unique, so already-migrated rows are skipped.
  Future<void> _migrateLocalExpensesToSupabase() async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final remoteNos =
          (await _cashRepo.fetchTransactions(siteId: _cashSiteId))
              .map((t) => t.txnNo)
              .toSet();
      for (final expense in _supervisorCashExpenses) {
        final txnNo = 'LOCAL-${expense.id}';
        if (remoteNos.contains(txnNo)) continue;
        try {
          await _cashRepo.createTransaction(
            siteId: _cashSiteId,
            txnNo: txnNo,
            type: 'expense',
            amount: expense.amount,
            method: 'cash',
            category: expense.category,
            note: expense.remarks,
            proofPath: expense.invoiceBillPath.isEmpty
                ? expense.vehiclePhotoPath
                : expense.invoiceBillPath,
          );
        } catch (_) {
          // A duplicate or transient failure is fine — retried next load.
        }
      }
    } catch (_) {}
  }

  Future<void> _bootstrapSupervisorCash() async {
    await _drainPendingFinanceRequests();
    await _resolveCurrentSupervisor();
    await _loadSupervisorCashData();
  }

  /// Replays offline finance requests against Supabase before loading.
  /// Idempotent: request_no is unique, so an already-inserted row simply
  /// fails the unique index and is treated as synced.
  Future<void> _drainPendingFinanceRequests() async {
    final entries = await PendingWritesStore.instance.all();
    for (final entry in entries) {
      if (entry['kind']?.toString() != 'finance_request') continue;
      final id = entry['id']?.toString() ?? '';
      final payload =
          Map<String, dynamic>.from(entry['payload'] as Map? ?? const {});
      try {
        final items = payload['items'];
        await _cashRepo.createFinanceRequest(
          siteId: payload['siteId']?.toString() ?? _cashSiteId,
          requestNo: payload['requestNo']?.toString() ?? '',
          thavvuPointId: payload['thavvuPointId']?.toString(),
          type: payload['type']?.toString() ?? 'expense',
          amount: (payload['amount'] as num?)?.toDouble() ?? 0,
          category: payload['category']?.toString(),
          reason: payload['reason']?.toString(),
          paymentMethod: payload['paymentMethod']?.toString() ?? 'upi',
          items: items is List
              ? items
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList()
              : const [],
          proofPath: payload['proofPath']?.toString(),
          voicePath: payload['voicePath']?.toString(),
        );
        await PendingWritesStore.instance.remove(id);
      } catch (e) {
        // Unique-constraint hit means it already synced — drop the queue.
        final msg = e.toString();
        if (msg.contains('23505') || msg.contains('duplicate')) {
          await PendingWritesStore.instance.remove(id);
        } else {
          debugPrint('drain finance request failed ($id): $e');
        }
      }
    }
  }

  Future<void> _resolveCurrentSupervisor() async {
    if (widget.supervisorId != null && widget.supervisorId!.trim().isNotEmpty) {
      _currentSupervisorId = widget.supervisorId!.trim();
      _currentSupervisorName = widget.supervisorName?.trim().isNotEmpty == true
          ? widget.supervisorName!.trim()
          : _thavvuNameFor(_currentSupervisorId);
      return;
    }

    final user = await AuthService.getUserData();
    final empId = user['empId']?.trim() ?? '';
    final name = user['name']?.trim() ?? '';

    if (empId.startsWith('THV-SUP-')) {
      _currentSupervisorId = empId;
    } else if (empId == 'EMP-001' || name.toLowerCase().contains('rajesh')) {
      _currentSupervisorId = 'THV-SUP-001';
    } else if (name.toLowerCase().contains('kumar')) {
      _currentSupervisorId = 'THV-SUP-002';
    }

    _currentSupervisorName =
        name.isNotEmpty ? name : _thavvuNameFor(_currentSupervisorId);
  }

  Future<void> _loadHodCashAllocations() => _loadSupervisorCashData();

  Future<void> _loadSupervisorCashData() async {
    // PRIMARY: Supabase cash_allocations (what the HOD actually issues).
    // The old local SharedPreferences store is only a fallback when the
    // Supabase backend is unavailable (offline / not initialized).
    try {
      final uid = _currentUid;
      final allocations =
          await _cashRepo.fetchAllocations(siteId: _cashSiteId);
      // Allocation targets the supervisor's profile; if none target this
      // user, treat the site allocations as issued to the site.
      final mine = uid == null
          ? allocations
          : allocations.where((a) => a.allocatedTo == uid).toList();
      final effective = mine.isEmpty ? allocations : mine;
      if (!mounted) return;
      setState(() {
        _hodCashAllocations
          ..clear()
          ..addAll(effective.map(_toLegacyAllocation));
        _totalCashIssued = effective.fold<double>(
          0,
          (sum, allocation) => sum + allocation.amount,
        );
      });
      return;
    } catch (_) {
      // Supabase unavailable — fall back to the legacy local store.
    }

    try {
      final results = await Future.wait([
        _cashAllocationService.allocationsForSupervisor(_currentSupervisorId),
        _cashExpenseService.expensesForSupervisor(_currentSupervisorId),
      ]);
      final allocations = results[0] as List<CashAllocation>;
      final expenses = results[1] as List<SupervisorCashExpense>;
      if (!mounted) return;
      setState(() {
        _hodCashAllocations
          ..clear()
          ..addAll(allocations);
        _supervisorCashExpenses
          ..clear()
          ..addAll(expenses);
        _totalCashIssued = allocations.fold<double>(
          0,
          (sum, allocation) => sum + allocation.amount,
        );
      });
    } catch (_) {}
  }

  /// Converts a Supabase cash_allocation row into the legacy display model
  /// used by the history tab and summary.
  CashAllocation _toLegacyAllocation(cash_repo.CashAllocation allocation) {
    return CashAllocation(
      id: allocation.id,
      supervisorId: allocation.allocatedTo ?? _currentSupervisorId,
      supervisorName: _currentSupervisorName,
      siteId: allocation.siteId,
      siteName: _thavvuNameFor(allocation.allocatedTo ?? _currentSupervisorId),
      amount: allocation.amount,
      purpose: allocation.note ?? 'HOD Cash Allocation',
      category: 'cash',
      paymentMode: 'cash',
      reference: '',
      notes: allocation.note ?? '',
      issuedByHodId: allocation.allocatedBy,
      issuedAt: allocation.createdAt ?? DateTime.now(),
    );
  }




  @override
  void dispose() {
    _cashRepo.stopWatching(_cashChannel);
    _tabController.dispose();
    _amountController.dispose();
    _remarkController.dispose();
    _itemNameController.dispose();
    _itemQuantityController.dispose();
    _itemAmountController.dispose();
    _cashPayTransportAmountController.dispose();
    _transportTotalController.dispose();
    _transportRemarkController.dispose();
    _requestItemNameController.dispose();
    _requestItemQuantityController.dispose();
    _requestItemAmountController.dispose();
    _requestTransportAmountController.dispose();
    _upiIdController.dispose();
    _bankHolderNameController.dispose();
    _bankAccountNoController.dispose();
    _bankIfscCodeController.dispose();
    _requestAmountController.dispose();
    _requestReasonController.dispose();
    _contraAmountController.dispose();
    super.dispose();
  }


  double get _totalSpentAllSites {
    // Once Supabase is loaded, spend = this supervisor's own transactions
    // (created_by = me). Fallback to the legacy local fold while offline.
    final supabaseSpent = _supabaseSpentByMe;
    if (supabaseSpent != null) return supabaseSpent;
    return _cashAccountTransactions.fold(0, (sum, txn) => sum + txn.amount);
  }

  double get _remainingBalance => _totalCashIssued - _totalSpentAllSites;

  List<CashTransaction> get _transportTransactions {
    return _allTransactions.where((txn) => txn.category == 'transport').toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  double get _transportTotalAmount {
    return _transportTransactions.fold(0, (sum, txn) => sum + txn.amount);
  }

  int get _transportSplitLineCount {
    return _transportSplitBills.fold(0, (sum, bill) => sum + bill.lines.length);
  }

  String _thavvuNameFor(String thavvuId) {
    final match = _thavvuIds.where((item) => item['id'] == thavvuId);
    if (match.isEmpty) return 'Unknown Thavvu';
    return match.first['name'] ?? 'Unknown Thavvu';
  }

  Map<String, List<CashTransaction>> get _transportTransactionsByThavvu {
    final grouped = <String, List<CashTransaction>>{};
    for (final txn in _transportTransactions) {
      final key = txn.thavvuId ?? 'Unassigned';
      grouped.putIfAbsent(key, () => []).add(txn);
    }
    return grouped;
  }

  Map<String, double> get _transportAmountByThavvu {
    final totals = <String, double>{};
    for (final txn in _transportTransactions) {
      final key = txn.thavvuId ?? 'Unassigned';
      totals[key] = (totals[key] ?? 0) + txn.amount;
    }
    return totals;
  }

  List<CashTransaction> get _persistedCashPayTransactions {
    return _supervisorCashExpenses
        .where((expense) => expense.affectsSupervisorBalance)
        .map(
          (expense) => CashTransaction(
            id: expense.id,
            reason: expense.remarks,
            dateTime: expense.submittedAt,
            amount: expense.amount,
            siteId: expense.siteId,
            category: expense.category,
            paymentMethod: 'cash',
            thavvuId: expense.thavvuId,
            invoiceBillPath: expense.invoiceBillPath,
            vehiclePhotoPath: expense.vehiclePhotoPath,
            items: expense.items
                .map(
                  (item) => CashExpenseItem(
                    name: item.name,
                    quantity: item.quantity,
                    amount: item.amount,
                    category: item.category,
                    transportEnabled: item.transportEnabled,
                    vehicleType:
                        item.vehicleType.isEmpty ? null : item.vehicleType,
                    transportAmount: item.transportAmount,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  List<CashTransaction> get _cashAccountTransactions {
    final localTransactions = _allTransactions.where((transaction) {
      final thavvuId = transaction.thavvuId;
      return thavvuId == null || thavvuId == _currentSupervisorId;
    });
    return [...localTransactions, ..._persistedCashPayTransactions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  void _recalculateEqualTransportSplit() {
    final total = double.tryParse(_transportTotalController.text.trim()) ?? 0;
    if (_selectedSplitThavvuIds.isEmpty) {
      _splitAmounts = {};
      return;
    }

    _splitAmounts = {
      for (final id in _selectedSplitThavvuIds)
        id: total / _selectedSplitThavvuIds.length,
    };
  }

  // Get all history items (now includes transport)
  List<HistoryItem> get _allHistoryItems {
    final List<HistoryItem> items = [];

    for (final allocation in _hodCashAllocations) {
      items.add(HistoryItem(
        date: allocation.issuedAt,
        transactionType: '🏦 HOD Cash Issued',
        thavvuId: allocation.supervisorId,
        amount: allocation.amount,
        isCredit: true,
        details: allocation.purpose,
      ));
    }

    for (var txn in _cashAccountTransactions) {
      String transactionType;
      switch (txn.category) {
        case 'food':
          transactionType = '🍽️ Food Purchase';
          break;
        case 'assets':
          transactionType = '🧰 Assets Purchase';
          break;
        case 'transport':
          transactionType = '🚚 Transport Fee'; // NEW
          break;
        default:
          transactionType = '✨ Other Expense';
      }

      final displayThavvuId = txn.thavvuId ?? 'THV-SUP-001';

      items.add(HistoryItem(
        date: txn.dateTime,
        transactionType: transactionType,
        thavvuId: displayThavvuId,
        amount: txn.amount,
        isCredit: false,
        details: txn.reason,
      ));
    }

    for (var req in _financeRequests) {
      if (req.isPaid) {
        String type;
        switch (req.requestType) {
          case 'food':
            type = '🍽️ Food Request';
            break;
          case 'assets':
            type = '🧰 Assets Request';
            break;
          default:
            type = '✨ Other Request';
        }

        items.add(HistoryItem(
          date: req.paidDate ?? req.requestDate,
          transactionType: type,
          thavvuId: req.thavvuId,
          amount: req.amount,
          isCredit: false,
          details: req.reason,
        ));
      }
    }

    for (var contra in _contraRequests) {
      if (contra.status == 'accepted') {
        if (contra.toId == _currentSupervisorId) {
          items.add(HistoryItem(
            date: contra.responseDate ?? contra.requestDate,
            transactionType: '🔁 Contra Received',
            thavvuId: contra.fromId,
            amount: contra.amount,
            isCredit: true,
            details: 'Contra transfer from ${contra.fromId}',
          ));
        }
        if (contra.fromId == _currentSupervisorId) {
          items.add(HistoryItem(
            date: contra.responseDate ?? contra.requestDate,
            transactionType: '🔁 Contra Sent',
            thavvuId: contra.toId,
            amount: contra.amount,
            isCredit: false,
            details: 'Contra transfer to ${contra.toId}',
          ));
        }
      }
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  // Filtered history items (now includes Transport filter)
  List<HistoryItem> get _filteredHistoryItems {
    if (_selectedCategoryFilter == 'All') {
      return _allHistoryItems;
    }

    return _allHistoryItems.where((item) {
      switch (_selectedCategoryFilter) {
        case 'Credit':
          return item.isCredit;
        case 'Debit':
          return !item.isCredit;
        case 'Food wise':
          return item.transactionType.toLowerCase().contains('food');
        case 'Assets':
          return item.transactionType.toLowerCase().contains('assets');
        case 'Transport':
          return item.transactionType
              .toLowerCase()
              .contains('transport'); // NEW
        case 'Others':
          return !item.transactionType.toLowerCase().contains('food') &&
              !item.transactionType.toLowerCase().contains('assets') &&
              !item.transactionType.toLowerCase().contains('transport');
        default:
          return item.thavvuId == _selectedCategoryFilter;
      }
    }).toList();
  }

  // Calculate running balance
  List<Map<String, dynamic>> _getHistoryWithRunningBalance() {
    final items = _filteredHistoryItems;
    final List<Map<String, dynamic>> result = [];
    double runningBalance = 0;

    final ascendingItems = List.from(items)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (var item in ascendingItems) {
      if (item.isCredit) {
        runningBalance += item.amount;
      } else {
        runningBalance -= item.amount;
      }

      result.add({
        'item': item,
        'balance': runningBalance,
      });
    }

    return result.reversed.toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDIT / DELETE HELPERS — APPLIES ACROSS CASH MODULE TABS
  // ═══════════════════════════════════════════════════════════════════════════

  void _syncCashPayDraftTotal() {
    _amountController.text = _cashPayItemsTotal.toStringAsFixed(0);
  }

  void _syncRequestPayDraftTotal() {
    _requestAmountController.text = _requestPayItemsTotal.toStringAsFixed(0);
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<CashExpenseItem?> _showExpenseItemEditor({
    required CashExpenseItem item,
    required String title,
  }) async {
    final nameController = TextEditingController(text: item.name);
    final quantityController =
        TextEditingController(text: item.quantity.toString());
    final amountController =
        TextEditingController(text: item.amount.toStringAsFixed(0));
    bool transportEnabled = item.transportEnabled;
    String? vehicleType = item.vehicleType;
    final transportAmountController = TextEditingController(
      text: item.transportAmount > 0
          ? item.transportAmount.toStringAsFixed(0)
          : '',
    );

    final result = await showModalBottomSheet<CashExpenseItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void showValidation(String message) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: AppTheme.danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.info.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.edit_note_rounded,
                                color: AppTheme.info),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                prefixIcon: const Icon(Icons.numbers),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Amount / Item',
                                prefixIcon: const Icon(Icons.currency_rupee),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: transportEnabled
                              ? AppTheme.warning.withValues(alpha: 0.08)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: transportEnabled
                                ? AppTheme.warning.withValues(alpha: 0.26)
                                : AppTheme.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Item Transport',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: const Text(
                                'Use this only when this exact item has its own vehicle amount.',
                                style: TextStyle(fontSize: 11),
                              ),
                              activeColor: AppTheme.warning,
                              value: transportEnabled,
                              onChanged: (value) {
                                setSheetState(() {
                                  transportEnabled = value;
                                  if (!value) {
                                    vehicleType = null;
                                    transportAmountController.clear();
                                  }
                                });
                              },
                            ),
                            if (transportEnabled) ...[
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: vehicleType != null &&
                                        _vehicleTypes.contains(vehicleType)
                                    ? vehicleType
                                    : null,
                                isExpanded: true,
                                hint: const Text('Select Vehicle Type'),
                                decoration: InputDecoration(
                                  prefixIcon:
                                      const Icon(Icons.local_shipping_outlined),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                items: _vehicleTypes
                                    .map(
                                      (vehicle) => DropdownMenuItem<String>(
                                        value: vehicle,
                                        child: Text(vehicle),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setSheetState(() => vehicleType = value),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: transportAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Transport Amount',
                                  prefixIcon:
                                      const Icon(Icons.currency_rupee_outlined),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                              ),
                              onPressed: () {
                                final name = nameController.text.trim();
                                final quantity = int.tryParse(
                                        quantityController.text.trim()) ??
                                    0;
                                final amount = double.tryParse(
                                        amountController.text.trim()) ??
                                    0;
                                final transportAmount = double.tryParse(
                                        transportAmountController.text
                                            .trim()) ??
                                    0;

                                if (name.isEmpty) {
                                  showValidation('Please enter item name.');
                                  return;
                                }
                                if (quantity <= 0) {
                                  showValidation(
                                      'Please enter valid quantity.');
                                  return;
                                }
                                if (amount <= 0) {
                                  showValidation(
                                      'Please enter valid item amount.');
                                  return;
                                }
                                if (transportEnabled &&
                                    (vehicleType == null ||
                                        transportAmount <= 0)) {
                                  showValidation(
                                      'Select vehicle and transport amount.');
                                  return;
                                }

                                Navigator.pop(
                                  sheetContext,
                                  item.copyWith(
                                    name: name,
                                    quantity: quantity,
                                    amount: amount,
                                    transportEnabled: transportEnabled,
                                    vehicleType:
                                        transportEnabled ? vehicleType : null,
                                    transportAmount:
                                        transportEnabled ? transportAmount : 0,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
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

    nameController.dispose();
    quantityController.dispose();
    amountController.dispose();
    transportAmountController.dispose();
    return result;
  }

  Future<void> _editCashPayItem(int index) async {
    if (index < 0 || index >= _cashPayItems.length) return;
    final updated = await _showExpenseItemEditor(
      item: _cashPayItems[index],
      title: 'Edit Cash Pay Item',
    );
    if (updated == null || !mounted) return;
    setState(() {
      _cashPayItems[index] = updated;
      _syncCashPayDraftTotal();
    });
    _showSnackbar('Cash Pay item updated.', AppTheme.success);
  }

  Future<void> _deleteCashPayItem(int index) async {
    if (index < 0 || index >= _cashPayItems.length) return;
    final confirmed = await _confirmDelete(
      title: 'Delete item?',
      message: 'This item will be removed from the Cash Pay draft.',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _cashPayItems.removeAt(index);
      _syncCashPayDraftTotal();
    });
    _showSnackbar('Cash Pay item deleted.', AppTheme.danger);
  }

  Future<void> _editRequestPayItem(int index) async {
    if (index < 0 || index >= _requestPayItems.length) return;
    final updated = await _showExpenseItemEditor(
      item: _requestPayItems[index],
      title: 'Edit Request Pay Item',
    );
    if (updated == null || !mounted) return;
    setState(() {
      _requestPayItems[index] = updated;
      _syncRequestPayDraftTotal();
    });
    _showSnackbar('Request Pay item updated.', AppTheme.success);
  }

  Future<void> _deleteRequestPayItem(int index) async {
    if (index < 0 || index >= _requestPayItems.length) return;
    final confirmed = await _confirmDelete(
      title: 'Delete request item?',
      message: 'This item will be removed from the Request Pay draft.',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _requestPayItems.removeAt(index);
      _syncRequestPayDraftTotal();
    });
    _showSnackbar('Request Pay item deleted.', AppTheme.danger);
  }

  void _replaceTransportTransactionsForBill(TransportSplitBill bill) {
    _allTransactions.removeWhere((txn) =>
        txn.reason.contains('Transport split bill ${bill.id}') ||
        txn.id.startsWith('txn_${bill.id}_'));

    for (final line in bill.lines) {
      _allTransactions.insert(
        0,
        CashTransaction(
          id: 'txn_${bill.id}_${line.thavvuId}',
          reason:
              'Transport split bill ${bill.id}${bill.remarks.isNotEmpty ? ': ${bill.remarks}' : ''}',
          dateTime: bill.dateTime,
          amount: line.amount,
          siteId: 'site_1',
          category: 'transport',
          thavvuId: line.thavvuId,
          invoiceBillPath: bill.invoiceBillPath,
          vehiclePhotoPath: bill.vehiclePhotoPath,
        ),
      );
    }
  }

  Future<void> _editTransportBill(TransportSplitBill bill) async {
    final totalController =
        TextEditingController(text: bill.totalAmount.toStringAsFixed(0));
    final remarksController = TextEditingController(text: bill.remarks);
    String splitMode = bill.splitMode;
    final selectedIds = bill.lines.map((line) => line.thavvuId).toSet();
    final splitControllers = <String, TextEditingController>{
      for (final line in bill.lines)
        line.thavvuId:
            TextEditingController(text: line.amount.toStringAsFixed(0)),
    };

    final updated = await showModalBottomSheet<TransportSplitBill>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void recalculateEqual() {
              final currentTotal =
                  double.tryParse(totalController.text.trim()) ??
                      bill.totalAmount;
              if (selectedIds.isEmpty) return;
              final each = currentTotal / selectedIds.length;
              for (final id in selectedIds) {
                splitControllers
                    .putIfAbsent(id, () => TextEditingController(text: '0'))
                    .text = each.toStringAsFixed(0);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Transport Split Bill',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: totalController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Total Transport Amount',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) {
                          if (splitMode == 'equal') {
                            setSheetState(recalculateEqual);
                          } else {
                            setSheetState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Equal'),
                              value: 'equal',
                              groupValue: splitMode,
                              dense: true,
                              onChanged: (value) {
                                if (value == null) return;
                                setSheetState(() {
                                  splitMode = value;
                                  recalculateEqual();
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Manual'),
                              value: 'manual',
                              groupValue: splitMode,
                              dense: true,
                              onChanged: (value) {
                                if (value == null) return;
                                setSheetState(() => splitMode = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Split Lines',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      ..._thavvuIds.map((thavvu) {
                        final id = thavvu['id']!;
                        final isSelected = selectedIds.contains(id);
                        splitControllers.putIfAbsent(
                            id, () => TextEditingController(text: '0'));
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.06)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.24)
                                  : AppTheme.border,
                            ),
                          ),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: isSelected,
                                activeColor: AppTheme.primary,
                                title: Text(
                                  '$id • ${_thavvuNameFor(id)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800),
                                ),
                                onChanged: (checked) {
                                  setSheetState(() {
                                    if (checked == true) {
                                      selectedIds.add(id);
                                    } else {
                                      selectedIds.remove(id);
                                    }
                                    if (splitMode == 'equal') {
                                      recalculateEqual();
                                    }
                                  });
                                },
                              ),
                              if (isSelected)
                                TextField(
                                  controller: splitControllers[id],
                                  readOnly: splitMode == 'equal',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Share Amount',
                                    prefixIcon:
                                        const Icon(Icons.currency_rupee),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  onChanged: (_) => setSheetState(() {}),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      TextField(
                        controller: remarksController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Transport Remarks',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                              onPressed: () {
                                final parsedTotal = double.tryParse(
                                        totalController.text.trim()) ??
                                    0;
                                if (parsedTotal <= 0) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Enter valid transport amount.'),
                                      backgroundColor: AppTheme.danger,
                                    ),
                                  );
                                  return;
                                }
                                if (selectedIds.isEmpty) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Select at least one Thavvu.'),
                                      backgroundColor: AppTheme.danger,
                                    ),
                                  );
                                  return;
                                }

                                final lines = selectedIds.map((id) {
                                  final amount = double.tryParse(
                                          splitControllers[id]?.text.trim() ??
                                              '') ??
                                      0;
                                  return TransportSplitLine(
                                    thavvuId: id,
                                    thavvuName: _thavvuNameFor(id),
                                    amount: amount,
                                  );
                                }).toList();

                                final splitTotal = lines.fold<double>(
                                    0, (sum, line) => sum + line.amount);
                                if ((splitTotal - parsedTotal).abs() > 0.01) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Split total ₹${splitTotal.toStringAsFixed(0)} must match ₹${parsedTotal.toStringAsFixed(0)}.'),
                                      backgroundColor: AppTheme.danger,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(
                                  sheetContext,
                                  bill.copyWith(
                                    totalAmount: parsedTotal,
                                    splitMode: splitMode,
                                    remarks: remarksController.text.trim(),
                                    lines: lines,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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

    totalController.dispose();
    remarksController.dispose();
    for (final controller in splitControllers.values) {
      controller.dispose();
    }

    if (updated == null || !mounted) return;
    setState(() {
      final index =
          _transportSplitBills.indexWhere((item) => item.id == bill.id);
      if (index != -1) {
        _transportSplitBills[index] = updated;
      }
      _replaceTransportTransactionsForBill(updated);
    });
    _showSnackbar('Transport split bill updated.', AppTheme.success);
  }

  Future<void> _deleteTransportBill(TransportSplitBill bill) async {
    final confirmed = await _confirmDelete(
      title: 'Delete transport split bill?',
      message:
          'This will remove the split bill and its Thavvu-wise transport entries from history.',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _transportSplitBills.removeWhere((item) => item.id == bill.id);
      _allTransactions.removeWhere((txn) =>
          txn.reason.contains('Transport split bill ${bill.id}') ||
          txn.id.startsWith('txn_${bill.id}_'));
    });
    _showSnackbar('Transport split bill deleted.', AppTheme.danger);
  }

  Future<void> _editContraRequest(ContraRequest request) async {
    final amountController =
        TextEditingController(text: request.amount.toStringAsFixed(0));
    String? selectedToId = request.toId;

    final updated = await showModalBottomSheet<ContraRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final availableRecipients = _recipientIds
            .where((r) => r['id'] != _currentSupervisorId)
            .toList();

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Edit Contra Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedToId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'To',
                        prefixIcon: const Icon(Icons.arrow_forward),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: availableRecipients
                          .map(
                            (recipient) => DropdownMenuItem<String>(
                              value: recipient['id'],
                              child: Text(
                                  '${recipient['id']} • ${recipient['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setSheetState(() => selectedToId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cash Amount',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary),
                            onPressed: () {
                              final amount = double.tryParse(
                                      amountController.text.trim()) ??
                                  0;
                              if (selectedToId == null || amount <= 0) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Select recipient and valid amount.'),
                                    backgroundColor: AppTheme.danger,
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(
                                sheetContext,
                                request.copyWith(
                                  toId: selectedToId,
                                  amount: amount,
                                ),
                              );
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    if (updated == null || !mounted) return;
    setState(() {
      final index = _contraRequests.indexWhere((item) => item.id == request.id);
      if (index != -1) {
        _contraRequests[index] = updated;
      }
    });
    _showSnackbar('Contra request updated.', AppTheme.success);
  }

  Future<void> _deleteContraRequest(ContraRequest request) async {
    final confirmed = await _confirmDelete(
      title: 'Delete contra request?',
      message: 'This pending contra request will be removed.',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _contraRequests.removeWhere((item) => item.id == request.id);
    });
    _showSnackbar('Contra request deleted.', AppTheme.danger);
  }

  Future<void> _editFinanceRequest(FinanceRequest request) async {
    if (request.isPaid) {
      _showSnackbar('Paid requests cannot be edited.', AppTheme.warning);
      return;
    }

    final reasonController = TextEditingController(text: request.reason);
    final amountController =
        TextEditingController(text: request.amount.toStringAsFixed(0));
    String thavvuId = request.thavvuId;
    String paymentMode = request.paymentMode;
    String requestType = request.requestType;

    final updated = await showModalBottomSheet<FinanceRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Finance Request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: thavvuId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Thavvu ID',
                          prefixIcon: const Icon(Icons.verified_user),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _thavvuIds
                            .map((item) => DropdownMenuItem<String>(
                                  value: item['id'],
                                  child:
                                      Text('${item['id']} • ${item['name']}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => thavvuId = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: requestType,
                        decoration: InputDecoration(
                          labelText: 'Request Type',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'food', child: Text('Food')),
                          DropdownMenuItem(
                              value: 'assets', child: Text('Assets')),
                          DropdownMenuItem(
                              value: 'others', child: Text('Others')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => requestType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: paymentMode,
                        decoration: InputDecoration(
                          labelText: 'Payment Mode',
                          prefixIcon:
                              const Icon(Icons.account_balance_wallet_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                          DropdownMenuItem(
                              value: 'Bank Transfer',
                              child: Text('Bank Transfer')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => paymentMode = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        readOnly: request.items.isNotEmpty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: request.items.isNotEmpty
                              ? 'Amount is controlled by request items'
                              : 'Amount',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Reason / Remarks',
                          prefixIcon: const Icon(Icons.description_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                              onPressed: () {
                                final amount = double.tryParse(
                                        amountController.text.trim()) ??
                                    0;
                                if (reasonController.text.trim().isEmpty ||
                                    (request.items.isEmpty && amount <= 0)) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Enter valid amount and reason.'),
                                      backgroundColor: AppTheme.danger,
                                    ),
                                  );
                                  return;
                                }

                                final derivedAmount = request.items.isEmpty
                                    ? amount
                                    : request.items.fold<double>(
                                        0, (sum, item) => sum + item.total);

                                Navigator.pop(
                                  sheetContext,
                                  request.copyWith(
                                    reason: reasonController.text.trim(),
                                    amount: derivedAmount,
                                    thavvuId: thavvuId,
                                    requestType: requestType,
                                    paymentMode: paymentMode,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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

    reasonController.dispose();
    amountController.dispose();

    if (updated == null || !mounted) return;
    setState(() {
      final index =
          _financeRequests.indexWhere((item) => item.id == request.id);
      if (index != -1) {
        _financeRequests[index] = updated;
      }
    });
    _showSnackbar('Finance request updated.', AppTheme.success);
  }

  Future<void> _deleteFinanceRequest(FinanceRequest request) async {
    if (request.isPaid) {
      _showSnackbar('Paid requests cannot be deleted.', AppTheme.warning);
      return;
    }
    final confirmed = await _confirmDelete(
      title: 'Delete finance request?',
      message: 'This pending finance request will be removed.',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _financeRequests.removeWhere((item) => item.id == request.id);
    });
    _showSnackbar('Finance request deleted.', AppTheme.danger);
  }

  Future<void> _editFinanceRequestItem(
    FinanceRequest request,
    int itemIndex,
  ) async {
    if (request.isPaid) {
      _showSnackbar('Paid request items cannot be edited.', AppTheme.warning);
      return;
    }
    if (itemIndex < 0 || itemIndex >= request.items.length) return;

    final updatedItem = await _showExpenseItemEditor(
      item: request.items[itemIndex],
      title: 'Edit Request Item',
    );
    if (updatedItem == null || !mounted) return;

    final items = List<CashExpenseItem>.from(request.items);
    items[itemIndex] = updatedItem;
    final amount = items.fold<double>(0, (sum, item) => sum + item.total);

    setState(() {
      final index =
          _financeRequests.indexWhere((item) => item.id == request.id);
      if (index != -1) {
        _financeRequests[index] =
            request.copyWith(items: items, amount: amount);
      }
    });
    _showSnackbar('Finance request item updated.', AppTheme.success);
  }

  Future<void> _deleteFinanceRequestItem(
    FinanceRequest request,
    int itemIndex,
  ) async {
    if (request.isPaid) {
      _showSnackbar('Paid request items cannot be deleted.', AppTheme.warning);
      return;
    }
    if (itemIndex < 0 || itemIndex >= request.items.length) return;

    final confirmed = await _confirmDelete(
      title: 'Delete request item?',
      message: request.items.length == 1
          ? 'This is the last item. The whole finance request will be deleted.'
          : 'This item will be removed from the finance request.',
    );
    if (!confirmed || !mounted) return;

    if (request.items.length == 1) {
      setState(() {
        _financeRequests.removeWhere((item) => item.id == request.id);
      });
      _showSnackbar('Finance request deleted.', AppTheme.danger);
      return;
    }

    final items = List<CashExpenseItem>.from(request.items)
      ..removeAt(itemIndex);
    final amount = items.fold<double>(0, (sum, item) => sum + item.total);

    setState(() {
      final index =
          _financeRequests.indexWhere((item) => item.id == request.id);
      if (index != -1) {
        _financeRequests[index] =
            request.copyWith(items: items, amount: amount);
      }
    });
    _showSnackbar('Finance request item deleted.', AppTheme.danger);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBMIT HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _submitTransportSplit() {
    final total = double.tryParse(_transportTotalController.text.trim());
    if (total == null || total <= 0) {
      _showSnackbar('Please enter a valid transport amount', AppTheme.danger);
      return;
    }

    if (_selectedSplitThavvuIds.isEmpty) {
      _showSnackbar('Please select at least one Thavvu ID', AppTheme.danger);
      return;
    }

    if (_splitMode == 'equal') {
      _recalculateEqualTransportSplit();
    }

    if (_splitMode == 'manual') {
      final missingAmount = _selectedSplitThavvuIds.any(
        (id) => (_splitAmounts[id] ?? 0) <= 0,
      );
      if (missingAmount) {
        _showSnackbar(
          'Enter manual split amount for every selected Thavvu ID',
          AppTheme.danger,
        );
        return;
      }

      final manualTotal = _selectedSplitThavvuIds.fold<double>(
        0,
        (sum, id) => sum + (_splitAmounts[id] ?? 0),
      );

      if ((manualTotal - total).abs() > 0.01) {
        _showSnackbar(
          'Manual split total must match ₹${total.toStringAsFixed(0)}',
          AppTheme.danger,
        );
        return;
      }
    }

    final selectedIds = List<String>.from(_selectedSplitThavvuIds);
    final remark = _transportRemarkController.text.trim();
    final now = DateTime.now();
    final billId = 'TSB-${now.millisecondsSinceEpoch}';

    final lines = selectedIds
        .map(
          (id) => TransportSplitLine(
            thavvuId: id,
            thavvuName: _thavvuNameFor(id),
            amount: _splitAmounts[id] ?? (total / selectedIds.length),
          ),
        )
        .toList();

    final bill = TransportSplitBill(
      id: billId,
      dateTime: now,
      totalAmount: total,
      splitMode: _splitMode,
      remarks: remark,
      lines: lines,
      vehiclePhotoPath: _transportVehiclePhotoPath,
      invoiceBillPath: _transportInvoiceBillPath,
    );

    setState(() {
      _transportSplitBills.insert(0, bill);

      for (final line in lines) {
        _allTransactions.insert(
          0,
          CashTransaction(
            id: 'txn_${billId}_${line.thavvuId}',
            reason:
                'Transport split bill $billId${remark.isNotEmpty ? ': $remark' : ''}',
            dateTime: now,
            amount: line.amount,
            siteId: 'site_1',
            category: 'transport',
            thavvuId: line.thavvuId,
            invoiceBillPath: _transportInvoiceBillPath,
            vehiclePhotoPath: _transportVehiclePhotoPath,
          ),
        );
      }
    });

    _showSnackbar(
      'Transport bill split into ${lines.length} Thavvu account(s).',
      AppTheme.success,
    );
    _clearTransportForm();
  }

  void _clearTransportForm() {
    _selectedSplitThavvuIds.clear();
    _splitAmounts.clear();
    _transportTotalController.clear();
    _transportRemarkController.clear();
    _transportVehiclePhotoPath = null;
    _transportInvoiceBillPath = null;
    _splitMode = 'equal';
  }

  double get _cashPayTransportTotal {
    if (!_cashPayTransportEnabled) return 0;
    return double.tryParse(_cashPayTransportAmountController.text.trim()) ?? 0;
  }

  double get _requestTransportTotal {
    if (!_requestTransportEnabled) return 0;
    return double.tryParse(_requestTransportAmountController.text.trim()) ?? 0;
  }

  double get _cashPayItemsTotal {
    final itemsTotal =
        _cashPayItems.fold<double>(0, (sum, item) => sum + item.baseTotal);
    return itemsTotal + _cashPayTransportTotal;
  }

  double get _requestPayItemsTotal {
    final itemsTotal =
        _requestPayItems.fold<double>(0, (sum, item) => sum + item.baseTotal);
    return itemsTotal + _requestTransportTotal;
  }

  String _cashPayTransportSummary() {
    if (!_cashPayTransportEnabled) return '';
    final vehicle = _selectedCashPayVehicleType ?? 'Vehicle';
    return 'Transport: $vehicle • ₹${_cashPayTransportTotal.toStringAsFixed(0)}';
  }

  String _requestTransportSummary() {
    if (!_requestTransportEnabled) return '';
    final vehicle = _selectedRequestVehicleType ?? 'Vehicle';
    return 'Transport: $vehicle • ₹${_requestTransportTotal.toStringAsFixed(0)}';
  }

  String _titleForCategory(String category) {
    switch (category) {
      case 'food':
        return 'Food';
      case 'assets':
        return 'Assets';
      default:
        return 'Others';
    }
  }

  Future<void> _submitCashPay() async {
    if (_selectedThavvuId == null) {
      _showSnackbar('Please select Thavvu ID', AppTheme.danger);
      return;
    }

    if (_cashPayItems.isEmpty &&
        (_itemNameController.text.trim().isNotEmpty ||
            _itemAmountController.text.trim().isNotEmpty)) {
      _addCashPayItem();
    }

    if (_cashPayItems.isEmpty) {
      _showSnackbar(
        'Please add at least one ${_titleForCategory(_selectedCategory).toLowerCase()} item',
        AppTheme.danger,
      );
      return;
    }

    if (_cashPayTransportEnabled) {
      if (_selectedCashPayVehicleType == null) {
        _showSnackbar(
            'Please select vehicle type for transport', AppTheme.danger);
        return;
      }
      if (_cashPayTransportTotal <= 0) {
        _showSnackbar('Please enter valid transport amount', AppTheme.danger);
        return;
      }
    }

    final remark = _remarkController.text.trim();
    if (remark.isEmpty) {
      _showSnackbar(
          'Please enter final remarks for all added items', AppTheme.danger);
      return;
    }

    final items = List<CashExpenseItem>.from(_cashPayItems);
    final itemSummary =
        items.map((item) => '${item.name} x${item.quantity}').join(', ');
    final transportSummary = _cashPayTransportSummary();
    final fullSummary = transportSummary.isEmpty
        ? itemSummary
        : '$itemSummary • $transportSummary';

    if (_cashPayItemsTotal > _remainingBalance) {
      _showSnackbar(
        'Insufficient HOD-issued cash. Available: ₹${_remainingBalance.toStringAsFixed(0)}',
        AppTheme.danger,
      );
      return;
    }

    final savedExpense = await _cashExpenseService.submitExpense(
      supervisorId: _currentSupervisorId,
      supervisorName: _currentSupervisorName,
      thavvuId: _selectedThavvuId!,
      siteId: 'site_1',
      siteName: 'Supervisor Cash Site',
      category: _selectedCategory,
      title: _titleForCategory(_selectedCategory),
      amount: _cashPayItemsTotal,
      items: items
          .map(
            (item) => SupervisorCashExpenseItem(
              name: item.name,
              quantity: item.quantity,
              amount: item.amount,
              category: item.category,
              transportEnabled: item.transportEnabled,
              vehicleType: item.vehicleType ?? '',
              transportAmount: item.transportAmount,
            ),
          )
          .toList(),
      remarks:
          '${_titleForCategory(_selectedCategory)}: $fullSummary - $remark',
      invoiceBillPath: _cashPayInvoiceBillPath ?? '',
      vehiclePhotoPath: _cashPayVehiclePhotoPath ?? '',
    );

    // WRITE-THROUGH: persist this expense to Supabase cash_transactions so
    // the HOD cash module and Reports see it. Uses the SAME txn_no the
    // migrator generates (LOCAL-<expense.id>), so an already-synced expense
    // is never written twice (the old CASH-<ts> code double-counted every
    // expense on the HOD ledger). Failure is surfaced, not swallowed.
    var writeThroughFailed = false;
    try {
      final proofPath = (_cashPayInvoiceBillPath ?? '').isEmpty
          ? _cashPayVehiclePhotoPath
          : _cashPayInvoiceBillPath;
      await _cashRepo.createTransaction(
        siteId: _cashSiteId,
        txnNo: 'LOCAL-${savedExpense.id}',
        type: 'expense',
        amount: _cashPayItemsTotal,
        method: 'cash',
        category: _selectedCategory,
        note:
            '${_titleForCategory(_selectedCategory)}: $fullSummary - $remark',
        proofPath: proofPath,
      );
      // Refresh immediately so the summary reflects the new spend.
      await _loadCashTransactions();
    } catch (e) {
      // Offline / backend unavailable — the local ledger keeps the entry
      // and _migrateLocalExpensesToSupabase() pushes it on the next load.
      writeThroughFailed = true;
      debugPrint('cash write-through failed (will migrate later): $e');
      if (mounted) {
        _showSnackbar(
          'Saved locally. Sync to HOD will retry automatically.',
          AppTheme.warning,
        );
      }
    }

    await _loadSupervisorCashData();

    unawaited(
      HodSiteWorkspaceService().recordSupervisorActivityForCurrentSession(
        module: 'Cash',
        action: 'Cash payment submitted',
        details:
            '${_titleForCategory(_selectedCategory)} payment ₹${_cashPayItemsTotal.toStringAsFixed(0)} for $fullSummary.',
      ),
    );
    if (!writeThroughFailed) {
      _showSnackbar(
        '${_titleForCategory(_selectedCategory)} payment submitted successfully!',
        AppTheme.success,
      );
    }
    _clearCashPayForm();
  }

  void _clearCashPayForm() {
    _selectedThavvuId = null;
    _amountController.clear();
    _remarkController.clear();
    _itemNameController.clear();
    _itemQuantityController.text = '1';
    _itemAmountController.clear();
    _cashPayTransportAmountController.clear();
    _cashPayTransportEnabled = false;
    _selectedCashPayVehicleType = null;
    _cashPayVehiclePhotoPath = null;
    _cashPayItems.clear();
    _cashPayInvoiceBillPath = null;
    // Transport split has its own tab and reset flow.
  }

  void _addCashPayItem() {
    if (_selectedThavvuId == null) {
      _showSnackbar('Please select Thavvu ID first', AppTheme.danger);
      return;
    }

    final name = _itemNameController.text.trim();
    final quantity = int.tryParse(_itemQuantityController.text.trim()) ?? 0;
    final amount = double.tryParse(_itemAmountController.text.trim()) ?? 0;

    if (name.isEmpty) {
      _showSnackbar('Please enter item name', AppTheme.danger);
      return;
    }
    if (quantity <= 0) {
      _showSnackbar('Please enter valid quantity', AppTheme.danger);
      return;
    }
    if (amount <= 0) {
      _showSnackbar('Please enter valid item amount', AppTheme.danger);
      return;
    }

    setState(() {
      _cashPayItems.add(
        CashExpenseItem(
          name: name,
          quantity: quantity,
          amount: amount,
          category: _selectedCategory,
        ),
      );
      _syncCashPayDraftTotal();
      _itemNameController.clear();
      _itemQuantityController.text = '1';
      _itemAmountController.clear();
    });
  }

  void _addRequestPayItem() {
    if (_requestSelectedThavvuId == null) {
      _showSnackbar('Please select Thavvu ID first', AppTheme.danger);
      return;
    }

    final name = _requestItemNameController.text.trim();
    final quantity =
        int.tryParse(_requestItemQuantityController.text.trim()) ?? 0;
    final amount =
        double.tryParse(_requestItemAmountController.text.trim()) ?? 0;

    if (name.isEmpty) {
      _showSnackbar('Please enter item name', AppTheme.danger);
      return;
    }
    if (quantity <= 0) {
      _showSnackbar('Please enter valid quantity', AppTheme.danger);
      return;
    }
    if (amount <= 0) {
      _showSnackbar('Please enter valid item amount', AppTheme.danger);
      return;
    }

    setState(() {
      _requestPayItems.add(
        CashExpenseItem(
          name: name,
          quantity: quantity,
          amount: amount,
          category: _requestSelectedCategory,
        ),
      );
      _syncRequestPayDraftTotal();
      _requestItemNameController.clear();
      _requestItemQuantityController.text = '1';
      _requestItemAmountController.clear();
    });
  }

  // ── Updated submit for Request Pay to use saved accounts ──────────────────
  Future<void> _submitRequestPay() async {
    if (_requestSelectedThavvuId == null) {
      _showSnackbar('Please select Thavvu ID', AppTheme.danger);
      return;
    }

    if (_requestPayItems.isEmpty &&
        (_requestItemNameController.text.trim().isNotEmpty ||
            _requestItemAmountController.text.trim().isNotEmpty)) {
      _addRequestPayItem();
    }

    if (_requestPayItems.isEmpty) {
      _showSnackbar(
        'Please add at least one ${_titleForCategory(_requestSelectedCategory).toLowerCase()} item',
        AppTheme.danger,
      );
      return;
    }

    if (_requestTransportEnabled) {
      if (_selectedRequestVehicleType == null) {
        _showSnackbar(
            'Please select vehicle type for transport', AppTheme.danger);
        return;
      }
      if (_requestTransportTotal <= 0) {
        _showSnackbar('Please enter valid transport amount', AppTheme.danger);
        return;
      }
    }

    final amount = _requestPayItemsTotal;
    if (amount <= 0) {
      _showSnackbar('Please enter valid item amounts', AppTheme.danger);
      return;
    }

    final reason = _requestReasonController.text.trim();
    if (reason.isEmpty) {
      _showSnackbar(
          'Please enter final remarks for all added items', AppTheme.danger);
      return;
    }

    if (_requestPaymentMethod == null) {
      _showSnackbar('Please select payment method', AppTheme.danger);
      return;
    }

    if (_selectedRequestOption == null) {
      _showSnackbar(
          'Please select an option (Manual/Photo/Voice)', AppTheme.danger);
      return;
    }

    String? upiId;
    String? bankHolder;
    String? bankAccount;
    String? bankIfsc;
    String? paymentAccountId;

    if (_requestPaymentMethod == 'upi') {
      if (_selectedRequestOption == 'manual') {
        // Use saved UPI account if selected, otherwise manual input
        if (_selectedUPIAccount != null) {
          final acc = _savedUPIAccounts.firstWhere(
            (a) => a['id'] == _selectedUPIAccount,
            orElse: () => {},
          );
          upiId = acc['upiId'];
          paymentAccountId = _selectedUPIAccount;
        } else if (_upiIdController.text.trim().isNotEmpty) {
          upiId = _upiIdController.text.trim();
        } else {
          _showSnackbar('Please select or enter UPI ID', AppTheme.danger);
          return;
        }
      }
    } else if (_requestPaymentMethod == 'bank_transfer') {
      if (_selectedRequestOption == 'manual') {
        if (_selectedBankAccount != null) {
          final acc = _savedBankAccounts.firstWhere(
            (b) => b['id'] == _selectedBankAccount,
            orElse: () => {},
          );
          bankHolder = acc['holderName'];
          bankAccount = acc['accountNumber'];
          bankIfsc = acc['ifsc'];
          paymentAccountId = _selectedBankAccount;
        } else {
          bankHolder = _bankHolderNameController.text.trim();
          bankAccount = _bankAccountNoController.text.trim();
          bankIfsc = _bankIfscCodeController.text.trim();
          if (bankHolder.isEmpty || bankAccount.isEmpty || bankIfsc.isEmpty) {
            _showSnackbar('Please fill all bank details', AppTheme.danger);
            return;
          }
        }
      } else if (_selectedRequestOption == 'photo') {
        if (_requestPhotoPath == null) {
          _showSnackbar('Please upload bank photo', AppTheme.danger);
          return;
        }
      } else if (_selectedRequestOption == 'voice') {
        if (_requestVoicePath == null) {
          _showSnackbar('Please record bank voice details', AppTheme.danger);
          return;
        }
      }
    }

    final items = List<CashExpenseItem>.from(_requestPayItems);
    final itemSummary =
        items.map((item) => '${item.name} x${item.quantity}').join(', ');
    final transportSummary = _requestTransportSummary();
    final fullSummary = transportSummary.isEmpty
        ? itemSummary
        : '$itemSummary • $transportSummary';

    final request = FinanceRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      reason:
          '${_titleForCategory(_requestSelectedCategory)}: $fullSummary - $reason',
      amount: amount,
      paymentMode: _requestPaymentMethod == 'upi' ? 'UPI' : 'Bank Transfer',
      isPaid: false,
      requestDate: DateTime.now(),
      paidDate: null,
      thavvuId: _requestSelectedThavvuId!,
      requestType: _requestSelectedCategory,
      upiId: upiId,
      bankHolderName: bankHolder,
      bankAccountNo: bankAccount,
      bankIfscCode: bankIfsc,
      photoPath: _requestPhotoPath,
      voicePath: _requestVoicePath,
      invoiceBillPath: _requestInvoiceBillPath,
      vehiclePhotoPath: _requestVehiclePhotoPath,
      items: items,
      paymentAccountId: paymentAccountId,
    );

    setState(() {
      _financeRequests.insert(0, request);
    });

    // WRITE-THROUGH to Supabase so the HOD review queue sees the request.
    // (Previously this was local-only; HOD never saw finance requests.)
    final requestNo = 'REQ-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _cashRepo.createFinanceRequest(
        siteId: _cashSiteId,
        requestNo: requestNo,
        thavvuPointId: _requestSelectedThavvuId,
        type: _requestSelectedCategory,
        amount: amount,
        category: _requestSelectedCategory,
        reason: request.reason,
        paymentMethod: _requestPaymentMethod == 'upi' ? 'upi' : 'bank',
        items: items
            .map((i) => {
                  'name': i.name,
                  'quantity': i.quantity,
                  'amount': i.amount,
                })
            .toList(),
        proofPath: (_requestPhotoPath ?? '').isEmpty
            ? _requestInvoiceBillPath
            : _requestPhotoPath,
        voicePath: _requestVoicePath,
      );
    } catch (e) {
      debugPrint('finance request write-through failed: $e');
      // Queue for retry so HOD still receives it when back online.
      await PendingWritesStore.instance.enqueue(
        id: 'req-$requestNo',
        kind: 'finance_request',
        payload: {
          'requestNo': requestNo,
          'siteId': _cashSiteId,
          'thavvuPointId': _requestSelectedThavvuId,
          'type': _requestSelectedCategory,
          'amount': amount,
          'category': _requestSelectedCategory,
          'reason': request.reason,
          'paymentMethod': _requestPaymentMethod == 'upi' ? 'upi' : 'bank',
          'items': items
              .map((i) => {
                    'name': i.name,
                    'quantity': i.quantity,
                    'amount': i.amount,
                  })
              .toList(),
          'proofPath': (_requestPhotoPath ?? '').isEmpty
              ? _requestInvoiceBillPath
              : _requestPhotoPath,
          'voicePath': _requestVoicePath,
        },
      );
      if (mounted) {
        _showSnackbar(
          'Request saved locally. Sync to HOD will retry automatically.',
          AppTheme.warning,
        );
      }
    }

    unawaited(
      HodSiteWorkspaceService().recordSupervisorActivityForCurrentSession(
        module: 'Cash',
        action: 'Finance request submitted',
        details:
            '${_titleForCategory(_requestSelectedCategory)} request ₹${amount.toStringAsFixed(0)} through ${request.paymentMode}.',
      ),
    );
    _showSnackbar('Finance request submitted successfully!', AppTheme.success);
    _clearRequestPayForm();
  }

  void _clearRequestPayForm() {
    _requestSelectedThavvuId = null;
    _requestPaymentMethod = null;
    _selectedRequestOption = null;
    _requestAmountController.clear();
    _requestReasonController.clear();
    _requestItemNameController.clear();
    _requestItemQuantityController.text = '1';
    _requestItemAmountController.clear();
    _requestTransportAmountController.clear();
    _requestTransportEnabled = false;
    _selectedRequestVehicleType = null;
    _requestPayItems.clear();
    _upiIdController.clear();
    _bankHolderNameController.clear();
    _bankAccountNoController.clear();
    _bankIfscCodeController.clear();
    _requestPhotoPath = null;
    _requestVoicePath = null;
    _requestInvoiceBillPath = null;
    _requestVehiclePhotoPath = null;
    _selectedUPIAccount = null;
    _selectedBankAccount = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTRA HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _sendContraRequest() {
    if (_contraSelectedToId == null) {
      _showSnackbar('Please select recipient', AppTheme.danger);
      return;
    }

    final amount = double.tryParse(_contraAmountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackbar('Please enter a valid amount', AppTheme.danger);
      return;
    }

    final request = ContraRequest(
      id: 'contra_${DateTime.now().millisecondsSinceEpoch}',
      fromId: _currentSupervisorId,
      toId: _contraSelectedToId!,
      amount: amount,
      status: 'pending',
      requestDate: DateTime.now(),
    );

    setState(() {
      _contraRequests.insert(0, request);
      _contraSelectedToId = null;
      _contraAmountController.clear();
    });
    _showSnackbar('Contra request sent successfully!', AppTheme.success);
  }

  void _acceptContraRequest(String requestId) {
    setState(() {
      final index = _contraRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _contraRequests[index] = ContraRequest(
          id: _contraRequests[index].id,
          fromId: _contraRequests[index].fromId,
          toId: _contraRequests[index].toId,
          amount: _contraRequests[index].amount,
          status: 'accepted',
          requestDate: _contraRequests[index].requestDate,
          responseDate: DateTime.now(),
        );
      }
    });
    _showSnackbar('Request accepted!', AppTheme.success);
  }

  void _rejectContraRequest(String requestId) {
    setState(() {
      final index = _contraRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _contraRequests[index] = ContraRequest(
          id: _contraRequests[index].id,
          fromId: _contraRequests[index].fromId,
          toId: _contraRequests[index].toId,
          amount: _contraRequests[index].amount,
          status: 'rejected',
          requestDate: _contraRequests[index].requestDate,
          responseDate: DateTime.now(),
        );
      }
    });
    _showSnackbar('Request rejected', AppTheme.danger);
  }

  void _showSnackbar(String message, Color color) {
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCOUNT MANAGEMENT DIALOGS (similar to DailyDataScreen)
  // ═══════════════════════════════════════════════════════════════════════════

  void _showAddUpiAccountSheet({String? existingId}) {
    final accCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    if (existingId != null) {
      final acc = _savedUPIAccounts.firstWhere((a) => a['id'] == existingId);
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
            Text(existingId != null ? 'Edit UPI Account' : 'Add UPI Account',
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: upiCtrl,
              decoration: InputDecoration(
                labelText: 'UPI ID',
                prefixIcon: const Icon(Icons.qr_code),
                filled: true,
                fillColor: AppTheme.surface,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bankCtrl,
              decoration: InputDecoration(
                labelText: 'Bank Name',
                prefixIcon: const Icon(Icons.business),
                filled: true,
                fillColor: AppTheme.surface,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ifscCtrl,
              decoration: InputDecoration(
                labelText: 'IFSC Code',
                prefixIcon: const Icon(Icons.code),
                filled: true,
                fillColor: AppTheme.surface,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
                        final idx = _savedUPIAccounts
                            .indexWhere((a) => a['id'] == existingId);
                        if (idx >= 0) _savedUPIAccounts[idx] = newAcc;
                      } else {
                        _savedUPIAccounts.add(newAcc);
                      }
                      _selectedUPIAccount = newAcc['id'];
                    });
                    Navigator.pop(context);
                    _showSnackbar(
                        existingId != null
                            ? 'UPI account updated!'
                            : 'UPI account added!',
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
                      borderRadius: BorderRadius.circular(12)),
                ),
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
                      borderRadius: BorderRadius.circular(12)),
                ),
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
                      borderRadius: BorderRadius.circular(12)),
                ),
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
                      borderRadius: BorderRadius.circular(12)),
                ),
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
        title: 'HOD Admin: Cash Review',
        moduleFilter: 'Cash',
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              buildCollapsibleAppBar(
                title: 'Cash Module',
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Refresh HOD cash',
                    icon: const Icon(Icons.sync_rounded),
                    onPressed: () async {
                      await _loadHodCashAllocations();
                      if (!mounted) return;
                      _showSnackbar(
                          'HOD cash balance refreshed.', AppTheme.success);
                    },
                  ),
                ],
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Cash Pay'),
                  Tab(text: 'Request'),
                  Tab(text: 'Transport'),
                  Tab(text: 'Contra'),
                  Tab(text: 'History'),
                ],
              ),
              SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(bottom: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: _buildCashSummaryCard(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // ========== CASH PAY TAB ==========
            _buildClassicTabShell(
              emoji: '💵',
              title: 'Cash Pay',
              subtitle:
                  'Classic cash entry for food, assets, others, transport and final remarks.',
              accent: AppTheme.primary,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCategorySelector(),
                    if (_selectedCategory == 'food' ||
                        _selectedCategory == 'others')
                      _buildFoodOthersForm(),
                    if (_selectedCategory == 'assets') _buildAssetsForm(),
                    _buildSubmitButton('💵 Submit Payment'),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            // ========== REQUEST PAY TAB ==========
            _buildClassicTabShell(
              emoji: '📩',
              title: 'Request Pay',
              subtitle:
                  'Raise professional finance requests with item details, proofs and payment mode.',
              accent: AppTheme.info,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildRequestCategorySelector(),
                    if (_requestSelectedCategory == 'food' ||
                        _requestSelectedCategory == 'others')
                      _buildRequestFoodOthersForm(),
                    if (_requestSelectedCategory == 'assets')
                      _buildRequestAssetsForm(),
                    _buildRequestAmountSection(),
                    if (_requestPaymentMethod != null)
                      _buildRequestOptionFields(),
                    _buildSendRequestButton(),
                    const SizedBox(height: 16),
                    _buildFinanceRequestsList(),
                  ],
                ),
              ),
            ),
            // ========== TRANSPORT TAB ==========
            _buildClassicTabShell(
              emoji: '🚚',
              title: 'Transport',
              subtitle:
                  'Split transport bills neatly between Thavvu accounts and keep proof history.',
              accent: AppTheme.warning,
              child: _buildTransportTab(),
            ),
            // ========== CONTRA TAB ==========
            _buildClassicTabShell(
              emoji: '🔁',
              title: 'Contra',
              subtitle:
                  'Request, accept and track internal cash movement between users.',
              accent: AppTheme.success,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildContraTab(),
                  ],
                ),
              ),
            ),
            // ========== HISTORY TAB ==========
            _buildClassicTabShell(
              emoji: '📜',
              title: 'History',
              subtitle:
                  'A classic ledger view of credits, debits, Thavvu IDs and running balance.',
              accent: AppTheme.primary,
              child: Column(
                children: [
                  _buildHistoryTableHeader(),
                  Expanded(
                    child: _buildHistoryList(),
                  ),
                  _buildCategoryFilterDropdown(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLASSIC UI WRAPPERS — THEME SAFE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildClassicTabShell({
    required String emoji,
    required String title,
    required String subtitle,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surface,
            AppTheme.surfaceCard.withValues(alpha: 0.58),
            AppTheme.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          _buildClassicTabHeader(
            emoji: emoji,
            title: title,
            subtitle: subtitle,
            accent: accent,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildClassicTabHeader({
    required String emoji,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.07),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.20)),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.16)),
            ),
            child: Text(
              'Classic',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ==================== HISTORY TAB WIDGETS ====================
  Widget _buildHistoryTableHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '📅 Date',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '📌 Type',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '🆔 Thavvu',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '💰 Balance',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final historyWithBalance = _getHistoryWithRunningBalance();

    if (historyWithBalance.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: AppTheme.textMuted),
              SizedBox(height: 12),
              Text(
                'No history found for selected filter',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: historyWithBalance.length,
      itemBuilder: (context, index) {
        final entry = historyWithBalance[index];
        final item = entry['item'] as HistoryItem;
        final balance = entry['balance'] as double;
        final isCredit = item.isCredit;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  _formatDate(item.date),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    item.transactionType,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isCredit ? AppTheme.success : AppTheme.danger,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  item.thavvuId,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCredit
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SlantArrow(
                        isCredit: isCredit,
                        color: isCredit ? AppTheme.success : AppTheme.danger,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '₹${balance.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                isCredit ? AppTheme.success : AppTheme.danger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilterDropdown() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categories',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategoryFilter,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.filter_list),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: _categoryFilters.map((filter) {
              return DropdownMenuItem<String>(
                value: filter,
                child: Text(filter),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategoryFilter = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  // ==================== CONTRA TAB WIDGETS ====================
  Widget _buildContraTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildContraSubTabButton('Request', 'request'),
              const SizedBox(width: 12),
              _buildContraSubTabButton('Accept', 'accept'),
            ],
          ),
        ),
        if (_contraSubTab == 'request') ...[
          _buildContraRequestForm(),
          _buildContraSentRequestList(),
        ],
        if (_contraSubTab == 'accept') _buildContraAcceptList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildContraSubTabButton(String label, String value) {
    final isSelected = _contraSubTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _contraSubTab = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent])
                : null,
            color: isSelected ? null : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppTheme.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContraRequestForm() {
    final availableRecipients =
        _recipientIds.where((r) => r['id'] != _currentSupervisorId).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contra Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('From',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  _currentSupervisorId,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('To',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _contraSelectedToId,
            hint: const Text('Select recipient'),
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.arrow_forward),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: availableRecipients.map((recipient) {
              return DropdownMenuItem<String>(
                value: recipient['id'],
                child: Row(
                  children: [
                    const Icon(Icons.person,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(recipient['id']!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(recipient['name']!,
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _contraSelectedToId = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contraAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Enter Cash Amount',
              prefixIcon: const Icon(Icons.currency_rupee),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sendContraRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Send Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContraSentRequestList() {
    final sentRequests = _contraRequests
        .where((request) => request.fromId == _currentSupervisorId)
        .toList()
      ..sort((a, b) => b.requestDate.compareTo(a.requestDate));

    if (sentRequests.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.outbox_outlined, color: AppTheme.textMuted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No sent contra requests yet.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Sent Contra Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
        ...sentRequests.map(
          (request) => _buildContraRequestCard(
            request,
            isResolved: request.status != 'pending',
            allowEditDelete: request.status == 'pending',
          ),
        ),
      ],
    );
  }

  Widget _buildContraAcceptList() {
    final pendingRequests = _contraRequests
        .where((r) => r.toId == _currentSupervisorId && r.status == 'pending')
        .toList();
    final acceptedRequests = _contraRequests
        .where((r) => r.toId == _currentSupervisorId && r.status == 'accepted')
        .toList();
    final rejectedRequests = _contraRequests
        .where((r) => r.toId == _currentSupervisorId && r.status == 'rejected')
        .toList();

    if (pendingRequests.isEmpty &&
        acceptedRequests.isEmpty &&
        rejectedRequests.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: AppTheme.textMuted),
              SizedBox(height: 12),
              Text('No contra requests found',
                  style: TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Pending Requests',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning)),
          ),
          ...pendingRequests.map((request) => _buildContraRequestCard(request)),
        ],
        if (acceptedRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Accepted Requests',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success)),
          ),
          ...acceptedRequests.map(
              (request) => _buildContraRequestCard(request, isResolved: true)),
        ],
        if (rejectedRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Rejected Requests',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.danger)),
          ),
          ...rejectedRequests.map(
              (request) => _buildContraRequestCard(request, isResolved: true)),
        ],
      ],
    );
  }

  Widget _buildContraRequestCard(
    ContraRequest request, {
    bool isResolved = false,
    bool allowEditDelete = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: request.status == 'accepted'
              ? AppTheme.success
              : request.status == 'rejected'
                  ? AppTheme.danger
                  : AppTheme.warning,
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.person,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('From: ${request.fromId}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: request.status == 'accepted'
                      ? AppTheme.successBg
                      : request.status == 'rejected'
                          ? AppTheme.dangerBg
                          : AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request.status == 'accepted'
                      ? 'ACCEPTED'
                      : request.status == 'rejected'
                          ? 'REJECTED'
                          : 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: request.status == 'accepted'
                        ? AppTheme.success
                        : request.status == 'rejected'
                            ? AppTheme.danger
                            : AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.currency_rupee,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text('₹${request.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'To: ${request.toId}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Requested: ${_formatDateTime(request.requestDate)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (request.responseDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Responded: ${_formatDateTime(request.responseDate!)}',
              style: TextStyle(
                  fontSize: 11,
                  color: request.status == 'accepted'
                      ? AppTheme.success
                      : AppTheme.danger),
            ),
          ],
          if (allowEditDelete && request.status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editContraRequest(request),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.info,
                      side: BorderSide(color: AppTheme.info),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteContraRequest(request),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(color: AppTheme.danger),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (!isResolved && request.status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _acceptContraRequest(request.id),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Accept'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.success,
                      side: BorderSide(color: AppTheme.success),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectContraRequest(request.id),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(color: AppTheme.danger),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== CASH PAY WIDGETS ====================
  Widget _buildCashSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Text('🏦', style: TextStyle(fontSize: 21)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Allocated, spent and remaining balance overview',
                      style: TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryItem(
                'Total Allocated',
                '₹${_totalCashIssued.toStringAsFixed(0)}',
                Icons.account_balance_wallet,
              ),
              _summaryItem(
                'Total Spent',
                '₹${_totalSpentAllSites.toStringAsFixed(0)}',
                Icons.shopping_cart,
              ),
              _summaryItem(
                'Remaining',
                '₹${_remainingBalance.toStringAsFixed(0)}',
                Icons.currency_rupee,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: Colors.white70),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9.5, color: Colors.white70),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildCategoryChip('🍽️ Food', 'food', Icons.restaurant),
          const SizedBox(width: 12),
          _buildCategoryChip('🧰 Assets', 'assets', Icons.inventory),
          const SizedBox(width: 12),
          _buildCategoryChip('✨ Others', 'others', Icons.more_horiz),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value, IconData icon) {
    final isSelected = _selectedCategory == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = value;
            _clearCashPayForm();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : AppTheme.border.withValues(alpha: 0.9),
              width: 1,
            ),
            boxShadow: isSelected ? AppTheme.cardShadow : AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodOthersForm() {
    return _buildCashPayItemComposer(
      title: _selectedCategory == 'food'
          ? '🍽️ Food Payment Details'
          : '✨ Other Payment Details',
      itemLabel:
          _selectedCategory == 'food' ? 'Food Item Name' : 'Other Item Name',
      icon: _selectedCategory == 'food' ? Icons.restaurant : Icons.more_horiz,
    );
  }

  Widget _buildAssetsForm() {
    return _buildCashPayItemComposer(
      title: '🧰 Asset Payment Details',
      itemLabel: 'Asset Item Name',
      icon: Icons.inventory,
    );
  }

  Widget _buildCashPayItemComposer({
    required String title,
    required String itemLabel,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Select Thavvu ID',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedThavvuId,
            hint: const Text('Choose Thavvu ID'),
            isExpanded: true,
            isDense: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.verified_user),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            ),
            selectedItemBuilder: (context) {
              return _thavvuIds.map((thavvu) {
                return Text(
                  thavvu['id']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                );
              }).toList();
            },
            items: _thavvuIds.map((thavvu) {
              return DropdownMenuItem<String>(
                value: thavvu['id'],
                child: SizedBox(
                  height: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(thavvu['id']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(thavvu['name']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedThavvuId = value),
          ),
          const SizedBox(height: 16),
          if (_selectedThavvuId == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.info),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Choose Thavvu ID first. Item name, amount, and transport details will be added under that Thavvu.',
                      style: TextStyle(fontSize: 12, color: AppTheme.info),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _itemNameController,
              decoration: InputDecoration(
                labelText: itemLabel,
                prefixIcon: const Icon(Icons.label_outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _itemAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount / Item',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addCashPayItem,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                    'Add Multiple ${_titleForCategory(_selectedCategory)} Items'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.info,
                  side: BorderSide(color: AppTheme.info),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            _buildExpenseItemsPreview(
              items: _cashPayItems,
              emptyText: 'No items added yet.',
              onEdit: _editCashPayItem,
              onRemove: _deleteCashPayItem,
            ),
            const SizedBox(height: 12),
            _buildTotalAmountBox(
              label: 'Total Payment Amount',
              amount: _cashPayItemsTotal,
            ),
            const SizedBox(height: 12),
            _buildCashTransportToggle(),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _remarkController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Last Remarks for All Added Items',
              hintText: 'Enter final remarks for this payment plan...',
              prefixIcon: const Icon(Icons.note),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          _buildCashUploadButton(
            label: _cashPayInvoiceBillPath != null
                ? 'Invoice / Bill Added'
                : 'Add Invoice / Bill',
            icon: Icons.receipt_long_outlined,
            color: AppTheme.info,
            onTap: () {
              setState(() {
                _cashPayInvoiceBillPath =
                    'cash_bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCashTransportToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cashPayTransportEnabled ? AppTheme.infoBg : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _cashPayTransportEnabled
              ? AppTheme.info.withValues(alpha: 0.35)
              : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Transport Required',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'Turn on if this item used a vehicle/transport amount'),
            value: _cashPayTransportEnabled,
            activeColor: AppTheme.info,
            onChanged: (value) {
              setState(() {
                _cashPayTransportEnabled = value;
                if (!value) {
                  _selectedCashPayVehicleType = null;
                  _cashPayTransportAmountController.clear();
                  _cashPayVehiclePhotoPath = null;
                }
                _syncCashPayDraftTotal();
              });
            },
          ),
          if (_cashPayTransportEnabled) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCashPayVehicleType,
              hint: const Text('Select Vehicle Type'),
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.local_shipping_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _vehicleTypes.map((vehicle) {
                return DropdownMenuItem<String>(
                  value: vehicle,
                  child: Text(vehicle),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedCashPayVehicleType = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cashPayTransportAmountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {
                _syncCashPayDraftTotal();
              }),
              decoration: InputDecoration(
                labelText: 'Transport Amount Used (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            _buildCashUploadButton(
              label: _cashPayVehiclePhotoPath != null
                  ? 'Vehicle Photo Added'
                  : 'Add Vehicle Photo',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.warning,
              onTap: () {
                setState(() {
                  _cashPayVehiclePhotoPath =
                      'cash_vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg';
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseItemsPreview({
    required List<CashExpenseItem> items,
    required String emptyText,
    required void Function(int index) onEdit,
    required void Function(int index) onRemove,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(emptyText,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                  item.transportEnabled
                      ? Icons.local_shipping_outlined
                      : Icons.inventory_2_outlined,
                  size: 18,
                  color:
                      item.transportEnabled ? AppTheme.warning : AppTheme.info,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(
                        'Qty ${item.quantity} x ₹${item.amount.toStringAsFixed(0)} = ₹${item.baseTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                      if (item.transportEnabled)
                        Text(
                          'Transport: ${item.transportSummary}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.warning),
                        ),
                    ],
                  ),
                ),
                Text('₹${item.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: 'Edit item',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppTheme.info,
                  onPressed: () => onEdit(index),
                ),
                IconButton(
                  tooltip: 'Delete item',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppTheme.danger,
                  onPressed: () => onRemove(index),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTotalAmountBox({
    required String label,
    required double amount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined,
              size: 18, color: AppTheme.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success)),
          ),
          Text('₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.success)),
        ],
      ),
    );
  }

  // ==================== TRANSPORT TAB WIDGETS ====================
  Widget _buildTransportTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTransportSummaryCard(),
          _buildTransportForm(),
          _buildTransportSubmitButton(),
          _buildTransportSplitHistory(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTransportSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Transport Split Billing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Split one transport bill across multiple Thavvu IDs and track each share separately.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildTransportSummaryItem(
                'Bills',
                _transportSplitBills.length.toString(),
                Icons.receipt_long,
              ),
              _buildTransportSummaryItem(
                'Split Lines',
                _transportSplitLineCount.toString(),
                Icons.account_tree,
              ),
              _buildTransportSummaryItem(
                'Total',
                '₹${_transportTotalAmount.toStringAsFixed(0)}',
                Icons.currency_rupee,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransportSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportForm() {
    final selectedCount = _selectedSplitThavvuIds.length;
    final total = double.tryParse(_transportTotalController.text.trim()) ?? 0;
    final splitTotal = _selectedSplitThavvuIds.fold<double>(
      0,
      (sum, id) => sum + (_splitAmounts[id] ?? 0),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Transport Split Bill',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use this when one vehicle/transport cost must be shared by multiple Thavvu IDs.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _transportTotalController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Total Transport Amount',
              hintText: 'Example: 12000',
              prefixIcon: const Icon(Icons.currency_rupee),
              filled: true,
              fillColor: AppTheme.surface,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) {
              setState(() {
                if (_splitMode == 'equal') {
                  _recalculateEqualTransportSplit();
                }
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Thavvu IDs',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._thavvuIds.map((thavvu) {
            final id = thavvu['id']!;
            final name = thavvu['name']!;
            final isSelected = _selectedSplitThavvuIds.contains(id);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (bool? checked) {
                  setState(() {
                    if (checked == true && !isSelected) {
                      _selectedSplitThavvuIds.add(id);
                    } else {
                      _selectedSplitThavvuIds.remove(id);
                      _splitAmounts.remove(id);
                    }

                    if (_splitMode == 'equal') {
                      _recalculateEqualTransportSplit();
                    }
                  });
                },
                title: Text(
                  id,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
                activeColor: AppTheme.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Equal'),
                  subtitle: const Text('Auto split'),
                  value: 'equal',
                  groupValue: _splitMode,
                  dense: true,
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _splitMode = val;
                      _recalculateEqualTransportSplit();
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Manual'),
                  subtitle: const Text('Custom share'),
                  value: 'manual',
                  groupValue: _splitMode,
                  dense: true,
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _splitMode = val);
                  },
                ),
              ),
            ],
          ),
          if (_splitMode == 'manual' && _selectedSplitThavvuIds.isNotEmpty)
            ..._selectedSplitThavvuIds.map((id) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '$id Split Amount',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _splitAmounts[id] = double.tryParse(val) ?? 0;
                    });
                  },
                ),
              );
            }),
          if (_selectedSplitThavvuIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSplitPreview(total, splitTotal, selectedCount),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _transportRemarkController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Transport Remarks',
              hintText: 'Example: Feed lorry from Bhimavaram yard to ponds',
              prefixIcon: const Icon(Icons.note),
              filled: true,
              fillColor: AppTheme.surface,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCashUploadButton(
                  label: _transportVehiclePhotoPath != null
                      ? 'Vehicle Photo Added'
                      : 'Take Vehicle Photo',
                  icon: Icons.local_shipping_outlined,
                  color: AppTheme.primary,
                  onTap: () {
                    setState(() {
                      _transportVehiclePhotoPath =
                          'vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCashUploadButton(
                  label: _transportInvoiceBillPath != null
                      ? 'Invoice / Bill Added'
                      : 'Add Invoice / Bill',
                  icon: Icons.receipt_long_outlined,
                  color: AppTheme.info,
                  onTap: () {
                    setState(() {
                      _transportInvoiceBillPath =
                          'transport_bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPreview(
    double total,
    double splitTotal,
    int selectedCount,
  ) {
    final isManualMismatch =
        _splitMode == 'manual' && (splitTotal - total).abs() > 0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isManualMismatch
            ? AppTheme.warning.withValues(alpha: 0.10)
            : AppTheme.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isManualMismatch ? AppTheme.warning : AppTheme.success,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Split Preview • $selectedCount Thavvu ID(s)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isManualMismatch ? AppTheme.warning : AppTheme.success,
            ),
          ),
          const SizedBox(height: 8),
          ..._selectedSplitThavvuIds.map((id) {
            final amount = _splitAmounts[id] ??
                (selectedCount == 0 ? 0 : total / selectedCount);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$id • ${_thavvuNameFor(id)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_splitMode == 'manual') ...[
            const Divider(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Manual split total',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '₹${splitTotal.toStringAsFixed(0)} / ₹${total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color:
                        isManualMismatch ? AppTheme.warning : AppTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransportSubmitButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitTransportSplit,
        icon: const Icon(Icons.call_split),
        label: const Text(
          'Submit Transport Split Bill',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildTransportSplitHistory() {
    final grouped = _transportTransactionsByThavvu;
    final totals = _transportAmountByThavvu;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Split Bill History by Thavvu ID',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Every submitted transport split is stored separately under each Thavvu ID.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          if (_transportSplitBills.isNotEmpty) ...[
            const Text(
              'Recent split bills',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._transportSplitBills.map(_buildTransportBillCard),
            const SizedBox(height: 12),
          ],
          if (grouped.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 42,
                    color: AppTheme.textMuted,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No transport split history yet',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            )
          else
            ...grouped.entries.map(
              (entry) => _buildTransportThavvuHistorySection(
                entry.key,
                entry.value,
                totals[entry.key] ?? 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransportBillCard(TransportSplitBill bill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bill.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  bill.splitMode == 'equal' ? 'Equal Split' : 'Manual Split',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit split bill',
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppTheme.info,
                onPressed: () => _editTransportBill(bill),
              ),
              IconButton(
                tooltip: 'Delete split bill',
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppTheme.danger,
                onPressed: () => _deleteTransportBill(bill),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatDateTime(bill.dateTime)} • ₹${bill.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (bill.remarks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              bill.remarks,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ...bill.lines.map(
            (line) => Row(
              children: [
                Expanded(
                  child: Text(
                    '${line.thavvuId} • ${line.thavvuName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '₹${line.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
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

  Widget _buildTransportThavvuHistorySection(
    String thavvuId,
    List<CashTransaction> transactions,
    double total,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: transactions.length <= 2,
        leading: const CircleAvatar(
          backgroundColor: AppTheme.primary,
          child: Icon(Icons.person, color: Colors.white, size: 18),
        ),
        title: Text(
          thavvuId,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${_thavvuNameFor(thavvuId)} • ${transactions.length} split(s)',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Text(
          '₹${total.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
          ),
        ),
        children: transactions.map((txn) {
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.local_shipping,
              size: 18,
              color: AppTheme.textMuted,
            ),
            title: Text(
              txn.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(
              _formatDateTime(txn.dateTime),
              style: const TextStyle(fontSize: 10),
            ),
            trailing: Text(
              '₹${txn.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.danger,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubmitButton(String label) {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitCashPay,
        icon: const Icon(Icons.verified_outlined, size: 20),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ==================== REQUEST PAY WIDGETS ====================
  Widget _buildRequestCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildRequestCategoryChip('🍽️ Food', 'food', Icons.restaurant),
          const SizedBox(width: 12),
          _buildRequestCategoryChip('🧰 Assets', 'assets', Icons.inventory),
          const SizedBox(width: 12),
          _buildRequestCategoryChip('✨ Others', 'others', Icons.more_horiz),
        ],
      ),
    );
  }

  Widget _buildRequestCategoryChip(String label, String value, IconData icon) {
    final isSelected = _requestSelectedCategory == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _requestSelectedCategory = value;
            _clearRequestPayForm();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : AppTheme.border.withValues(alpha: 0.9),
            ),
            boxShadow: isSelected ? AppTheme.cardShadow : AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppTheme.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppTheme.info,
                  size: 20,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestFoodOthersForm() {
    return _buildRequestPayItemComposer(
      title: _requestSelectedCategory == 'food'
          ? '🍽️ Food Request Details'
          : '✨ Other Request Details',
      itemLabel: _requestSelectedCategory == 'food'
          ? 'Food Item Name'
          : 'Other Item Name',
      icon: _requestSelectedCategory == 'food'
          ? Icons.restaurant
          : Icons.more_horiz,
    );
  }

  Widget _buildRequestAssetsForm() {
    return _buildRequestPayItemComposer(
      title: '🧰 Asset Request Details',
      itemLabel: 'Asset Item Name',
      icon: Icons.inventory,
    );
  }

  Widget _buildRequestPayItemComposer({
    required String title,
    required String itemLabel,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Select Thavvu ID',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _requestSelectedThavvuId,
            hint: const Text('Choose Thavvu ID'),
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.verified_user),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _thavvuIds.map((thavvu) {
              return DropdownMenuItem<String>(
                value: thavvu['id'],
                child: SizedBox(
                  height: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(thavvu['id']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(thavvu['name']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) =>
                setState(() => _requestSelectedThavvuId = value),
          ),
          const SizedBox(height: 16),
          if (_requestSelectedThavvuId == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.info),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Choose Thavvu ID first. Then add food, assets, or other request items under that Thavvu.',
                      style: TextStyle(fontSize: 12, color: AppTheme.info),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _requestItemNameController,
              decoration: InputDecoration(
                labelText: itemLabel,
                prefixIcon: const Icon(Icons.label_outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _requestItemQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _requestItemAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount / Item',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addRequestPayItem,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                    'Add Multiple ${_titleForCategory(_requestSelectedCategory)} Request Items'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.info,
                  side: BorderSide(color: AppTheme.info),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            _buildExpenseItemsPreview(
              items: _requestPayItems,
              emptyText: 'No request items added yet.',
              onEdit: _editRequestPayItem,
              onRemove: _deleteRequestPayItem,
            ),
            const SizedBox(height: 12),
            _buildTotalAmountBox(
              label: 'Total Request Amount',
              amount: _requestPayItemsTotal,
            ),
            const SizedBox(height: 12),
            _buildRequestTransportToggle(),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _requestReasonController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Last Remarks for All Added Items',
              hintText: 'Enter final reason / payment plan remarks...',
              prefixIcon: const Icon(Icons.description),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTransportToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _requestTransportEnabled ? AppTheme.infoBg : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _requestTransportEnabled
              ? AppTheme.info.withValues(alpha: 0.35)
              : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Transport Required',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'Turn on if this request item needs a vehicle/transport amount'),
            value: _requestTransportEnabled,
            activeColor: AppTheme.info,
            onChanged: (value) {
              setState(() {
                _requestTransportEnabled = value;
                if (!value) {
                  _selectedRequestVehicleType = null;
                  _requestTransportAmountController.clear();
                  _requestVehiclePhotoPath = null;
                }
                _syncRequestPayDraftTotal();
              });
            },
          ),
          if (_requestTransportEnabled) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRequestVehicleType,
              hint: const Text('Select Vehicle Type'),
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.local_shipping_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _vehicleTypes.map((vehicle) {
                return DropdownMenuItem<String>(
                  value: vehicle,
                  child: Text(vehicle),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedRequestVehicleType = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _requestTransportAmountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {
                _syncRequestPayDraftTotal();
              }),
              decoration: InputDecoration(
                labelText: 'Transport Amount Used (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            _buildCashUploadButton(
              label: _requestVehiclePhotoPath != null
                  ? 'Vehicle Photo Added'
                  : 'Add Vehicle Photo',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.warning,
              onTap: () {
                setState(() {
                  _requestVehiclePhotoPath =
                      'request_vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg';
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestAmountSection() {
    final hasItems = _requestPayItems.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _requestAmountController,
            readOnly: hasItems,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: hasItems
                  ? 'Advance Amount (Auto Total)'
                  : 'Advance Amount (₹)',
              helperText: hasItems
                  ? 'Amount is calculated from added food/assets/other items'
                  : 'Add items above to auto-calculate request amount',
              prefixIcon: const Icon(Icons.request_quote, size: 18),
              filled: true,
              fillColor: hasItems ? AppTheme.successBg : AppTheme.surface,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Payment Method',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRequestPaymentModeCard(
                  label: 'UPI',
                  value: 'upi',
                  icon: Icons.qr_code,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRequestPaymentModeCard(
                  label: 'Bank Transfer',
                  value: 'bank_transfer',
                  icon: Icons.account_balance,
                  color: AppTheme.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPaymentModeCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _requestPaymentMethod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _requestPaymentMethod = value;
          _selectedRequestOption = value == 'bank_transfer' ? null : 'manual';
          _selectedUPIAccount = null;
          _selectedBankAccount = null;
          _upiIdController.clear();
          _bankHolderNameController.clear();
          _bankAccountNoController.clear();
          _bankIfscCodeController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : AppTheme.border,
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 28, color: isSelected ? color : AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestOptionFields() {
    if (_requestPaymentMethod == 'upi') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Verified UPI Account',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            ..._savedUPIAccounts.map((acc) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedUPIAccount = acc['id'];
                      _upiIdController.text = acc['upiId']!;
                      _selectedRequestOption = 'manual';
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedUPIAccount == acc['id']
                          ? AppTheme.successBg
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _selectedUPIAccount == acc['id']
                              ? AppTheme.success
                              : AppTheme.border,
                          width: _selectedUPIAccount == acc['id'] ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            _selectedUPIAccount == acc['id']
                                ? Icons.check_circle
                                : Icons.account_balance_wallet,
                            size: 20,
                            color: _selectedUPIAccount == acc['id']
                                ? AppTheme.success
                                : AppTheme.textMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(acc['upiId']!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedUPIAccount == acc['id']
                                          ? AppTheme.success
                                          : AppTheme.textPrimary)),
                              Text(acc['bankName']!,
                                  style: const TextStyle(
                                      fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        if (acc['type'] == 'primary')
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
                              _showAddUpiAccountSheet(existingId: acc['id']),
                          color: AppTheme.warning,
                        ),
                      ],
                    ),
                  ),
                )),
            TextButton.icon(
              onPressed: _showAddUpiAccountSheet,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add UPI Account'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.info),
            ),
            const SizedBox(height: 8),
            const Text('Or enter manually',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _upiIdController,
              decoration: InputDecoration(
                labelText: 'UPI ID or Phone Number',
                prefixIcon: const Icon(Icons.qr_code),
                filled: true,
                fillColor: AppTheme.surface,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'example@okhdfcbank or 9876543210',
              ),
              onChanged: (_) =>
                  setState(() => _selectedRequestOption = 'manual'),
            ),
            const SizedBox(height: 12),
            _buildCashUploadButton(
              label: _requestInvoiceBillPath != null
                  ? 'Invoice / Bill Added'
                  : 'Add Invoice / Bill',
              icon: Icons.receipt_long_outlined,
              color: AppTheme.info,
              onTap: () {
                setState(() {
                  _requestInvoiceBillPath =
                      'request_bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
                });
              },
            ),
            const SizedBox(height: 12),
            _buildCashRequestNotice(),
          ],
        ),
      );
    } else if (_requestPaymentMethod == 'bank_transfer') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      _bankHolderNameController.text = bank['holderName'] ?? '';
                      _bankAccountNoController.text = bank['accountNumber']!;
                      _bankIfscCodeController.text = bank['ifsc']!;
                      _selectedRequestOption = 'manual';
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
                                : Icons.account_balance,
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
                                      color: _selectedBankAccount == bank['id']
                                          ? AppTheme.info
                                          : AppTheme.textPrimary)),
                              Text(
                                  'A/C ${bank['accountNumber']}  ·  IFSC: ${bank['ifsc']}',
                                  style: const TextStyle(
                                      fontSize: 10, color: AppTheme.textMuted)),
                              if (bank['holderName']!.isNotEmpty)
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
                          onPressed: () =>
                              _showAddBankAccountSheet(existingId: bank['id']),
                          color: AppTheme.warning,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                )),
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
            const Text('Select Entry Method',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _buildRequestEntryMethodOption(
                        'manual', 'Manual', Icons.edit_outlined)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildRequestEntryMethodOption(
                        'photo', 'Photo', Icons.camera_alt_outlined)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildRequestEntryMethodOption(
                        'voice', 'Voice', Icons.mic_none)),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedRequestOption == 'manual') ...[
              const Text('Bank Details',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _bankIfscCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'IFSC Code',
                  prefixIcon: const Icon(Icons.code),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bankAccountNoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  prefixIcon: const Icon(Icons.account_balance),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bankHolderNameController,
                decoration: InputDecoration(
                  labelText: 'Bank Holder Name',
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else if (_selectedRequestOption == 'photo') ...[
              _buildCashUploadButton(
                label: _requestPhotoPath != null
                    ? 'Bank Photo Added'
                    : 'Upload Bank Photo',
                icon: Icons.camera_alt_outlined,
                color: AppTheme.info,
                onTap: () {
                  setState(() {
                    _requestPhotoPath =
                        'bank_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  });
                },
              ),
            ] else if (_selectedRequestOption == 'voice') ...[
              _buildCashUploadButton(
                label: _requestVoicePath != null
                    ? 'Bank Voice Added'
                    : 'Record Bank Voice',
                icon: Icons.mic_none,
                color: AppTheme.info,
                onTap: () {
                  setState(() {
                    _requestVoicePath =
                        'bank_voice_${DateTime.now().millisecondsSinceEpoch}.mp3';
                  });
                },
              ),
            ],
            if (_selectedRequestOption != null) ...[
              const SizedBox(height: 8),
              _buildCashUploadButton(
                label: _requestInvoiceBillPath != null
                    ? 'Invoice / Bill Added'
                    : 'Add Invoice / Bill',
                icon: Icons.receipt_long_outlined,
                color: AppTheme.info,
                onTap: () {
                  setState(() {
                    _requestInvoiceBillPath =
                        'request_bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildCashRequestNotice(),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRequestEntryMethodOption(
      String method, String title, IconData icon) {
    final isSelected = _selectedRequestOption == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedRequestOption = method),
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

  Widget _buildCashRequestNotice() {
    return Container(
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
    );
  }

  Widget _buildCashUploadButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final attached = label.toLowerCase().contains('added') ||
        label.toLowerCase().contains('captured') ||
        label.toLowerCase().contains('recorded');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: attached ? color.withValues(alpha: 0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: attached ? color : AppTheme.border,
            width: attached ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(attached ? Icons.check_circle : icon,
                  size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: attached ? color : AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: attached ? color : AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSendRequestButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitRequestPay,
        icon: const Icon(Icons.send_rounded, size: 20),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        label: const Text(
          '📩 Send Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildFinanceRequestsList() {
    if (_financeRequests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: Text('No finance requests found.',
                style: TextStyle(color: AppTheme.textMuted))),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _financeRequests.length,
      itemBuilder: (context, index) {
        final req = _financeRequests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: req.isPaid ? AppTheme.success : AppTheme.warning,
                width: 1),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      req.reason,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          req.isPaid ? AppTheme.successBg : AppTheme.warningBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      req.isPaid ? 'PAID' : 'PENDING',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              req.isPaid ? AppTheme.success : AppTheme.warning),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.currency_rupee,
                      size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text('₹${req.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Icon(Icons.verified_user,
                      size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(req.thavvuId,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              if (req.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...req.items.asMap().entries.map((entry) {
                  final itemIndex = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.transportEnabled
                              ? Icons.local_shipping_outlined
                              : Icons.inventory_2_outlined,
                          size: 16,
                          color: item.transportEnabled
                              ? AppTheme.warning
                              : AppTheme.info,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.name} x${item.quantity} • ₹${item.total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                        if (item.transportEnabled)
                          Text(
                            item.vehicleType ?? 'Vehicle',
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.warning),
                          ),
                        if (!req.isPaid) ...[
                          IconButton(
                            tooltip: 'Edit request item',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            color: AppTheme.info,
                            onPressed: () =>
                                _editFinanceRequestItem(req, itemIndex),
                          ),
                          IconButton(
                            tooltip: 'Delete request item',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline, size: 16),
                            color: AppTheme.danger,
                            onPressed: () =>
                                _deleteFinanceRequestItem(req, itemIndex),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 6),
              Text('Payment: ${req.paymentMode}',
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              if (req.upiId != null)
                Text('UPI ID: ${req.upiId}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              if (req.bankHolderName != null)
                Text('Bank: ${req.bankHolderName}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 4),
              Text('Requested: ${_formatDate(req.requestDate)}',
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              if (req.isPaid && req.paidDate != null) ...[
                const SizedBox(height: 4),
                Text('Paid on: ${_formatDate(req.paidDate!)}',
                    style:
                        const TextStyle(fontSize: 11, color: AppTheme.success)),
              ],
              if (!req.isPaid) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editFinanceRequest(req),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Request'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.info,
                          side: BorderSide(color: AppTheme.info),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteFinanceRequest(req),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: BorderSide(color: AppTheme.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }


}
