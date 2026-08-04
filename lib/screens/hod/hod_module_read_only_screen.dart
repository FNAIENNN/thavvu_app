import 'package:flutter/material.dart';

import '../../models/hod_workflow_models.dart';
import '../../services/hod_workflow_store.dart';
import '../../services/thavvu_workflow_seed_service.dart';
import '../../theme/app_theme.dart';

class HodModuleReadOnlyScreen extends StatefulWidget {
  final String title;
  final String moduleFilter;
  final IconData icon;
  final Color color;
  final String actorId;

  const HodModuleReadOnlyScreen({
    super.key,
    required this.title,
    required this.moduleFilter,
    required this.icon,
    required this.color,
    this.actorId = 'HOD-001',
  });

  @override
  State<HodModuleReadOnlyScreen> createState() =>
      _HodModuleReadOnlyScreenState();
}

class _HodModuleReadOnlyScreenState extends State<HodModuleReadOnlyScreen> {
  final HodWorkflowStore _store = HodWorkflowStore();
  late final ThavvuWorkflowSeedService _seedService;
  late Future<_HodReadOnlyModuleData> _future;

  @override
  void initState() {
    super.initState();
    _seedService = ThavvuWorkflowSeedService(store: _store);
    _future = _loadData();
  }

  Future<_HodReadOnlyModuleData> _loadData() async {
    await _seedService.ensureSeeded();
    final requests = await _store.requestsForHod(widget.actorId);
    final actions = await _store.supervisorActionsForHod(widget.actorId);
    return _HodReadOnlyModuleData(
      requests: requests
          .where((request) => request.module == widget.moduleFilter)
          .toList(growable: false),
      actions: actions
          .where((action) => action.module == widget.moduleFilter)
          .toList(growable: false),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadData());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_HodReadOnlyModuleData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ReadOnlyEmptyState(
              title: 'Module data not ready',
              message: snapshot.error.toString(),
              icon: Icons.error_outline_rounded,
            );
          }

          final data = snapshot.data ?? const _HodReadOnlyModuleData();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ReadOnlyHeader(
                  title: widget.title,
                  module: widget.moduleFilter,
                  icon: widget.icon,
                  color: widget.color,
                  requestCount: data.requests.length,
                  actionCount: data.actions.length,
                ),
                const SizedBox(height: 14),
                _MetricRow(data: data, color: widget.color),
                const SizedBox(height: 18),
                const _SectionTitle(title: 'Supervisor Requests'),
                const SizedBox(height: 10),
                if (data.requests.isEmpty)
                  const _ReadOnlyEmptyState(
                    title: 'No supervisor requests',
                    message:
                        'Requests from this module will appear here for HOD review.',
                    icon: Icons.inbox_outlined,
                  )
                else
                  ...data.requests.map(
                    (request) => _RequestCard(
                      request: request,
                      color: widget.color,
                    ),
                  ),
                const SizedBox(height: 18),
                const _SectionTitle(title: 'Supervisor Activity'),
                const SizedBox(height: 10),
                if (data.actions.isEmpty)
                  const _ReadOnlyEmptyState(
                    title: 'No activity recorded',
                    message:
                        'Supervisor submissions and status changes will be listed here.',
                    icon: Icons.manage_search_outlined,
                  )
                else
                  ...data.actions.map(
                    (action) =>
                        _ActionCard(action: action, color: widget.color),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReadOnlyHeader extends StatelessWidget {
  final String title;
  final String module;
  final IconData icon;
  final Color color;
  final int requestCount;
  final int actionCount;

  const _ReadOnlyHeader({
    required this.title,
    required this.module,
    required this.icon,
    required this.color,
    required this.requestCount,
    required this.actionCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3460), Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$module records from supervisor modules',
                  style: const TextStyle(
                    color: Color(0xFFE0F2FE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderChip(label: '$requestCount requests'),
                    _HeaderChip(label: '$actionCount activities'),
                    const _HeaderChip(label: 'HOD workspace'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;

  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final _HodReadOnlyModuleData data;
  final Color color;

  const _MetricRow({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final pending = data.requests
        .where((request) => request.status == ApprovalStatus.pending)
        .length;
    return Row(
      children: [
        _MetricCard(
          label: 'Requests',
          value: '${data.requests.length}',
          icon: Icons.notifications_none_rounded,
          color: color,
        ),
        const SizedBox(width: 10),
        _MetricCard(
          label: 'Pending',
          value: '$pending',
          icon: Icons.hourglass_top_rounded,
          color: AppTheme.warning,
        ),
        const SizedBox(width: 10),
        _MetricCard(
          label: 'Activity',
          value: '${data.actions.length}',
          icon: Icons.timeline_rounded,
          color: AppTheme.success,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: color.withValues(alpha: 0.16)),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ApprovalRequestRecord request;
  final Color color;

  const _RequestCard({required this.request, required this.color});

  @override
  Widget build(BuildContext context) {
    final detail = request.payload['detail']?.toString() ?? request.title;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: request.siteId, color: AppTheme.info),
              _InfoChip(label: request.supervisorId, color: AppTheme.success),
              _InfoChip(
                label: _formatDate(request.createdAt),
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final SupervisorActionRecord action;
  final Color color;

  const _ActionCard({required this.action, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.manage_search_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.description,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${action.supervisorId} • ${action.action} • ${_formatDate(action.createdAt)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ApprovalStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ApprovalStatus.approved => AppTheme.success,
      ApprovalStatus.rejected => AppTheme.danger,
      ApprovalStatus.revisionRequested => AppTheme.warning,
      ApprovalStatus.cancelled => AppTheme.textMuted,
      ApprovalStatus.pending => AppTheme.info,
    };
    return _InfoChip(label: _statusLabel(status), color: color);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReadOnlyEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _ReadOnlyEmptyState({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HodReadOnlyModuleData {
  final List<ApprovalRequestRecord> requests;
  final List<SupervisorActionRecord> actions;

  const _HodReadOnlyModuleData({
    this.requests = const [],
    this.actions = const [],
  });
}

String _statusLabel(ApprovalStatus status) {
  switch (status) {
    case ApprovalStatus.pending:
      return 'Pending';
    case ApprovalStatus.approved:
      return 'Approved';
    case ApprovalStatus.rejected:
      return 'Rejected';
    case ApprovalStatus.revisionRequested:
      return 'Revision';
    case ApprovalStatus.cancelled:
      return 'Cancelled';
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}
