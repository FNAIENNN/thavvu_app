import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/hod_machine/data/repositories/supabase_hod_machine_repository.dart';
import '../../../features/hod_machine/domain/models/machine_asset.dart';
import '../../../features/hod_machine/domain/models/machine_payment_request.dart';
import '../../../features/hod_machine/domain/models/machine_supplier.dart';
import '../../../features/hod_machine/domain/services/hod_machine_repository_interface.dart';
import '../../../features/hod_machine/presentation/widgets/machine_context_card.dart';
import '../../../features/hod_machine/presentation/widgets/machine_status_chip.dart';
import '../../../services/hod_site_workspace_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';

/// HOD Machine Entry screen — Supabase refactor.
///
/// Replaces inline seed data with live reads/writes through
/// [HodMachineRepository] and the new domain models.
/// Uses [MachineAsset], [MachineSupplier], [MachinePaymentRequest],
/// and the reusable [MachineStatusChip]/[MachineContextCard] widgets.
class HodMachinesEntryScreen extends StatefulWidget {
  final String siteId;
  final String hodId;
  final String? thavvuPointId;
  final String? supervisorId;
  final bool readOnly;
  final String? siteName;

  /// Injectable repository (tests pass a fake; production uses Supabase).
  final HodMachineRepository? repository;

  const HodMachinesEntryScreen({
    super.key,
    this.siteId = 'SITE-VJA-001',
    this.hodId = 'HOD-001',
    this.thavvuPointId,
    this.supervisorId,
    this.readOnly = false,
    this.siteName,
    this.repository,
  });

  @override
  State<HodMachinesEntryScreen> createState() => _HodMachinesEntryScreenState();
}

