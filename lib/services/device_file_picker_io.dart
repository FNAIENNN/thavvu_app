import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'device_file_picker_models.dart';

Future<PickedDeviceFile?> pickHodMapDeviceFileImpl() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final extension = (file.extension ?? fileExtension(file.name)).toLowerCase();
  final bytes = file.bytes ?? await _readPathBytes(file.path);

  return PickedDeviceFile(
    name: file.name,
    extension: extension,
    size: file.size > 0 ? file.size : bytes.length,
    bytes: bytes,
  );
}

Future<Uint8List> _readPathBytes(String? path) async {
  if (path == null || path.isEmpty) return Uint8List(0);
  return File(path).readAsBytes();
}
