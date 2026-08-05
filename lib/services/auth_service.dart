import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth service that delegates to Supabase Auth for credential verification
/// and uses SharedPreferences to cache session metadata for offline UX.
class AuthService {
  static const _keyLoggedIn = 'is_logged_in';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserRole = 'user_role';
  static const _keyEmpId = 'emp_id';

  /// Convenience getter for the Supabase auth client.
  static GoTrueClient get _auth => Supabase.instance.client.auth;

  // ── Sign in via Supabase Auth ────────────────────────────────

  /// Authenticate with email + password via Supabase Auth.
  /// On success, saves session metadata to SharedPreferences using the
  /// ACCOUNT's REAL role (user metadata first, then the profiles table) —
  /// never the self-selected role, so a supervisor account cannot masquerade
  /// as HOD. Returns the resolved role (lowercase, e.g. 'hod'/'supervisor').
  /// Throws [AuthException] on invalid credentials.
  static Future<String> signInWithEmail({
    required String email,
    required String password,
    required String role,
    String name = '',
    String empId = '',
  }) async {
    final response = await _auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw AuthException('No user returned after sign-in.');
    }

    // Extract metadata (from user_metadata or fall back to params)
    final meta = user.userMetadata ?? {};
    final displayName =
        (meta['full_name'] as String?)?.trim() ??
        (meta['name'] as String?)?.trim() ??
        name;
    final displayEmpId =
        (meta['emp_id'] as String?)?.trim() ?? empId;

    // Resolve the REAL role: metadata first, then the profiles table
    // (authoritative, self-readable via RLS), then empty.
    var realRole = resolveRealRole(user.userMetadata);
    if (realRole.isEmpty) {
      try {
        final rows = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .limit(1);
        if (rows.isNotEmpty) {
          realRole = (rows.first['role']?.toString() ?? '').toLowerCase();
        }
      } catch (_) {
        // RLS/network failure → keep empty; the login screen will reject the
        // self-declared role rather than trusting it.
      }
    }

    await login(
      user.email ?? email,
      realRole.isEmpty ? role : realRole,
      name: displayName.isNotEmpty ? displayName : name,
      empId: displayEmpId.isNotEmpty ? displayEmpId : empId,
    );
    return realRole;
  }

  /// Resolves the account's REAL role from auth user metadata (lowercase).
  /// Empty when the metadata carries no role — callers must then fall back
  /// to the profiles table or reject the self-declared role.
  static String resolveRealRole(Map<String, dynamic>? meta) {
    final raw = meta?['role'];
    if (raw is! String) return '';
    return raw.trim().toLowerCase();
  }

  /// Sign out from Supabase and clear the local session.
  static Future<void> signOut() async {
    await _auth.signOut();
    await logout();
  }

  // ── Existing SharedPreferences helpers ───────────────────────

  /// Call after successful login to persist session metadata.
  static Future<void> login(String email, String role,
      {String name = 'Rajesh Kumar', String empId = 'EMP-001'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserRole, role);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyEmpId, empId);
  }

  /// Call on logout — clears session.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyEmpId);
  }

  /// Returns true if the user has a real Supabase session.
  ///
  /// SharedPreferences alone is NOT sufficient: every data operation goes
  /// through Supabase RLS, which requires a real authenticated session.
  static Future<bool> hasSupabaseSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      return session != null && session.isExpired == false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if user has a saved session.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  /// Returns saved user data map, or empty defaults.
  static Future<Map<String, String>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyUserName) ?? 'Rajesh Kumar',
      'email': prefs.getString(_keyUserEmail) ?? '',
      'role': prefs.getString(_keyUserRole) ?? 'Supervisor',
      'empId': prefs.getString(_keyEmpId) ?? 'EMP-001',
    };
  }
}
