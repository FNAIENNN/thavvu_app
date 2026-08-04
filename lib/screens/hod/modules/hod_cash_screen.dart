import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/attendance_context_service.dart';
import '../../../services/cash_repository.dart';
import '../../../services/csv_export_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

/// HOD Cash Module — Supabase-backed review dashboard.
///
/// Mirrors the supervisor Cash module (allocations, ledger, approvals) with
/// HOD-specialized powers:
///   1. Issue / allocate cash to site supervisors (cash_allocations)
///   2. Review supervisor cash transactions and approve / pay / reject
///   3. Running available balance and full audit trail
///
/// All data flows through [CashRepository] (cash_allocations +
/// cash_transactions tables) with realtime watching — no local storage.
class HodCashScreen extends StatefulWidget {
  const HodCashScreen({super.key});

  @override
  State<HodCashScreen> createState() => _HodCashScreenState();
}

class _CashSupervisor {
  final String id;
  final String empId;
  final String name;

  const _CashSupervisor({required this.id, required this.empId, required this.name});
}

class _HodCashScreenState extends State<HodCashScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Live backend integration ─────────────────────────────────
  final CashRepository _cashRepo = CashRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  RealtimeChannel? _cashChannel;
  String _hodSiteId = 'SITE-VJA-001';

  final List<CashAllocation> _allocations = <CashAllocation>[];
  final List<CashTransactionRecord> _transactions = <CashTransactionRecord>[];
  final List<_CashSupervisor> _supervisors = <_CashSupervisor>[];

  bool _loading = true;
  bool _busy = false;
  double _availableBalance = 0;

  // ── Filters ──────────────────────────────────────────────────
  String _txnStatusFilter = 'All';
  String _txnTypeFilter = 'All';
  String _allocationStatusFilter = 'All';

  // ── Issue cash form ──────────────────────────────────────────
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  _CashSupervisor? _selectedSupervisor;
  String _issueMode = 'cash';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _purposeController.text = 'Site daily cash allocation';
    unawaited(_initServer());
  }

  @override
  void dispose() {
    _cashRepo.stopWatching(_cashChannel);
    _tabController.dispose();
    _amountController.dispose();
    _purposeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initServer() async {
    try {
      final siteId = await _contextService.resolveSiteId();
      if (!mounted) return;
      _hodSiteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
      _cashChannel = _cashRepo.watchAll(_hodSiteId, _loadServerData);
      await _loadServerData();
    } catch (_) {
      // Supabase not initialized / offline: render the empty dashboard
      // instead of hanging on a spinner.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadServerData() async {
    try {
      final results = await Future.wait([
        _cashRepo.fetchAllocations(siteId: _hodSiteId),
        _cashRepo.fetchTransactions(siteId: _hodSiteId),
        _cashRepo.availableBalance(_hodSiteId),
        _loadSupervisors(),
      ]);
      if (!mounted) return;
      setState(() {
        _allocations
          ..clear()
          ..addAll(results[0] as List<CashAllocation>);
        _transactions
          ..clear()
          ..addAll(results[1] as List<CashTransactionRecord>);
        _availableBalance = results[2] as double;
        _supervisors
          ..clear()
          ..addAll(results[3] as List<_CashSupervisor>);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<_CashSupervisor>> _loadSupervisors() async {
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, emp_id, full_name')
          .eq('role', 'supervisor')
          .order('full_name');
      return (rows as List)
          .map((row) => _CashSupervisor(
                id: (row as Map)['id']?.toString() ?? '',
                empId: row['emp_id']?.toString() ?? '',
                name: row['full_name']?.toString() ?? 'Supervisor',
              ))
          .toList();
    } catch (_) {
      return const <_CashSupervisor>[];
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await _loadServerData();
    if (!mounted) return;
    _showSnack('HOD Cash dashboard refreshed.', AppTheme.info);
  }

  // ══════════════════════════════════════════════════════════════
  // HOD ACTIONS
  // ══════════════════════════════════════════════════════════════

  Future<void> _issueCash() async {
    final amount = double.tryParse(_amountController.text.trim());
    final supervisor = _selectedSupervisor;
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount to allocate.', AppTheme.warning);
      return;
    }
    if (supervisor == null) {
      _showSnack('Select a supervisor to allocate cash to.', AppTheme.warning);
      return;
    }
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _showSnack('Sign in required to allocate cash.', AppTheme.danger);
      return;
    }
    setState(() => _busy = true);
    try {
      final pointId = await _contextService.resolvePointId();
      await _cashRepo.createAllocation(
        siteId: _hodSiteId,
        allocatedBy: currentUser.id,
        allocatedTo: supervisor.id,
        amount: amount,
        balanceAfter: _availableBalance + amount,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : _purposeController.text.trim(),
        thavvuPointId: pointId,
      );
      await _cashRepo.createTransaction(
        siteId: _hodSiteId,
        txnNo: 'CASH-${DateTime.now().millisecondsSinceEpoch}',
        type: 'allocation',
        amount: amount,
        method: _issueMode,
        category: 'allocation',
        note: 'Allocated to ${supervisor.name} — ${_purposeController.text.trim()}',
        proofPath: null,
        thavvuPointId: pointId,
      );
      if (!mounted) return;
      _amountController.clear();
      _noteController.clear();
      _selectedSupervisor = null;
      _showSnack('Cash allocated to ${supervisor.name}.', AppTheme.success);
      await _loadServerData();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Allocation failed: $e', AppTheme.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewTransaction(
    CashTransactionRecord txn, {
    required String newStatus,
  }) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(
          newStatus == 'approved'
              ? 'Approve transaction'
              : newStatus == 'paid'
                  ? 'Mark as paid'
                  : 'Reject transaction',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${txn.txnNo} • ${txn.type.toUpperCase()} • ₹${txn.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'HOD note (optional)',
                hintText: 'Add a review note for the supervisor',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'rejected' ? AppTheme.danger : AppTheme.primary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              newStatus == 'approved'
                  ? 'Approve'
                  : newStatus == 'paid'
                      ? 'Mark paid'
                      : 'Reject',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await _cashRepo.updateTransactionStatus(
      transactionId: txn.id,
      status: newStatus,
      hodNote: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _showSnack(
        newStatus == 'rejected'
            ? 'Transaction rejected.'
            : newStatus == 'paid'
                ? 'Transaction marked as paid.'
                : 'Transaction approved.',
        AppTheme.success,
      );
      await _loadServerData();
    } else {
      _showSnack('Review failed. Check RLS permissions.', AppTheme.danger);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // DERIVED DATA
  // ══════════════════════════════════════════════════════════════

  List<CashTransactionRecord> get _filteredTransactions {
    return _transactions.where((txn) {
      final matchStatus =
          _txnStatusFilter == 'All' || txn.status == _txnStatusFilter;
      final matchType = _txnTypeFilter == 'All' || txn.type == _txnTypeFilter;
      return matchStatus && matchType;
    }).toList();
  }

  List<CashAllocation> get _filteredAllocations {
    return _allocations.where((allocation) {
      if (_allocationStatusFilter == 'All') return true;
      if (_allocationStatusFilter == 'Active') return allocation.balanceAfter > 0;
      return allocation.balanceAfter <= 0;
    }).toList();
  }

  double get _totalAllocated =>
      _allocations.fold(0, (sum, a) => sum + a.amount);

  double get _totalSpent => _transactions
      .where((t) => t.status == 'approved' || t.status == 'paid')
      .fold(0, (sum, t) => sum + t.amount);

  int get _pendingCount =>
      _transactions.where((t) => t.status == 'submitted').length;

  String _supervisorName(String? id) {
    if (id == null) return 'Site';
    final match = _supervisors.where((s) => s.id == id).toList();
    if (match.isNotEmpty) return match.first.name;
    return id.length > 12 ? 'Supervisor' : id;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatMoney(double value) {
    return '₹${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.success;
      case 'paid':
        return AppTheme.info;
      case 'rejected':
        return AppTheme.danger;
      default:
        return AppTheme.warning;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.successBg;
      case 'paid':
        return AppTheme.infoBg;
      case 'rejected':
        return AppTheme.dangerBg;
      default:
        return AppTheme.warningBg;
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: 'HOD Cash',
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _busy ? null : _refreshAll,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Allocations'),
        Tab(text: 'Approvals'),
        Tab(text: 'Ledger'),
        Tab(text: 'Audit'),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAllocationsTab(),
          _buildApprovalsTab(),
          _buildLedgerTab(),
          _buildAuditTab(),
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
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.white70),
              SizedBox(width: 6),
              Text('AVAILABLE BALANCE',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _loading ? '…' : _formatMoney(_availableBalance),
            style: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _heroMetric('Allocated', _formatMoney(_totalAllocated)),
              _heroMetric('Spent', _formatMoney(_totalSpent)),
              _heroMetric('Pending', '$_pendingCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      ],
    );
  }

  Widget _loadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }

  Widget _emptyView(String message) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 42, color: AppTheme.textHint),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor(status)),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_loading) return _loadingView();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildHeroHeader(),
        const SizedBox(height: 16),
        _sectionTitle(Icons.insights_outlined, 'Cash position', 'Live from cash_allocations + cash_transactions'),
        _panel(
          child: Column(
            children: [
              _metricRow(Icons.account_balance_outlined, 'Total allocated',
                  _formatMoney(_totalAllocated), AppTheme.info),
              const Divider(height: 18),
              _metricRow(Icons.payments_outlined, 'Approved / paid spend',
                  _formatMoney(_totalSpent), AppTheme.success),
              const Divider(height: 18),
              _metricRow(Icons.pending_actions_outlined, 'Pending approvals',
                  '$_pendingCount', AppTheme.warning),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(Icons.receipt_long_outlined, 'Recent transactions', 'Latest 4 ledger entries'),
        _panel(
          child: _transactions.isEmpty
              ? _emptyView('No transactions yet. Issue cash to get started.')
              : Column(
                  children: _transactions
                      .take(4)
                      .map((txn) => _txnTile(txn))
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(Icons.handshake_outlined, 'Supervisors', 'Profiles with supervisor role'),
        _panel(
          child: _supervisors.isEmpty
              ? _emptyView('No supervisor profiles found.')
              : Column(
                  children: _supervisors
                      .map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name,
                                          style: const TextStyle(
                                              fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                      Text(s.empId,
                                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textHint)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _metricRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary)),
        ),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ],
    );
  }

  // ── Tab 2: Allocations ───────────────────────────────────────

  Widget _buildAllocationsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(Icons.add_circle_outline, 'Issue cash to supervisor',
            'Creates a cash_allocation + ledger entry'),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<_CashSupervisor>(
                value: _selectedSupervisor,
                decoration: const InputDecoration(
                  labelText: 'Supervisor',
                  hintText: 'Select supervisor',
                ),
                items: _supervisors
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (${s.empId})',
                              style: const TextStyle(fontSize: 13.5)),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedSupervisor = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: 'e.g. 25000',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText: 'Site daily cash allocation',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _issueMode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                ],
                onChanged: (value) =>
                    setState(() => _issueMode = value ?? 'cash'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Allocation note shown in ledger',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _issueCash,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.send_outlined, size: 18, color: Colors.white),
                  label: Text(_busy ? 'Issuing…' : 'Allocate cash',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(Icons.history_edu_outlined, 'Allocation history',
            '${_allocations.length} allocations'),
        _panel(
          child: _allocations.isEmpty
              ? _emptyView('No allocations yet.')
              : Column(
                  children: _filteredAllocations
                      .map((a) => _allocationTile(a))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _allocationTile(CashAllocation a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_supervisorName(a.allocatedTo)} • ${_formatDate(a.createdAt)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(a.note ?? 'Cash allocation',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(_formatMoney(a.amount),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.success)),
        ],
      ),
    );
  }

  // ── Tab 3: Approvals ─────────────────────────────────────────

  Widget _buildApprovalsTab() {
    if (_loading) return _loadingView();
    final pending = _transactions
        .where((t) => t.status == 'submitted')
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(Icons.fact_check_outlined, 'Supervisor submissions',
            '${pending.length} pending review'),
        if (pending.isEmpty)
          _panel(
            child: _emptyView('No pending approvals. Everything is reviewed.'),
          )
        else
          ...pending.map(
            (txn) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(txn.txnNo,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        ),
                        _statusChip(txn.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${txn.type.toUpperCase()} • ${txn.method.toUpperCase()} • ${_formatMoney(txn.amount)}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    ),
                    if ((txn.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(txn.note!,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                    ],
                    const SizedBox(height: 6),
                    Text('${_formatDate(txn.createdAt)} ${_formatTime(txn.createdAt)}',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textHint)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _reviewTransaction(txn, newStatus: 'approved'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.success,
                              side: const BorderSide(color: AppTheme.successLight),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _reviewTransaction(txn, newStatus: 'paid'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.info,
                              side: const BorderSide(color: AppTheme.infoLight),
                            ),
                            icon: const Icon(Icons.payments_outlined, size: 16),
                            label: const Text('Mark paid', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _reviewTransaction(txn, newStatus: 'rejected'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.danger,
                              side: const BorderSide(color: AppTheme.dangerLight),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Tab 4: Ledger ────────────────────────────────────────────

  Widget _buildLedgerTab() {
    if (_loading) return _loadingView();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(Icons.receipt_long_outlined, 'Transaction ledger',
            '${_filteredTransactions.length} of ${_transactions.length} entries'),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _txnStatusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All statuses')),
                        DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (value) =>
                          setState(() => _txnStatusFilter = value ?? 'All'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _txnTypeFilter,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All types')),
                        DropdownMenuItem(value: 'expense', child: Text('Expense')),
                        DropdownMenuItem(value: 'advance', child: Text('Advance')),
                        DropdownMenuItem(value: 'payment', child: Text('Payment')),
                        DropdownMenuItem(value: 'contra', child: Text('Contra')),
                        DropdownMenuItem(value: 'allocation', child: Text('Allocation')),
                      ],
                      onChanged: (value) =>
                          setState(() => _txnTypeFilter = value ?? 'All'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _filteredTransactions.isEmpty
                ? null
                : _exportLedgerCsv,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primaryLight),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download ledger CSV',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        if (_filteredTransactions.isEmpty)
          _panel(child: _emptyView('No ledger entries match the filters.'))
        else
          ..._filteredTransactions.map((txn) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _panel(child: _txnTile(txn)),
              )),
      ],
    );
  }

  Widget _txnTile(CashTransactionRecord txn) {
    final isInflow = txn.type == 'allocation';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openTxnDetail(txn),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isInflow ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isInflow ? Icons.south_west_outlined : Icons.north_east_outlined,
                size: 16,
                color: isInflow ? AppTheme.success : AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(txn.txnNo,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      ),
                      _statusChip(txn.status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${txn.type.toUpperCase()} • ${txn.method.toUpperCase()}',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textHint),
                  ),
                  if ((txn.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(txn.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                  ],
                  const SizedBox(height: 2),
                  Text('${_formatDate(txn.createdAt)} ${_formatTime(txn.createdAt)}',
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.textHint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isInflow ? '+' : '-'} ${_formatMoney(txn.amount)}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isInflow ? AppTheme.success : AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                const Icon(Icons.chevron_right, size: 14, color: AppTheme.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Running balance at a transaction's position in the ledger:
  /// allocations add, everything else deducts, scanning oldest → newest.
  double _runningBalanceAt(CashTransactionRecord txn) {
    final ordered = List<CashTransactionRecord>.of(_transactions)
      ..sort((a, b) {
        final ad = a.createdAt;
        final bd = b.createdAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    var balance = 0.0;
    for (final t in ordered) {
      if (t.id == txn.id) return balance + (t.type == 'allocation' ? t.amount : 0);
      if (t.status == 'approved' || t.status == 'paid') {
        balance += t.type == 'allocation' ? t.amount : -t.amount;
      }
    }
    return balance;
  }

  Future<void> _openTxnDetail(CashTransactionRecord txn) async {
    final isInflow = txn.type == 'allocation';
    final running = _runningBalanceAt(txn);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(txn.txnNo,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary)),
                ),
                _statusChip(txn.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${txn.type.toUpperCase()} • ${txn.method.toUpperCase()}',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textHint),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isInflow ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: (isInflow ? AppTheme.successLight : AppTheme.primaryLight)
                        .withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isInflow ? '+' : '-'} ${_formatMoney(txn.amount)}',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isInflow ? AppTheme.success : AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text('Running balance after this entry: ${_formatMoney(running)}',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _detailRow('Transaction no', txn.txnNo),
            _detailRow('Type', txn.type),
            _detailRow('Method', txn.method),
            _detailRow('Category', txn.category ?? '—'),
            _detailRow('Amount', _formatMoney(txn.amount)),
            _detailRow('Status', txn.status),
            _detailRow('Created', '${_formatDate(txn.createdAt)} ${_formatTime(txn.createdAt)}'),
            if (txn.hodNote != null) _detailRow('HOD note', txn.hodNote!),
            if (txn.proofPath != null && txn.proofPath!.isNotEmpty)
              _detailRow('Proof', txn.proofPath!),
            if (txn.note != null && txn.note!.isNotEmpty)
              _detailRow('Note', txn.note!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  if (txn.status == 'submitted' && !_busy) {
                    _reviewTransaction(txn, newStatus: 'approved');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primaryLight),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(
                  txn.status == 'submitted' ? Icons.fact_check_outlined : Icons.close,
                  size: 18,
                ),
                label: Text(
                  txn.status == 'submitted' ? 'Review this transaction' : 'Close',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppTheme.textHint)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLedgerCsv() async {
    final buffer = StringBuffer();
    buffer.writeln(csvRow([
      'Txn No',
      'Type',
      'Method',
      'Category',
      'Amount',
      'Status',
      'Created Date',
      'Created Time',
      'Note',
      'HOD Note',
    ]));
    for (final t in _filteredTransactions) {
      buffer.writeln(csvRow([
        t.txnNo,
        t.type,
        t.method,
        t.category ?? '',
        _formatMoney(t.amount),
        t.status,
        _formatDate(t.createdAt),
        _formatTime(t.createdAt),
        t.note ?? '',
        t.hodNote ?? '',
      ]));
    }
    final fileName =
        'hod_cash_ledger_${DateTime.now().millisecondsSinceEpoch}.csv';
    final path = await downloadCsvFile(fileName: fileName, csv: buffer.toString());
    if (!mounted) return;
    if (path != null) {
      _showSnack('Ledger saved to $path', AppTheme.success);
    } else {
      _showSnack('Ledger CSV download started.', AppTheme.success);
    }
  }

  // ── Tab 5: Audit ─────────────────────────────────────────────

  Widget _buildAuditTab() {
    if (_loading) return _loadingView();

    final audit = <_AuditEntry>[];
    for (final a in _allocations) {
      audit.add(_AuditEntry(
        icon: Icons.add_card_outlined,
        color: AppTheme.info,
        title: 'Cash allocated ${_formatMoney(a.amount)}',
        subtitle: '${_supervisorName(a.allocatedTo)} • ${a.note ?? 'No note'}',
        date: a.createdAt,
      ));
    }
    for (final t in _transactions) {
      audit.add(_AuditEntry(
        icon: Icons.fact_check_outlined,
        color: _statusColor(t.status),
        title: '${t.txnNo} ${t.type} ${_formatMoney(t.amount)} → ${t.status}',
        subtitle: t.hodNote != null
            ? 'HOD note: ${t.hodNote}'
            : '${t.method.toUpperCase()} • ${t.category ?? 'No category'}',
        date: t.createdAt,
      ));
    }
    audit.sort((a, b) {
      final ad = a.date;
      final bd = b.date;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _sectionTitle(Icons.track_changes_outlined, 'Audit trail',
            'All allocations and ledger events, newest first'),
        if (audit.isEmpty)
          _panel(child: _emptyView('No cash activity yet.'))
        else
          _panel(
            child: Column(
              children: [
                for (var i = 0; i < audit.length; i++)
                  _auditRow(audit[i], key: ValueKey('audit-$i')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _auditRow(_AuditEntry entry, {required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(entry.icon, size: 15, color: entry.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text(entry.subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${_formatDate(entry.date)} ${_formatTime(entry.date)}',
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textHint)),
        ],
      ),
    );
  }
}

class _AuditEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime? date;

  const _AuditEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.date,
  });
}
