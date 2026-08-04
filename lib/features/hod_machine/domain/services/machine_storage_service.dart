import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages file uploads/downloads for machine-related attachments.
///
/// Buckets:
/// - `machine-opening-photos`  (supervisor opening evidence)
/// - `machine-payment-proofs`  (finance/HOD payment evidence)
/// - `machine-daily-attachments` (bills, screenshots)
///
/// All buckets are private; access is governed by Storage RLS policies.
class MachineStorageService {
  MachineStorageService(SupabaseClient? client) : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first upload.
  final SupabaseClient? _providedClient;
  late final SupabaseStorageClient _storage =
      (_providedClient ?? Supabase.instance.client).storage;

  /// Upload a file to a bucket. Returns the public/private path.
  ///
  /// [bucket] — one of the three machine buckets.
  /// [userId] — authenticated user UUID, used as folder prefix.
  /// [bytes] — file bytes.
  /// [fileName] — original file name for extension detection.
  Future<String> uploadFile({
    required String bucket,
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last
        : 'jpg';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: _mimeForExtension(ext)),
        );

    return path;
  }

  /// Get a publicly accessible signed URL for a file.
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
  }) async {
    return _storage.from(bucket).createSignedUrl(path, 3600); // 1 hour
  }

  /// Delete a file.
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await _storage.from(bucket).remove([path]);
  }

  String _mimeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
