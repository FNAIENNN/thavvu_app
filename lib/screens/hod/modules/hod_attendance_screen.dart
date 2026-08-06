// lib/screens/hod_attendence_screen.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/attendance_models.dart';
import '../../../services/attendance_repository.dart';
import '../../../services/attendance_context_service.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

// ==================== HOD REVIEW MODELS ====================

class HodWorker {
  final String id;
  final String name;
  final String department;
  final String baseStatus;
  final String attendanceStatus;
  final String? checkInMethod;
  final String? checkOutMethod;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final bool isTemporary;
  final String? tempId;
  final String? aadharNumber;
  final String? faceId;
  final String? biometricId;
  final String? referralName;
  final String? joiningDate;
  final bool geofenceVerified;
  final String? hodRemark;
  final String hodApprovalStatus; // 'pending', 'approved', 'rejected'

  HodWorker({
    required this.id,
    required this.name,
    required this.department,
    required this.baseStatus,
    required this.attendanceStatus,
    this.checkInMethod,
    this.checkOutMethod,
    this.checkInTime,
    this.checkOutTime,
    this.isTemporary = false,
    this.tempId,
    this.aadharNumber,
    this.faceId,
    this.biometricId,
    this.referralName,
    this.joiningDate,
    this.geofenceVerified = true,
    this.hodRemark,
    this.hodApprovalStatus = 'pending',
  });

  bool get isCheckedIn => checkInTime != null && attendanceStatus == 'Present';
  bool get isCheckedOut => checkOutTime != null;
}

class HodOutsideWorker {
  final String id;
  final String name;
  final String wage;
  final String sessionType;
  final String attendanceStatus;
  final String? supplier;
  final String? photoEntryPath;
  final String? photoExitPath;
  final String? geoLocation;
  final String? afternoonPhotoPath;
  final bool? isAfternoonContinued;
  final bool isOnLeave;
  final bool foodOptIn;
  final String? halfDayPhotoPath;

