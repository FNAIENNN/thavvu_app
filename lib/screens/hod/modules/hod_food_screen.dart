import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../models/food_models.dart';
import '../../../services/food_repository.dart';
import '../../../services/attendance_context_service.dart';

/// HOD Food — reads real `food_submissions` (written by supervisors from
/// the food module, which in turn consumes attendance `food_requests`).
///
/// This is a dedicated screen with real data; it is NOT a generic
/// module-review wrapper.
class HodFoodScreen extends StatefulWidget {
  const HodFoodScreen({super.key});

  @override
  State<HodFoodScreen> createState() => _HodFoodScreenState();
}

class _HodFoodScreenState extends State<HodFoodScreen> {
  final FoodRepository _foodRepo = FoodRepository();
  final AttendanceContextService _contextService = AttendanceContextService();

  String? _siteId;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  List<FoodSubmission> _submissions = [];
  Map<String, String> _profileNames = {};
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _loading = true);
    _siteId = await _contextService.resolveSiteId();
    final submissions =
        await _foodRepo.fetchSubmissions(_selectedDate, siteId: _siteId);

    final authors = submissions
        .map((s) => s.submittedBy)
        .whereType<String>()
        .toSet()
        .toList();
    final names = await _foodRepo.fetchProfileNames(authors);

    if (!mounted) return;
    setState(() {
      _submissions = submissions;
      _profileNames = names;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSubmissions();
    }
  }

  Future<void> _setStatus(FoodSubmission submission, String status) async {
    final ok = await _foodRepo.updateSubmissionStatus(submission.id!,
        status: status);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final index = _submissions.indexOf(submission);
        if (index != -1) {
          _submissions[index] = submission.copyWith(status: status);
        }
      });
      _showSnackbar(
        status == 'approved'
            ? '✅ Food submission approved'
            : '❌ Food submission rejected',
        status == 'approved' ? AppTheme.success : AppTheme.danger,
      );
    } else {
      _showSnackbar('Failed to update submission. Check connection.',
          AppTheme.danger);
    }
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
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('HOD Food'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Pick date',
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: _pickDate,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading food submissions...',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSubmissions,
              child: _submissions.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _submissions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildSubmissionCard(_submissions[index]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.restaurant_menu_outlined,
            size: 64, color: AppTheme.textSecondary),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'No food submissions for this date',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Supervisors submit daily food counts from the Food module.\n'
            'Attendance food requests flow there automatically.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionCard(FoodSubmission submission) {
    final isExpanded = _expandedIds.contains(submission.id);
    final statusColor = submission.status == 'approved'
        ? AppTheme.success
        : submission.status == 'rejected'
            ? AppTheme.danger
            : AppTheme.warning;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            final id = submission.id;
            if (id == null) return;
            if (!_expandedIds.remove(id)) _expandedIds.add(id);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.restaurant_menu, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${submission.totalPeople} people • '
                          '${submission.shifts.join(', ')}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profileNames[submission.submittedBy] ??
                              'Supervisor',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: submission.status, color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _countChip('Regular', submission.regularWorkerCount,
                      Icons.badge_outlined),
                  _countChip('Outside', submission.outsideWorkerCount,
                      Icons.groups_2_outlined),
                  _countChip('Machine', submission.machineWorkerCount,
                      Icons.precision_manufacturing_outlined),
                  _countChip(
                      'Guests', submission.guestCount, Icons.person_add_alt_1),
                  _countChip('Other', submission.otherCount, Icons.category),
                ],
              ),
              if (submission.remarks.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '📝 ${submission.remarks}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Submitted ${_formatDateTime(submission.submittedAt)}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
              if (isExpanded && submission.payload != null) ...[
                const Divider(height: 24),
                _buildPayloadList(submission.payload),
              ],
              if (submission.status == 'submitted') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _setStatus(submission, 'rejected'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _setStatus(submission, 'approved'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _countChip(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPayloadList(dynamic payload) {
    if (payload is! List || payload.isEmpty) {
      return const Text('No entry details.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
    }
    final entries = payload
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Entry details',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(_entryIcon(e['entryType']?.toString() ?? ''),
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${e['name'] ?? '-'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    'x${e['peopleCount'] ?? 1}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  IconData _entryIcon(String entryType) {
    if (entryType.contains('Regular')) return Icons.badge_outlined;
    if (entryType.contains('Outside')) return Icons.groups_2_outlined;
    if (entryType.contains('Machine')) return Icons.precision_manufacturing;
    if (entryType.contains('Guest')) return Icons.person_add_alt_1;
    return Icons.category_outlined;
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${dt.day}/${dt.month}/${dt.year} at $h12:$m $ampm';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
