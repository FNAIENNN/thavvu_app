import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'food_screen.dart'; // for navigation

// ==================== WORKER MODEL ====================
class Worker {
  final String id;
  final String name;
  final String department;
  String status; // 'active' 'inactive', 'leave', 'closed'

  Worker({
    required this.id,
    required this.name,
    required this.department,
    this.status = 'active',
  });

  Worker copyWith({String? status}) {
    return Worker(
      id: id,
      name: name,
      department: department,
      status: status ?? this.status,
    );
  }
}

// ==================== OUTSIDE WORKER MODEL ====================
class OutsideWorker {
  final String id;
  final String name;
  String wage;
  String sessionType; // 'Morning', 'Afternoon', 'Full Day', 'Others'
  String attendanceStatus; // 'Present', 'Absent', 'Half day', 'Leave'
  String? supplier;
  String? photoEntryPath;
  String? photoExitPath;
  String? geoLocation;
  String? afternoonPhotoPath;
  bool? isAfternoonContinued;
  bool isOnLeave;
  bool foodOptIn; // food preference
  String? halfDayPhotoPath;

  OutsideWorker({
    required this.id,
    required this.name,
    required this.wage,
    required this.sessionType,
    this.attendanceStatus = 'Present',
    this.supplier,
    this.photoEntryPath,
    this.photoExitPath,
    this.geoLocation,
    this.afternoonPhotoPath,
    this.isAfternoonContinued,
    this.isOnLeave = false,
    this.foodOptIn = true,
    this.halfDayPhotoPath,
  });

  OutsideWorker copyWith({
    String? wage,
    String? sessionType,
    String? attendanceStatus,
    String? supplier,
    String? photoEntryPath,
    String? photoExitPath,
    String? geoLocation,
    String? afternoonPhotoPath,
    bool? isAfternoonContinued,
    bool? isOnLeave,
    bool? foodOptIn,
    String? halfDayPhotoPath,
  }) {
    return OutsideWorker(
      id: id,
      name: name,
      wage: wage ?? this.wage,
      sessionType: sessionType ?? this.sessionType,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      supplier: supplier ?? this.supplier,
      photoEntryPath: photoEntryPath ?? this.photoEntryPath,
      photoExitPath: photoExitPath ?? this.photoExitPath,
      geoLocation: geoLocation ?? this.geoLocation,
      afternoonPhotoPath: afternoonPhotoPath ?? this.afternoonPhotoPath,
      isAfternoonContinued: isAfternoonContinued ?? this.isAfternoonContinued,
      isOnLeave: isOnLeave ?? this.isOnLeave,
      foodOptIn: foodOptIn ?? this.foodOptIn,
      halfDayPhotoPath: halfDayPhotoPath ?? this.halfDayPhotoPath,
    );
  }
}

// ==================== BATCH SHIFT STATE ENUM ====================
enum BatchShiftState {
  active,
  pendingContinuation,
  fullDayActive,
  shiftEnded,
  pendingEndShift,
}

// ==================== BATCH MODEL ====================
class WorkerBatch {
  final int batchNumber;
  final String batchId;
  final String supplier;
  String sessionType;
  List<OutsideWorker> workers;
  String? photoPath;
  String? geoLocation;
  final DateTime createdAt;

  BatchShiftState shiftState;
  String? continuationPhotoPath;
  String? endShiftPhotoPath;
  String? endShiftGeoLocation;

  WorkerBatch({
    required this.batchNumber,
    required this.batchId,
    required this.supplier,
    required this.sessionType,
    required this.workers,
    this.photoPath,
    this.geoLocation,
    required this.createdAt,
    this.shiftState = BatchShiftState.active,
    this.continuationPhotoPath,
    this.endShiftPhotoPath,
    this.endShiftGeoLocation,
  });
}

