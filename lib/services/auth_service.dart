import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight session service.
class AuthService {
  static const _keyLoggedIn = 'is_logged_in';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserRole = 'user_role';
  static const _keyEmpId = 'emp_id';

  /// Call after successful login
  static Future<void> login(String email, String role,
      {String name = 'Rajesh Kumar', String empId = 'EMP-001'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserRole, role);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyEmpId, empId);
  }

  /// Call on logout — clears session
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Returns true if user has a saved session
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  /// Returns saved user data map, or empty defaults
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
