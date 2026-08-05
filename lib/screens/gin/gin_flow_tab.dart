import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/gin_repository.dart';
import '../../services/supabase_supplier_repository.dart';
import '../../theme/app_theme.dart';
import 'gin_bill_details_screen.dart';

/// Supervisor GIN tab.
///
/// Lists every Thavvu Point with its pending Goods Inward bills:
///   Thavvu Point → Bill numbers → GIN reconciliation table (ACTIONS column)
///
/// A prominent "New GIN Entry" button composes a fresh supplier bill and
/// opens the same reconciliation table before submitting to HOD.
class GinFlowTab extends StatefulWidget {
  const GinFlowTab({super.key});

  @override
  State<GinFlowTab> createState() => _GinFlowTabState();
}

class _GinFlowTabState extends State<GinFlowTab> {
  final _repo = GinRepository();
  List<GinThavvuPoint> _points = [];
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
      final results = await Future.wait([
        _repo.fetchThavvuPoints(),
        _repo.fetchBills(),
      ]);
      if (!mounted) return;
      setState(() {
        _points = results[0] as List<GinThavvuPoint>;
        _bills = results[1] as List<GinBill>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load GIN data. Pull to retry.';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  List<GinBill> _billsForPoint(String pointId) =>
      _bills.where((b) => b.thavvuPointId == pointId).toList();

  int get _pendingCount =>
      _bills.where((b) => b.isPending || b.isRejected).length;
  int get _addedCount =>
      _bills.where((b) => b.addedToStock).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 10),
        _buildNewEntryButton(),
        const SizedBox(height: 10),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.receipt_long,
                color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Goods Inward Notes',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                Text('Supplier bills at Thavvu Points · HOD approval',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 20, color: AppTheme.info),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildNewEntryButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async {
            if (_points.isEmpty) {
              _snack('No Thavvu Points available for GIN entry.',
                  AppTheme.warning);
              return;
            }
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => GinComposerScreen(
                  repo: _repo,
                  points: _points,
                ),
              ),
            );
            if (changed == true && mounted) _load();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add_circle_outline,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New GIN Entry',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Compose a supplier bill & reconcile items',
                          style: TextStyle(
                              fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.white70),
              ],
            ),
          ),
        ),
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
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_points.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warehouse_outlined,
                size: 56, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('No Thavvu Points assigned',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            SizedBox(height: 4),
            Text('GIN bills appear here grouped by Thavvu Point',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Row(
            children: [
              _MiniTag('$_pendingCount Pending',
                  _pendingCount > 0 ? AppTheme.warning : AppTheme.success,
                  icon: Icons.pending_actions_outlined),
              const Spacer(),
              Text('$_addedCount Added to Stock',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          for (final point in _points)
            _buildPointCard(point, _billsForPoint(point.id)),
        ],
      ),
    );
  }

  Widget _buildPointCard(GinThavvuPoint point, List<GinBill> bills) {
    final pending =
        bills.where((b) => b.isPending || b.isRejected).toList();
    final added = bills.where((b) => b.addedToStock).toList();
    final shortageLines =
        pending.fold<int>(0, (s, b) => s + b.shortageCount);
    final excessLines = pending.fold<int>(0, (s, b) => s + b.excessCount);
    final hasIssues = shortageLines > 0 || excessLines > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => GinPointBillsScreen(
                  repo: _repo,
                  point: point,
                  bills: bills,
                ),
              ),
            );
            if (changed == true && mounted) _load();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasIssues
                    ? AppTheme.warning.withValues(alpha: 0.4)
                    : AppTheme.border,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.warehouse,
                      color: AppTheme.warning, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(point.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _MiniTag(
                              '${pending.length} bill${pending.length == 1 ? '' : 's'} pending',
                              AppTheme.info),
                          if (shortageLines > 0)
                            _MiniTag('$shortageLines shortage',
                                AppTheme.warning),
                          if (excessLines > 0)
                            _MiniTag('$excessLines extra', AppTheme.info),
                          if (added.isNotEmpty)
                            _MiniTag('${added.length} added',
                                AppTheme.success),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: AppTheme.textMuted, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
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
}

// ─── Bills list for one Thavvu Point ─────────────────────────────────────────

class GinPointBillsScreen extends StatefulWidget {
  final GinRepository repo;
  final GinThavvuPoint point;
  final List<GinBill> bills;

  const GinPointBillsScreen({
    super.key,
    required this.repo,
    required this.point,
    required this.bills,
  });

  @override
  State<GinPointBillsScreen> createState() => _GinPointBillsScreenState();
}