class _HodMachinesEntryScreenState extends State<HodMachinesEntryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late final HodMachineRepository _repository =
      widget.repository ?? SupabaseHodMachineRepository(null);

  // ── Data lists from repository ──────────────────────────────
  List<MachineSupplier> _suppliers = [];
  List<MachineAsset> _machines = [];
  List<MachinePaymentRequest> _paymentRequests = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ── Active workspace context (site / point) ────────────────
  // The HOD shell quick-routes may construct this screen with the demo
  // defaults; when that happens we resolve the HOD's real first site and
  // Thavvu Point from Supabase so dropdowns and writes are site-scoped.
  late String _siteId = widget.siteId;
  late String? _siteName = widget.siteName;
  late String? _thavvuPointId = widget.thavvuPointId;

  // ── Entry form state ────────────────────────────────────────
  MachineAsset? _selectedMachine;
  MachineSupplier? _selectedSupplier;

  static const List<String> _vehicleTypes = [
    'Poclain', 'Tractor', 'Dozer', 'Excavator', 'Loader',
    'Crane', 'Backhoe', 'Grader', 'Roller', 'Dumper',
    'Forklift', 'Bulldozer',
  ];
  static const List<String> _billingTypes = ['TRIP', 'HOUR', 'DAY', 'KM'];
  static const List<String> _dieselInclusions = [
    'With diesel', 'Without diesel', 'Fuel issued from stock point',
  ];
  static const List<String> _fuelTypes = ['Diesel', 'Petrol', 'CNG', 'Electric'];
  static const List<String> _stockPoints = [
    'Main Depot', 'Site A', 'Site B', 'Warehouse 1', 'Fuel Station 3',
  ];

  String? _selectedVehicleType;
  String? _selectedBillingType;
  String? _selectedDieselInclusion;
  String? _selectedFuelType;
  String? _selectedStockPoint;
  bool _extraBetaApprovalEnabled = false;
  bool _isSubmitting = false;

  final _vehicleNumberCtl = TextEditingController();
  final _operatorNameCtl = TextEditingController();
  final _operatorPhoneCtl = TextEditingController();
  final _fareAmountCtl = TextEditingController();
  final _fuelLitersCtl = TextEditingController();
  final _commissionAgentCtl = TextEditingController();
  final _commissionAmountCtl = TextEditingController();
  final _betaEligibleHoursCtl = TextEditingController(text: '8');
  final _regularBetaAmountCtl = TextEditingController(text: '0');
  final _extraBetaLimitCtl = TextEditingController(text: '0');
  final _notesCtl = TextEditingController();

  // ── Payment transaction state (local, not yet persisted) ─────
  bool _enableCashPayment = false;
  bool _enableAdvancePayment = false;
  final _cashAmountCtl = TextEditingController();
  final _advanceAmountCtl = TextEditingController();
  final _ifscCtl = TextEditingController();
  final _accNumCtl = TextEditingController();
  final _bankNameCtl = TextEditingController();
  String? _selectedAdvanceMode;
  String? _selectedEntryMethod;
  String? _selectedPaymentAccount;
  String? _selectedBankAccount;
  double _cashBalance = 75000;
  double _cashLimit = 50000;

  // Local unsaved payment rows (will be persisted on final submit)
  final List<_DraftPayment> _cashDrafts = [];
  final List<_DraftPayment> _advanceDrafts = [];
  String? _openingPhotoPath;

  static const List<Map<String, String>> _savedUpiAccounts = [
    {'id': 'UPI-001', 'upiId': 'abc-machinery@upi', 'bankName': 'HDFC Bank', 'type': 'primary'},
    {'id': 'UPI-002', 'upiId': 'globalmachinery@sbi', 'bankName': 'SBI', 'type': 'secondary'},
  ];
  static const List<Map<String, String>> _savedBankAccounts = [
    {'id': 'BANK-001', 'bankName': 'HDFC Bank', 'accountNumber': '****4567', 'ifsc': 'HDFC0001234', 'holderName': 'ABC Suppliers', 'type': 'primary'},
    {'id': 'BANK-002', 'bankName': 'SBI', 'accountNumber': '****2233', 'ifsc': 'SBIN0002211', 'holderName': 'Global Machinery', 'type': 'secondary'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedFuelType = _fuelTypes.first;
    _selectedStockPoint = _stockPoints.first;
    _loadData();
    unawaited(_maybeResolveContext());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vehicleNumberCtl.dispose();
    _operatorNameCtl.dispose();
    _operatorPhoneCtl.dispose();
    _fareAmountCtl.dispose();
    _fuelLitersCtl.dispose();
    _commissionAgentCtl.dispose();
    _commissionAmountCtl.dispose();
    _betaEligibleHoursCtl.dispose();
    _regularBetaAmountCtl.dispose();
    _extraBetaLimitCtl.dispose();
    _notesCtl.dispose();
    _cashAmountCtl.dispose();
    _advanceAmountCtl.dispose();
    _ifscCtl.dispose();
    _accNumCtl.dispose();
    _bankNameCtl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        _repository.getSuppliers(siteId: _siteId),
        _repository.getMachines(siteId: _siteId),
        _repository.getPaymentRequests(siteId: _siteId),
      ]);
      if (!mounted) return;
      setState(() {
        _suppliers = results[0] as List<MachineSupplier>;
        _machines = results[1] as List<MachineAsset>;
        _paymentRequests = results[2] as List<MachinePaymentRequest>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  /// Resolves the HOD's real workspace when this screen was constructed with
  /// the demo defaults (shell quick-route) instead of an explicit site/point
  /// (site-modules flow). Non-blocking: on any failure the demo defaults stay
  /// and the screen still renders.
  Future<void> _maybeResolveContext() async {
    final hasExplicitContext =
        widget.siteId != 'SITE-VJA-001' ||
        widget.siteName != null ||
        widget.thavvuPointId != null;
    if (hasExplicitContext) return;
    try {
      final sites = await HodSiteWorkspaceService().adminCreatedSites();
      if (sites.isEmpty) return;
      final site = sites.first;
      final points =
          await HodSiteWorkspaceService().thavvuPointsForSite(site.id);
      if (!mounted) return;
      setState(() {
        _siteId = site.id;
        _siteName = site.name;
        _thavvuPointId = points.isNotEmpty ? points.first.id : null;
      });
      await _loadData();
    } catch (_) {
      // Keep defaults — the screen works against them when offline.
    }
  }

  // ── Helpers ─────────────────────────────────────────────────
  String get _hodIdOrUid => widget.hodId;
  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _money(num v) => '₹${v.toStringAsFixed(0)}';
  double _amt(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  double get _entryPayable =>
      _amt(_fareAmountCtl) + _amt(_commissionAmountCtl) + _amt(_regularBetaAmountCtl);
  double get _draftTotal =>
      _cashDrafts.fold<double>(0, (s, d) => s + d.amount) +
      _advanceDrafts.fold<double>(0, (s, d) => s + d.amount);
  bool get _hasPendingAdvApproval =>
      _advanceDrafts.any((d) => d.status == PaymentStatus.draft);

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: c,
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  static String _statusLabel(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.draft: return 'Pending HOD Approval';
      case PaymentStatus.hodApproved: return 'HOD Approved';
      case PaymentStatus.hodRejected: return 'HOD Rejected';
      case PaymentStatus.submittedToFinance: return 'Submitted to Finance';
      case PaymentStatus.financeProcessing: return 'Finance Processing';
      case PaymentStatus.paid: return 'Paid';
      case PaymentStatus.closed: return 'Closed';
    }
  }

  Color _statusColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.draft: return AppTheme.warning;
      case PaymentStatus.hodApproved: return AppTheme.info;
      case PaymentStatus.hodRejected: return AppTheme.danger;
      case PaymentStatus.submittedToFinance: return AppTheme.primary;
      case PaymentStatus.financeProcessing: return AppTheme.info;
      case PaymentStatus.paid: return AppTheme.success;
      case PaymentStatus.closed: return AppTheme.textMuted;
    }
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? _buildError()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildEntryTab(),
                  _buildRecordsTab(),
                  _buildFinanceQueueTab(),
                ],
              );

    return CollapsibleTabScaffold(
      title: 'HOD Machine Entry',
      leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context)),
      controller: _tabController,
      tabs: const [
        Tab(text: 'Entry'),
        Tab(text: 'Records'),
        Tab(text: 'Finance'),
      ],
      body: body,
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          const Text('Failed to load data',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(_errorMessage!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════
  // TAB 1 — MACHINE ENTRY FORM
  // ═══════════════════════════════════════════════════════════
  Widget _buildEntryTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildPageHeader(),
          const SizedBox(height: 14),
          _buildSummaryStrip(),
          const SizedBox(height: 14),
          _buildStep('1', 'Site, Machine & Supplier', AppTheme.warning, _buildMachineSupplierSection()),
          const SizedBox(height: 12),
          _buildStep('2', 'Entry Details', AppTheme.info, _buildEntryDetailsSection()),
          const SizedBox(height: 12),
          _buildStep('3', 'Beta, Commission & Notes', AppTheme.primary, _buildBetaCommissionSection()),
          const SizedBox(height: 12),
          _buildStep('4', 'Payment Approval', AppTheme.success, _buildPaymentSection()),
          const SizedBox(height: 12),
          _buildStep('5', 'Opening Photo & Final Submit', AppTheme.danger, _buildPhotoAndSubmit()),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFF1565C0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.2))),
          alignment: Alignment.center,
          child: const Text('🚜', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Production HOD Machine Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          SizedBox(height: 5),
          Text('Create machine entry, approve payments, and submit advance requests to Finance.',
              style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFFE0F2FE))),
        ])),
      ]),
    );
  }

  Widget _buildSummaryStrip() {
    return Row(children: [
      _smStat('Machines', '${_machines.length}', AppTheme.warning, Icons.construction),
      const SizedBox(width: 10),
      _smStat('Payments', '${_paymentRequests.length}', AppTheme.info, Icons.receipt_long),
      const SizedBox(width: 10),
      _smStat('Finance', '${_paymentRequests.where((p) => p.isAdvance && p.status != PaymentStatus.draft).length}',
          AppTheme.success, Icons.account_balance),
    ]);
  }

  Widget _smStat(String title, String value, Color color, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)), boxShadow: AppTheme.subtleShadow),
      child: Row(children: [
        Container(width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          Text(title, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
        ])),
      ]),
    ));
  }

  Widget _buildStep(String step, String title, Color color, Widget child) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border), boxShadow: AppTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(step, style: TextStyle(color: color, fontWeight: FontWeight.w900))),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 14), child,
      ]),
    );
  }

  // ── Step 1: Machine & Supplier ──────────────────────────
  Widget _buildMachineSupplierSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MachineContextCard(
        siteName: _siteName ?? _siteId,
        siteId: _siteId, hodId: widget.hodId,
        thavvuPointName: _thavvuPointId,
        supervisorName: widget.supervisorId,
      ),
      const SizedBox(height: 12),
      _buildMachineDropdown(),
      if (_selectedMachine != null) ...[
        const SizedBox(height: 10),
        _buildPreview(Icons.precision_manufacturing_outlined, AppTheme.warning,
            '${_selectedMachine!.machineName} • ${_selectedMachine!.vehicleNumber}',
            '${_selectedMachine!.vehicleType} • Operator: ${_selectedMachine!.operatorName}'),
      ],
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(child: Text('Supplier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
        TextButton.icon(
          onPressed: _showAddSupplierSheet,
          icon: const Icon(Icons.add_business_rounded, size: 16),
          label: const Text('Add Supplier')),
      ]),
      const SizedBox(height: 8),
      _buildSupplierDropdown(),
      if (_selectedSupplier != null) ...[
        const SizedBox(height: 10),
        _buildPreview(Icons.store_outlined,
            _selectedSupplier!.type == 'temporary' ? AppTheme.warning : AppTheme.success,
            _selectedSupplier!.name,
            '${_selectedSupplier!.type} • Rating ${_selectedSupplier!.rating.toStringAsFixed(1)}'),
      ],
    ]);
  }

  Widget _buildMachineDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedMachine?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Select / Enter Machine',
        prefixIcon: Icon(Icons.precision_manufacturing_outlined),
      ),
      items: [
        ..._machines.map((m) => DropdownMenuItem<String>(
          value: m.id,
          child: Text('${m.machineName} • ${m.vehicleNumber}', overflow: TextOverflow.ellipsis),
        )),
        const DropdownMenuItem<String>(
          value: '__add__',
          child: Row(children: [
            Icon(Icons.add_circle_outline, color: AppTheme.success),
            SizedBox(width: 8),
            Expanded(child: Text('Enter / Add New Machine',
                style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800))),
          ]),
        ),
      ],
      onChanged: (v) {
        if (v == null) return;
        if (v == '__add__') { _showAddMachineSheet(); return; }
        setState(() { _selectedMachine = _machines.firstWhere((m) => m.id == v); });
      },
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSupplier?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Select supplier',
        prefixIcon: Icon(Icons.store_mall_directory_outlined),
      ),
      items: [
        ..._suppliers.map((s) => DropdownMenuItem<String>(
          value: s.id,
          child: Row(children: [
            Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
            if (s.type == 'temporary')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                child: const Text('TEMP', style: TextStyle(fontSize: 9, color: AppTheme.warning, fontWeight: FontWeight.w900)),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.star, color: AppTheme.warning, size: 14),
            Text(s.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
          ]),
        )),
        const DropdownMenuItem<String>(
          value: '__add_sup__',
          child: Row(children: [
            Icon(Icons.add_business_rounded, color: AppTheme.success),
            SizedBox(width: 8),
            Expanded(child: Text('Create New Supplier',
                style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800))),
          ]),
        ),
      ],
      onChanged: (v) {
        if (v == null) return;
        if (v == '__add_sup__') { _showAddSupplierSheet(); return; }
        final picked = _suppliers.firstWhere((s) => s.id == v);
        // Attach the current site context to the selected supplier so the
        // entry is recorded against THIS site (cross-site catalog support).
        setState(() => _selectedSupplier = picked.copyWith(siteId: _siteId));
      },
    );
  }

  // ── Step 2: Entry Details ───────────────────────────────
  Widget _buildEntryDetailsSection() {
    return Column(children: [
      DropdownButtonFormField<String>(
        value: _selectedVehicleType ?? _selectedMachine?.vehicleType,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Vehicle Type', prefixIcon: Icon(Icons.agriculture_outlined)),
        items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _selectedVehicleType = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: _vehicleNumberCtl, textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Vehicle Number', prefixIcon: Icon(Icons.confirmation_number_outlined))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _operatorNameCtl, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Operator Name', prefixIcon: Icon(Icons.person_outline)))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: _operatorPhoneCtl, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Operator Phone', prefixIcon: Icon(Icons.phone_outlined)))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _selectedBillingType,
          decoration: const InputDecoration(labelText: 'Billing Type', prefixIcon: Icon(Icons.timer_outlined)),
          items: _billingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _selectedBillingType = v),
        )),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: _fareAmountCtl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Fare Amount ₹', prefixIcon: Icon(Icons.currency_rupee_outlined)),
            onChanged: (_) => setState(() {}))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _selectedDieselInclusion,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Diesel Inclusion', prefixIcon: Icon(Icons.local_gas_station_outlined)),
        items: _dieselInclusions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _selectedDieselInclusion = v),
      ),
      if (_selectedDieselInclusion != null) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _selectedFuelType,
            decoration: const InputDecoration(labelText: 'Fuel Type', prefixIcon: Icon(Icons.local_gas_station)),
            items: _fuelTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _selectedFuelType = v),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _fuelLitersCtl, keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fuel Liters', prefixIcon: Icon(Icons.straighten)))),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedStockPoint,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Stock Point', prefixIcon: Icon(Icons.location_on_outlined)),
          items: _stockPoints.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _selectedStockPoint = v),
        ),
      ],
    ]);
  }

  // ── Step 3: Beta / Commission ───────────────────────────
  Widget _buildBetaCommissionSection() {
    return Column(children: [
      Row(children: [
        Expanded(child: TextField(controller: _commissionAgentCtl, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Commission Agent', prefixIcon: Icon(Icons.groups_outlined)))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: _commissionAmountCtl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Commission ₹', prefixIcon: Icon(Icons.currency_rupee)),
            onChanged: (_) => setState(() {}))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _betaEligibleHoursCtl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Beta Eligible Hours', prefixIcon: Icon(Icons.schedule_outlined)))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: _regularBetaAmountCtl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Regular Beta ₹', prefixIcon: Icon(Icons.currency_rupee)),
            onChanged: (_) => setState(() {}))),
      ]),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero, value: _extraBetaApprovalEnabled,
        activeColor: AppTheme.primary,
        title: const Text('Enable Extra Beta Approval', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Used when beta exceeds normal eligible limit'),
        onChanged: (v) => setState(() => _extraBetaApprovalEnabled = v),
      ),
      if (_extraBetaApprovalEnabled) ...[
        const SizedBox(height: 8),
        TextField(controller: _extraBetaLimitCtl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Extra Beta Approval Limit ₹', prefixIcon: Icon(Icons.rule_folder_outlined))),
      ],
      const SizedBox(height: 12),
      TextField(controller: _notesCtl, minLines: 3, maxLines: 5,
          decoration: const InputDecoration(labelText: 'Additional Notes', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_outlined))),
    ]);
  }

  // ── Step 4: Payment Approval ────────────────────────────
  Widget _buildPaymentSection() {
    return Column(children: [
      _buildPaymentSummary(),
      const SizedBox(height: 12),
      _buildCashToggle(),
      const SizedBox(height: 12),
      _buildCashTable(),
      const SizedBox(height: 16),
      _buildAdvanceToggle(),
      const SizedBox(height: 12),
      _buildAdvanceTable(),
    ]);
  }

  Widget _buildPaymentSummary() {
    final remaining = (_entryPayable - _draftTotal).clamp(0, double.infinity).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Expanded(child: _miniMetric('Payable', _money(_entryPayable))),
        const SizedBox(width: 8),
        Expanded(child: _miniMetric('Added', _money(_draftTotal))),
        const SizedBox(width: 8),
        Expanded(child: _miniMetric('Balance', _money(remaining))),
      ]),
    );
  }

  Widget _buildCashToggle() {
    return Row(children: [
      Expanded(child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Cash Payment', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('HOD approved cash payment. Limit applies.'),
        value: _enableCashPayment, activeColor: AppTheme.info,
        onChanged: (v) => setState(() => _enableCashPayment = v),
      )),
      _countPill('${_cashDrafts.length}',
          AppTheme.info, Icons.receipt_long, _showCashHistory),
    ]);
  }

  Widget _buildAdvanceToggle() {
    return Row(children: [
      Expanded(child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Advance Request', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('HOD approval is required before Finance submission.'),
        value: _enableAdvancePayment, activeColor: AppTheme.success,
        onChanged: (v) => setState(() => _enableAdvancePayment = v),
      )),
      _countPill('${_advanceDrafts.length}',
          AppTheme.success, Icons.request_quote_outlined, _showAdvanceHistory),
    ]);
  }

  Widget _buildCashTable() {
    if (!_enableCashPayment) return const SizedBox.shrink();
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppTheme.infoBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet, size: 16, color: AppTheme.info),
          const SizedBox(width: 6),
          Text('Available Balance: ${_money(_cashBalance)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
      TextField(controller: _cashAmountCtl, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Cash Amount (₹)', hintText: 'Max ${_money(_cashLimit)}', prefixIcon: const Icon(Icons.currency_rupee, size: 18)),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 8),
      _buildCashValidation(),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _amt(_cashAmountCtl) > 0 ? _proceedCash : null,
        icon: const Icon(Icons.verified_outlined, size: 18),
        label: const Text('Approve Cash Payment'),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
      const SizedBox(height: 12),
      if (_cashDrafts.isNotEmpty) _draftTable(_cashDrafts, AppTheme.info, Icons.payments_outlined, 'Cash Payment Table', 'Cash rows are HOD-approved immediately.'),
    ]);
  }

  Widget _buildCashValidation() {
    final text = _cashAmountCtl.text.trim();
    final amount = double.tryParse(text) ?? 0;
    if (text.isEmpty) {
      return _validation('Balance after payment: ${_money(_cashBalance)}', AppTheme.info, Icons.info_outline);
    }
    if (amount > _cashLimit) {
      return _validation('Exceeds HOD limit of ${_money(_cashLimit)}. Use advance request.', AppTheme.danger, Icons.error_outline);
    }
    if (amount > _cashBalance) {
      return _validation('Insufficient cash balance. Available: ${_money(_cashBalance)}.', AppTheme.danger, Icons.warning_amber);
    }
    return _validation('Valid. Balance after payment: ${_money(_cashBalance - amount)}.', AppTheme.success, Icons.check_circle_outline);
  }

  Widget _validation(String msg, Color c, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.22))),
      child: Row(children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _buildAdvanceSection() {
    if (!_enableAdvancePayment) return const SizedBox.shrink();
    final amount = _amt(_advanceAmountCtl);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _advanceAmountCtl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Advance Amount (₹)', prefixIcon: Icon(Icons.request_quote, size: 18)),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _payMode('upi', 'UPI', Icons.qr_code, AppTheme.success)),
        const SizedBox(width: 12),
        Expanded(child: _payMode('bank', 'Bank Transfer', Icons.account_balance, AppTheme.info)),
      ]),
      const SizedBox(height: 14),
      if (_selectedAdvanceMode == 'upi') _upiSelection(),
      if (_selectedAdvanceMode == 'bank') _bankEntry(),
      if (amount > 0) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.warning.withOpacity(0.24))),
          child: const Row(children: [
            Icon(Icons.verified_user_outlined, color: AppTheme.warning, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('This creates a Pending HOD Approval row. HOD must approve it before it goes to Finance.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.warning, fontWeight: FontWeight.w700))),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _createAdvanceDraft,
          icon: const Icon(Icons.add_task_outlined, size: 18),
          label: const Text('Create Advance Request'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ],
    ]);
  }

  Widget _payMode(String val, String title, IconData icon, Color color) {
    final sel = _selectedAdvanceMode == val;
    return GestureDetector(
      onTap: () => setState(() { _selectedAdvanceMode = val; _selectedEntryMethod = null; _selectedPaymentAccount = null; _selectedBankAccount = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(color: sel ? color.withOpacity(0.1) : AppTheme.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : AppTheme.border, width: sel ? 1.6 : 1)),
        child: Column(children: [
          Icon(icon, size: 26, color: sel ? color : AppTheme.textSecondary),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sel ? color : AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _upiSelection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Select Verified UPI Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      ..._savedUpiAccounts.map((a) {
        final sel = _selectedPaymentAccount == a['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedPaymentAccount = a['id']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: sel ? AppTheme.successBg : AppTheme.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? AppTheme.success : AppTheme.border, width: sel ? 1.6 : 1)),
            child: Row(children: [
              Icon(sel ? Icons.check_circle : Icons.account_balance_wallet, size: 20, color: sel ? AppTheme.success : AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['upiId']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(a['bankName']!, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
              ])),
              if (a['type'] == 'primary') _tinyChip('Default', AppTheme.info),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _bankEntry() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Saved Bank Accounts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      ..._savedBankAccounts.map((b) {
        final sel = _selectedBankAccount == b['id'];
        return GestureDetector(
          onTap: () => setState(() {
            _selectedBankAccount = b['id'];
            _bankNameCtl.text = b['bankName']!;
            _ifscCtl.text = b['ifsc']!;
            _accNumCtl.text = b['accountNumber']!.replaceAll('*', '');
            _selectedEntryMethod = 'saved';
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: sel ? AppTheme.infoBg : AppTheme.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? AppTheme.info : AppTheme.border, width: sel ? 1.6 : 1)),
            child: Row(children: [
              Icon(sel ? Icons.check_circle : Icons.account_balance_outlined, size: 20, color: sel ? AppTheme.info : AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b['bankName']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text('A/C ${b['accountNumber']} · IFSC: ${b['ifsc']}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                Text(b['holderName']!, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
              ])),
              if (b['type'] == 'primary') _tinyChip('Default', AppTheme.info),
            ]),
          ),
        );
      }),
      const SizedBox(height: 10),
      const Text('Or enter manually', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(controller: _ifscCtl, textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'IFSC Code', prefixIcon: Icon(Icons.code))),
      const SizedBox(height: 8),
      TextField(controller: _accNumCtl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Account Number', prefixIcon: Icon(Icons.account_balance))),
      const SizedBox(height: 8),
      TextField(controller: _bankNameCtl,
          decoration: const InputDecoration(labelText: 'Bank Name', prefixIcon: Icon(Icons.business))),
    ]);
  }

  void _proceedCash() {
    final amt = _amt(_cashAmountCtl);
    if (amt <= 0 || amt > _cashLimit || amt > _cashBalance) {
      _snack('Invalid cash amount or exceeds limit.', AppTheme.danger);
      return;
    }
    setState(() {
      _cashBalance -= amt;
      _cashDrafts.insert(0, _DraftPayment(
        id: 'HOD-CASH-${DateTime.now().millisecondsSinceEpoch}',
        kind: PaymentKind.cash, amount: amt,
        paymentMode: 'Cash', entryMethod: 'HOD approved cash',
        accountLabel: 'Cash balance',
        status: PaymentStatus.hodApproved,
        hodApprovedAt: DateTime.now(),
      ));
      _cashAmountCtl.clear();
    });
    _snack('Cash payment approved by HOD.', AppTheme.success);
  }

  void _createAdvanceDraft() {
    final amt = _amt(_advanceAmountCtl);
    if (amt <= 0) { _snack('Enter valid advance amount.', AppTheme.danger); return; }
    if (_selectedAdvanceMode == null) { _snack('Select advance payment mode.', AppTheme.warning); return; }

    String label = '-', method = '-';
    if (_selectedAdvanceMode == 'upi') {
      if (_selectedPaymentAccount == null) { _snack('Select verified UPI account.', AppTheme.warning); return; }
      final a = _savedUpiAccounts.firstWhere((e) => e['id'] == _selectedPaymentAccount);
      label = a['upiId']!; method = 'Verified UPI';
    } else {
      if (_selectedBankAccount == null && _selectedEntryMethod == null) { _snack('Select saved bank or enter details.', AppTheme.warning); return; }
      if (_selectedBankAccount != null) {
        final b = _savedBankAccounts.firstWhere((e) => e['id'] == _selectedBankAccount);
        label = '${b['bankName']} • ${b['accountNumber']}'; method = 'Saved Bank';
      } else {
        label = '${_bankNameCtl.text.trim()} • ${_accNumCtl.text.trim()}'; method = 'Manual';
      }
    }

    setState(() {
      _advanceDrafts.insert(0, _DraftPayment(
        id: 'HOD-ADV-${DateTime.now().millisecondsSinceEpoch}',
        kind: PaymentKind.advance, amount: amt,
        paymentMode: _selectedAdvanceMode == 'upi' ? 'UPI' : 'Bank Transfer',
        entryMethod: method, accountLabel: label,
        status: PaymentStatus.draft,
      ));
      _advanceAmountCtl.clear();
      _selectedAdvanceMode = null;
      _selectedEntryMethod = null;
      _selectedPaymentAccount = null;
      _selectedBankAccount = null;
    });
    _snack('Advance request created. HOD approval required.', AppTheme.warning);
  }

  void _approveDraft(_DraftPayment d) {
    final i = _advanceDrafts.indexWhere((x) => x.id == d.id);
    if (i == -1) return;
    setState(() {
      _advanceDrafts[i] = d.copyWith(
        status: PaymentStatus.submittedToFinance,
        hodApprovedAt: DateTime.now(),
      );
    });
    _snack('HOD approved — ready for Finance.', AppTheme.success);
  }

  Widget _draftTable(List<_DraftPayment> drafts, Color color, IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border), boxShadow: AppTheme.subtleShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 12),
        if (drafts.isEmpty)
          const Text('No entries yet.' , style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
        else
          ...drafts.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              Expanded(child: Text('${d.id} • ${_money(d.amount)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              if (d.kind == PaymentKind.advance && d.status == PaymentStatus.draft)
                TextButton(onPressed: () => _approveDraft(d),
                    child: const Text('Approve', style: TextStyle(fontSize: 11, color: AppTheme.warning)))
              else
                MachineStatusChip(label: _statusLabel(d.status), customColor: _statusColor(d.status)),
            ]),
          )),
      ]),
    );
  }

  Widget _buildAdvanceTable() {
    if (_enableAdvancePayment) return _buildAdvanceSection();
    if (_advanceDrafts.isEmpty) return const SizedBox.shrink();
    return _draftTable(_advanceDrafts, AppTheme.success, Icons.request_quote_outlined,
        'Advance Payment Request Table', 'HOD approval sends the request to Finance.');
  }

  // ── Step 5: Photo & Submit ──────────────────────────────
  Widget _buildPhotoAndSubmit() {
    final captured = _openingPhotoPath != null;
    return Column(children: [
      GestureDetector(
        onTap: () => setState(() => _openingPhotoPath = 'machine_opening_${DateTime.now().millisecondsSinceEpoch}.jpg'),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: captured ? AppTheme.successBg : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: captured ? AppTheme.success.withOpacity(0.28) : AppTheme.border),
          ),
          child: Row(children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(color: (captured ? AppTheme.success : AppTheme.warning).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(captured ? Icons.check_circle : Icons.add_a_photo_outlined,
                    color: captured ? AppTheme.success : AppTheme.warning)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(captured ? 'Opening Photo Captured' : 'Capture Opening Photo',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(captured ? _openingPhotoPath! : 'Tap to capture opening proof.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ])),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      if (_hasPendingAdvApproval)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.warning.withOpacity(0.22))),
          child: Row(children: [
            const Icon(Icons.pending_actions, color: AppTheme.warning),
            const SizedBox(width: 10),
            const Expanded(child: Text('Advance request still needs HOD approval.',
                style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w800))),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.success.withOpacity(0.22))),
          child: Row(children: [
            const Icon(Icons.verified_outlined, color: AppTheme.success),
            const SizedBox(width: 10),
            const Expanded(child: Text('Payment approval flow is ready.',
                style: TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w800))),
          ]),
        ),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitAll,
        icon: _isSubmitting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_outlined),
        label: Text(_isSubmitting ? 'Submitting...' : 'Complete HOD Machine Entry'),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      )),
    ]);
  }

  // ── Final Submit ────────────────────────────────────────
  Future<void> _submitAll() async {
    final err = _validate();
    if (err != null) { _snack(err, AppTheme.danger); return; }
    if (_hasPendingAdvApproval) { _snack('Approve all advance requests before final submit.', AppTheme.warning); return; }

    setState(() => _isSubmitting = true);
    try {
      // 1. Save or update machine asset
      final now = DateTime.now();
      MachineAsset machine;
      if (_selectedMachine != null) {
        machine = _selectedMachine!.copyWith(
          vehicleNumber: _vehicleNumberCtl.text.trim().toUpperCase(),
          vehicleType: _selectedVehicleType ?? _selectedMachine!.vehicleType,
          operatorName: _operatorNameCtl.text.trim().isEmpty ? _selectedMachine!.operatorName : _operatorNameCtl.text.trim(),
          operatorPhone: _operatorPhoneCtl.text.trim(),
        );
      } else {
        machine = MachineAsset(
          id: _newId('MCH'),
          siteId: _siteId,
          machineName: _operatorNameCtl.text.trim().isNotEmpty ? _operatorNameCtl.text.trim() : 'Machine',
          vehicleNumber: _vehicleNumberCtl.text.trim().toUpperCase(),
          vehicleType: _selectedVehicleType ?? 'Excavator',
          operatorName: _operatorNameCtl.text.trim().isEmpty ? 'Not assigned' : _operatorNameCtl.text.trim(),
          operatorPhone: _operatorPhoneCtl.text.trim(),
          createdBy: _hodIdOrUid,
        );
      }
      await _repository.createMachine(machine: machine);

      // 2. Persist cash drafts as payment requests (HOD approved)
      final allDrafts = [..._cashDrafts, ..._advanceDrafts];
      for (final d in allDrafts) {
        final pr = MachinePaymentRequest(
          id: d.id,
          siteId: _siteId,
          thavvuPointId: _thavvuPointId ?? _siteId,
          kind: d.kind,
          amount: d.amount,
          paymentMode: d.paymentMode,
          entryMethod: d.entryMethod,
          accountLabel: d.accountLabel,
          status: d.kind == PaymentKind.cash ? PaymentStatus.hodApproved : PaymentStatus.draft,
          hodApprovedAt: d.kind == PaymentKind.cash ? now : null,
          hodApprovedBy: d.kind == PaymentKind.cash ? _hodIdOrUid : null,
          createdBy: _hodIdOrUid,
        );
        final saved = await _repository.createPaymentRequest(pr);

        // 3. For advance requests that were HOD-approved, submit to finance
        if (d.kind == PaymentKind.advance && d.status == PaymentStatus.submittedToFinance) {
          await _repository.approvePaymentByHod(paymentId: saved.id, hodId: _hodIdOrUid);
          await _repository.submitApprovedPaymentToFinance(paymentId: saved.id);
        }
      }

      if (!mounted) return;
      _clearForm();
      await _loadData();
      _snack('HOD machine entry submitted. Approved advance requests sent to Finance.', AppTheme.success);
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), AppTheme.danger);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validate() {
    if (_selectedMachine == null && _vehicleNumberCtl.text.trim().isEmpty) return 'Select or add machine.';
    if (_selectedSupplier == null) return 'Select or create supplier.';
    if (_selectedBillingType == null) return 'Select billing type.';
    if (_selectedDieselInclusion == null) return 'Select diesel inclusion.';
    if (_amt(_fareAmountCtl) <= 0) return 'Enter valid fare amount.';
    if (_cashDrafts.isEmpty && _advanceDrafts.isEmpty) return 'Add at least one cash payment or advance request.';
    if (_openingPhotoPath == null) return 'Capture opening photo.';
    return null;
  }

  void _clearForm() {
    setState(() {
      _selectedMachine = null; _selectedSupplier = null;
      _selectedVehicleType = null; _selectedBillingType = null; _selectedDieselInclusion = null;
      _selectedFuelType = _fuelTypes.first; _selectedStockPoint = _stockPoints.first;
      _extraBetaApprovalEnabled = false;
      _vehicleNumberCtl.clear(); _operatorNameCtl.clear(); _operatorPhoneCtl.clear();
      _fareAmountCtl.clear(); _fuelLitersCtl.clear(); _commissionAgentCtl.clear();
      _commissionAmountCtl.clear(); _betaEligibleHoursCtl.text = '8'; _regularBetaAmountCtl.text = '0';
      _extraBetaLimitCtl.text = '0'; _notesCtl.clear();
      _enableCashPayment = false; _enableAdvancePayment = false;
      _cashAmountCtl.clear(); _advanceAmountCtl.clear();
      _selectedAdvanceMode = null; _selectedEntryMethod = null;
      _selectedPaymentAccount = null; _selectedBankAccount = null;
      _cashDrafts.clear(); _advanceDrafts.clear(); _openingPhotoPath = null;
    });
  }

  String _newId(String prefix) => '$prefix-${DateTime.now().millisecondsSinceEpoch}';

  // ═══════════════════════════════════════════════════════════
  // TAB 2 — TODAY RECORDS
  // ═══════════════════════════════════════════════════════════
  Widget _buildRecordsTab() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayPayments = _paymentRequests.where((p) {
      final pd = DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day);
      return pd == todayStart;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: todayPayments.isEmpty
          ? ListView(padding: const EdgeInsets.all(18), children: [
              _emptyState('No records today', 'Today\'s submitted payments will appear here.', Icons.receipt_long),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: todayPayments.length,
              itemBuilder: (_, i) => _buildPaymentCard(todayPayments[i]),
            ),
    );
  }

  Widget _buildPaymentCard(MachinePaymentRequest p) {
    final col = _statusColor(p.status);
    final canComplete = p.isAdvance && p.status == PaymentStatus.submittedToFinance;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: col.withOpacity(0.18)), boxShadow: AppTheme.subtleShadow),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(width: 44, height: 44,
            decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(p.isAdvance ? Icons.request_quote_outlined : Icons.payments_outlined, color: col)),
        title: Text('${p.kind.apiValue.toUpperCase()} • ${_money(p.amount)}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
        subtitle: Text('${p.paymentMode ?? '-'} • ${_fmt(p.createdAt)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        trailing: MachineStatusChip(label: _statusLabel(p.status), customColor: col),
        children: [
          Row(children: [
            Expanded(child: _infoCell('Method', p.entryMethod ?? p.paymentMode ?? '-')),
            const SizedBox(width: 8),
            Expanded(child: _infoCell('Account', p.accountLabel ?? '-')),
          ]),
          const SizedBox(height: 8),
          if (canComplete)
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () => _completeFinance(p),
              icon: const Icon(Icons.done_all, size: 15),
              label: const Text('Finance Complete'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
            ))
          else if (p.status == PaymentStatus.paid)
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: AppTheme.successBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.success.withOpacity(0.22))),
              child: Text('Proof: ${p.paymentProofPath ?? '-'} • Registered in IDs Book: ${p.registeredInIdsBook ? 'Yes' : 'No'}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 3 — FINANCE QUEUE
  // ═══════════════════════════════════════════════════════════
  Widget _buildFinanceQueueTab() {
    final financeItems = _paymentRequests.where((p) =>
        p.isAdvance && (p.status == PaymentStatus.submittedToFinance ||
            p.status == PaymentStatus.financeProcessing ||
            p.status == PaymentStatus.paid ||
            p.status == PaymentStatus.closed)).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: financeItems.isEmpty
          ? ListView(padding: const EdgeInsets.all(18), children: [
              _emptyState('No finance requests yet',
                  'Once HOD approves an advance and submits the machine entry, it will appear here.',
                  Icons.account_balance_rounded),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: financeItems.length,
              itemBuilder: (_, i) => _buildFinanceCard(financeItems[i]),
            ),
    );
  }

  Widget _buildFinanceCard(MachinePaymentRequest p) {
    final completed = p.status == PaymentStatus.paid || p.status == PaymentStatus.closed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: completed ? AppTheme.success.withOpacity(0.22) : AppTheme.primary.withOpacity(0.2)),
          boxShadow: AppTheme.subtleShadow),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: (completed ? AppTheme.success : AppTheme.primary).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.account_balance_rounded, color: completed ? AppTheme.success : AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.kind.apiValue.toUpperCase()} • ${_money(p.amount)}',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${p.id} • ${_fmt(p.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _tinyChip(_money(p.amount), AppTheme.success),
            _tinyChip(p.paymentMode ?? '-', AppTheme.info),
            _tinyChip(_statusLabel(p.status), completed ? AppTheme.success : AppTheme.primary),
          ]),
        ])),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FINANCE ACTIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> _completeFinance(MachinePaymentRequest p) async {
    try {
      await _repository.completeFinancePayment(
        paymentId: p.id,
        proofPath: 'finance_proof_${p.id}.jpg',
        registerInIdsBook: true,
      );
      await _loadData();
      _snack('Finance payment completed.', AppTheme.success);
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst('Exception: ', '')}', AppTheme.danger);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ADD MACHINE / SUPPLIER SHEETS
  // ═══════════════════════════════════════════════════════════
  Future<void> _showAddMachineSheet() async {
    final formKey = GlobalKey<FormState>();
    final nameCtl = TextEditingController();
    final vnCtl = TextEditingController();
    final opCtl = TextEditingController();
    final phCtl = TextEditingController();
    String type = _vehicleTypes.first;

    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
            child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sheetTitle('Add Machine', 'Creates a site-specific machine record.', Icons.add_business_outlined, AppTheme.success),
              const SizedBox(height: 16),
              TextFormField(controller: nameCtl, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Machine Name', prefixIcon: Icon(Icons.precision_manufacturing_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter machine name' : null),
              const SizedBox(height: 12),
              TextFormField(controller: vnCtl, textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Vehicle Number', prefixIcon: Icon(Icons.confirmation_number_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter vehicle number' : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Vehicle Type', prefixIcon: Icon(Icons.agriculture_outlined)),
                items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setSheet(() => type = v ?? type),
              ),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final machine = MachineAsset(
                    id: _newId('MCH'),
                    siteId: _siteId,
                    machineName: nameCtl.text.trim(),
                    vehicleNumber: vnCtl.text.trim().toUpperCase(),
                    vehicleType: type,
                    operatorName: opCtl.text.trim().isEmpty ? 'Not assigned' : opCtl.text.trim(),
                    operatorPhone: phCtl.text.trim(),
                    createdBy: _hodIdOrUid,
                  );
                  try {
                    final saved = await _repository.createMachine(machine: machine);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    await _loadData();
                    setState(() => _selectedMachine = saved);
                    _snack('${saved.vehicleNumber} added.', AppTheme.success);
                  } catch (e) {
                    _snack(e.toString().replaceFirst('Exception: ', ''), AppTheme.danger);
                  }
                },
                icon: const Icon(Icons.add), label: const Text('Add and Select'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
              )),
            ])),
          ));
        });
      },
    );
    nameCtl.dispose(); vnCtl.dispose(); opCtl.dispose(); phCtl.dispose();
  }

  Future<void> _showAddSupplierSheet() async {
    final formKey = GlobalKey<FormState>();
    final nameCtl = TextEditingController();
    final phCtl = TextEditingController();
    final notesCtl = TextEditingController();
    String type = 'permanent';
    double rating = 4.0;

    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
            child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sheetTitle('Create Supplier', 'Supplier becomes available in HOD machine entry.', Icons.store_mall_directory_outlined, AppTheme.success),
              const SizedBox(height: 16),
              TextFormField(controller: nameCtl, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Supplier Name', prefixIcon: Icon(Icons.store_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter supplier name' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _supplierTypeToggle(type, 'permanent', 'Permanent', (v) => setSheet(() => type = v))),
                const SizedBox(width: 10),
                Expanded(child: _supplierTypeToggle(type, 'temporary', 'Temporary', (v) => setSheet(() => type = v))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: phCtl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Rating', style: TextStyle(fontWeight: FontWeight.w800)),
                Expanded(child: Slider(value: rating, min: 1, max: 5, divisions: 8, label: rating.toStringAsFixed(1),
                    onChanged: (v) => setSheet(() => rating = v))),
                Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: notesCtl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes optional', prefixIcon: Icon(Icons.notes_outlined))),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  try {
                    final saved = await _repository.createSupplier(
                      siteId: _siteId, name: nameCtl.text.trim(), type: type,
                      phone: phCtl.text.trim(), rating: rating,
                      notes: notesCtl.text.trim(),
                      thavvuPointId: _thavvuPointId,
                      createdBy: _hodIdOrUid,
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    await _loadData();
                    // Bind the current site context so the selected supplier
                    // is recorded against this site even when the catalog row
                    // originated on another site.
                    setState(() =>
                        _selectedSupplier = saved.copyWith(siteId: _siteId));
                    _snack('${saved.name} supplier created.', AppTheme.success);
                  } catch (e) {
                    final raw = e.toString().replaceFirst('Exception: ', '');
                    final message = raw.contains('23505')
                        ? 'A supplier with this name already exists for this site.'
                        : raw;
                    _snack(message, AppTheme.danger);
                  }
                },
                icon: const Icon(Icons.save_outlined), label: const Text('Save Supplier'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
              )),
            ])),
          ));
        });
      },
    );
    nameCtl.dispose(); phCtl.dispose(); notesCtl.dispose();
  }

  Widget _supplierTypeToggle(String cur, String val, String label, ValueChanged<String> onSel) {
    final sel = cur == val;
    return GestureDetector(
      onTap: () => onSel(val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: sel ? AppTheme.successBg : AppTheme.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? AppTheme.success : AppTheme.border, width: sel ? 1.6 : 1)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: sel ? AppTheme.success : AppTheme.textSecondary, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SHARED WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════
  Widget _buildPreview(IconData icon, Color color, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18))),
      child: Row(children: [
        Icon(icon, color: color), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
      ]),
    );
  }

  Widget _miniMetric(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
        const SizedBox(height: 3),
        Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _tinyChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.22))),
      child: Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w900)),
    );
  }

  Widget _countPill(String label, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Icon(icon, size: 46, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _infoCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _sheetTitle(String title, String subtitle, IconData icon, Color color) {
    return Row(children: [
      Container(width: 42, height: 42,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
      ])),
    ]);
  }

  void _showCashHistory() {
    _showDraftHistory(_cashDrafts, AppTheme.info, 'Cash Payment History');
  }
  void _showAdvanceHistory() {
    _showDraftHistory(_advanceDrafts, AppTheme.success, 'Advance Request History');
  }

  void _showDraftHistory(List<_DraftPayment> drafts, Color color, String title) {
    showModalBottomSheet<void>(
      context: context, backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetTitle(title, 'Current unsaved rows in this HOD entry.', Icons.history_rounded, color),
            const SizedBox(height: 12),
            if (drafts.isEmpty)
              const Padding(padding: EdgeInsets.all(14), child: Text('No transactions yet.', style: TextStyle(color: AppTheme.textMuted)))
            else
              ...drafts.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                child: Row(children: [
                  Icon(d.kind == PaymentKind.cash ? Icons.payments_outlined : Icons.request_quote_outlined, color: color),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${d.id} • ${_money(d.amount)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${d.paymentMode} • ${_statusLabel(d.status)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ])),
                ]),
              )),
          ]),
        ),
      ),
    );
  }
}

// ── Local draft model (not persisted until final submit) ─────
class _DraftPayment {
  final String id;
  final PaymentKind kind;
  final double amount;
  final String paymentMode;
  final String entryMethod;
  final String accountLabel;
  final PaymentStatus status;
  final DateTime? hodApprovedAt;

  const _DraftPayment({
    required this.id,
    required this.kind,
    required this.amount,
    required this.paymentMode,
    required this.entryMethod,
    required this.accountLabel,
    this.status = PaymentStatus.draft,
    this.hodApprovedAt,
  });

  _DraftPayment copyWith({
    String? id,
    PaymentKind? kind,
    double? amount,
    String? paymentMode,
    String? entryMethod,
    String? accountLabel,
    PaymentStatus? status,
    DateTime? hodApprovedAt,
  }) {
    return _DraftPayment(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      entryMethod: entryMethod ?? this.entryMethod,
      accountLabel: accountLabel ?? this.accountLabel,
      status: status ?? this.status,
      hodApprovedAt: hodApprovedAt ?? this.hodApprovedAt,
    );
  }
}
