import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

/// Local backend / application state for Thavvu Supervisor.
/// Persists key collections to SharedPreferences as JSON.
class AppStore extends ChangeNotifier {
  static const _storageKey = 'thavvu_app_store_v1';
  static const _sessionKey = 'thavvu_session_email';

  bool ready = false;
  AppUser? currentUser;

  final List<AppUser> users = [];
  final List<MachineRecord> machines = [];
  final List<DailyLog> dailyLogs = [];
  final List<Worker> workers = [];
  final List<AttendanceRecord> attendance = [];
  final List<StockPoint> stockPoints = [];
  final List<StockMovement> stockMovements = [];
  final List<StockOrder> stockOrders = [];
  final List<StockReturn> stockReturns = [];
  final List<TransferRecord> transfers = [];
  final List<RentalRecord> rentals = [];
  final List<AppTask> tasks = [];
  final List<ReportRecord> reports = [];
  final List<AppNotification> notifications = [];
  final List<MapLocation> mapLocations = [];

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';

  Future<void> init() async {
    if (ready) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _seed();
      }
    } else {
      _seed();
    }

    final sessionEmail = prefs.getString(_sessionKey);
    if (sessionEmail != null) {
      try {
        currentUser = users.firstWhere((u) => u.email == sessionEmail && u.approved);
      } catch (_) {
        currentUser = null;
      }
    }

    ready = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  Future<void> _setSession(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, email);
    }
  }

  Map<String, dynamic> _toJson() => {
        'users': users.map((e) => e.toJson()).toList(),
        'machines': machines.map((e) => e.toJson()).toList(),
        'dailyLogs': dailyLogs.map((e) => e.toJson()).toList(),
        'workers': workers.map((e) => e.toJson()).toList(),
        'attendance': attendance.map((e) => e.toJson()).toList(),
        'stockPoints': stockPoints.map((e) => e.toJson()).toList(),
        'stockMovements': stockMovements.map((e) => e.toJson()).toList(),
        'stockOrders': stockOrders.map((e) => e.toJson()).toList(),
        'stockReturns': stockReturns.map((e) => e.toJson()).toList(),
        'transfers': transfers.map((e) => e.toJson()).toList(),
        'rentals': rentals.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'reports': reports.map((e) => e.toJson()).toList(),
        'notifications': notifications.map((e) => e.toJson()).toList(),
        'mapLocations': mapLocations.map((e) => e.toJson()).toList(),
      };

  void _loadFromJson(Map<String, dynamic> j) {
    users
      ..clear()
      ..addAll(((j['users'] as List?) ?? [])
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map))));
    machines
      ..clear()
      ..addAll(((j['machines'] as List?) ?? [])
          .map((e) => MachineRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    dailyLogs
      ..clear()
      ..addAll(((j['dailyLogs'] as List?) ?? [])
          .map((e) => DailyLog.fromJson(Map<String, dynamic>.from(e as Map))));
    workers
      ..clear()
      ..addAll(((j['workers'] as List?) ?? [])
          .map((e) => Worker.fromJson(Map<String, dynamic>.from(e as Map))));
    attendance
      ..clear()
      ..addAll(((j['attendance'] as List?) ?? [])
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    stockPoints
      ..clear()
      ..addAll(((j['stockPoints'] as List?) ?? [])
          .map((e) => StockPoint.fromJson(Map<String, dynamic>.from(e as Map))));
    stockMovements
      ..clear()
      ..addAll(((j['stockMovements'] as List?) ?? [])
          .map((e) => StockMovement.fromJson(Map<String, dynamic>.from(e as Map))));
    stockOrders
      ..clear()
      ..addAll(((j['stockOrders'] as List?) ?? [])
          .map((e) => StockOrder.fromJson(Map<String, dynamic>.from(e as Map))));
    stockReturns
      ..clear()
      ..addAll(((j['stockReturns'] as List?) ?? [])
          .map((e) => StockReturn.fromJson(Map<String, dynamic>.from(e as Map))));
    transfers
      ..clear()
      ..addAll(((j['transfers'] as List?) ?? [])
          .map((e) => TransferRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    rentals
      ..clear()
      ..addAll(((j['rentals'] as List?) ?? [])
          .map((e) => RentalRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    tasks
      ..clear()
      ..addAll(((j['tasks'] as List?) ?? [])
          .map((e) => AppTask.fromJson(Map<String, dynamic>.from(e as Map))));
    reports
      ..clear()
      ..addAll(((j['reports'] as List?) ?? [])
          .map((e) => ReportRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    notifications
      ..clear()
      ..addAll(((j['notifications'] as List?) ?? [])
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))));
    mapLocations
      ..clear()
      ..addAll(((j['mapLocations'] as List?) ?? [])
          .map((e) => MapLocation.fromJson(Map<String, dynamic>.from(e as Map))));

    if (users.isEmpty || stockPoints.isEmpty) {
      _seed();
    }
  }

  void _seed() {
    users
      ..clear()
      ..add(const AppUser(
        id: 'USR-001',
        name: 'Rajesh Kumar',
        email: 'rajesh@thavvu.com',
        password: 'password',
        role: 'Senior Supervisor',
        empId: 'EMP-001',
        site: 'Site A – Chennai North',
        phone: '+91 98765 43210',
        joinDate: '12 Jan 2022',
      ));

    machines
      ..clear()
      ..addAll([
        MachineRecord(
          id: 'MR-001',
          machineId: 'MCH-001',
          operatorName: 'Suresh',
          vehicleNumber: 'TN-01-AB-1234',
          vehicleType: 'Excavator',
          billingType: 'Hourly',
          workingAmount: 2500,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
        MachineRecord(
          id: 'MR-002',
          machineId: 'MCH-002',
          operatorName: 'Anil',
          vehicleNumber: 'TN-02-CD-5678',
          vehicleType: 'Loader',
          billingType: 'Daily',
          workingAmount: 4000,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 8)),
        ),
        MachineRecord(
          id: 'MR-003',
          machineId: 'MCH-003',
          operatorName: 'Vikram',
          vehicleNumber: 'TN-03-EF-9012',
          vehicleType: 'Crane',
          billingType: 'Hourly',
          workingAmount: 3500,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        MachineRecord(
          id: 'MR-004',
          machineId: 'MCH-004',
          operatorName: 'Ravi',
          vehicleNumber: 'TN-04-GH-3456',
          vehicleType: 'Dump Truck',
          billingType: 'Daily',
          workingAmount: 2800,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        MachineRecord(
          id: 'MR-005',
          machineId: 'MCH-005',
          operatorName: 'Kumar',
          vehicleNumber: 'TN-05-IJ-7890',
          vehicleType: 'Compactor',
          billingType: 'Hourly',
          workingAmount: 1800,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ]);

    workers
      ..clear()
      ..addAll(const [
        Worker(id: 'ATT-001', name: 'John Doe', department: 'Operations'),
        Worker(id: 'ATT-002', name: 'Jane Smith', department: 'Maintenance'),
        Worker(id: 'ATT-003', name: 'Robert Johnson', department: 'Logistics'),
        Worker(id: 'ATT-004', name: 'Priya Nair', department: 'Operations'),
        Worker(id: 'OUT-001', name: 'Karthik R', department: 'Contract', type: 'outside', wage: 800),
        Worker(id: 'OUT-002', name: 'Mani S', department: 'Contract', type: 'outside', wage: 750),
      ]);

    stockPoints
      ..clear()
      ..addAll(const [
        StockPoint(id: 'SP-001', name: 'Site A — North', location: 'North Block', batchId: 'B-042', onHand: 450, todayUsage: 12, reorderLevel: 20, totalIn: 750, totalOut: 300),
        StockPoint(id: 'SP-002', name: 'Site B — South', location: 'South Block', batchId: 'B-039', onHand: 200, todayUsage: 8, reorderLevel: 30, totalIn: 400, totalOut: 200),
        StockPoint(id: 'SP-003', name: 'Warehouse Main', location: 'Central Store', batchId: 'B-031', onHand: 18, todayUsage: 5, reorderLevel: 20, totalIn: 600, totalOut: 582),
        StockPoint(id: 'SP-004', name: 'Field Store', location: 'Field Office', batchId: 'B-044', onHand: 120, todayUsage: 20, reorderLevel: 15, totalIn: 300, totalOut: 180),
      ]);

    stockMovements
      ..clear()
      ..addAll([
        StockMovement(id: 'SM-001', type: 'in', item: 'Diesel', quantity: 80, batch: 'B-042', date: 'Today 9:10 AM', by: 'HOD Approved', stockPointId: 'SP-001'),
        StockMovement(id: 'SM-002', type: 'out', item: 'Diesel', quantity: 12, batch: 'B-042', date: 'Today 11:30 AM', by: 'MCH-001', stockPointId: 'SP-001'),
        StockMovement(id: 'SM-003', type: 'in', item: 'Engine Oil', quantity: 20, batch: 'B-041', date: 'Yesterday', by: 'HOD Approved', stockPointId: 'SP-002'),
        StockMovement(id: 'SM-004', type: 'return', item: 'Bolts & Nuts', quantity: 5, batch: 'B-038', date: '12 May', by: 'RET-0089', stockPointId: 'SP-003'),
        StockMovement(id: 'SM-005', type: 'transfer', item: 'Hydraulic Fluid', quantity: 10, batch: 'B-040', date: '11 May', by: 'SP-001→SP-002'),
      ]);

    transfers
      ..clear()
      ..addAll([
        TransferRecord(id: 'TRF-001', item: 'Diesel', fromPoint: 'Site A — North', toPoint: 'Site B — South', quantity: 50, status: 'completed', date: '12 May 2024', createdAt: DateTime.now().subtract(const Duration(days: 2))),
        TransferRecord(id: 'TRF-002', item: 'Engine Oil', fromPoint: 'Warehouse Main', toPoint: 'Field Store', quantity: 10, status: 'completed', date: '11 May 2024', createdAt: DateTime.now().subtract(const Duration(days: 3))),
      ]);

    rentals
      ..clear()
      ..addAll([
        RentalRecord(id: 'RNT-2024-0034', item: 'Excavator', billingMode: 'Per day', rate: 5000, fuel: 1200, startDate: '2024-05-01', createdAt: DateTime.now().subtract(const Duration(days: 12))),
        RentalRecord(id: 'RNT-2024-0035', item: 'Compressor', billingMode: 'Per day', rate: 3000, fuel: 800, startDate: '2024-05-05', createdAt: DateTime.now().subtract(const Duration(days: 8))),
        RentalRecord(id: 'RNT-2024-0036', item: 'Generator', billingMode: 'Per day', rate: 4000, fuel: 1500, startDate: '2024-05-10', createdAt: DateTime.now().subtract(const Duration(days: 3))),
      ]);

    tasks
      ..clear()
      ..addAll(const [
        AppTask(id: 'TSK-001', title: 'Check diesel levels at Site A', type: 'Daily', done: false, priority: 'high', dueDate: 'Today', assignedBy: 'HOD Sharma', source: 'checklist'),
        AppTask(id: 'TSK-002', title: 'Update machine log for MCH-003', type: 'Daily', done: true, priority: 'normal', dueDate: 'Yesterday', assignedBy: 'HOD Sharma', source: 'checklist'),
        AppTask(id: 'TSK-003', title: 'Verify operator attendance photos', type: 'Daily', done: false, priority: 'high', dueDate: 'Today', assignedBy: 'HOD Patel', source: 'checklist'),
        AppTask(id: 'TSK-004', title: 'Submit weekly stock summary', type: 'Weekly', done: false, priority: 'normal', dueDate: 'This Week', assignedBy: 'HOD Sharma', source: 'checklist'),
        AppTask(id: 'TSK-005', title: 'Calibrate equipment at Site B', type: 'Weekly', done: true, priority: 'high', dueDate: 'This Week', assignedBy: 'HOD Mehta', source: 'checklist'),
        AppTask(id: 'TSK-006', title: 'Review rental records', type: 'Monthly', done: false, priority: 'normal', dueDate: 'End of Month', assignedBy: 'HOD Sharma', source: 'checklist'),
        AppTask(id: 'TSK-007', title: 'Conduct safety inspection', type: 'Weekly', done: false, priority: 'high', dueDate: 'Tomorrow', assignedBy: 'HOD Patel', source: 'checklist'),
        AppTask(id: 'TSK-008', title: 'Update stock register', type: 'Daily', done: false, priority: 'normal', dueDate: 'Today', assignedBy: 'HOD Mehta', source: 'checklist'),
        AppTask(id: 'HT-001', title: 'Complete safety inspection at Site A', type: 'Daily', done: false, priority: 'high', dueDate: 'Today', assignedBy: 'HOD Sharma', source: 'hod', description: 'Inspect all safety equipment and submit report', points: 50),
        AppTask(id: 'HT-002', title: 'Submit weekly fuel consumption report', type: 'Weekly', done: false, priority: 'normal', dueDate: 'This Week', assignedBy: 'HOD Sharma', source: 'hod', description: 'Compile diesel usage data from all machines', points: 30),
        AppTask(id: 'HT-003', title: 'Update machine maintenance log', type: 'Daily', done: true, priority: 'high', dueDate: 'Today', assignedBy: 'HOD Patel', source: 'hod', description: 'Record all maintenance activities for MCH-003', points: 40),
        AppTask(id: 'HT-004', title: 'Monthly stock audit', type: 'Monthly', done: false, priority: 'normal', dueDate: 'End of Month', assignedBy: 'HOD Mehta', source: 'hod', description: 'Verify physical stock with system records', points: 100),
        AppTask(id: 'HT-005', title: 'Site B equipment calibration', type: 'Weekly', done: false, priority: 'high', dueDate: 'Tomorrow', assignedBy: 'HOD Sharma', source: 'hod', description: 'Calibrate all heavy equipment at Site B', points: 75),
        AppTask(id: 'HT-006', title: 'Submit worker attendance summary', type: 'Weekly', done: true, priority: 'normal', dueDate: 'This Week', assignedBy: 'HOD Patel', source: 'hod', description: 'Weekly attendance report for all workers', points: 25),
      ]);

    reports
      ..clear()
      ..addAll([
        ReportRecord(id: 'RPT-001', title: 'Machines Summary', date: DateTime(2024, 5, 13), size: '2.4 MB', type: 'PDF', summary: 'Seed report'),
        ReportRecord(id: 'RPT-002', title: 'Workers Report', date: DateTime(2024, 5, 12), size: '1.8 MB', type: 'PDF', summary: 'Seed report'),
        ReportRecord(id: 'RPT-003', title: 'Diesel Consumption', date: DateTime(2024, 5, 11), size: '1.2 MB', type: 'Excel', summary: 'Seed report'),
        ReportRecord(id: 'RPT-004', title: 'Rental Summary', date: DateTime(2024, 5, 10), size: '892 KB', type: 'PDF', status: 'pending', summary: 'Seed report'),
      ]);

    notifications
      ..clear()
      ..addAll([
        AppNotification(id: 'N-001', title: 'HOD Approval Needed', body: '2 machine entries await HOD review', type: 'warning', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
        AppNotification(id: 'N-002', title: 'Low Stock Alert', body: 'Warehouse Main is below reorder level', type: 'danger', createdAt: DateTime.now().subtract(const Duration(hours: 5))),
        AppNotification(id: 'N-003', title: 'Task Due Today', body: 'Check diesel levels at Site A', type: 'info', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
      ]);

    mapLocations
      ..clear()
      ..addAll(const [
        MapLocation(id: 'LOC-001', title: 'Site A – North', description: 'Main excavation zone', lat: 13.0827, lng: 80.2707, category: 'site'),
        MapLocation(id: 'LOC-002', title: 'Site B – South', description: 'Secondary operations', lat: 13.0500, lng: 80.2500, category: 'site'),
        MapLocation(id: 'LOC-003', title: 'Warehouse Main', description: 'Central store & diesel', lat: 13.1000, lng: 80.2900, category: 'warehouse'),
        MapLocation(id: 'LOC-004', title: 'Field Office', description: 'Supervisor cabin', lat: 13.0700, lng: 80.2600, category: 'office'),
      ]);

    dailyLogs.clear();
    attendance.clear();
    stockOrders.clear();
    stockReturns.clear();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String?> login(String email, String password, {bool remember = false}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    AppUser? user;
    try {
      user = users.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase() && u.password == password,
      );
    } catch (_) {
      return 'Invalid email or password';
    }
    if (!user.approved) return 'Account pending HOD approval';
    currentUser = user.copyWith(rememberMe: remember);
    if (remember) {
      await _setSession(user.email);
    } else {
      await _setSession(null);
    }
    notifyListeners();
    return null;
  }

  Future<String?> createAccount({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already registered';
    }
    final user = AppUser(
      id: _nextId('USR'),
      name: name,
      email: email,
      password: password,
      phone: phone,
      empId: 'EMP-${users.length + 1}'.padLeft(7, '0'),
      joinDate: _fmtDate(DateTime.now()),
      approved: false,
    );
    users.add(user);
    await _addNotification(
      'New Account Request',
      '$name requested supervisor access',
      type: 'info',
    );
    await _persist();
    notifyListeners();
    return null;
  }

  Future<String?> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final exists = users.any((u) => u.email.toLowerCase() == email.toLowerCase());
    if (!exists) return 'No account found for that email';
    await _addNotification(
      'Password Reset',
      'Reset link prepared for $email (demo: use password)',
      type: 'info',
    );
    await _persist();
    return null;
  }

  Future<void> logout() async {
    currentUser = null;
    await _setSession(null);
    notifyListeners();
  }

  Future<void> approvePendingUsers() async {
    for (var i = 0; i < users.length; i++) {
      if (!users[i].approved) {
        users[i] = users[i].copyWith(approved: true);
      }
    }
    await _persist();
    notifyListeners();
  }

  // ── Machines ──────────────────────────────────────────────────────────────

  List<MachineRecord> get approvedMachines =>
      machines.where((m) => m.status == 'approved').toList();

  List<MachineRecord> get pendingMachines =>
      machines.where((m) => m.status == 'pending').toList();

  Future<MachineRecord> submitMachine({
    required String machineId,
    required String operatorName,
    required String vehicleNumber,
    required String vehicleType,
    required String billingType,
    required double workingAmount,
    String paymentMode = 'cash',
    double dieselAmount = 0,
    double usedAmount = 0,
    String? dieselInclusion,
    String supplierName = '',
    double supplierAmount = 0,
    String notes = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final record = MachineRecord(
      id: _nextId('MR'),
      machineId: machineId,
      operatorName: operatorName,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
      billingType: billingType,
      workingAmount: workingAmount,
      paymentMode: paymentMode,
      dieselAmount: dieselAmount,
      usedAmount: usedAmount,
      dieselInclusion: dieselInclusion,
      supplierName: supplierName,
      supplierAmount: supplierAmount,
      notes: notes,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    machines.insert(0, record);
    await _addNotification(
      'Machine Submitted',
      '$machineId ($vehicleType) awaiting HOD approval',
      type: 'warning',
    );
    await _persist();
    notifyListeners();
    return record;
  }

  Future<void> approveMachine(String id) async {
    final idx = machines.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    machines[idx] = machines[idx].copyWith(status: 'approved');
    await _addNotification(
      'Machine Approved',
      '${machines[idx].machineId} is now available for daily logs',
      type: 'success',
    );
    await _persist();
    notifyListeners();
  }

  Future<void> approveAllPendingMachines() async {
    for (var i = 0; i < machines.length; i++) {
      if (machines[i].status == 'pending') {
        machines[i] = machines[i].copyWith(status: 'approved');
      }
    }
    await _persist();
    notifyListeners();
  }

  // ── Daily logs ────────────────────────────────────────────────────────────

  Future<DailyLog> saveDailyLog({
    required String machineId,
    required String machineName,
    required double usedAmount,
    double dieselAmount = 0,
    double betaAmount = 0,
    String notes = '',
    String paymentMode = 'cash',
    List<TimeBlockData> timeBlocks = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final log = DailyLog(
      id: _nextId('DL'),
      machineId: machineId,
      machineName: machineName,
      usedAmount: usedAmount,
      dieselAmount: dieselAmount,
      betaAmount: betaAmount,
      notes: notes,
      paymentMode: paymentMode,
      timeBlocks: timeBlocks,
      createdAt: DateTime.now(),
    );
    dailyLogs.insert(0, log);
    await _addNotification(
      'Daily Log Saved',
      'Log for $machineName recorded',
      type: 'success',
    );
    await _persist();
    notifyListeners();
    return log;
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  List<Worker> get regularWorkers =>
      workers.where((w) => w.type == 'regular' && w.approved).toList();

  List<Worker> get outsideWorkers =>
      workers.where((w) => w.type == 'outside' && w.approved).toList();

  int get presentTodayCount {
    final today = DateTime.now();
    return attendance
        .where((a) =>
            a.date.year == today.year &&
            a.date.month == today.month &&
            a.date.day == today.day &&
            a.status == 'Present')
        .length;
  }

  int get absentTodayCount {
    final today = DateTime.now();
    return attendance
        .where((a) =>
            a.date.year == today.year &&
            a.date.month == today.month &&
            a.date.day == today.day &&
            a.status == 'Absent')
        .length;
  }

  int get halfDayTodayCount {
    final today = DateTime.now();
    return attendance
        .where((a) =>
            a.date.year == today.year &&
            a.date.month == today.month &&
            a.date.day == today.day &&
            a.status == 'Half Day')
        .length;
  }

  int get leaveTodayCount {
    final today = DateTime.now();
    return attendance
        .where((a) =>
            a.date.year == today.year &&
            a.date.month == today.month &&
            a.date.day == today.day &&
            a.status == 'Leave')
        .length;
  }

  Future<AttendanceRecord> markAttendance({
    required String workerId,
    required String status,
    bool morning = false,
    bool evening = false,
    String method = 'Manual',
    bool photoCaptured = false,
  }) async {
    final worker = workers.firstWhere((w) => w.id == workerId);
    final record = AttendanceRecord(
      id: _nextId('AT'),
      workerId: workerId,
      workerName: worker.name,
      workerType: worker.type,
      status: status,
      morning: morning,
      evening: evening,
      method: method,
      date: DateTime.now(),
      photoCaptured: photoCaptured,
    );
    attendance.insert(0, record);
    await _persist();
    notifyListeners();
    return record;
  }

  Future<Worker> createOutsideWorker({
    required String name,
    required double wage,
    String department = 'Contract',
  }) async {
    final worker = Worker(
      id: _nextId('OUT'),
      name: name,
      department: department,
      type: 'outside',
      wage: wage,
      approved: true, // demo: auto-approve so dropdown updates immediately
    );
    workers.add(worker);
    await _addNotification(
      'Outside Worker Added',
      '$name profile created',
      type: 'success',
    );
    await _persist();
    notifyListeners();
    return worker;
  }

  // ── Stock ─────────────────────────────────────────────────────────────────

  Future<StockOrder> raiseStockOrder({
    required String stockPointId,
    required String item,
    required int quantity,
    String unit = 'Units',
    String notes = '',
    bool voiceNote = false,
  }) async {
    final point = stockPoints.firstWhere((p) => p.id == stockPointId);
    final order = StockOrder(
      id: _nextId('ORD'),
      stockPointId: stockPointId,
      stockPointName: point.name,
      item: item,
      quantity: quantity,
      unit: unit,
      notes: notes,
      voiceNote: voiceNote,
      createdAt: DateTime.now(),
    );
    stockOrders.insert(0, order);
    await _addNotification(
      'Stock Order Raised',
      '$item x$quantity for ${point.name}',
      type: 'warning',
    );
    await _persist();
    notifyListeners();
    return order;
  }

  Future<void> approveStockOrder(String id) async {
    final idx = stockOrders.indexWhere((o) => o.id == id);
    if (idx < 0) return;
    final order = stockOrders[idx];
    stockOrders[idx] = order.copyWith(status: 'approved');

    final pIdx = stockPoints.indexWhere((p) => p.id == order.stockPointId);
    if (pIdx >= 0) {
      final p = stockPoints[pIdx];
      stockPoints[pIdx] = p.copyWith(
        onHand: p.onHand + order.quantity,
        totalIn: p.totalIn + order.quantity,
      );
      stockMovements.insert(
        0,
        StockMovement(
          id: _nextId('SM'),
          type: 'in',
          item: order.item,
          quantity: order.quantity,
          batch: p.batchId,
          date: 'Just now',
          by: 'HOD Approved',
          stockPointId: p.id,
        ),
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> approveAllPendingOrders() async {
    final pending = stockOrders.where((o) => o.status == 'pending').map((o) => o.id).toList();
    for (final id in pending) {
      await approveStockOrder(id);
    }
  }

  Future<StockReturn> submitStockReturn({
    required String originalBatchId,
    required String item,
    required int quantity,
    String reason = '',
  }) async {
    final ret = StockReturn(
      id: _nextId('RET'),
      originalBatchId: originalBatchId,
      item: item,
      quantity: quantity,
      reason: reason,
      createdAt: DateTime.now(),
    );
    stockReturns.insert(0, ret);
    await _addNotification(
      'Return Submitted',
      '$item x$quantity return pending approval',
      type: 'info',
    );
    await _persist();
    notifyListeners();
    return ret;
  }

  Future<void> approveStockReturn(String id) async {
    final idx = stockReturns.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final ret = stockReturns[idx];
    stockReturns[idx] = ret.copyWith(status: 'approved');
    // Credit first stock point that matches batch, else first warehouse
    var pIdx = stockPoints.indexWhere((p) => p.batchId == ret.originalBatchId);
    if (pIdx < 0) pIdx = 0;
    if (stockPoints.isNotEmpty) {
      final p = stockPoints[pIdx];
      stockPoints[pIdx] = p.copyWith(
        onHand: p.onHand + ret.quantity,
        totalIn: p.totalIn + ret.quantity,
      );
      stockMovements.insert(
        0,
        StockMovement(
          id: _nextId('SM'),
          type: 'return',
          item: ret.item,
          quantity: ret.quantity,
          batch: ret.originalBatchId,
          date: 'Just now',
          by: ret.id,
          stockPointId: p.id,
        ),
      );
    }
    await _persist();
    notifyListeners();
  }

  // ── Transfers ─────────────────────────────────────────────────────────────

  Future<TransferRecord?> initiateTransfer({
    required String fromPoint,
    required String toPoint,
    required String item,
    required int quantity,
    String notes = '',
  }) async {
    if (fromPoint == toPoint) return null;
    final fromIdx = stockPoints.indexWhere((p) => p.name == fromPoint);
    if (fromIdx < 0) return null;
    final from = stockPoints[fromIdx];
    if (from.remaining < quantity) return null;

    stockPoints[fromIdx] = from.copyWith(
      onHand: from.onHand - quantity,
      totalOut: from.totalOut + quantity,
    );

    final record = TransferRecord(
      id: _nextId('TRF'),
      item: item,
      fromPoint: fromPoint,
      toPoint: toPoint,
      quantity: quantity,
      status: 'pending_ack',
      date: _fmtDate(DateTime.now()),
      notes: notes,
      createdAt: DateTime.now(),
    );
    transfers.insert(0, record);
    stockMovements.insert(
      0,
      StockMovement(
        id: _nextId('SM'),
        type: 'transfer',
        item: item,
        quantity: quantity,
        batch: from.batchId,
        date: 'Just now',
        by: '$fromPoint→$toPoint',
        stockPointId: from.id,
      ),
    );
    await _addNotification(
      'Transfer Initiated',
      '$item x$quantity from $fromPoint to $toPoint',
      type: 'info',
    );
    await _persist();
    notifyListeners();
    return record;
  }

  Future<void> acknowledgeTransfer(String id) async {
    final idx = transfers.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = transfers[idx];
    if (t.status == 'completed') return;

    final toIdx = stockPoints.indexWhere((p) => p.name == t.toPoint);
    if (toIdx >= 0) {
      final to = stockPoints[toIdx];
      stockPoints[toIdx] = to.copyWith(
        onHand: to.onHand + t.quantity,
        totalIn: to.totalIn + t.quantity,
      );
    }
    transfers[idx] = t.copyWith(status: 'completed');
    await _addNotification(
      'Transfer Completed',
      '${t.item} received at ${t.toPoint}',
      type: 'success',
    );
    await _persist();
    notifyListeners();
  }

  // ── Rentals ───────────────────────────────────────────────────────────────

  List<RentalRecord> get activeRentals =>
      rentals.where((r) => r.status == 'active').toList();

  List<RentalRecord> get closedRentals =>
      rentals.where((r) => r.status == 'closed').toList();

  Future<RentalRecord> openRental({
    required String item,
    required String billingMode,
    required double rate,
    double fuel = 0,
    String notes = '',
  }) async {
    final record = RentalRecord(
      id: 'RNT-${DateTime.now().year}-${(34 + rentals.length).toString().padLeft(4, '0')}',
      item: item,
      billingMode: billingMode,
      rate: rate,
      fuel: fuel,
      notes: notes,
      startDate: DateTime.now().toIso8601String().split('T').first,
      createdAt: DateTime.now(),
    );
    rentals.insert(0, record);
    await _addNotification(
      'Rental Opened',
      '${record.id} · $item',
      type: 'success',
    );
    await _persist();
    notifyListeners();
    return record;
  }

  Future<RentalRecord?> closeRental(String rentalId) async {
    final idx = rentals.indexWhere((r) => r.id == rentalId);
    if (idx < 0) return null;
    rentals[idx] = rentals[idx].copyWith(
      status: 'closed',
      endDate: DateTime.now().toIso8601String().split('T').first,
    );
    await _addNotification(
      'Rental Closed',
      '$rentalId closed successfully',
      type: 'info',
    );
    await _persist();
    notifyListeners();
    return rentals[idx];
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  List<AppTask> get checklistTasks =>
      tasks.where((t) => t.source == 'checklist').toList();

  List<AppTask> get hodTasks => tasks.where((t) => t.source == 'hod').toList();

  Future<void> toggleTask(String id) async {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(done: !tasks[idx].done);
    await _persist();
    notifyListeners();
  }

  int get pendingTaskCount => tasks.where((t) => !t.done).length;
  int get completedTaskCount => tasks.where((t) => t.done).length;

  int get hodPoints =>
      hodTasks.where((t) => t.done).fold(0, (sum, t) => sum + t.points);

  // ── Reports ───────────────────────────────────────────────────────────────

  Future<ReportRecord> generateReport({
    required String title,
    required String format,
    required String period,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final summary = _buildReportSummary(title);
    final report = ReportRecord(
      id: _nextId('RPT'),
      title: title,
      date: DateTime.now(),
      size: '${150 + DateTime.now().millisecond % 500} KB',
      type: format,
      period: period,
      summary: summary,
      status: 'completed',
    );
    reports.insert(0, report);
    await _addNotification(
      'Report Generated',
      '$title ($format)',
      type: 'success',
    );
    await _persist();
    notifyListeners();
    return report;
  }

  String _buildReportSummary(String title) {
    switch (title) {
      case 'Machines Summary':
        return 'Machines: ${machines.length} · Approved: ${approvedMachines.length} · Daily logs: ${dailyLogs.length}';
      case 'Workers':
        return 'Workers: ${workers.length} · Present today: $presentTodayCount · Attendance rows: ${attendance.length}';
      case 'Rental':
        return 'Active rentals: ${activeRentals.length} · Closed: ${closedRentals.length}';
      case 'Diesel':
        final dieselMoves = stockMovements.where((m) => m.item == 'Diesel').length;
        return 'Diesel movements: $dieselMoves · Stock points: ${stockPoints.length}';
      case 'Returns':
        return 'Returns submitted: ${stockReturns.length}';
      case 'Site bikes petrol':
        return 'Bike petrol logs: demo summary from site operations';
      default:
        return 'Generated from live store data';
    }
  }

  // ── Maps ──────────────────────────────────────────────────────────────────

  Future<void> syncMapLocations() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _addNotification(
      'Maps Synced',
      'Latest locations refreshed from HOD',
      type: 'success',
    );
    await _persist();
    notifyListeners();
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  int get unreadNotificationCount =>
      notifications.where((n) => !n.read).length;

  Future<void> _addNotification(String title, String body, {String type = 'info'}) async {
    notifications.insert(
      0,
      AppNotification(
        id: _nextId('N'),
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> markNotificationRead(String id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    notifications[idx] = notifications[idx].copyWith(read: true);
    await _persist();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(read: true);
    }
    await _persist();
    notifyListeners();
  }

  // ── Overview helpers ──────────────────────────────────────────────────────

  double get pendingAmount {
    final machinePending = pendingMachines.fold<double>(0, (s, m) => s + m.workingAmount);
    final rentalActive = activeRentals.fold<double>(0, (s, r) => s + r.rate);
    return machinePending + rentalActive;
  }

  // ── Settings helpers ──────────────────────────────────────────────────────

  Future<void> resetDemoData() async {
    _seed();
    await _persist();
    notifyListeners();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}';

  String _month(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }
}
