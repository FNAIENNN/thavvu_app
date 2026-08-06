// lib/screens/attendance_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'hod_module_review_screen.dart';
import 'food_screen.dart'; // for navigation
import 'face_capture_screen.dart'; // professional face UI
import '../models/machine_worker_group.dart';
import '../models/attendance_models.dart';
import '../models/food_models.dart';
import '../services/attendance_repository.dart';
import '../services/food_repository.dart';
import '../services/attendance_context_service.dart';
import '../services/face_signature_service.dart';
import '../services/photo_upload_service.dart';
import '../services/realtime_service.dart';
import '../services/payment_repository.dart';
import '../widgets/collapsible_tab_scaffold.dart';

// ==================== WORKER MODEL ====================
class Worker {
  final String id;
  final String name;
  final String department;
  String status; // 'active', 'inactive', 'leave', 'closed'
  String? faceSignature; // enrolled dHash signature for face ID

  Worker({
    required this.id,
    required this.name,
    required this.department,
    this.status = 'active',
    this.faceSignature,
  });

  Worker copyWith({String? status, String? faceSignature}) {
    return Worker(
      id: id,
      name: name,
      department: department,
      status: status ?? this.status,
      faceSignature: faceSignature ?? this.faceSignature,
    );
  }
}

// ==================== OUTSIDE WORKER MODEL ====================
class OutsideWorker {
  final String id;
  final String name;
  String wage;
  String sessionType; // Internal grouping label for outside-worker batches.
  String attendanceStatus; // 'Present', 'Absent', 'Half day'
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
    String? id,
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
      id: id ?? this.id,
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
  final bool isHOD;

  const AttendanceScreen({super.key, this.isHOD = false});

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
  List<AttendanceWorkerProfile> _regularAttendanceSnapshot = [];
  List<PermanentWorkerPaymentAccount> _paymentSnapshot = [];
  List<SupplierBillPaymentRequest> _supplierPaymentSnapshot = [];

  // Backend (Supabase) integration
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final FoodRepository _foodRepo = FoodRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  String? _siteId;
  bool _loadingBackend = true;

  // Realtime subscription
  AttendanceRealtimeSubscription? _realtimeSub;
  final RealtimeDebouncer _realtimeDebouncer = RealtimeDebouncer();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _workers = [];
    _outsideWorkers = [];

    _machineWorkerGroups = [
      MachineWorkerGroup(
          machineId: 'MCH-001', machineName: 'Excavator', workerCount: 2),
      MachineWorkerGroup(
          machineId: 'MCH-002', machineName: 'Loader', workerCount: 1),
    ];

