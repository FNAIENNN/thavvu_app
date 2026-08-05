import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/gin_repository.dart';
import '../../../theme/app_theme.dart';
import '../../gin/gin_bill_details_screen.dart';

/// HOD GIN Approvals module.
///
/// Every GIN bill submitted by supervisors appears here with the full
/// reconciliation table and the supervisor's ACTIONS (Shortage / Extra / OK)
/// visible per line. HOD approves (received stock is added to the Thavvu
/// Point automatically) or rejects with a note.
class HodGinApprovalsScreen extends StatefulWidget {
  const HodGinApprovalsScreen({super.key});

  @override
  State<HodGinApprovalsScreen> createState() => _HodGinApprovalsScreenState();
}

class _HodGinApprovalsScreenState extends State<HodGinApprovalsScreen> {
  final GinRepository _repo = GinRepository();
  List<GinBill> _bills = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _repo.watchGinBills(_load);
  }

  @override
  void dispose() {
    _repo.stopWatching(_channel);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bills = await _repo.fetchBills();
      if (!mounted) return;
      setState(() {
        _bills = bills;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load GIN approvals. Pull to retry.';
      });
    }
  }

  List<GinBill> get _pending => _bills
      .where((b) => b.hodStatus == 'pending' && !b.addedToStock)
      .toList();

  List<GinBill> get _reviewed => _bills
      .where((b) => b.hodStatus != 'pending' || b.addedToStock)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('GIN Approvals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _loading = true;
              _load();
            }),
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            color: AppTheme.surface,
            child: Row(
              children: [
                _MiniTag('${_pending.length} Pending',
                    _pending.isNotEmpty ? AppTheme.warning : AppTheme.success,
                    icon: Icons.pending_actions_outlined),
                const Spacer(),
                Text('${_reviewed.length} Reviewed',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_bills.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: AppTheme.success),
            SizedBox(height: 16),
            Text('No Goods Inward Notes',
                style: TextStyle(
                    fontSize: 16, color: AppTheme.textSecondary)),
            SizedBox(height: 4),
            Text('Supervisor GIN submissions appear here for approval.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (_pending.isNotEmpty) ...[
            const _SectionLabel('Pending Approval', Icons.fact_check_outlined,
                AppTheme.warning),
            for (final bill in _pending) _buildBillCard(bill, pending: true),
          ],
          if (_reviewed.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _SectionLabel('Reviewed', Icons.verified_outlined,
                AppTheme.success),
            for (final bill in _reviewed) _buildBillCard(bill, pending: false),
          ],
        ],
      ),
    );
  }

  Widget _buildBillCard(GinBill bill, {required bool pending}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openBill(bill),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: bill.isRejected
                    ? AppTheme.danger.withValues(alpha: 0.4)
                    : pending
                        ? AppTheme.warning.withValues(alpha: 0.35)
                        : AppTheme.border,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: bill.isRejected
                        ? AppTheme.danger.withValues(alpha: 0.1)
                        : AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    bill.isRejected
                        ? Icons.cancel_outlined
                        : bill.addedToStock
                            ? Icons.verified_outlined
                            : Icons.receipt_long,
                    color: bill.isRejected
                        ? AppTheme.danger
                        : bill.addedToStock
                            ? AppTheme.success
                            : AppTheme.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bill #${bill.billNumber}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('${bill.supplierName} · ${bill.thavvuPointName}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _MiniTag('${bill.lines.length} items', AppTheme.info),
                        if (bill.shortageCount > 0)
                          _MiniTag('${bill.shortageCount} shortage',
                              AppTheme.warning),
                        if (bill.excessCount > 0)
                          _MiniTag('${bill.excessCount} extra',
                              AppTheme.info),
                        if (bill.matchedCount > 0)
                          _MiniTag('${bill.matchedCount} matched',
                              AppTheme.success),
                        if (bill.isRejected)
                          const _MiniTag('Rejected', AppTheme.danger),
                        if (bill.addedToStock)
                          const _MiniTag('Added', AppTheme.success),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openBill(GinBill bill) async {
    final updated = await Navigator.push<GinBill?>(
      context,
      MaterialPageRoute(
        builder: (_) => GinBillDetailsScreen(
          bill: bill,
          mode: GinReviewMode.hod,
          repo: _repo,
          onChanged: (_) {},
        ),
      ),
    );
    if (updated != null && mounted) _load();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _SectionLabel(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _MiniTag(this.label, this.color, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
