import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads attendance proof photos to the private `attendance-photos`
/// bucket and returns the storage path for persistence on records.
///
/// Path layout: `<userId>/attendance/<yyyy-MM-dd>/<workerId>_<kind>_<ts>.<ext>`
/// The first path segment must be the authenticated user id for the
/// storage RLS insert policy.
class PhotoUploadService {
  PhotoUploadService({SupabaseClient? client}) : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first upload.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const _bucket = 'attendance-photos';

  /// Upload a photo file for a worker's attendance event.
  /// Returns the storage path (e.g. `uuid/attendance/2026-08-01/...`) or
  /// null on failure.
  Future<String?> uploadAttendancePhoto(
    String workerId,
    File photo, {
    String kind = 'checkin', // checkin / checkout / halfday / afternoon / batch
  }) async {
    final bytes = await photo.readAsBytes();
    final ext = photo.path.contains('.')
        ? photo.path.split('.').last.toLowerCase()
        : 'jpg';
    return uploadAttendancePhotoBytes(workerId, bytes, kind: kind, ext: ext);
  }

  /// Upload raw image bytes for a worker's attendance event (cross-platform,
  /// works on web where [File] paths are not usable).
  Future<String?> uploadAttendancePhotoBytes(
    String workerId,
    Uint8List bytes, {
    String kind = 'checkin',
    String ext = 'jpg',
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final now = DateTime.now();
      final date = now.toIso8601String().substring(0, 10);
      final path =
          '${user.id}/attendance/$date/${workerId}_${kind}_${now.millisecondsSinceEpoch}.$ext';

      await _client.storage.from(_bucket).uploadBinary(path, bytes);
      return path;
    } catch (e) {
      debugPrint('Error uploading attendance photo: $e');
      return null;
    }
  }

  /// Build a public URL for a stored path (HOD preview). Private bucket
  /// URLs require auth; this helper returns the API URL form which the
  /// Supabase client can fetch with the session token.
  String? photoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  /// Upload an outside-worker batch photo (entry, continuation, end-shift,
  /// half-day, supplier bill).
  /// [context] is a label like 'entry', 'continuation', 'endshift',
  /// 'halfday', 'bill'.
  Future<String?> uploadOutsideWorkerPhoto(
    String batchId,
    Uint8List bytes, {
    String context = 'entry',
    String ext = 'jpg',
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final now = DateTime.now();
      final date = now.toIso8601String().substring(0, 10);
      final path =
          '${user.id}/outside/$date/${batchId}_${context}_${now.millisecondsSinceEpoch}.$ext';

      await _client.storage.from(_bucket).uploadBinary(path, bytes);
      return path;
    } catch (e) {
      debugPrint('Error uploading outside worker photo: $e');
      return null;
    }
  }

  /// Upload a stock module proof photo (consumption, GIN, transfer).
  /// [context] is a label like 'consumption', 'gin', 'transfer'.
  Future<String?> uploadStockPhoto(
    String referenceId,
    Uint8List bytes, {
    String context = 'stock',
    String ext = 'jpg',
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final now = DateTime.now();
      final date = now.toIso8601String().substring(0, 10);
      final path =
          '${user.id}/stock/$date/${referenceId}_${context}_${now.millisecondsSinceEpoch}.$ext';

      await _client.storage.from(_bucket).uploadBinary(path, bytes);
      return path;
    } catch (e) {
      debugPrint('Error uploading stock photo: $e');
      return null;
    }
  }
}
