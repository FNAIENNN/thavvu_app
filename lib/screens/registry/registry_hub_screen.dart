import 'package:flutter/material.dart';

import '../../features/hod_machine/data/repositories/supabase_hod_machine_repository.dart';
import '../../features/hod_machine/domain/models/machine_asset.dart';
import '../../models/attendance_models.dart';
import '../../models/supplier_model.dart';
import '../../services/attendance_context_service.dart';
import '../../services/attendance_repository.dart';
import '../../services/stock_inventory_repository.dart';
import '../../services/supabase_supplier_repository.dart';
import '../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registry Hub — ONE place where every master-data dropdown is managed.
///
/// For each registry (stock items, suppliers, workers, machines) the user
/// can:
///   • ADD a new entry   → stored permanently in Supabase
///   • DELETE an entry   → soft-delete (hidden from every dropdown, history
///     preserved), with restore available
///
/// Deleted entries immediately disappear from every existing dropdown/list
/// because the repos filter on the active flag (is_active / active / status).
class RegistryHubScreen extends StatefulWidget {
  const RegistryHubScreen({super.key});

  @override
  State<RegistryHubScreen> createState() => _RegistryHubScreenState();
}

class _RegistryHubScreenState extends State<RegistryHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _stockRepo = StockInventoryRepository();
  final _supplierRepo = SupabaseSupplierRepository();
  final _attendanceRepo = AttendanceRepository();
  final _machineRepo = SupabaseHodMachineRepository(null);
  final _contextService = AttendanceContextService();

  String _siteId = 'SITE-VJA-001';
  String? _pointId;

  // Items
  List<StockInventoryItem> _items = [];
  // Suppliers
  List<Supplier> _suppliers = [];
  // Workers
  List<WorkerProfile> _workers = [];
  // Machines
  List<MachineAsset> _machines = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final siteId = await _contextService.resolveSiteId();
      final pointId = await _contextService.resolvePointId();
      if (!mounted) return;
      _siteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
      _pointId = pointId;
    } catch (_) {
      // Defaults keep the screen usable.
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _stockRepo.fetchAllItems(),
        _supplierRepo.fetchAll(),
        _attendanceRepo.fetchAllWorkers(siteId: _siteId),
        _machineRepo.getMachines(siteId: _siteId),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<StockInventoryItem>;
        _suppliers = results[1] as List<Supplier>;
        _workers = results[2] as List<WorkerProfile>;
        _machines = results[3] as List<MachineAsset>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load registries: $e';
      });
    }
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  Future<bool> _confirmDelete(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(message,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ════════════════════════════════════════════════════════════
  // ITEMS
  // ════════════════════════════════════════════════════════════

  Future<void> _addItem() async {
    final nameCtrl = TextEditingController();
    final uomCtrl = TextEditingController(text: 'units');
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Add New Item',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., TMT Steel Bar 16mm',
                  prefixIcon: Icon(Icons.edit_outlined, size: 18)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: uomCtrl,
                    decoration: const InputDecoration(
                        labelText: 'UoM',
                        prefixIcon: Icon(Icons.straighten, size: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Code (optional)',
                        prefixIcon: Icon(Icons.tag, size: 18)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Save Item'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final added = await _stockRepo.addStockItem(
      name: nameCtrl.text,
      uom: uomCtrl.text,
      code: codeCtrl.text,
    );
    if (!mounted) return;
    if (added) {
      _snack('Item "${nameCtrl.text.trim()}" saved permanently.',
          AppTheme.success);
      await _load();
    } else {
      _snack('Failed to add item.', AppTheme.danger);
    }
  }

  Future<void> _deleteItem(StockInventoryItem item) async {
    final confirm = await _confirmDelete(
        'Delete "${item.name}"?',
        'It will be hidden from every dropdown and list. '
        'Existing stock history is preserved.');
    if (!confirm) return;
    final ok = await _stockRepo.setStockItemActive(item.id, false);
    if (!mounted) return;
    _snack(ok ? 'Item deleted.' : 'Delete failed.', ok ? AppTheme.success : AppTheme.danger);
    if (ok) await _load();
  }

  Future<void> _restoreItem(StockInventoryItem item) async {
    final ok = await _stockRepo.setStockItemActive(item.id, true);
    if (!mounted) return;
    _snack(ok ? 'Item restored.' : 'Restore failed.',
        ok ? AppTheme.success : AppTheme.danger);
    if (ok) await _load();
  }

  Widget _buildItemsTab() {
    return _buildTabScaffold(
      empty: 'No items yet. Tap "Add New Item" to create your first catalog entry.',
      onAdd: _addItem,
      addLabel: 'Add New Item',
      count: _items.length,
      children: [
        for (final item in _items)
          _RegistryTile(
            title: item.name,
            subtitle: '${item.uom} · ${item.category.isNotEmpty ? item.category : 'General'}'
                '${item.code.isNotEmpty ? ' · ${item.code}' : ''}',
            icon: Icons.inventory_2_outlined,
            color: AppTheme.primary,
            active: item.isActive,
            onDelete: item.isActive ? () => _deleteItem(item) : null,
            onRestore: item.isActive ? null : () => _restoreItem(item),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // SUPPLIERS
  // ════════════════════════════════════════════════════════════

  Future<void> _addSupplier() async {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Add New Supplier',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Supplier Name *',
                    prefixIcon: Icon(Icons.business_outlined, size: 18)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(
                    labelText: 'Contact Person',
                    prefixIcon: Icon(Icons.person_outline, size: 18)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: upiCtrl,
                decoration: const InputDecoration(
                    labelText: 'Payment UPI (optional)',
                    prefixIcon: Icon(Icons.qr_code, size: 18)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Save Supplier'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (nameCtrl.text.trim().isEmpty) {
      _snack('Supplier name is required.', AppTheme.warning);
      return;
    }
    bool added;
    try {
      added = await _supplierRepo.addSupplier(
        name: nameCtrl.text,
        contactPerson: contactCtrl.text.trim().isEmpty ? null : contactCtrl.text.trim(),
        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
        siteId: _siteId,
        thavvuPointId: _pointId,
        paymentUpi: upiCtrl.text.trim().isEmpty ? null : upiCtrl.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to add supplier: $e', AppTheme.danger);
      return;
    }
    if (!mounted) return;
    if (added) {
      _snack('Supplier "${nameCtrl.text.trim()}" saved permanently.',
          AppTheme.success);
      await _load();
    } else {
      _snack('Supplier name is required.', AppTheme.warning);
    }
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirm = await _confirmDelete(
        'Delete "${supplier.name}"?',
        'It will be hidden from the GIN composer and every list. '
        'Supplier history is preserved.');
    if (!confirm) return;
    final ok = await _supplierRepo.setSupplierActive(supplier.id, false);
    if (!mounted) return;
    _snack(ok ? 'Supplier deleted.' : 'Delete failed.',
        ok ? AppTheme.success : AppTheme.danger);
    if (ok) await _load();
  }

  Future<void> _restoreSupplier(Supplier supplier) async {
    final ok = await _supplierRepo.setSupplierActive(supplier.id, true);
    if (!mounted) return;
    _snack(ok ? 'Supplier restored.' : 'Restore failed.',
        ok ? AppTheme.success : AppTheme.danger);
    if (ok) await _load();
  }

  Widget _buildSuppliersTab() {
    return _buildTabScaffold(
      empty: 'No suppliers yet. Add suppliers here — they appear in the '
          'supervisor GIN entry immediately.',
      onAdd: _addSupplier,
      addLabel: 'Add New Supplier',
      count: _suppliers.length,
      children: [
        for (final s in _suppliers)
          _RegistryTile(
            title: s.name,
            subtitle: [
              if (s.contactPerson.isNotEmpty) 'Contact: ${s.contactPerson}',
              if (s.phone.isNotEmpty) s.phone,
              if (s.address.isNotEmpty) s.address,
            ].join(' · '),
            icon: Icons.business_outlined,
            color: AppTheme.info,
            active: s.active,
            onDelete: s.active ? () => _deleteSupplier(s) : null,
            onRestore: s.active ? null : () => _restoreSupplier(s),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // WORKERS
  // ════════════════════════════════════════════════════════════

  Future<void> _addWorker() async {
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final wageCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Add New Worker',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Worker Name *',
                  prefixIcon: Icon(Icons.person_add_alt_1, size: 18)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: deptCtrl,
              decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.badge_outlined, size: 18)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_outlined, size: 18)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: wageCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Wage (₹/day)',
                  prefixIcon: Icon(Icons.currency_rupee, size: 18)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Save Worker'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (nameCtrl.text.trim().isEmpty) {
      _snack('Worker name is required.', AppTheme.warning);
      return;
    }
    final wage = double.tryParse(wageCtrl.text.trim());
    final worker = WorkerProfile(
      id: '',
      siteId: _siteId,
      thavvuPointId: _pointId,
      name: nameCtrl.text.trim(),
      department: deptCtrl.text.trim().isEmpty ? null : deptCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      wage: wage,
      status: 'active',
    );
    final created = await _attendanceRepo.createWorker(worker);
    if (!mounted) return;
    if (created != null) {
      _snack('Worker "${nameCtrl.text.trim()}" saved permanently.',
          AppTheme.success);
      await _load();
    } else {
      _snack('Failed to add worker.', AppTheme.danger);
    }
  }

  Future<void> _deleteWorker(WorkerProfile worker) async {
    final confirm = await _confirmDelete(
        'Delete "${worker.name}"?',
        'They will be hidden from attendance, food and payment dropdowns. '
        'Attendance history is preserved.');
    if (!confirm) return;
    final ok = await _attendanceRepo.setWorkerStatus(worker.id, 'inactive');
    if (!mounted) return;
    _snack(ok ? 'Worker deleted.' : 'Delete failed.',
        ok ? AppTheme.success : AppTheme.danger);
    if (ok) await _load();
  }

  Future<void> _restoreWorker(WorkerProfile worker) async {
    final ok = await _attendanceRepo.setWorkerStatus(worker.id, 'active');
    if (!mounted) return;
    _snack(ok ? 'Worker restored.' : 'Restore failed.',
        ok ? AppTheme.success : AppTheme.danger);
    if (ok) await _load();
  }

  Widget _buildWorkersTab() {
    return _buildTabScaffold(
      empty: 'No workers yet. Add workers here — they appear in attendance, '
          'food and payment entry screens immediately.',
      onAdd: _addWorker,
      addLabel: 'Add New Worker',
      count: _workers.length,
      children: [
        for (final w in _workers)
          _RegistryTile(
            title: w.name,
            subtitle: [
              if (w.department != null && w.department!.isNotEmpty) w.department!,
              if (w.phone != null && w.phone!.isNotEmpty) w.phone!,
              if (w.wage != null) '₹${w.wage!.toStringAsFixed(0)}/day',
            ].join(' · '),
            icon: Icons.person_outline,
            color: AppTheme.success,
            active: w.status == 'active',
            onDelete: w.status == 'active' ? () => _deleteWorker(w) : null,
            onRestore: w.status == 'active' ? null : () => _restoreWorker(w),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // MACHINES
  // ════════════════════════════════════════════════════════════

  Future<void> _addMachine() async {
    final nameCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final operatorCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Add New Machine',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Machine Name *',
                    hintText: 'e.g., JCB 3DX',
                    prefixIcon: Icon(Icons.construction_rounded, size: 18)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: vehicleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Vehicle Number *',
                    hintText: 'e.g., RJ-14-XXXX',
                    prefixIcon: Icon(Icons.directions_bus_outlined, size: 18)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: typeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    hintText: 'JCB / Excavator / Truck / Mixer',
                    prefixIcon: Icon(Icons.category_outlined, size: 18)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: operatorCtrl,
                decoration: const InputDecoration(
                    labelText: 'Operator Name',
                    prefixIcon: Icon(Icons.person_outline, size: 18)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Operator Phone',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Save Machine'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (nameCtrl.text.trim().isEmpty || vehicleCtrl.text.trim().isEmpty) {
      _snack('Machine name and vehicle number are required.', AppTheme.warning);
      return;
    }
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final machine = MachineAsset(
      id: 'MACHINE-${DateTime.now().millisecondsSinceEpoch}',
      siteId: _siteId,
      machineName: nameCtrl.text.trim(),
      vehicleNumber: vehicleCtrl.text.trim(),
      vehicleType: typeCtrl.text.trim().isEmpty ? 'General' : typeCtrl.text.trim(),
      operatorName: operatorCtrl.text.trim().isEmpty ? '-' : operatorCtrl.text.trim(),
      operatorPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      createdBy: uid,
    );
    try {
      await _machineRepo.createMachine(machine: machine);
      if (!mounted) return;
      _snack('Machine "${nameCtrl.text.trim()}" saved permanently.',
          AppTheme.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to add machine: $e', AppTheme.danger);
    }
  }

  Future<void> _deleteMachine(MachineAsset machine) async {
    final confirm = await _confirmDelete(
        'Delete "${machine.machineName}"?',
        'It will be hidden from Machine Entry and every dropdown. '
        'Machine logs are preserved.');
    if (!confirm) return;
    try {
      await _machineRepo.deactivateMachine(machine.id);
      if (!mounted) return;
      _snack('Machine deleted.', AppTheme.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Delete failed: $e', AppTheme.danger);
    }
  }

  Widget _buildMachinesTab() {
    return _buildTabScaffold(
      empty: 'No machines yet. Add machines here — they appear in the '
          'supervisor Machine Entry screen immediately.',
      onAdd: _addMachine,
      addLabel: 'Add New Machine',
      count: _machines.length,
      children: [
        for (final m in _machines)
          _RegistryTile(
            title: m.machineName,
            subtitle: '${m.vehicleNumber} · ${m.vehicleType}'
                ' · Operator: ${m.operatorName}',
            icon: Icons.construction_rounded,
            color: AppTheme.warning,
            active: m.isActive,
            onDelete: m.isActive ? () => _deleteMachine(m) : null,
            onRestore: null,
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // SHARED SCAFFOLDING
  // ════════════════════════════════════════════════════════════

  Widget _buildTabScaffold({
    required String empty,
    required VoidCallback onAdd,
    required String addLabel,
    required int count,
    required List<Widget> children,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 40, color: AppTheme.textMuted),
              const SizedBox(height: 10),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text('$count entr${count == 1 ? 'y' : 'ies'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(addLabel,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inbox_outlined,
                            size: 56, color: AppTheme.textMuted),
                        const SizedBox(height: 14),
                        Text(empty,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => children[i],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Manage Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          isScrollable: true,
          labelStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Items'),
            Tab(text: 'Suppliers'),
            Tab(text: 'Workers'),
            Tab(text: 'Machines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildItemsTab(),
          _buildSuppliersTab(),
          _buildWorkersTab(),
          _buildMachinesTab(),
        ],
      ),
    );
  }
}

/// One registry row with delete (and restore) actions.
class _RegistryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  const _RegistryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.active,
    this.onDelete,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: active ? AppTheme.border : AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ),
                    if (!active) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Deleted',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.danger)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (onRestore != null)
            IconButton(
              tooltip: 'Restore',
              onPressed: onRestore,
              icon: const Icon(Icons.restore,
                  size: 20, color: AppTheme.success),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppTheme.danger),
            ),
        ],
      ),
    );
  }
}
