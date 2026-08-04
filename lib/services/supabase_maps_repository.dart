import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hod_workflow_models.dart';

class SupabaseMapsRepository {
  static const String _tableName = 'hod_map_uploads';
  static const String _bucketName = 'hod-map-uploads';

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Fetch map uploads, optionally filtered by siteId
  Future<List<HodMapUploadRecord>> fetchMapUploads({String? siteId}) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from(_tableName).select();

      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }

      // Order by latest first
      final response = await query.order('uploaded_at', ascending: false);

      return (response as List).map((json) {
        return HodMapUploadRecord(
          id: json['id'],
          siteId: json['site_id'],
          thavvuPointId: json['thavvu_point_id'] as String?,
          uploadedById: json['uploaded_by_id'],
          title: json['title'],
          note: json['note'] ?? '',
          fileName: json['file_name'],
          fileType: json['file_type'],
          filePath: json['file_path'],
          uploadedAt: DateTime.parse(json['uploaded_at']).toLocal(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching map uploads: $e');
      return [];
    }
  }

  /// Upload selected HOD map/spec file bytes to Supabase Storage.
  Future<String?> uploadMapFile({
    required String siteId,
    required String fileName,
    required String fileType,
    required Uint8List bytes,
    required DateTime uploadedAt,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final storagePath = _storagePath(
        siteId: siteId,
        fileName: fileName,
        uploadedAt: uploadedAt,
      );
      await client.storage.from(_bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeFor(fileType),
              upsert: false,
            ),
          );

      final publicUrl =
          client.storage.from(_bucketName).getPublicUrl(storagePath);
      return publicUrl.isEmpty
          ? 'storage://$_bucketName/$storagePath'
          : publicUrl;
    } catch (e) {
      debugPrint('Error uploading map file: $e');
      return null;
    }
  }

  /// Save a new map upload from HOD
  Future<bool> saveMapUpload(HodMapUploadRecord record) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.from(_tableName).insert({
        'site_id': record.siteId,
        'thavvu_point_id': record.thavvuPointId,
        'uploaded_by_id': record.uploadedById,
        'title': record.title,
        'note': record.note,
        'file_name': record.fileName,
        'file_type': record.fileType,
        'file_path': record.filePath,
        'uploaded_at': record.uploadedAt.toUtc().toIso8601String(),
        'is_verified': true,
      });
      return true;
    } catch (e) {
      debugPrint('Error saving map upload: $e');
      return false;
    }
  }

  /// Get public URL for a stored file path
  String getPublicUrl(String filePath) {
    final client = _client;
    if (client == null) return '';
    return client.storage.from(_bucketName).getPublicUrl(filePath);
  }



  String _storagePath({
    required String siteId,
    required String fileName,
    required DateTime uploadedAt,
  }) {
    final safeName = fileName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return '$siteId/${uploadedAt.millisecondsSinceEpoch}-$safeName';
  }

  String _contentTypeFor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}
