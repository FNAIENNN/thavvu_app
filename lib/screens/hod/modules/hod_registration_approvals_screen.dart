import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supervisor_registration_repository.dart';
import '../../../theme/app_theme.dart';

/// HOD Supervisor Registrations module.
///
/// Supervisors who self-register from the login screen land here as
/// PENDING requests. HOD approves (optionally picking the site the
/// supervisor will work on — the account is provisioned immediately with
/// the password the supervisor chose) or rejects with a note. Realtime
/// keeps the list fresh the moment a supervisor submits.
class HodRegistrationApprovalsScreen extends StatefulWidget {
  const HodRegistrationApprovalsScreen({super.key, this.repository});

  final SupervisorRegistrationRepository? repository;

  @override
  State<HodRegistrationApprovalsScreen> createState() =>
      _HodRegistrationApprovalsScreenState();
}

class _HodRegistrationApprovalsScreenState
    extends State<HodRegistrationApprovalsScreen> {
  late final SupervisorRegistrationRepository _repo =
      widget.repository ?? SupervisorRegistrationRepository();
  List<SupervisorRegistration> _requests = [];
  List<RegistrationSiteOption> _sites = [];
  bool _loading = true;
  bool _acting = false;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _repo.watchRequests(_load);
  }

  @override
  void dispose() {
    _repo.stopWatching(_channel);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.fetchRequests(),
        _repo.fetchSites(),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<SupervisorRegistration>;
        _sites = results[1] as List<RegistrationSiteOption>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load registrations. Pull to retry.';
      });
    }
  }

  List<SupervisorRegistration> get _pending =>
      _requests.where((r) => r.isPending).toList();

  List<SupervisorRegistration> get _reviewed =>
      _requests.where((r) => !r.isPending).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Supervisor Registrations'),
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
                _MiniTag(
                  '${_pending.length} Pending',
                  _pending.isNotEmpty ? AppTheme.warning : AppTheme.success,
                  icon: Icons.pending_actions_outlined,
                ),
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
    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined,
                size: 64, color: AppTheme.success),
            SizedBox(height: 16),
            Text('No registration requests',
                style: TextStyle(
                    fontSize: 16, color: AppTheme.textSecondary)),
            SizedBox(height: 4),
            Text(
                'Supervisor sign-ups from the login screen appear here for approval.',
                textAlign: TextAlign.center,
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
            const _SectionLabel('Pending Approval',
                Icons.fact_check_outlined, AppTheme.warning),
            for (final request in _pending)
              _buildRequestCard(request, pending: true),
          ],
          if (_reviewed.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _SectionLabel('Reviewed', Icons.verified_outlined,
                AppTheme.success),
            for (final request in _reviewed)
              _buildRequestCard(request, pending: false),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestCard(SupervisorRegistration request,
      {required bool pending}) {
    final statusColor = request.isRejected
        ? AppTheme.danger
        : request.isApproved
            ? AppTheme.success
            : AppTheme.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: request.isRejected
              ? AppTheme.danger.withValues(alpha: 0.4)
              : pending
                  ? AppTheme.warning.withValues(alpha: 0.35)
                  : AppTheme.border,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  request.isRejected
                      ? Icons.cancel_outlined
                      : request.isApproved
                          ? Icons.verified_outlined
                          : Icons.hourglass_top_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.fullName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(request.email,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _MiniTag(
                request.status.toUpperCase(),
                statusColor,
                icon: request.isApproved
                    ? Icons.check_circle_outline
                    : request.isRejected
                        ? Icons.cancel_outlined
                        : Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _MiniTag(request.empId, AppTheme.info,
                icon: Icons.badge_outlined),
            _MiniTag(request.phone, AppTheme.info,
                icon: Icons.phone_outlined),
            if (request.siteName.isNotEmpty)
              _MiniTag(request.siteName, AppTheme.info,
                  icon: Icons.location_on_outlined),
            _MiniTag(_formatTime(request.createdAt), AppTheme.textMuted,
                icon: Icons.schedule),
          ]),
          if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: request.isRejected
                    ? AppTheme.dangerBg
                    : AppTheme.infoBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: (request.isRejected
                            ? AppTheme.danger
                            : AppTheme.info)
                        .withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    request.isRejected
                        ? Icons.info_outline
                        : Icons.notes_rounded,
                    size: 14,
                    color: request.isRejected
                        ? AppTheme.danger
                        : AppTheme.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.adminNote!,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: request.isRejected
                              ? AppTheme.danger
                              : AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _acting
                        ? null
                        : () => _confirmReject(request),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(
                          color: AppTheme.danger.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _acting ? null : () => _openApproveSheet(request),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Approve & Create Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
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

  // ── Approve flow: site picker sheet ─────────────────────────────────────

  Future<void> _openApproveSheet(SupervisorRegistration request) async {
    final suggested = _matchSite(request.siteName);
    String? siteId = suggested?.id;
    String? siteLabel =
        suggested == null ? null : '${suggested.name} · ${suggested.place}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Approve Supervisor',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${request.fullName} · ${request.email}\n'
                  'Their chosen password will work immediately after approval.',
                  style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Assign to Site',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  initialValue: siteId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.apartment_rounded, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No site yet (assign later)',
                          style: TextStyle(fontSize: 13)),
                    ),
                    for (final site in _sites)
                      DropdownMenuItem<String?>(
                        value: site.id,
                        child: Text(
                          siteLabel == null
                              ? site.label
                              : (site.id == suggested?.id
                                  ? '${site.label}  (requested)'
                                  : site.label),
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => siteId = value),
                ),
                if (request.siteName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Requested: ${request.siteName}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _acting
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _approve(request, siteId: siteId);
                          },
                    icon: const Icon(Icons.verified_user_rounded, size: 18),
                    label: Text(
                        _acting ? 'Creating…' : 'Approve & Create Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _approve(
      SupervisorRegistration request, {String? siteId}) async {
    setState(() => _acting = true);
    final result = await _repo.approve(request.id, siteId: siteId);
    if (!mounted) return;
    setState(() => _acting = false);
    if (result == null || result['status'] != 'approved') {
      _showSnack('Could not approve. Check the request and try again.',
          AppTheme.danger);
      return;
    }
    _showSnack(
      '${request.fullName} approved — '
      'login: ${result['email']} / emp id ${result['emp_id']}',
      AppTheme.success,
    );
    _load();
  }

  // ── Reject flow ──────────────────────────────────────────────────────────

  Future<void> _confirmReject(SupervisorRegistration request) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Reject Registration',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.fullName} · ${request.email}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Employee ID mismatch',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject',
                style: TextStyle(
                    color: AppTheme.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    final ok = await _repo.reject(request.id,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
    if (!mounted) return;
    setState(() => _acting = false);
    _showSnack(
      ok ? 'Registration rejected.' : 'Could not reject. Try again.',
      ok ? AppTheme.success : AppTheme.danger,
    );
    _load();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  RegistrationSiteOption? _matchSite(String requested) {
    if (requested.isEmpty) return null;
    final needle = requested.toLowerCase();
    for (final site in _sites) {
      if (site.name.toLowerCase().contains(needle) ||
          needle.contains(site.name.toLowerCase()) ||
          site.id.toLowerCase().contains(needle)) {
        return site;
      }
    }
    return null;
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
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

  String _formatTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]}, $h:$m $ampm';
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
