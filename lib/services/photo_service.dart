import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Captures or picks a photo and stores a durable copy under app documents.
class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();

  final ImagePicker _picker = ImagePicker();

  Future<String?> capture({required String module, required String label}) async {
    try {
      final XFile? shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
      );
      if (shot == null) return null;
      return _persist(shot, module: module, label: label);
    } catch (_) {
      // Camera may be unavailable (web/desktop/simulator) — fall back to gallery.
      return pickFromGallery(module: module, label: label);
    }
  }

  Future<String?> pickFromGallery({required String module, required String label}) async {
    try {
      final XFile? shot = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
      );
      if (shot == null) return null;
      return _persist(shot, module: module, label: label);
    } catch (_) {
      return null;
    }
  }

  /// Shows a simple choice when both sources may be needed — callers pass source.
  Future<String?> acquire({
    required String module,
    required String label,
    ImageSource source = ImageSource.camera,
  }) async {
    if (source == ImageSource.gallery) {
      return pickFromGallery(module: module, label: label);
    }
    return capture(module: module, label: label);
  }

  Future<String?> _persist(XFile shot, {required String module, required String label}) async {
    if (kIsWeb) {
      // On web, keep the blob/object URL path returned by the picker.
      return shot.path;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(dir.path, 'thavvu_photos', module));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final safeLabel = label.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final name = '${DateTime.now().millisecondsSinceEpoch}_$safeLabel.jpg';
      final dest = p.join(photosDir.path, name);
      await File(shot.path).copy(dest);
      return dest;
    } catch (_) {
      return shot.path;
    }
  }
}
