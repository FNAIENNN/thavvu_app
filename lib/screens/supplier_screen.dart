import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_capture_card.dart';

/// Supplier directory + payment requests for the active site.
///
/// Supervisors can browse suppliers and raise a payment request (amount,
/// method, optional bill photo). HODs additionally see approve/reject
/// controls on each pending request. Fully remote-backed — there is no
/// local/offline supplier data, so this screen shows a friendly notice when
/// `remoteEnabled` is false.
class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Suppliers & Payments'),
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
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Suppliers', icon: Icon(Icons.storefront_outlined)),
            Tab(text: 'Payment Requests', icon: Icon(Icons.receipt_long_outlined)),
          ],
        ),
      ),
      body: !store.remoteEnabled
          ? const _OfflineNotice()
          : TabBarView(
              controller: _tabController,
              children: const [
                _SuppliersListTab(),
                _PaymentRequestsTab(),
              ],
            ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Supplier module needs live backend',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Suppliers and payment requests are stored directly in Supabase. Connect to the network and sign in again to use this module.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Suppliers List Tab ───────────────────────────────────────────────────────
class _SuppliersListTab extends StatefulWidget {
  const _SuppliersListTab();

  @override
  State<_SuppliersListTab> createState() => _SuppliersListTabState();
}

class _SuppliersListTabState extends State<_SuppliersListTab> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final suppliers = store.suppliers;

    return RefreshIndicator(
      onRefresh: store.hydrateFromRemote,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suppliers (${suppliers.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openRequestForm(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Request Payment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (suppliers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No suppliers found for this site yet',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ...suppliers.map((s) => _SupplierTile(supplier: s)),
          ],
        ),
      ),
    );
  }

  void _openRequestForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _RequestPaymentSheet(),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  const _SupplierTile({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.info),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(supplier.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (supplier.category.isNotEmpty) supplier.category,
                    if (supplier.phone.isNotEmpty) supplier.phone,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (supplier.phone.isNotEmpty)
            Icon(Icons.call_outlined, size: 18, color: AppTheme.textMuted.withOpacity(0.7)),
        ],
      ),
    );
  }
}

// ─── Request Payment Sheet ────────────────────────────────────────────────────
class _RequestPaymentSheet extends StatefulWidget {
  const _RequestPaymentSheet();

  @override
  State<_RequestPaymentSheet> createState() => _RequestPaymentSheetState();
}

class _RequestPaymentSheetState extends State<_RequestPaymentSheet> {
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _billAmountController = TextEditingController();
  String _method = 'upi';
  String? _photoPath;
  bool _capturingPhoto = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _supplierController.dispose();
    _amountController.dispose();
    _billAmountController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    setState(() => _capturingPhoto = true);
    final store = context.read<AppStore>();
    final path = await store.capturePhoto(module: 'supplier', label: 'bill_photo');
    if (!mounted) return;
    setState(() {
      _capturingPhoto = false;
      if (path != null) _photoPath = path;
    });
  }

  Future<void> _submit() async {
    if (_supplierController.text.trim().isEmpty) {
      _showSnackbar('Please enter supplier name', AppTheme.danger);
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackbar('Please enter a valid amount', AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    final row = await context.read<AppStore>().requestSupplierPayment(
          supplierName: _supplierController.text.trim(),
          amount: amount,
          method: _method,
          billAmount: double.tryParse(_billAmountController.text),
          photoPath: _photoPath,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (row == null) {
      _showSnackbar('Could not submit request. Check connection and try again.', AppTheme.danger);
      return;
    }
    Navigator.pop(context);
    _showSnackbar('Payment request submitted for HOD approval', AppTheme.success);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Request Supplier Payment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            const Text('Submitted for HOD review before payout', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            TextField(
              controller: _supplierController,
              decoration: InputDecoration(
                labelText: 'Supplier Name',
                prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount to Pay (₹)',
                prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _billAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bill Amount (optional)',
                hintText: 'Original invoice amount, if different',
                prefixIcon: const Icon(Icons.receipt_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _methodChip('cash', 'Cash', Icons.payments_outlined),
                _methodChip('upi', 'UPI', Icons.qr_code_2_outlined),
                _methodChip('bank', 'Bank Transfer', Icons.account_balance_outlined),
              ],
            ),
            const SizedBox(height: 16),
            PhotoCaptureCard(
              label: 'Bill photo (optional)',
              hint: 'Tap to capture',
              imagePath: _photoPath,
              onTap: _capturingPhoto ? null : _capturePhoto,
              onClear: _photoPath == null ? null : () => setState(() => _photoPath = null),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodChip(String value, String label, IconData icon) {
    final isSelected = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── Payment Requests Tab ─────────────────────────────────────────────────────
class _PaymentRequestsTab extends StatelessWidget {
  const _PaymentRequestsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final payments = store.supplierPayments;
    final isHod = store.isHod;

    return RefreshIndicator(
      onRefresh: store.hydrateFromRemote,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Requests (${payments.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No supplier payment requests yet',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ...payments.map((p) => _PaymentTile(payment: p, showActions: isHod && p.status == 'pending')),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatefulWidget {
  final SupplierPayment payment;
  final bool showActions;
  const _PaymentTile({required this.payment, required this.showActions});

  @override
  State<_PaymentTile> createState() => _PaymentTileState();
}

class _PaymentTileState extends State<_PaymentTile> {
  bool _busy = false;

  Color get _statusColor => switch (widget.payment.status) {
        'approved' => AppTheme.success,
        'rejected' => AppTheme.danger,
        _ => AppTheme.warning,
      };

  Future<void> _review(String status) async {
    setState(() => _busy = true);
    await context.read<AppStore>().reviewSupplierPayment(widget.payment.id, status);
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  p.mode == 'upi'
                      ? Icons.qr_code_2_outlined
                      : p.mode == 'bank'
                          ? Icons.account_balance_outlined
                          : Icons.payments_outlined,
                  size: 18,
                  color: _statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.supplierName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text('₹${p.amount.toStringAsFixed(0)} · ${p.mode.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.status[0].toUpperCase() + p.status.substring(1),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor),
                ),
              ),
            ],
          ),
          if (widget.showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _review('rejected'),
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.danger),
                    label: const Text('Reject', style: TextStyle(color: AppTheme.danger)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _review('approved'),
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
