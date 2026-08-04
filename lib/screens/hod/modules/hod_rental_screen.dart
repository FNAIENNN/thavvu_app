import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/attendance_context_service.dart';
import '../../../services/rental_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

/// HOD Rental Screen — Pro Enhanced Version
///
/// Replace your old wrapper with this file.
/// This screen is designed for the HOD side and keeps the same app theme.
/// It gives HOD a complete review dashboard for rentals, approvals,
/// internal transfers, supplier payments, proof checks, and audit history.
class HodRentalScreen extends StatefulWidget {
  const HodRentalScreen({super.key});

  @override
  State<HodRentalScreen> createState() => _HodRentalScreenState();
}

class _HodRentalScreenState extends State<HodRentalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _rentalStatusFilter = 'All';
  String _approvalStatusFilter = 'Pending';
  String _priorityFilter = 'All';
  String _paymentStatusFilter = 'Pending';
  String _transferStatusFilter = 'All';
  DateTime? _reportDateFilter;
  bool _onlyRiskRentals = false;

  final List<HodRentalRecord> _rentals = <HodRentalRecord>[];
  final List<HodRentalApproval> _approvals = <HodRentalApproval>[];
  final List<HodTransferReview> _transfers = <HodTransferReview>[];
  final List<HodPaymentReview> _payments = <HodPaymentReview>[];
  final List<HodAuditLog> _auditLogs = <HodAuditLog>[];

  // ── Live backend integration ─────────────────────────────────
  final RentalRepository _rentalRepo = RentalRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  RealtimeChannel? _rentalChannel;
  String _hodSiteId = 'SITE-VJA-001';
  List<RentalEntry> _serverEntries = <RentalEntry>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _seedDemoData();
    _searchController.addListener(_onSearchChanged);
    _initServerRentals();
  }

  Future<void> _initServerRentals() async {
    final siteId = await _contextService.resolveSiteId();
    if (!mounted) return;
    _hodSiteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
    _rentalChannel = _rentalRepo.watchEntries(_hodSiteId, _loadServerRentals);
    await _loadServerRentals();
  }

  Future<void> _loadServerRentals() async {
    try {
      final entries = await _rentalRepo.fetchEntries(siteId: _hodSiteId);
      if (!mounted) return;
      setState(() => _serverEntries = entries);
    } catch (_) {
      // Backend is best-effort; seeded demo data still works.
    }
  }

  @override
  void dispose() {
    _rentalRepo.stopWatching(_rentalChannel);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _seedDemoData() {
    final now = DateTime.now();

    _rentals.addAll([
      HodRentalRecord(
        id: 'RNT-AP-2026-0034',
        machineName: '2 HP Paddle Wheel Aerator',
        supplierName: 'Bhimavaram Machine Rentals',
        siteName: 'Bhimavaram Aqua Yard',
        supervisorName: 'Supervisor Rajesh',
        thavvuId: 'THV-BVRM-01',
        tankId: 'TNK-BVRM-11',
        quantity: 4,
        activeQuantity: 2,
        ratePerDay: 1450,
        advancePaid: 3000,
        fuelAmount: 1140,
        startDate: now.subtract(const Duration(days: 8)),
        lastCheckIn: now.subtract(const Duration(hours: 4)),
        status: HodRentalStatus.active,
        priority: HodPriority.high,
        openingPhotoUploaded: true,
        billPhotoUploaded: true,
        closingProofUploaded: false,
        note: 'High runtime aerator. Continue monitoring oxygen support.',
      ),
      HodRentalRecord(
        id: 'RNT-AP-2026-0035',
        machineName: 'Diesel Water Pump 5 HP',
        supplierName: 'Delta Work Equipment',
        siteName: 'Krishna Brackish Pond',
        supervisorName: 'Supervisor Kumar',
        thavvuId: 'THV-KRS-01',
        tankId: 'TNK-KRS-09',
        quantity: 2,
        activeQuantity: 2,
        ratePerDay: 1800,
        advancePaid: 2500,
        fuelAmount: 1550,
        startDate: now.subtract(const Duration(days: 6)),
        lastCheckIn: now.subtract(const Duration(days: 1, hours: 2)),
        status: HodRentalStatus.active,
        priority: HodPriority.normal,
        openingPhotoUploaded: true,
        billPhotoUploaded: true,
        closingProofUploaded: false,
        note: 'Water exchange ongoing. Check-in is slightly delayed.',
      ),
      HodRentalRecord(
        id: 'RNT-AP-2026-0036',
        machineName: 'DO Meter Kit',
        supplierName: 'AP Aqua Tools & Motors',
        siteName: 'Nellore Test Station',
        supervisorName: 'Lab Assistant',
        thavvuId: 'THV-NLR-01',
        tankId: 'TNK-NLR-44',
        quantity: 3,
        activeQuantity: 0,
        ratePerDay: 450,
        advancePaid: 500,
        fuelAmount: 0,
        startDate: now.subtract(const Duration(days: 3)),
        lastCheckIn: null,
        status: HodRentalStatus.atSite,
        priority: HodPriority.low,
        openingPhotoUploaded: true,
        billPhotoUploaded: false,
        closingProofUploaded: false,
        note: 'At site but not activated. Bill photo is missing.',
      ),
      HodRentalRecord(
        id: 'RNT-AP-2026-0028',
        machineName: 'Portable Generator 7.5 kVA',
        supplierName: 'West Godavari Power Rentals',
        siteName: 'West Godavari Backup Bay',
        supervisorName: 'Supervisor Mahesh',
        thavvuId: 'THV-WG-07',
        tankId: 'TNK-WG-07',
        quantity: 1,
        activeQuantity: 0,
        ratePerDay: 2200,
        advancePaid: 5000,
        fuelAmount: 2100,
        startDate: now.subtract(const Duration(days: 20)),
        closeDate: now.subtract(const Duration(days: 3)),
        lastCheckIn: now.subtract(const Duration(days: 4)),
        status: HodRentalStatus.closed,
        priority: HodPriority.normal,
        openingPhotoUploaded: true,
        billPhotoUploaded: true,
        closingProofUploaded: true,
        note: 'Closed rental. Balance payment pending review.',
      ),
    ]);

    _approvals.addAll([
      HodRentalApproval(
        id: 'REN-REV-001',
        rentalId: 'RNT-AP-2026-0034',
        title: 'Approve aerator continuation',
        requestedBy: 'Supervisor Rajesh',
        siteName: 'Bhimavaram Aqua Yard',
        amount: 11600,
        priority: HodPriority.high,
        status: HodReviewStatus.pending,
        createdAt: now.subtract(const Duration(hours: 5)),
        description: 'Aerator needs one more shift because DO level is unstable.',
        proofSummary: 'Opening photo, bill photo, and daily check-ins available.',
      ),
      HodRentalApproval(
        id: 'REN-REV-002',
        rentalId: 'RNT-AP-2026-0035',
        title: 'Fuel log correction',
        requestedBy: 'Supervisor Kumar',
        siteName: 'Krishna Brackish Pond',
        amount: 450,
        priority: HodPriority.normal,
        status: HodReviewStatus.pending,
        createdAt: now.subtract(const Duration(hours: 3)),
        description: 'Supervisor corrected shift-end fuel amount.',
        proofSummary: 'Fuel note, meter reading, and machine photo attached.',
      ),
      HodRentalApproval(
        id: 'REN-REV-003',
        rentalId: 'RNT-AP-2026-0028',
        title: 'Generator closure balance',
        requestedBy: 'Supervisor Mahesh',
        siteName: 'West Godavari Backup Bay',
        amount: 8200,
        priority: HodPriority.normal,
        status: HodReviewStatus.revisionRequested,
        createdAt: now.subtract(const Duration(days: 1)),
        description: 'Supplier requested final balance after closure.',
        proofSummary: 'Closing proof uploaded but clarity is low.',
        hodNote: 'Upload clearer closing proof before payment release.',
      ),
    ]);

    _transfers.addAll([
      HodTransferReview(
        id: 'ITR-REN-001',
        date: now.subtract(const Duration(hours: 7)),
        fromThavvuId: 'THV-BVRM-01',
        toThavvuId: 'THV-BVRM-02',
        rentalId: 'RNT-AP-2026-0034',
        itemName: '2 HP Paddle Wheel Aerator',
        quantity: 1,
        submittedBy: 'Supervisor Rajesh',
        status: HodTransferStatus.submitted,
        photoPath: 'photo_ITR_001.jpg',
        note: 'One aerator moved to adjacent pond line.',
      ),
      HodTransferReview(
        id: 'ITR-REN-002',
        date: now.subtract(const Duration(days: 1)),
        fromThavvuId: 'THV-KRS-01',
        toThavvuId: 'THV-KRS-02',
        rentalId: 'RNT-AP-2026-0035',
        itemName: 'Diesel Water Pump 5 HP',
        quantity: 1,
        submittedBy: 'Supervisor Kumar',
        status: HodTransferStatus.verified,
        photoPath: 'photo_ITR_002.jpg',
        note: 'Pump moved for water exchange line.',
      ),
      HodTransferReview(
        id: 'ITR-REN-003',
        date: now.subtract(const Duration(days: 2)),
        fromThavvuId: 'THV-MTM-01',
        toThavvuId: 'THV-MTM-02',
        rentalId: 'RNT-AP-2026-0037',
        itemName: 'Drag Net / Seine Net',
        quantity: 1,
        submittedBy: 'Supervisor Mahesh',
        status: HodTransferStatus.needsProof,
        photoPath: '',
        note: 'Photo proof missing.',
      ),
    ]);

    _payments.addAll([
      HodPaymentReview(
        id: 'PAY-REN-001',
        supplierName: 'Bhimavaram Machine Rentals',
        rentalId: 'RNT-AP-2026-0034',
        itemName: '2 HP Paddle Wheel Aerator',
        requestedAmount: 11600,
        approvedAmount: 0,
        method: 'Bank Transfer',
        requestedBy: 'Supervisor Rajesh',
        status: HodPaymentStatus.pending,
        createdAt: now.subtract(const Duration(hours: 4)),
        note: 'Continuation payment request for aerator.',
      ),
      HodPaymentReview(
        id: 'PAY-REN-002',
        supplierName: 'Delta Work Equipment',
        rentalId: 'RNT-AP-2026-0035',
        itemName: 'Diesel Water Pump 5 HP',
        requestedAmount: 10800,
        approvedAmount: 0,
        method: 'UPI',
        requestedBy: 'Supervisor Kumar',
        status: HodPaymentStatus.pending,
        createdAt: now.subtract(const Duration(hours: 8)),
        note: 'Pump running amount for current work period.',
      ),
      HodPaymentReview(
        id: 'PAY-REN-003',
        supplierName: 'West Godavari Power Rentals',
        rentalId: 'RNT-AP-2026-0028',
        itemName: 'Portable Generator 7.5 kVA',
        requestedAmount: 8200,
        approvedAmount: 0,
        method: 'Bank Transfer',
        requestedBy: 'Supervisor Mahesh',
        status: HodPaymentStatus.revisionRequested,
        createdAt: now.subtract(const Duration(days: 1)),
        note: 'Waiting for better closing proof.',
      ),
    ]);

    _auditLogs.addAll([
      HodAuditLog(
        id: 'AUD-001',
        date: now.subtract(const Duration(hours: 2)),
        action: 'Revision requested',
        module: 'Payment Review',
        itemId: 'PAY-REN-003',
        actor: 'HOD-001',
        note: 'Requested clearer closing proof.',
      ),
      HodAuditLog(
        id: 'AUD-002',
        date: now.subtract(const Duration(days: 1)),
        action: 'Transfer verified',
        module: 'Internal Transfer',
        itemId: 'ITR-REN-002',
        actor: 'HOD-001',
        note: 'Verified pump movement with photo proof.',
      ),
    ]);
  }

  String get _query => _searchController.text.trim().toLowerCase();

  List<HodRentalRecord> get _visibleRentals {
    return _rentals.where((rental) {
      final matchesSearch = _query.isEmpty ||
          rental.id.toLowerCase().contains(_query) ||
          rental.machineName.toLowerCase().contains(_query) ||
          rental.siteName.toLowerCase().contains(_query) ||
          rental.thavvuId.toLowerCase().contains(_query) ||
          rental.supervisorName.toLowerCase().contains(_query);
      final matchesStatus = _rentalStatusFilter == 'All' ||
          rental.status.label == _rentalStatusFilter;
      final matchesPriority = _priorityFilter == 'All' ||
          rental.priority.label == _priorityFilter;
      final matchesRisk = !_onlyRiskRentals ||
          rental.hasMissingProof ||
          rental.isCheckInDelayed;
      return matchesSearch && matchesStatus && matchesPriority && matchesRisk;
    }).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  List<HodRentalApproval> get _visibleApprovals {
    return _approvals.where((request) {
      final matchesSearch = _query.isEmpty ||
          request.id.toLowerCase().contains(_query) ||
          request.rentalId.toLowerCase().contains(_query) ||
          request.title.toLowerCase().contains(_query) ||
          request.siteName.toLowerCase().contains(_query) ||
          request.requestedBy.toLowerCase().contains(_query);
      final matchesStatus = _approvalStatusFilter == 'All' ||
          request.status.label == _approvalStatusFilter;
      final matchesPriority = _priorityFilter == 'All' ||
          request.priority.label == _priorityFilter;
      return matchesSearch && matchesStatus && matchesPriority;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<HodTransferReview> get _visibleTransfers {
    return _transfers.where((transfer) {
      final matchesSearch = _query.isEmpty ||
          transfer.id.toLowerCase().contains(_query) ||
          transfer.rentalId.toLowerCase().contains(_query) ||
          transfer.itemName.toLowerCase().contains(_query) ||
          transfer.fromThavvuId.toLowerCase().contains(_query) ||
          transfer.toThavvuId.toLowerCase().contains(_query);
      final matchesStatus = _transferStatusFilter == 'All' ||
          transfer.status.label == _transferStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<HodPaymentReview> get _visiblePayments {
    return _payments.where((payment) {
      final matchesSearch = _query.isEmpty ||
          payment.id.toLowerCase().contains(_query) ||
          payment.rentalId.toLowerCase().contains(_query) ||
          payment.supplierName.toLowerCase().contains(_query) ||
          payment.itemName.toLowerCase().contains(_query);
      final matchesStatus = _paymentStatusFilter == 'All' ||
          payment.status.label == _paymentStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<HodAuditLog> get _visibleAuditLogs {
    final logs = _auditLogs.where((log) {
      final matchesSearch = _query.isEmpty ||
          log.action.toLowerCase().contains(_query) ||
          log.module.toLowerCase().contains(_query) ||
          log.itemId.toLowerCase().contains(_query) ||
          log.note.toLowerCase().contains(_query);
      final matchesDate = _reportDateFilter == null ||
          _isSameDay(log.date, _reportDateFilter!);
      return matchesSearch && matchesDate;
    }).toList();
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  int get _activeRentalCount =>
      _rentals.where((r) => r.status == HodRentalStatus.active).length;

  int get _pendingApprovalCount =>
      _approvals.where((r) => r.status == HodReviewStatus.pending).length;

  int get _pendingPaymentCount =>
      _payments.where((p) => p.status == HodPaymentStatus.pending).length;

  int get _missingProofCount => _rentals.where((r) => r.hasMissingProof).length +
      _transfers.where((t) => t.photoPath.trim().isEmpty).length;

  double get _totalRentalAmount =>
      _rentals.fold(0, (sum, r) => sum + r.estimatedRentalAmount);

  double get _totalFuelAmount => _rentals.fold(0, (sum, r) => sum + r.fuelAmount);

  double get _pendingPaymentAmount => _payments
      .where((payment) => payment.status == HodPaymentStatus.pending)
      .fold(0, (sum, p) => sum + p.requestedAmount);

  double get _advanceTotal => _rentals.fold(0, (sum, r) => sum + r.advancePaid);

  int get _delayedCheckInCount =>
      _rentals.where((rental) => rental.isCheckInDelayed).length;

  int get _proofIssueRentalCount =>
      _rentals.where((rental) => rental.hasMissingProof).length;

  int get _verifiedTransferCount => _transfers
      .where((transfer) => transfer.status == HodTransferStatus.verified)
      .length;

  int get _highPriorityApprovalCount => _approvals
      .where((approval) =>
          approval.priority == HodPriority.high &&
          approval.status == HodReviewStatus.pending)
      .length;

  double get _approvedPaymentAmount => _payments
      .where((payment) => payment.status == HodPaymentStatus.approved)
      .fold(0, (sum, payment) => sum + payment.approvedAmount);

  double get _paymentApprovalProgress {
    if (_payments.isEmpty) return 0;
    final approved = _payments
        .where((payment) => payment.status == HodPaymentStatus.approved)
        .length;
    return approved / _payments.length;
  }

  List<_RiskAlert> get _riskAlerts {
    final alerts = <_RiskAlert>[];
    for (final rental in _rentals) {
      if (rental.isCheckInDelayed) {
        alerts.add(_RiskAlert(
          title: 'Delayed check-in',
          subtitle: '${rental.machineName} • ${rental.thavvuId}',
          color: AppTheme.warning,
          icon: Icons.schedule_outlined,
        ));
      }
      if (rental.hasMissingProof) {
        alerts.add(_RiskAlert(
          title: 'Missing proof',
          subtitle: '${rental.machineName} • ${rental.id}',
          color: AppTheme.danger,
          icon: Icons.photo_camera_back_outlined,
        ));
      }
    }
    for (final transfer in _transfers.where((item) => item.photoPath.isEmpty)) {
      alerts.add(_RiskAlert(
        title: 'Transfer photo missing',
        subtitle: '${transfer.itemName} • ${transfer.id}',
        color: AppTheme.danger,
        icon: Icons.swap_horiz_outlined,
      ));
    }
    return alerts.take(5).toList();
  }

  void _refreshDashboard() {
    setState(() {
      _rentals.sort((a, b) => b.startDate.compareTo(a.startDate));
      _approvals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _transfers.sort((a, b) => b.date.compareTo(a.date));
      _auditLogs.sort((a, b) => b.date.compareTo(a.date));
    });
    _showSnackBar('HOD rental dashboard refreshed.', AppTheme.success);
  }

  void _focusTab(int index) {
    if (!_tabController.indexIsChanging && mounted) {
      _tabController.animateTo(index);
    }
  }

  void _toggleRiskRentalsOnly() {
    setState(() {
      _onlyRiskRentals = !_onlyRiskRentals;
      if (_onlyRiskRentals) {
        _rentalStatusFilter = 'All';
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _rentalStatusFilter = 'All';
      _approvalStatusFilter = 'Pending';
      _priorityFilter = 'All';
      _paymentStatusFilter = 'Pending';
      _transferStatusFilter = 'All';
      _reportDateFilter = null;
      _onlyRiskRentals = false;
    });
  }

  Future<void> _decideApproval(
    HodRentalApproval request,
    HodReviewStatus decision,
  ) async {
    final note = await _showHodNoteSheet(
      title: decision == HodReviewStatus.approved
          ? 'Approve Request'
          : decision == HodReviewStatus.rejected
              ? 'Reject Request'
              : 'Request Revision',
      hintText: decision == HodReviewStatus.approved
          ? 'Optional approval note'
          : 'Enter reason / correction needed',
      isRequired: decision != HodReviewStatus.approved,
    );
    if (note == null || !mounted) return;

    setState(() {
      request.status = decision;
      request.hodNote = note.trim();
      request.decidedAt = DateTime.now();
      _addAudit(
        action: decision.label,
        module: 'Rental Approval',
        itemId: request.id,
        note: note.trim().isEmpty ? 'No note added.' : note.trim(),
      );
    });

    _showSnackBar('${request.title} marked as ${decision.label}',
        _reviewStatusColor(decision));
  }

  Future<void> _decidePayment(
    HodPaymentReview payment,
    HodPaymentStatus decision,
  ) async {
    final note = await _showHodNoteSheet(
      title: decision == HodPaymentStatus.approved
          ? 'Approve Payment'
          : decision == HodPaymentStatus.rejected
              ? 'Reject Payment'
              : 'Request Payment Revision',
      hintText: decision == HodPaymentStatus.approved
          ? 'Optional payment note'
          : 'Enter reason / correction needed',
      isRequired: decision != HodPaymentStatus.approved,
    );
    if (note == null || !mounted) return;

    setState(() {
      payment.status = decision;
      payment.hodNote = note.trim();
      payment.decidedAt = DateTime.now();
      if (decision == HodPaymentStatus.approved) {
        payment.approvedAmount = payment.requestedAmount;
      }
      _addAudit(
        action: decision.label,
        module: 'Supplier Payment',
        itemId: payment.id,
        note: note.trim().isEmpty ? 'No note added.' : note.trim(),
      );
    });

    _showSnackBar('${payment.itemName} payment marked as ${decision.label}',
        _paymentStatusColor(decision));
  }

  Future<void> _verifyTransfer(
    HodTransferReview transfer,
    HodTransferStatus decision,
  ) async {
    if (decision == HodTransferStatus.verified && transfer.photoPath.isEmpty) {
      _showSnackBar('Photo proof is required before verifying transfer.',
          AppTheme.danger);
      return;
    }

    final note = await _showHodNoteSheet(
      title: decision == HodTransferStatus.verified
          ? 'Verify Transfer'
          : 'Request Transfer Proof',
      hintText: decision == HodTransferStatus.verified
          ? 'Optional verification note'
          : 'Enter proof/correction needed',
      isRequired: decision != HodTransferStatus.verified,
    );
    if (note == null || !mounted) return;

    setState(() {
      transfer.status = decision;
      transfer.hodNote = note.trim();
      transfer.verifiedAt = decision == HodTransferStatus.verified
          ? DateTime.now()
          : transfer.verifiedAt;
      _addAudit(
        action: decision.label,
        module: 'Internal Transfer',
        itemId: transfer.id,
        note: note.trim().isEmpty ? 'No note added.' : note.trim(),
      );
    });

    _showSnackBar('Transfer ${transfer.id} marked as ${decision.label}',
        _transferStatusColor(decision));
  }

  void _addAudit({
    required String action,
    required String module,
    required String itemId,
    required String note,
  }) {
    _auditLogs.insert(
      0,
      HodAuditLog(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        action: action,
        module: module,
        itemId: itemId,
        actor: 'HOD-001',
        note: note,
      ),
    );
  }

  Future<String?> _showHodNoteSheet({
    required String title,
    required String hintText,
    required bool isRequired,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
            child: Form(
              key: formKey,
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: isRequired ? '$hintText *' : hintText,
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                    ),
                    validator: (value) {
                      if (!isRequired) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a HOD note.';
                      }
                      return null;
                    },
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
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.pop(sheetContext, controller.text);
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Submit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                          ),
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
    controller.dispose();
    return result;
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _pickReportDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDateFilter ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() => _reportDateFilter = picked);
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: 'HOD Rental',
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _refreshDashboard,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Clear filters',
          onPressed: _clearFilters,
          icon: const Icon(Icons.filter_alt_off_outlined),
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Active'),
        Tab(text: 'Approvals'),
        Tab(text: 'Transfers'),
        Tab(text: 'Payments'),
        Tab(text: 'Reports'),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildActiveRentalsTab(),
          _buildApprovalsTab(),
          _buildTransfersTab(),
          _buildPaymentsTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                ),
                child: const Icon(Icons.admin_panel_settings_outlined,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Professional Rental Command Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Review active machines, payments, transfers, proofs and audit actions.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroMetric(label: 'Active', value: '$_activeRentalCount'),
              _HeroMetric(label: 'Approvals', value: '$_pendingApprovalCount'),
              _HeroMetric(label: 'Payments', value: '$_pendingPaymentCount'),
              _HeroMetric(label: 'Proof Issues', value: '$_missingProofCount'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _paymentApprovalProgress.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment approval progress: ${(_paymentApprovalProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildCompactSearchPanel({
    String hintText = 'Search rental ID, machine, site, thavvu...',
  }) {
    return _Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.manage_search_rounded, color: AppTheme.primary, size: 36),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Search & Controls',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Search is inside the screen now, so the app bar stays clean.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear',
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => _searchController.clear(),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return _TabScaffold(
      children: [
        _buildHeroHeader(),
        const SizedBox(height: 14),
        _buildCompactSearchPanel(),
        _buildExecutiveActionStrip(),
        const SizedBox(height: 14),
        _buildOperationalHealthCard(),
        const SizedBox(height: 14),
        _SectionTitle(
          icon: Icons.insights_outlined,
          title: 'HOD Rental Overview',
          subtitle: 'Fast review of rental health, risks and money flow.',
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _StatCard(
              title: 'Rental Amount',
              value: _formatMoney(_totalRentalAmount),
              icon: Icons.currency_rupee,
              color: AppTheme.primary,
              subtitle: 'Estimated running value',
            ),
            _StatCard(
              title: 'Fuel Amount',
              value: _formatMoney(_totalFuelAmount),
              icon: Icons.local_gas_station_outlined,
              color: AppTheme.warning,
              subtitle: 'Logged fuel cost',
            ),
            _StatCard(
              title: 'Pending Payment',
              value: _formatMoney(_pendingPaymentAmount),
              icon: Icons.pending_actions_outlined,
              color: AppTheme.danger,
              subtitle: 'Waiting HOD action',
            ),
            _StatCard(
              title: 'Advance Paid',
              value: _formatMoney(_advanceTotal),
              icon: Icons.account_balance_wallet_outlined,
              color: AppTheme.success,
              subtitle: 'Cash + request advances',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionTitle(
          icon: Icons.warning_amber_rounded,
          title: 'Risk Alerts',
          subtitle: 'Proof gaps and delayed check-ins that need attention.',
        ),
        if (_riskAlerts.isEmpty)
          const _EmptyState(
            icon: Icons.verified_outlined,
            title: 'No rental risks found',
            subtitle: 'All visible rental records look clean.',
          )
        else
          ..._riskAlerts.map(_buildRiskAlertCard),
        const SizedBox(height: 14),
        _buildProofCenterCard(),
        const SizedBox(height: 14),
        _SectionTitle(
          icon: Icons.timeline_outlined,
          title: 'Recent Activity',
          subtitle: 'Latest actions from approval, transfer and payment flows.',
        ),
        ..._auditLogs.take(4).map(_buildAuditMiniCard),
      ],
    );
  }

  Widget _buildActiveRentalsTab() {
    return _TabScaffold(
      children: [
        _buildCompactSearchPanel(hintText: 'Search active rentals by ID, machine, supervisor, site...'),
        _buildRentalRiskToggle(),
        const SizedBox(height: 12),
        _buildFilterRow(
          filters: [
            _FilterBox(
              label: 'Status',
              value: _rentalStatusFilter,
              values: ['All', ...HodRentalStatus.values.map((e) => e.label)],
              onChanged: (value) => setState(() => _rentalStatusFilter = value ?? 'All'),
            ),
            _FilterBox(
              label: 'Priority',
              value: _priorityFilter,
              values: ['All', ...HodPriority.values.map((e) => e.label)],
              onChanged: (value) => setState(() => _priorityFilter = value ?? 'All'),
            ),
          ],
        ),
        if (_visibleRentals.isEmpty)
          const _EmptyState(
            icon: Icons.precision_manufacturing_outlined,
            title: 'No active rental records',
            subtitle: 'Try clearing filters or search text.',
          )
        else
          ..._visibleRentals.map(_buildRentalCard),
      ],
    );
  }

  Widget _buildLiveRentalApprovals() {
    final pending = _serverEntries
        .where((entry) => entry.status == 'submitted')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.cloud_sync_outlined,
          title: 'Supervisor Entries (Live)',
          subtitle:
              'Rental entries submitted by supervisors, synced in realtime.',
        ),
        if (pending.isEmpty)
          const _EmptyState(
            icon: Icons.cloud_done_outlined,
            title: 'No pending entries',
            subtitle:
                'New supervisor rental entries will appear here instantly.',
          )
        else
          ...pending.map(_buildLiveEntryCard),
      ],
    );
  }

  Widget _buildLiveEntryCard(RentalEntry entry) {
    final workDate = entry.workDate;
    final dateLabel = '${workDate.day}/${workDate.month}/${workDate.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.vehicleName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppTheme.warning.withOpacity(0.25)),
                ),
                child: Text(
                  entry.status,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.entryNo} · $dateLabel · ${entry.billingType}',
            style: const TextStyle(
                fontSize: 11.5, color: AppTheme.textMuted),
          ),
          if (entry.units > 0 || entry.rate > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${entry.units.toStringAsFixed(0)} unit(s) × '
              '₹${entry.rate.toStringAsFixed(0)} · Total '
              '₹${entry.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary),
            ),
          ],
          if (entry.openingPhotoPath != null ||
              entry.billPhotoPath != null) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.photo_camera_outlined,
                    size: 14, color: AppTheme.info),
                SizedBox(width: 6),
                Text('Photos attached (opening / bill)',
                    style: TextStyle(
                        fontSize: 11.5, color: AppTheme.info)),
              ],
            ),
          ],
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.notes!,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reviewServerEntry(entry, 'approved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.success,
                    side: const BorderSide(color: AppTheme.success),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reviewServerEntry(entry, 'rejected'),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
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
    );
  }

  Future<void> _reviewServerEntry(RentalEntry entry, String status) async {
    final ok = await _rentalRepo.updateEntryStatus(
      entryId: entry.id,
      status: status,
      hodNote: 'Marked $status by HOD',
    );
    if (!mounted) return;
    _showSnackBar(
      ok ? 'Entry ${entry.entryNo} ${status == 'approved' ? 'approved' : 'rejected'}.' : 'Failed to update entry.',
      ok ? AppTheme.success : AppTheme.danger,
    );
    _loadServerRentals();
  }

  Widget _buildApprovalsTab() {
    return _TabScaffold(
      children: [
        _buildLiveRentalApprovals(),
        _buildCompactSearchPanel(hintText: 'Search approvals by request, rental ID, site or supervisor...'),
        _buildFilterRow(
          filters: [
            _FilterBox(
              label: 'Status',
              value: _approvalStatusFilter,
              values: ['All', ...HodReviewStatus.values.map((e) => e.label)],
              onChanged: (value) => setState(() => _approvalStatusFilter = value ?? 'All'),
            ),
            _FilterBox(
              label: 'Priority',
              value: _priorityFilter,
              values: ['All', ...HodPriority.values.map((e) => e.label)],
              onChanged: (value) => setState(() => _priorityFilter = value ?? 'All'),
            ),
          ],
        ),
        if (_visibleApprovals.isEmpty)
          const _EmptyState(
            icon: Icons.verified_outlined,
            title: 'No approval requests found',
            subtitle: 'No records match the selected filters.',
          )
        else
          ..._visibleApprovals.map(_buildApprovalCard),
      ],
    );
  }

  Widget _buildTransfersTab() {
    return _TabScaffold(
      children: [
        _buildCompactSearchPanel(hintText: 'Search transfers by item, rental ID, from/to Thavvu...'),
        _buildFilterRow(
          filters: [
            _FilterBox(
              label: 'Transfer',
              value: _transferStatusFilter,
              values: ['All', ...HodTransferStatus.values.map((e) => e.label)],
              onChanged: (value) => setState(() => _transferStatusFilter = value ?? 'All'),
            ),
          ],
        ),
        _SectionTitle(
          icon: Icons.swap_horiz_outlined,
          title: 'Internal Transfer Review',
          subtitle: 'From Thavvu → To Thavvu transfers with machine proof.',
        ),
        if (_visibleTransfers.isEmpty)
          const _EmptyState(
            icon: Icons.swap_horiz_outlined,
            title: 'No transfer records found',
            subtitle: 'No transfer records match your search/filter.',
          )
        else
          ..._visibleTransfers.map(_buildTransferCard),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    return _TabScaffold(
      children: [
        _buildCompactSearchPanel(hintText: 'Search payments by supplier, rental ID or item...'),
        _buildFilterRow(
          filters: [
            _FilterBox(
              label: 'Payment',
              value: _paymentStatusFilter,
              values: ['All', ...HodPaymentStatus.values.map((e) => e.label)],
              onChanged: (value) => setState(() => _paymentStatusFilter = value ?? 'All'),
            ),
          ],
        ),
        if (_visiblePayments.isEmpty)
          const _EmptyState(
            icon: Icons.payments_outlined,
            title: 'No payment requests found',
            subtitle: 'No supplier payment records match this filter.',
          )
        else
          ..._visiblePayments.map(_buildPaymentCard),
      ],
    );
  }

  Widget _buildReportsTab() {
    return _TabScaffold(
      children: [
        _buildCompactSearchPanel(hintText: 'Search audit logs by action, module, item ID or note...'),
        _SectionTitle(
          icon: Icons.analytics_outlined,
          title: 'Rental Reports',
          subtitle: 'HOD audit trail, totals and verification status.',
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _StatCard(
              title: 'Active Machines',
              value: '$_activeRentalCount',
              icon: Icons.play_circle_outline,
              color: AppTheme.success,
              subtitle: 'Currently active',
            ),
            _StatCard(
              title: 'Pending Reviews',
              value: '$_pendingApprovalCount',
              icon: Icons.verified_outlined,
              color: AppTheme.warning,
              subtitle: 'Need HOD decision',
            ),
            _StatCard(
              title: 'Proof Issues',
              value: '$_missingProofCount',
              icon: Icons.photo_camera_back_outlined,
              color: AppTheme.danger,
              subtitle: 'Missing proof count',
            ),
            _StatCard(
              title: 'Audit Logs',
              value: '${_auditLogs.length}',
              icon: Icons.history_rounded,
              color: AppTheme.info,
              subtitle: 'Recorded HOD actions',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Audit Table',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickReportDate,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(_reportDateFilter == null
                        ? 'Filter Date'
                        : _formatDate(_reportDateFilter!)),
                  ),
                  if (_reportDateFilter != null)
                    IconButton(
                      tooltip: 'Clear date',
                      onPressed: () => setState(() => _reportDateFilter = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildAuditTable(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveActionStrip() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            title: 'Pending Approvals',
            value: '$_pendingApprovalCount',
            icon: Icons.verified_outlined,
            color: AppTheme.warning,
            onTap: () => _focusTab(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            title: 'Payments',
            value: '$_pendingPaymentCount',
            icon: Icons.payments_outlined,
            color: AppTheme.danger,
            onTap: () => _focusTab(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            title: 'Transfers',
            value: '${_transfers.length}',
            icon: Icons.swap_horiz_outlined,
            color: AppTheme.info,
            onTap: () => _focusTab(3),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalHealthCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.health_and_safety_outlined, color: AppTheme.success),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational Health',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Professional HOD view of proof, check-in and payment health.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MiniValue(label: 'Delayed Check-ins', value: '$_delayedCheckInCount')),
              Expanded(child: _MiniValue(label: 'Rental Proof Issues', value: '$_proofIssueRentalCount')),
              Expanded(child: _MiniValue(label: 'High Priority', value: '$_highPriorityApprovalCount')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MiniValue(label: 'Verified Transfers', value: '$_verifiedTransferCount')),
              Expanded(child: _MiniValue(label: 'Approved Payments', value: _formatMoney(_approvedPaymentAmount))),
              Expanded(child: _MiniValue(label: 'Pending Amount', value: _formatMoney(_pendingPaymentAmount))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofCenterCard() {
    final missingRentalProofs = _rentals.where((rental) => rental.hasMissingProof).toList();
    final missingTransferProofs = _transfers.where((transfer) => transfer.photoPath.trim().isEmpty).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.photo_camera_back_outlined, color: AppTheme.danger),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proof Control Center',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Missing proof is separated so HOD can follow up quickly.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: '$_missingProofCount issues',
                color: _missingProofCount == 0 ? AppTheme.success : AppTheme.danger,
                backgroundColor: _softBg(_missingProofCount == 0 ? AppTheme.success : AppTheme.danger),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (missingRentalProofs.isEmpty && missingTransferProofs.isEmpty)
            const _ProofBox(label: 'All rental and transfer proofs are clean', isDone: true)
          else ...[
            ...missingRentalProofs.take(3).map(
              (rental) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ProofIssueRow(
                  title: rental.machineName,
                  subtitle: '${rental.id} • ${rental.thavvuId}',
                  type: 'Rental Proof',
                ),
              ),
            ),
            ...missingTransferProofs.take(3).map(
              (transfer) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ProofIssueRow(
                  title: transfer.itemName,
                  subtitle: '${transfer.id} • ${transfer.fromThavvuId} → ${transfer.toThavvuId}',
                  type: 'Transfer Proof',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRentalRiskToggle() {
    return _Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _IconBadge(
            icon: _onlyRiskRentals ? Icons.warning_amber_rounded : Icons.fact_check_outlined,
            color: _onlyRiskRentals ? AppTheme.warning : AppTheme.primary,
            size: 36,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rental Risk Focus',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Show only delayed check-ins or missing-proof machines.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: _onlyRiskRentals,
            activeColor: AppTheme.warning,
            onChanged: (_) => _toggleRiskRentalsOnly(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow({required List<Widget> filters}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...filters.map((filter) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: filter,
              )),
          OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAlertCard(_RiskAlert alert) {
    return _Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _IconBadge(icon: alert.icon, color: alert.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 3),
                Text(alert.subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: alert.color),
        ],
      ),
    );
  }

  Widget _buildRentalCard(HodRentalRecord rental) {
    final statusColor = _rentalStatusColor(rental.status);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: Icons.precision_manufacturing_outlined, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rental.machineName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${rental.id} • ${rental.supplierName}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _StatusPill(
                label: rental.status.label,
                color: statusColor,
                backgroundColor: _softBg(statusColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.location_on_outlined, label: rental.siteName),
              _InfoChip(icon: Icons.account_tree_outlined, label: rental.thavvuId),
              _InfoChip(icon: Icons.water_outlined, label: rental.tankId),
              _InfoChip(icon: Icons.person_outline, label: rental.supervisorName),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MiniValue(label: 'Qty', value: '${rental.activeQuantity}/${rental.quantity}')),
              Expanded(child: _MiniValue(label: 'Days', value: '${rental.runningDays}')),
              Expanded(child: _MiniValue(label: 'Rent', value: _formatMoney(rental.estimatedRentalAmount))),
              Expanded(child: _MiniValue(label: 'Fuel', value: _formatMoney(rental.fuelAmount))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ProofBox(
                  label: 'Opening',
                  isDone: rental.openingPhotoUploaded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProofBox(label: 'Bill', isDone: rental.billPhotoUploaded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProofBox(label: 'Closing', isDone: rental.closingProofUploaded),
              ),
            ],
          ),
          if (rental.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoteBox(text: rental.note, color: AppTheme.info),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovalCard(HodRentalApproval request) {
    final statusColor = _reviewStatusColor(request.status);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: Icons.verified_outlined, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${request.id} • ${request.rentalId} • ${request.siteName}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _StatusPill(
                label: request.status.label,
                color: statusColor,
                backgroundColor: _softBg(statusColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(request.description,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          _NoteBox(text: request.proofSummary, color: AppTheme.info),
          if (request.hodNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _NoteBox(text: 'HOD Note: ${request.hodNote}', color: AppTheme.warning),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniValue(label: 'Requested', value: _formatMoney(request.amount))),
              Expanded(child: _MiniValue(label: 'Priority', value: request.priority.label)),
              Expanded(child: _MiniValue(label: 'By', value: request.requestedBy)),
            ],
          ),
          if (request.status == HodReviewStatus.pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Approve',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.success,
                    onTap: () => _decideApproval(request, HodReviewStatus.approved),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Revision',
                    icon: Icons.edit_note_outlined,
                    color: AppTheme.warning,
                    onTap: () => _decideApproval(request, HodReviewStatus.revisionRequested),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Reject',
                    icon: Icons.cancel_outlined,
                    color: AppTheme.danger,
                    onTap: () => _decideApproval(request, HodReviewStatus.rejected),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferCard(HodTransferReview transfer) {
    final statusColor = _transferStatusColor(transfer.status);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: Icons.swap_horiz_outlined, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transfer.itemName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${transfer.id} • ${transfer.rentalId}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _StatusPill(
                label: transfer.status.label,
                color: statusColor,
                backgroundColor: _softBg(statusColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniValue(label: 'From', value: transfer.fromThavvuId)),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.textMuted),
              Expanded(child: _MiniValue(label: 'To', value: transfer.toThavvuId)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniValue(label: 'Qty', value: '${transfer.quantity}')),
              Expanded(child: _MiniValue(label: 'Date', value: _formatDate(transfer.date))),
              Expanded(child: _MiniValue(label: 'By', value: transfer.submittedBy)),
            ],
          ),
          const SizedBox(height: 12),
          _ProofBox(label: 'Photo Proof', isDone: transfer.photoPath.trim().isNotEmpty),
          if (transfer.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            _NoteBox(text: transfer.note, color: AppTheme.info),
          ],
          if (transfer.hodNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _NoteBox(text: 'HOD Note: ${transfer.hodNote}', color: AppTheme.warning),
          ],
          if (transfer.status == HodTransferStatus.submitted ||
              transfer.status == HodTransferStatus.needsProof) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Verify',
                    icon: Icons.verified_outlined,
                    color: AppTheme.success,
                    onTap: () => _verifyTransfer(transfer, HodTransferStatus.verified),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Need Proof',
                    icon: Icons.photo_camera_back_outlined,
                    color: AppTheme.warning,
                    onTap: () => _verifyTransfer(transfer, HodTransferStatus.needsProof),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(HodPaymentReview payment) {
    final statusColor = _paymentStatusColor(payment.status);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: Icons.payments_outlined, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payment.supplierName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${payment.id} • ${payment.rentalId} • ${payment.itemName}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _StatusPill(
                label: payment.status.label,
                color: statusColor,
                backgroundColor: _softBg(statusColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniValue(label: 'Requested', value: _formatMoney(payment.requestedAmount))),
              Expanded(child: _MiniValue(label: 'Approved', value: _formatMoney(payment.approvedAmount))),
              Expanded(child: _MiniValue(label: 'Method', value: payment.method)),
            ],
          ),
          const SizedBox(height: 10),
          _NoteBox(text: payment.note, color: AppTheme.info),
          if (payment.hodNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _NoteBox(text: 'HOD Note: ${payment.hodNote}', color: AppTheme.warning),
          ],
          if (payment.status == HodPaymentStatus.pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Approve',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.success,
                    onTap: () => _decidePayment(payment, HodPaymentStatus.approved),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Revision',
                    icon: Icons.edit_note_outlined,
                    color: AppTheme.warning,
                    onTap: () => _decidePayment(payment, HodPaymentStatus.revisionRequested),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Reject',
                    icon: Icons.cancel_outlined,
                    color: AppTheme.danger,
                    onTap: () => _decidePayment(payment, HodPaymentStatus.rejected),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditMiniCard(HodAuditLog log) {
    return _Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _IconBadge(icon: Icons.history_rounded, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.action,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 3),
                Text('${log.module} • ${log.itemId} • ${_formatDateTime(log.date)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTable() {
    final logs = _visibleAuditLogs;
    if (logs.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        title: 'No audit logs found',
        subtitle: 'No logs match your selected date/search.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(AppTheme.primary.withOpacity(0.10)),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('Module')),
          DataColumn(label: Text('Item ID')),
          DataColumn(label: Text('Actor')),
          DataColumn(label: Text('Note')),
        ],
        rows: logs.map((log) {
          return DataRow(
            cells: [
              DataCell(Text(_formatDateTime(log.date))),
              DataCell(Text(log.action)),
              DataCell(Text(log.module)),
              DataCell(Text(log.itemId)),
              DataCell(Text(log.actor)),
              DataCell(SizedBox(width: 220, child: Text(log.note))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _rentalStatusColor(HodRentalStatus status) {
    switch (status) {
      case HodRentalStatus.active:
        return AppTheme.success;
      case HodRentalStatus.atSite:
        return AppTheme.warning;
      case HodRentalStatus.closed:
        return AppTheme.textMuted;
    }
  }

  Color _reviewStatusColor(HodReviewStatus status) {
    switch (status) {
      case HodReviewStatus.pending:
        return AppTheme.warning;
      case HodReviewStatus.approved:
        return AppTheme.success;
      case HodReviewStatus.revisionRequested:
        return AppTheme.info;
      case HodReviewStatus.rejected:
        return AppTheme.danger;
    }
  }

  Color _transferStatusColor(HodTransferStatus status) {
    switch (status) {
      case HodTransferStatus.submitted:
        return AppTheme.warning;
      case HodTransferStatus.verified:
        return AppTheme.success;
      case HodTransferStatus.needsProof:
        return AppTheme.danger;
    }
  }

  Color _paymentStatusColor(HodPaymentStatus status) {
    switch (status) {
      case HodPaymentStatus.pending:
        return AppTheme.warning;
      case HodPaymentStatus.approved:
        return AppTheme.success;
      case HodPaymentStatus.revisionRequested:
        return AppTheme.info;
      case HodPaymentStatus.rejected:
        return AppTheme.danger;
    }
  }

  Color _softBg(Color color) => color.withOpacity(0.11);

  String _formatMoney(num amount) => '₹${amount.toStringAsFixed(0)}';

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum HodRentalStatus { active, atSite, closed }

extension HodRentalStatusX on HodRentalStatus {
  String get label {
    switch (this) {
      case HodRentalStatus.active:
        return 'Active';
      case HodRentalStatus.atSite:
        return 'At Site';
      case HodRentalStatus.closed:
        return 'Closed';
    }
  }
}

enum HodPriority { high, normal, low }

extension HodPriorityX on HodPriority {
  String get label {
    switch (this) {
      case HodPriority.high:
        return 'High';
      case HodPriority.normal:
        return 'Normal';
      case HodPriority.low:
        return 'Low';
    }
  }
}

enum HodReviewStatus { pending, approved, revisionRequested, rejected }

extension HodReviewStatusX on HodReviewStatus {
  String get label {
    switch (this) {
      case HodReviewStatus.pending:
        return 'Pending';
      case HodReviewStatus.approved:
        return 'Approved';
      case HodReviewStatus.revisionRequested:
        return 'Revision Requested';
      case HodReviewStatus.rejected:
        return 'Rejected';
    }
  }
}

enum HodTransferStatus { submitted, verified, needsProof }

extension HodTransferStatusX on HodTransferStatus {
  String get label {
    switch (this) {
      case HodTransferStatus.submitted:
        return 'Submitted';
      case HodTransferStatus.verified:
        return 'Verified';
      case HodTransferStatus.needsProof:
        return 'Needs Proof';
    }
  }
}

enum HodPaymentStatus { pending, approved, revisionRequested, rejected }

extension HodPaymentStatusX on HodPaymentStatus {
  String get label {
    switch (this) {
      case HodPaymentStatus.pending:
        return 'Pending';
      case HodPaymentStatus.approved:
        return 'Approved';
      case HodPaymentStatus.revisionRequested:
        return 'Revision Requested';
      case HodPaymentStatus.rejected:
        return 'Rejected';
    }
  }
}

class HodRentalRecord {
  final String id;
  final String machineName;
  final String supplierName;
  final String siteName;
  final String supervisorName;
  final String thavvuId;
  final String tankId;
  final int quantity;
  final int activeQuantity;
  final double ratePerDay;
  final double advancePaid;
  final double fuelAmount;
  final DateTime startDate;
  final DateTime? closeDate;
  final DateTime? lastCheckIn;
  final HodRentalStatus status;
  final HodPriority priority;
  final bool openingPhotoUploaded;
  final bool billPhotoUploaded;
  final bool closingProofUploaded;
  final String note;

  const HodRentalRecord({
    required this.id,
    required this.machineName,
    required this.supplierName,
    required this.siteName,
    required this.supervisorName,
    required this.thavvuId,
    required this.tankId,
    required this.quantity,
    required this.activeQuantity,
    required this.ratePerDay,
    required this.advancePaid,
    required this.fuelAmount,
    required this.startDate,
    this.closeDate,
    this.lastCheckIn,
    required this.status,
    required this.priority,
    required this.openingPhotoUploaded,
    required this.billPhotoUploaded,
    required this.closingProofUploaded,
    this.note = '',
  });

  int get runningDays {
    final end = closeDate ?? DateTime.now();
    final days = end.difference(startDate).inDays;
    return days <= 0 ? 1 : days;
  }

  double get estimatedRentalAmount => runningDays * ratePerDay * quantity;

  bool get hasMissingProof {
    if (!openingPhotoUploaded || !billPhotoUploaded) return true;
    if (status == HodRentalStatus.closed && !closingProofUploaded) return true;
    return false;
  }

  bool get isCheckInDelayed {
    if (status != HodRentalStatus.active) return false;
    if (lastCheckIn == null) return true;
    return DateTime.now().difference(lastCheckIn!).inHours > 24;
  }
}

class HodRentalApproval {
  final String id;
  final String rentalId;
  final String title;
  final String requestedBy;
  final String siteName;
  final double amount;
  final HodPriority priority;
  HodReviewStatus status;
  final DateTime createdAt;
  DateTime? decidedAt;
  final String description;
  final String proofSummary;
  String hodNote;

  HodRentalApproval({
    required this.id,
    required this.rentalId,
    required this.title,
    required this.requestedBy,
    required this.siteName,
    required this.amount,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    required this.description,
    required this.proofSummary,
    this.hodNote = '',
  });
}

class HodTransferReview {
  final String id;
  final DateTime date;
  final String fromThavvuId;
  final String toThavvuId;
  final String rentalId;
  final String itemName;
  final int quantity;
  final String submittedBy;
  HodTransferStatus status;
  final String photoPath;
  final String note;
  String hodNote;
  DateTime? verifiedAt;

  HodTransferReview({
    required this.id,
    required this.date,
    required this.fromThavvuId,
    required this.toThavvuId,
    required this.rentalId,
    required this.itemName,
    required this.quantity,
    required this.submittedBy,
    required this.status,
    this.photoPath = '',
    this.note = '',
    this.hodNote = '',
    this.verifiedAt,
  });
}

class HodPaymentReview {
  final String id;
  final String supplierName;
  final String rentalId;
  final String itemName;
  final double requestedAmount;
  double approvedAmount;
  final String method;
  final String requestedBy;
  HodPaymentStatus status;
  final DateTime createdAt;
  DateTime? decidedAt;
  final String note;
  String hodNote;

  HodPaymentReview({
    required this.id,
    required this.supplierName,
    required this.rentalId,
    required this.itemName,
    required this.requestedAmount,
    this.approvedAmount = 0,
    required this.method,
    required this.requestedBy,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.note = '',
    this.hodNote = '',
  });
}

class HodAuditLog {
  final String id;
  final DateTime date;
  final String action;
  final String module;
  final String itemId;
  final String actor;
  final String note;

  const HodAuditLog({
    required this.id,
    required this.date,
    required this.action,
    required this.module,
    required this.itemId,
    required this.actor,
    this.note = '',
  });
}

class _RiskAlert {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _RiskAlert({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE UI WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(icon: icon, color: color, size: 34),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, size: 17, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofIssueRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String type;

  const _ProofIssueRow({
    required this.title,
    required this.subtitle,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          _StatusPill(
            label: type,
            color: AppTheme.danger,
            backgroundColor: AppTheme.danger.withOpacity(0.10),
          ),
        ],
      ),
    );
  }
}

class _TabScaffold extends StatelessWidget {
  final List<Widget> children;

  const _TabScaffold({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _Card({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon, color: color, size: 36),
              const Spacer(),
              Icon(Icons.trending_up_rounded, size: 18, color: color),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FilterBox extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  const _FilterBox({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: values.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                '$label: $item',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconBadge({required this.icon, required this.color, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.36),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  final String label;
  final String value;

  const _MiniValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofBox extends StatelessWidget {
  final String label;
  final bool isDone;

  const _ProofBox({required this.label, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final color = isDone ? AppTheme.success : AppTheme.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDone ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String text;
  final Color color;

  const _NoteBox({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.35)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