  HodOutsideWorker({
    required this.id,
    required this.name,
    required this.wage,
    required this.sessionType,
    required this.attendanceStatus,
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
}

enum HodBatchShiftState {
  active,
  pendingContinuation,
  fullDayActive,
  shiftEnded,
  pendingEndShift,
}

class HodWorkerBatch {
  final int batchNumber;
  final String batchId;
  final String supplier;
  final String sessionType;
  final List<HodOutsideWorker> workers;
  final String? photoPath;
  final String? geoLocation;
  final DateTime createdAt;
  final HodBatchShiftState shiftState;
  final String? continuationPhotoPath;
  final String? endShiftPhotoPath;
  final String? endShiftGeoLocation;
  final String hodApprovalStatus;

  HodWorkerBatch({
    required this.batchNumber,
    required this.batchId,
    required this.supplier,
    required this.sessionType,
    required this.workers,
    this.photoPath,
    this.geoLocation,
    required this.createdAt,
    required this.shiftState,
    this.continuationPhotoPath,
    this.endShiftPhotoPath,
    this.endShiftGeoLocation,
    this.hodApprovalStatus = 'pending',
  });
}

class HodPaymentLedgerEntry {
  final String id;
  final String type;
  final double amount;
  final DateTime date;
  final String status;
  final String method;
  final String note;
  final String? proofId;
  final bool registeredInMachineIdsBook;

  HodPaymentLedgerEntry({
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
}

class HodPermanentWorkerPayment {
  final String id;
  final String workerId;
  final String name;
  final String department;
  final int daysWorked;
  final double monthlyAmount;
  final double usedAmount;
  final double paidAmount;
  final DateTime paymentMonth;
  final bool isPaid;
  final DateTime? paidAt;
  final List<HodPaymentLedgerEntry> ledger;
  final String hodApprovalStatus;

  HodPermanentWorkerPayment({
    required this.id,
    required this.workerId,
    required this.name,
    required this.department,
    required this.daysWorked,
    required this.monthlyAmount,
    required this.usedAmount,
    required this.paidAmount,
    required this.paymentMonth,
    required this.isPaid,
    this.paidAt,
    required this.ledger,
    this.hodApprovalStatus = 'pending',
  });

  double get balanceAmount => (monthlyAmount - usedAmount - paidAmount)
      .clamp(0, double.infinity)
      .toDouble();
}

class HodSupplierBillRequest {
  final String id;
  final String supplierName;
  final List<String> batchIds;
  final double amount;
  final double billAmount;
  final DateTime requestedAt;
  final String method;
  final String requestType;
  final String status;
  final String? paymentProof;
  final String hodApprovalStatus;

  HodSupplierBillRequest({
    required this.id,
    required this.supplierName,
    required this.batchIds,
    required this.amount,
    required this.billAmount,
    required this.requestedAt,
    required this.method,
    required this.requestType,
    required this.status,
    this.paymentProof,
    this.hodApprovalStatus = 'pending',
  });
}

// ==================== MAIN HOD ATTENDANCE SCREEN ====================

class HodAttendanceScreen extends StatefulWidget {
  final String title;
  final String moduleFilter;

  const HodAttendanceScreen({
    super.key,
    required this.title,
    required this.moduleFilter,
  });

  @override
  State<HodAttendanceScreen> createState() => _HodAttendanceScreenState();
}

class _HodAttendanceScreenState extends State<HodAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late List<HodWorker> _workers;
  late List<HodOutsideWorker> _outsideWorkers;
  List<HodWorkerBatch> _confirmedBatches = [];
  late List<HodPermanentWorkerPayment> _paymentWorkers;
  late List<HodSupplierBillRequest> _supplierRequests;

  // Backend (Supabase) integration
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  String? _siteId;
  DateTime _selectedDate = DateTime.now();
  bool _loadingBackend = true;
  final Map<String, String> _recordIds = {}; // workerId -> attendance record id
  final Map<String, String> _batchIds = {}; // ui batchId -> db batch id

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _seedAllData();
    _loadFromBackend();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _seedAllData() {
    // No demo workers. Real workers/records load from Supabase in
    // [_loadFromBackend]; lists start empty so no fabricated data ever shows.
    _workers = [];
    _outsideWorkers = [];
    _confirmedBatches = [];
    _supplierRequests = [];
  }

  // ── Computed getters ──
  List<HodWorker> get _presentWorkers =>
      _workers.where((w) => w.attendanceStatus == 'Present').toList();
  List<HodWorker> get _absentWorkers =>
      _workers.where((w) => w.attendanceStatus == 'Absent').toList();
  List<HodWorker> get _leaveWorkers =>
      _workers.where((w) => w.attendanceStatus == 'Leave').toList();
  List<HodWorker> get _tempWorkers =>
      _workers.where((w) => w.isTemporary).toList();
  List<HodWorker> get _pendingApprovalWorkers =>
      _workers.where((w) => w.hodApprovalStatus == 'pending').toList();
  List<HodWorker> get _geofenceViolationWorkers =>
      _workers.where((w) => !w.geofenceVerified).toList();

  double get _totalEarned =>
      _paymentWorkers.fold(0.0, (s, w) => s + w.monthlyAmount);
  double get _totalUsed =>
      _paymentWorkers.fold(0.0, (s, w) => s + w.usedAmount);
  double get _totalBalance =>
      _paymentWorkers.fold(0.0, (s, w) => s + w.balanceAmount);
  int get _paidWorkers => _paymentWorkers.where((w) => w.isPaid).length;

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

  /// Load real attendance data from Supabase (replaces mock workers/batches).
  Future<void> _loadFromBackend() async {
    _siteId = await _contextService.resolveSiteId();
    final workers = await _attendanceRepo.fetchWorkers(siteId: _siteId);
    final records =
        await _attendanceRepo.fetchAttendance(_selectedDate, siteId: _siteId);
    final batches =
        await _attendanceRepo.fetchBatches(_selectedDate, siteId: _siteId);

    if (!mounted) return;

    final recordByWorker = <String, AttendanceRecord>{};
    _recordIds.clear();
    for (final r in records) {
      recordByWorker[r.workerId] = r;
      if (r.id != null) _recordIds[r.workerId] = r.id!;
    }

    setState(() {
      _workers = workers.map((w) {
        final rec = recordByWorker[w.id];
        return HodWorker(
          id: w.id,
          name: w.name,
          department: w.department ?? '',
          baseStatus: w.status,
          attendanceStatus: rec?.status ?? 'Not Marked',
          checkInMethod: rec?.checkInMethod,
          checkOutMethod: rec?.checkOutMethod,
          checkInTime: rec?.checkInTime,
          checkOutTime: rec?.checkOutTime,
          isTemporary: w.isTemporary,
          aadharNumber: w.aadharNumber,
          faceId: w.faceId,
          biometricId: w.biometricId,
          joiningDate: w.joiningDate != null
              ? '${w.joiningDate!.year.toString().padLeft(4, '0')}-'
                  '${w.joiningDate!.month.toString().padLeft(2, '0')}-'
                  '${w.joiningDate!.day.toString().padLeft(2, '0')}'
              : null,
          geofenceVerified: true,
          hodRemark: rec?.hodRemark,
          hodApprovalStatus: rec?.hodApprovalStatus ?? 'pending',
        );
      }).toList();

      _outsideWorkers = [];
      _confirmedBatches = [];
      _batchIds.clear();
      for (final batch in batches) {
        final uiBatch = HodWorkerBatch(
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
          hodApprovalStatus: batch.hodApprovalStatus,
          workers: batch.workers.map((bw) {
            final w = HodOutsideWorker(
              id: bw.id ?? '',
              name: bw.name,
              wage: (bw.wage ?? 0).toStringAsFixed(0),
              sessionType: batch.sessionType,
              attendanceStatus: bw.attendanceStatus,
              supplier: batch.supplier,
              foodOptIn: bw.foodOptIn,
            );
            _outsideWorkers.add(w);
            return w;
          }).toList(),
        );
        _confirmedBatches.add(uiBatch);
        if (batch.id != null) _batchIds[uiBatch.batchId] = batch.id!;
      }

      _loadingBackend = false;
    });
  }

  HodBatchShiftState _mapShiftState(String state) {
    switch (state) {
      case 'pendingContinuation':
        return HodBatchShiftState.pendingContinuation;
      case 'fullDayActive':
        return HodBatchShiftState.fullDayActive;
      case 'shiftEnded':
        return HodBatchShiftState.shiftEnded;
      case 'pendingEndShift':
        return HodBatchShiftState.pendingEndShift;
      default:
        return HodBatchShiftState.active;
    }
  }

  void _approveWorker(HodWorker worker) {
    setState(() {
      final index = _workers.indexOf(worker);
      _workers[index] = HodWorker(
        id: worker.id,
        name: worker.name,
        department: worker.department,
        baseStatus: worker.baseStatus,
        attendanceStatus: worker.attendanceStatus,
        checkInMethod: worker.checkInMethod,
        checkOutMethod: worker.checkOutMethod,
        checkInTime: worker.checkInTime,
        checkOutTime: worker.checkOutTime,
        isTemporary: worker.isTemporary,
        tempId: worker.tempId,
        aadharNumber: worker.aadharNumber,
        faceId: worker.faceId,
        biometricId: worker.biometricId,
        referralName: worker.referralName,
        joiningDate: worker.joiningDate,
        geofenceVerified: true,
        hodRemark: worker.hodRemark,
        hodApprovalStatus: 'approved',
      );
    });
    final recordId = _recordIds[worker.id];
    if (recordId != null) {
      _attendanceRepo.approveRecord(recordId, status: 'approved');
    }
    _showSnackbar('${worker.name} attendance approved', AppTheme.success);
  }

  void _rejectWorker(HodWorker worker, String remark) {
    setState(() {
      final index = _workers.indexOf(worker);
      _workers[index] = HodWorker(
        id: worker.id,
        name: worker.name,
        department: worker.department,
        baseStatus: worker.baseStatus,
        attendanceStatus: worker.attendanceStatus,
        checkInMethod: worker.checkInMethod,
        checkOutMethod: worker.checkOutMethod,
        checkInTime: worker.checkInTime,
        checkOutTime: worker.checkOutTime,
        isTemporary: worker.isTemporary,
        tempId: worker.tempId,
        aadharNumber: worker.aadharNumber,
        faceId: worker.faceId,
        biometricId: worker.biometricId,
        referralName: worker.referralName,
        joiningDate: worker.joiningDate,
        geofenceVerified: worker.geofenceVerified,
        hodRemark: remark,
        hodApprovalStatus: 'rejected',
      );
    });
    final recordId = _recordIds[worker.id];
    if (recordId != null) {
      _attendanceRepo.approveRecord(recordId, status: 'rejected', remark: remark);
    }
    _showSnackbar('${worker.name} attendance rejected', AppTheme.danger);
  }

  void _approveBatch(HodWorkerBatch batch) {
    setState(() {
      final index = _confirmedBatches.indexOf(batch);
      _confirmedBatches[index] = HodWorkerBatch(
        batchNumber: batch.batchNumber,
        batchId: batch.batchId,
        supplier: batch.supplier,
        sessionType: batch.sessionType,
        workers: batch.workers,
        photoPath: batch.photoPath,
        geoLocation: batch.geoLocation,
        createdAt: batch.createdAt,
        shiftState: batch.shiftState,
        continuationPhotoPath: batch.continuationPhotoPath,
        endShiftPhotoPath: batch.endShiftPhotoPath,
        endShiftGeoLocation: batch.endShiftGeoLocation,
        hodApprovalStatus: 'approved',
      );
    });
    final dbBatchId = _batchIds[batch.batchId];
    if (dbBatchId != null) {
      _attendanceRepo.approveBatch(dbBatchId, status: 'approved');
    }
    _showSnackbar('Batch #${batch.batchNumber} approved', AppTheme.success);
  }

  void _approvePayment(HodPermanentWorkerPayment payment) {
    setState(() {
      final index = _paymentWorkers.indexOf(payment);
      _paymentWorkers[index] = HodPermanentWorkerPayment(
        id: payment.id,
        workerId: payment.workerId,
        name: payment.name,
        department: payment.department,
        daysWorked: payment.daysWorked,
        monthlyAmount: payment.monthlyAmount,
        usedAmount: payment.usedAmount,
        paidAmount: payment.paidAmount,
        paymentMonth: payment.paymentMonth,
        isPaid: payment.isPaid,
        paidAt: payment.paidAt,
        ledger: payment.ledger,
        hodApprovalStatus: 'approved',
      );
    });
    _showSnackbar('${payment.name} payment approved', AppTheme.success);
  }

  void _approveSupplierRequest(HodSupplierBillRequest request) {
    setState(() {
      final index = _supplierRequests.indexOf(request);
      _supplierRequests[index] = HodSupplierBillRequest(
        id: request.id,
        supplierName: request.supplierName,
        batchIds: request.batchIds,
        amount: request.amount,
        billAmount: request.billAmount,
        requestedAt: request.requestedAt,
        method: request.method,
        requestType: request.requestType,
        status: request.status,
        paymentProof: request.paymentProof,
        hodApprovalStatus: 'approved',
      );
    });
    _showSnackbar('Supplier request ${request.id} approved', AppTheme.success);
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: widget.title,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          tooltip: 'Pick date',
          icon: const Icon(Icons.calendar_today, size: 20),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
              _loadFromBackend();
            }
          },
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _loadFromBackend,
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text(
                'HOD • ${_selectedDate.day}/${_selectedDate.month}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Review'),
        Tab(text: 'Outside'),
        Tab(text: 'Payments'),
        Tab(text: 'Bills'),
      ],
      header: _buildHeader(),
      body: _loadingBackend
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading attendance from server...',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceReviewTab(),
                _buildOutsideWorkersReviewTab(),
                _buildPaymentsReviewTab(),
                _buildSupplierBillsReviewTab(),
              ],
            ),
    );
  }

  // ==================== HEADER ====================
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
                    Text('HOD Review Panel',
                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text('Attendance Admin Review',
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
          _buildStatsRow(),
          const SizedBox(height: 10),
          _buildPendingApprovalsBar(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Present', '${_presentWorkers.length}', AppTheme.success,
            Icons.check_circle),
        const SizedBox(width: 12),
        _buildStatCard('Absent', '${_absentWorkers.length}', AppTheme.danger,
            Icons.cancel),
        const SizedBox(width: 12),
        _buildStatCard('Leave', '${_leaveWorkers.length}', AppTheme.info,
            Icons.beach_access),
        const SizedBox(width: 12),
        _buildStatCard('Temp ID', '${_tempWorkers.length}', AppTheme.warning,
            Icons.badge_outlined),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String count, Color color, IconData icon) {
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovalsBar() {
    final pendingCount = _pendingApprovalWorkers.length +
        _confirmedBatches
            .where((b) => b.hodApprovalStatus == 'pending')
            .length +
        _paymentWorkers.where((p) => p.hodApprovalStatus == 'pending').length +
        _supplierRequests.where((r) => r.hodApprovalStatus == 'pending').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: pendingCount > 0
            ? AppTheme.warning.withValues(alpha: 0.2)
            : AppTheme.success.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: pendingCount > 0
                ? AppTheme.warning.withValues(alpha: 0.4)
                : AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(pendingCount > 0 ? Icons.pending_actions : Icons.verified,
              color: pendingCount > 0 ? AppTheme.warning : AppTheme.success,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? '$pendingCount pending approval(s) across all tabs'
                  : 'All entries approved',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pendingCount > 0 ? AppTheme.warning : AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: ATTENDANCE REVIEW ====================
  Widget _buildAttendanceReviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ──
          Container(
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
                      const Text('Mark Attendance (HOD Review)',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        '${_presentWorkers.length} present • ${_absentWorkers.length} absent • ${_leaveWorkers.length} leave • ${_tempWorkers.length} temp',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                _buildApprovalBadge(
                    '${_pendingApprovalWorkers.length}', AppTheme.warning),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Check-in / Check-out data card ──
          _buildAttendanceDataCard(),
          const SizedBox(height: 16),

          // ── Today's attendance result summary ──
          _buildAttendanceResultSummary(),
          const SizedBox(height: 16),

          // ── Pending approval list ──
          if (_pendingApprovalWorkers.isNotEmpty) ...[
            _buildPendingApprovalSection(),
            const SizedBox(height: 16),
          ],

          // ── Geofence violations ──
          if (_geofenceViolationWorkers.isNotEmpty) ...[
            _buildGeofenceViolationSection(),
            const SizedBox(height: 16),
          ],

          // ── Full worker list ──
          _buildFullWorkerList(),
        ],
      ),
    );
  }

  Widget _buildApprovalBadge(String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top, size: 14, color: color),
          const SizedBox(width: 4),
          Text('$count pending',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildAttendanceDataCard() {
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
              const Icon(Icons.history_rounded, color: AppTheme.info, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Check-In / Check-Out Data',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              _statusBadge('Read Only', AppTheme.info),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Supervisor submitted attendance data. HOD can review, approve, or reject entries.',
            style: TextStyle(
                fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),

          // ── Operation methods stats ──
          Row(
            children: [
              _buildOperationStat(
                  'Face Recognition',
                  _workers
                      .where((w) => w.checkInMethod == 'Face Recognition')
                      .length,
                  AppTheme.success,
                  Icons.face_retouching_natural),
              const SizedBox(width: 8),
              _buildOperationStat(
                  'Biometric',
                  _workers.where((w) => w.checkInMethod == 'Biometric').length,
                  AppTheme.primary,
                  Icons.fingerprint),
              const SizedBox(width: 8),
              _buildOperationStat(
                  'Manual + Photo',
                  _workers
                      .where((w) => w.checkInMethod == 'Manual + Photo')
                      .length,
                  AppTheme.warning,
                  Icons.add_a_photo),
            ],
          ),
          const SizedBox(height: 16),

          // ── Worker check-in/out data rows ──
          ..._workers.where((w) => w.isCheckedIn).map((worker) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: worker.geofenceVerified
                      ? AppTheme.success.withValues(alpha: 0.3)
                      : AppTheme.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.success.withValues(alpha: 0.12),
                    child: Icon(
                        worker.isTemporary
                            ? Icons.badge_outlined
                            : Icons.person,
                        color: AppTheme.success,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(worker.name,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis),
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
                                child: Text(worker.tempId ?? 'TEMP',
                                    style: const TextStyle(
                                        fontSize: 9.5,
                                        color: AppTheme.warning,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${worker.id} • ${worker.department}',
                          style: const TextStyle(
                              fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _infoChip(
                                Icons.login_rounded,
                                '${worker.checkInMethod ?? '--'} • ${_formatTime(worker.checkInTime)}',
                                AppTheme.success),
                            if (worker.checkOutTime != null) ...[
                              const SizedBox(width: 6),
                              _infoChip(
                                  Icons.logout_rounded,
                                  '${worker.checkOutMethod ?? '--'} • ${_formatTime(worker.checkOutTime)}',
                                  AppTheme.info),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!worker.geofenceVerified)
                        _statusBadge('Geofence Alert', AppTheme.danger)
                      else
                        _statusBadge('Verified', AppTheme.success),
                      const SizedBox(height: 4),
                      _hodApprovalChip(worker.hodApprovalStatus),
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

  Widget _buildOperationStat(
      String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text('$count',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _hodApprovalChip(String status) {
    switch (status) {
      case 'approved':
        return _statusBadge('✓ Approved', AppTheme.success);
      case 'rejected':
        return _statusBadge('✗ Rejected', AppTheme.danger);
      default:
        return _statusBadge('Pending', AppTheme.warning);
    }
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
              _buildMiniStat(
                  'Present', _presentWorkers.length, AppTheme.success),
              const SizedBox(width: 8),
              _buildMiniStat('Absent', _absentWorkers.length, AppTheme.danger),
              const SizedBox(width: 8),
              _buildMiniStat('Leave', _leaveWorkers.length, AppTheme.info),
              const SizedBox(width: 8),
              _buildMiniStat('Temp', _tempWorkers.length, AppTheme.warning),
            ],
          ),
          const SizedBox(height: 16),
          _buildWorkerSummaryGroup(
              'Present Workers', _presentWorkers, AppTheme.success),
          const SizedBox(height: 10),
          _buildWorkerSummaryGroup(
              'Absent Workers', _absentWorkers, AppTheme.danger),
          const SizedBox(height: 10),
          _buildWorkerSummaryGroup(
              'Leave Workers', _leaveWorkers, AppTheme.info),
          if (_tempWorkers.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildWorkerSummaryGroup(
                'Temporary ID Workers', _tempWorkers, AppTheme.warning),
          ],
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
            Text('$count',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerSummaryGroup(
      String title, List<HodWorker> workers, Color color) {
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
            const Text('No workers',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted))
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
                          size: 14),
                      const SizedBox(width: 5),
                      Text(
                        worker.isTemporary
                            ? '${worker.name} (${worker.tempId})'
                            : worker.name,
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

  Widget _buildPendingApprovalSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions,
                  color: AppTheme.warning, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Pending HOD Approvals',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              _statusBadge('${_pendingApprovalWorkers.length} pending',
                  AppTheme.warning),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Review each worker attendance entry. Approve or reject with remarks.',
            style: TextStyle(
                fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          ..._pendingApprovalWorkers.map((worker) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppTheme.warning.withValues(alpha: 0.12),
                        child: Icon(
                            worker.isTemporary
                                ? Icons.badge_outlined
                                : Icons.person,
                            color: AppTheme.warning,
                            size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(worker.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800)),
                            Text('${worker.id} • ${worker.department}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      _statusBadge(worker.attendanceStatus,
                          _attendanceStatusColor(worker.attendanceStatus)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Check-In: ${worker.checkInMethod ?? 'N/A'} at ${_formatTime(worker.checkInTime)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.info,
                                fontWeight: FontWeight.w600)),
                        if (worker.checkOutTime != null)
                          Text(
                              'Check-Out: ${worker.checkOutMethod ?? 'N/A'} at ${_formatTime(worker.checkOutTime)}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.info,
                                  fontWeight: FontWeight.w600)),
                        if (!worker.geofenceVerified)
                          const Text(
                              '⚠ Out-of-geofence entry — manual verification required',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(worker),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: BorderSide(
                                color: AppTheme.danger.withValues(alpha: 0.35)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveWorker(worker),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
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
            );
          }),
        ],
      ),
    );
  }

  void _showRejectDialog(HodWorker worker) {
    final remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.cancel, color: AppTheme.danger),
          const SizedBox(width: 10),
          Text('Reject: ${worker.name}'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter rejection remark:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: remarkController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Geofence violation, face mismatch...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              final remark = remarkController.text.trim();
              _rejectWorker(
                  worker, remark.isEmpty ? 'Rejected by HOD' : remark);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Submit Rejection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceViolationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off, color: AppTheme.danger, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Geofence Violations',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              _statusBadge('${_geofenceViolationWorkers.length} alert(s)',
                  AppTheme.danger),
            ],
          ),
          const SizedBox(height: 10),
          ..._geofenceViolationWorkers.map((worker) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: AppTheme.danger, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(worker.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(
                            'Check-in: ${worker.checkInMethod ?? 'N/A'} • ${_formatTime(worker.checkInTime)}',
                            style: const TextStyle(
                                fontSize: 10.5, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  _statusBadge('Manual Review', AppTheme.warning),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFullWorkerList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('All Workers (Full List)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'HOD view of every worker attendance entry submitted by supervisor.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ..._workers.map((worker) {
            final statusColor = _attendanceStatusColor(worker.attendanceStatus);
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
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Icon(
                        worker.isTemporary
                            ? Icons.badge_outlined
                            : Icons.person,
                        color: statusColor,
                        size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(worker.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (worker.isTemporary) ...[
                              const SizedBox(width: 4),
                              Text(worker.tempId ?? 'TEMP',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ],
                        ),
                        Text(
                          '${worker.id} • ${worker.department} • ${worker.attendanceStatus}',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textMuted),
                        ),
                        if (worker.checkInTime != null)
                          Text(
                              'In: ${_formatTime(worker.checkInTime)} • Out: ${_formatTime(worker.checkOutTime)}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  _hodApprovalChip(worker.hodApprovalStatus),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== TAB 2: OUTSIDE WORKERS REVIEW ====================
  Widget _buildOutsideWorkersReviewTab() {
    final batchTypes = ['Morning', 'Afternoon', 'Full Day', 'Others'];
    final Map<String, List<HodWorkerBatch>> batchBySession = {
      for (final s in batchTypes) s: [],
    };
    for (final batch in _confirmedBatches) {
      batchBySession.putIfAbsent(batch.sessionType, () => []).add(batch);
    }
    final activeSessions = batchBySession.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ──
          Container(
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
                  child: const Icon(Icons.people_outline, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Outside Workers (HOD Review)',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        '${_confirmedBatches.length} batch(es) • ${_outsideWorkers.length} worker(s) • ${_confirmedBatches.where((b) => b.hodApprovalStatus == 'pending').length} pending',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Confirmed batches header ──
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
                          style:
                              TextStyle(fontSize: 11, color: Colors.white70)),
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
                  child: Text('${_confirmedBatches.length} batches',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Session-grouped batch cards ──
          if (activeSessions.isEmpty)
            _buildEmptyState('No confirmed batches yet.')
          else
            ...activeSessions.map((session) {
              final batches = batchBySession[session]!;
              final color = _sessionColor(session);
              final totalWorkers =
                  batches.fold<int>(0, (sum, b) => sum + b.workers.length);
              return _buildSessionBatchCard(
                  session, batches, color, totalWorkers);
            }),

          const SizedBox(height: 16),

          // ── All outside workers list ──
          const Text('All Outside Workers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_outsideWorkers.isEmpty)
            _buildEmptyState('No outside workers added yet.')
          else
            ..._outsideWorkers.map((w) => _buildExistingWorkerTile(w)),
        ],
      ),
    );
  }

  Widget _buildSessionBatchCard(String session, List<HodWorkerBatch> batches,
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

  Widget _buildBatchDetailCard(HodWorkerBatch batch, Color sessionColor) {
    final isShiftEnded = batch.shiftState == HodBatchShiftState.shiftEnded;
    final isFullDayActive =
        batch.shiftState == HodBatchShiftState.fullDayActive;
    final isPendingContinuation =
        batch.shiftState == HodBatchShiftState.pendingContinuation;

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
                      : AppTheme.border,
          width: 1.2,
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
                  child: Text(batch.supplier,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                _statusBadge(
                  _batchStateLabel(batch.shiftState),
                  _batchStateColor(batch.shiftState),
                ),
                const SizedBox(width: 6),
                _hodApprovalChip(batch.hodApprovalStatus),
              ],
            ),
          ),
          ...batch.workers.asMap().entries.map((entry) {
            final index = entry.key;
            final worker = entry.value;
            final isHalfDay = worker.attendanceStatus == 'Half day';
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
                          '₹${worker.wage} • ${worker.sessionType}'
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
                            batch.shiftState == HodBatchShiftState.shiftEnded)
                          const Text('🏁 End-shift photo recorded',
                              style: TextStyle(
                                  fontSize: 9, color: AppTheme.success)),
                      ],
                    ),
                  ),
                  _statusBadge(
                    _attendanceLabel(
                        worker.sessionType, worker.attendanceStatus),
                    _attendanceStatusColor(worker.attendanceStatus),
                  ),
                ],
              ),
            );
          }),
          // ── HOD approval actions ──
          if (batch.hodApprovalStatus == 'pending')
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HOD Review Required',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.warning)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showBatchRejectDialog(batch),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: BorderSide(
                                color: AppTheme.danger.withValues(alpha: 0.35)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveBatch(batch),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (batch.hodApprovalStatus == 'approved')
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.task_alt, color: AppTheme.success, size: 20),
                  SizedBox(width: 8),
                  Text('Batch approved by HOD',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success)),
                ],
              ),
            ),
          // ── Footer info ──
          if (batch.geoLocation != null ||
              batch.photoPath != null ||
              batch.endShiftPhotoPath != null)
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
                  if (batch.endShiftPhotoPath != null)
                    _footerInfo(Icons.flag, 'End-shift photo recorded',
                        AppTheme.success),
                  if (batch.endShiftGeoLocation != null)
                    _footerInfo(Icons.location_on, 'End geo recorded',
                        AppTheme.success),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showBatchRejectDialog(HodWorkerBatch batch) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject Batch #${batch.batchNumber}?'),
        content: const Text(
            'Are you sure you want to reject this batch? The supervisor will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showSnackbar(
                  'Batch #${batch.batchNumber} rejected', AppTheme.danger);
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject Batch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingWorkerTile(HodOutsideWorker worker) {
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
                Text('${worker.id} • ₹${worker.wage} • ${worker.sessionType}',
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

  // ==================== TAB 3: PAYMENTS REVIEW ====================
  Widget _buildPaymentsReviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payments (HOD Review)',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Permanent worker monthly salary — HOD review',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: Text('$_paidWorkers/${_paymentWorkers.length} Paid',
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Summary ──
          Row(
            children: [
              _buildPaymentMiniStat('Earned', _formatCurrency(_totalEarned),
                  AppTheme.primary, Icons.trending_up),
              const SizedBox(width: 10),
              _buildPaymentMiniStat('Used Amount', _formatCurrency(_totalUsed),
                  AppTheme.warning, Icons.remove_circle_outline),
              const SizedBox(width: 10),
              _buildPaymentMiniStat('Balance', _formatCurrency(_totalBalance),
                  AppTheme.success, Icons.account_balance_wallet),
            ],
          ),
          const SizedBox(height: 16),

          // ── Pending payment approvals ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.warning.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions,
                    color: AppTheme.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_paymentWorkers.where((p) => p.hodApprovalStatus == "pending").length} payment(s) pending HOD approval',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Payment cards ──
          ..._paymentWorkers.map(_buildPaymentReviewCard),
        ],
      ),
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

  Widget _buildPaymentReviewCard(HodPermanentWorkerPayment account) {
    final balance = account.balanceAmount;
    final paidColor = account.isPaid ? AppTheme.success : AppTheme.warning;
    final isPending = account.hodApprovalStatus == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: account.isPaid
              ? AppTheme.success.withValues(alpha: 0.45)
              : isPending
                  ? AppTheme.warning.withValues(alpha: 0.4)
                  : AppTheme.border,
          width: account.isPaid || isPending ? 1.4 : 0.8,
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

          // ── Payment breakdown ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _paymentBreakdownRow(
                    'No. of days worked', '${account.daysWorked} days'),
                _paymentBreakdownRow('Amount earned/month',
                    _formatCurrency(account.monthlyAmount)),
                _paymentBreakdownRow('Used Amount before payday',
                    '- ${_formatCurrency(account.usedAmount)}',
                    color: AppTheme.warning),
                _paymentBreakdownRow(
                    'Already paid', '- ${_formatCurrency(account.paidAmount)}',
                    color: AppTheme.info),
                const Divider(height: 22),
                _paymentBreakdownRow(
                    'Balance amount to pay', _formatCurrency(balance),
                    color: AppTheme.success, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Ledger preview ──
          if (account.ledger.isNotEmpty) ...[
            const Text('Payment Ledger (HOD Review)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...account.ledger.reversed.take(4).map((entry) {
              final isUsedEntry = entry.type == 'used_amount' ||
                  entry.type == 'used_amount_request';
              final color = isUsedEntry
                  ? AppTheme.warning
                  : entry.status == 'Completed'
                      ? AppTheme.success
                      : AppTheme.info;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.16)),
                ),
                child: Row(
                  children: [
                    Icon(
                        entry.type == 'used_amount' ||
                                entry.type == 'used_amount_request'
                            ? Icons.remove_circle_outline
                            : entry.type == 'cash'
                                ? Icons.payments_outlined
                                : Icons.request_quote_outlined,
                        color: color,
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.note,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                          Text(
                              '${entry.method} • ${_formatDateTime(entry.date)}',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
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
            const SizedBox(height: 12),
          ],

          // ── HOD approval ──
          if (isPending && !account.isPaid)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showSnackbar('Payment rejected for ${account.name}',
                          AppTheme.danger);
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(
                          color: AppTheme.danger.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approvePayment(account),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve Payment'),
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
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (account.isPaid ? AppTheme.success : AppTheme.info)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (account.isPaid ? AppTheme.success : AppTheme.info)
                        .withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  Icon(account.isPaid ? Icons.task_alt : Icons.verified,
                      color: account.isPaid ? AppTheme.success : AppTheme.info,
                      size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      account.isPaid
                          ? 'Payment completed & approved by HOD'
                          : 'Payment approved by HOD — awaiting completion',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: account.isPaid
                              ? AppTheme.success
                              : AppTheme.info),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
          Text(value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: color ?? AppTheme.textPrimary,
              )),
        ],
      ),
    );
  }

  Widget _paymentStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w900, color: color)),
    );
  }

  // ==================== TAB 4: SUPPLIER BILLS REVIEW ====================
  Widget _buildSupplierBillsReviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
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
                      Text('Supplier Bills (HOD Review)',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Review supplier bill payment requests',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: Text('${_supplierRequests.length} Requests',
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Summary stats ──
          Row(
            children: [
              _buildSupplierMiniStat(
                  'Total Requests',
                  '${_supplierRequests.length}',
                  AppTheme.info,
                  Icons.layers_outlined),
              const SizedBox(width: 10),
              _buildSupplierMiniStat(
                  'Pending',
                  '${_supplierRequests.where((r) => r.hodApprovalStatus == "pending").length}',
                  AppTheme.warning,
                  Icons.pending_actions),
              const SizedBox(width: 10),
              _buildSupplierMiniStat(
                  'Approved',
                  '${_supplierRequests.where((r) => r.hodApprovalStatus == "approved").length}',
                  AppTheme.success,
                  Icons.check_circle),
            ],
          ),
          const SizedBox(height: 16),

          // ── Request table ──
          Container(
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
                const Text('Supplier Request Payment Table (HOD Review)',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text(
                    'All supplier bill payment requests submitted by supervisor.',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                if (_supplierRequests.isEmpty)
                  _buildEmptyState('No supplier payment requests yet.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 42,
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 90,
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
                        DataColumn(label: Text('HOD Action')),
                      ],
                      rows: _supplierRequests.map((request) {
                        final completed = request.status == 'Completed';
                        final isPending =
                            request.hodApprovalStatus == 'pending';
                        return DataRow(
                          cells: [
                            DataCell(Text(request.id,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800))),
                            DataCell(Text(request.supplierName,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(request.requestType,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800))),
                            DataCell(Text(
                                request.batchIds.isEmpty
                                    ? '-'
                                    : request.batchIds.join(', '),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_formatCurrency(request.billAmount),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_formatCurrency(request.amount),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900))),
                            DataCell(Text(request.method,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(
                              completed
                                  ? _smallSupplierChip(
                                      'Completed', AppTheme.success)
                                  : _smallSupplierChip(
                                      'Requested', AppTheme.warning),
                            ),
                            DataCell(
                              isPending
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon:
                                              const Icon(Icons.close, size: 18),
                                          color: AppTheme.danger,
                                          onPressed: () {
                                            _showSnackbar(
                                                'Request ${request.id} rejected',
                                                AppTheme.danger);
                                          },
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.check, size: 18),
                                          color: AppTheme.success,
                                          onPressed: () =>
                                              _approveSupplierRequest(request),
                                        ),
                                      ],
                                    )
                                  : _hodApprovalChip(request.hodApprovalStatus),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Detailed request cards ──
          ..._supplierRequests.map(_buildSupplierRequestDetailCard),
        ],
      ),
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

  Widget _buildSupplierRequestDetailCard(HodSupplierBillRequest request) {
    final isPending = request.hodApprovalStatus == 'pending';
    final completed = request.status == 'Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? AppTheme.warning.withValues(alpha: 0.35)
              : AppTheme.border,
          width: isPending ? 1.4 : 0.8,
        ),
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
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.request_quote_outlined,
                    color: AppTheme.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.id,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    Text(request.supplierName,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _smallSupplierChip(completed ? 'Completed' : 'Requested',
                  completed ? AppTheme.success : AppTheme.warning),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildWorkerMoneyTile('Bill Amount',
                  _formatCurrency(request.billAmount), AppTheme.primary),
              const SizedBox(width: 8),
              _buildWorkerMoneyTile('Request Amount',
                  _formatCurrency(request.amount), AppTheme.success),
              const SizedBox(width: 8),
              _buildWorkerMoneyTile('Method', request.method, AppTheme.info),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Batches: ${request.batchIds.isEmpty ? 'N/A' : request.batchIds.join(', ')}\n'
                    'Requested: ${_formatDateTime(request.requestedAt)}\n'
                    'Payment Proof: ${request.paymentProof ?? 'Pending completion'}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.info),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showSnackbar(
                          'Request ${request.id} rejected', AppTheme.danger);
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(
                          color: AppTheme.danger.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveSupplierRequest(request),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve Request'),
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
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.task_alt, color: AppTheme.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    completed
                        ? 'Payment completed & approved by HOD'
                        : 'Approved by HOD — awaiting finance completion',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

  // ==================== SHARED HELPERS ====================

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.info,
                    fontWeight: FontWeight.w600)),
          ),
        ],
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
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
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

  Color _batchStateColor(HodBatchShiftState state) {
    switch (state) {
      case HodBatchShiftState.active:
        return AppTheme.info;
      case HodBatchShiftState.pendingContinuation:
        return AppTheme.warning;
      case HodBatchShiftState.fullDayActive:
        return AppTheme.success;
      case HodBatchShiftState.shiftEnded:
        return AppTheme.success;
      case HodBatchShiftState.pendingEndShift:
        return AppTheme.warning;
    }
  }

  String _batchStateLabel(HodBatchShiftState state) {
    switch (state) {
      case HodBatchShiftState.active:
        return 'Active';
      case HodBatchShiftState.pendingContinuation:
        return 'Pending Extension';
      case HodBatchShiftState.fullDayActive:
        return 'Afternoon Active';
      case HodBatchShiftState.shiftEnded:
        return '✓ Shift Ended';
      case HodBatchShiftState.pendingEndShift:
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

  String _formatCurrency(double amount) => '₹${amount.toStringAsFixed(0)}';

  String _formatTime(DateTime? value) {
    if (value == null) return '--';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} • $hour:$minute';
  }
}
