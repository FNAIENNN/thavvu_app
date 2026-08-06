import 'dart:convert';

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
      final tasksRes = await _client
          .from(_tasksTable)
          .select()
          .eq('assigned_supervisor_id', supervisorId)
          .order('due_date', ascending: true);
      final tasks = (tasksRes as List).cast<Map<String, dynamic>>();
      if (tasks.isEmpty) return [];

      // task_steps has NO FK to tasks (and its task_id is text while
      // tasks.id is uuid), so a `select('*, task_steps(*)')` embed fails.
      // Fetch steps in a second query and merge client-side instead.
      final steps = await _fetchStepsForTasks(
          tasks.map((t) => t['id'].toString()).toList());

      return tasks.map((json) {
        final stepsJson = steps[json['id'].toString()] ?? const [];
        final parsedSteps = stepsJson.map((s) => SupervisorChecklistStep(
          id: s['id'],
          title: s['title'],
          instruction: s['instruction'] ?? '',
          done: s['is_done'] ?? false,
          proofRequirement: _parseProofReq(s['proof_requirement']),
          proof: _parseProofBundle(s['proof']),
        )).toList();

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
          steps: parsedSteps,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching supervisor tasks: $e');
      return [];
    }
  }

  /// Fetches task_steps for a batch of task ids, grouped by task_id and
  /// already ordered by step_order (no FK/embed dependency).
  Future<Map<String, List<Map<String, dynamic>>>> _fetchStepsForTasks(
      List<String> taskIds) async {
    final result = <String, List<Map<String, dynamic>>>{};
    if (taskIds.isEmpty) return result;
    try {
      final rows = await _client
          .from(_stepsTable)
          .select()
          .inFilter('task_id', taskIds)
          .order('step_order', ascending: true);
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        result.putIfAbsent(r['task_id']?.toString() ?? '', () => []).add(r);
      }
    } catch (e) {
      debugPrint('fetch task steps failed: $e');
    }
    return result;
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

  /// Persists a single checklist step's done flag (supervisor toggle).
  Future<bool> updateTaskStepCompletion(
    String taskId,
    String stepId,
    bool isDone,
  ) async {
    try {
      await _client
          .from(_stepsTable)
          .update({'is_done': isDone})
          .eq('task_id', taskId)
          .eq('id', stepId);
      return true;
    } catch (e) {
      debugPrint('updateTaskStepCompletion failed: $e');
      return false;
    }
  }

  /// Persists a proof bundle on a task (stepId null) or a single step.
  Future<bool> updateTaskProof({
    required String taskId,
    String? stepId,
    required Map<String, dynamic> proof,
  }) async {
    try {
      if (stepId != null && stepId.isNotEmpty) {
        await _client
            .from(_stepsTable)
            .update({'proof': proof})
            .eq('task_id', taskId)
            .eq('id', stepId);
      } else {
        await _client
            .from(_tasksTable)
            .update({'proof': proof})
            .eq('id', taskId);
      }
      return true;
    } catch (e) {
      debugPrint('updateTaskProof failed: $e');
      return false;
    }
  }

  /// Uploads a proof image/video to the `task-proofs` bucket (uid-prefixed
  /// path, matching the storage RLS policy) and returns the path or null.
  Future<String?> uploadTaskProof(
    Uint8List bytes, {
    required String taskId,
    String? stepId,
    required String extension,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final now = DateTime.now();
      final path =
          '${user.id}/task/$taskId/${stepId ?? 'single'}_${now.millisecondsSinceEpoch}.$extension';
      await _client.storage.from('task-proofs').uploadBinary(path, bytes);
      return path;
    } catch (e) {
      debugPrint('uploadTaskProof failed: $e');
      return null;
    }
  }

  // ==========================================================
  // HOD SIDE METHODS
  // ==========================================================

  Future<List<HodTaskRecord>> fetchHodTasks(String hodId) async {
    try {
      final tasksRes = await _client
          .from(_tasksTable)
          .select()
          // Usually you'd filter by siteId or created_by, but assuming HOD sees what they assigned
          .eq('assigned_by', hodId)
          .order('assigned_at', ascending: false);
      final tasks = (tasksRes as List).cast<Map<String, dynamic>>();
      if (tasks.isEmpty) return [];

      final steps = await _fetchStepsForTasks(
          tasks.map((t) => t['id'].toString()).toList());

      return tasks.map((json) {
        final stepsJson = steps[json['id'].toString()] ?? const [];
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
      final proofReq = _proofRequirementToJson(task.requiredProofs);
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
        'proof_requirement': proofReq,
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
          'proof_requirement': proofReq,
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
    final map = _proofAsMap(json);
    if (map == null) return const TaskProofRequirement();
    return TaskProofRequirement(
      photoRequired: map['photoRequired'] == true,
      videoRequired: map['videoRequired'] == true,
      locationRequired: map['locationRequired'] == true,
      noteRequired: map['noteRequired'] == true,
    );
  }

  TaskProofBundle _parseProofBundle(dynamic json) {
    final map = _proofAsMap(json);
    if (map == null) return TaskProofBundle();
    TaskLocationProof? location;
    final loc = map['location'];
    if (loc is Map) {
      final locMap = Map<String, dynamic>.from(loc);
      location = TaskLocationProof(
        label: locMap['label']?.toString() ?? '',
        latitude: (locMap['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (locMap['longitude'] as num?)?.toDouble() ?? 0,
        capturedAt: DateTime.tryParse(locMap['capturedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    }
    return TaskProofBundle(
      photoPath: map['photoPath']?.toString(),
      videoPath: map['videoPath']?.toString(),
      location: location,
      note: map['note']?.toString() ?? '',
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  /// proof_requirement / proof are jsonb in the model but stored as TEXT /
  /// jsonb columns — normalise both string (JSON-encoded) and map shapes.
  Map<String, dynamic>? _proofAsMap(dynamic json) {
    if (json == null) return null;
    if (json is Map) return Map<String, dynamic>.from(json);
    if (json is String) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Serialises the HOD's required-proof set into the JSON string the
  /// `proof_requirement` TEXT column stores (read back by [_parseProofReq]).
  String _proofRequirementToJson(List<HodProofType> proofs) {
    return jsonEncode({
      'photoRequired': proofs.contains(HodProofType.photo),
      'videoRequired': proofs.contains(HodProofType.video),
      'locationRequired': proofs.contains(HodProofType.location),
      'noteRequired': proofs.contains(HodProofType.textNote),
    });
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
