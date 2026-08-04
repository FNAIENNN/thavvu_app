import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hod_site_workspace_service.dart';
import '../theme/app_theme.dart';
import '../widgets/collapsible_tab_scaffold.dart';
import '../services/supabase_tasks_repository.dart';

enum SupervisorTaskMode { single, multiChecklist }

enum SupervisorTaskStatus {
  pending,
  inProgress,
  completed,
  submitted,
  revisionRequested,
  approved,
}

extension SupervisorTaskStatusX on SupervisorTaskStatus {
  String get label {
    switch (this) {
      case SupervisorTaskStatus.pending:
        return 'Pending';
      case SupervisorTaskStatus.inProgress:
        return 'In Progress';
      case SupervisorTaskStatus.completed:
        return 'Completed';
      case SupervisorTaskStatus.submitted:
        return 'Submitted';
      case SupervisorTaskStatus.revisionRequested:
        return 'Revision';
      case SupervisorTaskStatus.approved:
        return 'Approved';
    }
  }

  IconData get icon {
    switch (this) {
      case SupervisorTaskStatus.pending:
        return Icons.pending_actions_outlined;
      case SupervisorTaskStatus.inProgress:
        return Icons.timelapse_outlined;
      case SupervisorTaskStatus.completed:
        return Icons.task_alt_outlined;
      case SupervisorTaskStatus.submitted:
        return Icons.outbox_outlined;
      case SupervisorTaskStatus.revisionRequested:
        return Icons.rate_review_outlined;
      case SupervisorTaskStatus.approved:
        return Icons.verified_outlined;
    }
  }
}

class TaskProofRequirement {
  final bool photoRequired;
  final bool videoRequired;
  final bool locationRequired;
  final bool noteRequired;

  const TaskProofRequirement({
    this.photoRequired = false,
    this.videoRequired = false,
    this.locationRequired = false,
    this.noteRequired = false,
  });

  bool get hasAny =>
      photoRequired || videoRequired || locationRequired || noteRequired;

  int get requiredCount {
    var count = 0;
    if (photoRequired) count++;
    if (videoRequired) count++;
    if (locationRequired) count++;
    if (noteRequired) count++;
    return count;
  }

  List<String> get labels {
    return [
      if (photoRequired) 'Photo',
      if (videoRequired) 'Video',
      if (locationRequired) 'Location',
      if (noteRequired) 'Note',
    ];
  }
}

