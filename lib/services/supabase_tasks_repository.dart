import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/tasks_screen.dart';
import '../screens/hod/modules/hod_tasks_screen.dart';

class SupabaseTasksRepository {
  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first query.
  late final SupabaseClient _client = Supabase.instance.client;
  final String _tasksTable = 'tasks';
  final String _stepsTable = 'task_steps';

  // ==========================================================
  // SUPERVISOR SIDE METHODS
  // ==========================================================

  Future<List<SupervisorHodTask>> fetchSupervisorTasks(String supervisorId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select('*, task_steps(*)')
          .eq('assigned_supervisor_id', supervisorId)
          .order('due_date', ascending: true);

      return (response as List).map((json) {
        final stepsJson = json['task_steps'] as List? ?? [];
        final steps = stepsJson.map((s) => SupervisorChecklistStep(
          id: s['id'],
          title: s['title'],
          instruction: s['instruction'] ?? '',
          done: s['is_done'] ?? false,
          proofRequirement: _parseProofReq(s['proof_requirement']),
          proof: _parseProofBundle(s['proof']),
        )).toList();
        
        steps.sort((a, b) => (stepsJson.firstWhere((s) => s['id'] == a.id)['step_order'] as int? ?? 0)
            .compareTo(stepsJson.firstWhere((s) => s['id'] == b.id)['step_order'] as int? ?? 0));

        return SupervisorHodTask(
          id: json['id'],
          title: json['title'],
          description: json['description'] ?? '',
          mode: json['mode'] == 'single' ? SupervisorTaskMode.single : SupervisorTaskMode.multiChecklist,
          type: json['type'],
          priority: json['priority'],
          dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']).toLocal().toString() : '',
          assignedAt: DateTime.parse(json['assigned_at']).toLocal(),
          assignedBy: json['assigned_by'],
          siteName: json['site_name'] ?? '',
          thavvuId: json['thavvu_id'] ?? '',
          tankId: json['tank_id'] ?? '',
          locationHint: json['location_hint'] ?? '',
          status: _parseSupervisorStatus(json['status']),
          hodNote: json['hod_note'] ?? '',
          submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at']).toLocal() : null,
          proofRequirement: _parseProofReq(json['proof_requirement']),
          proof: _parseProofBundle(json['proof']),
          steps: steps,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching supervisor tasks: $e');
      return [];
    }
  }

  Future<bool> updateTaskStatus(String taskId, SupervisorTaskStatus status) async {
    try {
      final statusStr = _statusToString(status);
      await _client.from(_tasksTable).update({
        'status': statusStr,
        if (status == SupervisorTaskStatus.submitted) 'submitted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', taskId);
      return true;
    } catch (e) {
      debugPrint('Error updating task status: $e');
      return false;
    }
  }

  // ==========================================================
  // HOD SIDE METHODS
  // ==========================================================

  Future<List<HodTaskRecord>> fetchHodTasks(String hodId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select('*, task_steps(*)')
          // Usually you'd filter by siteId or created_by, but assuming HOD sees what they assigned
          .eq('assigned_by', hodId)
          .order('assigned_at', ascending: false);

      return (response as List).map((json) {
        final stepsJson = json['task_steps'] as List? ?? [];
        final items = stepsJson.map((s) => HodTaskChecklistItem(
          title: s['title'],
          done: s['is_done'] ?? false,
          note: s['note'] ?? '',
        )).toList();

        final workStatusStr = json['status'] as String? ?? 'pending';
        final HodTaskWorkStatus workStatus = _mapToHodWorkStatus(workStatusStr);
        final HodTaskReviewStatus reviewStatus = _mapToHodReviewStatus(workStatusStr);

        return HodTaskRecord(
          id: json['id'],
          kind: json['mode'] == 'single' ? HodTaskKind.task : HodTaskKind.checklist,
          title: json['title'],
          description: json['description'] ?? '',
          type: _mapToHodTaskType(json['type']),
          priority: _mapToHodPriority(json['priority']),
          assignedSupervisorId: json['assigned_supervisor_id'] ?? '',
          assignedSupervisorName: 'Supervisor', // Needs lookup in real app
          siteId: json['site_id'] ?? '',
          siteName: json['site_name'] ?? '',
          thavvuPointId: json['thavvu_id'] ?? '',
          dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']).toLocal() : DateTime.now(),
          createdAt: DateTime.parse(json['assigned_at']).toLocal(),
          updatedAt: DateTime.parse(json['assigned_at']).toLocal(),
          createdByHodId: json['assigned_by'],
          workStatus: workStatus,
          reviewStatus: reviewStatus,
          requiredProofs: [], // Simplification
          submittedProofs: [], // Simplification
          checklistItems: items,
          hodNote: json['hod_note'] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching HOD tasks: $e');
      return [];
    }
  }

  Future<bool> createTask(HodTaskRecord task) async {
    try {
      final response = await _client.from(_tasksTable).insert({
        'title': task.title,
        'description': task.description,
        'mode': task.isSingleTask ? 'single' : 'multiChecklist',
        'type': task.type.name,
        'priority': task.priority.name,
        'due_date': task.dueDate.toUtc().toIso8601String(),
        'assigned_at': task.createdAt.toUtc().toIso8601String(),
        'assigned_by': task.createdByHodId,
        'assigned_supervisor_id': task.assignedSupervisorId,
        'site_id': task.siteId,
        'site_name': task.siteName,
        'thavvu_id': task.thavvuPointId,
        'thavvu_point_id': task.thavvuPointId,
        'status': 'pending',
      }).select().single();

      final taskId = response['id'];

      if (task.isChecklist && task.checklistItems.isNotEmpty) {
        int order = 0;
        final stepsData = task.checklistItems.map((item) => {
          'task_id': taskId,
          'title': item.title,
          'is_done': item.done,
          'note': item.note,
          'step_order': order++,
        }).toList();

        await _client.from(_stepsTable).insert(stepsData);
      }
      return true;
    } catch (e) {
      debugPrint('Error creating task: $e');
      return false;
    }
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  TaskProofRequirement _parseProofReq(dynamic json) {
    if (json == null) return const TaskProofRequirement();
    final map = json as Map<String, dynamic>;
    return TaskProofRequirement(
      photoRequired: map['photoRequired'] == true,
      videoRequired: map['videoRequired'] == true,
      locationRequired: map['locationRequired'] == true,
      noteRequired: map['noteRequired'] == true,
    );
  }

  TaskProofBundle _parseProofBundle(dynamic json) {
    if (json == null) return TaskProofBundle();
    final map = json as Map<String, dynamic>;
    return TaskProofBundle(
      photoPath: map['photoPath'],
      videoPath: map['videoPath'],
      note: map['note'] ?? '',
      // Location needs parsing too if present
    );
  }

  SupervisorTaskStatus _parseSupervisorStatus(String? status) {
    switch (status) {
      case 'inProgress': return SupervisorTaskStatus.inProgress;
      case 'completed': return SupervisorTaskStatus.completed;
      case 'submitted': return SupervisorTaskStatus.submitted;
      case 'revisionRequested': return SupervisorTaskStatus.revisionRequested;
      case 'approved': return SupervisorTaskStatus.approved;
      default: return SupervisorTaskStatus.pending;
    }
  }

  String _statusToString(SupervisorTaskStatus status) {
    switch (status) {
      case SupervisorTaskStatus.pending: return 'pending';
      case SupervisorTaskStatus.inProgress: return 'inProgress';
      case SupervisorTaskStatus.completed: return 'completed';
      case SupervisorTaskStatus.submitted: return 'submitted';
      case SupervisorTaskStatus.revisionRequested: return 'revisionRequested';
      case SupervisorTaskStatus.approved: return 'approved';
    }
  }

  HodTaskWorkStatus _mapToHodWorkStatus(String status) {
    if (status == 'pending') return HodTaskWorkStatus.pending;
    if (status == 'inProgress') return HodTaskWorkStatus.inProgress;
    return HodTaskWorkStatus.completed; // Simplification
  }

  HodTaskReviewStatus _mapToHodReviewStatus(String status) {
    if (status == 'revisionRequested') return HodTaskReviewStatus.revisionRequested;
    if (status == 'approved') return HodTaskReviewStatus.approved;
    if (status == 'submitted') return HodTaskReviewStatus.pendingReview;
    return HodTaskReviewStatus.draft; // Default
  }

  HodTaskType _mapToHodTaskType(String type) {
    return HodTaskType.values.firstWhere((e) => e.name == type, orElse: () => HodTaskType.custom);
  }

  HodTaskPriority _mapToHodPriority(String priority) {
    return HodTaskPriority.values.firstWhere((e) => e.name == priority, orElse: () => HodTaskPriority.normal);
  }
}
