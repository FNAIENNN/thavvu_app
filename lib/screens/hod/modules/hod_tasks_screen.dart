import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';
import '../../../widgets/collapsible_tab_scaffold.dart';
import '../../../services/supabase_tasks_repository.dart';
// ── HOD Tasks & Checklist Production-Ready Frontend Module ────────────────
// This screen is intentionally HOD-specific. It mirrors the supervisor
// TasksScreen UI language, but changes the actions from "complete work" to
// "assign, monitor, review, approve, reject, and request revision".
//
// Backend note:
// Task/checklist records and the supervisor roster load from Supabase via
// SupabaseTasksRepository / the account RPCs (no demo data).

// ── Enums and labels ───────────────────────────────────────────────────────

enum HodTaskType { daily, weekly, monthly, safety, machine, stock, attendance, custom }

enum HodTaskPriority { low, normal, high, urgent }

enum HodTaskWorkStatus { pending, inProgress, completed, overdue, cancelled }

enum HodTaskReviewStatus { draft, pendingReview, approved, revisionRequested, rejected }

enum HodProofType { photo, video, voiceNote, textNote, document, location }

enum HodTaskKind { task, checklist }

extension HodTaskTypeLabel on HodTaskType {
  String get label {
    switch (this) {
      case HodTaskType.daily:
        return 'Daily';
      case HodTaskType.weekly:
        return 'Weekly';
      case HodTaskType.monthly:
        return 'Monthly';
      case HodTaskType.safety:
        return 'Safety';
      case HodTaskType.machine:
        return 'Machine';
      case HodTaskType.stock:
        return 'Stock';
      case HodTaskType.attendance:
        return 'Attendance';
      case HodTaskType.custom:
        return 'Custom';
    }
  }
}

extension HodTaskPriorityLabel on HodTaskPriority {
  String get label {
    switch (this) {
      case HodTaskPriority.low:
        return 'Low';
      case HodTaskPriority.normal:
        return 'Normal';
      case HodTaskPriority.high:
        return 'High';
      case HodTaskPriority.urgent:
        return 'Urgent';
    }
  }
}

extension HodTaskWorkStatusLabel on HodTaskWorkStatus {
  String get label {
    switch (this) {
      case HodTaskWorkStatus.pending:
        return 'Pending';
      case HodTaskWorkStatus.inProgress:
        return 'In Progress';
      case HodTaskWorkStatus.completed:
        return 'Completed';
      case HodTaskWorkStatus.overdue:
        return 'Overdue';
      case HodTaskWorkStatus.cancelled:
        return 'Cancelled';
    }
  }
}

extension HodTaskReviewStatusLabel on HodTaskReviewStatus {
  String get label {
    switch (this) {
      case HodTaskReviewStatus.draft:
        return 'Draft';
      case HodTaskReviewStatus.pendingReview:
        return 'Pending Review';
      case HodTaskReviewStatus.approved:
        return 'Approved';
      case HodTaskReviewStatus.revisionRequested:
        return 'Revision Requested';
      case HodTaskReviewStatus.rejected:
        return 'Rejected';
    }
  }
}

extension HodProofTypeLabel on HodProofType {
  String get label {
    switch (this) {
      case HodProofType.photo:
        return 'Photo';
      case HodProofType.video:
        return 'Video';
      case HodProofType.voiceNote:
        return 'Voice Note';
      case HodProofType.textNote:
        return 'Text Note';
      case HodProofType.document:
        return 'Document';
      case HodProofType.location:
        return 'Location';
    }
  }
}

extension HodTaskKindLabel on HodTaskKind {
  String get label => this == HodTaskKind.checklist ? 'Checklist' : 'Task';
}

// ── Models ────────────────────────────────────────────────────────────────

class HodTaskProof {
  final String id;
  final HodProofType type;
  final String fileName;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String remarks;

  const HodTaskProof({
    required this.id,
    required this.type,
    required this.fileName,
    required this.uploadedBy,
    required this.uploadedAt,
    this.remarks = '',
  });
}

class HodTaskChecklistItem {
  final String title;
  bool done;
  String note;

  HodTaskChecklistItem({
    required this.title,
    this.done = false,
    this.note = '',
  });
}

class HodTaskRecord {
  final String id;
  final HodTaskKind kind;
  String title;
  String description;
  HodTaskType type;
  HodTaskPriority priority;
  String assignedSupervisorId;
  String assignedSupervisorName;
  String siteId;
  String siteName;
  String thavvuPointId;
  DateTime dueDate;
  DateTime createdAt;
  DateTime updatedAt;
  String createdByHodId;
  HodTaskWorkStatus workStatus;
  HodTaskReviewStatus reviewStatus;
  List<HodProofType> requiredProofs;
  List<HodTaskProof> submittedProofs;
  List<HodTaskChecklistItem> checklistItems;
  String supervisorNote;
  String hodNote;
  bool alertSentToSupervisor;

  HodTaskRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.assignedSupervisorId,
    required this.assignedSupervisorName,
    required this.siteId,
    required this.siteName,
    required this.thavvuPointId,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByHodId,
    required this.workStatus,
    required this.reviewStatus,
    required this.requiredProofs,
    required this.submittedProofs,
    required this.checklistItems,
    this.supervisorNote = '',
    this.hodNote = '',
    this.alertSentToSupervisor = false,
  });

  bool get isChecklist => kind == HodTaskKind.checklist;
  bool get isSingleTask => kind == HodTaskKind.task;
  bool get isTask => kind == HodTaskKind.task;
  bool get isWorkCompleted => workStatus == HodTaskWorkStatus.completed;
  bool get needsHodReview =>
      reviewStatus == HodTaskReviewStatus.pendingReview ||
      reviewStatus == HodTaskReviewStatus.revisionRequested ||
      reviewStatus == HodTaskReviewStatus.rejected;

  bool get isOverdue {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dueOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueOnly.isBefore(todayOnly) &&
        workStatus != HodTaskWorkStatus.completed &&
        workStatus != HodTaskWorkStatus.cancelled;
  }

  int get completedChecklistItems => checklistItems.where((e) => e.done).length;

  String get proofSummary {
    if (submittedProofs.isEmpty) return 'No proof uploaded';
    return submittedProofs.map((proof) => proof.type.label).join(', ');
  }
}

class HodTaskAuditLog {
  final String id;
  final String taskId;
  final String taskTitle;
  final DateTime date;
  final String action;
  final String actorId;
  final String actorRole;
  final String oldStatus;
  final String newStatus;
  final String note;

  const HodTaskAuditLog({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.date,
    required this.action,
    required this.actorId,
    required this.actorRole,
    required this.oldStatus,
    required this.newStatus,
    required this.note,
  });
}

class HodSupervisorSummary {
  final String id; // profiles.emp_id — what tasks.assigned_supervisor_id stores
  final String profileUuid; // profiles.id
  final String name;
  final String siteName;
  final String thavvuPointId;
  final String siteId;

  const HodSupervisorSummary({
    required this.id,
    this.profileUuid = '',
    required this.name,
    this.siteName = '',
    this.thavvuPointId = '',
    this.siteId = '',
  });
}

// ── Screen ────────────────────────────────────────────────────────────────

class HodTasksScreen extends StatefulWidget {
  final String siteId;
  final String thavvuPointId;
  final String hodId;

  const HodTasksScreen({
    super.key,
    this.siteId = 'SITE-DEMO-001',
    this.thavvuPointId = 'TP-DEMO-001',
    this.hodId = 'HOD-001',
  });

  @override
  State<HodTasksScreen> createState() => _HodTasksScreenState();
}

