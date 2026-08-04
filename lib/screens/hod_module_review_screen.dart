import 'package:flutter/material.dart';

import '../models/hod_workflow_models.dart';
import '../services/hod_alert_service.dart';
import '../services/hod_workflow_store.dart';
import '../services/thavvu_workflow_seed_service.dart';

class HodModuleReviewScreen extends StatefulWidget {
  final String title;
  final String moduleFilter;
  final String actorId;

  const HodModuleReviewScreen({
    super.key,
    required this.title,
    required this.moduleFilter,
    this.actorId = 'HOD-001',
  });

  @override
  State<HodModuleReviewScreen> createState() => _HodModuleReviewScreenState();
}

class _HodModuleReviewScreenState extends State<HodModuleReviewScreen> {
  final HodWorkflowStore _store = HodWorkflowStore();
  final HodAlertService _alertService = const HodAlertService();
  late final ThavvuWorkflowSeedService _seedService;
  late Future<_HodModuleData> _future;

  @override
  void initState() {
    super.initState();
    _seedService = ThavvuWorkflowSeedService(store: _store);
    _future = _loadData();
  }

  Future<_HodModuleData> _loadData() async {
    await _seedService.ensureSeeded();
    final requests = await _store.requestsForHod(widget.actorId);
    final actions = await _store.supervisorActionsForHod(widget.actorId);
    final alerts = await _alertService.alertsForHod(widget.actorId);
    return _HodModuleData(
      requests: requests
          .where((request) => request.module == widget.moduleFilter)
          .toList(),
      actions: actions
          .where((action) => action.module == widget.moduleFilter)
          .toList(),
      alerts:
          alerts.where((alert) => alert.module == widget.moduleFilter).toList(),
    );
  }

  Future<void> _updateStatus(
    ApprovalRequestRecord request,
    ApprovalStatus status,
  ) async {
    try {
      await _store.updateRequestStatus(
        requestId: request.id,
        status: status,
        actorId: widget.actorId,
        note: '${widget.title} ${status.name}',
      );
      if (!mounted) return;
      setState(() {
        _future = _loadData();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.title} ${status.name}')),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<_HodModuleData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EmptyState(
              title: 'Workflow data not ready',
              message: snapshot.error.toString(),
            );
          }
          final data = snapshot.data ?? const _HodModuleData();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(
                module: widget.moduleFilter,
                pendingCount: data.requests
                    .where(
                        (request) => request.status == ApprovalStatus.pending)
                    .length,
                totalCount: data.requests.length,
                actionCount: data.actions.length,
              ),
              const SizedBox(height: 14),
              const Text(
                'Module Alerts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (data.alerts.isEmpty)
                const _EmptyState(
                  title: 'No module alerts',
                  message: 'Alerts for this module will appear here.',
                )
              else
                ...data.alerts.map(_buildAlertCard),
              const SizedBox(height: 18),
              const Text(
                'Approval Queue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (data.requests.isEmpty)
                const _EmptyState(
                  title: 'No requests found',
                  message:
                      'Supervisor submissions for this module will appear here.',
                )
              else
                ...data.requests.map(_buildRequestCard),
              const SizedBox(height: 18),
              const Text(
                'Supervisor Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (data.actions.isEmpty)
                const _EmptyState(
                  title: 'No activity yet',
                  message:
                      'Supervisor action history for this module will appear here.',
                )
              else
                ...data.actions.map(_buildActionCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertCard(HodAlertViewData alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(alert.icon, color: alert.color),
        title: Text(alert.title),
        subtitle: Text('${alert.siteName} • ${alert.message}'),
        trailing: Chip(
          label: Text(alert.module),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildRequestCard(ApprovalRequestRecord request) {
    final finalDecision = request.status == ApprovalStatus.approved ||
        request.status == ApprovalStatus.rejected ||
        request.status == ApprovalStatus.cancelled;
    final detail = request.payload['detail']?.toString() ?? request.title;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: finalDecision
                      ? null
                      : () => _updateStatus(request, ApprovalStatus.approved),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0FA37A),
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: finalDecision
                      ? null
                      : () => _updateStatus(request, ApprovalStatus.rejected),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(SupervisorActionRecord action) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.manage_search_outlined),
        title: Text(action.description),
        subtitle: Text('${action.supervisorId} · ${action.action}'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String module;
  final int pendingCount;
  final int totalCount;
  final int actionCount;

  const _SummaryCard({
    required this.module,
    required this.pendingCount,
    required this.totalCount,
    required this.actionCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E4F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$module HOD Controls',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(label: 'Pending', value: pendingCount.toString()),
              _MetricChip(label: 'Total', value: totalCount.toString()),
              _MetricChip(label: 'Actions', value: actionCount.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _StatusChip extends StatelessWidget {
  final ApprovalStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(status.name));
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E4F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _HodModuleData {
  final List<ApprovalRequestRecord> requests;
  final List<SupervisorActionRecord> actions;
  final List<HodAlertViewData> alerts;

  const _HodModuleData({
    this.requests = const [],
    this.actions = const [],
    this.alerts = const [],
  });
}