class TaskLocationProof {
  final String label;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  const TaskLocationProof({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  String get displayCoordinates =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

class TaskProofBundle {
  String? photoPath;
  String? videoPath;
  TaskLocationProof? location;
  String note;
  DateTime? updatedAt;

  TaskProofBundle({
    this.photoPath,
    this.videoPath,
    this.location,
    this.note = '',
    this.updatedAt,
  });

  bool hasPhoto() => photoPath != null && photoPath!.trim().isNotEmpty;

  bool hasVideo() => videoPath != null && videoPath!.trim().isNotEmpty;

  bool hasLocation() => location != null;

  bool hasNote() => note.trim().isNotEmpty;

  int uploadedCount() {
    var count = 0;
    if (hasPhoto()) count++;
    if (hasVideo()) count++;
    if (hasLocation()) count++;
    if (hasNote()) count++;
    return count;
  }

  bool satisfies(TaskProofRequirement requirement) {
    if (requirement.photoRequired && !hasPhoto()) return false;
    if (requirement.videoRequired && !hasVideo()) return false;
    if (requirement.locationRequired && !hasLocation()) return false;
    if (requirement.noteRequired && !hasNote()) return false;
    return true;
  }
}

class SupervisorChecklistStep {
  final String id;
  final String title;
  final String instruction;
  final TaskProofRequirement proofRequirement;
  bool done;
  final TaskProofBundle proof;

  SupervisorChecklistStep({
    required this.id,
    required this.title,
    required this.instruction,
    this.proofRequirement = const TaskProofRequirement(),
    this.done = false,
    TaskProofBundle? proof,
  }) : proof = proof ?? TaskProofBundle();

  bool get isReadyForSubmit => done && proof.satisfies(proofRequirement);
}

class SupervisorHodTask {
  final String id;
  final String title;
  final String description;
  final SupervisorTaskMode mode;
  final String type;
  final String priority;
  final String dueDate;
  final DateTime assignedAt;
  final String assignedBy;
  final String siteName;
  final String thavvuId;
  final String tankId;
  final String locationHint;
  final TaskProofRequirement proofRequirement;
  final TaskProofBundle proof;
  final List<SupervisorChecklistStep> steps;
  SupervisorTaskStatus status;
  String hodNote;
  DateTime? submittedAt;

  SupervisorHodTask({
    required this.id,
    required this.title,
    required this.description,
    required this.mode,
    required this.type,
    required this.priority,
    required this.dueDate,
    required this.assignedAt,
    required this.assignedBy,
    required this.siteName,
    required this.thavvuId,
    required this.tankId,
    this.locationHint = '',
    this.proofRequirement = const TaskProofRequirement(),
    TaskProofBundle? proof,
    List<SupervisorChecklistStep>? steps,
    this.status = SupervisorTaskStatus.pending,
    this.hodNote = '',
    this.submittedAt,
  })  : proof = proof ?? TaskProofBundle(),
        steps = steps ?? [];

  bool get isHighPriority => priority.toLowerCase() == 'high';

  bool get isSingleTask => mode == SupervisorTaskMode.single;

  bool get allStepsDone =>
      steps.isNotEmpty && steps.every((step) => step.done == true);

  bool get allStepProofsReady =>
      steps.isNotEmpty &&
      steps.every((step) => step.proof.satisfies(step.proofRequirement));

  bool get isWorkMarkedDone => isSingleTask
      ? status == SupervisorTaskStatus.completed ||
          status == SupervisorTaskStatus.submitted ||
          status == SupervisorTaskStatus.approved
      : allStepsDone;

  bool get isReadyForSubmit {
    if (status == SupervisorTaskStatus.submitted ||
        status == SupervisorTaskStatus.approved) {
      return false;
    }
    if (isSingleTask) {
      return isWorkMarkedDone && proof.satisfies(proofRequirement);
    }
    return allStepsDone && allStepProofsReady;
  }

  int get completedStepCount => steps.where((step) => step.done).length;

  int get totalStepCount => steps.length;

  double get progress {
    if (isSingleTask) {
      return isWorkMarkedDone ? 1 : 0;
    }
    if (steps.isEmpty) return 0;
    return completedStepCount / steps.length;
  }
}

class TaskSubmissionRecord {
  final String id;
  final String taskId;
  final String taskTitle;
  final String modeLabel;
  final DateTime submittedAt;
  final String submittedBy;
  final int completedItems;
  final int totalItems;
  final int proofCount;
  final String status;

  const TaskSubmissionRecord({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.modeLabel,
    required this.submittedAt,
    required this.submittedBy,
    required this.completedItems,
    required this.totalItems,
    required this.proofCount,
    required this.status,
  });
}

class TasksScreen extends StatefulWidget {
  final bool isHOD;

  const TasksScreen({
    super.key,
    this.isHOD = false,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _filter = 'All';
  String _searchQuery = '';
  bool _showOnlyPendingProof = false;

  final List<SupervisorHodTask> _tasks = [];
  final List<TaskSubmissionRecord> _submissionHistory = [];
  final SupabaseTasksRepository _tasksRepo = SupabaseTasksRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final records = await _tasksRepo.fetchSupervisorTasks('SUP-VJA-001');
    setState(() {
      _tasks.clear();
      _tasks.addAll(records);
    });
  }

  List<SupervisorHodTask> get _singleTasks => _tasks
      .where((task) => task.mode == SupervisorTaskMode.single)
      .where(_matchesSearchAndFilter)
      .toList();

  List<SupervisorHodTask> get _multiTasks => _tasks
      .where((task) => task.mode == SupervisorTaskMode.multiChecklist)
      .where(_matchesSearchAndFilter)
      .toList();

  List<SupervisorHodTask> get _allVisibleTasks =>
      _tasks.where(_matchesSearchAndFilter).toList();

  List<SupervisorHodTask> get _submittedTasks => _tasks
      .where((task) =>
          task.status == SupervisorTaskStatus.submitted ||
          task.status == SupervisorTaskStatus.approved ||
          task.status == SupervisorTaskStatus.revisionRequested)
      .where(_matchesSearchAndFilter)
      .toList();

  bool _matchesSearchAndFilter(SupervisorHodTask task) {
    final matchesFilter = _filter == 'All' ||
        task.type == _filter ||
        (_filter == 'High' && task.isHighPriority) ||
        (_filter == 'Pending' &&
            task.status != SupervisorTaskStatus.submitted &&
            task.status != SupervisorTaskStatus.approved);

    final raw = _searchQuery.trim().toLowerCase();
    final matchesSearch = raw.isEmpty ||
        task.title.toLowerCase().contains(raw) ||
        task.id.toLowerCase().contains(raw) ||
        task.assignedBy.toLowerCase().contains(raw) ||
        task.siteName.toLowerCase().contains(raw) ||
        task.thavvuId.toLowerCase().contains(raw) ||
        task.steps.any((step) => step.title.toLowerCase().contains(raw));

    final matchesProof =
        !_showOnlyPendingProof || !_allRequiredProofReady(task);

    return matchesFilter && matchesSearch && matchesProof;
  }

  int get _totalTasks => _tasks.length;

  int get _completedTasks => _tasks
      .where((task) =>
          task.status == SupervisorTaskStatus.completed ||
          task.status == SupervisorTaskStatus.submitted ||
          task.status == SupervisorTaskStatus.approved)
      .length;

  int get _submittedCount => _tasks
      .where((task) => task.status == SupervisorTaskStatus.submitted)
      .length;

  int get _pendingProofCount =>
      _tasks.where((task) => !_allRequiredProofReady(task)).length;

  bool _allRequiredProofReady(SupervisorHodTask task) {
    if (task.isSingleTask) {
      return task.proof.satisfies(task.proofRequirement);
    }
    return task.steps.every(
      (step) => step.proof.satisfies(step.proofRequirement),
    );
  }

  void _toggleSingleTaskDone(SupervisorHodTask task) {
    setState(() {
      if (task.status == SupervisorTaskStatus.submitted ||
          task.status == SupervisorTaskStatus.approved) {
        return;
      }
      final currentlyDone = task.status == SupervisorTaskStatus.completed;
      task.status = currentlyDone
          ? SupervisorTaskStatus.inProgress
          : SupervisorTaskStatus.completed;
    });

    _showSnackbar(
      task.status == SupervisorTaskStatus.completed
          ? 'Single task marked as completed.'
          : 'Single task moved back to pending.',
      task.status == SupervisorTaskStatus.completed
          ? AppTheme.success
          : AppTheme.warning,
    );
  }

  void _toggleChecklistStep(
    SupervisorHodTask task,
    SupervisorChecklistStep step,
  ) {
    if (task.status == SupervisorTaskStatus.submitted ||
        task.status == SupervisorTaskStatus.approved) {
      _showSnackbar('Submitted task cannot be edited.', AppTheme.warning);
      return;
    }

    setState(() {
      step.done = !step.done;
      if (task.steps.any((item) => item.done)) {
        task.status = SupervisorTaskStatus.inProgress;
      }
      if (task.steps.every((item) => item.done)) {
        task.status = SupervisorTaskStatus.completed;
      }
      if (task.steps.every((item) => !item.done)) {
        task.status = SupervisorTaskStatus.pending;
      }
    });

    _showSnackbar(
      step.done ? '${step.title} checked.' : '${step.title} unchecked.',
      step.done ? AppTheme.success : AppTheme.warning,
    );
  }

  void _submitTaskForReview(SupervisorHodTask task) {
    if (task.status == SupervisorTaskStatus.submitted) {
      _showSnackbar('This task is already submitted to HOD.', AppTheme.info);
      return;
    }

    if (task.status == SupervisorTaskStatus.approved) {
      _showSnackbar('This task is already approved.', AppTheme.success);
      return;
    }

    if (!task.isWorkMarkedDone) {
      _showSnackbar(
        task.isSingleTask
            ? 'Mark the whole task as completed before submitting.'
            : 'Check every checklist item separately before submitting.',
        AppTheme.warning,
      );
      return;
    }

    if (!_allRequiredProofReady(task)) {
      _showSnackbar(
        'Required proof is missing. Upload proof as assigned by HOD.',
        AppTheme.danger,
      );
      return;
    }

    final now = DateTime.now();

    setState(() {
      task.status = SupervisorTaskStatus.submitted;
      task.submittedAt = now;

      _submissionHistory.insert(
        0,
        TaskSubmissionRecord(
          id: 'SUB-${now.millisecondsSinceEpoch}',
          taskId: task.id,
          taskTitle: task.title,
          modeLabel: task.isSingleTask ? 'Single Task' : 'Multi Checklist',
          submittedAt: now,
          submittedBy: 'Supervisor',
          completedItems: task.isSingleTask ? 1 : task.completedStepCount,
          totalItems: task.isSingleTask ? 1 : task.totalStepCount,
          proofCount: task.isSingleTask
              ? task.proof.uploadedCount()
              : task.steps.fold<int>(
                  0,
                  (sum, step) => sum + step.proof.uploadedCount(),
                ),
          status: 'Submitted to HOD',
        ),
      );
    });

    unawaited(
      HodSiteWorkspaceService().recordSupervisorActivityForCurrentSession(
        module: 'Tasks',
        action: 'Task submitted to HOD',
        details:
            '${task.title} submitted with ${task.isSingleTask ? 1 : task.completedStepCount}/${task.isSingleTask ? 1 : task.totalStepCount} items complete.',
      ),
    );
    _showSnackbar('Submitted to HOD for review.', AppTheme.success);
  }

  void _showProofSheet({
    required SupervisorHodTask task,
    SupervisorChecklistStep? step,
  }) {
    final isStepProof = step != null;
    final title = isStepProof ? step.title : task.title;
    final requirement =
        isStepProof ? step.proofRequirement : task.proofRequirement;
    final proof = isStepProof ? step.proof : task.proof;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refreshAll() {
              setState(() {});
              setSheetState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isStepProof
                                      ? 'Upload Step Proof'
                                      : 'Upload Task Proof',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRequirementBanner(requirement),
                      if (task.locationHint.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildHintBox(
                          icon: Icons.location_on_outlined,
                          text: 'HOD location hint: ${task.locationHint}',
                          color: AppTheme.info,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildUploadActionTile(
                        label: proof.hasPhoto()
                            ? 'Photo uploaded'
                            : 'Upload Photo',
                        value: proof.photoPath ?? 'Required only if HOD asked',
                        icon: proof.hasPhoto()
                            ? Icons.check_circle_outline
                            : Icons.camera_alt_outlined,
                        color: AppTheme.info,
                        isRequired: requirement.photoRequired,
                        onTap: () {
                          proof.photoPath =
                              'photo_${task.id}_${step?.id ?? 'single'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          proof.updatedAt = DateTime.now();
                          refreshAll();
                          _showSnackbar('Photo proof attached.', AppTheme.info);
                        },
                        onClear: proof.hasPhoto()
                            ? () {
                                proof.photoPath = null;
                                proof.updatedAt = DateTime.now();
                                refreshAll();
                              }
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _buildUploadActionTile(
                        label: proof.hasVideo()
                            ? 'Video uploaded'
                            : 'Upload Video',
                        value: proof.videoPath ?? 'Required only if HOD asked',
                        icon: proof.hasVideo()
                            ? Icons.check_circle_outline
                            : Icons.videocam_outlined,
                        color: AppTheme.danger,
                        isRequired: requirement.videoRequired,
                        onTap: () {
                          proof.videoPath =
                              'video_${task.id}_${step?.id ?? 'single'}_${DateTime.now().millisecondsSinceEpoch}.mp4';
                          proof.updatedAt = DateTime.now();
                          refreshAll();
                          _showSnackbar(
                              'Video proof attached.', AppTheme.danger);
                        },
                        onClear: proof.hasVideo()
                            ? () {
                                proof.videoPath = null;
                                proof.updatedAt = DateTime.now();
                                refreshAll();
                              }
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _buildUploadActionTile(
                        label: proof.hasLocation()
                            ? 'Location captured'
                            : 'Add Location',
                        value: proof.location?.displayCoordinates ??
                            'Required only if HOD asked',
                        icon: proof.hasLocation()
                            ? Icons.check_circle_outline
                            : Icons.my_location_outlined,
                        color: AppTheme.success,
                        isRequired: requirement.locationRequired,
                        onTap: () => _showLocationDialog(
                          proof: proof,
                          defaultLabel: task.locationHint.isEmpty
                              ? task.siteName
                              : task.locationHint,
                          afterSave: refreshAll,
                        ),
                        onClear: proof.hasLocation()
                            ? () {
                                proof.location = null;
                                proof.updatedAt = DateTime.now();
                                refreshAll();
                              }
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _buildUploadActionTile(
                        label: proof.hasNote() ? 'Note added' : 'Add Note',
                        value: proof.hasNote()
                            ? proof.note
                            : 'Required only if HOD asked',
                        icon: proof.hasNote()
                            ? Icons.check_circle_outline
                            : Icons.sticky_note_2_outlined,
                        color: AppTheme.warning,
                        isRequired: requirement.noteRequired,
                        onTap: () => _showProofNoteDialog(
                          proof: proof,
                          afterSave: refreshAll,
                        ),
                        onClear: proof.hasNote()
                            ? () {
                                proof.note = '';
                                proof.updatedAt = DateTime.now();
                                refreshAll();
                              }
                            : null,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.done_all),
                          label: Text(
                            proof.satisfies(requirement)
                                ? 'Proof Ready'
                                : 'Save Proof Draft',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: proof.satisfies(requirement)
                                ? AppTheme.success
                                : AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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

  void _showLocationDialog({
    required TaskProofBundle proof,
    required String defaultLabel,
    required VoidCallback afterSave,
  }) {
    final labelController = TextEditingController(text: defaultLabel);
    final latController = TextEditingController(text: '16.54490');
    final lngController = TextEditingController(text: '81.52120');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Capture Location Proof'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Location / Place Name',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    prefixIcon: Icon(Icons.explore_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    prefixIcon: Icon(Icons.explore),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is ready for GPS/API integration. Currently it stores manual/mock location proof.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                labelController.dispose();
                latController.dispose();
                lngController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final lat = double.tryParse(latController.text.trim());
                final lng = double.tryParse(lngController.text.trim());
                if (lat == null || lng == null) {
                  _showSnackbar(
                      'Enter valid latitude and longitude.', AppTheme.danger);
                  return;
                }

                proof.location = TaskLocationProof(
                  label: labelController.text.trim().isEmpty
                      ? 'Task location'
                      : labelController.text.trim(),
                  latitude: lat,
                  longitude: lng,
                  capturedAt: DateTime.now(),
                );
                proof.updatedAt = DateTime.now();

                labelController.dispose();
                latController.dispose();
                lngController.dispose();

                Navigator.pop(context);
                afterSave();
                _showSnackbar('Location proof saved.', AppTheme.success);
              },
              child: const Text('Save Location'),
            ),
          ],
        );
      },
    );
  }

  void _showProofNoteDialog({
    required TaskProofBundle proof,
    required VoidCallback afterSave,
  }) {
    final controller = TextEditingController(text: proof.note);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Supervisor Note'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'Write completion note, issue, reading, or observation...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                proof.note = controller.text.trim();
                proof.updatedAt = DateTime.now();
                controller.dispose();
                Navigator.pop(context);
                afterSave();
                _showSnackbar('Note saved successfully.', AppTheme.success);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showSearchDialog() {
    final controller = TextEditingController(text: _searchQuery);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search Tasks'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search by task, HOD, site, Thavvu ID...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              setState(() => _searchQuery = value.trim());
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _searchQuery = '');
                controller.dispose();
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _searchQuery = controller.text.trim());
                controller.dispose();
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    final filters = ['All', 'Daily', 'Weekly', 'Monthly', 'High', 'Pending'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Filter Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: filters.map((filter) {
                    final selected = _filter == filter;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(filter),
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      side: BorderSide(
                        color: selected ? AppTheme.primary : AppTheme.border,
                      ),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        setState(() => _filter = filter);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showOnlyPendingProof,
                  activeColor: AppTheme.warning,
                  title: const Text(
                    'Show only pending proof',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Tasks where photo, video, location, or note proof is missing.',
                  ),
                  onChanged: (value) {
                    setState(() => _showOnlyPendingProof = value);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackbar(String message, Color color) {
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

  String _formatDateTime(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  Color _statusColor(SupervisorTaskStatus status) {
    switch (status) {
      case SupervisorTaskStatus.pending:
        return AppTheme.textMuted;
      case SupervisorTaskStatus.inProgress:
        return AppTheme.info;
      case SupervisorTaskStatus.completed:
        return AppTheme.success;
      case SupervisorTaskStatus.submitted:
        return AppTheme.primary;
      case SupervisorTaskStatus.revisionRequested:
        return AppTheme.warning;
      case SupervisorTaskStatus.approved:
        return AppTheme.success;
    }
  }

  Color _priorityColor(String priority) {
    return priority.toLowerCase() == 'high' ? AppTheme.danger : AppTheme.info;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: 'Tasks & Checklist',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _showSearchDialog,
                tooltip: 'Search',
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterDialog,
                tooltip: 'Filter',
              ),
            ],
            controller: _tabController,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Single Tasks'),
              Tab(text: 'Multi Checklist'),
              Tab(text: 'Submitted'),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildSingleTasksTab(),
            _buildMultiTasksTab(),
            _buildSubmittedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final visible = _allVisibleTasks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildOverallStats(),
          const SizedBox(height: 18),
          _buildCategoryTabs(),
          if (_searchQuery.trim().isNotEmpty || _showOnlyPendingProof) ...[
            const SizedBox(height: 12),
            _buildActiveFilterBanner(),
          ],
          const SizedBox(height: 18),
          _buildSectionTitle(
            title: 'HOD Assigned Work',
            subtitle: '${visible.length} task(s) matching current filter',
            icon: Icons.assignment_outlined,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            _buildEmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No tasks found',
              subtitle: 'Try clearing search or changing filter.',
            )
          else
            ...visible.take(4).map(_buildCompactOverviewCard),
          const SizedBox(height: 16),
          _buildGuidanceNote(),
        ],
      ),
    );
  }

  Widget _buildSingleTasksTab() {
    final tasks = _singleTasks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildSingleTaskStats(),
          const SizedBox(height: 18),
          _buildCategoryTabs(),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            _buildEmptyState(
              icon: Icons.task_alt,
              title: 'No single tasks available',
              subtitle: 'Single tasks from HOD will appear here.',
            )
          else
            ...tasks.map(_buildSingleTaskCard),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildMultiTasksTab() {
    final tasks = _multiTasks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildMultiTaskStats(),
          const SizedBox(height: 18),
          _buildCategoryTabs(),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            _buildEmptyState(
              icon: Icons.checklist_outlined,
              title: 'No multi checklists available',
              subtitle: 'HOD multi-task checklists will appear here.',
            )
          else
            ...tasks.map(_buildMultiChecklistCard),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildSubmittedTab() {
    final submitted = _submittedTasks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildSubmittedStats(),
          const SizedBox(height: 18),
          if (submitted.isEmpty && _submissionHistory.isEmpty)
            _buildEmptyState(
              icon: Icons.outbox_outlined,
              title: 'No submitted tasks yet',
              subtitle:
                  'Completed tasks will appear here after sending to HOD review.',
            )
          else ...[
            if (submitted.isNotEmpty) ...[
              _buildSectionTitle(
                title: 'Current Review Queue',
                subtitle: 'Tasks currently waiting for HOD action',
                icon: Icons.rate_review_outlined,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 12),
              ...submitted.map(_buildSubmittedTaskCard),
              const SizedBox(height: 18),
            ],
            if (_submissionHistory.isNotEmpty) ...[
              _buildSectionTitle(
                title: 'Submission History',
                subtitle: 'Local proof submission records',
                icon: Icons.history,
                color: AppTheme.info,
              ),
              const SizedBox(height: 12),
              ..._submissionHistory.map(_buildSubmissionHistoryCard),
            ],
          ],
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tasks & Checklist',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'HOD-assigned work with proof tracking',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStats() {
    return _buildGradientStatsCard(
      children: [
        _buildStatItem(
            'Total', '$_totalTasks', Icons.assignment_outlined, Colors.white),
        _buildStatItem(
            'Done', '$_completedTasks', Icons.check_circle, Colors.green),
        _buildStatItem(
            'Review', '$_submittedCount', Icons.outbox_outlined, Colors.orange),
        _buildStatItem(
            'Proof', '$_pendingProofCount', Icons.upload_file, Colors.cyan),
      ],
    );
  }

  Widget _buildSingleTaskStats() {
    final total = _singleTasks.length;
    final completed = _singleTasks
        .where((task) =>
            task.status == SupervisorTaskStatus.completed ||
            task.status == SupervisorTaskStatus.submitted ||
            task.status == SupervisorTaskStatus.approved)
        .length;
    final proofReady = _singleTasks
        .where((task) => task.proof.satisfies(task.proofRequirement))
        .length;

    return _buildGradientStatsCard(
      children: [
        _buildStatItem('Single', '$total', Icons.task_alt, Colors.white),
        _buildStatItem('Done', '$completed', Icons.check_circle, Colors.green),
        _buildStatItem(
            'Proof Ready', '$proofReady', Icons.verified_outlined, Colors.cyan),
      ],
    );
  }

  Widget _buildMultiTaskStats() {
    final total = _multiTasks.length;
    final totalSteps =
        _multiTasks.fold<int>(0, (sum, task) => sum + task.totalStepCount);
    final doneSteps =
        _multiTasks.fold<int>(0, (sum, task) => sum + task.completedStepCount);

    return _buildGradientStatsCard(
      children: [
        _buildStatItem('Checklists', '$total', Icons.checklist, Colors.white),
        _buildStatItem(
            'Steps', '$totalSteps', Icons.list_alt_outlined, Colors.cyan),
        _buildStatItem(
            'Checked', '$doneSteps', Icons.check_circle, Colors.green),
      ],
    );
  }

  Widget _buildSubmittedStats() {
    return _buildGradientStatsCard(
      children: [
        _buildStatItem(
            'Submitted', '$_submittedCount', Icons.outbox, Colors.white),
        _buildStatItem('History', '${_submissionHistory.length}', Icons.history,
            Colors.cyan),
        _buildStatItem(
            'Approved',
            '${_tasks.where((task) => task.status == SupervisorTaskStatus.approved).length}',
            Icons.verified,
            Colors.green),
      ],
    );
  }

  Widget _buildGradientStatsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: children),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = ['All', 'Daily', 'Weekly', 'Monthly', 'High', 'Pending'];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _filter == category;
          return GestureDetector(
            onTap: () => setState(() => _filter = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                      )
                    : null,
                color: isSelected ? null : AppTheme.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: isSelected ? 0 : 0.8,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveFilterBanner() {
    final chips = <String>[
      if (_searchQuery.trim().isNotEmpty) 'Search: $_searchQuery',
      if (_showOnlyPendingProof) 'Pending proof only',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...chips.map(
            (chip) => _buildInfoPill(chip, AppTheme.info, Icons.filter_alt),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _searchQuery = '';
              _showOnlyPendingProof = false;
            }),
            child:
                _buildInfoPill('Clear filters', AppTheme.danger, Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOverviewCard(SupervisorHodTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          _buildCircularProgress(task),
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
                  '${task.assignedBy} • ${task.type} • ${task.dueDate}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildStatusChip(task.status),
                    _buildModeChip(task),
                    if (!_allRequiredProofReady(task))
                      _buildMiniChip(
                        'Proof Pending',
                        AppTheme.warning,
                        Icons.warning_amber_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _tabController.animateTo(task.isSingleTask ? 1 : 2);
            },
            icon: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTaskCard(SupervisorHodTask task) {
    final ready = task.isReadyForSubmit;
    final isSubmitted = task.status == SupervisorTaskStatus.submitted ||
        task.status == SupervisorTaskStatus.approved;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: task.status == SupervisorTaskStatus.completed ||
                  task.status == SupervisorTaskStatus.submitted ||
                  task.status == SupervisorTaskStatus.approved
              ? AppTheme.success.withValues(alpha: 0.30)
              : AppTheme.border,
          width: 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: GestureDetector(
          onTap: () => _toggleSingleTaskDone(task),
          child: _buildCheckBox(
            checked: task.isWorkMarkedDone,
            enabled: !isSubmitted,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: task.isWorkMarkedDone
                ? AppTheme.textMuted
                : AppTheme.textPrimary,
            decoration:
                task.isWorkMarkedDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              _buildTypeBadge(task.type),
              _buildPriorityBadge(task.priority),
              _buildDueDateChip(task.dueDate),
              _buildAssignedByChip(task.assignedBy),
            ],
          ),
        ),
        trailing: _buildProofIconCluster(task.proof, task.proofRequirement),
        children: [
          _buildTaskMetaPanel(task),
          const SizedBox(height: 12),
          _buildHodInstructionBox(task),
          const SizedBox(height: 12),
          _buildProofRequirementRow(task.proofRequirement),
          const SizedBox(height: 12),
          _buildProofStatusPanel(
            requirement: task.proofRequirement,
            proof: task.proof,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isSubmitted ? null : () => _showProofSheet(task: task),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload Proof'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: ready ? () => _submitTaskForReview(task) : null,
                  icon: Icon(
                    ready ? Icons.outbox_outlined : Icons.lock_outline,
                    size: 18,
                  ),
                  label: Text(ready ? 'Submit' : 'Locked'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.textMuted.withValues(alpha: 0.18),
                    disabledForegroundColor: AppTheme.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiChecklistCard(SupervisorHodTask task) {
    final ready = task.isReadyForSubmit;
    final progressPercent = (task.progress * 100).round();
    final isSubmitted = task.status == SupervisorTaskStatus.submitted ||
        task.status == SupervisorTaskStatus.approved;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: task.allStepsDone
              ? AppTheme.success.withValues(alpha: 0.30)
              : AppTheme.border,
          width: 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: _buildCircularProgress(task),
        title: Text(
          task.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              _buildTypeBadge(task.type),
              _buildPriorityBadge(task.priority),
              _buildDueDateChip(task.dueDate),
              _buildMiniChip(
                '${task.completedStepCount}/${task.totalStepCount} checked',
                task.allStepsDone ? AppTheme.success : AppTheme.info,
                Icons.checklist,
              ),
            ],
          ),
        ),
        trailing: Text(
          '$progressPercent%',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: task.allStepsDone ? AppTheme.success : AppTheme.info,
          ),
        ),
        children: [
          _buildTaskMetaPanel(task),
          const SizedBox(height: 12),
          _buildHodInstructionBox(task),
          const SizedBox(height: 12),
          ...task.steps.map((step) => _buildChecklistStepTile(task, step)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ready && !isSubmitted
                  ? () => _submitTaskForReview(task)
                  : null,
              icon: Icon(
                ready ? Icons.outbox_outlined : Icons.lock_outline,
                size: 18,
              ),
              label: Text(
                ready
                    ? 'Submit Multi Checklist to HOD'
                    : isSubmitted
                        ? 'Already Submitted'
                        : 'Complete Each Checklist Item & Proof',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.textMuted.withValues(alpha: 0.18),
                disabledForegroundColor: AppTheme.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistStepTile(
    SupervisorHodTask task,
    SupervisorChecklistStep step,
  ) {
    final proofReady = step.proof.satisfies(step.proofRequirement);
    final locked = task.status == SupervisorTaskStatus.submitted ||
        task.status == SupervisorTaskStatus.approved;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: step.done
            ? AppTheme.success.withValues(alpha: 0.06)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: step.done
              ? AppTheme.success.withValues(alpha: 0.26)
              : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: locked ? null : () => _toggleChecklistStep(task, step),
                child: _buildCheckBox(
                  checked: step.done,
                  enabled: !locked,
                  size: 26,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: step.done
                            ? AppTheme.textMuted
                            : AppTheme.textPrimary,
                        decoration:
                            step.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step.instruction,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: locked
                    ? null
                    : () => _showProofSheet(task: task, step: step),
                icon: Icon(
                  proofReady
                      ? Icons.verified_outlined
                      : Icons.upload_file_outlined,
                  color: proofReady ? AppTheme.success : AppTheme.primary,
                ),
                tooltip: 'Upload step proof',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildProofRequirementRow(step.proofRequirement)),
            ],
          ),
          const SizedBox(height: 8),
          _buildProofStatusPanel(
            requirement: step.proofRequirement,
            proof: step.proof,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedTaskCard(SupervisorHodTask task) {
    final color = _statusColor(task.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(task.status.icon, color: color, size: 22),
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
                  '${task.id} • ${task.siteName}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (task.submittedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Submitted: ${_formatDateTime(task.submittedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildStatusChip(task.status),
                    _buildModeChip(task),
                    _buildMiniChip(
                      task.isSingleTask
                          ? '${task.proof.uploadedCount()} proof(s)'
                          : '${task.steps.fold<int>(0, (sum, step) => sum + step.proof.uploadedCount())} proof(s)',
                      AppTheme.info,
                      Icons.upload_file_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionHistoryCard(TaskSubmissionRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.taskTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.id} • ${record.modeLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.completedItems}/${record.totalItems} completed • ${record.proofCount} proof(s) • ${_formatDateTime(record.submittedAt)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskMetaPanel(SupervisorHodTask task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildInfoPill(
              task.id, AppTheme.primary, Icons.confirmation_number_outlined),
          _buildInfoPill(task.siteName, AppTheme.info, Icons.business_outlined),
          _buildInfoPill(task.thavvuId, AppTheme.success, Icons.badge_outlined),
          _buildInfoPill(
              task.tankId, AppTheme.warning, Icons.water_drop_outlined),
        ],
      ),
    );
  }

  Widget _buildHodInstructionBox(SupervisorHodTask task) {
    return _buildHintBox(
      icon: Icons.admin_panel_settings_outlined,
      text: task.hodNote.trim().isEmpty
          ? 'Complete this task exactly as assigned by HOD.'
          : 'HOD note: ${task.hodNote}',
      color: AppTheme.primary,
    );
  }

  Widget _buildRequirementBanner(TaskProofRequirement requirement) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: requirement.hasAny ? AppTheme.warningBg : AppTheme.successBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (requirement.hasAny ? AppTheme.warning : AppTheme.success)
              .withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            requirement.hasAny
                ? Icons.rule_folder_outlined
                : Icons.verified_outlined,
            color: requirement.hasAny ? AppTheme.warning : AppTheme.success,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              requirement.hasAny
                  ? 'HOD required proof: ${requirement.labels.join(', ')}'
                  : 'No required proof. Optional proof can still be added.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: requirement.hasAny ? AppTheme.warning : AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofRequirementRow(TaskProofRequirement requirement) {
    if (!requirement.hasAny) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildMiniChip(
              'Optional proof', AppTheme.textMuted, Icons.info_outline),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (requirement.photoRequired)
          _buildMiniChip(
              'Photo req.', AppTheme.info, Icons.camera_alt_outlined),
        if (requirement.videoRequired)
          _buildMiniChip(
              'Video req.', AppTheme.danger, Icons.videocam_outlined),
        if (requirement.locationRequired)
          _buildMiniChip(
              'Location req.', AppTheme.success, Icons.location_on_outlined),
        if (requirement.noteRequired)
          _buildMiniChip(
              'Note req.', AppTheme.warning, Icons.sticky_note_2_outlined),
      ],
    );
  }

  Widget _buildProofStatusPanel({
    required TaskProofRequirement requirement,
    required TaskProofBundle proof,
    bool compact = false,
  }) {
    final ready = proof.satisfies(requirement);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: ready
            ? AppTheme.success.withValues(alpha: 0.07)
            : AppTheme.warning.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (ready ? AppTheme.success : AppTheme.warning)
              .withValues(alpha: 0.18),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildMiniChip(
            ready ? 'Proof ready' : 'Proof pending',
            ready ? AppTheme.success : AppTheme.warning,
            ready ? Icons.verified_outlined : Icons.warning_amber_outlined,
          ),
          if (proof.hasPhoto())
            _buildMiniChip('Photo', AppTheme.info, Icons.camera_alt),
          if (proof.hasVideo())
            _buildMiniChip('Video', AppTheme.danger, Icons.videocam),
          if (proof.hasLocation())
            _buildMiniChip('Location', AppTheme.success, Icons.location_on),
          if (proof.hasNote())
            _buildMiniChip('Note', AppTheme.warning, Icons.sticky_note_2),
        ],
      ),
    );
  }

  Widget _buildUploadActionTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isRequired,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.textMuted,
                tooltip: 'Remove',
              )
            else
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildProofIconCluster(
    TaskProofBundle proof,
    TaskProofRequirement requirement,
  ) {
    final ready = proof.satisfies(requirement);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (proof.hasPhoto())
          const Icon(Icons.camera_alt, size: 14, color: AppTheme.info),
        if (proof.hasVideo())
          const Icon(Icons.videocam, size: 14, color: AppTheme.danger),
        if (proof.hasLocation())
          const Icon(Icons.location_on, size: 14, color: AppTheme.success),
        if (proof.hasNote())
          const Icon(Icons.sticky_note_2, size: 14, color: AppTheme.warning),
        const SizedBox(width: 5),
        Icon(
          ready ? Icons.verified_outlined : Icons.warning_amber_outlined,
          size: 18,
          color: ready ? AppTheme.success : AppTheme.warning,
        ),
      ],
    );
  }

  Widget _buildCheckBox({
    required bool checked,
    bool enabled = true,
    double size = 28,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: checked
            ? const LinearGradient(
                colors: [AppTheme.success, AppTheme.successLight],
              )
            : null,
        color: checked ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: checked
              ? AppTheme.success
              : enabled
                  ? AppTheme.border
                  : AppTheme.textMuted.withValues(alpha: 0.28),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildCircularProgress(SupervisorHodTask task) {
    final progress = task.progress;
    final color = progress >= 1 ? AppTheme.success : AppTheme.info;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: AppTheme.border.withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '${(progress * 100).round()}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final color = type == 'Daily'
        ? AppTheme.info
        : type == 'Weekly'
            ? AppTheme.success
            : AppTheme.warning;

    return _buildMiniChip(
      type,
      color,
      type == 'Daily'
          ? Icons.today
          : type == 'Weekly'
              ? Icons.weekend
              : Icons.calendar_month,
    );
  }

  Widget _buildPriorityBadge(String priority) {
    final color = _priorityColor(priority);
    return _buildMiniChip(
      priority.toLowerCase() == 'high' ? 'High Priority' : 'Normal',
      color,
      priority.toLowerCase() == 'high'
          ? Icons.priority_high
          : Icons.flag_outlined,
    );
  }

  Widget _buildDueDateChip(String dueDate) {
    final isUrgent = dueDate == 'Today' || dueDate == 'Tomorrow';

    return _buildMiniChip(
      dueDate,
      isUrgent ? AppTheme.warning : AppTheme.textMuted,
      Icons.access_time,
    );
  }

  Widget _buildAssignedByChip(String assignedBy) {
    return _buildMiniChip(
      assignedBy,
      AppTheme.textMuted,
      Icons.person_outline,
    );
  }

  Widget _buildStatusChip(SupervisorTaskStatus status) {
    return _buildMiniChip(
      status.label,
      _statusColor(status),
      status.icon,
    );
  }

  Widget _buildModeChip(SupervisorHodTask task) {
    return _buildMiniChip(
      task.isSingleTask ? 'Single Task' : 'Multi Checklist',
      task.isSingleTask ? AppTheme.info : AppTheme.success,
      task.isSingleTask ? Icons.task_alt : Icons.checklist,
    );
  }

  Widget _buildMiniChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintBox({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuidanceNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_up, color: AppTheme.primary, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Single tasks are completed as one whole task. Multi checklist tasks must be checked item by item, and every HOD-required proof must be uploaded before submission.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