class _GinPointBillsScreenState extends State<GinPointBillsScreen> {
  @override
  Widget build(BuildContext context) {
    final pending = widget.bills
        .where((b) => b.isPending || b.isRejected)
        .toList();
    final added = widget.bills.where((b) => b.addedToStock).toList();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.point.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.info, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${pending.length} bill${pending.length == 1 ? '' : 's'} pending GIN verification',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.info),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: widget.bills.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 56, color: AppTheme.success),
                        SizedBox(height: 12),
                        Text('No GIN bills for this point yet',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: pending.length + added.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i < pending.length) {
                        return _BillCard(
                          bill: pending[i],
                          pending: true,
                          onTap: () => _openBill(pending[i]),
                        );
                      }
                      final bill = added[i - pending.length];
                      return _BillCard(
                        bill: bill,
                        pending: false,
                        onTap: () => _openBill(bill),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBill(GinBill bill) async {
    final changed = await Navigator.push<GinBill?>(
      context,
      MaterialPageRoute(
        builder: (_) => GinBillDetailsScreen(
          bill: bill,
          mode: GinReviewMode.supervisor,
          repo: widget.repo,
          onChanged: (_) {},
        ),
      ),
    );
    if (changed != null && mounted) {
      Navigator.pop(context, true);
    }
  }
}

class _BillCard extends StatelessWidget {
  final GinBill bill;
  final bool pending;
  final VoidCallback onTap;

  const _BillCard({
    required this.bill,
    required this.pending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bill.isRejected
                    ? AppTheme.danger.withValues(alpha: 0.1)
                    : AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                bill.isRejected
                    ? Icons.cancel_outlined
                    : bill.addedToStock
                        ? Icons.verified_outlined
                        : Icons.receipt,
                color: bill.isRejected
                    ? AppTheme.danger
                    : bill.addedToStock
                        ? AppTheme.success
                        : AppTheme.info,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
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
                  Text(bill.supplierName,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _MiniTag('${bill.lines.length} items', AppTheme.info),
                    if (bill.matchedCount > 0)
                      _MiniTag('${bill.matchedCount} matched',
                          AppTheme.success),
                    if (bill.shortageCount > 0)
                      _MiniTag('${bill.shortageCount} shortage',
                          AppTheme.warning),
                    if (bill.excessCount > 0)
                      _MiniTag('${bill.excessCount} extra', AppTheme.info),
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
    );
  }
}

// ─── New GIN Entry composer ──────────────────────────────────────────────────

class GinComposerScreen extends StatefulWidget {
  final GinRepository repo;
  final List<GinThavvuPoint> points;

  const GinComposerScreen({
    super.key,
    required this.repo,
    required this.points,
  });

  @override
  State<GinComposerScreen> createState() => _GinComposerScreenState();
}

class _GinComposerScreenState extends State<GinComposerScreen> {
  final SupabaseSupplierRepository _suppliers = SupabaseSupplierRepository();

  String? _pointId;
  String? _supplierId;
  final _billNumberCtrl = TextEditingController();
  DateTime? _billDate;
  String? _siteId;

  final List<_ItemDraft> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pointId = widget.points.isEmpty ? null : widget.points.first.id;
    _addItem();
    _addItem();
  }

  @override
  void dispose() {
    _billNumberCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_ItemDraft()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      _snack('At least one item is required.', AppTheme.warning);
      return;
    }
    setState(() => _items.removeAt(index).dispose());
  }

  Future<void> _openReconciliation() async {
    final point = widget.points.where((p) => p.id == _pointId).firstOrNull;
    if (point == null) {
      _snack('Select a Thavvu Point', AppTheme.warning);
      return;
    }
    final billNumber = _billNumberCtrl.text.trim();
    if (billNumber.isEmpty) {
      _snack('Enter the supplier bill number', AppTheme.warning);
      return;
    }

    final lines = <GinBillLine>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final name = item.nameCtrl.text.trim();
      if (name.isEmpty) {
        _snack('Item ${i + 1}: enter an item name', AppTheme.warning);
        return;
      }
      final ordered = double.tryParse(item.orderedCtrl.text.trim()) ?? 0;
      final billed = double.tryParse(item.billedCtrl.text.trim()) ?? 0;
      final received = double.tryParse(item.receivedCtrl.text.trim()) ?? 0;
      if (billed <= 0) {
        _snack('Item ${i + 1}: billed quantity must be > 0',
            AppTheme.warning);
        return;
      }
      lines.add(GinBillLine(
        id: 'tmp-${DateTime.now().microsecondsSinceEpoch}-$i',
        itemName: name,
        orderedQty: ordered,
        billedQty: billed,
        receivedQty: received,
        uom: item.uomCtrl.text.trim().isEmpty
            ? 'units'
            : item.uomCtrl.text.trim(),
      ));
    }

    final supplierName = _supplierId == null
        ? 'Manual Supplier'
        : (_suppliersCache[_supplierId] ?? 'Supplier');

    final ginNo = await widget.repo.generateGinNo();
    if (!mounted) return;

    final draft = GinBill.draft(
      ginNo: ginNo,
      billNumber: billNumber,
      supplierId: _supplierId,
      supplierName: supplierName,
      thavvuPointId: point.id,
      thavvuPointName: point.name,
      siteId: _siteId,
      billDate: _billDate,
      lines: lines,
    );

    setState(() => _saving = true);
    final result = await Navigator.push<GinBill?>(
      context,
      MaterialPageRoute(
        builder: (_) => GinBillDetailsScreen(
          bill: draft,
          mode: GinReviewMode.supervisor,
          repo: widget.repo,
          siteId: _siteId,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) {
      _snack('GIN ${result.ginNo} submitted — HOD will review it.',
          AppTheme.success);
      Navigator.pop(context, true);
    }
  }

  Map<String, String> _suppliersCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('New GIN Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepCard(
              step: '1',
              title: 'Thavvu Point & Supplier',
              color: AppTheme.warning,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _pointId,
                    hint: const Text('Select Thavvu Point'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.warehouse_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: widget.points
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name,
                                  style:
                                      const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _pointId = value),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<dynamic>>(
                    future: _loadSuppliers(),
                    builder: (context, snapshot) {
                      final suppliers =
                          snapshot.data ?? const <dynamic>[];
                      return DropdownButtonFormField<String>(
                        initialValue: _supplierId,
                        hint: const Text('Select Supplier'),
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.business_outlined, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          for (final supplier in suppliers)
                            DropdownMenuItem(
                              value: supplier.id,
                              child: Text(supplier.name,
                                  style:
                                      const TextStyle(fontSize: 13)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _supplierId = value),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _billNumberCtrl,
                    decoration: InputDecoration(
                      labelText: 'Bill Number',
                      hintText: 'e.g., BILL-SUP-2026-120',
                      prefixIcon: const Icon(Icons.receipt_long_outlined,
                          size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(),
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 16),
                          label: Text(
                            _billDate == null
                                ? 'Bill Date (optional)'
                                : '${_billDate!.day.toString().padLeft(2, '0')}/'
                                    '${_billDate!.month.toString().padLeft(2, '0')}/'
                                    '${_billDate!.year}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.info,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
            const SizedBox(height: 16),
            _buildStepCard(
              step: '2',
              title: 'Bill Items (Ordered / Billed / Received)',
              color: AppTheme.info,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    _buildItemRow(i),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Item'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.info,
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.info, size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Next: the reconciliation table opens with a functional '
                      'ACTIONS column — Extra for excess stock, Shortage for '
                      'shortage — plus document upload before submitting to HOD.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.info, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _openReconciliation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 20),
                label: const Text('Open Reconciliation Table',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<List<dynamic>> _loadSuppliers() async {
    try {
      final list = await _suppliers.fetchForSupervisor(siteId: _siteId);
      final cache = <String, String>{};
      for (final s in list) {
        cache[s.id] = s.name;
      }
      _suppliersCache = cache;
      if (_supplierId == null && list.isNotEmpty) {
        _supplierId = list.first.id;
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required Color color,
    required Widget child,
  }) {
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(step,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
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

  Widget _buildItemRow(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.info)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: item.nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Item name (e.g., Cement OPC 53 Grade)',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeItem(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      size: 14, color: AppTheme.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _qtyField(item.orderedCtrl, 'Ordered'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _qtyField(item.billedCtrl, 'Billed'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _qtyField(item.receivedCtrl, 'Received'),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: item.uomCtrl,
                  decoration: InputDecoration(
                    hintText: 'UoM',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      style: const TextStyle(fontSize: 12),
    );
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
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
}

class _ItemDraft {
  final nameCtrl = TextEditingController();
  final orderedCtrl = TextEditingController();
  final billedCtrl = TextEditingController();
  final receivedCtrl = TextEditingController();
  final uomCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    orderedCtrl.dispose();
    billedCtrl.dispose();
    receivedCtrl.dispose();
    uomCtrl.dispose();
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
