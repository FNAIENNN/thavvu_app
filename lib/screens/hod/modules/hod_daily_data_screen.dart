import 'package:flutter/material.dart';

import '../../../features/hod_machine/data/repositories/supabase_hod_machine_repository.dart';
import '../../../features/hod_machine/domain/models/machine_daily_log.dart';
import '../../../features/hod_machine/domain/models/machine_payment_request.dart';
import '../../../features/hod_machine/domain/services/hod_machine_repository_interface.dart';
import '../../../features/hod_machine/presentation/widgets/daily_log_detail_sheet.dart';
import '../../../features/hod_machine/presentation/widgets/daily_log_review_card.dart';
import '../../../features/hod_machine/presentation/widgets/machine_context_card.dart';
import '../../../features/hod_machine/presentation/widgets/machine_status_chip.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

/// HOD Daily Data Review screen — Supabase refactor.
///
/// Replaces the previous in-memory seed implementation. The screen now
/// loads real machine daily logs + payment requests via
/// [HodMachineRepository] (Supabase-backed) and renders them through the
/// new reusable widget cards (`DailyLogReviewCard`, `MachineStatusChip`,
/// `MachineContextCard`, `DailyLogDetailSheet`).
class HodDailyDataScreen extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String thavvuPointId;
  final String supervisorId;
  final String supervisorName;
  final String hodId;

  const HodDailyDataScreen({
    super.key,
    this.siteId = 'SITE-VJA-001',
    this.siteName = 'Demo Site',
    this.thavvuPointId = 'TP-VJA-001',
    this.supervisorId = 'SUP-VJA-001',
    this.supervisorName = 'Supervisor Rajesh',
    this.hodId = 'HOD-001',
  });

  @override
  State<HodDailyDataScreen> createState() => _HodDailyDataScreenState();
}

