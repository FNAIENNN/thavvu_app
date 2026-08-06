import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted offline retry queue for critical writes.
///
/// When a write fails (no network / backend down) the caller enqueues the
/// operation here instead of losing it; on the next app start or load the
/// queue is drained against Supabase and each entry is removed once it
/// succeeds. Entries are keyed by [id] so replays are idempotent.
class PendingWritesStore {
  PendingWritesStore._();

  static final PendingWritesStore instance = PendingWritesStore._();

  static const _prefsKey = 'pending_writes_v1';

  List<Map<String, dynamic>> _cache = [];

  Future<List<Map<String, dynamic>>> all() async {
    if (_cache.isNotEmpty) return List.of(_cache);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _cache = decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    } catch (_) {
      _cache = [];
    }
    return List.of(_cache);
  }

  /// Adds (or replaces, by id) a pending operation.
  Future<void> enqueue({
    required String id,
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    final entries = await all();
    entries.removeWhere((e) => e['id'] == id);
    entries.insert(0, {
      'id': id,
      'kind': kind,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _persist(entries);
  }

  /// Removes a successfully replayed operation.
  Future<void> remove(String id) async {
    final entries = await all();
    entries.removeWhere((e) => e['id'] == id);
    await _persist(entries);
  }

  Future<void> clear() async {
    _cache = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  Future<void> _persist(List<Map<String, dynamic>> entries) async {
    _cache = entries;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(entries));
    } catch (_) {
      // Best-effort persistence; in-memory queue still works this session.
    }
  }
}