    _loadFromBackend();
  }

  /// Load workers, today's attendance and outside batches from Supabase.
  Future<void> _loadFromBackend() async {
    try {
      _siteId = await _contextService.resolveSiteId();
      final workers = await _attendanceRepo.fetchWorkers(siteId: _siteId);
      final batches = await _attendanceRepo.fetchBatches(
        DateTime.now(),
        siteId: _siteId,
      );

      if (!mounted) return;

      setState(() {
        _workers = workers
            .map((w) => Worker(
                  id: w.id,
                  name: w.name,
                  department: w.department ?? '',
                  status: w.status,
                  faceSignature: w.faceSignature,
                ))
            .toList();

        _outsideWorkers = [];
        _confirmedBatches = [];
        for (final batch in batches) {
          final uiBatch = WorkerBatch(
            batchNumber: batch.batchNumber,
            batchId: batch.id ?? '',
            supplier: batch.supplier,
            sessionType: batch.sessionType,
            createdAt: batch.attendanceDate,
            shiftState: _mapShiftState(batch.shiftState),
            photoPath: batch.photoUrl,
            geoLocation: batch.geoLocation,
            continuationPhotoPath: batch.continuationPhotoUrl,
            endShiftPhotoPath: batch.endShiftPhotoUrl,
            endShiftGeoLocation: batch.endShiftGeoLocation,
            workers: batch.workers.map((bw) {
              final worker = OutsideWorker(
                id: bw.id ?? '',
                name: bw.name,
                wage: (bw.wage ?? 0).toStringAsFixed(0),
                sessionType: batch.sessionType,
                attendanceStatus: bw.attendanceStatus,
                supplier: batch.supplier,
                foodOptIn: bw.foodOptIn,
              );
              _outsideWorkers.add(worker);
              return worker;
            }).toList(),
          );
          _confirmedBatches.add(uiBatch);
        }

        _loadingBackend = false;
    });
    } catch (e) {
      // A failed backend load must never leave the screen stuck on the
      // spinner — surface the error and let the user retry.
      debugPrint('Error loading attendance from backend: $e');
      if (!mounted) return;
      setState(() {
        _loadingBackend = false;
      });
      _showSnackbar(
          'Could not load workers from server. Pull to retry.',
          AppTheme.warning);
    }

    // Start realtime subscription (once siteId is resolved)
    _realtimeSub?.cancel();
    _realtimeSub = RealtimeService.subscribeAttendance(
      siteId: _siteId,
      onAnyChange: () {
        _realtimeDebouncer.call(() {
          if (mounted) _loadFromBackend();
        });
      },
    );
  }

  BatchShiftState _mapShiftState(String state) {
    switch (state) {
      case 'pendingContinuation':
        return BatchShiftState.pendingContinuation;
      case 'fullDayActive':
        return BatchShiftState.fullDayActive;
      case 'shiftEnded':
        return BatchShiftState.shiftEnded;
      case 'pendingEndShift':
        return BatchShiftState.pendingEndShift;
      default:
        return BatchShiftState.active;
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateWorkerStatus(String workerId, String newStatus) async {
    setState(() {
      final index = _workers.indexWhere((w) => w.id == workerId);
      if (index != -1)
        _workers[index] = _workers[index].copyWith(status: newStatus);
    });
    // Persist so the leave/active status survives restarts and syncs.
    final ok = await _attendanceRepo.updateWorkerStatus(workerId, newStatus);
    if (!ok) {
      _showSnackbar(
          'Worker status failed to sync. Check connection.', AppTheme.danger);
      return;
    }
    _showSnackbar('Worker status updated to $newStatus', AppTheme.success);
  }

  Future<void> _updateOutsideWorkerStatus(
      String workerId, String newStatus) async {
    setState(() {
      final index = _outsideWorkers.indexWhere((w) => w.id == workerId);
      if (index != -1) {
        _outsideWorkers[index] =
            _outsideWorkers[index].copyWith(attendanceStatus: newStatus);
      }
    });
    final ok =
        await _attendanceRepo.updateBatchWorkerStatus(workerId, newStatus);
    _syncFoodRequests();
    if (!ok) {
      _showSnackbar(
          'Worker status failed to sync. Check connection.', AppTheme.danger);
      return;
    }
    _showSnackbar(
        'Outside worker status updated to $newStatus', AppTheme.success);
  }

  Future<void> _addOutsideWorkers(
      List<OutsideWorker> newWorkers, WorkerBatch batch) async {
    setState(() {
      _outsideWorkers.addAll(newWorkers);
      _confirmedBatches.add(batch);
    });
    try {
      await _persistBatchToBackend(batch);
    } catch (e) {
      debugPrint('_persistBatchToBackend failed: $e');
      _showSnackbar(
          'Batch saved locally, but sync to HOD failed. Check connection.',
          AppTheme.warning);
    }
  }

  void _refreshBatches() => setState(() {});

  Future<void> _syncRegularAttendanceSnapshot(
      List<AttendanceWorkerProfile> snapshot) async {
    if (!mounted) return;
    setState(() {
      _regularAttendanceSnapshot = List<AttendanceWorkerProfile>.from(snapshot);
    });
    try {
      await _persistSnapshotToBackend(snapshot);
    } catch (e) {
      debugPrint('_persistSnapshotToBackend failed: $e');
      _showSnackbar(
          'Attendance saved locally, but sync to HOD failed. Check connection.',
          AppTheme.warning);
    }
  }

  void _syncPaymentSnapshot(List<PermanentWorkerPaymentAccount> snapshot) {
    if (!mounted) return;
    setState(() {
      _paymentSnapshot = List<PermanentWorkerPaymentAccount>.from(snapshot);
    });
  }

  void _syncSupplierPaymentSnapshot(List<SupplierBillPaymentRequest> snapshot) {
    if (!mounted) return;
    setState(() {
      _supplierPaymentSnapshot = List<SupplierBillPaymentRequest>.from(snapshot);
    });
  }

  // ==========================================================
  // BACKEND PERSISTENCE (Supabase)
  // ==========================================================

  /// Persist regular-worker check-ins/check-outs to `attendance_records`.
  /// Idempotent: upserts keyed on (worker_id, attendance_date).
  Future<void> _persistSnapshotToBackend(
      List<AttendanceWorkerProfile> snapshot) async {
    if (_siteId == null) return;

    final now = DateTime.now();
    for (final profile in snapshot) {
      // Persist workers who were actually marked (check-in/check-out)
      // OR explicitly marked on leave (so HOD sees the leave record).
      if (profile.checkInTime == null &&
          profile.checkOutTime == null &&
          profile.attendanceStatus != 'Leave') {
        continue;
      }

      final record = AttendanceRecord(
        siteId: _siteId,
        workerId: profile.id,
        attendanceDate: now,
        status: profile.attendanceStatus == 'Leave' ? 'Leave' : 'Present',
        checkInTime: profile.checkInTime,
        checkOutTime: profile.checkOutTime,
        checkInMethod: _dbMethod(profile.checkInMethod),
        checkOutMethod: _dbMethod(profile.checkOutMethod),
        checkInPhotoUrl: profile.checkInPhotoPath,
        checkOutPhotoUrl: profile.checkOutPhotoPath,
        foodOptIn: true,
      );
      await _attendanceRepo.upsertRecord(record);
    }

    _syncFoodRequests();
  }

  /// Persist a confirmed outside-worker batch and its workers.
  Future<void> _persistBatchToBackend(WorkerBatch batch) async {
    if (_siteId == null) return;

    final outsideBatch = OutsideBatch(
      siteId: _siteId,
      attendanceDate: DateTime.now(),
      batchNumber: batch.batchNumber,
      supplier: batch.supplier,
      sessionType: batch.sessionType,
      shiftState: _shiftStateToDb(batch.shiftState),
      photoUrl: batch.photoPath,
      geoLocation: batch.geoLocation,
      continuationPhotoUrl: batch.continuationPhotoPath,
      endShiftPhotoUrl: batch.endShiftPhotoPath,
      endShiftGeoLocation: batch.endShiftGeoLocation,
      workers: batch.workers
          .map((w) => OutsideBatchWorker(
                name: w.name,
                wage: double.tryParse(w.wage),
                attendanceStatus: w.attendanceStatus,
                foodOptIn: w.foodOptIn,
                supplier: w.supplier,
              ))
          .toList(),
    );

    final created = await _attendanceRepo.createBatch(outsideBatch);
    if (created == null) return;

    // Re-map UI worker ids to real DB batch-worker ids so status updates
    // and food requests reference persistent rows.
    setState(() {
      for (var i = 0; i < batch.workers.length; i++) {
        if (i < created.workers.length) {
          batch.workers[i] = batch.workers[i].copyWith(
            id: created.workers[i].id ?? batch.workers[i].id,
          );
        }
      }
      _confirmedBatches = _confirmedBatches
          .map((b) => b.batchId == batch.batchId
              ? WorkerBatch(
                  batchNumber: b.batchNumber,
                  batchId: created.id ?? b.batchId,
                  supplier: b.supplier,
                  sessionType: b.sessionType,
                  workers: batch.workers,
                  photoPath: b.photoPath,
                  geoLocation: b.geoLocation,
                  createdAt: b.createdAt,
                  shiftState: b.shiftState,
                  continuationPhotoPath: b.continuationPhotoPath,
                  endShiftPhotoPath: b.endShiftPhotoPath,
                  endShiftGeoLocation: b.endShiftGeoLocation,
                )
              : b)
          .toList();
    });

    _syncFoodRequests();
  }

  /// Rebuild `food_requests` for today from the current attendance state.
  /// This is attendance's ONLY food responsibility — who needs food.
  /// The food module reads these rows from Supabase.
  /// Rule: all workers EXCEPT those on Leave get food.
  Future<void> _syncFoodRequests() async {
    if (_siteId == null) return;

    final today = DateTime.now();
    final requests = <FoodRequest>[];

    for (final p in _regularAttendanceSnapshot) {
      // Include Present workers (checked in) AND Absent workers.
      // Exclude only those explicitly on Leave.
      if (p.attendanceStatus != 'Leave') {
        requests.add(FoodRequest(
          siteId: _siteId,
          attendanceDate: today,
          category: 'regular',
          workerId: p.id,
          name: p.name,
          status: 'pending',
        ));
      }
    }

    for (final batch in _confirmedBatches) {
      for (final w in batch.workers) {
        // Outside workers: include if foodOptIn and not Absent (they are still on site)
        // Present + Half day → food. Absent → food if foodOptIn (may have arrived).
        // Only exclude if explicitly marked as Leave (isOnLeave).
        if (w.foodOptIn && !w.isOnLeave) {
          requests.add(FoodRequest(
            siteId: _siteId,
            attendanceDate: today,
            category: 'outside',
            batchWorkerId: w.id.isEmpty ? null : w.id,
            name: w.name,
            status: 'pending',
          ));
        }
      }
    }

    await _foodRepo.syncFoodRequests(today,
        siteId: _siteId!, requests: requests);
  }

  /// Map UI operation labels to DB CHECK constraint values.
  String _dbMethod(String? label) {
    switch (label) {
      case 'Face Recognition':
        return 'face';
      case 'Biometric':
        return 'biometric';
      case 'Manual + Photo':
        return 'manual_photo';
      default:
        return 'manual';
    }
  }

  String _shiftStateToDb(BatchShiftState state) {
    switch (state) {
      case BatchShiftState.pendingContinuation:
        return 'pendingContinuation';
      case BatchShiftState.fullDayActive:
        return 'fullDayActive';
      case BatchShiftState.shiftEnded:
        return 'shiftEnded';
      case BatchShiftState.pendingEndShift:
        return 'pendingEndShift';
      default:
        return 'active';
    }
  }

  void _navigateToFoodScreen() {
    // Attendance no longer builds food lists. The food module reads
    // today's `food_requests` from Supabase, which this screen writes
    // via _syncFoodRequests() whenever attendance is marked.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FoodScreen()),
    );
  }

  /// Create a temporary worker in the backend so their attendance records
  /// and face signature persist. Returns the DB id or null on failure.
  Future<String?> _createWorkerInBackend(AttendanceWorkerProfile profile) async {
    final worker = WorkerProfile(
      id: 'new-${DateTime.now().microsecondsSinceEpoch}',
      siteId: _siteId,
      name: profile.name,
      department: profile.department,
      aadharNumber: profile.aadharNumber,
      faceId: profile.faceId,
      biometricId: profile.biometricId,
      faceSignature: profile.faceSignature,
      status: 'active',
      isTemporary: true,
      referralName: profile.referralName,
    );
    final created = await _attendanceRepo.createWorker(worker);
    return created?.id;
  }

  /// Called after a worker's face signature is enrolled (or re-enrolled)
  /// from the Face panel — updates the in-memory list and persists.
  Future<void> _onFaceEnrolled(String workerId, String signature) async {
    await _attendanceRepo.updateWorkerFaceSignature(workerId, signature);
    if (!mounted) return;
    setState(() {
      final index = _workers.indexWhere((w) => w.id == workerId);
      if (index != -1) {
        _workers[index] = _workers[index].copyWith(faceSignature: signature);
      }
    });
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

  void _submitAllReports() {
    final totalBatches = _confirmedBatches.length;
    final totalWorkers =
        _confirmedBatches.fold<int>(0, (s, b) => s + b.workers.length);

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
            _reportRow('Regular Workers Present',
                '${_regularAttendanceSnapshot.where((w) => w.checkInTime != null).length}'),
            _reportRow('Total Food Count',
                '${_regularAttendanceSnapshot.where((w) => w.checkInTime != null).length + totalWorkers}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Report will be sent to:\n• HOD (Head of Department)\n• Attendance Register\n\nFood list is handled in the Food module.',
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
                'Reports submitted to HOD successfully!',
                AppTheme.success,
              );
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Submit Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHOD) {
      return const HodModuleReviewScreen(
        title: 'HOD Admin: Attendance Review',
        moduleFilter: 'Attendance',
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            buildCollapsibleAppBar(
              title: 'Attendance',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              controller: _tabController,
              tabs: const [
                Tab(text: 'Mark'),
                Tab(text: 'Outside'),
                Tab(text: 'Payments'),
                Tab(text: 'Bills'),
                Tab(text: 'History'),
              ],
            ),
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
          ];
        },
        body: _loadingBackend
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading workers from server...',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              )
            : TabBarView(
          controller: _tabController,
          children: [
            RegularWorkersTab(
              workers: _workers.where((w) => w.status != 'closed').toList(),
              onWorkerStatusChanged: _updateWorkerStatus,
              onAttendanceSnapshotChanged: _syncRegularAttendanceSnapshot,
              onCreateWorker: _createWorkerInBackend,
              onFaceEnrolled: _onFaceEnrolled,
            ),
            OutsideWorkersTab(
              outsideWorkers: _outsideWorkers,
              confirmedBatches: _confirmedBatches,
              siteId: _siteId,
              onAddWorkers: _addOutsideWorkers,
              onStatusChanged: _updateOutsideWorkerStatus,
              onBatchesChanged: _refreshBatches,
            ),
            PaymentsTab(
              permanentWorkers:
                  _workers.where((w) => w.status != 'closed').toList(),
              siteId: _siteId,
              onPaymentSnapshotChanged: _syncPaymentSnapshot,
            ),
            SupplierBillsPaymentTab(
              confirmedBatches: _confirmedBatches,
              outsideWorkers: _outsideWorkers,
              siteId: _siteId,
              onSupplierPaymentSnapshotChanged: _syncSupplierPaymentSnapshot,
            ),
            AttendanceHistoryTab(
              regularWorkers: _workers,
              regularAttendanceSnapshot: _regularAttendanceSnapshot,
              outsideWorkers: _outsideWorkers,
              confirmedBatches: _confirmedBatches,
              machineWorkerGroups: _machineWorkerGroups,
              paymentAccounts: _paymentSnapshot,
              supplierPaymentRequests: _supplierPaymentSnapshot,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildGlobalSubmitBar(),
    );
  }

  // ignore: unused_element
  Widget _buildHODAdminView() {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('HOD Admin: Attendance Review'),
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
              'HOD Attendance Admin Panel',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pending Approvals for Out-of-Geofence, Overtime, and Manual Entries will be reviewed here.',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
                    'Food requests: ${_regularAttendanceSnapshot.where((w) => w.attendanceStatus != 'Leave').length + _confirmedBatches.fold<int>(0, (s, b) => s + b.workers.length)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _navigateToFoodScreen,
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
              label: const Text('Food',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _submitAllReports,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text('Submit to HOD',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
                width: 50,
                height: 50,
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Today',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLiveSummaryRow(),
        ],
      ),
    );
  }

  /// Live summary line computed from actual attendance state.
  /// Replaces the hardcoded 4-card stats row.
  Widget _buildLiveSummaryRow() {
    final presentCount = _regularAttendanceSnapshot
        .where((w) => w.attendanceStatus == 'Present')
        .length;
    final absentCount = _regularAttendanceSnapshot
        .where((w) => w.attendanceStatus == 'Absent')
        .length;
    final outsideTotal = _confirmedBatches.fold<int>(
        0, (sum, b) => sum + b.workers.length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            '$presentCount Present  •  $absentCount Absent  •  $outsideTotal Outside',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            _loadingBackend ? 'Syncing...' : 'Live',
            style: TextStyle(
              fontSize: 11,
              color: _loadingBackend
                  ? Colors.white54
                  : Colors.greenAccent.shade200,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!_loadingBackend) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
} // end _AttendanceScreenState

// ==================== TAB 1: MARK ATTENDANCE CLEAN ARCHITECTURE ====================
enum AttendanceFlowAction {
  checkIn,
  checkOut,
}

enum AttendanceOperation {
  faceRecognition,
  biometric,
  manualPhoto,
}

class AttendanceWorkerProfile {
  final String id;
  final String name;
  final String department;
  String baseStatus; // active / inactive / leave (mutable — leave can be toggled)
  final bool isTemporary;

  String? aadharNumber;
  String? joiningDate;
  String? bankBookPhotoPath;
  String? aadharPhotoPath;
  String? workerPhotoPath;
  String? referralName;
  String? faceId;
  String? biometricId;
  String? faceSignature;
  String? tempId;
  String? matchedPermanentWorkerId;

  String attendanceStatus; // Present / Absent / Leave / Not Marked
  String? checkInMethod;
  String? checkOutMethod;
  String? checkInPhotoPath;
  String? checkOutPhotoPath;
  DateTime? checkInTime;
  DateTime? checkOutTime;

  AttendanceWorkerProfile({
    required this.id,
    required this.name,
    required this.department,
    required this.baseStatus,
    this.isTemporary = false,
    this.aadharNumber,
    this.joiningDate,
    this.bankBookPhotoPath,
    this.aadharPhotoPath,
    this.workerPhotoPath,
    this.referralName,
    this.faceId,
    this.biometricId,
    this.faceSignature,
    this.tempId,
    this.matchedPermanentWorkerId,
    this.attendanceStatus = 'Absent',
    this.checkInMethod,
    this.checkOutMethod,
    this.checkInPhotoPath,
    this.checkOutPhotoPath,
    this.checkInTime,
    this.checkOutTime,
  });

  bool get isCheckedIn => checkInTime != null && attendanceStatus == 'Present';
  bool get isCheckedOut => checkOutTime != null;
  bool get canCheckOut => isCheckedIn && !isCheckedOut;
}

// ==================== TAB 1: REGULAR WORKERS (CHECK-IN / CHECK-OUT) ====================
class RegularWorkersTab extends StatefulWidget {
  final List<Worker> workers;
  final Function(String, String) onWorkerStatusChanged;
  final ValueChanged<List<AttendanceWorkerProfile>>? onAttendanceSnapshotChanged;
  final Future<String?> Function(AttendanceWorkerProfile)? onCreateWorker;
  final Future<void> Function(String workerId, String signature)?
      onFaceEnrolled;

  const RegularWorkersTab({
    super.key,
    required this.workers,
    required this.onWorkerStatusChanged,
    this.onAttendanceSnapshotChanged,
    this.onCreateWorker,
    this.onFaceEnrolled,
  });

  @override
  State<RegularWorkersTab> createState() => _RegularWorkersTabState();
}

class _RegularWorkersTabState extends State<RegularWorkersTab> {
  AttendanceFlowAction? _selectedFlow;
  AttendanceOperation _selectedOperation = AttendanceOperation.faceRecognition;
  bool _isProcessing = false;
  String? _lastAutomationMessage;

  late List<AttendanceWorkerProfile> _attendanceWorkers;

  @override
  void initState() {
    super.initState();
    _attendanceWorkers = widget.workers.asMap().entries.map((entry) {
      final index = entry.key;
      final worker = entry.value;
      return AttendanceWorkerProfile(
        id: worker.id,
        name: worker.name,
        department: worker.department,
        baseStatus: worker.status,
        aadharNumber: '9000000000${(index + 1).toString().padLeft(2, '0')}',
        faceId: _buildIdentitySignature('FACE', worker.name),
        biometricId: _buildIdentitySignature('BIO', worker.name),
        faceSignature: worker.faceSignature,
        attendanceStatus: worker.status == 'leave' ? 'Leave' : 'Absent',
      );
    }).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyAttendanceSnapshotChanged();
    });
  }

  void _notifyAttendanceSnapshotChanged() {
    widget.onAttendanceSnapshotChanged?.call(
      List<AttendanceWorkerProfile>.from(_attendanceWorkers),
    );
  }

  List<AttendanceWorkerProfile> get _temporaryWorkers =>
      _attendanceWorkers.where((worker) => worker.isTemporary).toList();

  List<AttendanceWorkerProfile> get _presentWorkers => _attendanceWorkers
      .where((worker) => worker.attendanceStatus == 'Present')
      .toList();

  List<AttendanceWorkerProfile> get _absentWorkers => _attendanceWorkers
      .where((worker) => worker.attendanceStatus == 'Absent')
      .toList();

  List<AttendanceWorkerProfile> get _leaveWorkers => _attendanceWorkers
      .where((worker) => worker.attendanceStatus == 'Leave')
      .toList();

  List<AttendanceWorkerProfile> get _pendingCheckoutWorkers =>
      _attendanceWorkers.where((worker) => worker.canCheckOut).toList();

  List<AttendanceWorkerProfile> get _checkedOutWorkers =>
      _attendanceWorkers.where((worker) => worker.isCheckedOut).toList();

  String _buildIdentitySignature(String prefix, String value) {
    final cleaned = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$prefix-$cleaned';
  }

  String _operationLabel(AttendanceOperation operation) {
    switch (operation) {
      case AttendanceOperation.faceRecognition:
        return 'Face Recognition';
      case AttendanceOperation.biometric:
        return 'Biometric';
      case AttendanceOperation.manualPhoto:
        return 'Manual + Photo';
    }
  }

  IconData _operationIcon(AttendanceOperation operation) {
    switch (operation) {
      case AttendanceOperation.faceRecognition:
        return Icons.face_retouching_natural;
      case AttendanceOperation.biometric:
        return Icons.fingerprint;
      case AttendanceOperation.manualPhoto:
        return Icons.add_a_photo;
    }
  }

  Color _operationColor(AttendanceOperation operation) {
    switch (operation) {
      case AttendanceOperation.faceRecognition:
        return AppTheme.success;
      case AttendanceOperation.biometric:
        return AppTheme.primary;
      case AttendanceOperation.manualPhoto:
        return AppTheme.warning;
    }
  }

  String _flowTitle(AttendanceFlowAction flow) {
    switch (flow) {
      case AttendanceFlowAction.checkIn:
        return 'Check In';
      case AttendanceFlowAction.checkOut:
        return 'Check Out';
    }
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModuleTopBar(),
          const SizedBox(height: 16),
          _buildCheckInCheckOutSelector(),
          const SizedBox(height: 16),
          if (_selectedFlow == null)
            _buildOpeningState()
          else
            _buildAttendanceWorkspace(),
          const SizedBox(height: 16),
          _buildAttendanceResultSummary(),
        ],
      ),
    );
  }

  Widget _buildModuleTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.edit_calendar, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mark Attendance',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_presentWorkers.length} present • ${_absentWorkers.length} absent • ${_pendingCheckoutWorkers.length} checkout pending',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildTemporaryIdButton(),
        ],
      ),
    );
  }

  Widget _buildTemporaryIdButton() {
    final hasTempWorkers = _temporaryWorkers.isNotEmpty;
    return GestureDetector(
      onTap: hasTempWorkers ? _openTemporaryIdsSheet : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: hasTempWorkers
                  ? AppTheme.warning.withValues(alpha: 0.18)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: hasTempWorkers ? AppTheme.warning : AppTheme.border,
                width: hasTempWorkers ? 1.4 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge_outlined,
                    size: 17,
                    color:
                        hasTempWorkers ? AppTheme.warning : AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Temp ID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        hasTempWorkers ? AppTheme.warning : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (hasTempWorkers)
            Positioned(
              right: -5,
              top: -7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '${_temporaryWorkers.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckInCheckOutSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildFlowButton(
            flow: AttendanceFlowAction.checkIn,
            title: 'Check In',
            subtitle: 'Start morning attendance',
            icon: Icons.login_rounded,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFlowButton(
            flow: AttendanceFlowAction.checkOut,
            title: 'Check Out',
            subtitle: 'Close today shift',
            icon: Icons.logout_rounded,
            color: AppTheme.info,
          ),
        ),
      ],
    );
  }

  Widget _buildFlowButton({
    required AttendanceFlowAction flow,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedFlow == flow;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFlow = flow;
          _selectedOperation = AttendanceOperation.faceRecognition;
          _lastAutomationMessage = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.12) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.6 : 0.8,
          ),
          boxShadow: isSelected ? AppTheme.cardShadow : null,
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpeningState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, color: AppTheme.info, size: 30),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Choose Check In or Check Out to open the required attendance workflow. New workers can be added from the New Entry button below.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.info,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _openNewEntrySheet,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('New Entry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceWorkspace() {
    final flow = _selectedFlow!;
    final isCheckIn = flow == AttendanceFlowAction.checkIn;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                color: isCheckIn ? AppTheme.success : AppTheme.info,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_flowTitle(flow)} Operations',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _openNewEntrySheet,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('New Entry'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isCheckIn
                ? 'Select one method. Face and biometric capture one worker per tap. Manual + Photo marks workers one by one.'
                : 'Morning check-in data is shown below. Workers must check out with the same method used at check-in.',
            style: const TextStyle(
                fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildOperationSelector(),
          const SizedBox(height: 16),
          if (isCheckIn)
            _buildCheckInOperationPanel()
          else
            _buildCheckOutOperationPanel(),
        ],
      ),
    );
  }

  Widget _buildOperationSelector() {
    return Row(
      children: AttendanceOperation.values.map((operation) {
        final isSelected = _selectedOperation == operation;
        final color = _operationColor(operation);

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedOperation = operation;
                _lastAutomationMessage = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: EdgeInsets.only(
                right: operation == AttendanceOperation.manualPhoto ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.12)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : AppTheme.border,
                  width: isSelected ? 1.5 : 0.8,
                ),
              ),
              child: Column(
                children: [
                  Icon(_operationIcon(operation),
                      size: 23, color: isSelected ? color : AppTheme.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    _operationLabel(operation),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCheckInOperationPanel() {
    if (_selectedOperation == AttendanceOperation.manualPhoto) {
      return _buildManualPhotoWorkerList(isCheckout: false);
    }
    return _buildAutomaticScanPanel(isCheckout: false);
  }

  Widget _buildCheckOutOperationPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMorningDataCard(),
        const SizedBox(height: 14),
        if (_selectedOperation == AttendanceOperation.manualPhoto)
          _buildManualPhotoWorkerList(isCheckout: true)
        else
          _buildAutomaticScanPanel(isCheckout: true),
      ],
    );
  }

  Widget _buildAutomaticScanPanel({required bool isCheckout}) {
    final operation = _selectedOperation;
    final color = _operationColor(operation);
    final label = _operationLabel(operation);
    final pendingForCheckout = _pendingCheckoutWorkers
        .where((worker) => worker.checkInMethod == label)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            height: 142,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_operationIcon(operation), color: color, size: 52),
                    const SizedBox(height: 10),
                    Text(
                      isCheckout
                          ? '$label checkout verification'
                          : '$label attendance verification',
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCheckout
                          ? '${pendingForCheckout.length} worker(s) waiting for this method'
                          : 'System will match one worker identity per tap',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                if (_isProcessing)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_lastAutomationMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.successBg,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.success.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lastAutomationMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () {
                      if (operation == AttendanceOperation.faceRecognition) {
                        // Real face capture & match with professional UI.
                        _faceCheckInWithPhoto(isCheckout: isCheckout);
                      } else if (isCheckout) {
                        _runAutomaticCheckOut();
                      } else {
                        _runAutomaticCheckIn();
                      }
                    },
              icon: Icon(_operationIcon(operation), size: 20),
              label: Text(
                _isProcessing
                    ? 'Processing...'
                    : isCheckout
                        ? 'Start $label Check Out'
                        : 'Start $label Check In',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          if (operation == AttendanceOperation.faceRecognition) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _faceCheckInWithPhoto(isCheckout: isCheckout),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: Text(
                  isCheckout
                      ? 'Capture Selfie & Match Check Out'
                      : 'Capture Selfie & Match Check In',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  side: const BorderSide(color: AppTheme.success),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _openFaceEnrollment,
                icon: const Icon(Icons.face_retouching_natural, size: 18),
                label: const Text('Enroll Face Signature'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualPhotoWorkerList({required bool isCheckout}) {
    final selectedMethodLabel = _operationLabel(_selectedOperation);
    final workers = isCheckout
        ? _pendingCheckoutWorkers
            .where((worker) => worker.checkInMethod == selectedMethodLabel)
            .toList()
        : _attendanceWorkers;

    if (workers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.infoBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: AppTheme.info),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No workers available for this action.',
                style: TextStyle(fontSize: 12, color: AppTheme.info),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCheckout
              ? 'Tap a worker to capture checkout photo'
              : 'Tap a worker name to capture photo and mark present',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...workers.map((worker) {
          final isPresent = worker.attendanceStatus == 'Present';
          final isLeave = worker.attendanceStatus == 'Leave';
          final isDone = isCheckout ? worker.isCheckedOut : isPresent;
          final statusColor = isLeave
              ? AppTheme.info
              : isPresent
                  ? AppTheme.success
                  : AppTheme.danger;

          return GestureDetector(
            onTap: isCheckout && worker.isCheckedOut
                ? () => _editManualCheckoutTime(worker)
                : () => _captureManualPhotoForWorker(worker,
                    isCheckout: isCheckout),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isDone
                    ? AppTheme.success.withValues(alpha: 0.07)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isDone
                      ? AppTheme.success.withValues(alpha: 0.5)
                      : AppTheme.border,
                  width: isDone ? 1.2 : 0.8,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Icon(
                      worker.isTemporary
                          ? Icons.badge_outlined
                          : isCheckout
                              ? Icons.logout_rounded
                              : Icons.person,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                worker.name,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (worker.isTemporary) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.warning.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  worker.tempId ?? 'TEMP',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isCheckout
                              ? 'Check-in: ${worker.checkInMethod ?? '--'} • ${_formatTime(worker.checkInTime)}${worker.checkOutTime != null ? '  •  Checkout: ${_formatTime(worker.checkOutTime)}' : ''}'
                              : '${worker.id} • ${worker.department}${worker.checkInTime != null ? '  •  In: ${_formatTime(worker.checkInTime)}' : ''}',
                          style: const TextStyle(
                              fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isCheckout) ...[
                    _buildLeaveToggle(worker),
                    const SizedBox(width: 8),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle
                            : isCheckout
                                ? Icons.camera_alt
                                : Icons.add_a_photo,
                        color: isDone ? AppTheme.success : AppTheme.warning,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCheckout
                            ? (worker.isCheckedOut ? 'Edit time' : 'Capture')
                            : worker.attendanceStatus,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isCheckout
                              ? (worker.isCheckedOut
                                  ? AppTheme.success
                                  : AppTheme.warning)
                              : statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMorningDataCard() {
    final rows = _presentWorkers;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AppTheme.info, size: 20),
              SizedBox(width: 8),
              Text(
                'Morning Check-in Data',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'No morning check-in data available yet.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            )
          else
            ...rows.map((worker) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          worker.name,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '${worker.checkInMethod ?? '--'} • ${_formatTime(worker.checkInTime)}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildAttendanceResultSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today Attendance Result',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat('Present', _presentWorkers.length, AppTheme.success),
              const SizedBox(width: 8),
              _buildMiniStat('Absent', _absentWorkers.length, AppTheme.danger),
              const SizedBox(width: 8),
              _buildMiniStat('Leave', _leaveWorkers.length, AppTheme.info),
              const SizedBox(width: 8),
              _buildMiniStat('Out', _checkedOutWorkers.length, AppTheme.warning),
            ],
          ),
          const SizedBox(height: 16),
          _buildAttendanceTimeRegister(),
          const SizedBox(height: 16),
          _buildWorkerSummaryGroup('Checked In Workers', _presentWorkers, AppTheme.success),
          const SizedBox(height: 10),
          _buildWorkerSummaryGroup('Checked Out Workers', _checkedOutWorkers, AppTheme.warning),
          const SizedBox(height: 10),
          _buildWorkerSummaryGroup('Absent Workers', _absentWorkers, AppTheme.danger),
          if (_temporaryWorkers.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildWorkerSummaryGroup('Temporary ID Workers', _temporaryWorkers, AppTheme.warning),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceTimeRegister() {
    final rows = _attendanceWorkers
        .where((worker) => worker.checkInTime != null || worker.checkOutTime != null)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: AppTheme.info, size: 18),
              SizedBox(width: 8),
              Text('Checked In / Checked Out Time Register',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'No check-in or checkout time recorded yet.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            )
          else
            ...rows.map((worker) {
              final canEditCheckout = worker.isCheckedOut &&
                  worker.checkOutMethod == _operationLabel(AttendanceOperation.manualPhoto);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: (worker.isCheckedOut ? AppTheme.warning : AppTheme.success)
                          .withValues(alpha: 0.12),
                      child: Icon(
                        worker.isCheckedOut ? Icons.logout_rounded : Icons.login_rounded,
                        size: 16,
                        color: worker.isCheckedOut ? AppTheme.warning : AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(worker.name,
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            'In: ${_formatTime(worker.checkInTime)} (${worker.checkInMethod ?? '--'})  •  Out: ${_formatTime(worker.checkOutTime)} (${worker.checkOutMethod ?? '--'})',
                            style: const TextStyle(
                                fontSize: 10.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (canEditCheckout)
                      TextButton.icon(
                        onPressed: () => _editManualCheckoutTime(worker),
                        icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerSummaryGroup(
    String title,
    List<AttendanceWorkerProfile> workers,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 8),
          if (workers.isEmpty)
            const Text(
              'No workers',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: workers.map((worker) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        worker.isTemporary
                            ? Icons.badge_outlined
                            : Icons.person,
                        color: color,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _workerTimelineLabel(worker),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _workerTimelineLabel(AttendanceWorkerProfile worker) {
    final base = worker.isTemporary ? '${worker.name} (${worker.tempId})' : worker.name;
    final checkIn = worker.checkInTime != null ? ' • In ${_formatTime(worker.checkInTime)}' : '';
    final checkOut = worker.checkOutTime != null ? ' • Out ${_formatTime(worker.checkOutTime)}' : '';
    return '$base$checkIn$checkOut';
  }

  Future<void> _runAutomaticCheckIn() async {
    if (_isProcessing) return;
    final operation = _selectedOperation;
    final method = _operationLabel(operation);
    final worker = _nextAutomaticCheckInWorker(operation);

    if (worker == null) {
      _showSnackbar('No pending worker found for $method', AppTheme.warning);
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastAutomationMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;

    setState(() {
      worker.attendanceStatus = 'Present';
      worker.checkInMethod = method;
      worker.checkInTime = DateTime.now();
      _isProcessing = false;
      _lastAutomationMessage = '$method captured for ${worker.name}.';
    });

    widget.onWorkerStatusChanged(worker.id, 'active');
    _notifyAttendanceSnapshotChanged();
    _showSnackbar(
        '${worker.name} marked present using $method', AppTheme.success);
  }

  Future<void> _runAutomaticCheckOut() async {
    if (_isProcessing) return;
    final operation = _selectedOperation;
    final method = _operationLabel(operation);
    final worker = _nextAutomaticCheckOutWorker(method);

    if (worker == null) {
      _showSnackbar(
          'No pending checkout workers for $method', AppTheme.warning);
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastAutomationMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    setState(() {
      worker.checkOutMethod = method;
      worker.checkOutTime = DateTime.now();
      _isProcessing = false;
      _lastAutomationMessage = '${worker.name} checked out using $method.';
    });

    _notifyAttendanceSnapshotChanged();
    _showSnackbar('${worker.name} checked out using $method', AppTheme.success);
  }

  AttendanceWorkerProfile? _nextAutomaticCheckInWorker(
      AttendanceOperation operation) {
    for (final worker in _attendanceWorkers) {
      final alreadyCheckedIn =
          worker.attendanceStatus == 'Present' && worker.checkInTime != null;
      final hasIdentity = operation == AttendanceOperation.faceRecognition
          ? worker.faceId != null
          : worker.biometricId != null;

      if (worker.baseStatus == 'leave' || alreadyCheckedIn || !hasIdentity) {
        continue;
      }

      if (worker.baseStatus == 'active' || worker.isTemporary) {
        return worker;
      }
    }
    return null;
  }

  AttendanceWorkerProfile? _nextAutomaticCheckOutWorker(String method) {
    for (final worker in _pendingCheckoutWorkers) {
      if (worker.checkInMethod == method) return worker;
    }
    return null;
  }

  /// Toggle a worker between working and on-leave.
  /// Persists the worker status + attendance record, and food requests
  /// automatically exclude workers on leave (food sync rule).
  void _toggleWorkerLeave(AttendanceWorkerProfile worker) {
    final isLeave = worker.attendanceStatus == 'Leave';
    setState(() {
      worker.baseStatus = isLeave ? 'active' : 'leave';
      worker.attendanceStatus = isLeave ? 'Absent' : 'Leave';
      if (isLeave) {
        // Restoring to work clears any leave-only timestamps.
        worker.checkInTime = null;
        worker.checkOutTime = null;
      }
    });
    widget.onWorkerStatusChanged(worker.id, isLeave ? 'active' : 'leave');
    _notifyAttendanceSnapshotChanged();
    _showSnackbar(
      isLeave
          ? '${worker.name} restored to work'
          : '${worker.name} marked on leave',
      isLeave ? AppTheme.success : AppTheme.info,
    );
  }

  /// Compact leave toggle chip used on worker rows (check-in flow only).
  Widget _buildLeaveToggle(AttendanceWorkerProfile worker) {
    final isLeave = worker.attendanceStatus == 'Leave';
    return GestureDetector(
      onTap: () => _toggleWorkerLeave(worker),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLeave
              ? AppTheme.info.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLeave ? AppTheme.info : AppTheme.border,
            width: isLeave ? 1.3 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLeave ? Icons.beach_access : Icons.beach_access_outlined,
              size: 14,
              color: isLeave ? AppTheme.info : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              isLeave ? 'On Leave' : 'Leave',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isLeave ? AppTheme.info : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _captureManualPhotoForWorker(
    AttendanceWorkerProfile worker, {
    required bool isCheckout,
  }) async {
    final bytes = await _showPhotoCaptureDialog(
      isCheckout
          ? 'Capture checkout photo for ${worker.name}'
          : 'Capture attendance photo for ${worker.name}',
    );

    if (bytes == null) return;

    // Upload the photo as proof.
    final uploadPath = await _uploadManualPhoto(worker, bytes,
        isCheckout: isCheckout);

    DateTime? selectedCheckoutTime;
    if (isCheckout) {
      selectedCheckoutTime = await _showManualCheckoutTimeEntryDialog(
        worker,
        initialTime: DateTime.now(),
        title: 'Manual Checkout Time Entry',
      );
      if (selectedCheckoutTime == null) return;

    }

    setState(() {
      if (isCheckout) {
        worker.checkOutPhotoPath = uploadPath;
        worker.checkOutMethod = _operationLabel(AttendanceOperation.manualPhoto);
        worker.checkOutTime = selectedCheckoutTime ?? DateTime.now();
      } else {
        worker.attendanceStatus = 'Present';
        worker.checkInMethod = _operationLabel(AttendanceOperation.manualPhoto);
        worker.checkInPhotoPath = uploadPath;
        worker.checkInTime = DateTime.now();
        if (!worker.isTemporary) {
          widget.onWorkerStatusChanged(worker.id, 'active');
        }
      }
    });

    _notifyAttendanceSnapshotChanged();
    _showSnackbar(
      isCheckout
          ? '${worker.name} checked out with manual time ${_formatTime(worker.checkOutTime)}'
          : '${worker.name} marked present with photo',
      AppTheme.success,
    );
  }

  Future<void> _editManualCheckoutTime(AttendanceWorkerProfile worker) async {
    final selected = await _showManualCheckoutTimeEntryDialog(
      worker,
      initialTime: worker.checkOutTime ?? DateTime.now(),
      title: 'Edit Manual Checkout Time',
    );
    if (selected == null) return;
    setState(() {
      worker.checkOutTime = selected;
      worker.checkOutMethod = _operationLabel(AttendanceOperation.manualPhoto);
    });
    _notifyAttendanceSnapshotChanged();
    _showSnackbar(
      'Checkout time updated for ${worker.name}: ${_formatTime(worker.checkOutTime)}',
      AppTheme.success,
    );
  }

  Future<DateTime?> _showManualCheckoutTimeEntryDialog(
    AttendanceWorkerProfile worker, {
    required DateTime initialTime,
    required String title,
  }) async {
    final pickedDate = worker.checkInTime ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(initialTime);

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final preview = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Checked in: ${_formatTime(worker.checkInTime)} • ${worker.checkInMethod ?? '--'}',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.24)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: AppTheme.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Checkout Time: ${_formatTime(preview)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.warning),
                            ),
                          ),
                          const Icon(Icons.edit_rounded, color: AppTheme.warning, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, preview),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save Time'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // PROFESSIONAL FACE ID: real selfie capture → signature match
  // ==========================================================

  /// Open the professional face-capture screen, match the live selfie
  /// against enrolled worker signatures, confirm with the supervisor,
  /// then mark check-in/check-out with the photo uploaded to Supabase
  /// Storage as proof.
  Future<void> _faceCheckInWithPhoto({required bool isCheckout}) async {
    if (_isProcessing) return;

    final enrolled = <String, String>{};
    final profiles = <String, (String, String)>{};
    for (final w in _attendanceWorkers) {
      final sig = w.faceSignature;
      if (sig != null && sig.isNotEmpty) {
        enrolled[w.id] = sig;
        profiles[w.id] = (w.name, w.department);
      }
    }
    if (enrolled.isEmpty) {
      _showSnackbar(
          'No enrolled faces yet. Enroll workers from the Face panel first.',
          AppTheme.info);
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastAutomationMessage = null;
    });

    final result = await Navigator.push<FaceMatchResult>(
      context,
      MaterialPageRoute(
        builder: (_) => isCheckout
            ? FaceCaptureScreen.checkOut(
                enrolledSignatures: enrolled, workerProfiles: profiles)
            : FaceCaptureScreen.checkIn(
                enrolledSignatures: enrolled, workerProfiles: profiles),
      ),
    );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isProcessing = false);
      return; // user cancelled
    }

    final worker =
        _attendanceWorkers.firstWhere((w) => w.id == result.workerId);
    final alreadyCheckedIn = worker.isCheckedIn;
    if (isCheckout && !alreadyCheckedIn) {
      setState(() => _isProcessing = false);
      _showSnackbar('${worker.name} is not checked in yet.',
          AppTheme.warning);
      return;
    }
    if (!isCheckout && alreadyCheckedIn) {
      setState(() => _isProcessing = false);
      _showSnackbar('${worker.name} is already checked in.',
          AppTheme.warning);
      return;
    }

    // Upload the selfie as proof.
    final uploadPath = await PhotoUploadService().uploadAttendancePhotoBytes(
      worker.id,
      result.imageBytes,
      kind: isCheckout ? 'checkout' : 'checkin',
    );

    if (!mounted) return;
    setState(() {
      if (isCheckout) {
        worker.checkOutPhotoPath = uploadPath;
        worker.checkOutMethod = _operationLabel(AttendanceOperation.faceRecognition);
        worker.checkOutTime = DateTime.now();
      } else {
        worker.attendanceStatus = 'Present';
        worker.checkInMethod = _operationLabel(AttendanceOperation.faceRecognition);
        worker.checkInPhotoPath = uploadPath;
        worker.checkInTime = DateTime.now();
        if (!worker.isTemporary) {
          widget.onWorkerStatusChanged(worker.id, 'active');
        }
      }
      _isProcessing = false;
      _lastAutomationMessage =
          '${worker.name} matched by face (${FaceSignatureService.confidenceLabel(result.distance)}).';
    });

    _notifyAttendanceSnapshotChanged();
    _showSnackbar(
      isCheckout
          ? '${worker.name} checked out by face'
          : '${worker.name} checked in by face',
      AppTheme.success,
    );
  }

  /// Enroll (or re-enroll) a worker's face signature with a live selfie.
  Future<void> _openFaceEnrollment() async {
    final unenrolled = _attendanceWorkers
        .where((w) => w.faceSignature == null || w.faceSignature!.isEmpty)
        .toList();
    final all = _attendanceWorkers;

    final selected = await showModalBottomSheet<AttendanceWorkerProfile>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Enroll Face Signature',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (unenrolled.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'All workers have enrolled faces. Select any worker to re-enroll.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: all.length,
                  itemBuilder: (context, index) {
                    final w = all[index];
                    final hasFace = w.faceSignature != null &&
                        w.faceSignature!.isNotEmpty;
                    return ListTile(
                      leading: Icon(
                        hasFace
                            ? Icons.face_retouching_natural
                            : Icons.face_outlined,
                        color: hasFace ? AppTheme.success : AppTheme.warning,
                      ),
                      title: Text(w.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        hasFace
                            ? 'Enrolled — tap to re-enroll'
                            : 'Not enrolled yet',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(sheetContext, w),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    final result = await Navigator.push<FaceEnrollResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen.enroll(workerName: selected.name),
      ),
    );

    if (result == null || !mounted) return;

    // Persist to DB and update local state.
    if (widget.onFaceEnrolled != null) {
      await widget.onFaceEnrolled!(selected.id, result.signature);
    }
    if (!mounted) return;
    setState(() {
      selected.faceSignature = result.signature;
    });
    _showSnackbar('Face enrolled for ${selected.name}', AppTheme.success);
  }

  AttendanceWorkerProfile? _findMatchingWorker({
    String? aadhar,
    String? faceId,
    String? biometricId,
  }) {
    for (final worker in _attendanceWorkers) {
      final aadharMatched = aadhar != null &&
          aadhar.trim().isNotEmpty &&
          worker.aadharNumber == aadhar.trim();
      final faceMatched =
          faceId != null && faceId.trim().isNotEmpty && worker.faceId == faceId;
      final bioMatched = biometricId != null &&
          biometricId.trim().isNotEmpty &&
          worker.biometricId == biometricId;

      if (aadharMatched || faceMatched || bioMatched) {
        return worker;
      }
    }
    return null;
  }

  void _openNewEntrySheet() {
    final fullNameController = TextEditingController();
    final aadharController = TextEditingController();
    final referralController = TextEditingController();
    DateTime joiningDate = DateTime.now();

    String? bankBookPhotoPath;
    String? aadharPhotoPath;
    String? workerPhotoPath;
    String? faceId;
    String? faceSignature;
    String? facePhotoPath;
    String? biometricId;
    AttendanceWorkerProfile? matchedWorker;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void captureFile(String type) async {
              if (type == 'face') {
                final result = await Navigator.push<FaceEnrollResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FaceCaptureScreen.enroll(
                        workerName: fullNameController.text.trim().isEmpty
                            ? null
                            : fullNameController.text.trim()),
                  ),
                );
                if (result == null) return;
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  faceId = _buildIdentitySignature(
                      'FACE', fullNameController.text.trim());
                  faceSignature = result.signature;
                  facePhotoPath = result.imageBytes.isNotEmpty
                      ? 'face_${DateTime.now().millisecondsSinceEpoch}.jpg'
                      : null;
                  matchedWorker = _findMatchingWorker(
                    aadhar: aadharController.text,
                    faceId: faceId,
                    biometricId: biometricId,
                  );
                });
                return;
              }
              setSheetState(() {
                final now = DateTime.now().millisecondsSinceEpoch;
                switch (type) {
                  case 'bank':
                    bankBookPhotoPath = 'bank_book_$now.jpg';
                    break;
                  case 'aadhar':
                    aadharPhotoPath = 'aadhar_$now.jpg';
                    break;
                  case 'photo':
                    workerPhotoPath = 'worker_photo_$now.jpg';
                    break;
                  case 'bio':
                    biometricId = _buildIdentitySignature(
                        'BIO', fullNameController.text.trim());
                    break;
                }
                matchedWorker = _findMatchingWorker(
                  aadhar: aadharController.text,
                  faceId: faceId,
                  biometricId: biometricId,
                );
              });
            }

            Future<void> saveNewEntry() async {
              final fullName = fullNameController.text.trim();
              final aadhar = aadharController.text.trim();
              final referral = referralController.text.trim();

              if (fullName.isEmpty) {
                _showSheetSnack(
                    sheetContext, 'Please enter full name', AppTheme.danger);
                return;
              }
              if (aadhar.isEmpty) {
                _showSheetSnack(sheetContext, 'Please enter Aadhar number',
                    AppTheme.danger);
                return;
              }
              if (bankBookPhotoPath == null ||
                  aadharPhotoPath == null ||
                  workerPhotoPath == null) {
                _showSheetSnack(
                  sheetContext,
                  'Please capture bank book, Aadhar and worker photo',
                  AppTheme.warning,
                );
                return;
              }
              if (faceId == null || faceSignature == null) {
                _showSheetSnack(
                  sheetContext,
                  'Please capture the Face ID selfie',
                  AppTheme.warning,
                );
                return;
              }
              if (biometricId == null) {
                _showSheetSnack(
                  sheetContext,
                  'Please capture the Biometric ID',
                  AppTheme.warning,
                );
                return;
              }

              final matched = _findMatchingWorker(
                aadhar: aadhar,
                faceId: faceId,
                biometricId: biometricId,
              );

              if (matched != null && !matched.isTemporary) {
                Navigator.pop(sheetContext);
                _showSnackbar(
                  'Matched with previous worker: ${matched.name}. Use existing ID ${matched.id}.',
                  AppTheme.info,
                );
                return;
              }

              final now = DateTime.now().millisecondsSinceEpoch;
              final tempId =
                  'TEMP-${now.toString().substring(now.toString().length - 6)}';

              // Persist the worker to the backend first so attendance
              // records and the face signature survive restarts.
              final profileToCreate = AttendanceWorkerProfile(
                id: 'TMP-$now',
                name: fullName,
                department: 'Temporary Worker',
                baseStatus: 'active',
                isTemporary: true,
                aadharNumber: aadhar,
                joiningDate: _formatDate(joiningDate),
                bankBookPhotoPath: bankBookPhotoPath,
                aadharPhotoPath: aadharPhotoPath,
                workerPhotoPath: workerPhotoPath,
                referralName: referral.isEmpty ? null : referral,
                faceId: faceId,
                faceSignature: faceSignature,
                biometricId: biometricId,
                tempId: tempId,
                attendanceStatus: 'Absent',
              );

              String? createdId;
              if (widget.onCreateWorker != null) {
                createdId = await widget.onCreateWorker!(profileToCreate);
              }

              if (!mounted) return;
              setState(() {
                _attendanceWorkers.add(AttendanceWorkerProfile(
                  id: createdId ?? profileToCreate.id,
                  name: profileToCreate.name,
                  department: profileToCreate.department,
                  baseStatus: profileToCreate.baseStatus,
                  isTemporary: profileToCreate.isTemporary,
                  aadharNumber: profileToCreate.aadharNumber,
                  joiningDate: profileToCreate.joiningDate,
                  bankBookPhotoPath: profileToCreate.bankBookPhotoPath,
                  aadharPhotoPath: profileToCreate.aadharPhotoPath,
                  workerPhotoPath: profileToCreate.workerPhotoPath,
                  referralName: profileToCreate.referralName,
                  faceId: profileToCreate.faceId,
                  faceSignature: profileToCreate.faceSignature,
                  biometricId: profileToCreate.biometricId,
                  tempId: profileToCreate.tempId,
                  attendanceStatus: profileToCreate.attendanceStatus,
                ));
              });

              _notifyAttendanceSnapshotChanged();
              Navigator.pop(sheetContext);
              _showSnackbar(
                createdId != null
                    ? 'New worker added with ID $tempId. Face signature enrolled.'
                    : 'New worker added locally (offline). Re-enroll when online.',
                createdId != null ? AppTheme.success : AppTheme.warning,
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.person_add_alt_1,
                              color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'New Entry',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add a new worker. Aadhar, face and biometric are checked against existing records. If no match is found, a temporary ID is generated.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (_) {
                        setSheetState(() {
                          if (faceId != null) {
                            faceId = _buildIdentitySignature(
                                'FACE', fullNameController.text.trim());
                          }
                          if (biometricId != null) {
                            biometricId = _buildIdentitySignature(
                                'BIO', fullNameController.text.trim());
                          }
                          matchedWorker = _findMatchingWorker(
                            aadhar: aadharController.text,
                            faceId: faceId,
                            biometricId: biometricId,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aadharController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Aadhar Number',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (_) {
                        setSheetState(() {
                          matchedWorker = _findMatchingWorker(
                            aadhar: aadharController.text,
                            faceId: faceId,
                            biometricId: biometricId,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: joiningDate,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setSheetState(() => joiningDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Joining Date',
                          prefixIcon: const Icon(Icons.calendar_month),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(_formatDate(joiningDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referralController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Referral Name',
                        prefixIcon: const Icon(Icons.group),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCaptureMiniButton(
                            label: 'Bank Book',
                            captured: bankBookPhotoPath != null,
                            icon: Icons.account_balance,
                            onTap: () => captureFile('bank'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCaptureMiniButton(
                            label: 'Aadhar',
                            captured: aadharPhotoPath != null,
                            icon: Icons.badge,
                            onTap: () => captureFile('aadhar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCaptureMiniButton(
                            label: 'Photo',
                            captured: workerPhotoPath != null,
                            icon: Icons.camera_alt,
                            onTap: () => captureFile('photo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCaptureMiniButton(
                            label: 'Face ID',
                            captured: faceId != null,
                            icon: Icons.face,
                            onTap: () {
                              if (fullNameController.text.trim().isEmpty) {
                                _showSheetSnack(
                                  sheetContext,
                                  'Enter full name before Face ID capture',
                                  AppTheme.warning,
                                );
                                return;
                              }
                              captureFile('face');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCaptureMiniButton(
                            label: 'Biometric',
                            captured: biometricId != null,
                            icon: Icons.fingerprint,
                            onTap: () {
                              if (fullNameController.text.trim().isEmpty) {
                                _showSheetSnack(
                                  sheetContext,
                                  'Enter full name before biometric capture',
                                  AppTheme.warning,
                                );
                                return;
                              }
                              captureFile('bio');
                            },
                          ),
                        ),
                      ],
                    ),
                    if (matchedWorker != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.info.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user,
                                color: AppTheme.info),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Matched previous worker: ${matchedWorker!.name} (${matchedWorker!.id})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.info,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saveNewEntry,
                        icon: const Icon(Icons.save),
                        label: const Text('Save New Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
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
    ).whenComplete(() {
      fullNameController.dispose();
      aadharController.dispose();
      referralController.dispose();
    });
  }

  Widget _buildCaptureMiniButton({
    required String label,
    required bool captured,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: captured
              ? AppTheme.success.withValues(alpha: 0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: captured ? AppTheme.success : AppTheme.border,
            width: captured ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: captured ? AppTheme.success : AppTheme.textMuted,
                size: 20),
            const SizedBox(height: 6),
            Text(
              captured ? '$label ✓' : label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: captured ? AppTheme.success : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTemporaryIdsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, color: AppTheme.warning),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Temporary IDs',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_temporaryWorkers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No temporary IDs generated yet.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else
                ..._temporaryWorkers.map((worker) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.warning.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.warning,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                worker.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${worker.tempId} • ${worker.attendanceStatus}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            setState(() {
                              _selectedFlow = AttendanceFlowAction.checkIn;
                              _selectedOperation =
                                  AttendanceOperation.manualPhoto;
                            });
                          },
                          child: const Text('Mark'),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  /// Real camera capture for manual check-in/check-out photos.
  /// Returns the captured image bytes, or null if cancelled/failed.
  Future<Uint8List?> _showPhotoCaptureDialog(String title) async {
    return showDialog<Uint8List>(
      context: context,
      builder: (dialogContext) => _PhotoCaptureDialog(title: title),
    );
  }

  /// Upload a manual-attendance photo and return its storage path.
  Future<String?> _uploadManualPhoto(
      AttendanceWorkerProfile worker, Uint8List bytes,
      {required bool isCheckout}) async {
    return PhotoUploadService().uploadAttendancePhotoBytes(
      worker.id,
      bytes,
      kind: isCheckout ? 'checkout' : 'checkin',
    );
  }

  void _showSheetSnack(BuildContext sheetContext, String message, Color color) {
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  final String? siteId;
  final Function(List<OutsideWorker>, WorkerBatch) onAddWorkers;
  final Function(String, String) onStatusChanged;
  final VoidCallback onBatchesChanged;

  const OutsideWorkersTab({
    super.key,
    required this.outsideWorkers,
    required this.confirmedBatches,
    this.siteId,
    required this.onAddWorkers,
    required this.onStatusChanged,
    required this.onBatchesChanged,
  });

  @override
  State<OutsideWorkersTab> createState() => _OutsideWorkersTabState();
}

class _OutsideWorkersTabState extends State<OutsideWorkersTab> {
  final List<String> _supplierList = [
    'ABC Suppliers',
    'XYZ Contractors',
    'Global Manpower',
    'Local Labour Services',
    'Quick Staffing',
  ];

  final List<String> _batchTypes = const [
    'Morning',
    'Afternoon',
    'Full Day',
    'Others',
  ];

  String? _selectedSupplier;
  final TextEditingController _customSupplierController =
      TextEditingController();
  bool _isCustomSupplier = false;

  final TextEditingController _countController = TextEditingController();
  // Wage controllers retained for backward-compat with existing batches
  // (loaded from DB), but NO pre-filled amounts — wages are no longer
  // entered or shown in the UI (per product decision).
  final Map<String, TextEditingController> _wageControllers = {
    'Morning': TextEditingController(),
    'Afternoon': TextEditingController(),
    'Full Day': TextEditingController(),
    'Others': TextEditingController(),
  };

  String _selectedBatchType = 'Morning';
  bool _photoCaptured = false;
  String? _photoPath;
  String? _geoLocation;

  List<OutsideWorker> _pendingBatchWorkers = [];
  int _nextBatchNumber = 1;
  List<Map<String, dynamic>> _supplierBills = [];

  // Backend persistence for uploaded bills + realtime sync.
  final PaymentRepository _paymentRepo = PaymentRepository();
  PaymentsRealtimeSubscription? _billsRealtimeSub;
  final RealtimeDebouncer _billsDebouncer = RealtimeDebouncer();

  @override
  void initState() {
    super.initState();
    _loadBillsFromBackend();
    _startBillsRealtime();
  }

  Future<void> _loadBillsFromBackend() async {
    if (widget.siteId == null || widget.siteId!.isEmpty) return;
    final bills = await _paymentRepo.fetchBills(siteId: widget.siteId);
    if (!mounted) return;
    setState(() {
      _supplierBills = bills
          .map((b) => {
                'id': b.id ?? '',
                'supplier': b.supplier,
                'photoPath': b.photoPath ?? '',
              })
          .toList();
    });
  }

  void _startBillsRealtime() {
    _billsRealtimeSub?.cancel();
    if (widget.siteId == null || widget.siteId!.isEmpty) return;
    _billsRealtimeSub = RealtimeService.subscribePayments(
      siteId: widget.siteId,
      onAnyChange: () {
        _billsDebouncer.call(() {
          if (mounted) _loadBillsFromBackend();
        });
      },
    );
  }

  @override
  void dispose() {
    _billsRealtimeSub?.cancel();
    _customSupplierController.dispose();
    _countController.dispose();
    for (final controller in _wageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getFinalSupplier() {
    if (_isCustomSupplier) return _customSupplierController.text.trim();
    return _selectedSupplier ?? '';
  }

  Color _sessionColor(String session) {
    switch (session) {
      case 'Morning':
        return AppTheme.warning;
      case 'Afternoon':
        return AppTheme.accent;
      case 'Full Day':
        return AppTheme.success;
      case 'Others':
        return AppTheme.info;
      default:
        return AppTheme.primary;
    }
  }

  String _sessionEmoji(String session) {
    switch (session) {
      case 'Morning':
        return '🌅';
      case 'Afternoon':
        return '☀️';
      case 'Full Day':
        return '🌞';
      case 'Others':
        return '⏱️';
      default:
        return '👷';
    }
  }

  bool _isHalfDay(OutsideWorker worker) =>
      worker.attendanceStatus == 'Half day';

  bool _canEditHalfDay(WorkerBatch batch) {
    if (batch.shiftState == BatchShiftState.shiftEnded) return false;
    return batch.shiftState == BatchShiftState.pendingContinuation ||
        batch.shiftState == BatchShiftState.fullDayActive ||
        batch.sessionType == 'Full Day';
  }

  bool _batchIsMorningExtendable(WorkerBatch batch) =>
      batch.sessionType == 'Morning' &&
      batch.shiftState == BatchShiftState.active;

  /// Real camera capture with a friendly full-screen overlay.
  /// Returns the captured bytes (or null on cancel/error).
  Future<Uint8List?> _showPhotoCaptureDialog(String title) async {
    final result = await showDialog<Uint8List>(
      context: context,
      builder: (dialogContext) => _PhotoCaptureDialog(title: title),
    );
    return result;
  }

  /// Capture the batch entry photo with the real camera, then upload it to
  /// Supabase Storage and store the returned storage path + a geo label.
  Future<void> _capturePhotoWithGeo() async {
    final photo = await _showPhotoCaptureDialog('Capture batch entry photo');
    if (photo == null) return;

    // Show progress while uploading
    _showSnackbar('Uploading batch photo...', AppTheme.info);

    final batchId =
        'entry-${DateTime.now().millisecondsSinceEpoch}';
    final uploadPath =
        await PhotoUploadService().uploadOutsideWorkerPhoto(batchId, photo,
            context: 'entry');

    if (!mounted) return;
    setState(() {
      _photoCaptured = true;
      _photoPath = uploadPath ?? _photoPath;
      _geoLocation = 'Captured at ${_formatClock(DateTime.now())}';
    });
    _showSnackbar(
        uploadPath != null
            ? 'Batch entry photo captured & uploaded'
            : 'Batch entry photo captured (upload pending)',
        AppTheme.success);
  }

  String _formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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

    if (!_photoCaptured) {
      _showSnackbar(
          'Please capture batch photo with geo-location', AppTheme.warning);
      return;
    }

    final session = _selectedBatchType;
    if (_pendingBatchWorkers.isNotEmpty &&
        _pendingBatchWorkers.first.sessionType != session) {
      _showSnackbar(
        'Confirm the current ${_pendingBatchWorkers.first.sessionType} batch before adding $session workers.',
        AppTheme.warning,
      );
      return;
    }

    final seed = DateTime.now().millisecondsSinceEpoch;
    // Optional wage per worker — empty stays empty (no prefill).
    final wage = _wageControllers[session]?.text.trim() ?? '';
    setState(() {
      final newWorkers = List.generate(count, (index) {
        return OutsideWorker(
          id: 'OW-$seed-$index',
          name:
              'Worker ${widget.outsideWorkers.length + _pendingBatchWorkers.length + index + 1}',
          wage: wage,
          sessionType: session,
          attendanceStatus: 'Present',
          supplier: supplier,
          photoEntryPath: _photoPath,
          geoLocation: _geoLocation,
          isOnLeave: false,
          foodOptIn: true,
        );
      });
      _pendingBatchWorkers = [..._pendingBatchWorkers, ...newWorkers];
    });

    _showSnackbar(
        '$count $session worker(s) added to pending batch', AppTheme.success);
  }

  void _removePendingWorker(int index) {
    setState(() => _pendingBatchWorkers.removeAt(index));
  }

  BatchShiftState _initialShiftStateFor(String session) {
    if (session == 'Morning') return BatchShiftState.active;
    return BatchShiftState.pendingEndShift;
  }

  void _confirmAndAddBatch() {
    if (_pendingBatchWorkers.isEmpty) {
      _showSnackbar('No workers to confirm', AppTheme.danger);
      return;
    }

    final session = _pendingBatchWorkers.first.sessionType;
    final batch = WorkerBatch(
      batchNumber: _nextBatchNumber++,
      batchId:
          'BATCH-${DateTime.now().millisecondsSinceEpoch}-${session.toLowerCase().replaceAll(' ', '-')}',
      supplier: _getFinalSupplier().isNotEmpty
          ? _getFinalSupplier()
          : (_pendingBatchWorkers.first.supplier ?? 'Unknown'),
      sessionType: session,
      workers: List.from(_pendingBatchWorkers),
      photoPath: _pendingBatchWorkers.first.photoEntryPath,
      geoLocation: _pendingBatchWorkers.first.geoLocation,
      createdAt: DateTime.now(),
      shiftState: _initialShiftStateFor(session),
    );

    widget.onAddWorkers(batch.workers, batch);
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

    _showSnackbar('$session batch confirmed & added!', AppTheme.success);
  }

  void _startBatchExtension(WorkerBatch batch) {
    setState(() {
      batch.shiftState = BatchShiftState.pendingContinuation;
    });
    widget.onBatchesChanged();
    _showSnackbar(
      'Mark half-day workers with photo, then capture batch photo to extend.',
      AppTheme.info,
    );
  }

  Future<void> _toggleBatchWorkerHalfDay(
      WorkerBatch batch, int workerIndex, bool makeHalfDay) async {
    final worker = batch.workers[workerIndex];

    if (makeHalfDay) {
      final photoBytes = await _showPhotoCaptureDialog(
        'Capture half-day photo for ${worker.name}',
      );
      if (photoBytes == null) {
        _showSnackbar('Photo is required to mark Half Day', AppTheme.warning);
        return;
      }
      // Upload the half-day proof photo.
      final uploadPath = await PhotoUploadService().uploadOutsideWorkerPhoto(
        batch.batchId,
        photoBytes,
        context: 'halfday',
      );
      final photoPath =
          uploadPath ?? 'halfday_${worker.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      setState(() {
        batch.workers[workerIndex] = worker.copyWith(
          attendanceStatus: 'Half day',
          isOnLeave: false,
          halfDayPhotoPath: photoPath,
          photoExitPath: photoPath,
          isAfternoonContinued: false,
        );
      });
      widget.onBatchesChanged();
      _showSnackbar(
          '${worker.name} marked Half Day with photo', AppTheme.warning);
    } else {
      setState(() {
        batch.workers[workerIndex] = worker.copyWith(
          attendanceStatus: 'Present',
          isOnLeave: false,
          halfDayPhotoPath: null,
          photoExitPath: null,
        );
      });
      widget.onBatchesChanged();
      _showSnackbar('${worker.name} restored to working', AppTheme.success);
    }
  }

  Future<void> _captureContinuationPhoto(WorkerBatch batch) async {
    final photoBytes = await _showPhotoCaptureDialog(
      'Capture batch photo before extending to afternoon',
    );
    if (photoBytes == null) {
      _showSnackbar('Continuation photo is required', AppTheme.warning);
      return;
    }
    // Upload the continuation proof photo.
    final uploadPath = await PhotoUploadService().uploadOutsideWorkerPhoto(
      batch.batchId,
      photoBytes,
      context: 'continuation',
    );
    setState(() {
      batch.continuationPhotoPath = uploadPath ??
          'continuation_${batch.batchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
    widget.onBatchesChanged();

    final continuingCount = batch.workers.where((w) => !_isHalfDay(w)).length;
    _showSnackbar(
      'Continuation photo captured. $continuingCount worker(s) can continue.',
      AppTheme.success,
    );
  }

  void _confirmFullDayContinuation(WorkerBatch batch) {
    if (batch.continuationPhotoPath == null) {
      _showSnackbar('Capture the continuation photo first.', AppTheme.warning);
      return;
    }

    setState(() {
      for (int i = 0; i < batch.workers.length; i++) {
        final worker = batch.workers[i];
        if (!_isHalfDay(worker)) {
          batch.workers[i] = worker.copyWith(
            sessionType: 'Full Day',
            isAfternoonContinued: true,
            attendanceStatus: 'Present',
            isOnLeave: false,
          );
        }
      }
      batch.sessionType = 'Full Day';
      batch.shiftState = BatchShiftState.fullDayActive;
    });
    widget.onBatchesChanged();
    _showSnackbar(
      'Morning batch extended to afternoon. Half-day workers remain visible in the same batch.',
      AppTheme.success,
    );
  }

  Future<void> _captureEndShiftPhoto(WorkerBatch batch) async {
    final photoBytes = await _showPhotoCaptureDialog(
      'Capture end-shift photo for all workers in Batch #${batch.batchNumber}',
    );
    if (photoBytes == null) {
      _showSnackbar(
          'End-shift photo is required to close batch', AppTheme.warning);
      return;
    }

    // Upload the end-shift proof photo.
    final uploadPath = await PhotoUploadService().uploadOutsideWorkerPhoto(
      batch.batchId,
      photoBytes,
      context: 'endshift',
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      for (int i = 0; i < batch.workers.length; i++) {
        final worker = batch.workers[i];
        batch.workers[i] = worker.copyWith(
          photoExitPath: _isHalfDay(worker) && worker.halfDayPhotoPath != null
              ? worker.halfDayPhotoPath
              : uploadPath ?? 'endshift_${worker.id}_$timestamp.jpg',
          attendanceStatus:
              _isHalfDay(worker) ? 'Half day' : worker.attendanceStatus,
          isOnLeave: false,
        );
      }
      batch.endShiftPhotoPath = uploadPath;
      batch.endShiftGeoLocation = 'Captured at ${_formatClock(DateTime.now())}';
      batch.shiftState = BatchShiftState.shiftEnded;
    });
    widget.onBatchesChanged();

    _showSnackbar(
      'Shift ended. End-shift photo recorded for ${batch.workers.length} worker(s).',
      AppTheme.success,
    );
  }

  void _openBillUpload() {
    final suppliers = widget.outsideWorkers
        .map((w) => w.supplier ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    suppliers.add('Other...');

    String? selectedBillSupplier =
        suppliers.isNotEmpty ? suppliers.first : null;
    bool isCustomBillSupplier = false;
    final customBillController = TextEditingController();
    String? tempBillPhotoPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Upload Supplier Bill',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedBillSupplier,
                      decoration: InputDecoration(
                        labelText: 'Select Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: suppliers
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: tempBillPhotoPath != null
                              ? AppTheme.success
                              : AppTheme.border,
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: tempBillPhotoPath != null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: AppTheme.success, size: 40),
                                SizedBox(height: 8),
                                Text('Bill uploaded',
                                    style: TextStyle(color: AppTheme.success)),
                              ],
                            )
                          : const Text('No bill image',
                              style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Real camera capture for the supplier bill.
                          final bytes = await _showPhotoCaptureDialog(
                              'Capture supplier bill photo');
                          if (bytes == null || !sheetContext.mounted) return;
                          final uploadPath =
                              await PhotoUploadService()
                                  .uploadOutsideWorkerPhoto(
                                'bill-${DateTime.now().millisecondsSinceEpoch}',
                                bytes,
                                context: 'bill',
                              );
                          if (!sheetContext.mounted) return;
                          setSheetState(() {
                            tempBillPhotoPath = uploadPath ??
                                'bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          });
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Bill Photo'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final supplier = isCustomBillSupplier
                              ? customBillController.text.trim()
                              : selectedBillSupplier;
                          if (supplier == null || supplier.isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please select or enter supplier'),
                                backgroundColor: AppTheme.danger,
                              ),
                            );
                            return;
                          }
                          if (tempBillPhotoPath == null) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Please upload bill photo'),
                                backgroundColor: AppTheme.warning,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _supplierBills.add({
                              'supplier': supplier,
                              'photoPath': tempBillPhotoPath,
                            });
                          });
                          // Persist to Supabase so other devices see the bill.
                          if (widget.siteId != null &&
                              widget.siteId!.isNotEmpty) {
                            _paymentRepo.insertBill(
                              siteId: widget.siteId!,
                              supplier: supplier,
                              photoPath: tempBillPhotoPath,
                            );
                          }
                          Navigator.pop(sheetContext);
                          _showSnackbar(
                              'Bill uploaded for $supplier', AppTheme.success);
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Bill'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
    ).whenComplete(customBillController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupplierSection(),
          const SizedBox(height: 16),
          _buildBatchTypeSection(),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  leading:
                      const Icon(Icons.receipt_long, color: AppTheme.primary),
                  title: Text(bill['supplier'] as String),
                  subtitle: const Text('Bill uploaded',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.check_circle,
                      color: AppTheme.success, size: 20),
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
          const Text('Supplier & Worker Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedSupplier,
            decoration: InputDecoration(
              labelText: 'Supplier / Contractor Name',
              prefixIcon: const Icon(Icons.business),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              ..._supplierList
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))),
              const DropdownMenuItem(
                  value: 'custom', child: Text('Add New Supplier...')),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchTypeSection() {
    final selectedColor = _sessionColor(_selectedBatchType);
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
          const Text('Batch Type',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Select the shift/session for this batch of outside workers.',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _batchTypes.map((type) {
              final selected = _selectedBatchType == type;
              final color = _sessionColor(type);
              return ChoiceChip(
                selected: selected,
                label: Text('${_sessionEmoji(type)} $type'),
                labelStyle: TextStyle(
                  color: selected ? color : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                selectedColor: color.withValues(alpha: 0.16),
                backgroundColor: AppTheme.surface,
                side: BorderSide(
                  color: selected ? color : AppTheme.border,
                  width: selected ? 1.3 : 0.8,
                ),
                onSelected: (_) => setState(() => _selectedBatchType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selectedColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: selectedColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_sessionEmoji(_selectedBatchType)} $_selectedBatchType batch selected. Workers will be grouped under this session.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: selectedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _wageControllers[_selectedBatchType],
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            decoration: InputDecoration(
              labelText: 'Wage per worker (optional)',
              hintText: 'e.g. 350',
              helperText:
                  'Optional — used to calculate supplier bill amounts. Leave empty if not applicable.',
              prefixIcon: const Icon(Icons.currency_rupee, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: selectedColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                      color:
                          _photoCaptured ? AppTheme.success : AppTheme.border,
                      width: 2,
                    ),
                  ),
                  child: _photoCaptured
                      ? const Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                color: AppTheme.success, size: 48),
                            Positioned(
                              bottom: 10,
                              child: Text('Photo Captured',
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.success)),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt,
                                size: 48, color: AppTheme.textMuted),
                            SizedBox(height: 8),
                            Text('Capture batch photo',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted)),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                            const Icon(Icons.location_on,
                                size: 14, color: AppTheme.info),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _geoLocation!,
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.info),
                              ),
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

  Widget _buildPendingBatchPreview() {
    final Map<String, List<OutsideWorker>> grouped = {};
    for (final worker in _pendingBatchWorkers) {
      grouped.putIfAbsent(worker.sessionType, () => []).add(worker);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Pending Batch (Not yet confirmed)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                _miniStatBadge(
                    '${_pendingBatchWorkers.length} workers', AppTheme.primary),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: color.withValues(alpha: 0.07),
                  child: Row(
                    children: [
                      Text(_sessionEmoji(session),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('$session Batch',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      const Spacer(),
                      Text('${workers.length} workers',
                          style: TextStyle(fontSize: 11, color: color)),
                    ],
                  ),
                ),
                ...workers.asMap().entries.map((entry) {
                  final worker = entry.value;
                  final globalIndex = _pendingBatchWorkers.indexOf(worker);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.border.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(worker.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '${worker.id}'
                                '${worker.wage.trim().isNotEmpty ? ' • ₹${worker.wage}' : ''}'
                                ' • ${worker.supplier ?? ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _statusBadge(session, color),
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

  Widget _buildConfirmedBatchesBySession() {
    final Map<String, List<WorkerBatch>> batchBySession = {
      for (final session in _batchTypes) session: [],
    };

    for (final batch in widget.confirmedBatches) {
      batchBySession.putIfAbsent(batch.sessionType, () => []).add(batch);
    }

    final activeSessions = batchBySession.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList();

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
              end: Alignment.bottomRight,
            ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(
                        'Morning, Afternoon, Full Day and Others grouped below',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.confirmedBatches.length} batches',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...activeSessions.map((session) {
          final batches = batchBySession[session]!;
          final color = _sessionColor(session);
          final totalWorkers =
              batches.fold<int>(0, (sum, b) => sum + b.workers.length);
          return _buildSessionBatchCard(session, batches, color, totalWorkers);
        }),
      ],
    );
  }

  Widget _buildSessionBatchCard(String session, List<WorkerBatch> batches,
      Color color, int totalWorkers) {
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_sessionEmoji(session),
                      style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$session Section',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      Text(
                        '${batches.length} batch${batches.length > 1 ? 'es' : ''} • $totalWorkers workers',
                        style: TextStyle(
                          fontSize: 11,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                _miniStatBadge('$totalWorkers', color),
              ],
            ),
          ),
          ...batches.map((batch) => _buildBatchDetailCard(batch, color)),
        ],
      ),
    );
  }

  Widget _buildBatchDetailCard(WorkerBatch batch, Color sessionColor) {
    final isPendingContinuation =
        batch.shiftState == BatchShiftState.pendingContinuation;
    final isFullDayActive = batch.shiftState == BatchShiftState.fullDayActive;
    final isShiftEnded = batch.shiftState == BatchShiftState.shiftEnded;
    final isPendingEndShift =
        batch.shiftState == BatchShiftState.pendingEndShift;

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
          width: (isPendingContinuation ||
                  isFullDayActive ||
                  isShiftEnded ||
                  isPendingEndShift)
              ? 1.5
              : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Batch #${batch.batchNumber}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    batch.supplier,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusBadge(
                  _batchStateLabel(batch.shiftState),
                  _batchStateColor(batch.shiftState),
                ),
              ],
            ),
          ),
          ...batch.workers.asMap().entries.map((entry) {
            final index = entry.key;
            final worker = entry.value;
            final isHalfDay = _isHalfDay(worker);
            final canEditHalfDay = _canEditHalfDay(batch);
            final workerColor = isHalfDay ? AppTheme.warning : sessionColor;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.border.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: workerColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${index + 1}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: workerColor)),
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
                          '${worker.wage.trim().isNotEmpty ? '₹${worker.wage} • ' : ''}'
                          '${worker.sessionType}'
                          '${worker.isAfternoonContinued == true ? ' • Extended to afternoon' : ''}'
                          '${isHalfDay ? ' • Half Day' : ''}',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textMuted),
                        ),
                        if (worker.halfDayPhotoPath != null)
                          const Text('📸 Half-day photo taken',
                              style: TextStyle(
                                  fontSize: 9, color: AppTheme.warning)),
                        if (worker.photoExitPath != null &&
                            batch.shiftState == BatchShiftState.shiftEnded)
                          const Text('🏁 End-shift photo recorded',
                              style: TextStyle(
                                  fontSize: 9, color: AppTheme.success)),
                      ],
                    ),
                  ),
                  if (canEditHalfDay)
                    GestureDetector(
                      onTap: () =>
                          _toggleBatchWorkerHalfDay(batch, index, !isHalfDay),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isHalfDay
                              ? AppTheme.warning.withValues(alpha: 0.15)
                              : AppTheme.success.withValues(alpha: 0.12),
                          border: Border.all(
                            color:
                                isHalfDay ? AppTheme.warning : AppTheme.success,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isHalfDay
                                  ? Icons.hourglass_top
                                  : Icons.check_circle_outline,
                              size: 14,
                              color: isHalfDay
                                  ? AppTheme.warning
                                  : AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isHalfDay ? 'Half Day' : 'Working',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isHalfDay
                                    ? AppTheme.warning
                                    : AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _statusBadge(
                      _attendanceLabel(
                          worker.sessionType, worker.attendanceStatus),
                      _attendanceStatusColor(worker.attendanceStatus),
                    ),
                ],
              ),
            );
          }),
          _buildShiftWorkflowPanel(batch),
          if (batch.geoLocation != null || batch.photoPath != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (batch.geoLocation != null)
                    _footerInfo(
                        Icons.location_on, batch.geoLocation!, AppTheme.info),
                  if (batch.photoPath != null)
                    _footerInfo(Icons.photo_camera, 'Entry photo recorded',
                        AppTheme.info),
                  if (batch.continuationPhotoPath != null)
                    _footerInfo(Icons.update, 'Continuation photo recorded',
                        AppTheme.warning),
                  if (batch.endShiftGeoLocation != null)
                    _footerInfo(
                        Icons.flag, 'End geo recorded', AppTheme.success),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShiftWorkflowPanel(WorkerBatch batch) {
    switch (batch.shiftState) {
      case BatchShiftState.active:
        if (!_batchIsMorningExtendable(batch)) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.infoBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Morning batch can be ended now or extended to afternoon. During extension, mark non-continuing workers as Half Day with photo.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.info),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _startBatchExtension(batch),
                      icon: const Icon(Icons.update, size: 18),
                      label: const Text('Extend to Afternoon'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _captureEndShiftPhoto(batch),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('End Morning Shift'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case BatchShiftState.pendingContinuation:
        final halfDayCount = batch.workers.where(_isHalfDay).length;
        final continuingCount = batch.workers.length - halfDayCount;
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
              const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Before extending: mark workers who are not continuing as Half Day and capture their photo. Then capture the batch continuation photo.',
                    style: TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(
                children: [
                  _miniStatBadge('$halfDayCount half day', AppTheme.warning),
                  const SizedBox(width: 8),
                  _miniStatBadge(
                      '$continuingCount continuing', AppTheme.success),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _captureContinuationPhoto(batch),
                icon: Icon(hasPhoto ? Icons.check_circle : Icons.camera_alt,
                    size: 18),
                label: Text(hasPhoto
                    ? '✓ Continuation Photo Taken'
                    : 'Capture Continuation Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasPhoto ? AppTheme.success : AppTheme.info,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (hasPhoto) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: continuingCount <= 0
                      ? null
                      : () => _confirmFullDayContinuation(batch),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label:
                      Text('Continue $continuingCount Worker(s) to Afternoon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      case BatchShiftState.fullDayActive:
        final halfDayCount = batch.workers.where(_isHalfDay).length;
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
              const Row(children: [
                Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Extended batch is active. All original workers stay visible. You can still mark Half Day workers, then end shift with photo.',
                    style: TextStyle(fontSize: 12, color: AppTheme.success),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniStatBadge('$halfDayCount half day', AppTheme.warning),
                  const SizedBox(width: 8),
                  _miniStatBadge('$workingCount working', AppTheme.success),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _captureEndShiftPhoto(batch),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('End Shift — Capture All Worker Photos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        );
      case BatchShiftState.pendingEndShift:
        final halfDayCount = batch.workers.where(_isHalfDay).length;
        final workingCount = batch.workers.length - halfDayCount;
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
                        ? 'Full Day batch: use Half Day edit above if needed, then end shift with photo for all workers.'
                        : '${batch.sessionType} batch has only End Shift action.',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (batch.sessionType == 'Full Day') ...[
                    _miniStatBadge('$halfDayCount half day', AppTheme.warning),
                    const SizedBox(width: 8),
                  ],
                  _miniStatBadge('$workingCount working', AppTheme.success),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _captureEndShiftPhoto(batch),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('End Shift — Capture All Worker Photos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        );
      case BatchShiftState.shiftEnded:
        final halfDayCount = batch.workers.where(_isHalfDay).length;
        final completedCount = batch.workers.length - halfDayCount;
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
                      '$completedCount completed • $halfDayCount half day • End photos recorded.',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
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
                child:
                    const Icon(Icons.check, color: AppTheme.success, size: 16),
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _footerInfo(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }

  Color _batchStateColor(BatchShiftState state) {
    switch (state) {
      case BatchShiftState.active:
        return AppTheme.info;
      case BatchShiftState.pendingContinuation:
        return AppTheme.warning;
      case BatchShiftState.fullDayActive:
        return AppTheme.success;
      case BatchShiftState.shiftEnded:
        return AppTheme.success;
      case BatchShiftState.pendingEndShift:
        return AppTheme.warning;
    }
  }

  String _batchStateLabel(BatchShiftState state) {
    switch (state) {
      case BatchShiftState.active:
        return 'Active';
      case BatchShiftState.pendingContinuation:
        return 'Pending Extension';
      case BatchShiftState.fullDayActive:
        return 'Afternoon Active';
      case BatchShiftState.shiftEnded:
        return '✓ Shift Ended';
      case BatchShiftState.pendingEndShift:
        return 'End Shift';
    }
  }

  String _attendanceLabel(String session, String status) {
    if (status == 'Present') return session;
    if (status == 'Half day') return 'Half Day';
    return status;
  }

  Color _attendanceStatusColor(String status) {
    switch (status) {
      case 'Present':
        return AppTheme.success;
      case 'Half day':
        return AppTheme.warning;
      case 'Absent':
        return AppTheme.danger;
      default:
        return AppTheme.info;
    }
  }

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
          CircleAvatar(
            radius: 18,
            backgroundColor:
                _sessionColor(worker.sessionType).withValues(alpha: 0.12),
            child: Text(_sessionEmoji(worker.sessionType),
                style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(worker.supplier ?? 'No supplier',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
                Text('${worker.id}'
                    '${worker.wage.trim().isNotEmpty ? ' • ₹${worker.wage}' : ''}'
                    ' • ${worker.sessionType}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
                if (worker.isAfternoonContinued ?? false)
                  const Text('⏩ Extended to afternoon',
                      style: TextStyle(fontSize: 9, color: AppTheme.info)),
              ],
            ),
          ),
          _statusBadge(
            _attendanceLabel(worker.sessionType, worker.attendanceStatus),
            _attendanceStatusColor(worker.attendanceStatus),
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

// ==================== PAYMENTS SUPPORT MODELS ====================
class PermanentWorkerPaymentAccount {
  final String id;
  final String workerId;
  String name;
  String department;
  int daysWorked;
  double monthlyAmount;
  double usedAmount;
  bool isPaid;
  DateTime paymentMonth;
  DateTime? paidAt;
  double paidAmount;
  final List<WorkerPaymentLedgerEntry> ledger;

  PermanentWorkerPaymentAccount({
    required this.id,
    required this.workerId,
    required this.name,
    required this.department,
    required this.daysWorked,
    required this.monthlyAmount,
    this.usedAmount = 0,
    this.isPaid = false,
    required this.paymentMonth,
    this.paidAt,
    this.paidAmount = 0,
    List<WorkerPaymentLedgerEntry>? ledger,
  }) : ledger = ledger ?? [];

  double get balanceAmount => (monthlyAmount - usedAmount - paidAmount)
      .clamp(0, double.infinity)
      .toDouble();
  double get effectivePayableAmount =>
      (monthlyAmount - usedAmount).clamp(0, double.infinity).toDouble();
}

class WorkerPaymentLedgerEntry {
  final String id;
  final String type; // used amount / cash / request
  final double amount;
  final DateTime date;
  String status;
  String method;
  String note;
  String? proofId;
  bool registeredInMachineIdsBook;

  WorkerPaymentLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
    required this.method,
    required this.note,
    this.proofId,
    this.registeredInMachineIdsBook = false,
  });

  String? get paymentProof => proofId;
}

class SupplierBillPaymentRequest {
  String id;
  final String supplierName;
  final List<String> batchIds;
  final double amount;
  final DateTime requestedAt;
  final String requestType;
  final double billAmount;
  final double usedAmount;
  String status;
  String method;
  String? paymentProof;

  SupplierBillPaymentRequest({
    required this.id,
    required this.supplierName,
    required this.batchIds,
    required this.amount,
    required this.requestedAt,
    required this.method,
    this.requestType = 'Bill Balance',
    this.billAmount = 0,
    this.usedAmount = 0,
    this.status = 'Requested',
    this.paymentProof,
  });
}

// ==================== TAB 4: PERMANENT WORKER PAYMENTS ====================
class PaymentsTab extends StatefulWidget {
  final List<Worker> permanentWorkers;
  final String? siteId;
  final ValueChanged<List<PermanentWorkerPaymentAccount>>? onPaymentSnapshotChanged;

  const PaymentsTab({
    super.key,
    required this.permanentWorkers,
    this.siteId,
    this.onPaymentSnapshotChanged,
  });

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  final List<PermanentWorkerPaymentAccount> _paymentWorkers = [];
  final TextEditingController _paymentSearchController =
      TextEditingController();

  // Backend persistence + realtime for payment accounts & ledger.
  final PaymentRepository _paymentRepo = PaymentRepository();
  PaymentsRealtimeSubscription? _realtimeSub;
  final RealtimeDebouncer _realtimeDebouncer = RealtimeDebouncer();
  // Maps local ledger entry ids → DB row ids after insert.
  final Map<String, String> _ledgerDbIdByLocalId = {};

  // Attendance salary payment model fields. These support using Cash Payment and
  // Request Payment at the same time for the selected worker payment sheet.
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _advanceAmountController =
      TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _accNumController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  PermanentWorkerPaymentAccount? _activePaymentWorker;
  StateSetter? _activePaymentSheetSetState;
  bool _enableCashPayment = false;
  bool _enableAdvancePayment = false;
  String _selectedAdvanceMode = 'upi';
  String? _selectedEntryMethod;
  String? _selectedPaymentAccount;
  String? _selectedBankAccount;

  final List<Map<String, String>> _savedAccounts = [
    {
      'id': 'upi-primary',
      'upiId': 'worker.salary@upi',
      'bankName': 'Verified UPI Salary Account',
      'type': 'primary',
    },
    {
      'id': 'upi-secondary',
      'upiId': 'site.payments@upi',
      'bankName': 'Site Payment UPI',
      'type': 'secondary',
    },
  ];

  final List<Map<String, String>> _savedBankAccounts = [
    {
      'id': 'bank-primary',
      'bankName': 'SBI Salary Account',
      'accountNumber': '****4291',
      'ifsc': 'SBIN0004291',
      'holderName': 'Worker Salary Ledger',
      'type': 'primary',
    },
  ];

  double _supervisorCashBalance = 50000;
  final double _cashLimit = 25000;

  @override
  void initState() {
    super.initState();
    _loadOrSeedAccounts();
    _startRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyPaymentSnapshotChanged();
    });
    _paymentSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _paymentSearchController.dispose();
    _cashAmountController.dispose();
    _advanceAmountController.dispose();
    _ifscController.dispose();
    _accNumController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // Backend load / persist
  // ---------------------------------------------------------------

  Future<void> _loadOrSeedAccounts() async {
    final siteId = widget.siteId;
    if (siteId == null || siteId.isEmpty) {
      // No site context (offline/tests): fall back to in-memory seeding.
      _seedPermanentWorkers();
      _rolloverMonthlyPaymentsIfNeeded();
      return;
    }

    final now = DateTime.now();
    final rows = await _paymentRepo.fetchAccounts(
      DateTime(now.year, now.month),
      siteId: siteId,
    );

    if (rows.isEmpty) {
      // Seed from worker list, then persist so other devices see them.
      _seedPermanentWorkers();
      _rolloverMonthlyPaymentsIfNeeded();
      for (final account in _paymentWorkers) {
        _persistAccount(account);
        for (final entry in account.ledger) {
          _persistLedgerEntry(account, entry);
        }
      }
      _notifyPaymentSnapshotChanged();
      return;
    }

    // Load ledger rows once and attach to their accounts.
    final ledgerRows = await _paymentRepo.fetchLedger(siteId: siteId);
    final ledgerByAccount = <String, List<WorkerPaymentLedgerEntry>>{};
    for (final row in ledgerRows) {
      final accountId = row.accountId;
      if (accountId == null || accountId.isEmpty) continue;
      ledgerByAccount.putIfAbsent(accountId, () => []).add(
            WorkerPaymentLedgerEntry(
              id: row.id ?? '',
              type: row.type,
              amount: row.amount,
              date: row.entryDate,
              status: row.status,
              method: row.method,
              note: row.note,
              proofId: row.proofId,
              registeredInMachineIdsBook: row.registeredInMachineIdsBook,
            ),
          );
    }

    if (!mounted) return;
    setState(() {
      _paymentWorkers.clear();
      _ledgerDbIdByLocalId.clear();
      for (final row in rows) {
        _paymentWorkers.add(
          PermanentWorkerPaymentAccount(
            id: 'PAY-DB-${row.id ?? row.workerName}',
            workerId: row.workerId ?? '',
            name: row.workerName,
            department: row.department ?? '',
            daysWorked: row.daysWorked,
            monthlyAmount: row.monthlyAmount,
            usedAmount: row.usedAmount,
            isPaid: row.isPaid,
            paymentMonth: row.paymentMonth,
            paidAt: row.paidAt,
            paidAmount: row.paidAmount,
            ledger: ledgerByAccount[row.id] ?? [],
          ),
        );
      }
    });
    _notifyPaymentSnapshotChanged();
  }

  void _startRealtime() {
    _realtimeSub?.cancel();
    final siteId = widget.siteId;
    if (siteId == null || siteId.isEmpty) return;
    _realtimeSub = RealtimeService.subscribePayments(
      siteId: siteId,
      onAnyChange: () {
        _realtimeDebouncer.call(() {
          if (mounted) _loadOrSeedAccounts();
        });
      },
    );
  }

  /// Persist the current account state (upsert keyed on site/worker/month).
  void _persistAccount(PermanentWorkerPaymentAccount account) {
    final siteId = widget.siteId;
    if (siteId == null || siteId.isEmpty) return;
    _paymentRepo.upsertAccount(PaymentAccountRow(
      siteId: siteId,
      workerId: account.workerId.isEmpty ? null : account.workerId,
      workerName: account.name,
      department: account.department,
      daysWorked: account.daysWorked,
      monthlyAmount: account.monthlyAmount,
      usedAmount: account.usedAmount,
      paidAmount: account.paidAmount,
      isPaid: account.isPaid,
      paymentMonth: account.paymentMonth,
      paidAt: account.paidAt,
    ));
  }

  /// Persist a ledger entry (insert new, or update when [updateOnly]).
  void _persistLedgerEntry(
    PermanentWorkerPaymentAccount account,
    WorkerPaymentLedgerEntry entry, {
    bool updateOnly = false,
  }) {
    final siteId = widget.siteId;
    if (siteId == null || siteId.isEmpty) return;

    if (updateOnly) {
      final dbId = _ledgerDbIdByLocalId[entry.id] ?? entry.id;
      if (_isUuid(dbId)) {
        _paymentRepo.updateLedgerEntry(
          dbId,
          status: entry.status,
          proofId: entry.proofId,
          registeredInMachineIdsBook: entry.registeredInMachineIdsBook,
        );
      }
      return;
    }

    _paymentRepo
        .insertLedgerEntry(PaymentLedgerRow(
          siteId: siteId,
          workerId: account.workerId.isEmpty ? null : account.workerId,
          workerName: account.name,
          type: entry.type,
          amount: entry.amount,
          status: entry.status,
          method: entry.method,
          note: entry.note,
          proofId: entry.proofId,
          registeredInMachineIdsBook: entry.registeredInMachineIdsBook,
          entryDate: entry.date,
        ))
        .then((row) {
          if (row != null && row.id != null && row.id!.isNotEmpty) {
            _ledgerDbIdByLocalId[entry.id] = row.id!;
          }
        });
  }

  bool _isUuid(String value) =>
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false)
          .hasMatch(value);

  void _notifyPaymentSnapshotChanged() {
    widget.onPaymentSnapshotChanged?.call(
      List<PermanentWorkerPaymentAccount>.from(_paymentWorkers),
    );
  }

  void _seedPermanentWorkers() {
    final now = DateTime.now();
    final eligibleWorkers = widget.permanentWorkers
        .where((worker) =>
            worker.status == 'active' || worker.status == 'inactive')
        .toList();

    for (int i = 0; i < eligibleWorkers.length; i++) {
      final worker = eligibleWorkers[i];
      if (_paymentWorkers.any((account) => account.workerId == worker.id))
        continue;
      _paymentWorkers.add(
        PermanentWorkerPaymentAccount(
          id: 'PAY-WRK-${(i + 1).toString().padLeft(3, '0')}',
          workerId: worker.id,
          name: worker.name,
          department: worker.department,
          daysWorked: worker.status == 'active' ? 26 : 18,
          monthlyAmount: worker.status == 'active' ? 18000 : 14000,
          paymentMonth: DateTime(now.year, now.month),
        ),
      );
    }
  }

  void _rolloverMonthlyPaymentsIfNeeded() {
    final now = DateTime.now();
    for (final account in _paymentWorkers) {
      if (account.paymentMonth.month != now.month ||
          account.paymentMonth.year != now.year) {
        account.paymentMonth = DateTime(now.year, now.month);
        account.daysWorked = 0;
        account.usedAmount = 0;
        account.isPaid = false;
        account.paidAt = null;
        account.paidAmount = 0;
        final resetEntry = WorkerPaymentLedgerEntry(
          id: 'MONTH-${DateTime.now().millisecondsSinceEpoch}',
          type: 'month_reset',
          amount: 0,
          date: DateTime.now(),
          status: 'Completed',
          method: 'Auto',
          note: 'New month started. Used amount reset to ₹0.',
        );
        account.ledger.add(resetEntry);
        _persistAccount(account);
        _persistLedgerEntry(account, resetEntry);
      }
    }
  }

  String _formatCurrency(double amount) => '₹${amount.toStringAsFixed(0)}';

  String _formatMonth(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} • $hour:$minute';
  }

  double get _totalEarned => _paymentWorkers.fold<double>(
      0, (sum, worker) => sum + worker.monthlyAmount);

  double get _totalUsedAmount =>
      _paymentWorkers.fold<double>(0, (sum, worker) => sum + worker.usedAmount);

  double get _totalBalance => _paymentWorkers.fold<double>(
      0, (sum, worker) => sum + worker.balanceAmount);

  int get _paidWorkers =>
      _paymentWorkers.where((worker) => worker.isPaid).length;

  String get _paymentSearchQuery =>
      _paymentSearchController.text.trim().toLowerCase();

  List<PermanentWorkerPaymentAccount> get _filteredPaymentWorkers {
    final query = _paymentSearchQuery;
    if (query.isEmpty) return _paymentWorkers;
    return _paymentWorkers.where((account) {
      final searchable = [
        account.name,
        account.workerId,
        account.department,
        account.isPaid ? 'paid' : 'pending',
        account.daysWorked.toString(),
        account.monthlyAmount.toStringAsFixed(0),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    _rolloverMonthlyPaymentsIfNeeded();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentsHeader(),
          const SizedBox(height: 16),
          _buildPaymentsSummary(),
          const SizedBox(height: 16),
          _buildWorkerSearchBar(),
          const SizedBox(height: 14),
          if (_paymentWorkers.isEmpty)
            _buildEmptyPaymentsState()
          else if (_filteredPaymentWorkers.isEmpty)
            _buildNoPaymentSearchResultsState()
          else
            ..._filteredPaymentWorkers.map(_buildWorkerPaymentCard),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildPaymentsHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.payments_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payments',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Permanent worker monthly salary • ${_formatMonth(DateTime.now())}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          _paymentStatusChip(
              '$_paidWorkers/${_paymentWorkers.length} Paid', AppTheme.success,
              light: true),
        ],
      ),
    );
  }

  Widget _buildPaymentsSummary() {
    return Row(
      children: [
        _buildPaymentMiniStat('Earned', _formatCurrency(_totalEarned),
            AppTheme.primary, Icons.trending_up),
        const SizedBox(width: 10),
        _buildPaymentMiniStat('Used Amount', _formatCurrency(_totalUsedAmount),
            AppTheme.warning, Icons.remove_circle_outline),
        const SizedBox(width: 10),
        _buildPaymentMiniStat('Balance', _formatCurrency(_totalBalance),
            AppTheme.success, Icons.account_balance_wallet),
      ],
    );
  }

  Widget _buildPaymentMiniStat(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 7),
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerSearchBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextField(
        controller: _paymentSearchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: 'Search permanent workers',
          hintText: 'Search by name, ID, department or paid status',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _paymentSearchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _paymentSearchController.clear(),
                ),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildEmptyPaymentsState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.22)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.info),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No permanent worker payment cards are available yet. Permanent workers from attendance will appear here automatically.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.info,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPaymentSearchResultsState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_off_rounded, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No workers found for "${_paymentSearchController.text}". Try searching another name, ID, department, or payment status.',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerPaymentCard(PermanentWorkerPaymentAccount account) {
    final balance = account.balanceAmount;
    final paidColor = account.isPaid ? AppTheme.success : AppTheme.warning;

    return GestureDetector(
      onTap: () => _openWorkerPaymentDetails(account),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: account.isPaid
                ? AppTheme.success.withValues(alpha: 0.45)
                : AppTheme.border,
            width: account.isPaid ? 1.4 : 0.8,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: paidColor.withValues(alpha: 0.12),
                  child: Icon(
                      account.isPaid ? Icons.verified_rounded : Icons.person,
                      color: paidColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text('${account.workerId} • ${account.department}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                _paymentStatusChip(
                    account.isPaid ? 'Paid' : 'Pending', paidColor),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildWorkerMoneyTile(
                    'Days', '${account.daysWorked}', AppTheme.info),
                const SizedBox(width: 8),
                _buildWorkerMoneyTile('Earned',
                    _formatCurrency(account.monthlyAmount), AppTheme.primary),
                const SizedBox(width: 8),
                _buildWorkerMoneyTile('Used Amount',
                    _formatCurrency(account.usedAmount), AppTheme.warning),
                const SizedBox(width: 8),
                _buildWorkerMoneyTile(
                    'Balance', _formatCurrency(balance), AppTheme.success),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: account.isPaid
                        ? null
                        : () => _openAddUsedAmountSheet(account),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Add Used'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warning,
                      side: BorderSide(
                          color: AppTheme.warning.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: account.isPaid
                        ? null
                        : () => _openWorkerPaymentDetails(account),
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text(account.isPaid ? 'Paid' : 'Pay Balance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  Widget _buildWorkerMoneyTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9.5, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _paymentStatusChip(String label, Color color, {bool light = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.16)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: light
                ? Colors.white.withValues(alpha: 0.28)
                : color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: light ? Colors.white : color,
        ),
      ),
    );
  }

  void _openAddUsedAmountSheet(PermanentWorkerPaymentAccount account) {
    final usedAmountController = TextEditingController();
    final noteController = TextEditingController(text: 'Advance/used amount before salary');
    final usedCashController = TextEditingController();
    final usedRequestController = TextEditingController();
    bool enableUsedCashPayment = false;
    bool enableUsedRequestPayment = true;
    String selectedUsedRequestMode = 'upi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final targetAmount = double.tryParse(usedAmountController.text.trim()) ?? 0;
            final cashAmount = enableUsedCashPayment
                ? (double.tryParse(usedCashController.text.trim()) ?? 0)
                : 0.0;
            final requestAmount = enableUsedRequestPayment
                ? (double.tryParse(usedRequestController.text.trim()) ?? 0)
                : 0.0;
            final plannedTotal = cashAmount + requestAmount;
            final validTarget = targetAmount > 0 && targetAmount <= account.balanceAmount;
            final exceedsBalance = targetAmount > account.balanceAmount && targetAmount > 0;
            final overPlanned = plannedTotal > targetAmount && targetAmount > 0;
            final remainingPlan = (targetAmount - plannedTotal).clamp(0, double.infinity).toDouble();
            final canProcessCash = validTarget &&
                enableUsedCashPayment &&
                cashAmount > 0 &&
                cashAmount <= targetAmount &&
                plannedTotal <= targetAmount &&
                cashAmount <= _supervisorCashBalance &&
                cashAmount <= _cashLimit;
            final canSendRequest = validTarget &&
                enableUsedRequestPayment &&
                requestAmount > 0 &&
                requestAmount <= targetAmount &&
                plannedTotal <= targetAmount;

            void syncDefaultAmounts() {
              final raw = usedAmountController.text.trim();
              if (raw.isEmpty) return;
              if (usedCashController.text.trim().isEmpty && enableUsedCashPayment) {
                usedCashController.text = raw;
              }
              if (usedRequestController.text.trim().isEmpty && enableUsedRequestPayment) {
                usedRequestController.text = raw;
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.remove_circle_outline, color: AppTheme.warning),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add Used • ${account.name}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text('Balance: ${_formatCurrency(account.balanceAmount)} • Supervisor cash: ${_formatCurrency(_supervisorCashBalance)}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: usedAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Used Amount Target',
                        hintText: 'Example: 5000',
                        helperText: targetAmount > 0
                            ? 'Salary balance after full used entry: ${_formatCurrency((account.balanceAmount - targetAmount).clamp(0, double.infinity).toDouble())}'
                            : 'Enter used amount, then choose cash and/or request payment.',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) {
                        syncDefaultAmounts();
                        setSheetState(() {});
                      },
                    ),
                    if (exceedsBalance) ...[
                      const SizedBox(height: 10),
                      _buildUsedPaymentNotice(
                        'Used amount cannot be greater than current worker balance.',
                        AppTheme.danger,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Note',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (targetAmount > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: overPlanned ? AppTheme.dangerBg : AppTheme.infoBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (overPlanned ? AppTheme.danger : AppTheme.info).withValues(alpha: 0.24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(overPlanned ? Icons.warning_amber_rounded : Icons.calculate_outlined,
                                    color: overPlanned ? AppTheme.danger : AppTheme.info,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    overPlanned
                                        ? 'Cash + request amount is higher than used target.'
                                        : 'Use Cash Payment and Request Payment together for this used amount.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: overPlanned ? AppTheme.danger : AppTheme.info,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _paymentPill('Used Target', _formatCurrency(targetAmount), AppTheme.warning),
                                _paymentPill('Cash Used', _formatCurrency(cashAmount), AppTheme.info),
                                _paymentPill('Request Used', _formatCurrency(requestAmount), AppTheme.success),
                                _paymentPill('Unplanned', _formatCurrency(remainingPlan), remainingPlan == 0 ? AppTheme.success : AppTheme.warning),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cash Payment', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Directly add used amount by cash'),
                        value: enableUsedCashPayment,
                        activeColor: AppTheme.info,
                        onChanged: validTarget
                            ? (value) {
                                setSheetState(() {
                                  enableUsedCashPayment = value;
                                  if (value && usedCashController.text.trim().isEmpty) {
                                    usedCashController.text = usedAmountController.text.trim();
                                  }
                                });
                              }
                            : null,
                      ),
                      if (enableUsedCashPayment) ...[
                        TextField(
                          controller: usedCashController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Cash Used Amount (₹)',
                            hintText: 'Max ${_formatCurrency(_cashLimit)}',
                            helperText: 'Available supervisor cash: ${_formatCurrency(_supervisorCashBalance)}',
                            prefixIcon: const Icon(Icons.payments_outlined),
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: canProcessCash
                                ? () {
                                    setState(() {
                                      _processWorkerUsedCashAmount(
                                        account,
                                        cashAmount,
                                        noteController.text.trim(),
                                      );
                                    });
                                    setSheetState(() {
                                      usedCashController.clear();
                                      enableUsedCashPayment = false;
                                    });
                                    _notifyPaymentSnapshotChanged();
                                    _showPaymentSnack(
                                      'Cash used amount added for ${account.name}',
                                      AppTheme.success,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.payment_rounded),
                            label: const Text('Proceed Used Cash Payment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.info,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Request Payment', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Send used amount request to finance team'),
                        value: enableUsedRequestPayment,
                        activeColor: AppTheme.success,
                        onChanged: validTarget
                            ? (value) {
                                setSheetState(() {
                                  enableUsedRequestPayment = value;
                                  if (value && usedRequestController.text.trim().isEmpty) {
                                    usedRequestController.text = usedAmountController.text.trim();
                                  }
                                });
                              }
                            : null,
                      ),
                      if (enableUsedRequestPayment) ...[
                        TextField(
                          controller: usedRequestController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Request Used Amount (₹)',
                            prefixIcon: const Icon(Icons.request_quote_outlined),
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildUsedRequestModeTile(
                                label: 'UPI',
                                icon: Icons.qr_code_rounded,
                                selected: selectedUsedRequestMode == 'upi',
                                color: AppTheme.success,
                                enabled: canSendRequest,
                                onTap: () => setSheetState(() => selectedUsedRequestMode = 'upi'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildUsedRequestModeTile(
                                label: 'Bank Transfer',
                                icon: Icons.account_balance_rounded,
                                selected: selectedUsedRequestMode == 'bank',
                                color: AppTheme.info,
                                enabled: canSendRequest,
                                onTap: () => setSheetState(() => selectedUsedRequestMode = 'bank'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: canSendRequest
                                ? () {
                                    setState(() {
                                      _submitWorkerUsedAmountRequest(
                                        account,
                                        requestAmount,
                                        selectedUsedRequestMode,
                                        noteController.text.trim().isEmpty
                                            ? 'Used amount request sent to finance team'
                                            : noteController.text.trim(),
                                      );
                                    });
                                    setSheetState(() {
                                      usedRequestController.clear();
                                      enableUsedRequestPayment = false;
                                    });
                                    _notifyPaymentSnapshotChanged();
                                    _showPaymentSnack(
                                      'Used amount request sent to finance team for ${account.name}',
                                      AppTheme.success,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Send Used Request to Finance Team'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.success,
                              side: BorderSide(color: AppTheme.success.withValues(alpha: 0.42)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildWorkerLedger(account, onChanged: () {
                        setState(() {});
                        setSheetState(() {});
                        _notifyPaymentSnapshotChanged();
                      }),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      usedAmountController.dispose();
      noteController.dispose();
      usedCashController.dispose();
      usedRequestController.dispose();
      _notifyPaymentSnapshotChanged();
    });
  }

  Widget _buildUsedPaymentNotice(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color == AppTheme.danger ? AppTheme.dangerBg : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildUsedRequestModeTile({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected && enabled
              ? color.withValues(alpha: 0.1)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected && enabled ? color : AppTheme.border,
            width: selected && enabled ? 1.6 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected && enabled ? color : AppTheme.textMuted),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: selected && enabled ? color : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWorkerPaymentDetails(PermanentWorkerPaymentAccount account) {
    _prepareAttendancePaymentSection(account);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            _activePaymentSheetSetState = setSheetState;
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.96,
              expand: false,
              builder: (_, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.12),
                            child: const Icon(Icons.person,
                                color: AppTheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(account.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 3),
                                Text(
                                    '${account.workerId} • ${_formatMonth(account.paymentMonth)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          _paymentStatusChip(
                              account.isPaid ? 'Paid' : 'Pending',
                              account.isPaid
                                  ? AppTheme.success
                                  : AppTheme.warning),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentBreakdownCard(account),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.info.withValues(alpha: 0.22)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.info, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cash Payment and Request Payment can be enabled together. Use cash for one part and request payment for the remaining balance.',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.info,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentSection(),
                      const SizedBox(height: 16),
                      _buildWorkerLedger(account, onChanged: () {
                        setState(() {});
                        setSheetState(() {});
                      }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {
        _enableCashPayment = false;
        _enableAdvancePayment = false;
        _activePaymentWorker = null;
        _activePaymentSheetSetState = null;
      });
    });
  }

  void _prepareAttendancePaymentSection(PermanentWorkerPaymentAccount account) {
    _activePaymentWorker = account;
    _enableCashPayment = false;
    _enableAdvancePayment = false;
    _selectedAdvanceMode = 'upi';
    _selectedEntryMethod = null;
    _selectedPaymentAccount =
        _savedAccounts.isNotEmpty ? _savedAccounts.first['id'] : null;
    _selectedBankAccount =
        _savedBankAccounts.isNotEmpty ? _savedBankAccounts.first['id'] : null;
    final balanceText = account.balanceAmount.toStringAsFixed(0);
    _cashAmountController.text = balanceText;
    _advanceAmountController.text = balanceText;
  }

  List<WorkerPaymentLedgerEntry> get _cashTransactions =>
      _activePaymentWorker?.ledger
          .where((entry) => entry.type == 'cash')
          .toList() ??
      [];

  List<WorkerPaymentLedgerEntry> get _advanceTransactions =>
      _activePaymentWorker?.ledger
          .where((entry) => entry.type == 'request')
          .toList() ??
      [];

  double get _cashBalance => _supervisorCashBalance;

  String _formatCompactDateTime(DateTime value) => _formatDateTime(value);

  void _refreshAttendancePaymentUi([VoidCallback? changes]) {
    if (!mounted) return;
    setState(() {
      changes?.call();
    });
    _activePaymentSheetSetState?.call(() {});
  }

  double get _cashDraftAmount =>
      double.tryParse(_cashAmountController.text.trim()) ?? 0;

  double get _requestDraftAmount =>
      double.tryParse(_advanceAmountController.text.trim()) ?? 0;

  double get _activeWorkerBalance => _activePaymentWorker?.balanceAmount ?? 0;

  double get _draftTotalPayment {
    final cash = _enableCashPayment ? _cashDraftAmount : 0.0;
    final request = _enableAdvancePayment ? _requestDraftAmount : 0.0;
    return cash + request;
  }

  double get _draftRemainingBalance =>
      (_activeWorkerBalance - _draftTotalPayment)
          .clamp(0, double.infinity)
          .toDouble();

// ── Payment section ───────────────────────────────────────────────────────
  Widget _buildPaymentSection() {
    return Column(
      children: [
        _buildDualPaymentLiveSummary(),
        const SizedBox(height: 12),
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
                onChanged: (val) =>
                    _refreshAttendancePaymentUi(() => _enableCashPayment = val),
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
            onChanged: (_) => _refreshAttendancePaymentUi(),
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
                onChanged: (val) => _refreshAttendancePaymentUi(
                    () => _enableAdvancePayment = val),
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

  Widget _buildDualPaymentLiveSummary() {
    final account = _activePaymentWorker;
    final balance = account?.balanceAmount ?? 0.0;
    final cash = _enableCashPayment ? _cashDraftAmount : 0.0;
    final request = _enableAdvancePayment ? _requestDraftAmount : 0.0;
    final total = cash + request;
    final remaining = (balance - total).clamp(0, double.infinity).toDouble();
    final overAmount = total > balance && balance > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overAmount ? AppTheme.dangerBg : AppTheme.infoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              (overAmount ? AppTheme.danger : AppTheme.info).withOpacity(0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overAmount
                    ? Icons.warning_amber_rounded
                    : Icons.calculate_outlined,
                size: 18,
                color: overAmount ? AppTheme.danger : AppTheme.info,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  overAmount
                      ? 'Entered payment is higher than worker balance.'
                      : 'Cash and Request Payment can both be used together.',
                  style: TextStyle(
                    fontSize: 12,
                    color: overAmount ? AppTheme.danger : AppTheme.info,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _paymentPill(
                  'Balance', _formatCurrency(balance), AppTheme.primary),
              _paymentPill('Cash', _formatCurrency(cash), AppTheme.info),
              _paymentPill(
                  'Request', _formatCurrency(request), AppTheme.success),
              _paymentPill('After Entered', _formatCurrency(remaining),
                  overAmount ? AppTheme.danger : AppTheme.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        '$label: $value',
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
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
    final text = _cashAmountController.text.trim();
    final amount = double.tryParse(text) ?? 0;
    final workerBalance = _activePaymentWorker?.balanceAmount ?? 0;

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
            Expanded(
              child: Text(
                'Worker balance: ${_formatCurrency(workerBalance)} • Supervisor cash: ${_formatCurrency(_cashBalance)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.info),
              ),
            ),
          ],
        ),
      );
    }

    if (amount > workerBalance) {
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
                'Cash amount exceeds worker balance of ${_formatCurrency(workerBalance)}.',
                style: const TextStyle(fontSize: 11, color: AppTheme.danger),
              ),
            ),
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
                'Exceeds HOD cash limit of ${_formatCurrency(_cashLimit)}. Reduce cash amount or use request payment for remaining balance.',
                style: const TextStyle(fontSize: 11, color: AppTheme.danger),
              ),
            ),
          ],
        ),
      );
    }

    if (amount > _cashBalance) {
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
                'Insufficient supervisor cash balance. Available: ${_formatCurrency(_cashBalance)}.',
                style: const TextStyle(fontSize: 11, color: AppTheme.danger),
              ),
            ),
          ],
        ),
      );
    }

    final remaining = workerBalance - amount;
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
          Expanded(
            child: Text(
              'Valid cash payment. Worker balance after cash: ${_formatCurrency(remaining)}.',
              style: const TextStyle(fontSize: 11, color: AppTheme.success),
            ),
          ),
        ],
      ),
    );
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
          onChanged: (_) => _refreshAttendancePaymentUi(),
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
                onTap: () => _refreshAttendancePaymentUi(() {
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
                onTap: () => _refreshAttendancePaymentUi(() {
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
                  onTap: () => _refreshAttendancePaymentUi(
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
                      _refreshAttendancePaymentUi(() {
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
      onTap: () =>
          _refreshAttendancePaymentUi(() => _selectedEntryMethod = method),
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

  Widget _buildPaymentBreakdownCard(PermanentWorkerPaymentAccount account) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _paymentBreakdownRow(
              'No. of days worked', '${account.daysWorked} days'),
          _paymentBreakdownRow('Amount worker earned/month',
              _formatCurrency(account.monthlyAmount)),
          _paymentBreakdownRow('Used Amount before payday',
              '- ${_formatCurrency(account.usedAmount)}',
              color: AppTheme.warning),
          _paymentBreakdownRow(
              'Already paid', '- ${_formatCurrency(account.paidAmount)}',
              color: AppTheme.info),
          const Divider(height: 22),
          _paymentBreakdownRow(
              'Balance amount to pay', _formatCurrency(account.balanceAmount),
              color: AppTheme.success, bold: true),
        ],
      ),
    );
  }

  Widget _paymentBreakdownRow(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerLedger(PermanentWorkerPaymentAccount account,
      {VoidCallback? onChanged}) {
    final rows = account.ledger.reversed.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Payment Ledger',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text('No used/payment entries yet.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
          else
            ...rows.map((entry) {
              final isUsedEntry = entry.type == 'used_amount' ||
                  entry.type == 'used_amount_request';
              final isPendingFinance = (entry.type == 'request' ||
                      entry.type == 'used_amount_request') &&
                  entry.status == 'Requested';
              final color = isUsedEntry
                  ? AppTheme.warning
                  : entry.status == 'Completed'
                      ? AppTheme.success
                      : AppTheme.info;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withValues(alpha: 0.16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.type == 'used_amount'
                          ? Icons.remove_circle_outline
                          : entry.type == 'used_amount_request'
                              ? Icons.request_quote_outlined
                              : entry.type == 'cash'
                                  ? Icons.payments_outlined
                                  : Icons.request_quote_outlined,
                      color: color,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.note,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                              '${entry.method} • ${_formatDateTime(entry.date)}',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    if (isPendingFinance)
                      TextButton.icon(
                        onPressed: () {
                          _refreshAttendancePaymentUi(() {
                            if (entry.type == 'used_amount_request') {
                              _completeWorkerUsedAmountRequest(account, entry);
                            } else {
                              _completeWorkerPaymentRequest(account, entry);
                            }
                          });
                          onChanged?.call();
                          _showPaymentSnack(
                              'Finance request completed for ${account.name}',
                              AppTheme.success);
                        },
                        icon: const Icon(Icons.verified_outlined, size: 15),
                        label: const Text('Complete'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.warning),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatCurrency(entry.amount),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: color)),
                          const SizedBox(height: 2),
                          Text(
                            entry.proofId == null
                                ? entry.status
                                : '${entry.status} • Proof',
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCashAmountBox({
    required TextEditingController controller,
    required double balanceAmount,
    required double typedAmount,
    required VoidCallback onChanged,
  }) {
    Color infoColor = AppTheme.info;
    String infoText =
        'Enter balance amount to pay. Balance: ${_formatCurrency(balanceAmount)}';

    if (typedAmount > _cashLimit) {
      infoColor = AppTheme.danger;
      infoText = 'Amount exceeds cash limit of ${_formatCurrency(_cashLimit)}.';
    } else if (typedAmount > _supervisorCashBalance) {
      infoColor = AppTheme.danger;
      infoText = 'Insufficient supervisor cash balance.';
    } else if (typedAmount > balanceAmount) {
      infoColor = AppTheme.danger;
      infoText = 'Amount cannot be greater than worker balance.';
    } else if (typedAmount > 0) {
      infoColor = AppTheme.success;
      infoText =
          'Valid payment. Cash after payment: ${_formatCurrency(_supervisorCashBalance - typedAmount)}';
    }

    return Column(
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Cash Amount',
            hintText: 'Pay ${_formatCurrency(balanceAmount)}',
            prefixIcon: const Icon(Icons.currency_rupee),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 9),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: infoColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: infoColor.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: infoColor, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(infoText,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: infoColor,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestPaymentMiniModel({
    required TextEditingController amountController,
    required String selectedMode,
    required double balanceAmount,
    required double amount,
    required ValueChanged<String> onModeChanged,
    required VoidCallback onAmountChanged,
    required VoidCallback? onSubmit,
  }) {
    final isValid = amount > 0 && amount <= balanceAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Request Amount',
              helperText:
                  'Maximum payable balance: ${_formatCurrency(balanceAmount)}',
              prefixIcon: const Icon(Icons.currency_rupee),
              filled: true,
              fillColor: AppTheme.surfaceCard,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => onAmountChanged(),
          ),
          const SizedBox(height: 12),
          const Text('Payment Method',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRequestModeTile(
                  label: 'UPI',
                  icon: Icons.qr_code_rounded,
                  selected: selectedMode == 'upi',
                  color: AppTheme.success,
                  onTap: () => onModeChanged('upi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRequestModeTile(
                  label: 'Bank Transfer',
                  icon: Icons.account_balance_rounded,
                  selected: selectedMode == 'bank',
                  color: AppTheme.info,
                  onTap: () => onModeChanged('bank'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                    selectedMode == 'upi'
                        ? Icons.verified_outlined
                        : Icons.account_balance_wallet_outlined,
                    color: selectedMode == 'upi'
                        ? AppTheme.success
                        : AppTheme.info,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedMode == 'upi'
                        ? 'Verified UPI: worker.pay@upi'
                        : 'Verified Bank: Worker Salary Account • ****4291',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!isValid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Enter a valid request amount within the worker balance.',
                style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit Request Payment'),
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
      ),
    );
  }

  Widget _buildRequestModeTile({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: selected ? color : AppTheme.border,
              width: selected ? 1.6 : 0.8),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppTheme.textMuted),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: selected ? color : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _proceedCashPayment() {
    final account = _activePaymentWorker;
    final amount = double.tryParse(_cashAmountController.text.trim()) ?? 0;
    if (account == null) return;
    if (!_canPayCash(account, amount)) {
      _showPaymentSnack(
          'Enter a valid cash amount within worker balance, HOD cash limit and available cash.',
          AppTheme.danger);
      return;
    }
    _refreshAttendancePaymentUi(() {
      _completeWorkerCashPayment(account, amount);
      final remaining = account.balanceAmount;
      _cashAmountController.clear();
      _advanceAmountController.text =
          remaining > 0 ? remaining.toStringAsFixed(0) : '';
    });
    _showPaymentSnack(
        'Cash payment completed for ${account.name}. Remaining balance: ${_formatCurrency(account.balanceAmount)}',
        AppTheme.success);
  }

  void _submitAdvanceRequest() {
    final account = _activePaymentWorker;
    final amount = double.tryParse(_advanceAmountController.text.trim()) ?? 0;
    if (account == null) return;
    if (!_canSubmitWorkerRequest(account, amount)) {
      _showPaymentSnack(
          'Enter a valid request amount within the current worker balance.',
          AppTheme.danger);
      return;
    }
    if (_selectedAdvanceMode == 'upi' && _selectedPaymentAccount == null) {
      _showPaymentSnack('Select a verified UPI account.', AppTheme.warning);
      return;
    }
    if (_selectedAdvanceMode == 'bank' &&
        _selectedEntryMethod == null &&
        _selectedBankAccount == null) {
      _showPaymentSnack(
          'Select saved bank account or enter bank details before submitting request.',
          AppTheme.warning);
      return;
    }
    _refreshAttendancePaymentUi(() {
      _submitWorkerPaymentRequest(account, amount, _selectedAdvanceMode);
      _advanceAmountController.clear();
    });
    _showPaymentSnack(
        'Request payment sent to finance team for ${account.name}',
        AppTheme.success);
  }

  void _completeRequestedAdvance(WorkerPaymentLedgerEntry txn) {
    final account = _activePaymentWorker;
    if (account == null) return;
    _refreshAttendancePaymentUi(() {
      _completeWorkerPaymentRequest(account, txn);
      final remaining = account.balanceAmount;
      _cashAmountController.text =
          remaining > 0 ? remaining.toStringAsFixed(0) : '';
      _advanceAmountController.text =
          remaining > 0 ? remaining.toStringAsFixed(0) : '';
    });
    _showPaymentSnack(
        'Finance request completed for ${account.name}', AppTheme.success);
  }

  void _toggleAdvanceMachineBook(WorkerPaymentLedgerEntry txn, bool value) {
    _refreshAttendancePaymentUi(() => txn.registeredInMachineIdsBook = value);
    final account = _activePaymentWorker;
    if (account != null) {
      _persistLedgerEntry(account, txn, updateOnly: true);
    }
  }

  void _showEditCashPaymentSheet(WorkerPaymentLedgerEntry txn) {
    final account = _activePaymentWorker;
    if (account == null) return;
    final editController =
        TextEditingController(text: txn.amount.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_outlined, color: AppTheme.info),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Edit Cash Payment',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: editController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Correct Cash Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final newAmount =
                        double.tryParse(editController.text.trim()) ?? 0;
                    if (newAmount <= 0) {
                      _showPaymentSnack('Enter valid amount.', AppTheme.danger);
                      return;
                    }
                    final delta = newAmount - txn.amount;
                    if (delta > account.balanceAmount + txn.amount ||
                        delta > _supervisorCashBalance) {
                      _showPaymentSnack(
                          'Edited amount is not valid for current balance.',
                          AppTheme.danger);
                      return;
                    }
                    setState(() {
                      account.paidAmount -= txn.amount;
                      _supervisorCashBalance += txn.amount;
                      txn.note = 'Cash salary payment edited';
                      final updated = WorkerPaymentLedgerEntry(
                        id: txn.id,
                        type: txn.type,
                        amount: newAmount,
                        date: txn.date,
                        status: txn.status,
                        method: txn.method,
                        note: txn.note,
                        proofId: txn.proofId,
                        registeredInMachineIdsBook:
                            txn.registeredInMachineIdsBook,
                      );
                      final index = account.ledger.indexOf(txn);
                      if (index != -1) account.ledger[index] = updated;
                      account.paidAmount += newAmount;
                      _supervisorCashBalance -= newAmount;
                      account.isPaid = account.balanceAmount <= 0;
                      account.paidAt = account.isPaid ? DateTime.now() : null;
                      _cashAmountController.text =
                          account.balanceAmount.toStringAsFixed(0);
                      _advanceAmountController.text =
                          account.balanceAmount.toStringAsFixed(0);
                    });
                    _persistAccount(account);
                    _persistLedgerEntry(account, txn, updateOnly: true);
                    Navigator.pop(sheetContext);
                    _showPaymentSnack(
                        'Cash payment corrected.', AppTheme.success);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Correction'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.info,
                      foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(editController.dispose);
  }

  void _showTransactionHistorySheet(String type) {
    final rows = type == 'cash' ? _cashTransactions : _advanceTransactions;
    final color = type == 'cash' ? AppTheme.info : AppTheme.success;
    final title =
        type == 'cash' ? 'Cash Payment History' : 'Request Payment History';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900))),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Text('No transactions yet.',
                    style: TextStyle(color: AppTheme.textSecondary))
              else
                ...rows.map((txn) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.12),
                        child: Icon(
                            type == 'cash'
                                ? Icons.payments_outlined
                                : Icons.request_quote_outlined,
                            color: color),
                      ),
                      title: Text(
                          '${txn.id} • ₹${txn.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                          '${txn.method} • ${txn.status} • ${_formatCompactDateTime(txn.date)}'),
                    )),
            ],
          ),
        );
      },
    );
  }

  Map<String, String>? _findSavedUpiAccount(String? id) {
    if (id == null) return null;
    for (final account in _savedAccounts) {
      if (account['id'] == id) return account;
    }
    return null;
  }

  Map<String, String>? _findSavedBankAccount(String? id) {
    if (id == null) return null;
    for (final account in _savedBankAccounts) {
      if (account['id'] == id) return account;
    }
    return null;
  }

  void _showAddAccountSheet({String? existingId}) {
    final account =
        existingId == null ? null : _findSavedUpiAccount(existingId);
    final upiController = TextEditingController(text: account?['upiId'] ?? '');
    final bankController =
        TextEditingController(text: account?['bankName'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existingId == null ? 'Add UPI Account' : 'Edit UPI Account',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                  controller: upiController,
                  decoration: const InputDecoration(labelText: 'UPI ID')),
              const SizedBox(height: 10),
              TextField(
                  controller: bankController,
                  decoration:
                      const InputDecoration(labelText: 'Bank / Account Name')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final upi = upiController.text.trim();
                    final bank = bankController.text.trim();
                    if (upi.isEmpty) {
                      _showPaymentSnack('Enter UPI ID.', AppTheme.danger);
                      return;
                    }
                    setState(() {
                      if (existingId == null) {
                        final id =
                            'upi-${DateTime.now().millisecondsSinceEpoch}';
                        _savedAccounts.add({
                          'id': id,
                          'upiId': upi,
                          'bankName': bank.isEmpty ? 'UPI Account' : bank,
                          'type': 'secondary'
                        });
                        _selectedPaymentAccount = id;
                      } else {
                        final index = _savedAccounts
                            .indexWhere((item) => item['id'] == existingId);
                        if (index != -1) {
                          _savedAccounts[index]['upiId'] = upi;
                          _savedAccounts[index]['bankName'] =
                              bank.isEmpty ? 'UPI Account' : bank;
                        }
                      }
                    });
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save UPI Account'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      upiController.dispose();
      bankController.dispose();
    });
  }

  void _showAddBankAccountSheet({String? existingId}) {
    final bank = existingId == null ? null : _findSavedBankAccount(existingId);
    final bankNameController =
        TextEditingController(text: bank?['bankName'] ?? '');
    final accountController = TextEditingController(
        text: bank?['accountNumber']?.replaceAll('****', '') ?? '');
    final ifscController = TextEditingController(text: bank?['ifsc'] ?? '');
    final holderController =
        TextEditingController(text: bank?['holderName'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  existingId == null ? 'Add Bank Account' : 'Edit Bank Account',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                  controller: bankNameController,
                  decoration: const InputDecoration(labelText: 'Bank Name')),
              const SizedBox(height: 10),
              TextField(
                  controller: accountController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Account Number')),
              const SizedBox(height: 10),
              TextField(
                  controller: ifscController,
                  decoration: const InputDecoration(labelText: 'IFSC Code')),
              const SizedBox(height: 10),
              TextField(
                  controller: holderController,
                  decoration: const InputDecoration(labelText: 'Holder Name')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final bankName = bankNameController.text.trim();
                    final acc = accountController.text.trim();
                    final ifsc = ifscController.text.trim();
                    final holder = holderController.text.trim();
                    if (bankName.isEmpty || acc.isEmpty || ifsc.isEmpty) {
                      _showPaymentSnack(
                          'Enter bank name, account number and IFSC.',
                          AppTheme.danger);
                      return;
                    }
                    setState(() {
                      final masked = acc.length > 4
                          ? '****${acc.substring(acc.length - 4)}'
                          : acc;
                      if (existingId == null) {
                        final id =
                            'bank-${DateTime.now().millisecondsSinceEpoch}';
                        _savedBankAccounts.add({
                          'id': id,
                          'bankName': bankName,
                          'accountNumber': masked,
                          'ifsc': ifsc,
                          'holderName': holder,
                          'type': 'secondary',
                        });
                        _selectedBankAccount = id;
                      } else {
                        final index = _savedBankAccounts
                            .indexWhere((item) => item['id'] == existingId);
                        if (index != -1) {
                          _savedBankAccounts[index]['bankName'] = bankName;
                          _savedBankAccounts[index]['accountNumber'] = masked;
                          _savedBankAccounts[index]['ifsc'] = ifsc;
                          _savedBankAccounts[index]['holderName'] = holder;
                        }
                      }
                      _selectedEntryMethod = 'manual';
                    });
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Bank Account'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.info,
                      foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      bankNameController.dispose();
      accountController.dispose();
      ifscController.dispose();
      holderController.dispose();
    });
  }

  bool _canPayCash(PermanentWorkerPaymentAccount account, double amount) {
    return !account.isPaid &&
        amount > 0 &&
        amount <= account.balanceAmount &&
        amount <= _supervisorCashBalance &&
        amount <= _cashLimit;
  }

  bool _canSubmitWorkerRequest(
      PermanentWorkerPaymentAccount account, double amount) {
    return !account.isPaid && amount > 0 && amount <= account.balanceAmount;
  }

  void _processWorkerUsedCashAmount(
    PermanentWorkerPaymentAccount account,
    double amount,
    String note,
  ) {
    if (amount <= 0) return;
    final safeAmount = amount
        .clamp(0, account.balanceAmount)
        .clamp(0, _supervisorCashBalance)
        .toDouble();
    if (safeAmount <= 0) return;
    _supervisorCashBalance -= safeAmount;
    account.usedAmount += safeAmount;
    final entry = WorkerPaymentLedgerEntry(
      id: 'USED-CASH-${DateTime.now().millisecondsSinceEpoch}',
      type: 'used_amount_cash',
      amount: safeAmount,
      date: DateTime.now(),
      status: 'Completed',
      method: 'Cash Used Payment',
      note: note.isEmpty ? 'Used amount added through cash payment' : note,
      proofId: 'USED-CASH-PROOF-${DateTime.now().millisecondsSinceEpoch}',
    );
    account.ledger.add(entry);
    if (account.balanceAmount <= 0) {
      account.isPaid = true;
      account.paidAt = DateTime.now();
    }
    _persistAccount(account);
    _persistLedgerEntry(account, entry);
  }

  void _completeWorkerCashPayment(
      PermanentWorkerPaymentAccount account, double amount) {
    _supervisorCashBalance -= amount;
    account.paidAmount += amount;
    final entry = WorkerPaymentLedgerEntry(
      id: 'CASH-${DateTime.now().millisecondsSinceEpoch}',
      type: 'cash',
      amount: amount,
      date: DateTime.now(),
      status: 'Completed',
      method: 'Cash Payment',
      note: 'Cash salary payment completed',
      proofId: 'CASH-PROOF-${DateTime.now().millisecondsSinceEpoch}',
    );
    account.ledger.add(entry);

    if (account.balanceAmount <= 0) {
      account.isPaid = true;
      account.paidAt = DateTime.now();
    }
    _persistAccount(account);
    _persistLedgerEntry(account, entry);
    _notifyPaymentSnapshotChanged();
  }

  void _submitWorkerUsedAmountRequest(
    PermanentWorkerPaymentAccount account,
    double amount,
    String mode,
    String note,
  ) {
    final entry = WorkerPaymentLedgerEntry(
      id: 'USED-REQ-${DateTime.now().millisecondsSinceEpoch}',
      type: 'used_amount_request',
      amount: amount,
      date: DateTime.now(),
      status: 'Requested',
      method: mode == 'upi' ? 'UPI Finance Request' : 'Bank Finance Request',
      note: note.isEmpty ? 'Used amount request sent to finance team' : note,
    );
    account.ledger.add(entry);
    _persistLedgerEntry(account, entry);
    _notifyPaymentSnapshotChanged();
  }

  void _completeWorkerUsedAmountRequest(
    PermanentWorkerPaymentAccount account,
    WorkerPaymentLedgerEntry entry,
  ) {
    if (entry.status == 'Completed') return;
    final availableUsedRoom = (account.monthlyAmount - account.usedAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final amountToApply = entry.amount.clamp(0, availableUsedRoom).toDouble();
    entry.status = 'Completed';
    entry.proofId = 'USED-PROOF-${DateTime.now().millisecondsSinceEpoch}';
    if (amountToApply > 0) {
      account.usedAmount += amountToApply;
    }
    if (account.balanceAmount <= 0) {
      account.isPaid = true;
      account.paidAt = DateTime.now();
    }
    _persistAccount(account);
    _persistLedgerEntry(account, entry, updateOnly: true);
    _notifyPaymentSnapshotChanged();
  }

  void _submitWorkerPaymentRequest(
      PermanentWorkerPaymentAccount account, double amount, String mode) {
    final entry = WorkerPaymentLedgerEntry(
      id: 'REQ-${DateTime.now().millisecondsSinceEpoch}',
      type: 'request',
      amount: amount,
      date: DateTime.now(),
      status: 'Requested',
      method: mode == 'upi' ? 'UPI' : 'Bank Transfer',
      note: 'Request payment sent to finance team',
    );
    account.ledger.add(entry);
    _persistLedgerEntry(account, entry);
    _notifyPaymentSnapshotChanged();
  }

  void _completeWorkerPaymentRequest(
    PermanentWorkerPaymentAccount account,
    WorkerPaymentLedgerEntry entry,
  ) {
    if (entry.status == 'Completed') return;
    final amountToApply =
        entry.amount.clamp(0, account.balanceAmount).toDouble();
    entry.status = 'Completed';
    entry.proofId = 'REQ-PROOF-${DateTime.now().millisecondsSinceEpoch}';
    account.paidAmount += amountToApply;

    if (account.balanceAmount <= 0) {
      account.isPaid = true;
      account.paidAt = DateTime.now();
    }
    _persistAccount(account);
    _persistLedgerEntry(account, entry, updateOnly: true);
    _notifyPaymentSnapshotChanged();
  }

  void _showPaymentSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ==================== TAB 5: SUPPLIER BILLS PAYMENT ====================
class SupplierBillsPaymentTab extends StatefulWidget {
  final List<WorkerBatch> confirmedBatches;
  final List<OutsideWorker> outsideWorkers;
  final String? siteId;
  final ValueChanged<List<SupplierBillPaymentRequest>>? onSupplierPaymentSnapshotChanged;

  const SupplierBillsPaymentTab({
    super.key,
    required this.confirmedBatches,
    required this.outsideWorkers,
    this.siteId,
    this.onSupplierPaymentSnapshotChanged,
  });

  @override
  State<SupplierBillsPaymentTab> createState() =>
      _SupplierBillsPaymentTabState();
}

class _SupplierBillsPaymentTabState extends State<SupplierBillsPaymentTab> {
  String? _selectedSupplier;
  final Set<String> _selectedBatchIds = {};
  final Set<String> _expandedBatchIds = {};
  List<SupplierBillPaymentRequest> _paymentRequests = [];
  String _selectedRequestMode = 'upi';

  // Backend persistence + realtime for payment requests.
  final PaymentRepository _paymentRepo = PaymentRepository();
  PaymentsRealtimeSubscription? _realtimeSub;
  final RealtimeDebouncer _realtimeDebouncer = RealtimeDebouncer();

  @override
  void initState() {
    super.initState();
    final suppliers = _availableSuppliers;
    if (suppliers.isNotEmpty) _selectedSupplier = suppliers.first;
    _loadPaymentRequests();
    _startRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifySupplierPaymentSnapshotChanged();
    });
  }

  Future<void> _loadPaymentRequests() async {
    if (widget.siteId == null || widget.siteId!.isEmpty) return;
    final rows =
        await _paymentRepo.fetchPaymentRequests(siteId: widget.siteId);
    if (!mounted) return;
    setState(() {
      _paymentRequests = rows
          .map((r) => SupplierBillPaymentRequest(
                id: r.id ?? 'SUP-REQ-${DateTime.now().millisecondsSinceEpoch}',
                supplierName: r.supplierName,
                batchIds: r.batchIds,
                amount: r.amount,
                billAmount: r.billAmount,
                usedAmount: r.usedAmount,
                requestType: r.requestType,
                requestedAt: r.requestedAt,
                method: r.method,
                status: r.status,
                paymentProof: r.paymentProof,
              ))
          .toList();
    });
    _notifySupplierPaymentSnapshotChanged();
  }

  void _startRealtime() {
    _realtimeSub?.cancel();
    if (widget.siteId == null || widget.siteId!.isEmpty) return;
    _realtimeSub = RealtimeService.subscribePayments(
      siteId: widget.siteId,
      onAnyChange: () {
        _realtimeDebouncer.call(() {
          if (mounted) _loadPaymentRequests();
        });
      },
    );
  }

  void _notifySupplierPaymentSnapshotChanged() {
    widget.onSupplierPaymentSnapshotChanged?.call(
      List<SupplierBillPaymentRequest>.from(_paymentRequests),
    );
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  List<WorkerBatch> get _displayBatches {
    if (widget.confirmedBatches.isNotEmpty) return widget.confirmedBatches;

    final grouped = <String, List<OutsideWorker>>{};
    for (final worker in widget.outsideWorkers) {
      final supplier =
          (worker.supplier == null || worker.supplier!.trim().isEmpty)
              ? 'Unknown Supplier'
              : worker.supplier!.trim();
      grouped.putIfAbsent(supplier, () => []).add(worker);
    }

    int index = 1;
    return grouped.entries.map((entry) {
      return WorkerBatch(
        batchNumber: index,
        batchId: 'AUTO-BATCH-${(index++).toString().padLeft(3, '0')}',
        supplier: entry.key,
        sessionType: 'Today',
        workers: entry.value,
        geoLocation: 'Site location pending',
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  List<String> get _availableSuppliers {
    final suppliers = _displayBatches
        .map((batch) => batch.supplier)
        .where((supplier) => supplier.trim().isNotEmpty)
        .toSet()
        .toList();
    suppliers.sort();
    return suppliers;
  }

  List<WorkerBatch> get _supplierBatches {
    if (_selectedSupplier == null) return [];
    return _displayBatches
        .where((batch) => batch.supplier == _selectedSupplier)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<WorkerBatch> get _selectedBatches => _supplierBatches
      .where((batch) => _selectedBatchIds.contains(batch.batchId))
      .toList();

  double get _selectedTotalAmount => _selectedBatches.fold<double>(
      0, (sum, batch) => sum + _batchTotalAmount(batch));

  double get _selectedPayableAmount =>
      _selectedTotalAmount.clamp(0, double.infinity).toDouble();

  int get _selectedWorkersCount =>
      _selectedBatches.fold<int>(0, (sum, batch) => sum + batch.workers.length);

  String _formatCurrency(double amount) => '₹${amount.toStringAsFixed(0)}';

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} • $hour:$minute';
  }

  double _workerWage(OutsideWorker worker) {
    final wage = double.tryParse(worker.wage.trim()) ?? 0;
    return worker.attendanceStatus == 'Half day' ? wage / 2 : wage;
  }

  double _batchTotalAmount(WorkerBatch batch) =>
      batch.workers.fold<double>(0, (sum, worker) => sum + _workerWage(worker));

  Map<String, List<WorkerBatch>> get _batchesByDate {
    final grouped = <String, List<WorkerBatch>>{};
    for (final batch in _supplierBatches) {
      grouped.putIfAbsent(_formatDate(batch.createdAt), () => []).add(batch);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = _availableSuppliers;
    if (_selectedSupplier == null && suppliers.isNotEmpty) {
      _selectedSupplier = suppliers.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupplierHeader(),
          const SizedBox(height: 16),
          if (suppliers.isEmpty)
            _buildNoSupplierState()
          else ...[
            _buildSupplierDropdown(suppliers),
            const SizedBox(height: 16),
            _buildSupplierSelectionSummary(),
            const SizedBox(height: 16),
            _buildBatchDateGroups(),
            const SizedBox(height: 16),
            _buildSupplierRequestPaymentModel(),
            const SizedBox(height: 16),
            _buildSupplierRequestTable(),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplierHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supplier Bills Payment',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Select supplier, choose batches, request payment',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Text(
              '${_paymentRequests.length} Requests',
              style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSupplierState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.22)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.info),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No supplier batches are available yet. Add outside worker batches first, then supplier bills will appear here automatically.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.info,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierDropdown(List<String> suppliers) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedSupplier,
        decoration: InputDecoration(
          labelText: 'Select Supplier',
          prefixIcon: const Icon(Icons.storefront_outlined),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: suppliers
            .map((supplier) => DropdownMenuItem(
                  value: supplier,
                  child: Text(supplier),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedSupplier = value;
            _selectedBatchIds.clear();
            _expandedBatchIds.clear();
          });
        },
      ),
    );
  }

  Widget _buildSupplierSelectionSummary() {
    return Row(
      children: [
        _buildSupplierMiniStat('Batches', '${_supplierBatches.length}',
            AppTheme.info, Icons.layers_outlined),
        const SizedBox(width: 10),
        _buildSupplierMiniStat('Selected', '${_selectedBatchIds.length}',
            AppTheme.primary, Icons.checklist_rounded),
        const SizedBox(width: 10),
        _buildSupplierMiniStat(
            'Payable',
            _formatCurrency(_selectedPayableAmount),
            AppTheme.success,
            Icons.currency_rupee),
      ],
    );
  }

  Widget _buildSupplierMiniStat(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 7),
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchDateGroups() {
    final groups = _batchesByDate;
    if (groups.isEmpty) {
      return _buildNoSupplierState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        final batches = entry.value;
        final workersCount =
            batches.fold<int>(0, (sum, batch) => sum + batch.workers.length);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
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
                  const Icon(Icons.calendar_month_rounded,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${entry.key} • ${batches.length} batch(es) came to site',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ),
                  _smallSupplierChip('$workersCount Workers', AppTheme.info),
                ],
              ),
              const SizedBox(height: 12),
              ...batches.map(_buildSupplierBatchCard),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupplierBatchCard(WorkerBatch batch) {
    final selected = _selectedBatchIds.contains(batch.batchId);
    final expanded = _expandedBatchIds.contains(batch.batchId);
    final total = _batchTotalAmount(batch);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.success.withValues(alpha: 0.07)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppTheme.success.withValues(alpha: 0.4)
              : AppTheme.border,
          width: selected ? 1.4 : 0.8,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              if (expanded) {
                _expandedBatchIds.remove(batch.batchId);
              } else {
                _expandedBatchIds.add(batch.batchId);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    activeColor: AppTheme.success,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedBatchIds.add(batch.batchId);
                        } else {
                          _selectedBatchIds.remove(batch.batchId);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      '${batch.batchNumber}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Batch ${batch.batchNumber} • ${batch.sessionType}',
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(
                            '${batch.workers.length} workers came • Per person wages shown below',
                            style: const TextStyle(
                                fontSize: 10.5, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatCurrency(total),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.success)),
                      const SizedBox(height: 3),
                      Icon(
                          expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppTheme.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _buildBatchWorkersInfo(batch),
        ],
      ),
    );
  }

  Widget _buildBatchWorkersInfo(WorkerBatch batch) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 16),
          const Text('Workers came info',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...batch.workers.map((worker) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      worker.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    worker.attendanceStatus,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total Workers',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${batch.workers.length}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallSupplierChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, color: color, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildSupplierRequestPaymentModel() {
    final enabled = _selectedBatchIds.isNotEmpty && _selectedPayableAmount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: enabled
                ? AppTheme.success.withValues(alpha: 0.28)
                : AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.request_quote_outlined, color: AppTheme.success),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Request Payment Model',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              _smallSupplierChip('${_selectedBatchIds.length} Batch(es)',
                  enabled ? AppTheme.success : AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Supplier bills use request payment only. Select supplier batches and submit the bill amount to the finance team.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppTheme.success.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.currency_rupee, color: AppTheme.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payable balance for $_selectedWorkersCount workers',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  _formatCurrency(_selectedPayableAmount),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.success),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Payment Method',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _requestModeTile(
                  label: 'UPI',
                  icon: Icons.qr_code_rounded,
                  selected: _selectedRequestMode == 'upi',
                  color: AppTheme.success,
                  enabled: enabled,
                  onTap: () => setState(() => _selectedRequestMode = 'upi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _requestModeTile(
                  label: 'Bank Transfer',
                  icon: Icons.account_balance_rounded,
                  selected: _selectedRequestMode == 'bank',
                  color: AppTheme.info,
                  enabled: enabled,
                  onTap: () => setState(() => _selectedRequestMode = 'bank'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                    _selectedRequestMode == 'upi'
                        ? Icons.verified_outlined
                        : Icons.account_balance_wallet_outlined,
                    color: _selectedRequestMode == 'upi'
                        ? AppTheme.success
                        : AppTheme.info,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedRequestMode == 'upi'
                        ? 'Supplier UPI account will be used for request payment.'
                        : 'Supplier bank account will be used for request payment.',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: enabled ? _submitSupplierPaymentRequest : null,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit Request Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestModeTile({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected && enabled
              ? color.withValues(alpha: 0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected && enabled ? color : AppTheme.border,
            width: selected && enabled ? 1.6 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected && enabled ? color : AppTheme.textMuted),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: selected && enabled ? color : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierRequestTable() {
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
          const Text('Supplier Request Payment Table',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Only request payment entries are shown here.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          if (_paymentRequests.isEmpty)
            const Text('No supplier payment requests generated yet.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 76,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Request ID')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Batches')),
                  DataColumn(label: Text('Bill Amount')),
                  DataColumn(label: Text('Request Amount')),
                  DataColumn(label: Text('Method')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Payment Proof')),
                ],
                rows: _paymentRequests.map((request) {
                  final completed = request.status == 'Completed';
                  return DataRow(
                    cells: [
                      DataCell(Text(request.id,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(Text(request.supplierName,
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(request.requestType,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(Text(
                          request.batchIds.isEmpty
                              ? '-'
                              : request.batchIds.join(', '),
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_formatCurrency(request.billAmount),
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_formatCurrency(request.amount),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w900))),
                      DataCell(Text(request.method,
                          style: const TextStyle(fontSize: 12))),
                      DataCell(
                        completed
                            ? _smallSupplierChip('Completed', AppTheme.success)
                            : TextButton.icon(
                                onPressed: () =>
                                    _completeSupplierRequest(request),
                                icon: const Icon(Icons.verified_outlined,
                                    size: 15),
                                label: const Text('Requested'),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.warning),
                              ),
                      ),
                      DataCell(
                        completed
                            ? _buildSupplierProof(
                                request.paymentProof ?? 'Payment proof')
                            : const Text('Visible after completion',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSupplierProof(String proofId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, size: 16, color: AppTheme.success),
          const SizedBox(width: 6),
          Text(
            proofId,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.success,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  void _submitSupplierPaymentRequest() {
    if (_selectedSupplier == null ||
        _selectedBatchIds.isEmpty ||
        _selectedPayableAmount <= 0) return;

    final request = SupplierBillPaymentRequest(
      id: 'SUP-REQ-${(_paymentRequests.length + 1).toString().padLeft(3, '0')}',
      supplierName: _selectedSupplier!,
      batchIds: _selectedBatchIds.toList(),
      amount: _selectedPayableAmount,
      billAmount: _selectedTotalAmount,
      requestType: 'Supplier Bill',
      requestedAt: DateTime.now(),
      method: _selectedRequestMode == 'upi' ? 'UPI' : 'Bank Transfer',
    );

    setState(() {
      _paymentRequests.add(request);
      _selectedBatchIds.clear();
      _expandedBatchIds.clear();
    });
    _notifySupplierPaymentSnapshotChanged();

    // Persist so HOD/finance on other devices see the request in realtime.
    if (widget.siteId != null && widget.siteId!.isNotEmpty) {
      _paymentRepo
          .insertPaymentRequest(SupplierPaymentRequestRow(
            siteId: widget.siteId,
            supplierName: request.supplierName,
            batchIds: request.batchIds,
            amount: request.amount,
            billAmount: request.billAmount,
            usedAmount: request.usedAmount,
            requestType: request.requestType,
            method: request.method,
            status: request.status,
            requestedAt: request.requestedAt,
          ))
          .then((row) {
            // Adopt the DB id so completion/status updates hit the row
            // even before a realtime reload replaces the list.
            if (row != null && row.id != null && row.id!.isNotEmpty) {
              request.id = row.id!;
            }
          });
    }

    _showSupplierSnack(
        'Supplier bill balance request sent to finance team', AppTheme.success);
  }

  void _completeSupplierRequest(SupplierBillPaymentRequest request) {
    final proofId = 'PROOF-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      request.status = 'Completed';
      request.paymentProof = proofId;
    });
    _notifySupplierPaymentSnapshotChanged();

    // Persist the completion so it syncs to other devices.
    if (request.id.isNotEmpty &&
        !request.id.startsWith('SUP-REQ-')) {
      _paymentRepo.updatePaymentRequest(
        request.id,
        status: 'Completed',
        paymentProof: proofId,
      );
    }
    _showSupplierSnack(
        'Supplier payment completed. Proof unlocked.', AppTheme.success);
  }

  void _showSupplierSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}


// ==================== TAB 5: FULL ATTENDANCE HISTORY ====================
class AttendanceHistoryRow {
  final DateTime date;
  final String section;
  final String referenceId;
  final String title;
  final String status;
  final String method;
  final double? amount;
  final String details;

  AttendanceHistoryRow({
    required this.date,
    required this.section,
    required this.referenceId,
    required this.title,
    required this.status,
    this.method = '-',
    this.amount,
    required this.details,
  });
}

class AttendanceHistoryTab extends StatefulWidget {
  final List<Worker> regularWorkers;
  final List<AttendanceWorkerProfile> regularAttendanceSnapshot;
  final List<OutsideWorker> outsideWorkers;
  final List<WorkerBatch> confirmedBatches;
  final List<MachineWorkerGroup> machineWorkerGroups;
  final List<PermanentWorkerPaymentAccount> paymentAccounts;
  final List<SupplierBillPaymentRequest> supplierPaymentRequests;

  const AttendanceHistoryTab({
    super.key,
    required this.regularWorkers,
    required this.regularAttendanceSnapshot,
    required this.outsideWorkers,
    required this.confirmedBatches,
    required this.machineWorkerGroups,
    required this.paymentAccounts,
    required this.supplierPaymentRequests,
  });

  @override
  State<AttendanceHistoryTab> createState() => _AttendanceHistoryTabState();
}

class _AttendanceHistoryTabState extends State<AttendanceHistoryTab> {
  DateTime _selectedDay = DateTime.now();
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatMoney(double? value) {
    if (value == null) return '-';
    return '₹${value.toStringAsFixed(0)}';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<AttendanceHistoryRow> get _allRows {
    final now = DateTime.now();
    final rows = <AttendanceHistoryRow>[];

    final attendanceRows = widget.regularAttendanceSnapshot.isNotEmpty
        ? widget.regularAttendanceSnapshot
        : widget.regularWorkers
            .map((worker) => AttendanceWorkerProfile(
                  id: worker.id,
                  name: worker.name,
                  department: worker.department,
                  baseStatus: worker.status,
                  attendanceStatus: worker.status == 'leave' ? 'Leave' : 'Not Marked',
                ))
            .toList();

    for (final worker in attendanceRows) {
      rows.add(
        AttendanceHistoryRow(
          date: worker.checkInTime ?? now,
          section: 'Regular',
          referenceId: worker.id,
          title: worker.name,
          status: worker.attendanceStatus,
          method: worker.checkInMethod ?? '-',
          details:
              'Dept: ${worker.department} • Check In: ${_formatTime(worker.checkInTime)} • Check Out: ${_formatTime(worker.checkOutTime)} • Out Method: ${worker.checkOutMethod ?? '-'}',
        ),
      );
      if (worker.checkOutTime != null) {
        rows.add(
          AttendanceHistoryRow(
            date: worker.checkOutTime!,
            section: 'Check Out',
            referenceId: worker.id,
            title: worker.name,
            status: 'Checked Out',
            method: worker.checkOutMethod ?? '-',
            details:
                'Manual/automatic checkout recorded at ${_formatTime(worker.checkOutTime)} after check-in ${_formatTime(worker.checkInTime)}',
          ),
        );
      }
    }

    for (final worker in widget.outsideWorkers) {
      rows.add(
        AttendanceHistoryRow(
          date: now,
          section: 'Outside',
          referenceId: worker.id,
          title: worker.name,
          status: worker.attendanceStatus,
          amount: double.tryParse(worker.wage),
          details:
              'Supplier: ${worker.supplier ?? '-'} • Session: ${worker.sessionType} • Food: ${worker.foodOptIn ? 'Yes' : 'No'} • Geo: ${worker.geoLocation ?? '-'}',
        ),
      );
    }

    for (final batch in widget.confirmedBatches) {
      rows.add(
        AttendanceHistoryRow(
          date: batch.createdAt,
          section: 'Batches',
          referenceId: batch.batchId,
          title: batch.supplier,
          status: batch.shiftState.name,
          method: batch.sessionType,
          details:
              '${batch.workers.length} worker(s) • Photo: ${batch.photoPath ?? '-'} • End photo: ${batch.endShiftPhotoPath ?? '-'} • Geo: ${batch.geoLocation ?? '-'}',
        ),
      );
    }

    for (final group in widget.machineWorkerGroups) {
      rows.add(
        AttendanceHistoryRow(
          date: now,
          section: 'Machine',
          referenceId: group.machineId,
          title: group.machineName,
          status: '${group.workerCount} worker(s)',
          details: 'Machine worker group used for attendance and food count.',
        ),
      );
    }

    for (final account in widget.paymentAccounts) {
      rows.add(
        AttendanceHistoryRow(
          date: account.paidAt ?? account.paymentMonth,
          section: 'Payments',
          referenceId: account.workerId,
          title: account.name,
          status: account.isPaid ? 'Paid' : 'Open',
          amount: account.balanceAmount,
          details:
              'Monthly: ${_formatMoney(account.monthlyAmount)} • Used: ${_formatMoney(account.usedAmount)} • Paid: ${_formatMoney(account.paidAmount)} • Days: ${account.daysWorked}',
        ),
      );
      for (final entry in account.ledger) {
        rows.add(
          AttendanceHistoryRow(
            date: entry.date,
            section: entry.type.contains('used') ? 'Used Amount' : 'Payments',
            referenceId: entry.id,
            title: account.name,
            status: entry.status,
            method: entry.method,
            amount: entry.amount,
            details:
                '${entry.note} • Proof: ${entry.proofId ?? '-'} • Book: ${entry.registeredInMachineIdsBook ? 'Yes' : 'No'}',
          ),
        );
      }
    }

    for (final request in widget.supplierPaymentRequests) {
      rows.add(
        AttendanceHistoryRow(
          date: request.requestedAt,
          section: 'Supplier Bills',
          referenceId: request.id,
          title: request.supplierName,
          status: request.status,
          method: request.method,
          amount: request.amount,
          details:
              '${request.requestType} • Batches: ${request.batchIds.join(', ')} • Bill: ${_formatMoney(request.billAmount)} • Used: ${_formatMoney(request.usedAmount)} • Proof: ${request.paymentProof ?? '-'}',
        ),
      );
    }

    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  List<AttendanceHistoryRow> get _filteredRows {
    final q = _searchController.text.trim().toLowerCase();
    return _allRows.where((row) {
      final matchesDate = _sameDay(row.date, _selectedDay);
      final matchesFilter = _selectedFilter == 'All' || row.section == _selectedFilter;
      final matchesSearch = q.isEmpty ||
          row.title.toLowerCase().contains(q) ||
          row.referenceId.toLowerCase().contains(q) ||
          row.status.toLowerCase().contains(q) ||
          row.details.toLowerCase().contains(q);
      return matchesDate && matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHistoryHeader(),
                const SizedBox(height: 14),
                _buildCalendarStrip(),
                const SizedBox(height: 12),
                _buildSearchAndFilters(),
                const SizedBox(height: 14),
                _buildHistoryStats(rows),
                const SizedBox(height: 14),
                _buildHistoryTable(rows),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance History',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Calendar-wise table for regular, outside, payments and supplier data',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDay,
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _selectedDay = picked);
            },
            icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip() {
    final days = List.generate(7, (index) => DateTime.now().subtract(Duration(days: index))).reversed.toList();
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = _sameDay(day, _selectedDay);
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(colors: [AppTheme.primary, AppTheme.accent])
                    : null,
                color: selected ? null : AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
                boxShadow: selected ? AppTheme.cardShadow : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? Colors.white70 : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final filters = [
      'All',
      'Regular',
      'Check Out',
      'Outside',
      'Batches',
      'Machine',
      'Payments',
      'Used Amount',
      'Supplier Bills',
    ];
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search by worker, ID, status or payment reference...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final selected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  label: Text(filter,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppTheme.textSecondary)),
                  selectedColor: AppTheme.primary,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryStats(List<AttendanceHistoryRow> rows) {
    final totalAmount = rows.fold<double>(0, (sum, row) => sum + (row.amount ?? 0));
    return Row(
      children: [
        _historyMiniCard('Rows', '${rows.length}', AppTheme.primary, Icons.table_chart_rounded),
        const SizedBox(width: 8),
        _historyMiniCard('Present', '${rows.where((r) => r.status == 'Present').length}', AppTheme.success, Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _historyMiniCard('Pending', '${rows.where((r) => r.status.contains('Requested') || r.status.contains('Open')).length}', AppTheme.warning, Icons.pending_actions_rounded),
        const SizedBox(width: 8),
        _historyMiniCard('Amount', _formatMoney(totalAmount), AppTheme.info, Icons.currency_rupee_rounded),
      ],
    );
  }

  Widget _historyMiniCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTable(List<AttendanceHistoryRow> rows) {
    if (rows.isEmpty) {
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
            Icon(Icons.history_toggle_off_rounded, size: 42, color: AppTheme.textMuted),
            SizedBox(height: 10),
            Text('No history found for the selected date/filter.',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 76,
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Section')),
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Name / Title')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Method')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Details')),
          ],
          rows: rows.map((row) {
            return DataRow(
              cells: [
                DataCell(Text(_formatDate(row.date), style: const TextStyle(fontSize: 12))),
                DataCell(Text(_formatTime(row.date), style: const TextStyle(fontSize: 12))),
                DataCell(_sectionChip(row.section)),
                DataCell(Text(row.referenceId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                DataCell(SizedBox(width: 150, child: Text(row.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))) ,
                DataCell(Text(row.status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                DataCell(Text(row.method, style: const TextStyle(fontSize: 12))),
                DataCell(Text(_formatMoney(row.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                DataCell(SizedBox(width: 260, child: Text(row.details, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _sectionChip(String section) {
    final color = section == 'Regular'
        ? AppTheme.success
        : section == 'Check Out'
            ? AppTheme.warning
            : section == 'Payments' || section == 'Used Amount'
                ? AppTheme.info
                : section == 'Supplier Bills'
                    ? AppTheme.primary
                    : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(section,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ==================== REAL CAMERA CAPTURE DIALOG ====================
/// Full-screen camera capture dialog used by outside-worker and manual
/// attendance photo flows. Opens the real system camera via ImagePicker,
/// previews the captured image, and returns the raw bytes on confirm.
class _PhotoCaptureDialog extends StatefulWidget {
  final String title;

  const _PhotoCaptureDialog({required this.title});

  @override
  State<_PhotoCaptureDialog> createState() => _PhotoCaptureDialogState();
}

class _PhotoCaptureDialogState extends State<_PhotoCaptureDialog> {
  Uint8List? _bytes;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (_) {
      photo = null;
    }
    if (!mounted) return;
    if (photo == null) {
      setState(() => _capturing = false);
      return; // user cancelled the camera
    }
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _capturing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Preview area
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _bytes != null ? AppTheme.success : AppTheme.border,
                  width: 1.4,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _bytes != null
                  ? Image.memory(
                      _bytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : _capturing
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Opening camera...',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.no_photography_outlined,
                                  size: 44, color: AppTheme.textMuted),
                              const SizedBox(height: 10),
                              const Text(
                                'No photo captured yet',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              TextButton.icon(
                                onPressed: _capture,
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('Open Camera'),
                              ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 14),
            if (_bytes == null)
              const Text(
                'A clear photo is required as attendance proof.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppTheme.success, size: 16),
                    SizedBox(width: 6),
                    Text('Photo captured — ready to save',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.success)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _capturing ? null : _capture,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _bytes == null || _capturing
                        ? null
                        : () => Navigator.pop(context, _bytes),
                    icon: const Icon(Icons.save_alt_rounded, size: 18),
                    label: const Text('Use Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
}
