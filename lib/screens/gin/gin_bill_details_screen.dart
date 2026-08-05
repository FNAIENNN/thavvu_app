import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/device_file_picker.dart';
import '../../services/gin_repository.dart';
import '../../theme/app_theme.dart';

/// Who is driving the bill screen.
enum GinReviewMode { supervisor, hod }

/// Multi-item GIN reconciliation screen.
///
/// Shows the full table — # / ITEM / ORD / BILLED / RCVD / DIFF (Bld−Rcvd) /
/// DIFF (Ord−Rcvd) / STATUS / **ACTIONS** — with a neat functional ACTIONS
/// column:
///   * received < billed  → "Shortage −X" button (warns, opens action sheet)
///   * received > billed  → "Extra +X" button (opens action sheet)
///   * received = billed  → "✓ OK" (one-tap Done)
///
/// Supervisor mode: received qty is editable, actions are picked, documents
/// uploaded, and the bill is submitted (or re-submitted after HOD reject).
/// HOD mode: quantities are locked, the supervisor's ACTIONS are shown, and
/// HOD approves (stock added to the Thavvu Point automatically) or rejects.
class GinBillDetailsScreen extends StatefulWidget {
  final GinBill bill;
  final GinReviewMode mode;
  final GinRepository repo;
  final String? siteId;
  final ValueChanged<GinBill?>? onChanged;

  const GinBillDetailsScreen({
    super.key,
    required this.bill,
    required this.mode,
    required this.repo,
    this.siteId,
    this.onChanged,
  });

  @override
  State<GinBillDetailsScreen> createState() => _GinBillDetailsScreenState();
}

class _GinBillDetailsScreenState extends State<GinBillDetailsScreen> {
  late final List<TextEditingController> _rcvdCtrl;

  /// Per-line action picked on this screen (line id → action).
  final Map<String, GinLineAction> _pickedActions = {};

  /// Optional note attached to a picked action.
  final Map<String, String> _pickedNotes = {};

  final List<GinDocumentDraft> _newDocs = [];
  bool _busy = false;

  bool get _isSupervisor => widget.mode == GinReviewMode.supervisor;

  /// Editing is only allowed while the bill has not been HOD-approved.
  bool get _editable =>
      _isSupervisor && !widget.bill.addedToStock && !widget.bill.isApproved;

  bool get _hodCanReview =>
      widget.mode == GinReviewMode.hod && widget.bill.hodStatus == 'pending';

