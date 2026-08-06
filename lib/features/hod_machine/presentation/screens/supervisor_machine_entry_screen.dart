import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/attendance_context_service.dart';
import '../../../../services/stock_inventory_repository.dart';
import '../../../../screens/daily_data_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/collapsible_tab_scaffold.dart';
import '../../data/repositories/supabase_hod_machine_repository.dart';
import '../../domain/models/machine_asset.dart';
import '../../domain/models/machine_daily_log.dart';
import '../../domain/models/machine_diesel_line.dart';
import '../../domain/services/hod_machine_repository_interface.dart';
import '../widgets/machine_status_chip.dart';

/// Supervisor Machine Entry — production screen backed by the same
/// [HodMachineRepository] the HOD module uses.
///
/// Flow:
///  1. Pick an assigned machine (from machine_assets for the site).
///  2. Add diesel lines (fuel type, live stock point, litres, remarks).
///  3. Submit: diesel is deducted from stock via the atomic
///     `issue_stock_for_module` RPC, then a MachineDailyLog is persisted
///     (one log per machine per day; later submissions append fuel lines).
///  4. The HOD review screens read the same machine_daily_logs table.
class SupervisorMachineEntryScreen extends StatefulWidget {
  /// Injectable repositories (tests pass fakes; production uses Supabase).
  final HodMachineRepository? repository;
  final StockInventoryRepository? stockRepository;

  const SupervisorMachineEntryScreen({
    super.key,
    this.repository,
    this.stockRepository,
  });

  @override
  State<SupervisorMachineEntryScreen> createState() =>
      _SupervisorMachineEntryScreenState();
}

