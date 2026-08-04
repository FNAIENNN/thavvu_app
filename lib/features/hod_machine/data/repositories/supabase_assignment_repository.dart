import 'package:supabase_flutter/supabase_flutter.dart';

/// Thavvu Point assignment model — mirrors `thavvu_point_assignments` table.
class ThavvuPointAssignment {
  final String id;
  final String thavvuPointId;
  final String supervisorId;
  final String siteId;
  final String assignedBy;
  final bool isActive;
  final DateTime assignedAt;
  final DateTime? endedAt;
  final String? reason;

  const ThavvuPointAssignment({
    required this.id,
    required this.thavvuPointId,
    required this.supervisorId,
    required this.siteId,
    required this.assignedBy,
    this.isActive = true,
    required this.assignedAt,
    this.endedAt,
    this.reason,
  });

  factory ThavvuPointAssignment.fromJson(Map<String, dynamic> json) {
    return ThavvuPointAssignment(
      id: json['id'] as String,
      thavvuPointId: json['thavvu_point_id'] as String,
      supervisorId: json['supervisor_id'] as String,
      siteId: json['site_id'] as String,
      assignedBy: json['assigned_by'] as String,
      isActive: json['is_active'] as bool? ?? true,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      reason: json['reason'] as String?,
    );
  }
}

/// Manages supervisor assignments to Thavvu Points in Supabase.
///
/// Reassigning a point:
/// 1. Ends the current active assignment (sets `ended_at`, `is_active` false).
/// 2. Creates a new active assignment for the target supervisor.
/// 3. Records an audit event.
/// 4. Creates alerts for both old and new supervisors.
///
/// RLS ensures only authorized HODs can perform reassignments.
class SupabaseAssignmentRepository {
  SupabaseAssignmentRepository(SupabaseClient? client)
      : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first query.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  /// Returns the currently active assignment for a Thavvu Point, if any.
  Future<ThavvuPointAssignment?> getActiveAssignment({
    required String thavvuPointId,
  }) async {
    final response = await _client
        .from('thavvu_point_assignments')
        .select()
        .eq('thavvu_point_id', thavvuPointId)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return ThavvuPointAssignment.fromJson(response);
  }