class _HodDailyDataScreenState extends State<HodDailyDataScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final HodMachineRepository _repository = SupabaseHodMachineRepository(null);

  String _statusFilter = 'All';
  String _dateFilter = 'All';

  List<MachineDailyLog> _logs = [];
  List<MachinePaymentRequest> _paymentRequests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final logs = await _repository.getDailyLogs(
        siteId: widget.siteId,
        thavvuPointId: widget.thavvuPointId,
        supervisorId: widget.supervisorId,
      );
      final payments = await _repository.getPaymentRequests(
        siteId: widget.siteId,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _paymentRequests = payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<MachineDailyLog> get _pendingLogs => _filteredLogs
      .where((log) => log.status == DailyLogStatus.submitted)
      .toList();

  List<MachineDailyLog> get _historyLogs => _filteredLogs
      .where((log) =>
          log.status == DailyLogStatus.approved ||
          log.status == DailyLogStatus.revisionRequested ||
          log.status == DailyLogStatus.rejected)
      .toList();

  List<MachinePaymentRequest> get _financeRequests => _paymentRequests
      .where((p) =>
          p.status == PaymentStatus.submittedToFinance ||
          p.status == PaymentStatus.financeProcessing ||
          p.status == PaymentStatus.paid)
      .toList();

  List<MachineDailyLog> get _filteredLogs {
    final query = _searchController.text.trim().toLowerCase();
    return _logs.where((log) {
      if (query.isNotEmpty) {
        final text = [
          log.id,
          log.machineId,
          log.location ?? '',
          log.notes ?? '',
          log.dieselOption ?? '',
        ].join(' ').toLowerCase();
        if (!text.contains(query)) return false;
      }

      if (_statusFilter != 'All') {
        if (_statusFilter == 'Pending' && log.status != DailyLogStatus.submitted) {
          return false;
        }
        if (_statusFilter == 'Approved' && log.status != DailyLogStatus.approved) {
          return false;
        }
        if (_statusFilter == 'Revision' &&
            log.status != DailyLogStatus.revisionRequested) {
          return false;
        }
        if (_statusFilter == 'Rejected' &&
            log.status != DailyLogStatus.rejected) {
          return false;
        }
      }

      if (_dateFilter != 'All') {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final day = DateTime(
          log.logDate.year,
          log.logDate.month,
          log.logDate.day,
        );
        if (_dateFilter == 'Today' && day != today) return false;
        if (_dateFilter == 'Yesterday' &&
            day != today.subtract(const Duration(days: 1))) {
          return false;
        }
        if (_dateFilter == 'Last 7 Days' &&
            day.isBefore(today.subtract(const Duration(days: 7)))) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) => b.logDate.compareTo(a.logDate));
  }

  double get _pendingAmount => _pendingLogs.fold<double>(
        0,
        (sum, log) => sum + log.dieselAmount + log.betaAmount + log.extraBetaAmount,
      );

  double get _financeAmount => _financeRequests
      .where((p) => p.isAdvance)
      .fold<double>(0, (sum, p) => sum + p.amount);

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: 'HOD Daily Data Review',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.maybePop(context),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Pending'),
        Tab(text: 'History'),
        Tab(text: 'Finance'),
        Tab(text: 'Audit'),
      ],
      header: Column(
        children: [
          MachineContextCard(
            siteName: widget.siteName,
            siteId: widget.siteId,
            thavvuPointName: widget.thavvuPointId,
            supervisorName: widget.supervisorName,
            hodId: widget.hodId,
          ),
          _buildTopHeader(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingTab(),
                    _buildHistoryTab(),
                    _buildFinanceTab(),
                    _buildAuditTab(),
                  ],
                ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          _buildHeaderStat('Pending', '${_pendingLogs.length}'),
          const SizedBox(width: 8),
          _buildHeaderStat('Amount', '₹${_pendingAmount.toStringAsFixed(0)}'),
          const SizedBox(width: 8),
          _buildHeaderStat(
              'Finance', '₹${_financeAmount.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.11),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Column(
          children: [
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(
              'Failed to load daily data',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    return _buildReviewList(
      emptyTitle: 'No pending daily data',
      emptySubtitle: 'Supervisor machine logs will appear here for HOD review.',
      logs: _pendingLogs,
      showActions: true,
    );
  }

  Widget _buildHistoryTab() {
    return _buildReviewList(
      emptyTitle: 'No review history',
      emptySubtitle: 'Approved, rejected and revision logs appear here.',
      logs: _historyLogs,
      showActions: false,
    );
  }

  Widget _buildReviewList({
    required String emptyTitle,
    required String emptySubtitle,
    required List<MachineDailyLog> logs,
    required bool showActions,
  }) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _buildFilters(),
          const SizedBox(height: 14),
          if (logs.isEmpty)
            _buildEmptyState(emptyTitle, emptySubtitle)
          else
            ...logs.map(
              (log) => DailyLogReviewCard(
                log: log,
                showActions: showActions,
                onApprove: () => _approveLog(log),
                onReject: () => _rejectLog(log),
                onRequestRevision: () => _requestRevision(log),
                onTap: () => _openLogDetails(log),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
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
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by machine, ID, notes...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _searchController.clear(),
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
            value: _statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter status',
              prefixIcon: Icon(Icons.filter_list_outlined),
            ),
            items: const ['All', 'Pending', 'Approved', 'Revision', 'Rejected']
                .map((s) =>
                    DropdownMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const ['All', 'Today', 'Yesterday', 'Last 7 Days']
                  .map(_buildDateChip)
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String item) {
    final selected = _dateFilter == item;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        side: BorderSide(
          color: selected ? AppTheme.primary : AppTheme.border,
        ),
        label: Text(item),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : AppTheme.textSecondary,
        ),
        onSelected: (_) => setState(() => _dateFilter = item),
      ),
    );
  }

  Widget _buildFinanceTab() {
    final items = _financeRequests;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _buildFinanceSummary(items),
        const SizedBox(height: 14),
        if (items.isEmpty)
          _buildEmptyState(
            'No finance queue',
            'Approved advance requests submitted to finance will appear here.',
          )
        else
          ...items.map(_buildFinanceCard),
      ],
    );
  }

  Widget _buildFinanceSummary(List<MachinePaymentRequest> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.success.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: AppTheme.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${items.length} finance item(s) • ₹${_financeAmount.toStringAsFixed(0)} pending/paid',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard(MachinePaymentRequest p) {
    final paid = p.status == PaymentStatus.paid;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.request_quote_outlined,
                    color: AppTheme.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${p.kind.apiValue.toUpperCase()} • ₹${p.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              MachineStatusChip(
                label: paid ? 'Paid' : p.status.displayLabel,
                customColor: paid ? AppTheme.success : AppTheme.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoCell('Request', p.id)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoCell(
                  'Method',
                  p.paymentMode ?? p.entryMethod ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (paid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.successBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.22)),
              ),
              child: Text(
                'Payment proof: ${p.paymentProofPath ?? '-'} • Machine IDs Book: ${p.registeredInIdsBook ? 'Yes' : 'No'}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markFinancePaid(p),
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Mark Paid'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    // Audit events are derived from action history in the audit log
    // (machine_audit_logs table). For brevity here we render a placeholder
    // until the audit endpoint is wired.
    return _buildEmptyState(
      'No audit logs',
      'HOD action history will appear here as it is recorded.',
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 46, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCell(String label, String value) {
    return Container(
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
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  void _openLogDetails(MachineDailyLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DailyLogDetailSheet(
        log: log,
        onApprove: log.status == DailyLogStatus.submitted
            ? () => _approveLog(log)
            : null,
        onReject: log.status == DailyLogStatus.submitted
            ? () => _rejectLog(log)
            : null,
        onRequestRevision: log.status == DailyLogStatus.submitted
            ? () => _requestRevision(log)
            : null,
      ),
    );
  }

  Future<void> _approveLog(MachineDailyLog log) async {
    try {
      await _repository.reviewDailyLog(
        logId: log.id,
        hodId: widget.hodId,
        status: 'approved',
        hodNote: 'Approved by HOD.',
      );
      await _loadData();
      _showSnackbar('Daily log approved', AppTheme.success);
    } catch (e) {
      _showSnackbar('Approve failed: $e', AppTheme.danger);
    }
  }

  Future<void> _requestRevision(MachineDailyLog log) async {
    final note = await _showNoteDialog(
      title: 'Request Revision',
      hint: 'Explain what supervisor should correct',
      color: AppTheme.warning,
    );
    if (note == null) return;
    try {
      await _repository.reviewDailyLog(
        logId: log.id,
        hodId: widget.hodId,
        status: 'revision_requested',
        hodNote: note,
      );
      await _loadData();
      _showSnackbar('Revision requested', AppTheme.warning);
    } catch (e) {
      _showSnackbar('Revision failed: $e', AppTheme.danger);
    }
  }

  Future<void> _rejectLog(MachineDailyLog log) async {
    final note = await _showNoteDialog(
      title: 'Reject Daily Data',
      hint: 'Reason for rejection',
      color: AppTheme.danger,
    );
    if (note == null) return;
    try {
      await _repository.reviewDailyLog(
        logId: log.id,
        hodId: widget.hodId,
        status: 'rejected',
        hodNote: note,
      );
      await _loadData();
      _showSnackbar('Daily log rejected', AppTheme.danger);
    } catch (e) {
      _showSnackbar('Reject failed: $e', AppTheme.danger);
    }
  }

  Future<void> _markFinancePaid(MachinePaymentRequest p) async {
    try {
      await _repository.completeFinancePayment(
        paymentId: p.id,
        proofPath: 'finance_proof_${p.id}.jpg',
        registerInIdsBook: true,
      );
      await _loadData();
      _showSnackbar('Finance payment completed', AppTheme.success);
    } catch (e) {
      _showSnackbar('Mark paid failed: $e', AppTheme.danger);
    }
  }

  Future<String?> _showNoteDialog({
    required String title,
    required String hint,
    required Color color,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