class _SupervisorMachineEntryScreenState
    extends State<SupervisorMachineEntryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late final HodMachineRepository _repository =
      widget.repository ?? SupabaseHodMachineRepository(null);
  late final StockInventoryRepository _stockRepository =
      widget.stockRepository ?? StockInventoryRepository();
  final AttendanceContextService _contextService = AttendanceContextService();

  // ── Context (site / point / user) ───────────────────────────
  String _siteId = 'SITE-VJA-001';
  String? _thavvuPointId;

  // ── Live data ───────────────────────────────────────────────
  List<MachineAsset> _machines = [];
  List<StockBatchBalance> _balances = [];
  List<MachineDailyLog> _todayLogs = [];
  bool _loading = true;
  String? _errorMessage;

  // ── Entry form ──────────────────────────────────────────────
  MachineAsset? _selectedMachine;
  final List<_DieselDraft> _drafts = [];
  bool _submitting = false;

  static const List<String> _fuelTypes = ['Diesel', 'Petrol', 'CNG', 'Electric'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _addDraft();
    _loadContext();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  List<String> get _stockPointNames {
    final names = <String>{};
    for (final balance in _balances) {
      names.add(balance.stockPointName);
    }
    return names.toList();
  }

  Future<void> _loadContext() async {
    final user = Supabase.instance.client.auth.currentUser;
    final siteId = await _contextService.resolveSiteId();
    if (!mounted) return;
    setState(() {
      _siteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
    });
    String? pointId;
    try {
      final assignment = await Supabase.instance.client
          .from('thavvu_point_assignments')
          .select('thavvu_point_id')
          .eq('supervisor_id', user?.id ?? '')
          .eq('is_active', true)
          .order('assigned_at', ascending: false)
          .limit(1)
          .maybeSingle();
      pointId = assignment?['thavvu_point_id'] as String?;
    } catch (_) {
      // Fall back to site-level point lookup below.
    }
    if (pointId == null) {
      try {
        final point = await Supabase.instance.client
            .from('thavvu_points')
            .select('id')
            .eq('site_id', _siteId)
            .limit(1)
            .maybeSingle();
        pointId = point?['id'] as String?;
      } catch (_) {
        // No point resolvable; daily log sync will be skipped.
      }
    }
    if (!mounted) return;
    _thavvuPointId = pointId;
    await _loadData();
  }

  Future<void> _loadData() async {
    try {
      final machines = await _repository.getMachines(siteId: _siteId);
      final balances = await _stockRepository.fetchBatchBalances();
      final user = Supabase.instance.client.auth.currentUser;
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      List<MachineDailyLog> logs = [];
      try {
        logs = await _repository.getDailyLogs(
          siteId: _siteId,
          supervisorId: user?.id,
          fromDate: dayStart,
          toDate: dayStart.add(const Duration(days: 1)),
        );
      } catch (_) {
        // Records are best-effort; the entry flow still works.
      }
      if (!mounted) return;
      setState(() {
        _machines = machines.where((m) => m.isActive).toList();
        _balances = balances;
        _todayLogs = logs;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Machines could not be loaded: $error';
      });
    }
  }

  void _addDraft() {
    setState(() {
      _drafts.add(_DieselDraft(
        fuelTypes: _fuelTypes,
        stockPointNames: _stockPointNames,
        onRemoved: () => _removeDraft(_drafts.last),
      ));
    });
  }

  void _removeDraft(_DieselDraft draft) {
    if (_drafts.length <= 1) return;
    setState(() {
      draft.dispose();
      _drafts.remove(draft);
    });
  }

  Future<void> _submit() async {
    final machine = _selectedMachine;
    if (machine == null) {
      _showSnackbar('Select a machine / vehicle first.', AppTheme.danger);
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackbar('Sign in to submit a machine entry.', AppTheme.danger);
      return;
    }

    final validDrafts =
        _drafts.where((d) => (double.tryParse(d.litersCtl.text) ?? 0) > 0).toList();
    if (validDrafts.isEmpty) {
      _showSnackbar('Enter litres for at least one diesel line.',
          AppTheme.danger);
      return;
    }

    setState(() => _submitting = true);
    final submissionReference =
        'SUP-MACHINE-${DateTime.now().microsecondsSinceEpoch}';

    try {
      // 1. Blocking: deduct diesel from stock (atomic, idempotent).
      for (var index = 0; index < validDrafts.length; index++) {
        final draft = validDrafts[index];
        final litres = double.tryParse(draft.litersCtl.text) ?? 0;
        final balance = await _stockRepository.findFuelBalance(
          stockPointName: draft.stockPoint,
          fuelType: draft.fuelType,
        );
        await _stockRepository.issueForModule(
          siteId: _siteId,
          module: 'machines',
          sourceReference: '$submissionReference-$index',
          stockBalanceId: balance.id,
          quantity: litres,
          note: '${machine.machineName} ${machine.vehicleNumber}: '
              '${draft.fuelType} (${draft.remarksCtl.text})',
        );
      }

      // 2. Blocking: persist the daily log (one per machine per day).
      final lines = validDrafts
          .map((draft) => MachineDieselLine(
                id:
                    'DL-${DateTime.now().microsecondsSinceEpoch}-${validDrafts.indexOf(draft)}',
                dailyLogId: '',
                fuelType: draft.fuelType,
                stockPoint: draft.stockPoint,
                liters: double.tryParse(draft.litersCtl.text) ?? 0,
                amount: 0,
                remarks: draft.remarksCtl.text.trim().isEmpty
                    ? null
                    : draft.remarksCtl.text.trim(),
              ))
          .toList();

      final log = MachineDailyLog(
        id: 'LOG-${DateTime.now().microsecondsSinceEpoch}',
        logDate: DateTime.now(),
        siteId: _siteId,
        thavvuPointId: _thavvuPointId ?? '',
        supervisorId: user.id,
        machineId: machine.id,
        location: '${machine.machineName} ${machine.vehicleNumber}',
        dieselOption: 'Fuel issued from stock point',
        workingHours: 0,
        workerCount: 0,
        betaAmount: 0,
        extraBetaAmount: 0,
        notes: 'Supervisor machine entry',
        status: DailyLogStatus.submitted,
        submittedAt: DateTime.now(),
        dieselLines: lines,
      );
      await _repository.submitDailyLog(log);

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedMachine = null;
        for (final draft in _drafts) {
          draft.dispose();
        }
        _drafts.clear();
      });
      _addDraft();
      unawaited(_loadData());
      _showSnackbar(
          'Entry submitted — fuel deducted and log saved for HOD review.',
          AppTheme.success);
      // Seamlessly continue into the Daily Machine screen with the
      // registered machine pre-selected (context is preserved on the stack).
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DailyDataScreen(initialMachineId: machine.id),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackbar('Entry was not submitted: $error', AppTheme.danger);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ));
  }

  MachineAsset? _machineById(String? id) {
    if (id == null) return null;
    for (final machine in _machines) {
      if (machine.id == id) return machine;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: 'Machines',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.maybePop(context),
            ),
            controller: _tabController,
            tabs: const [
              Tab(text: 'New Entry'),
              Tab(text: "Today's Records"),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEntryTab(),
            _buildRecordsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    if (_machines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No machines are available for your site yet. '
            'Ask the HOD to add machines first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Machine / Vehicle',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedMachine?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Select machine',
              prefixIcon: const Icon(Icons.precision_manufacturing_outlined,
                  size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            items: _machines
                .map((machine) => DropdownMenuItem(
                      value: machine.id,
                      child: Text(
                        '${machine.machineName} · ${machine.vehicleNumber} '
                        '(${machine.operatorName})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedMachine =
                    _machines.firstWhere((machine) => machine.id == value);
              });
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Diesel Details',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addDraft,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Line'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var index = 0; index < _drafts.length; index++)
            _DieselDraftCard(
              draft: _drafts[index],
              index: index,
              canRemove: _drafts.length > 1,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(
                  _submitting ? 'Submitting...' : 'Submit Diesel Entry',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _todayLogs.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.receipt_long_outlined,
                    size: 44, color: AppTheme.textMuted),
                SizedBox(height: 10),
                Center(
                  child: Text('No entries submitted today.',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _todayLogs.length,
              itemBuilder: (context, index) {
                final log = _todayLogs[index];
                final machine = _machineById(log.machineId);
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
                              machine?.machineName ?? log.machineId,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary),
                            ),
                          ),
                          MachineStatusChip(label: log.status.displayLabel),
                        ],
                      ),
                      if (machine != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${machine.vehicleNumber} · ${machine.operatorName}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${log.dieselLiters.toStringAsFixed(1)} L diesel '
                        '(${log.dieselLines.length} line'
                        '${log.dieselLines.length == 1 ? '' : 's'})',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary),
                      ),
                      if (log.notes != null &&
                          log.notes!.trim().isNotEmpty &&
                          log.notes != 'Supervisor machine entry') ...[
                        const SizedBox(height: 6),
                        Text(log.notes!,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppTheme.textMuted)),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 10),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
                _loadData();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DieselDraft {
  final List<String> fuelTypes;
  final List<String> stockPointNames;
  final VoidCallback onRemoved;
  String fuelType;
  String stockPoint;
  final TextEditingController litersCtl = TextEditingController();
  final TextEditingController remarksCtl = TextEditingController();

  _DieselDraft({
    required this.fuelTypes,
    required this.stockPointNames,
    required this.onRemoved,
  })  : fuelType = fuelTypes.first,
        stockPoint = stockPointNames.isNotEmpty ? stockPointNames.first : '';

  void dispose() {
    litersCtl.dispose();
    remarksCtl.dispose();
  }
}

class _DieselDraftCard extends StatelessWidget {
  final _DieselDraft draft;
  final int index;
  final bool canRemove;

  const _DieselDraftCard({
    required this.draft,
    required this.index,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Line ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary)),
              const Spacer(),
              if (canRemove)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.danger),
                  onPressed: draft.onRemoved,
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: draft.fuelType,
            decoration: InputDecoration(
              labelText: 'Fuel Type',
              prefixIcon: const Icon(Icons.local_gas_station, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            items: draft.fuelTypes
                .map((type) => DropdownMenuItem(
                    value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              draft.fuelType = value;
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: draft.stockPoint.isEmpty ? null : draft.stockPoint,
            decoration: InputDecoration(
              labelText: 'Stock Point',
              prefixIcon: const Icon(Icons.warehouse_outlined, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            items: draft.stockPointNames
                .map((point) => DropdownMenuItem(
                    value: point, child: Text(point)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              draft.stockPoint = value;
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.litersCtl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Litres',
              prefixIcon: const Icon(Icons.numbers, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.remarksCtl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Remarks (optional)',
              prefixIcon: const Icon(Icons.notes_outlined, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
