import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';

/// Reusable "live activity" table backed by [AppStore.loadActivityReport].
///
/// Shared by the Reports screen (Supervisor) and the HOD dashboard so both
/// roles see the same scoped (site/point/hod) feed of stock, transfer, daily
/// log, attendance, supplier and machine events straight from
/// `app_activity_events`.
class ActivityFeedView extends StatefulWidget {
  const ActivityFeedView({super.key});

  @override
  State<ActivityFeedView> createState() => _ActivityFeedViewState();
}

class _ModuleFilter {
  final String value;
  final String label;
  const _ModuleFilter(this.value, this.label);
}

class _ActivityFeedViewState extends State<ActivityFeedView> {
  static const _modules = [
    _ModuleFilter('all', 'All'),
    _ModuleFilter('stock', 'Stock'),
    _ModuleFilter('transfer', 'Transfer'),
    _ModuleFilter('daily_data', 'Daily'),
    _ModuleFilter('attendance', 'Attendance'),
    _ModuleFilter('supplier', 'Supplier'),
    _ModuleFilter('machines', 'Machines'),
  ];

  String _module = 'all';
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();
  bool _loading = false;
  List<ActivityEvent> _events = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final store = context.read<AppStore>();
    if (!store.remoteEnabled) {
      setState(() => _error = 'Connect to the live backend to see the activity feed.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final events = await store.loadActivityReport(
      module: _module,
      from: _from,
      to: _to.add(const Duration(days: 1)),
    );
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
      _load();
    }
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _modules)
              _chip(m.label, _module == m.value, () {
                setState(() => _module = m.value);
                _load();
              }),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Text('${_fmt(_from)} – ${_fmt(_to)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted), textAlign: TextAlign.center),
            ),
          )
        else if (_events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: Text('No activity in this range', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
          )
        else
          _buildTable(),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 60,
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Module', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Action', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          ],
          rows: _events.map((e) {
            return DataRow(cells: [
              DataCell(Text(_fmt(e.createdAt), style: const TextStyle(fontSize: 11))),
              DataCell(_moduleTag(e.type)),
              DataCell(Text(e.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              DataCell(SizedBox(
                width: 220,
                child: Text(e.detail, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis, maxLines: 2),
              )),
              DataCell(Text(
                e.quantity != null ? '${e.quantity!.toStringAsFixed(e.quantity! % 1 == 0 ? 0 : 1)}${e.unit != null ? ' ${e.unit}' : ''}' : '—',
                style: const TextStyle(fontSize: 11),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _moduleTag(String module) {
    final color = switch (module) {
      'stock' => AppTheme.warning,
      'transfer' => AppTheme.info,
      'daily_data' => AppTheme.success,
      'attendance' => AppTheme.primary,
      'supplier' => AppTheme.danger,
      'machines' => AppTheme.info,
      _ => AppTheme.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(module, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
