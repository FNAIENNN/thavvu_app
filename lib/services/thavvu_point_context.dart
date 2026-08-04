import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the Thavvu Point that the signed-in SUPERVISOR is currently working on.
///
/// Unlike the HOD app (which grants points), the supervisor does not manage
/// assignments — they receive whatever the HOD granted. When a supervisor is
/// granted more than one active point, this store lets them choose which one
/// they are operating on. Every module that writes point-scoped rows reads
/// this selection (see `AttendanceContextService.resolvePointId`), so the
/// chosen point becomes the current context across attendance, food, stock,
/// cash, tasks, maps etc.
///
/// The selection is persisted locally so it survives app restarts.
class ThavvuPointContext extends ChangeNotifier {
  ThavvuPointContext._();

  /// Process-wide singleton (one device = one logged-in user context).
  static final ThavvuPointContext instance = ThavvuPointContext._();

  static const _prefsKey = 'supervisor_selected_point_id';

  String? _selectedPointId;

  /// The point id the supervisor picked, or null when not chosen yet.
  String? get selectedPointId => _selectedPointId;

  bool get hasSelection => _selectedPointId != null;

  /// Loads the persisted selection (call after login / on shell start).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedPointId = prefs.getString(_prefsKey);
      notifyListeners();
    } catch (_) {
      // Persistence is best-effort; fall back to no selection.
    }
  }

  /// Persists the supervisor's chosen active point.
  Future<void> select(String? pointId) async {
    _selectedPointId = pointId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pointId == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, pointId);
      }
    } catch (_) {
      // Best-effort; selection still applies for this session.
    }
  }

  /// Clears the selection (reverts to automatic assignment resolution).
  Future<void> clear() => select(null);
}