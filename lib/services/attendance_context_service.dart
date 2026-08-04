import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'thavvu_point_context.dart';

/// Resolves the current user's operational context (site id) so
/// attendance/food screens know which rows to read and write.
///
/// Priority:
///   1. Explicit site override (HOD picked a site on their shell).
///   2. Active `thavvu_point_assignments` for the signed-in supervisor.
///   3. First active site membership for the signed-in user.
class AttendanceContextService {
  AttendanceContextService({SupabaseClient? client})
      : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first resolution.
  final SupabaseClient? _providedClient;

  /// Lazy and null-safe: resolves to null when Supabase hasn't been
  /// initialized (widget tests, early startup, hot-restart edge cases)
  /// instead of throwing the "You must initialize the supabase instance"
  /// assertion. Every public method treats a null client as "no context"
  /// and returns its safe default, so a context-resolution failure can
  /// never take down a screen.
  late final SupabaseClient? _client = _resolveClient();

  SupabaseClient? _resolveClient() {
    try {
      return _providedClient ?? Supabase.instance.client;
    } catch (_) {
      // Supabase not initialized — degrade to "no client".
      return null;
    }
  }

  String? _cachedSiteId;

  /// Resolve the site id for the current user, caching the result.
  ///
  /// Never throws: a context resolution failure must not take down the
  /// screen. Uses limit(1) so multiple active assignments/memberships
  /// cannot trip PostgREST's single-row coercion (PGRST116).
  Future<String?> resolveSiteId({String? override}) async {
    if (override != null && override.isNotEmpty) return override;
    if (_cachedSiteId != null) return _cachedSiteId;

    final client = _client;
    if (client == null) return null;

    final user = client.auth.currentUser;
    if (user == null) return null;

    // Supervisor: active thavvu point assignment → site
    try {
      final assignment = await client
          .from('thavvu_point_assignments')
          .select('site_id')
          .eq('supervisor_id', user.id)
          .eq('is_active', true)
          .order('assigned_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (assignment != null) {
        _cachedSiteId = assignment['site_id'] as String?;
        return _cachedSiteId;
      }
    } catch (e) {
      // Assignment lookup failed (RLS/permissions/network) — fall through
      // to the membership lookup instead of crashing the caller.
      debugPrint('resolveSiteId: assignment lookup failed: $e');
    }

    // Fallback: any active site membership
    try {
      final membership = await client
          .from('site_memberships')
          .select('site_id')
          .eq('profile_id', user.id)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      if (membership != null) {
        _cachedSiteId = membership['site_id'] as String?;
        return _cachedSiteId;
      }
    } catch (e) {
      debugPrint('resolveSiteId: membership lookup failed: $e');
    }

    return null;
  }

  /// Resolve the currently active Thavvu Point id for the signed-in user.
  ///
  /// The enterprise key: every data row a supervisor enters stores the
  /// thavvu_point_id of their active assignment. Returns null when the user
  /// has no active point assignment (site-level fallback still works).
  ///
  /// Priority:
  ///   1. Explicit selection made by the supervisor on the shell
  ///      (ThavvuPointContext) — the user's chosen point wins.
  ///   2. Most recent active `thavvu_point_assignments` row.
  String? _cachedPointId;

  Future<String?> resolvePointId({String? override}) async {
    if (override != null && override.isNotEmpty) return override;

    // The supervisor explicitly picked a point — honor it above the
    // automatic assignment resolution.
    if (ThavvuPointContext.instance.hasSelection) {
      return ThavvuPointContext.instance.selectedPointId;
    }
    if (_cachedPointId != null) return _cachedPointId;

    final client = _client;
    if (client == null) return null;

    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final assignment = await client
          .from('thavvu_point_assignments')
          .select('thavvu_point_id')
          .eq('supervisor_id', user.id)
          .eq('is_active', true)
          .order('assigned_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (assignment != null) {
        _cachedPointId = assignment['thavvu_point_id'] as String?;
        return _cachedPointId;
      }
    } catch (e) {
      // Assignment lookup failed — point scoping is best-effort; the write
      // still succeeds with a null point.
      debugPrint('resolvePointId: assignment lookup failed: $e');
    }
    return null;
  }

  /// The signed-in user's `profiles` row (identity card used by the
  /// supervisor shell: full name, emp id, email, phone, role, join date).
  Future<Map<String, dynamic>?> fetchProfileForCurrentUser() async {
    final client = _client;
    if (client == null) return null;

    try {
      final user = client.auth.currentUser;
      if (user == null) return null;
      final rows = await client
          .from('profiles')
          .select('id, emp_id, full_name, email, phone, role, created_at')
          .eq('id', user.id)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (e) {
      debugPrint('fetchProfileForCurrentUser failed: $e');
    }
    return null;
  }

  /// Updates the signed-in user's profile (identity) row.
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final user = client.auth.currentUser;
      if (user == null) return false;
      final patch = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (fullName != null && fullName.trim().isNotEmpty) {
        patch['full_name'] = fullName.trim();
      }
      if (phone != null) patch['phone'] = phone.trim();
      await client.from('profiles').update(patch).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('updateProfile failed: $e');
      return false;
    }
  }

  /// All active Thavvu Points granted to the signed-in user, with the
  /// point name + site id joined in. Ground truth comes from Supabase
  /// (`thavvu_point_assignments` × `thavvu_points`), never local seeds.
  Future<List<Map<String, dynamic>>> fetchActivePointsForCurrentUser() async {
    final client = _client;
    if (client == null) return const [];

    try {
      final user = client.auth.currentUser;
      if (user == null) return const [];

      final response = await client
          .from('thavvu_point_assignments')
          .select('thavvu_point_id, site_id, thavvu_points(point_name)')
          .eq('supervisor_id', user.id)
          .eq('is_active', true)
          .order('assigned_at', ascending: false);
      final rows = response as List;
      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } catch (e) {
      debugPrint('fetchActivePointsForCurrentUser failed: $e');
      return const [];
    }
  }
}