// ==================== MAIN ATTENDANCE SCREEN ====================
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late List<Worker> _workers;
  late List<OutsideWorker> _outsideWorkers;
  List<WorkerBatch> _confirmedBatches = [];
  List<MachineWorkerGroup> _machineWorkerGroups = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _workers = [
      Worker(id: 'ATT-001', name: 'John Doe', department: 'Operations', status: 'active'),
      Worker(id: 'ATT-002', name: 'Jane Smith', department: 'Maintenance', status: 'active'),
      Worker(id: 'ATT-003', name: 'Robert Johnson', department: 'Logistics', status: 'inactive'),
      Worker(id: 'ATT-004', name: 'Maria Garcia', department: 'Quality', status: 'active'),
      Worker(id: 'ATT-005', name: 'David Wilson', department: 'Operations', status: 'leave'),
      Worker(id: 'ATT-006', name: 'Sarah Brown', department: 'Maintenance', status: 'closed'),
    ];

    _outsideWorkers = [
      OutsideWorker(
        id: 'OW-001', name: 'Raju', wage: '500',
        sessionType: 'Full Day', attendanceStatus: 'Present', supplier: 'ABC Suppliers',
      ),
      OutsideWorker(
        id: 'OW-002', name: 'Lakshmi', wage: '450',
        sessionType: 'Morning', attendanceStatus: 'Present', supplier: 'ABC Suppliers',
      ),
      OutsideWorker(
        id: 'OW-003', name: 'Suresh', wage: '550',
        sessionType: 'Afternoon', attendanceStatus: 'Absent', supplier: 'XYZ Contractors',
      ),
    ];

    _machineWorkerGroups = [
      MachineWorkerGroup(machineId: 'MCH-001', machineName: 'Excavator', workerCount: 2),
      MachineWorkerGroup(machineId: 'MCH-002', machineName: 'Loader', workerCount: 1),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateWorkerStatus(String workerId, String newStatus) {
    setState(() {
      final index = _workers.indexWhere((w) => w.id == workerId);
      if (index != -1) _workers[index] = _workers[index].copyWith(status: newStatus);
    });
    _showSnackbar('Worker status updated to $newStatus', AppTheme.success);
  }

  void _updateOutsideWorkerStatus(String workerId, String newStatus) {
    setState(() {
      final index = _outsideWorkers.indexWhere((w) => w.id == workerId);
      if (index != -1) {
        _outsideWorkers[index] = _outsideWorkers[index].copyWith(attendanceStatus: newStatus);
      }
    });
    _showSnackbar('Outside worker status updated to $newStatus', AppTheme.success);
  }

  void _updateOutsideWorkerFoodOptIn(String workerId, bool foodOptIn) {
    setState(() {
      final index = _outsideWorkers.indexWhere((w) => w.id == workerId);
      if (index != -1) {
        _outsideWorkers[index] = _outsideWorkers[index].copyWith(foodOptIn: foodOptIn);
      }
    });
    _showSnackbar(
      foodOptIn ? 'Food included for worker' : 'Food excluded for worker',
      foodOptIn ? AppTheme.success : AppTheme.warning,
    );
  }

  void _addOutsideWorkers(List<OutsideWorker> newWorkers, WorkerBatch batch) {
    setState(() {
      _outsideWorkers.addAll(newWorkers);
      _confirmedBatches.add(batch);
    });
  }

  void _refreshBatches() => setState(() {});

  List<Worker> get _foodEligibleRegularWorkers =>
      _workers.where((w) => w.status == 'active' || w.status == 'inactive').toList();

  List<OutsideWorker> get _foodEligibleOutsideWorkers => _outsideWorkers
      .where((w) => (w.attendanceStatus == 'Present' || w.attendanceStatus == 'Half day') && w.foodOptIn)
      .toList();

  int get _totalFoodCount {
    int count = _foodEligibleRegularWorkers.length;
    count += _foodEligibleOutsideWorkers.length;
    for (var group in _machineWorkerGroups) count += group.workerCount;
    return count;
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _navigateToFoodScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodScreen(
          activeInactiveWorkers: _foodEligibleRegularWorkers
              .map((w) => WorkerFood(id: w.id, name: w.name, status: w.status))
              .toList(),
          machineWorkerGroups: _machineWorkerGroups,
          outsideWorkerCount: _foodEligibleOutsideWorkers.length,
          outsideWorkers: _foodEligibleOutsideWorkers
              .map((w) => OutsideWorkerFood(id: w.id, name: w.name, status: w.attendanceStatus))
              .toList(),
        ),
      ),
    );
  }

  void _submitAllReports() {
    final totalBatches = _confirmedBatches.length;
    final totalWorkers = _confirmedBatches.fold<int>(0, (s, b) => s + b.workers.length);
    final fullDayCount = _confirmedBatches
        .expand((b) => b.workers)
        .where((w) => w.sessionType == 'Full Day' || (w.isAfternoonContinued ?? false))
        .length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: const [
          Icon(Icons.send, color: AppTheme.primary),
          SizedBox(width: 10),
          Text('Submit Reports'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reportRow('Total Batches', '$totalBatches'),
            _reportRow('Total Outside Workers', '$totalWorkers'),
            _reportRow('Full Day Workers', '$fullDayCount'),
            _reportRow('Regular Workers (Food)', '${_foodEligibleRegularWorkers.length}'),
            _reportRow('Total Food Count', '$_totalFoodCount'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Report will be sent to:\n• HOD (Head of Department)\n• Attendance Register\n• Food Canteen',
                style: TextStyle(fontSize: 12, color: AppTheme.info),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showSnackbar(
                '✅ Reports submitted to HOD & Canteen successfully!',
                AppTheme.success,
              );
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Submit Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
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
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Mark Attendance', icon: Icon(Icons.edit_calendar)),
            Tab(text: 'Outside Workers', icon: Icon(Icons.people_outline)),
            Tab(text: 'Workers & Food', icon: Icon(Icons.manage_accounts)),
          ],
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            RegularWorkersTab(
              workers: _workers.where((w) => w.status != 'closed').toList(),
              onWorkerStatusChanged: _updateWorkerStatus,
            ),
            OutsideWorkersTab(
              outsideWorkers: _outsideWorkers,
              confirmedBatches: _confirmedBatches,
              onAddWorkers: _addOutsideWorkers,
              onStatusChanged: _updateOutsideWorkerStatus,
              onFoodOptInChanged: _updateOutsideWorkerFoodOptIn,  // Pass callback
              onBatchesChanged: _refreshBatches,
            ),
            WorkersManagementTab(
              activeWorkers: _workers.where((w) => w.status == 'active').toList(),
              inactiveWorkers: _workers.where((w) => w.status == 'inactive').toList(),
              leaveWorkers: _workers.where((w) => w.status == 'leave').toList(),
              closedWorkers: _workers.where((w) => w.status == 'closed').toList(),
              outsideWorkersPresent: _foodEligibleOutsideWorkers,
              outsideWorkersAbsent: _outsideWorkers
                  .where((w) =>
                      w.attendanceStatus != 'Present' &&
                      w.attendanceStatus != 'Half day')
                  .toList(),
              machineWorkerGroups: _machineWorkerGroups,
              totalFoodCount: _totalFoodCount,
              onStatusChanged: _updateWorkerStatus,
              onOutsideStatusChanged: _updateOutsideWorkerStatus,
              onFoodOptInChanged: _updateOutsideWorkerFoodOptIn,
              onSubmit: _navigateToFoodScreen,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildGlobalSubmitBar(),
    );
  }

  Widget _buildGlobalSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_confirmedBatches.length} Batch(es) • ${_confirmedBatches.fold<int>(0, (s, b) => s + b.workers.length)} Workers',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Food count: $_totalFoodCount meals',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _submitAllReports,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text('Submit to HOD',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('🪪', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attendance Management',
                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text('Mark & Manage Attendance',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Today',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Present', '24', AppTheme.success, Icons.check_circle),
        const SizedBox(width: 12),
        _buildStatCard('Absent', '3', AppTheme.danger, Icons.cancel),
        const SizedBox(width: 12),
        _buildStatCard('Late', '5', AppTheme.warning, Icons.access_time),
        const SizedBox(width: 12),
        _buildStatCard('Leave', '2', AppTheme.info, Icons.beach_access),
      ],
    );
  }

  Widget _buildStatCard(String label, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(count,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ==================== TAB 1: REGULAR WORKERS ====================
class RegularWorkersTab extends StatefulWidget {
  final List<Worker> workers;
  final Function(String, String) onWorkerStatusChanged;

  const RegularWorkersTab({
    super.key,
    required this.workers,
    required this.onWorkerStatusChanged,
  });

  @override
  State<RegularWorkersTab> createState() => _RegularWorkersTabState();
}

class _RegularWorkersTabState extends State<RegularWorkersTab> {
  String _selectedMethod = 'Face Recognition';
  String _selectedStatus = 'Present';
  bool _morningMarked = false;
  bool _eveningMarked = false;
  String? _selectedWorkerId;
  bool _isScanning = false;
  bool _faceRecognized = false;
  String? _recognizedName;
  late Map<String, String> _todayAttendance;

  @override
  void initState() {
    super.initState();
    _todayAttendance = {for (var w in widget.workers) w.id: 'Absent'};
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildStep(1, 'Face Recognition Attendance', _buildFaceRecognitionSection(),
              badge: _buildFaceRecognitionBadge()),
          const SizedBox(height: 16),
          _buildStep(2, 'Today\'s Attendance Status', _buildWorkerList()),
          const SizedBox(height: 16),
          _buildStep(
            3,
            'Session & Method',
            Column(children: [
              _buildSessionSection(),
              const SizedBox(height: 12),
              _buildMethodSection(),
              const SizedBox(height: 12),
              _buildStatusSection(),
            ]),
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.info.withValues(alpha: 0.1), AppTheme.infoBg]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.info_outline, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Attendance',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Use face recognition or select a worker and mark attendance.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceRecognitionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.success.withValues(alpha: 0.1), AppTheme.successBg]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _faceRecognized ? AppTheme.success : AppTheme.border, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_faceRecognized ? Icons.face : Icons.camera_alt,
                        size: 64,
                        color: _faceRecognized ? AppTheme.success : AppTheme.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      _faceRecognized ? 'Face Detected' : 'Position face in frame',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _faceRecognized ? AppTheme.success : AppTheme.textMuted),
                    ),
                  ],
                ),
                if (_isScanning)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.info),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_faceRecognized && _recognizedName != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Recognized: $_recognizedName',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startFaceRecognition,
              icon: Icon(_faceRecognized ? Icons.refresh : Icons.face, size: 20),
              label: Text(_faceRecognized
                  ? 'Scan Again'
                  : (_isScanning ? 'Scanning...' : 'Start Face Recognition')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _faceRecognized ? AppTheme.success : AppTheme.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startFaceRecognition() {
    setState(() {
      _isScanning = true;
      _faceRecognized = false;
      _recognizedName = null;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _faceRecognized = true;
        if (_selectedWorkerId != null) {
          final worker = widget.workers
              .firstWhere((w) => w.id == _selectedWorkerId, orElse: () => widget.workers.first);
          _recognizedName = worker.name;
        } else {
          final first = widget.workers.first;
          _selectedWorkerId = first.id;
          _recognizedName = first.name;
        }
      });
      _showSnackbar('Face recognized successfully!', AppTheme.success);
    });
  }

  Widget _buildFaceRecognitionBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: AppTheme.successBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.2))),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.face, size: 14, color: AppTheme.success),
          SizedBox(width: 6),
          Text('AI-powered face recognition',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWorkerList() {
    if (widget.workers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.danger),
            color: AppTheme.dangerBg),
        child: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.danger),
            SizedBox(width: 8),
            Expanded(child: Text('No workers available for attendance.')),
          ],
        ),
      );
    }
    return Column(
      children: widget.workers.map((worker) {
        final todayStatus = _todayAttendance[worker.id] ?? 'Absent';
        final isPresent = todayStatus == 'Present';
        final isSelected = worker.id == _selectedWorkerId;
        return GestureDetector(
          onTap: () => setState(() => _selectedWorkerId = worker.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPresent
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.danger.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : (isPresent ? AppTheme.success : AppTheme.danger),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(isPresent ? Icons.check_circle : Icons.cancel,
                    color: isPresent ? AppTheme.success : AppTheme.danger, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(worker.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${worker.id} • ${worker.department}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPresent
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : AppTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(isPresent ? 'Present' : 'Absent',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPresent ? AppTheme.success : AppTheme.danger)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionSection() {
    return Row(
      children: [
        Expanded(
            child: _buildSessionCard('Morning', '🌅', _morningMarked,
                () => setState(() => _morningMarked = !_morningMarked), AppTheme.warning)),
        const SizedBox(width: 16),
        Expanded(
            child: _buildSessionCard('Evening', '🌙', _eveningMarked,
                () => setState(() => _eveningMarked = !_eveningMarked), AppTheme.info)),
      ],
    );
  }

  Widget _buildSessionCard(
      String title, String emoji, bool isMarked, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isMarked
              ? LinearGradient(
                  colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)])
              : null,
          color: isMarked ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isMarked ? color : AppTheme.border, width: isMarked ? 1.5 : 0.8),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMarked ? color : AppTheme.textSecondary)),
            if (isMarked) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle, color: color, size: 16)
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSection() {
    final methods = [
      {'label': 'Face Recognition', 'emoji': '👤', 'color': AppTheme.success},
      {'label': 'ID Scan', 'emoji': '📷', 'color': AppTheme.info},
      {'label': 'Manual', 'emoji': '⌨️', 'color': AppTheme.info},
      {'label': 'Manual + Photo', 'emoji': '📝', 'color': AppTheme.warning},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: methods.map((method) {
        final isSelected = _selectedMethod == method['label'];
        final color = method['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedMethod = method['label'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: isSelected ? color : AppTheme.border,
                  width: isSelected ? 1.5 : 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(method['emoji'] as String, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(method['label'] as String,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : AppTheme.textSecondary)),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle, color: color, size: 14)
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusSection() {
    final statuses = [
      {'label': 'Present', 'color': AppTheme.success, 'icon': Icons.check_circle},
      {'label': 'Absent', 'color': AppTheme.danger, 'icon': Icons.cancel},
      {'label': 'Half day', 'color': AppTheme.warning, 'icon': Icons.hourglass_top},
      {'label': 'Leave', 'color': AppTheme.info, 'icon': Icons.beach_access},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: statuses.map((status) {
        final isSelected = _selectedStatus == status['label'];
        final color = status['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = status['label'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: isSelected ? color : AppTheme.border,
                  width: isSelected ? 1.5 : 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status['icon'] as IconData,
                    color: isSelected ? color : AppTheme.textMuted, size: 16),
                const SizedBox(width: 8),
                Text(status['label'] as String,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : AppTheme.textSecondary)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep(int number, String title, Widget content, {Widget? badge}) {
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
                width: 30, height: 30,
                decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text('$number',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          content,
          if (badge != null) badge,
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_selectedWorkerId == null && !_faceRecognized) {
            _showSnackbar('Please select a worker or use face recognition', AppTheme.danger);
            return;
          }
          if (!_morningMarked && !_eveningMarked) {
            _showSnackbar('Please mark at least one session', AppTheme.warning);
            return;
          }
          final workerId = _selectedWorkerId ?? widget.workers.first.id;
          setState(() => _todayAttendance[workerId] = _selectedStatus);
          _showSnackbar('Attendance marked for ${_todayAttendance[workerId]}!', AppTheme.success);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 20),
            SizedBox(width: 10),
            Text('Mark Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ==================== TAB 2: OUTSIDE WORKERS ====================
class OutsideWorkersTab extends StatefulWidget {
  final List<OutsideWorker> outsideWorkers;
  final List<WorkerBatch> confirmedBatches;
  final Function(List<OutsideWorker>, WorkerBatch) onAddWorkers;
  final Function(String, String) onStatusChanged;
  final Function(String, bool) onFoodOptInChanged; // NEW: callback for food toggle
  final VoidCallback onBatchesChanged;

  const OutsideWorkersTab({
    super.key,
    required this.outsideWorkers,
    required this.confirmedBatches,
    required this.onAddWorkers,
    required this.onStatusChanged,
    required this.onFoodOptInChanged,
    required this.onBatchesChanged,
  });

  @override
  State<OutsideWorkersTab> createState() => _OutsideWorkersTabState();
}

class _OutsideWorkersTabState extends State<OutsideWorkersTab> {
  // ---- Supplier ----
  final List<String> _supplierList = [
    'ABC Suppliers', 'XYZ Contractors', 'Global Manpower',
    'Local Labour Services', 'Quick Staffing',
  ];
  String? _selectedSupplier;
  final TextEditingController _customSupplierController = TextEditingController();
  bool _isCustomSupplier = false;

  // ---- Worker count ----
  final TextEditingController _countController = TextEditingController();

  // ---- Session type ----
  String _selectedSessionType = 'Full Day';

  // ---- Per-session wages ----
  final TextEditingController _morningWageController = TextEditingController(text: '300');
  final TextEditingController _afternoonWageController = TextEditingController(text: '300');
  final TextEditingController _fullDayWageController = TextEditingController(text: '500');
  final TextEditingController _othersWageController = TextEditingController(text: '400');

  // ---- Photo / Geo ----
  bool _photoCaptured = false;
  String? _photoPath;
  String? _geoLocation;

  // ---- Pending batch ----
  List<OutsideWorker> _pendingBatchWorkers = [];
  int _nextBatchNumber = 1;

  // ---- Supplier bills ----
  final List<Map<String, dynamic>> _supplierBills = [];

  // ==================== HELPERS ====================
  String _getFinalSupplier() {
    if (_isCustomSupplier) return _customSupplierController.text.trim();
    return _selectedSupplier ?? '';
  }

  double _getWageForSession(String sessionType) {
    switch (sessionType) {
      case 'Morning': return double.tryParse(_morningWageController.text) ?? 0;
      case 'Afternoon': return double.tryParse(_afternoonWageController.text) ?? 0;
      case 'Full Day': return double.tryParse(_fullDayWageController.text) ?? 0;
      default: return double.tryParse(_othersWageController.text) ?? 0;
    }
  }

  TextEditingController _wageControllerForSession(String session) {
    switch (session) {
      case 'Morning': return _morningWageController;
      case 'Afternoon': return _afternoonWageController;
      case 'Full Day': return _fullDayWageController;
      default: return _othersWageController;
    }
  }

  Color _sessionColor(String session) {
    switch (session) {
      case 'Morning': return AppTheme.warning;
      case 'Afternoon': return AppTheme.accent;
      case 'Full Day': return AppTheme.success;
      default: return AppTheme.info;
    }
  }

  String _sessionEmoji(String session) {
    switch (session) {
      case 'Morning': return '🌅';
      case 'Afternoon': return '☀️';
      case 'Full Day': return '🌞';
      default: return '⏱️';
    }
  }

  // ==================== BATCH SHIFT WORKFLOW HELPERS ====================

  bool _batchIsMorningExtendable(WorkerBatch batch) =>
      batch.sessionType == 'Morning' && batch.shiftState == BatchShiftState.active;

  bool _batchIsDirectEndShift(WorkerBatch batch) =>
      (batch.sessionType == 'Full Day' || batch.sessionType == 'Afternoon') &&
      batch.shiftState == BatchShiftState.active;

  void _startBatchExtension(WorkerBatch batch) {
    setState(() {
      batch.shiftState = BatchShiftState.pendingContinuation;
    });
    widget.onBatchesChanged();
    _showSnackbar(
      'Batch #${batch.batchNumber}: Mark workers on leave, then capture photo to continue.',
      AppTheme.info,
    );
  }

  void _cancelBatchExtension(WorkerBatch batch) {
    setState(() {
      batch.shiftState = BatchShiftState.pendingEndShift;
    });
    widget.onBatchesChanged();
    _showSnackbar(
      'Batch #${batch.batchNumber}: Extension cancelled. Mark any leaves then end shift.',
      AppTheme.warning,
    );
  }

  Future<void> _toggleBatchWorkerHalfDay(WorkerBatch batch, int workerIndex, bool isHalfDay) async {
    final worker = batch.workers[workerIndex];
    if (isHalfDay) {
      final photoPath = await _showPhotoCaptureDialog('Capture half-day exit photo for ${worker.name}');
      if (photoPath != null) {
        setState(() {
          batch.workers[workerIndex] = worker.copyWith(
            attendanceStatus: 'Half day',
            isOnLeave: false,
            halfDayPhotoPath: photoPath,
          );
        });
        widget.onBatchesChanged();
        _showSnackbar('${worker.name} marked as Half Day with photo', AppTheme.warning);
      } else {
        _showSnackbar('Photo required for half-day marking', AppTheme.danger);
      }
    } else {
      setState(() {
        batch.workers[workerIndex] = worker.copyWith(
          attendanceStatus: 'Present',
          isOnLeave: false,
          halfDayPhotoPath: null,
        );
      });
      widget.onBatchesChanged();
      _showSnackbar('${worker.name} restored to Full Day', AppTheme.success);
    }
  }

  void _toggleBatchWorkerLeave(WorkerBatch batch, int workerIndex, bool onLeave) {
    setState(() {
      final w = batch.workers[workerIndex];
      batch.workers[workerIndex] = w.copyWith(
        isOnLeave: onLeave,
        attendanceStatus: onLeave ? 'Leave' : 'Present',
      );
    });
    widget.onBatchesChanged();
  }

  void _captureContinuationPhoto(WorkerBatch batch) {
    setState(() {
      batch.continuationPhotoPath =
          'continuation_${batch.batchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
    widget.onBatchesChanged();
    final leaveCount = batch.workers.where((w) => w.isOnLeave).length;
    final continuing = batch.workers.length - leaveCount;
    _showSnackbar(
      'Continuation photo captured. $continuing workers continuing to Full Day.',
      AppTheme.success,
    );
  }

  void _confirmFullDayContinuation(WorkerBatch batch) {
    if (batch.continuationPhotoPath == null) {
      _showSnackbar('Please capture the continuation photo first.', AppTheme.warning);
      return;
    }
    setState(() {
      for (int i = 0; i < batch.workers.length; i++) {
        if (!batch.workers[i].isOnLeave) {
          batch.workers[i] = batch.workers[i].copyWith(
            sessionType: 'Full Day',
            isAfternoonContinued: true,
            attendanceStatus: 'Present',
          );
        }
      }
      batch.sessionType = 'Full Day';
      batch.shiftState = BatchShiftState.fullDayActive;
    });
    widget.onBatchesChanged();
    _showSnackbar(
      '✅ Workers converted to Full Day! Capture end-of-shift photo to close.',
      AppTheme.success,
    );
  }

  void _captureEndShiftPhoto(WorkerBatch batch) {
    setState(() {
      batch.endShiftPhotoPath =
          'endshift_${batch.batchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      batch.endShiftGeoLocation = '12.9716° N, 77.5946° E';
      batch.shiftState = BatchShiftState.shiftEnded;
    });
    widget.onBatchesChanged();
    _showSnackbar(
      '🏁 Shift ended for Batch #${batch.batchNumber}. Ready for submission.',
      AppTheme.success,
    );
  }

  Future<String?> _showPhotoCaptureDialog(String title) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 48, color: AppTheme.primary),
                    SizedBox(height: 8),
                    Text('Tap to capture photo', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg'),
                  icon: const Icon(Icons.camera),
                  label: const Text('Capture'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================
  void _capturePhotoWithGeo() {
    setState(() {
      _photoCaptured = true;
      _photoPath = 'captured_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      _geoLocation = '12.9716° N, 77.5946° E';
    });
    _showSnackbar('Photo captured with geo-tag: $_geoLocation', AppTheme.success);
  }

  void _generatePendingWorkers() {
    final supplier = _getFinalSupplier();
    if (supplier.isEmpty) {
      _showSnackbar('Please select or enter supplier name', AppTheme.danger);
      return;
    }
    final count = int.tryParse(_countController.text.trim());
    if (count == null || count <= 0) {
      _showSnackbar('Enter a valid worker count', AppTheme.danger);
      return;
    }
    final wage = _getWageForSession(_selectedSessionType);
    if (wage <= 0) {
      _showSnackbar('Please enter a valid wage for the selected session', AppTheme.danger);
      return;
    }
    if (!_photoCaptured) {
      _showSnackbar('Please capture a photo with geo-location', AppTheme.warning);
      return;
    }
    setState(() {
      final newWorkers = List.generate(count, (index) {
        return OutsideWorker(
          id: 'OW-${DateTime.now().millisecondsSinceEpoch}-$index',
          name: 'Worker ${_pendingBatchWorkers.length + index + 1}',
          wage: wage.toStringAsFixed(0),
          sessionType: _selectedSessionType,
          attendanceStatus: 'Present',
          supplier: supplier,
          photoEntryPath: _photoPath,
          geoLocation: _geoLocation,
          foodOptIn: true,
        );
      });
      _pendingBatchWorkers = [..._pendingBatchWorkers, ...newWorkers];
    });
    _showSnackbar(
        '$count workers added to pending batch ($_selectedSessionType)', AppTheme.success);
  }

  void _removePendingWorker(int index) {
    setState(() => _pendingBatchWorkers.removeAt(index));
  }

  void _confirmAndAddBatch() {
    if (_pendingBatchWorkers.isEmpty) {
      _showSnackbar('No workers to confirm', AppTheme.danger);
      return;
    }
    final sessionGroups = <String, List<OutsideWorker>>{};
    for (var w in _pendingBatchWorkers) {
      sessionGroups.putIfAbsent(w.sessionType, () => []).add(w);
    }
    final batchesToAdd = <WorkerBatch>[];
    for (final entry in sessionGroups.entries) {
      final initialState = (entry.key == 'Full Day' || entry.key == 'Afternoon')
          ? BatchShiftState.pendingEndShift
          : BatchShiftState.active;

      batchesToAdd.add(WorkerBatch(
        batchNumber: _nextBatchNumber++,
        batchId: 'BATCH-${DateTime.now().millisecondsSinceEpoch}-${entry.key}',
        supplier: _getFinalSupplier().isNotEmpty
            ? _getFinalSupplier()
            : (entry.value.first.supplier ?? 'Unknown'),
        sessionType: entry.key,
        workers: List.from(entry.value),
        photoPath: entry.value.first.photoEntryPath,
        geoLocation: entry.value.first.geoLocation,
        createdAt: DateTime.now(),
        shiftState: initialState,
      ));
    }
    for (final batch in batchesToAdd) {
      widget.onAddWorkers(batch.workers, batch);
    }
    setState(() {
      _pendingBatchWorkers = [];
      _selectedSupplier = null;
      _isCustomSupplier = false;
      _customSupplierController.clear();
      _countController.clear();
      _photoCaptured = false;
      _photoPath = null;
      _geoLocation = null;
    });
    _showSnackbar('${batchesToAdd.length} batch(es) confirmed & added!', AppTheme.success);
  }

  void _openBillUpload() {
    final suppliers = widget.outsideWorkers
        .map((w) => w.supplier ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    suppliers.add('Other...');
    String? selectedBillSupplier = suppliers.isNotEmpty ? suppliers.first : null;
    bool isCustomBillSupplier = false;
    final customBillController = TextEditingController();
    String? tempBillPhotoPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Upload Supplier Bill',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBillSupplier,
                    decoration: InputDecoration(
                      labelText: 'Select Supplier',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: suppliers
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      setSheetState(() {
                        selectedBillSupplier = val;
                        isCustomBillSupplier = val == 'Other...';
                      });
                    },
                  ),
                  if (isCustomBillSupplier) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customBillController,
                      decoration: InputDecoration(
                        labelText: 'Enter supplier name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: tempBillPhotoPath != null
                                    ? AppTheme.success
                                    : AppTheme.border,
                                width: 2),
                          ),
                          alignment: Alignment.center,
                          child: tempBillPhotoPath != null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.check_circle, color: AppTheme.success, size: 40),
                                    SizedBox(height: 8),
                                    Text('Bill uploaded',
                                        style: TextStyle(color: AppTheme.success)),
                                  ],
                                )
                              : const Text('No bill image',
                                  style: TextStyle(color: AppTheme.textMuted)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            tempBillPhotoPath =
                                'bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          });
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Bill'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.info,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final supplier = isCustomBillSupplier
                            ? customBillController.text.trim()
                            : selectedBillSupplier;
                        if (supplier == null || supplier.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(
                              content: Text('Please select or enter supplier'),
                              backgroundColor: AppTheme.danger));
                          return;
                        }
                        if (tempBillPhotoPath == null) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(
                              content: Text('Please upload bill photo'),
                              backgroundColor: AppTheme.warning));
                          return;
                        }
                        setState(() {
                          _supplierBills.add({
                            'supplier': supplier,
                            'photoPath': tempBillPhotoPath,
                          });
                        });
                        Navigator.pop(sheetContext);
                        _showSnackbar('Bill uploaded for $supplier', AppTheme.success);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _customSupplierController.dispose();
    _countController.dispose();
    _morningWageController.dispose();
    _afternoonWageController.dispose();
    _fullDayWageController.dispose();
    _othersWageController.dispose();
    super.dispose();
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupplierSection(),
          const SizedBox(height: 16),
          _buildAllWagesSection(),
          const SizedBox(height: 16),
          _buildPhotoCapture(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generatePendingWorkers,
              icon: const Icon(Icons.engineering),
              label: const Text('Generate Workers for Batch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_pendingBatchWorkers.isNotEmpty) ...[
            _buildPendingBatchPreview(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmAndAddBatch,
                icon: const Icon(Icons.group_add),
                label: const Text('Confirm & Add Batch to List'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (widget.confirmedBatches.isNotEmpty) ...[
            _buildConfirmedBatchesBySession(),
            const SizedBox(height: 24),
          ],
          const Text('All Outside Workers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (widget.outsideWorkers.isEmpty)
            const Text('No outside workers added yet.',
                style: TextStyle(color: AppTheme.textSecondary))
          else
            ...widget.outsideWorkers.map((w) => _buildExistingWorkerTile(w)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Supplier Bills',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _openBillUpload,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Upload Bill'),
              ),
            ],
          ),
          if (_supplierBills.isNotEmpty)
            ..._supplierBills.map((bill) => ListTile(
                  leading: const Icon(Icons.receipt_long, color: AppTheme.primary),
                  title: Text(bill['supplier'] as String),
                  subtitle: const Text('Bill uploaded', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                ))
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('No supplier bills uploaded.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
        ],
      ),
    );
  }

  // ==================== SUPPLIER SECTION ====================
  Widget _buildSupplierSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Supplier & Session Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedSupplier,
            decoration: InputDecoration(
              labelText: 'Supplier / Contractor Name',
              prefixIcon: const Icon(Icons.business),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              ..._supplierList.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              const DropdownMenuItem(value: 'custom', child: Text('Add New Supplier...')),
            ],
            onChanged: (val) {
              setState(() {
                if (val == 'custom') {
                  _isCustomSupplier = true;
                  _selectedSupplier = null;
                } else {
                  _isCustomSupplier = false;
                  _selectedSupplier = val;
                }
              });
            },
          ),
          if (_isCustomSupplier) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customSupplierController,
              decoration: InputDecoration(
                labelText: 'Enter supplier name',
                prefixIcon: const Icon(Icons.edit),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Number of Workers',
              prefixIcon: const Icon(Icons.people),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Session Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _buildSessionRadioGroup(),
        ],
      ),
    );
  }

  Widget _buildSessionRadioGroup() {
    final sessions = ['Morning', 'Afternoon', 'Full Day', 'Others'];
    return Column(
      children: sessions.map((session) {
        final isSelected = _selectedSessionType == session;
        final color = _sessionColor(session);
        return GestureDetector(
          onTap: () => setState(() => _selectedSessionType = session),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isSelected ? color : AppTheme.border,
                  width: isSelected ? 1.8 : 0.8),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isSelected ? color : AppTheme.textMuted, width: 2),
                    color: isSelected ? color : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Text(_sessionEmoji(session), style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(session,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? color : AppTheme.textSecondary)),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Selected',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== ALL WAGES SECTION ====================
  Widget _buildAllWagesSection() {
    final sessions = ['Morning', 'Afternoon', 'Full Day', 'Others'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Daily Wages per Session',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.infoBg, borderRadius: BorderRadius.circular(20)),
                child: const Text('All sessions',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.info)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'Set wages for each shift. The selected session above applies when generating workers.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 16),
          ...sessions.map((session) {
            final isActive = _selectedSessionType == session;
            final color = _sessionColor(session);
            final controller = _wageControllerForSession(session);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.06) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Text(_sessionEmoji(session), style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isActive ? color : AppTheme.textSecondary)),
                        if (isActive)
                          Text('Currently selected',
                              style: TextStyle(fontSize: 10, color: color)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Wage (₹)',
                        prefixIcon: Icon(Icons.currency_rupee,
                            size: 18,
                            color: isActive ? color : AppTheme.textMuted),
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: color, width: 1.5),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ==================== PHOTO CAPTURE ====================
  Widget _buildPhotoCapture() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photo & Geo-location Proof',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _photoCaptured ? AppTheme.success : AppTheme.border,
                        width: 2),
                  ),
                  child: _photoCaptured
                      ? Stack(
                          alignment: Alignment.center,
                          children: const [
                            Icon(Icons.check_circle, color: AppTheme.success, size: 48),
                            Positioned(
                              bottom: 10,
                              child: Text('Photo Captured',
                                  style: TextStyle(fontSize: 12, color: AppTheme.success)),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt, size: 48, color: AppTheme.textMuted),
                            SizedBox(height: 8),
                            Text('Capture workers photo',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _capturePhotoWithGeo,
                      icon: const Icon(Icons.camera, size: 20),
                      label: const Text('Capture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.info,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_geoLocation != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: AppTheme.info),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(_geoLocation!,
                                  style: const TextStyle(fontSize: 10, color: AppTheme.info)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PENDING BATCH PREVIEW ====================
  Widget _buildPendingBatchPreview() {
    final Map<String, List<OutsideWorker>> grouped = {};
    for (var w in _pendingBatchWorkers) {
      grouped.putIfAbsent(w.sessionType, () => []).add(w);
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                const Text('Pending Batch (Not yet confirmed)',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_pendingBatchWorkers.length} workers',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
              ],
            ),
          ),
          ...grouped.entries.map((entry) {
            final session = entry.key;
            final workers = entry.value;
            final color = _sessionColor(session);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: color.withValues(alpha: 0.07),
                  child: Row(
                    children: [
                      Text(_sessionEmoji(session), style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('$session Session',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                      const Spacer(),
                      Text('${workers.length} workers',
                          style: TextStyle(fontSize: 11, color: color)),
                    ],
                  ),
                ),
                ...workers.asMap().entries.map((e) {
                  final globalIndex = _pendingBatchWorkers.indexOf(e.value);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.value.name,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(
                                  '${e.value.id} • ₹${e.value.wage}/day • ${e.value.supplier ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                              session == 'Full Day' ? 'Full Day' : session,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.success)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppTheme.danger, size: 20),
                          onPressed: () => _removePendingWorker(globalIndex),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ==================== CONFIRMED BATCHES ====================
  Widget _buildConfirmedBatchesBySession() {
    final sessions = ['Morning', 'Afternoon', 'Full Day', 'Others'];
    final Map<String, List<WorkerBatch>> batchBySession = {
      for (var s in sessions) s: [],
    };
    for (var batch in widget.confirmedBatches) {
      if (batchBySession.containsKey(batch.sessionType)) {
        batchBySession[batch.sessionType]!.add(batch);
      } else {
        batchBySession['Others']!.add(batch);
      }
    }
    final activeSessions =
        sessions.where((s) => batchBySession[s]!.isNotEmpty).toList();
    if (activeSessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.fact_check, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's Confirmed Batches",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('All sessions grouped below',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${widget.confirmedBatches.length} batches',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...activeSessions.map((session) {
          final batches = batchBySession[session]!;
          final color = _sessionColor(session);
          final totalWorkers = batches.fold<int>(0, (sum, b) => sum + b.workers.length);
          return _buildSessionBatchCard(session, batches, color, totalWorkers);
        }),
      ],
    );
  }

  Widget _buildSessionBatchCard(
      String session, List<WorkerBatch> batches, Color color, int totalWorkers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_sessionEmoji(session), style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$session Session',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                      Text(
                          '${batches.length} batch${batches.length > 1 ? 'es' : ''} • $totalWorkers workers',
                          style: TextStyle(
                              fontSize: 11, color: color.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text('$totalWorkers',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...batches.map((batch) => _buildBatchDetailCard(batch, color)),
        ],
      ),
    );
  }

  // ==================== BATCH DETAIL CARD ====================
  Widget _buildBatchDetailCard(WorkerBatch batch, Color sessionColor) {
    final isPendingContinuation = batch.shiftState == BatchShiftState.pendingContinuation;
    final isFullDayActive = batch.shiftState == BatchShiftState.fullDayActive;
    final isShiftEnded = batch.shiftState == BatchShiftState.shiftEnded;
    final isPendingEndShift = batch.shiftState == BatchShiftState.pendingEndShift;
    final isFullDayBatch = batch.sessionType == 'Full Day';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isShiftEnded
              ? AppTheme.success.withValues(alpha: 0.5)
              : isPendingContinuation
                  ? AppTheme.warning.withValues(alpha: 0.5)
                  : isFullDayActive
                      ? AppTheme.success.withValues(alpha: 0.4)
                      : isPendingEndShift
                          ? AppTheme.warning.withValues(alpha: 0.35)
                          : AppTheme.border,
          width: (isPendingContinuation || isFullDayActive || isShiftEnded || isPendingEndShift)
              ? 1.5
              : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Batch header ----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('Batch #${batch.batchNumber}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(batch.supplier,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _batchStateColor(batch.shiftState).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_batchStateLabel(batch.shiftState),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _batchStateColor(batch.shiftState))),
                ),
              ],
            ),
          ),

          // ---- Worker list ----
          ...batch.workers.asMap().entries.map((entry) {
            final idx = entry.key;
            final worker = entry.value;
            final isHalfDay = worker.attendanceStatus == 'Half day';
            final showHalfDayToggle = isFullDayBatch && (isPendingEndShift || isFullDayActive);
            final showLeaveToggle = !isFullDayBatch && (isPendingContinuation || isPendingEndShift || isFullDayActive);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.4))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: sessionColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${idx + 1}',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: sessionColor)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(worker.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                            '₹${worker.wage}/day'
                            '${worker.isAfternoonContinued == true ? ' • ⏩ Full Day' : ''}'
                            '${worker.attendanceStatus == 'Half day' ? ' • ½ Half Day' : ''}'
                            '${worker.isOnLeave ? ' • 🏖 Leave' : ''}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        if (worker.halfDayPhotoPath != null)
                          const Text('📸 Half-day exit photo taken',
                              style: TextStyle(fontSize: 9, color: AppTheme.warning)),
                      ],
                    ),
                  ),
                  if (showHalfDayToggle)
                    GestureDetector(
                      onTap: () => _toggleBatchWorkerHalfDay(batch, idx, !isHalfDay),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isHalfDay
                              ? AppTheme.warning.withValues(alpha: 0.15)
                              : AppTheme.success.withValues(alpha: 0.12),
                          border: Border.all(
                            color: isHalfDay ? AppTheme.warning : AppTheme.success,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isHalfDay ? Icons.hourglass_top : Icons.check_circle_outline,
                              size: 14,
                              color: isHalfDay ? AppTheme.warning : AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isHalfDay ? 'Half Day' : 'Working',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isHalfDay ? AppTheme.warning : AppTheme.success),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (showLeaveToggle)
                    GestureDetector(
                      onTap: () => _toggleBatchWorkerLeave(batch, idx, !worker.isOnLeave),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: worker.isOnLeave
                              ? AppTheme.info.withValues(alpha: 0.15)
                              : AppTheme.success.withValues(alpha: 0.12),
                          border: Border.all(
                            color: worker.isOnLeave ? AppTheme.info : AppTheme.success,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              worker.isOnLeave
                                  ? Icons.beach_access
                                  : Icons.check_circle_outline,
                              size: 14,
                              color: worker.isOnLeave ? AppTheme.info : AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              worker.isOnLeave ? 'Leave' : 'Working',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: worker.isOnLeave ? AppTheme.info : AppTheme.success),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _attendanceStatusColor(worker.attendanceStatus)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                          _attendanceLabel(
                              worker.sessionType, worker.attendanceStatus),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  _attendanceStatusColor(worker.attendanceStatus))),
                    ),
                ],
              ),
            );
          }),

          // ---- SHIFT WORKFLOW ACTION PANEL ----
          _buildShiftWorkflowPanel(batch),

          // ---- Batch footer ----
          if (batch.geoLocation != null || batch.photoPath != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  if (batch.geoLocation != null) ...[
                    const Icon(Icons.location_on, size: 12, color: AppTheme.info),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(batch.geoLocation!,
                            style: const TextStyle(fontSize: 10, color: AppTheme.info))),
                  ],
                  if (batch.photoPath != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.photo_camera, size: 12, color: AppTheme.info),
                    const SizedBox(width: 4),
                    const Text('Photo recorded',
                        style: TextStyle(fontSize: 10, color: AppTheme.info)),
                  ],
                  if (batch.endShiftGeoLocation != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.flag, size: 12, color: AppTheme.success),
                    const SizedBox(width: 4),
                    const Text('End geo recorded',
                        style: TextStyle(fontSize: 10, color: AppTheme.success)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================== SHIFT WORKFLOW PANEL ====================
  Widget _buildShiftWorkflowPanel(WorkerBatch batch) {
    switch (batch.shiftState) {
      case BatchShiftState.active:
        if (!_batchIsMorningExtendable(batch)) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startBatchExtension(batch),
                  icon: const Icon(Icons.update, size: 18),
                  label: const Text('Extend to Full Day'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _cancelBatchExtension(batch),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );

      case BatchShiftState.pendingContinuation:
        final leaveCount = batch.workers.where((w) => w.isOnLeave).length;
        final continuingCount = batch.workers.length - leaveCount;
        final hasPhoto = batch.continuationPhotoPath != null;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Mark workers on leave above, then capture a group photo to continue.',
                    style: TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(
                children: [
                  _miniStatBadge('$leaveCount on leave', AppTheme.info),
                  const SizedBox(width: 8),
                  _miniStatBadge('$continuingCount continuing', AppTheme.success),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _captureContinuationPhoto(batch),
                icon: Icon(hasPhoto ? Icons.check_circle : Icons.camera_alt, size: 18),
                label: Text(hasPhoto ? '✓ Photo Taken' : 'Capture Continuation Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasPhoto ? AppTheme.success : AppTheme.info,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (hasPhoto) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _confirmFullDayContinuation(batch),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text('Continue — Convert $continuingCount to Full Day'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        );

      case BatchShiftState.fullDayActive:
        final halfDayCount = batch.workers.where((w) => w.attendanceStatus == 'Half day').length;
        final workingCount = batch.workers.length - halfDayCount;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Workers converted to Full Day. Mark half-day workers above, then capture end-of-shift photo to close.',
                    style: TextStyle(fontSize: 12, color: AppTheme.success),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniStatBadge('$halfDayCount half day', AppTheme.warning),
                  const SizedBox(width: 8),
                  _miniStatBadge('$workingCount full day', AppTheme.success),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _captureEndShiftPhoto(batch),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('End Shift — Capture Photo & Geo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );

      case BatchShiftState.pendingEndShift:
        final halfDayCount = batch.workers.where((w) => w.attendanceStatus == 'Half day').length;
        final workingCount = batch.workers.length - halfDayCount;
        final leaveCount = batch.workers.where((w) => w.isOnLeave).length;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.schedule, size: 16, color: AppTheme.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    batch.sessionType == 'Full Day'
                        ? 'Mark half-day workers above, then capture end-of-shift photo + geo to close.'
                        : 'Mark any workers on leave above, then capture end-of-shift photo + geo to close.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (batch.sessionType == 'Full Day') ...[
                    _miniStatBadge('$halfDayCount half day', AppTheme.warning),
                    const SizedBox(width: 8),
                    _miniStatBadge('$workingCount working', AppTheme.success),
                  ] else ...[
                    _miniStatBadge('$leaveCount on leave', AppTheme.info),
                    const SizedBox(width: 8),
                    _miniStatBadge('${batch.workers.length - leaveCount} working', AppTheme.success),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _captureEndShiftPhoto(batch),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('End Shift — Capture Photo & Geo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );

      case BatchShiftState.shiftEnded:
        final halfDayCount = batch.workers.where((w) => w.attendanceStatus == 'Half day').length;
        final workingCount = batch.workers.length - halfDayCount;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.task_alt, color: AppTheme.success, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shift Completed',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success)),
                    Text(
                      batch.sessionType == 'Full Day'
                          ? '$workingCount full day • $halfDayCount half day. Ready for submission.'
                          : '${batch.workers.where((w) => !w.isOnLeave).length} worked • ${batch.workers.where((w) => w.isOnLeave).length} on leave. Ready for submission.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppTheme.success, size: 16),
              ),
            ],
          ),
        );
    }
  }

  Widget _miniStatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Color _batchStateColor(BatchShiftState state) {
    switch (state) {
      case BatchShiftState.active: return AppTheme.info;
      case BatchShiftState.pendingContinuation: return AppTheme.warning;
      case BatchShiftState.fullDayActive: return AppTheme.success;
      case BatchShiftState.shiftEnded: return AppTheme.success;
      case BatchShiftState.pendingEndShift: return AppTheme.warning;
    }
  }

  String _batchStateLabel(BatchShiftState state) {
    switch (state) {
      case BatchShiftState.active: return 'Active';
      case BatchShiftState.pendingContinuation: return 'Pending Continue';
      case BatchShiftState.fullDayActive: return 'Full Day';
      case BatchShiftState.shiftEnded: return '✓ Shift Ended';
      case BatchShiftState.pendingEndShift: return 'End Shift';
    }
  }

  String _attendanceLabel(String session, String status) {
    if (status == 'Present') {
      if (session == 'Full Day') return 'Full Day';
      return session;
    }
    if (status == 'Half day') return 'Half Day';
    return status;
  }

  Color _attendanceStatusColor(String status) {
    switch (status) {
      case 'Present': return AppTheme.success;
      case 'Half day': return AppTheme.warning;
      case 'Absent': return AppTheme.danger;
      default: return AppTheme.info;
    }
  }

  // ==================== EXISTING WORKER TILE ====================
  // UPDATED: Replaced attendance status dropdown with food Yes/No toggle.
  // Attendance status is still shown as a small badge for reference.
  Widget _buildExistingWorkerTile(OutsideWorker worker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(worker.supplier ?? 'No supplier',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                Text(
                    '${worker.id} • ₹${worker.wage}/day • ${worker.sessionType}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                if (worker.isAfternoonContinued ?? false)
                  const Text('⏩ Continued to Full Day',
                      style: TextStyle(fontSize: 9, color: AppTheme.info)),
                // Small badge for attendance status (non-interactive)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _attendanceStatusColor(worker.attendanceStatus).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    worker.attendanceStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _attendanceStatusColor(worker.attendanceStatus),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Food toggle: Yes/No (Green/Red)
          GestureDetector(
            onTap: () => widget.onFoodOptInChanged(worker.id, !worker.foodOptIn),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: worker.foodOptIn ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: worker.foodOptIn ? AppTheme.success : AppTheme.danger,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    worker.foodOptIn ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: worker.foodOptIn ? AppTheme.success : AppTheme.danger,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    worker.foodOptIn ? 'Yes' : 'No',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: worker.foodOptIn ? AppTheme.success : AppTheme.danger,
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

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ==================== TAB 3: WORKERS MANAGEMENT & FOOD ====================
class WorkersManagementTab extends StatefulWidget {
  final List<Worker> activeWorkers;
  final List<Worker> inactiveWorkers;
  final List<Worker> leaveWorkers;
  final List<Worker> closedWorkers;
  final List<OutsideWorker> outsideWorkersPresent;
  final List<OutsideWorker> outsideWorkersAbsent;
  final List<MachineWorkerGroup> machineWorkerGroups;
  final int totalFoodCount;
  final Function(String, String) onStatusChanged;
  final Function(String, String) onOutsideStatusChanged;
  final Function(String, bool) onFoodOptInChanged;
  final VoidCallback onSubmit;

  const WorkersManagementTab({
    super.key,
    required this.activeWorkers,
    required this.inactiveWorkers,
    required this.leaveWorkers,
    required this.closedWorkers,
    required this.outsideWorkersPresent,
    required this.outsideWorkersAbsent,
    required this.machineWorkerGroups,
    required this.totalFoodCount,
    required this.onStatusChanged,
    required this.onOutsideStatusChanged,
    required this.onFoodOptInChanged,
    required this.onSubmit,
  });

  @override
  State<WorkersManagementTab> createState() => _WorkersManagementTabState();
}

class _WorkersManagementTabState extends State<WorkersManagementTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFoodSummaryCard(),
          const SizedBox(height: 20),
          if (widget.activeWorkers.isNotEmpty)
            _buildWorkerCard(
                'Active Workers (Food)', widget.activeWorkers, Icons.check_circle, AppTheme.success),
          if (widget.inactiveWorkers.isNotEmpty)
            _buildWorkerCard('Inactive / Absent Workers (Food)', widget.inactiveWorkers,
                Icons.cancel, AppTheme.warning),
          if (widget.outsideWorkersPresent.isNotEmpty)
            _buildOutsideWorkerCard('Outside Workers Present/Half day (Food)',
                widget.outsideWorkersPresent, Icons.people, AppTheme.primary, true),
          if (widget.machineWorkerGroups.isNotEmpty)
            _buildMachineWorkerCard(widget.machineWorkerGroups),
          if (widget.outsideWorkersAbsent.isNotEmpty)
            _buildOutsideWorkerCard('Outside Workers Absent (No Food)',
                widget.outsideWorkersAbsent, Icons.person_off, AppTheme.danger, false),
          if (widget.leaveWorkers.isNotEmpty)
            _buildWorkerCard('Regular Workers on Leave (No Food)', widget.leaveWorkers,
                Icons.beach_access, AppTheme.info),
          if (widget.closedWorkers.isNotEmpty)
            _buildWorkerCard(
                'Closed Workers (No Food)', widget.closedWorkers, Icons.block, AppTheme.danger),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onSubmit,
              icon: const Icon(Icons.send, size: 20),
              label: const Text('Finalize Food List & Send to Canteen',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant, color: AppTheme.info, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Food Preparation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Total meals to prepare: ${widget.totalFoodCount}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const Text(
                    '(Regular Active/Inactive + Outside Present/Half day + Machine Workers)',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(
      String title, List<Worker> workers, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 10),
                Text(title,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${workers.length}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),
          ...workers.map((w) => _buildWorkerTile(
              w.id, w.name, w.department, w.status, color, widget.onStatusChanged)),
        ],
      ),
    );
  }

  Widget _buildOutsideWorkerCard(
      String title, List<OutsideWorker> workers, IconData icon, Color color, bool showFoodToggle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 10),
                Text(title,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${workers.length}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),
          ...workers.map((w) => _buildOutsideWorkerTile(
              w.id, w.name, w.attendanceStatus, color, widget.onOutsideStatusChanged, showFoodToggle, w.foodOptIn)),
        ],
      ),
    );
  }

  Widget _buildMachineWorkerCard(List<MachineWorkerGroup> groups) {
    const color = AppTheme.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.construction, size: 20, color: color),
                const SizedBox(width: 10),
                const Text('Machine Workers (Food)',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${groups.length} machines',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),
          ...groups.map((g) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.machineName,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('${g.workerCount} workers • ${g.machineId}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Food',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWorkerTile(
      String id, String name, String dept, String status, Color categoryColor,
      Function(String, String) onStatusChanged) {
    final statusOptions = [
      {'value': 'active', 'label': 'Active', 'icon': Icons.check_circle, 'color': AppTheme.success},
      {'value': 'inactive', 'label': 'Inactive/Absent', 'icon': Icons.cancel, 'color': AppTheme.warning},
      {'value': 'leave', 'label': 'On Leave', 'icon': Icons.beach_access, 'color': AppTheme.info},
      {'value': 'closed', 'label': 'Closed', 'icon': Icons.block, 'color': AppTheme.danger},
    ];
    final current = statusOptions.firstWhere((opt) => opt['value'] == status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('$id • $dept',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            initialValue: status,
            onSelected: (value) => onStatusChanged(id, value),
            itemBuilder: (context) => statusOptions
                .map((opt) => PopupMenuItem<String>(
                      value: opt['value'] as String,
                      child: Row(
                        children: [
                          Icon(opt['icon'] as IconData, size: 18, color: opt['color'] as Color),
                          const SizedBox(width: 8),
                          Text(opt['label'] as String),
                        ],
                      ),
                    ))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (current['color'] as Color).withValues(alpha: 0.1),
                border: Border.all(
                    color: (current['color'] as Color).withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(current['icon'] as IconData,
                      size: 16, color: current['color'] as Color),
                  const SizedBox(width: 6),
                  Text(current['label'] as String,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: current['color'] as Color)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutsideWorkerTile(
      String id, String name, String status, Color color,
      Function(String, String) onStatusChanged, bool showFoodToggle, bool foodOptIn) {
    final statusOptions = [
      {'value': 'Present', 'label': 'Present', 'icon': Icons.check_circle, 'color': AppTheme.success},
      {'value': 'Absent', 'label': 'Absent', 'icon': Icons.cancel, 'color': AppTheme.danger},
      {'value': 'Half day', 'label': 'Half Day', 'icon': Icons.hourglass_top, 'color': AppTheme.warning},
      {'value': 'Leave', 'label': 'Leave', 'icon': Icons.beach_access, 'color': AppTheme.info},
    ];
    final current = statusOptions.firstWhere((opt) => opt['value'] == status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(id, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (showFoodToggle)
            GestureDetector(
              onTap: () => widget.onFoodOptInChanged(id, !foodOptIn),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: foodOptIn ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: foodOptIn ? AppTheme.success : AppTheme.danger,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      foodOptIn ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: foodOptIn ? AppTheme.success : AppTheme.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      foodOptIn ? 'Yes' : 'No',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: foodOptIn ? AppTheme.success : AppTheme.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          PopupMenuButton<String>(
            initialValue: status,
            onSelected: (value) => onStatusChanged(id, value),
            itemBuilder: (context) => statusOptions
                .map((opt) => PopupMenuItem<String>(
                      value: opt['value'] as String,
                      child: Row(
                        children: [
                          Icon(opt['icon'] as IconData, size: 18, color: opt['color'] as Color),
                          const SizedBox(width: 8),
                          Text(opt['label'] as String),
                        ],
                      ),
                    ))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (current['color'] as Color).withValues(alpha: 0.1),
                border: Border.all(
                    color: (current['color'] as Color).withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(current['icon'] as IconData,
                      size: 16, color: current['color'] as Color),
                  const SizedBox(width: 6),
                  Text(current['label'] as String,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: current['color'] as Color)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}