  @override
  void initState() {
    super.initState();
    _rcvdCtrl = List.generate(widget.bill.lines.length, (i) {
      final line = widget.bill.lines[i];
      final ctrl =
          TextEditingController(text: _qtyText(line.receivedQty));
      ctrl.addListener(() {
        if (!mounted) return;
        final val = double.tryParse(ctrl.text);
        if (val != null && val >= 0) {
          setState(() {
            line.receivedQty = val;
            // Editing received qty changes the diff → action must be re-picked.
            _pickedActions.remove(line.id);
            _pickedNotes.remove(line.id);
          });
        }
      });
      return ctrl;
    });
    for (final line in widget.bill.lines) {
      if (line.action != null) {
        _pickedActions[line.id] = line.action!;
        if (line.actionNote != null) _pickedNotes[line.id] = line.actionNote!;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _rcvdCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Derived counts ────────────────────────────────────────────────────────

  int get _shortageCount => widget.bill.shortageCount;
  int get _excessCount => widget.bill.excessCount;
  int get _matchedCount => widget.bill.matchedCount;
  bool get _allMatched => _shortageCount == 0 && _excessCount == 0;

  int get _reorderCount => _pickedActions.values
      .where((a) => a == GinLineAction.reorder)
      .length;
  int get _extraCount => _pickedActions.values
      .where((a) => a == GinLineAction.extra)
      .length;
  int get _doneCount => _pickedActions.values
      .where((a) => a == GinLineAction.done)
      .length;

  int get _pendingActionCount =>
      widget.bill.lines.where((l) => !_pickedActions.containsKey(l.id)).length;

  int get _docCount => widget.bill.documents.length + _newDocs.length;

  bool get _canSubmit =>
      _docCount > 0 && _pendingActionCount == 0 && !_busy;

  // ── Action helpers ────────────────────────────────────────────────────────

  void _setAction(int index, GinLineAction action, {String? note}) {
    final line = widget.bill.lines[index];
    setState(() {
      _pickedActions[line.id] = action;
      if (note != null && note.isNotEmpty) {
        _pickedNotes[line.id] = note;
      }
    });
  }

  void _clearAction(int index) {
    final line = widget.bill.lines[index];
    setState(() {
      _pickedActions.remove(line.id);
      _pickedNotes.remove(line.id);
    });
  }

  void _openActionSheet(int index) {
    final line = widget.bill.lines[index];
    if (line.status == GinReconciliationStatus.shortage) {
      _showShortageSheet(index, line);
    } else if (line.status == GinReconciliationStatus.excess) {
      _showExtraSheet(index, line);
    } else {
      _setAction(index, GinLineAction.done,
          note: 'Received exactly as billed');
      _snack('Marked OK for "${line.itemName}"', AppTheme.success,
          Icons.check_circle_outline);
    }
  }

  void _showShortageSheet(int index, GinBillLine line) {
    final diff = line.diffBilledReceived.abs();
    _showSheet(
      title: 'Shortage Action',
      titleColor: AppTheme.danger,
      titleIcon: Icons.arrow_downward_rounded,
      subtitle:
          '${line.itemName}  ·  short by ${_qtyText(diff)} ${line.uom}',
      options: [
        _SheetOption(
          action: GinLineAction.reorder,
          icon: Icons.replay_circle_filled,
          color: AppTheme.warning,
          label: 'Reorder',
          description: 'Place a new purchase order for the missing units.',
        ),
        _SheetOption(
          action: GinLineAction.done,
          icon: Icons.check_circle_outline_rounded,
          color: AppTheme.success,
          label: 'Accept Shortage',
          description: 'Accept with fewer units — update stock accordingly.',
        ),
        _SheetOption(
          action: GinLineAction.extra,
          icon: Icons.cancel_outlined,
          color: AppTheme.danger,
          label: 'Reject Delivery',
          description: 'Reject this item entirely. Return to supplier.',
        ),
      ],
      onPick: (a, note) {
        Navigator.pop(context);
        _setAction(index, a, note: note);
        _snack(
          _shortageActionLabel(a, line.itemName),
          _actionSnackColor(a),
          _actionSnackIcon(a),
        );
      },
    );
  }

  void _showExtraSheet(int index, GinBillLine line) {
    final diff = line.diffBilledReceived.abs();
    _showSheet(
      title: 'Excess Stock Action',
      titleColor: AppTheme.info,
      titleIcon: Icons.arrow_upward_rounded,
      subtitle:
          '${line.itemName}  ·  excess by ${_qtyText(diff)} ${line.uom}',
      options: [
        _SheetOption(
          action: GinLineAction.reorder,
          icon: Icons.local_shipping_outlined,
          color: AppTheme.warning,
          label: 'Return to Supplier',
          description: 'Send back the extra units to the supplier.',
        ),
        _SheetOption(
          action: GinLineAction.extra,
          icon: Icons.add_circle_outline_rounded,
          color: AppTheme.info,
          label: 'Accept Extra',
          description: 'Keep the extra stock and update inventory.',
        ),
        _SheetOption(
          action: GinLineAction.done,
          icon: Icons.tune_rounded,
          color: AppTheme.success,
          label: 'Adjust Inventory',
          description: 'Manually adjust the stock count to match received.',
        ),
      ],
      onPick: (a, note) {
        Navigator.pop(context);
        _setAction(index, a, note: note);
        _snack(
          _excessActionLabel(a, line.itemName),
          _actionSnackColor(a),
          _actionSnackIcon(a),
        );
      },
    );
  }

  void _showSheet({
    required String title,
    required Color titleColor,
    required IconData titleIcon,
    required String subtitle,
    required List<_SheetOption> options,
    required void Function(GinLineAction, String?) onPick,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GinActionSheet(
        title: title,
        titleColor: titleColor,
        titleIcon: titleIcon,
        subtitle: subtitle,
        options: options,
        onPick: onPick,
      ),
    );
  }

  String _shortageActionLabel(GinLineAction a, String name) {
    switch (a) {
      case GinLineAction.reorder:
        return 'Reorder raised for "$name"';
      case GinLineAction.done:
        return 'Shortage accepted for "$name"';
      case GinLineAction.extra:
        return 'Delivery rejected for "$name"';
    }
  }

  String _excessActionLabel(GinLineAction a, String name) {
    switch (a) {
      case GinLineAction.reorder:
        return 'Return to supplier raised for "$name"';
      case GinLineAction.extra:
        return 'Extra stock accepted for "$name"';
      case GinLineAction.done:
        return 'Inventory adjusted for "$name"';
    }
  }

  Color _actionSnackColor(GinLineAction a) {
    switch (a) {
      case GinLineAction.reorder:
        return AppTheme.warning;
      case GinLineAction.extra:
        return AppTheme.info;
      case GinLineAction.done:
        return AppTheme.success;
    }
  }

  IconData _actionSnackIcon(GinLineAction a) {
    switch (a) {
      case GinLineAction.reorder:
        return Icons.replay_circle_filled;
      case GinLineAction.extra:
        return Icons.add_circle_outline_rounded;
      case GinLineAction.done:
        return Icons.check_circle_outline;
    }
  }

  String _actionLabel(GinLineAction a) {
    switch (a) {
      case GinLineAction.reorder:
        return 'Reorder';
      case GinLineAction.extra:
        return 'Extra';
      case GinLineAction.done:
        return 'OK';
    }
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  Future<void> _addDocument(String type) async {
    try {
      final picked = await pickHodMapDeviceFile();
      if (picked == null || picked.bytes.isEmpty || !mounted) return;
      setState(() {
        _newDocs.add(GinDocumentDraft(
          name: picked.name,
          type: type,
          bytes: picked.bytes,
          extension: picked.extension,
        ));
      });
      _snack('${_typeLabel(type)} "${picked.name}" attached',
          AppTheme.success, Icons.upload_file);
    } catch (e) {
      if (!mounted) return;
      _snack('Could not pick file: $e', AppTheme.danger, Icons.error_outline);
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _UploadOptionsSheet(
        onSelected: (type) {
          Navigator.pop(ctx);
          _addDocument(type);
        },
      ),
    );
  }

  void _removeNewDoc(int index) {
    setState(() => _newDocs.removeAt(index));
  }

  // ── Submit (supervisor) ───────────────────────────────────────────────────

  void _onSubmit() {
    if (_pendingActionCount > 0) {
      _snack(
          '$_pendingActionCount item(s) still need an action (Shortage / Extra / OK)',
          AppTheme.warning,
          Icons.warning_amber_rounded);
      return;
    }
    if (_docCount == 0) {
      _snack('Upload at least one document before submitting.',
          AppTheme.danger, Icons.error_outline);
      return;
    }
    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GINConfirmDialog(
        matchedCount: _matchedCount,
        shortageCount: _shortageCount,
        excessCount: _excessCount,
        reorderCount: _reorderCount,
        extraCount: _extraCount,
        doneCount: _doneCount,
        docCount: _docCount,
        allMatched: _allMatched,
        isUpdate: !widget.bill.isDraft,
        onReview: () => Navigator.pop(ctx),
        onConfirm: () {
          Navigator.pop(ctx);
          _submit();
        },
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final lines = widget.bill.lines
        .map((line) => GinBillLine(
              id: line.id,
              itemName: line.itemName,
              orderedQty: line.orderedQty,
              billedQty: line.billedQty,
              receivedQty: line.receivedQty,
              uom: line.uom,
              action: _pickedActions[line.id],
              actionNote: _pickedNotes[line.id],
            ))
        .toList();

    final GinBill? result;
    if (widget.bill.isDraft) {
      result = await widget.repo.submitBill(
        billNumber: widget.bill.billNumber,
        supplierName: widget.bill.supplierName,
        supplierId: widget.bill.supplierId,
        thavvuPointId: widget.bill.thavvuPointId,
        thavvuPointName: widget.bill.thavvuPointName,
        siteId: widget.siteId ?? widget.bill.siteId,
        billDate: widget.bill.billDate,
        ginNo: widget.bill.ginNo,
        lines: lines,
        documents: _newDocs,
      );
    } else {
      result = await widget.repo.updateBill(
        billId: widget.bill.id,
        billNumber: widget.bill.billNumber,
        supplierName: widget.bill.supplierName,
        supplierId: widget.bill.supplierId,
        thavvuPointId: widget.bill.thavvuPointId,
        thavvuPointName: widget.bill.thavvuPointName,
        siteId: widget.siteId ?? widget.bill.siteId,
        billDate: widget.bill.billDate,
        lines: lines,
        documents: _newDocs,
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      _snack(
        widget.bill.isDraft
            ? 'GIN ${result.ginNo} submitted for HOD approval'
            : 'GIN ${result.ginNo} updated & re-submitted',
        AppTheme.success,
        Icons.check_circle_outline,
      );
      widget.onChanged?.call(result);
      Navigator.pop(context, result);
    } else {
      _snack('Submission failed. Check connection and try again.',
          AppTheme.danger, Icons.error_outline);
    }
  }

  // ── HOD review ────────────────────────────────────────────────────────────

  Future<void> _hodReview(String decision) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(
          decision == 'approved' ? 'Approve GIN' : 'Reject GIN',
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.bill.ginNo} · ${widget.bill.supplierName} · '
              '${widget.bill.lines.length} item(s)',
              style: const TextStyle(
                  fontSize: 13.5, color: AppTheme.textSecondary),
            ),
            if (decision == 'approved') ...[
              const SizedBox(height: 8),
              Text(
                'Approving adds the received quantities to '
                '${widget.bill.thavvuPointName} stock.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'HOD note (optional)',
                hintText: 'Tell the supervisor what to fix or confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  decision == 'rejected' ? AppTheme.danger : AppTheme.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              decision == 'approved' ? 'Approve' : 'Reject',
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    noteCtrl.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await widget.repo.reviewAsHod(
      billId: widget.bill.id,
      decision: decision,
      note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result == null) {
      _snack('Review failed. Check permissions and try again.',
          AppTheme.danger, Icons.error_outline);
      return;
    }
    if (decision == 'approved') {
      final added = result['added'];
      _snack(
        'GIN approved — ${added == null ? '' : '$added '}item(s) added to '
        '${widget.bill.thavvuPointName} stock.',
        AppTheme.success,
        Icons.check_circle_outline,
      );
    } else {
      _snack('GIN rejected — supervisor notified to fix.',
          AppTheme.warning, Icons.warning_amber_rounded);
    }
    final updated = await widget.repo.fetchBill(widget.bill.id);
    if (!mounted) return;
    widget.onChanged?.call(updated);
    Navigator.pop(context, updated);
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  void _snack(String message, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _qtyText(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  String _typeLabel(String type) {
    switch (type) {
      case 'invoice':
        return 'Invoice';
      case 'delivery_note':
        return 'Delivery Note';
      case 'photo':
        return 'Photo';
      default:
        return 'Document';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'invoice':
        return Icons.receipt_long;
      case 'delivery_note':
        return Icons.local_shipping_outlined;
      case 'photo':
        return Icons.camera_alt_outlined;
      default:
        return Icons.attach_file;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'invoice':
        return AppTheme.info;
      case 'delivery_note':
        return AppTheme.success;
      case 'photo':
        return AppTheme.warning;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel() {
    if (widget.bill.addedToStock) return 'Added to Stock';
    if (widget.bill.isApproved) return 'Approved';
    if (widget.bill.isRejected) return 'Rejected by HOD';
    return 'Pending HOD Approval';
  }

  Color _statusColor() {
    if (widget.bill.addedToStock) return AppTheme.success;
    if (widget.bill.isApproved) return AppTheme.success;
    if (widget.bill.isRejected) return AppTheme.danger;
    return AppTheme.warning;
  }

  IconData _statusIcon() {
    if (widget.bill.addedToStock) return Icons.verified_outlined;
    if (widget.bill.isApproved) return Icons.check_circle_outline;
    if (widget.bill.isRejected) return Icons.cancel_outlined;
    return Icons.pending_actions_outlined;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Bill #${widget.bill.billNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(), size: 14, color: _statusColor()),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSupplierBanner(),
                  if (widget.bill.hodNote != null &&
                      widget.bill.hodNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildHodNoteBanner(),
                  ],
                  const SizedBox(height: 20),
                  _buildReconciliationSection(),
                  const SizedBox(height: 20),
                  _buildDocumentSection(),
                  const SizedBox(height: 180),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSupplierBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.info.withValues(alpha: 0.08),
            AppTheme.infoBg,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.business_outlined,
                color: AppTheme.info, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.bill.supplierName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  _infoPill(Icons.receipt_long_outlined,
                      'GIN ${widget.bill.ginNo}', AppTheme.info),
                  _infoPill(Icons.location_on_outlined,
                      widget.bill.thavvuPointName, AppTheme.success),
                  _infoPill(Icons.inventory_2_outlined,
                      '${widget.bill.lines.length} items', AppTheme.warning),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHodNoteBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.comment_outlined, color: AppTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HOD Note',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.danger)),
                const SizedBox(height: 2),
                Text(widget.bill.hodNote!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Reconciliation table ─────────────────────────────────────────────────

  Widget _buildReconciliationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Item Reconciliation',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const Spacer(),
            if (_matchedCount > 0)
              _buildChip('$_matchedCount ✓', AppTheme.success),
            if (_shortageCount > 0) ...[
              const SizedBox(width: 6),
              _buildChip('$_shortageCount ⚠', AppTheme.warning),
            ],
            if (_excessCount > 0) ...[
              const SizedBox(width: 6),
              _buildChip('$_excessCount ↑', AppTheme.info),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _editable
              ? 'Tap the ACTIONS button on every line to confirm (Shortage / Extra / OK) · scroll table sideways →'
              : 'Received quantities are locked · ACTIONS chosen by the supervisor are shown below',
          style: const TextStyle(
              fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.cardShadow,
          ),
          clipBehavior: Clip.hardEdge,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTableHeader(),
                  ...List.generate(widget.bill.lines.length,
                      (i) => _buildTableRow(i)),
                  _buildTableSummaryRow(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildLegend(),
      ],
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildTableHeader() {
    const base = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: AppTheme.textSecondary);
    const rcvdStyle =
        TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24, child: Text('#', style: base)),
          const SizedBox(width: 8),
          const SizedBox(width: 116, child: Text('ITEM', style: base)),
          const SizedBox(width: 8),
          const SizedBox(
              width: 52,
              child: Text('ORD', textAlign: TextAlign.center, style: base)),
          const SizedBox(width: 8),
          const SizedBox(
              width: 52,
              child: Text('BILLED', textAlign: TextAlign.center, style: base)),
          const SizedBox(width: 8),
          SizedBox(
              width: 72,
              child: Text(_editable ? 'RCVD ✎' : 'RCVD',
                  textAlign: TextAlign.center, style: rcvdStyle)),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Column(children: const [
              Text('DIFF', textAlign: TextAlign.center, style: base),
              Text('Bld−Rcvd',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Column(children: const [
              Text('DIFF', textAlign: TextAlign.center, style: base),
              Text('Ord−Rcvd',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
            ]),
          ),
          const SizedBox(width: 8),
          const SizedBox(
              width: 62,
              child: Text('STATUS', textAlign: TextAlign.center, style: base)),
          const SizedBox(width: 8),
          const SizedBox(
              width: 118,
              child: Text('ACTIONS', textAlign: TextAlign.center, style: base)),
        ],
      ),
    );
  }

  Widget _buildTableRow(int index) {
    final line = widget.bill.lines[index];
    final status = line.status;
    final Color statusColor = status == GinReconciliationStatus.matched
        ? AppTheme.success
        : status == GinReconciliationStatus.shortage
            ? AppTheme.warning
            : AppTheme.info;
    final rowBg = index.isEven
        ? Colors.white
        : AppTheme.surface.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
            bottom:
                BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 116,
            child: Text(line.itemName,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_qtyText(line.orderedQty),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_qtyText(line.billedQty),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: _editable
                ? Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: TextField(
                      controller: _rcvdCtrl[index],
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                    ),
                  )
                : Text(_qtyText(line.receivedQty),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: _buildDiffBadge(
              diff: line.diffBilledReceived,
              positiveLabel: 'Short',
              negativeLabel: 'Excess',
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: _buildDiffBadge(
              diff: line.diffOrderedReceived,
              positiveLabel: 'Short',
              negativeLabel: 'Excess',
              positiveColor: AppTheme.danger,
              negativeColor: AppTheme.info,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: _buildStatusBadge(status, statusColor),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 118, child: _buildActionCell(index, line)),
        ],
      ),
    );
  }

  /// The functional ACTIONS cell — auto-shows Extra when received stock is
  /// extra, Shortage when received stock is low, OK when matched.
  Widget _buildActionCell(int index, GinBillLine line) {
    if (!_editable) {
      // HOD / read-only view: show the supervisor's picked ACTION.
      final picked = _pickedActions[line.id] ?? line.action;
      if (picked == null) {
        return const Center(
          child: Text('—',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        );
      }
      final color = _actionColor(picked);
      return _ActionChip(
        label: _actionLabel(picked),
        icon: _actionIcon(picked),
        color: color,
        note: _pickedNotes[line.id] ?? line.actionNote,
      );
    }

    final picked = _pickedActions[line.id];
    if (picked != null) {
      final color = _actionColor(picked);
      return Row(
        children: [
          Expanded(
            child: _ActionChip(
              label: _actionLabel(picked),
              icon: _actionIcon(picked),
              color: color,
              note: _pickedNotes[line.id],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _clearAction(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close,
                  size: 12, color: AppTheme.danger),
            ),
          ),
        ],
      );
    }

    // No action picked yet → auto-labelled functional button.
    switch (line.status) {
      case GinReconciliationStatus.shortage:
        return _ActionButton(
          label: 'Shortage −${_qtyText(line.diffBilledReceived.abs())}',
          icon: Icons.arrow_downward_rounded,
          color: AppTheme.danger,
          bg: AppTheme.dangerBg,
          onTap: () => _openActionSheet(index),
        );
      case GinReconciliationStatus.excess:
        return _ActionButton(
          label: 'Extra +${_qtyText(line.diffBilledReceived.abs())}',
          icon: Icons.arrow_upward_rounded,
          color: AppTheme.info,
          bg: AppTheme.infoBg,
          onTap: () => _openActionSheet(index),
        );
      case GinReconciliationStatus.matched:
        return _ActionButton(
          label: '✓ OK',
          icon: Icons.check,
          color: AppTheme.success,
          bg: AppTheme.successBg,
          onTap: () => _openActionSheet(index),
        );
    }
  }

  Color _actionColor(GinLineAction a) {
    switch (a) {
      case GinLineAction.reorder:
        return AppTheme.warning;
      case GinLineAction.extra:
        return AppTheme.info;
      case GinLineAction.done:
        return AppTheme.success;
    }
  }

  IconData _actionIcon(GinLineAction a) {
    switch (a) {
      case GinLineAction.reorder:
        return Icons.replay_circle_filled;
      case GinLineAction.extra:
        return Icons.add_circle_outline_rounded;
      case GinLineAction.done:
        return Icons.check_circle_outline;
    }
  }

  Widget _buildDiffBadge({
    required double diff,
    String positiveLabel = 'Short',
    String negativeLabel = 'Excess',
    Color positiveColor = AppTheme.warning,
    Color negativeColor = AppTheme.info,
  }) {
    if (diff == 0) {
      return const Center(
          child: Icon(Icons.check, size: 16, color: AppTheme.success));
    }
    final isPositive = diff > 0;
    final color = isPositive ? positiveColor : negativeColor;
    final sign = isPositive ? '−' : '+';
    final label = isPositive ? positiveLabel : negativeLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$sign${_qtyText(diff.abs())}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color),
                textAlign: TextAlign.center),
          ),
          Text(label,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.8)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
      GinReconciliationStatus status, Color color) {
    final String label = status == GinReconciliationStatus.matched
        ? '✓ OK'
        : status == GinReconciliationStatus.shortage
            ? '⚠ Short'
            : '↑ Excess';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildTableSummaryRow() {
    final totalOrdered = widget.bill.totalOrdered;
    final totalBilled = widget.bill.totalBilled;
    final totalReceived = widget.bill.totalReceived;
    const totalStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.06),
            AppTheme.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
            top: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.2), width: 1.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          const SizedBox(width: 8),
          const SizedBox(
            width: 116,
            child: Text('TOTAL',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary)),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 52,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_qtyText(totalOrdered),
                    textAlign: TextAlign.center, style: totalStyle),
              )),
          const SizedBox(width: 8),
          SizedBox(
              width: 52,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_qtyText(totalBilled),
                    textAlign: TextAlign.center, style: totalStyle),
              )),
          const SizedBox(width: 8),
          SizedBox(
              width: 72,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_qtyText(totalReceived),
                    textAlign: TextAlign.center,
                    style: totalStyle.copyWith(fontSize: 13)),
              )),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: _buildDiffBadge(
              diff: totalBilled - totalReceived,
              positiveLabel: 'Short',
              negativeLabel: 'Excess',
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: _buildDiffBadge(
              diff: totalOrdered - totalReceived,
              positiveLabel: 'Short',
              negativeLabel: 'Excess',
              positiveColor: AppTheme.danger,
              negativeColor: AppTheme.info,
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 62),
          const SizedBox(width: 8),
          const SizedBox(width: 118),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        _buildLegendItem('Matched', AppTheme.success),
        _buildLegendItem('Shortage', AppTheme.warning),
        _buildLegendItem('Excess', AppTheme.info),
        const SizedBox(width: 4),
        _buildLegendPill(
            'Bld−Rcvd', 'Billed qty minus Received qty', AppTheme.warning),
        _buildLegendPill('Ord−Rcvd', 'Ordered qty minus Received qty',
            AppTheme.danger),
        const Text(
          'ACTIONS = tap to resolve each line  ·  scroll table sideways',
          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLegendPill(String title, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(title,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  Widget _buildDocumentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Supporting Documents',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const Spacer(),
            if (_docCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_docCount attached',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Attach invoice and any delivery supporting documents',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 14),
        for (final doc in widget.bill.documents) _buildSavedDocTile(doc),
        for (var i = 0; i < _newDocs.length; i++)
          _buildNewDocTile(_newDocs[i], i),
        if (_editable) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showUploadOptions,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _newDocs.isEmpty
                    ? AppTheme.primary.withValues(alpha: 0.04)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _newDocs.isEmpty
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : AppTheme.border,
                  width: _newDocs.isEmpty ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.upload_file,
                        color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _docCount > 0
                              ? 'Add More Documents'
                              : 'Upload Invoice or Documents',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        const Text('Invoice · Delivery Note · Photo',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Browse',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_editable && _docCount == 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.dangerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.danger.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: AppTheme.danger),
                SizedBox(width: 6),
                Text(
                  'At least one document is required to submit.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSavedDocTile(GinBillDocument doc) {
    final color = _typeColor(doc.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(_typeIcon(doc.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_typeLabel(doc.type),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 2),
                Text(doc.name,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.verified_outlined,
              color: AppTheme.success, size: 16),
        ],
      ),
    );
  }

  Widget _buildNewDocTile(GinDocumentDraft doc, int index) {
    final color = _typeColor(doc.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(_typeIcon(doc.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_typeLabel(doc.type),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 2),
                Text('${doc.name} · ${doc.bytes.length ~/ 1024} KB',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.pending_outlined,
              color: AppTheme.warning, size: 16),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _removeNewDoc(index),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.close, size: 14, color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    if (_isSupervisor) return _buildSupervisorBar();
    return _buildHodBar();
  }

  Widget _buildSupervisorBar() {
    if (!_editable) {
      // Approved / added-to-stock bills are view-only for the supervisor.
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Icon(_statusIcon(), color: _statusColor(), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.bill.addedToStock
                    ? 'Goods added to ${widget.bill.thavvuPointName} stock.'
                    : 'Approved by HOD — goods are being added to stock.',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomStat('Items', '${widget.bill.lines.length}',
                  AppTheme.info),
              _buildBottomStat('Matched', '$_matchedCount', AppTheme.success),
              if (_shortageCount > 0)
                _buildBottomStat('Shortage', '$_shortageCount',
                    AppTheme.warning),
              if (_excessCount > 0)
                _buildBottomStat('Extra', '$_excessCount', AppTheme.info),
              _buildBottomStat('Docs', '$_docCount',
                  _docCount == 0 ? AppTheme.danger : AppTheme.success),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? _onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit
                    ? AppTheme.success
                    : AppTheme.textMuted,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: _canSubmit ? 2 : 0,
              ),
              child: _busy
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)),
                        ),
                        SizedBox(width: 12),
                        Text('Submitting GIN...',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fact_check_outlined, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          _pendingActionCount > 0
                              ? 'Tap ACTIONS to confirm '
                                  '($_pendingActionCount left)'
                              : _docCount == 0
                                  ? 'Upload Document to Submit'
                                  : widget.bill.isDraft
                                      ? 'Submit Goods Inward Note'
                                      : 'Update & Re-submit GIN',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHodBar() {
    if (!_hodCanReview) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Icon(_statusIcon(), color: _statusColor(), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.bill.isRejected
                    ? 'Rejected — note sent to supervisor.'
                    : 'Reviewed — goods already added to stock.',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomStat('Items', '${widget.bill.lines.length}',
                  AppTheme.info),
              _buildBottomStat('Shortage', '$_shortageCount',
                  AppTheme.warning),
              _buildBottomStat('Extra', '$_excessCount', AppTheme.info),
              _buildBottomStat('Matched', '$_matchedCount', AppTheme.success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _hodReview('rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Reject',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _hodReview('approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Approve & Add to Stock',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ─── Action sheet ────────────────────────────────────────────────────────────

class _SheetOption {
  final GinLineAction action;
  final IconData icon;
  final Color color;
  final String label;
  final String description;

  const _SheetOption({
    required this.action,
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
  });
}

class _GinActionSheet extends StatefulWidget {
  final String title;
  final Color titleColor;
  final IconData titleIcon;
  final String subtitle;
  final List<_SheetOption> options;
  final void Function(GinLineAction, String?) onPick;

  const _GinActionSheet({
    required this.title,
    required this.titleColor,
    required this.titleIcon,
    required this.subtitle,
    required this.options,
    required this.onPick,
  });

  @override
  State<_GinActionSheet> createState() => _GinActionSheetState();
}

class _GinActionSheetState extends State<_GinActionSheet> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
                    color: widget.titleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.titleIcon,
                      color: widget.titleColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: widget.titleColor)),
                      const SizedBox(height: 2),
                      Text(widget.subtitle,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final option in widget.options) ...[
              _buildOption(option),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Action note (optional)',
                hintText: 'Add a remark for HOD to review',
                prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(_SheetOption option) {
    return InkWell(
      onTap: () {
        final note = _noteCtrl.text.trim();
        widget.onPick(option.action, note.isEmpty ? null : note);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: option.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: option.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(option.icon, color: option.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: option.color)),
                  const SizedBox(height: 2),
                  Text(option.description,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: option.color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Small widgets ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? note;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: note ?? label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadOptionsSheet extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _UploadOptionsSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              const Text('Select Document Type',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Choose the type of document you are attaching.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          _buildOption('Invoice', 'Official invoice from the supplier',
              Icons.receipt_long, AppTheme.info, () => onSelected('invoice')),
          const SizedBox(height: 12),
          _buildOption('Delivery Note', 'Goods delivery / dispatch note',
              Icons.local_shipping_outlined, AppTheme.success,
              () => onSelected('delivery_note')),
          const SizedBox(height: 12),
          _buildOption('Photo', 'Photo of received goods or packaging',
              Icons.camera_alt_outlined, AppTheme.warning,
              () => onSelected('photo')),
        ],
      ),
    );
  }

  Widget _buildOption(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _GINConfirmDialog extends StatelessWidget {
  final int matchedCount, shortageCount, excessCount;
  final int reorderCount, extraCount, doneCount, docCount;
  final bool allMatched;
  final bool isUpdate;
  final VoidCallback onReview;
  final VoidCallback onConfirm;

  const _GINConfirmDialog({
    required this.matchedCount,
    required this.shortageCount,
    required this.excessCount,
    required this.reorderCount,
    required this.extraCount,
    required this.doneCount,
    required this.docCount,
    required this.allMatched,
    required this.isUpdate,
    required this.onReview,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.fact_check_outlined,
                      color: AppTheme.success, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUpdate ? 'Confirm GIN Update' : 'Confirm GIN Submission',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reconciliation Summary',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  _summaryRow(Icons.check_circle,
                      '$matchedCount items matched', AppTheme.success),
                  if (shortageCount > 0) ...[
                    const SizedBox(height: 6),
                    _summaryRow(Icons.warning_amber,
                        '$shortageCount items with shortage', AppTheme.warning),
                  ],
                  if (excessCount > 0) ...[
                    const SizedBox(height: 6),
                    _summaryRow(Icons.arrow_upward,
                        '$excessCount items with extra stock', AppTheme.info),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _summaryRow(Icons.replay_circle_filled,
                      '$reorderCount reorder · $extraCount accept extra · '
                      '$doneCount ok',
                      AppTheme.textSecondary),
                  const SizedBox(height: 6),
                  _summaryRow(Icons.upload_file,
                      '$docCount document${docCount == 1 ? '' : 's'} attached',
                      AppTheme.info),
                ],
              ),
            ),
            if (!allMatched) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.warning, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Discrepancies detected. HOD will be notified for review.',
                        style:
                            TextStyle(fontSize: 11, color: AppTheme.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReview,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Review Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(isUpdate ? 'Update GIN' : 'Submit GIN',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// Re-export so callers can build bytes-based docs if needed.
typedef GinDocBytes = Uint8List;