class _HodTasksScreenState extends State<HodTasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _categoryFilter = 'All';
  String _statusFilter = 'All';
  String _searchQuery = '';
  String _selectedSupervisorFilter = 'All';
  final SupabaseTasksRepository _tasksRepo = SupabaseTasksRepository();

  // Assign task form state
  HodTaskKind _draftKind = HodTaskKind.task;
  HodTaskType _draftType = HodTaskType.daily;
  HodTaskPriority _draftPriority = HodTaskPriority.normal;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _checklistItemsController = TextEditingController();
  final TextEditingController _hodInstructionController = TextEditingController();
  DateTime _draftDueDate = DateTime.now();
  final Set<HodProofType> _draftRequiredProofs = <HodProofType>{
    HodProofType.photo,
  };
  String _draftSupervisorId = '';

  List<HodSupervisorSummary> _supervisors = [];

  /// Loads the tenant's real supervisors (profiles, role=supervisor) and
  /// resolves each one's active Thavvu Point + site for task assignment.
  Future<void> _loadSupervisors() async {
    try {
      final client = Supabase.instance.client;
      final profilesRes = await client
          .from('profiles')
          .select('id, full_name, emp_id')
          .eq('role', 'supervisor')
          .order('full_name');
      final profiles = (profilesRes as List).cast<Map<String, dynamic>>();

      final pointById = <String, Map<String, dynamic>>{};
      try {
        final pointsRes = await client
            .from('thavvu_points')
            .select('id, site_id, point_name')
            .limit(500);
        for (final p in (pointsRes as List).cast<Map<String, dynamic>>()) {
          pointById[p['id']?.toString() ?? ''] = p;
        }
      } catch (_) {
        // Points unavailable — supervisors still list with blank assignment.
      }

      final assignmentsBySupervisor = <String, List<String>>{};
      try {
        final assignsRes = await client
            .from('thavvu_point_assignments')
            .select('supervisor_id, thavvu_point_id')
            .eq('is_active', true)
            .limit(500);
        for (final a in (assignsRes as List).cast<Map<String, dynamic>>()) {
          final sid = a['supervisor_id']?.toString() ?? '';
          final pid = a['thavvu_point_id']?.toString() ?? '';
          if (sid.isEmpty || pid.isEmpty) continue;
          assignmentsBySupervisor
              .putIfAbsent(sid, () => <String>[])
              .add(pid);
        }
      } catch (_) {
        // Assignments unavailable — supervisors still list with no point.
      }

      final list = <HodSupervisorSummary>[];
      for (final p in profiles) {
        final profileUuid = p['id']?.toString() ?? '';
        final empId = p['emp_id']?.toString().trim() ?? '';
        if (empId.isEmpty) continue;
        final pointIds = assignmentsBySupervisor[profileUuid] ?? const [];
        final point = pointIds.isEmpty ? null : pointById[pointIds.first];
        list.add(HodSupervisorSummary(
          id: empId,
          profileUuid: profileUuid,
          name: p['full_name']?.toString().trim() ??
              empId,
          siteName: point?['point_name']?.toString() ?? '',
          thavvuPointId: point?['id']?.toString() ?? '',
          siteId: point?['site_id']?.toString() ?? '',
        ));
      }

      if (!mounted) return;
      setState(() {
        _supervisors = list;
        if (_draftSupervisorId.isEmpty && list.isNotEmpty) {
          _draftSupervisorId = list.first.id;
        }
      });
    } catch (e) {
      debugPrint('_loadSupervisors failed: $e');
    }
  }

  List<HodTaskRecord> _tasks = [];

  final List<HodTaskAuditLog> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadSupervisors();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final fetchedTasks = await _tasksRepo.fetchHodTasks(widget.hodId);
    setState(() {
      _tasks = fetchedTasks;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _checklistItemsController.dispose();
    _hodInstructionController.dispose();
    super.dispose();
  }

  // ── Derived data ─────────────────────────────────────────────────────────

  List<HodTaskRecord> get _visibleRecords {
    return _tasks.where((task) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query) ||
          task.assignedSupervisorName.toLowerCase().contains(query) ||
          task.siteName.toLowerCase().contains(query) ||
          task.thavvuPointId.toLowerCase().contains(query);

      final matchesCategory = _categoryFilter == 'All' ||
          task.type.label == _categoryFilter ||
          task.kind.label == _categoryFilter;

      final matchesStatus = _statusFilter == 'All' ||
          task.workStatus.label == _statusFilter ||
          task.reviewStatus.label == _statusFilter;

      final matchesSupervisor = _selectedSupervisorFilter == 'All' ||
          task.assignedSupervisorId == _selectedSupervisorFilter;

      return matchesSearch && matchesCategory && matchesStatus && matchesSupervisor;
    }).toList();
  }

  List<HodTaskRecord> get _visibleTasksOnly =>
      _visibleRecords.where((task) => task.isTask).toList();

  List<HodTaskRecord> get _visibleChecklistsOnly =>
      _visibleRecords.where((task) => task.isChecklist).toList();

  List<HodTaskRecord> get _reviewQueue => _tasks
      .where((task) => task.reviewStatus == HodTaskReviewStatus.pendingReview || task.reviewStatus == HodTaskReviewStatus.revisionRequested)
      .toList();

  int get _totalCount => _tasks.length;
  int get _completedCount =>
      _tasks.where((task) => task.workStatus == HodTaskWorkStatus.completed).length;
  int get _pendingReviewCount =>
      _tasks.where((task) => task.reviewStatus == HodTaskReviewStatus.pendingReview).length;
  int get _revisionCount =>
      _tasks.where((task) => task.reviewStatus == HodTaskReviewStatus.revisionRequested).length;
  int get _overdueCount => _tasks.where((task) => task.isOverdue).length;

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _formatDateTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '${_formatDate(date)} $h:$min';
  }

  Color _typeColor(HodTaskType type) {
    switch (type) {
      case HodTaskType.daily:
      case HodTaskType.machine:
        return AppTheme.info;
      case HodTaskType.weekly:
      case HodTaskType.stock:
        return AppTheme.success;
      case HodTaskType.monthly:
      case HodTaskType.safety:
        return AppTheme.warning;
      case HodTaskType.attendance:
        return AppTheme.primary;
      case HodTaskType.custom:
        return AppTheme.accent;
    }
  }

  Color _priorityColor(HodTaskPriority priority) {
    switch (priority) {
      case HodTaskPriority.low:
        return AppTheme.textMuted;
      case HodTaskPriority.normal:
        return AppTheme.info;
      case HodTaskPriority.high:
        return AppTheme.warning;
      case HodTaskPriority.urgent:
        return AppTheme.danger;
    }
  }

  Color _workStatusColor(HodTaskWorkStatus status) {
    switch (status) {
      case HodTaskWorkStatus.pending:
        return AppTheme.warning;
      case HodTaskWorkStatus.inProgress:
        return AppTheme.info;
      case HodTaskWorkStatus.completed:
        return AppTheme.success;
      case HodTaskWorkStatus.overdue:
        return AppTheme.danger;
      case HodTaskWorkStatus.cancelled:
        return AppTheme.textMuted;
    }
  }

  Color _reviewStatusColor(HodTaskReviewStatus status) {
    switch (status) {
      case HodTaskReviewStatus.draft:
        return AppTheme.textMuted;
      case HodTaskReviewStatus.pendingReview:
        return AppTheme.warning;
      case HodTaskReviewStatus.approved:
        return AppTheme.success;
      case HodTaskReviewStatus.revisionRequested:
        return AppTheme.info;
      case HodTaskReviewStatus.rejected:
        return AppTheme.danger;
    }
  }

  IconData _proofIcon(HodProofType type) {
    switch (type) {
      case HodProofType.photo:
        return Icons.camera_alt_outlined;
      case HodProofType.video:
        return Icons.videocam_outlined;
      case HodProofType.voiceNote:
        return Icons.mic_none_outlined;
      case HodProofType.textNote:
        return Icons.text_fields_outlined;
      case HodProofType.document:
        return Icons.description_outlined;
      case HodProofType.location:
        return Icons.location_on_outlined;
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Mutations ───────────────────────────────────────────────────────────

  Future<void> _publishTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackbar('Task title is required.', AppTheme.danger);
      return;
    }

    if (_supervisors.isEmpty) {
      _showSnackbar(
        'No supervisors available yet. Create a supervisor account first.',
        AppTheme.danger,
      );
      return;
    }

    final supervisor =
        _supervisors.firstWhere((s) => s.id == _draftSupervisorId);
    final now = DateTime.now();

    List<HodTaskChecklistItem> checklistItems = [];
    if (_draftKind == HodTaskKind.checklist) {
      final text = _checklistItemsController.text.trim();
      if (text.isEmpty) {
        _showSnackbar(
            'At least one checklist item is required.', AppTheme.danger);
        return;
      }
      checklistItems = text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => HodTaskChecklistItem(title: e, done: false))
          .toList();
    }

    final record = HodTaskRecord(
      id: '', // Supabase generated
      kind: _draftKind,
      title: title,
      description: _descriptionController.text.trim(),
      type: _draftType,
      priority: _draftPriority,
      assignedSupervisorId: supervisor.id,
      assignedSupervisorName: supervisor.name,
      siteId: supervisor.siteId,
      siteName: supervisor.siteName,
      thavvuPointId: supervisor.thavvuPointId,
      dueDate: _draftDueDate,
      createdAt: now,
      updatedAt: now,
      createdByHodId: widget.hodId,
      workStatus: HodTaskWorkStatus.pending,
      reviewStatus: HodTaskReviewStatus.draft,
      requiredProofs: _draftRequiredProofs.toList(),
      submittedProofs: const [],
      checklistItems: checklistItems,
      supervisorNote: '',
      hodNote: _hodInstructionController.text.trim(),
      alertSentToSupervisor: true,
    );

    final success = await _tasksRepo.createTask(record);

    if (success) {
      _clearDraft();
      _showSnackbar('Task assigned to ${supervisor.name}.', AppTheme.success);
      _tabController.animateTo(2);
      await _loadTasks(); // Reload tasks from Supabase
    } else {
      _showSnackbar('Failed to assign task.', AppTheme.danger);
    }
  }

  void _clearDraft() {
    _draftKind = HodTaskKind.task;
    _draftType = HodTaskType.daily;
    _draftPriority = HodTaskPriority.normal;
    _draftDueDate = DateTime.now();
    if (_supervisors.isNotEmpty) {
      _draftSupervisorId = _supervisors.first.id;
    }
    _draftRequiredProofs
      ..clear()
      ..add(HodProofType.photo);
    _titleController.clear();
    _descriptionController.clear();
    _checklistItemsController.clear();
    _hodInstructionController.clear();
  }

  void _simulateSupervisorProgress(HodTaskRecord task) {
    setState(() {
      final oldStatus = task.workStatus.label;
      if (task.workStatus == HodTaskWorkStatus.pending) {
        task.workStatus = HodTaskWorkStatus.inProgress;
        task.updatedAt = DateTime.now();
        _addAudit(task, 'Supervisor Started', 'Supervisor', oldStatus,
            task.workStatus.label, 'Mock supervisor progress update.');
      } else if (task.workStatus == HodTaskWorkStatus.inProgress) {
        task.workStatus = HodTaskWorkStatus.completed;
        task.reviewStatus = HodTaskReviewStatus.pendingReview;
        task.updatedAt = DateTime.now();
        task.supervisorNote = task.supervisorNote.isEmpty
            ? 'Work completed and submitted for HOD review.'
            : task.supervisorNote;
        if (task.requiredProofs.isNotEmpty && task.submittedProofs.isEmpty) {
          task.submittedProofs = task.requiredProofs
              .map(
                (proof) => HodTaskProof(
                  id: 'PRF-${DateTime.now().microsecondsSinceEpoch}-${proof.label}',
                  type: proof,
                  fileName: 'mock_${proof.label.toLowerCase().replaceAll(' ', '_')}.jpg',
                  uploadedBy: task.assignedSupervisorId,
                  uploadedAt: DateTime.now(),
                  remarks: 'Mock proof added for frontend verification.',
                ),
              )
              .toList();
        }
        _addAudit(task, 'Supervisor Submitted', 'Supervisor', oldStatus,
            task.reviewStatus.label, 'Submitted with proof for HOD review.');
      }
    });
  }

  void _updateReview(HodTaskRecord task, HodTaskReviewStatus newStatus, String note) {
    final oldStatus = task.reviewStatus.label;
    setState(() {
      task.reviewStatus = newStatus;
      task.hodNote = note.trim().isEmpty ? 'No HOD note added.' : note.trim();
      task.updatedAt = DateTime.now();
      _addAudit(
        task,
        newStatus == HodTaskReviewStatus.approved
            ? 'HOD Approved'
            : newStatus == HodTaskReviewStatus.revisionRequested
                ? 'Revision Requested'
                : 'HOD Rejected',
        'HOD',
        oldStatus,
        newStatus.label,
        task.hodNote,
      );
    });
    _showSnackbar('${task.title} ${newStatus.label.toLowerCase()}.',
        _reviewStatusColor(newStatus));
  }

  void _addAudit(
    HodTaskRecord task,
    String action,
    String actorRole,
    String oldStatus,
    String newStatus,
    String note,
  ) {
    _auditLogs.insert(
      0,
      HodTaskAuditLog(
        id: 'AUD-${DateTime.now().microsecondsSinceEpoch}',
        taskId: task.id,
        taskTitle: task.title,
        date: DateTime.now(),
        action: action,
        actorId: actorRole == 'HOD' ? widget.hodId : task.assignedSupervisorId,
        actorRole: actorRole,
        oldStatus: oldStatus,
        newStatus: newStatus,
        note: note,
      ),
    );
  }

  Future<void> _selectDraftDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draftDueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _draftDueDate = picked);
  }

  void _showReviewSheet(HodTaskRecord task) {
    final noteController = TextEditingController(text: task.hodNote);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSheetTitle(
                      title: 'HOD Review',
                      subtitle: task.title,
                      icon: Icons.verified_user_outlined,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 14),
                    _buildProofSummaryBox(task),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'HOD note / reason',
                        hintText: 'Enter approval note, rejection reason, or revision instruction',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveActions(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateReview(task, HodTaskReviewStatus.rejected,
                                noteController.text);
                          },
                          icon: const Icon(Icons.close_outlined),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: const BorderSide(color: AppTheme.danger),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateReview(task, HodTaskReviewStatus.revisionRequested,
                                noteController.text);
                          },
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Revision'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.warning,
                            side: const BorderSide(color: AppTheme.warning),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateReview(task, HodTaskReviewStatus.approved,
                                noteController.text);
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSearchDialog() {
    final controller = TextEditingController(text: _searchQuery);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Tasks & Checklists'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search title, supervisor, site, or thavvu point',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            setState(() => _searchQuery = value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _searchQuery = controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSheetTitle(
                        title: 'Filter Tasks',
                        subtitle: 'Filter by type, status, and supervisor.',
                        icon: Icons.filter_list,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text('Category', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'All',
                          ...HodTaskKind.values.map((e) => e.label),
                          ...HodTaskType.values.map((e) => e.label),
                        ].map((item) {
                          return _buildSelectableChip(
                            label: item,
                            selected: _categoryFilter == item,
                            color: AppTheme.primary,
                            onTap: () => sheetSetState(() => _categoryFilter = item),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Status', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'All',
                          ...HodTaskWorkStatus.values.map((e) => e.label),
                          ...HodTaskReviewStatus.values.map((e) => e.label),
                        ].map((item) {
                          return _buildSelectableChip(
                            label: item,
                            selected: _statusFilter == item,
                            color: AppTheme.info,
                            onTap: () => sheetSetState(() => _statusFilter = item),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Supervisor', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['All', ..._supervisors.map((e) => e.id)].map((id) {
                          final label = id == 'All'
                              ? 'All'
                              : _supervisors.firstWhere((e) => e.id == id).name;
                          return _buildSelectableChip(
                            label: label,
                            selected: _selectedSupervisorFilter == id,
                            color: AppTheme.success,
                            onTap: () => sheetSetState(() => _selectedSupervisorFilter = id),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Apply Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleTabScaffold(
      title: 'HOD Tasks & Checklist',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.maybePop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _showSearchDialog,
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterSheet,
        ),
      ],
      controller: _tabController,
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Assign'),
        Tab(text: 'Tasks'),
        Tab(text: 'Checklists'),
        Tab(text: 'Review'),
        Tab(text: 'Progress'),
        Tab(text: 'Audit'),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAssignTab(),
          _buildAllTasksTab(),
          _buildChecklistsTab(),
          _buildReviewTab(),
          _buildProgressTab(),
          _buildAuditTab(),
        ],
      ),
    );
  }

  // ── Tabs ────────────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            title: 'HOD Task Dashboard',
            subtitle: 'Assign, monitor, review, and approve supervisor tasks.',
          ),
          const SizedBox(height: 20),
          _buildOverviewStats(),
          const SizedBox(height: 20),
          _buildContextCard(),
          const SizedBox(height: 18),
          _buildSectionTitle('Pending HOD Review', Icons.pending_actions_outlined),
          const SizedBox(height: 12),
          if (_reviewQueue.isEmpty)
            _buildEmptyState('No submitted tasks waiting for HOD review.')
          else
            ..._reviewQueue.take(3).map(_buildTaskReviewCard),
          if (_reviewQueue.length > 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _tabController.animateTo(4),
                icon: const Icon(Icons.arrow_forward),
                label: Text('View all ${_reviewQueue.length} review items'),
              ),
            ),
          const SizedBox(height: 16),
          const NoteBox(
            title: 'Role Separation',
            content:
                'Supervisor completes work and uploads proof. HOD assigns tasks and reviews submitted work without directly changing supervisor proof.',
            icon: Icons.admin_panel_settings_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignTab() {
    final selectedSupervisor = _supervisors.isEmpty
        ? null
        : _supervisors.firstWhere(
            (item) => item.id == _draftSupervisorId,
            orElse: () => _supervisors.first,
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            title: 'Assign Task',
            subtitle: 'Create task or checklist and send it to a supervisor.',
          ),
          const SizedBox(height: 20),
          _buildFormCard(
            title: 'Basic Details',
            icon: Icons.assignment_outlined,
            color: AppTheme.primary,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildOptionCard(
                        title: 'Task',
                        subtitle: 'Single work item',
                        icon: Icons.task_alt_outlined,
                        color: AppTheme.info,
                        selected: _draftKind == HodTaskKind.task,
                        onTap: () => setState(() => _draftKind = HodTaskKind.task),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildOptionCard(
                        title: 'Checklist',
                        subtitle: 'Multiple check points',
                        icon: Icons.checklist_outlined,
                        color: AppTheme.success,
                        selected: _draftKind == HodTaskKind.checklist,
                        onTap: () => setState(() => _draftKind = HodTaskKind.checklist),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task title',
                    hintText: '[TASK_TITLE]',
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Task description',
                    hintText: '[TASK_DESCRIPTION]',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                if (_draftKind == HodTaskKind.checklist) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _checklistItemsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Checklist items',
                      hintText: 'Enter one checklist item per line',
                      prefixIcon: Icon(Icons.format_list_bulleted_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildFormCard(
            title: 'Assignment',
            icon: Icons.engineering_outlined,
            color: AppTheme.info,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _draftSupervisorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assign to supervisor',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: _supervisors.map((supervisor) {
                    return DropdownMenuItem<String>(
                      value: supervisor.id,
                      child: Text('${supervisor.name} • ${supervisor.siteName}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _draftSupervisorId = value);
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip('Site', selectedSupervisor?.siteName ?? '—', AppTheme.info),
                    _buildInfoChip('Thavvu', selectedSupervisor?.thavvuPointId ?? '—', AppTheme.warning),
                    _buildInfoChip('Supervisor ID', selectedSupervisor?.id ?? '—', AppTheme.success),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildFormCard(
            title: 'Type, Priority & Due Date',
            icon: Icons.tune_outlined,
            color: AppTheme.warning,
            child: Column(
              children: [
                DropdownButtonFormField<HodTaskType>(
                  value: _draftType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Task type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: HodTaskType.values.map((type) {
                    return DropdownMenuItem<HodTaskType>(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _draftType = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<HodTaskPriority>(
                  value: _draftPriority,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    prefixIcon: Icon(Icons.priority_high_outlined),
                  ),
                  items: HodTaskPriority.values.map((priority) {
                    return DropdownMenuItem<HodTaskPriority>(
                      value: priority,
                      child: Text(priority.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _draftPriority = value);
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDraftDueDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_formatDate(_draftDueDate)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildFormCard(
            title: 'Proof & HOD Instructions',
            icon: Icons.attach_file_outlined,
            color: AppTheme.success,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Required proof', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: HodProofType.values.map((proof) {
                    final selected = _draftRequiredProofs.contains(proof);
                    return _buildSelectableChip(
                      label: proof.label,
                      selected: selected,
                      color: AppTheme.success,
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _draftRequiredProofs.remove(proof);
                          } else {
                            _draftRequiredProofs.add(proof);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hodInstructionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'HOD instructions / note',
                    hintText: 'Add clear instructions for supervisor',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildResponsiveActions(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(_clearDraft),
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Clear'),
              ),
              ElevatedButton.icon(
                onPressed: _publishTask,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Assign Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllTasksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            title: 'All Tasks',
            subtitle: 'Monitor supervisor task progress and proof status.',
          ),
          const SizedBox(height: 18),
          _buildCategoryChips(),
          const SizedBox(height: 16),
          if (_visibleTasksOnly.isEmpty)
            _buildEmptyState('No tasks found for selected filters.')
          else
            ..._visibleTasksOnly.map(_buildTaskCard),
        ],
      ),
    );
  }

  Widget _buildChecklistsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            title: 'Checklists',
            subtitle: 'Review supervisor checklist progress and submitted proof.',
          ),
          const SizedBox(height: 18),
          _buildCategoryChips(),
          const SizedBox(height: 16),
          if (_visibleChecklistsOnly.isEmpty)
            _buildEmptyState('No checklists found for selected filters.')
          else
            ..._visibleChecklistsOnly.map(_buildTaskCard),
        ],
      ),
    );
  }

  Widget _buildReviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            title: 'Review Queue',
            subtitle: 'Approve, reject, or request revision for supervisor-submitted work.',
          ),
          const SizedBox(height: 18),
          _buildReviewStatusChips(),
          const SizedBox(height: 16),
          if (_reviewQueue.isEmpty)
            _buildEmptyState('No pending review items.')
          else
            ..._reviewQueue.map(_buildTaskReviewCard),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            title: 'Supervisor Progress',
            subtitle: 'Supervisor-wise progress, revision count, and approval quality.',
          ),
          const SizedBox(height: 18),
          ..._supervisors.map(_buildSupervisorProgressCard),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            title: 'Audit Logs',
            subtitle: 'Every assignment and review action is tracked.',
          ),
          const SizedBox(height: 18),
          if (_auditLogs.isEmpty)
            _buildEmptyState('No audit logs available yet.')
          else
            ..._auditLogs.map(_buildAuditCard),
        ],
      ),
    );
  }

  // ── Main UI blocks ──────────────────────────────────────────────────────

  Widget _buildHeader({required String title, required String subtitle}) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.success.withValues(alpha: 0.15),
                AppTheme.success.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('✅', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildStatItem('Total', '$_totalCount', Icons.fact_check_outlined, Colors.white),
          _buildStatItem('Completed', '$_completedCount', Icons.check_circle, Colors.green),
          _buildStatItem('Review', '$_pendingReviewCount', Icons.pending_actions, Colors.orange),
          _buildStatItem('Overdue', '$_overdueCount', Icons.warning_amber, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildContextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSheetTitle(
            title: 'Current HOD Context',
            subtitle: 'This screen is ready to receive real site/point context from HOD navigation.',
            icon: Icons.account_tree_outlined,
            color: AppTheme.info,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip('Site', widget.siteId, AppTheme.info),
              _buildInfoChip('Thavvu', widget.thavvuPointId, AppTheme.warning),
              _buildInfoChip('HOD', widget.hodId, AppTheme.success),
              _buildInfoChip('Revision', '$_revisionCount', AppTheme.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(HodTaskRecord task) {
    final isCompleted = task.workStatus == HodTaskWorkStatus.completed;
    final typeColor = _typeColor(task.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.border,
          width: 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ExpansionTile(
        leading: _buildReadOnlyStatusBox(task),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isCompleted ? AppTheme.textMuted : AppTheme.textPrimary,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildTypeBadge(task.type.label, typeColor),
            _buildInfoBadge(task.kind.label, AppTheme.primary, Icons.layers_outlined),
            _buildPriorityBadge(task.priority),
            _buildDueDateChip(task.dueDate),
            _buildStatusChip(task.workStatus.label, _workStatusColor(task.workStatus)),
            _buildStatusChip(task.reviewStatus.label, _reviewStatusColor(task.reviewStatus)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...task.submittedProofs.take(3).map(
                  (proof) => Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(_proofIcon(proof.type), size: 15, color: AppTheme.info),
                  ),
                ),
            IconButton(
              icon: const Icon(Icons.verified_outlined, size: 20, color: AppTheme.primary),
              onPressed: () => _showReviewSheet(task),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.description,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip('Supervisor', task.assignedSupervisorName, AppTheme.info),
                    _buildInfoChip('Site', task.siteName, AppTheme.warning),
                    _buildInfoChip('Thavvu', task.thavvuPointId, AppTheme.success),
                    _buildInfoChip('Updated', _formatDateTime(task.updatedAt), AppTheme.primary),
                  ],
                ),
              ],
            ),
          ),
          if (task.isChecklist) _buildChecklistProgress(task),
          _buildProofSummaryBox(task),
          if (task.supervisorNote.isNotEmpty)
            _buildNotePreview(
              icon: Icons.engineering_outlined,
              title: 'Supervisor Note',
              note: task.supervisorNote,
              color: AppTheme.info,
            ),
          if (task.hodNote.isNotEmpty)
            _buildNotePreview(
              icon: Icons.admin_panel_settings_outlined,
              title: 'HOD Note',
              note: task.hodNote,
              color: _reviewStatusColor(task.reviewStatus),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildResponsiveActions(
              children: [
                OutlinedButton.icon(
                  onPressed: task.workStatus == HodTaskWorkStatus.pending ||
                          task.workStatus == HodTaskWorkStatus.inProgress
                      ? () => _simulateSupervisorProgress(task)
                      : null,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text(task.workStatus == HodTaskWorkStatus.pending
                      ? 'Mock Start'
                      : 'Mock Submit'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showReviewSheet(task),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('HOD Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskReviewCard(HodTaskRecord task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _reviewStatusColor(task.reviewStatus).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  task.isChecklist ? Icons.checklist_outlined : Icons.task_alt_outlined,
                  color: _reviewStatusColor(task.reviewStatus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${task.assignedSupervisorName} • ${task.siteName} • ${_formatDateTime(task.updatedAt)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(task.reviewStatus.label, _reviewStatusColor(task.reviewStatus)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip('Proof', task.proofSummary, AppTheme.info),
              _buildInfoChip('Work', task.workStatus.label, _workStatusColor(task.workStatus)),
              _buildInfoChip('Due', _formatDate(task.dueDate), AppTheme.warning),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponsiveActions(
            children: [
              OutlinedButton.icon(
                onPressed: () => _updateReview(
                  task,
                  HodTaskReviewStatus.rejected,
                  'Rejected from quick review. Please check full details.',
                ),
                icon: const Icon(Icons.close_outlined),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _updateReview(
                  task,
                  HodTaskReviewStatus.revisionRequested,
                  'Please resubmit with corrected proof.',
                ),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Revision'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warning,
                  side: const BorderSide(color: AppTheme.warning),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showReviewSheet(task),
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Open'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorProgressCard(HodSupervisorSummary supervisor) {
    final related = _tasks.where((task) => task.assignedSupervisorId == supervisor.id).toList();
    final total = related.length;
    final completed = related.where((task) => task.workStatus == HodTaskWorkStatus.completed).length;
    final approved = related.where((task) => task.reviewStatus == HodTaskReviewStatus.approved).length;
    final revision = related.where((task) => task.reviewStatus == HodTaskReviewStatus.revisionRequested).length;
    final overdue = related.where((task) => task.isOverdue).length;
    final approvalRate = total == 0 ? 0 : ((approved / total) * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.engineering_outlined, color: AppTheme.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supervisor.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${supervisor.siteName} • ${supervisor.thavvuPointId}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              _buildStatusChip('$approvalRate%', AppTheme.success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMiniMetric('Assigned', '$total', AppTheme.primary)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniMetric('Completed', '$completed', AppTheme.success)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniMetric('Revision', '$revision', AppTheme.warning)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniMetric('Overdue', '$overdue', AppTheme.danger)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard(HodTaskAuditLog log) {
    final color = log.newStatus.toLowerCase().contains('approved')
        ? AppTheme.success
        : log.newStatus.toLowerCase().contains('reject')
            ? AppTheme.danger
            : log.newStatus.toLowerCase().contains('revision')
                ? AppTheme.info
                : AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.history_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.taskTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    _buildStatusChip(log.newStatus, color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${log.action} by ${log.actorRole} ${log.actorId} • ${_formatDateTime(log.date)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  log.note,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable UI helpers ─────────────────────────────────────────────────

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSheetTitle(title: title, subtitle: '', icon: icon, color: color),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      'All',
      'Task',
      'Checklist',
      'Daily',
      'Weekly',
      'Monthly',
      'Safety',
      'Machine',
      'Stock',
      'Attendance',
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = _categoryFilter == category;
          return GestureDetector(
            onTap: () => setState(() => _categoryFilter = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(colors: [AppTheme.primary, AppTheme.accent])
                    : null,
                color: selected ? null : AppTheme.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.border,
                  width: selected ? 0 : 0.8,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewStatusChips() {
    final filters = [
      'All',
      HodTaskReviewStatus.pendingReview.label,
      HodTaskReviewStatus.revisionRequested.label,
      HodTaskReviewStatus.rejected.label,
      HodTaskReviewStatus.approved.label,
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final count = filter == 'All'
              ? _tasks.length
              : _tasks.where((task) => task.reviewStatus.label == filter).length;
          final selected = _statusFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _statusFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(colors: [AppTheme.primary, AppTheme.accent])
                    : null,
                color: selected ? null : AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: 0.2) : AppTheme.infoBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : AppTheme.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadOnlyStatusBox(HodTaskRecord task) {
    final isDone = task.workStatus == HodTaskWorkStatus.completed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: isDone
            ? const LinearGradient(colors: [AppTheme.success, AppTheme.successLight])
            : null,
        color: isDone ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone ? AppTheme.success : AppTheme.border,
          width: 1.5,
        ),
      ),
      child: isDone
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : Icon(
              task.isChecklist ? Icons.checklist_outlined : Icons.task_alt_outlined,
              size: 16,
              color: AppTheme.textMuted,
            ),
    );
  }

  Widget _buildChecklistProgress(HodTaskRecord task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_outlined, size: 18, color: AppTheme.success),
              const SizedBox(width: 8),
              Text(
                'Checklist Progress: ${task.completedChecklistItems}/${task.checklistItems.length}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...task.checklistItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 17,
                    color: item.done ? AppTheme.success : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: item.done ? AppTheme.textSecondary : AppTheme.textPrimary,
                        decoration: item.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProofSummaryBox(HodTaskRecord task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proof Review',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.info),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: task.requiredProofs.map((requiredProof) {
              final hasProof = task.submittedProofs.any((proof) => proof.type == requiredProof);
              return _buildProofPill(requiredProof, hasProof);
            }).toList(),
          ),
          if (task.submittedProofs.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...task.submittedProofs.map((proof) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(_proofIcon(proof.type), size: 16, color: AppTheme.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${proof.fileName} • ${_formatDateTime(proof.uploadedAt)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildProofPill(HodProofType type, bool available) {
    final color = available ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_proofIcon(type), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '${type.label} ${available ? '✓' : 'Pending'}',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildNotePreview({
    required IconData icon,
    required String title,
    required String note,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(note, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppTheme.textMuted, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? color : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.4 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String label, Color color) {
    return _buildInfoBadge(label, color, Icons.category_outlined);
  }

  Widget _buildInfoBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(HodTaskPriority priority) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final isUrgent = dateOnly == today || dateOnly.isBefore(today);
    final color = isUrgent ? AppTheme.warning : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            _formatDate(dueDate),
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
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

  Widget _buildSheetTitle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveActions({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children) ...[
                SizedBox(width: double.infinity, child: child),
                const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}
