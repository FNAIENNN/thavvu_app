import 'dart:typed_data';

class PickedDeviceFile {
  final String name;
  final String extension;
  final int size;
  final Uint8List bytes;

  const PickedDeviceFile({
    required this.name,
    required this.extension,
    required this.size,
    required this.bytes,
  });
}

String fileExtension(String fileName) {
  final parts = fileName.split('.');
  if (parts.length < 2) return '';
  return parts.last.toLowerCase();
}

bool isAllowedHodMapExtension(String extension) {
  return {'pdf', 'jpg', 'jpeg', 'png'}.contains(extension.toLowerCase());
}