  /// Creates a Thavvu Point in the database (HOD → enterprise point).
  ///
  /// Returns the new point id. The caller then calls [grant] to assign it
  /// to a supervisor.
  Future<String> createPoint({
    required String siteId,
    required String pointName,
    required double assignedAcres,
    required String createdBy,
  }) async {
    final resolvedCreator = await _resolveProfileUuid(createdBy);
    if (resolvedCreator == null) {
      throw StateError(
        'HOD profile not found. Seed auth users + profiles first.',
      );
    }
    final pointId = 'TP-${DateTime.now().millisecondsSinceEpoch}';
    final response = await _client.from('thavvu_points').insert({
      'id': pointId,
      'site_id': siteId,
      'point_name': pointName,
      'assigned_acres': assignedAcres,
      'status': 'active',
      'created_by': resolvedCreator,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();
    return (response as Map)['id'] as String;
  }

  /// All Thavvu Points for a site (from the DB, not local storage).
  Future<List<Map<String, dynamic>>> pointsForSite(String siteId) async {
    final response = await _client
        .from('thavvu_points')
        .select()
        .eq('site_id', siteId)
        .order('created_at', ascending: true);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// The currently active Thavvu Point for a supervisor (UUID), or null.
  Future<Map<String, dynamic>?> activePointForSupervisor(
    String supervisorId,
  ) async {
    if (!_isValidUuid(supervisorId)) return null;
    final response = await _client
        .from('thavvu_point_assignments')
        .select('thavvu_point_id, thavvu_points(site_id, point_name)')
        .eq('supervisor_id', supervisorId)
        .eq('is_active', true)
        .order('assigned_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return response;
  }

  /// Returns all active assignments for a supervisor.
  ///
  /// `supervisor_id` is a UUID column; a human-readable placeholder such as
  /// "SUP-VJA-001" is not a valid UUID and would trigger a PostgREST 400.
  /// When the value is not a UUID we return an empty list (the placeholder has
  /// no real Supabase assignments yet).
  Future<List<ThavvuPointAssignment>> getAssignmentsForSupervisor({
    required String supervisorId,
  }) async {
    if (!_isValidUuid(supervisorId)) return [];
    final response = await _client
        .from('thavvu_point_assignments')
        .select()
        .eq('supervisor_id', supervisorId)
        .eq('is_active', true);

    return (response as List)
        .map((j) => ThavvuPointAssignment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns all active assignments for a site.
  Future<List<ThavvuPointAssignment>> getAssignmentsForSite({
    required String siteId,
  }) async {
    final response = await _client
        .from('thavvu_point_assignments')
        .select()
        .eq('site_id', siteId)
        .eq('is_active', true);

    return (response as List)
        .map((j) => ThavvuPointAssignment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Reassigns a Thavvu Point from its current supervisor to a new one.
  ///
  /// [newSupervisorId] and [assignedBy] can be either a Supabase auth UUID or
  /// a human-readable emp_id (e.g. `THV-SUP-001`, `HOD-001`). This method
  /// resolves emp_ids to real auth UUIDs via the `profiles` table before
  /// writing to any UUID column.
  Future<ThavvuPointAssignment> reassign({
    required String thavvuPointId,
    required String newSupervisorId,
    required String siteId,
    required String assignedBy,
    String? reason,
  }) async {
    // Resolve human-readable ids to auth UUIDs.
    final resolvedSupervisor = await _resolveProfileUuid(newSupervisorId);
    final resolvedAssigner = await _resolveProfileUuid(assignedBy);

    if (resolvedSupervisor == null) {
      throw StateError(
        'Supervisor "$newSupervisorId" not found in profiles. '
        'Create a Supabase auth user and profile first.',
      );
    }
    if (resolvedAssigner == null) {
      throw StateError(
        'HOD "$assignedBy" not found in profiles. '
        'Log in with Supabase auth before reassigning.',
      );
    }

    // 1. End the current active assignment (if any).
    await _client
        .from('thavvu_point_assignments')
        .update({
          'is_active': false,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('thavvu_point_id', thavvuPointId)
        .eq('is_active', true);

    // 2. Create the new assignment.
    final response = await _client
        .from('thavvu_point_assignments')
        .insert({
          'thavvu_point_id': thavvuPointId,
          'supervisor_id': resolvedSupervisor,
          'site_id': siteId,
          'assigned_by': resolvedAssigner,
          'reason': reason,
        })
        .select()
        .single();

    final assignment =
        ThavvuPointAssignment.fromJson(response);

    // 3. Record audit event.
    try {
      await _client.from('machine_audit_logs').insert({
        'site_id': siteId,
        'thavvu_point_id': thavvuPointId,
        'actor_id': resolvedAssigner,
        'action': 'thavvu_point_reassigned',
        'entity_type': 'thavvu_point_assignment',
        'entity_id': assignment.id,
        'details': {
          'thavvu_point_id': thavvuPointId,
          'new_supervisor_id': resolvedSupervisor,
          'assigned_by': resolvedAssigner,
          'reason': reason,
        },
      });
    } catch (_) {}

    // 4. Create alerts for the new supervisor.
    try {
      await _client.from('module_alerts').insert({
        'site_id': siteId,
        'thavvu_point_id': thavvuPointId,
        'module': 'Planning',
        'alert_type': 'info',
        'title': 'Thavvu Point Assigned',
        'message': 'A Thavvu Point has been assigned to you by HOD.',
        'target_profile_id': resolvedSupervisor,
        'target_role': 'supervisor',
      });
    } catch (_) {}

    return assignment;
  }

  /// Grants (activates / creates first assignment for) a Thavvu Point.
  ///
  /// As with [reassign], the id arguments may be either auth UUIDs or
  /// human-readable emp_ids; both are resolved via `profiles` first.
  Future<ThavvuPointAssignment> grant({
    required String thavvuPointId,
    required String supervisorId,
    required String siteId,
    required String assignedBy,
  }) async {
    final resolvedSupervisor = await _resolveProfileUuid(supervisorId);
    final resolvedAssigner = await _resolveProfileUuid(assignedBy);

    if (resolvedSupervisor == null || resolvedAssigner == null) {
      throw StateError(
        'Supervisor or HOD profile not found. Seed auth users + profiles first.',
      );
    }

    final response = await _client
        .from('thavvu_point_assignments')
        .insert({
          'thavvu_point_id': thavvuPointId,
          'supervisor_id': resolvedSupervisor,
          'site_id': siteId,
          'assigned_by': resolvedAssigner,
        })
        .select()
        .single();

    final assignment =
        ThavvuPointAssignment.fromJson(response);

    try {
      await _client.from('machine_audit_logs').insert({
        'site_id': siteId,
        'thavvu_point_id': thavvuPointId,
        'actor_id': resolvedAssigner,
        'action': 'thavvu_point_granted',
        'entity_type': 'thavvu_point_assignment',
        'entity_id': assignment.id,
      });
    } catch (_) {}

    return assignment;
  }

  /// Resolves [identifier] (a Supabase auth UUID or a human-readable emp_id)
  /// to the corresponding `profiles.id` UUID. Returns the value as-is if it
  /// is already a valid UUID, otherwise looks up `profiles.emp_id`.
  ///
  /// Returns null if no profile is found.
  Future<String?> _resolveProfileUuid(String identifier) async {
    if (identifier.isEmpty) return null;
    if (_isValidUuid(identifier)) return identifier;

    try {
      final rows = await _client
          .from('profiles')
          .select('id')
          .eq('emp_id', identifier)
          .limit(1);
      if (rows.isNotEmpty) {
        return rows.first['id'] as String;
      }
    } catch (_) {
      // Ignore — table may not exist yet in local dev before migrations run.
    }
    return null;
  }

  /// Returns true when [value] is a 36-character UUID.
  bool _isValidUuid(String value) {
    final pattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return pattern.hasMatch(value);
  }
}
