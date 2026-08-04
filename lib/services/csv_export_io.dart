import 'dart:io';

/// IO implementation: writes the CSV into the current directory (mobile and
/// desktop can resolve a real downloads folder via the OS share sheet; this
/// gives a guaranteed file path for the app to expose).
Future<String?> downloadCsv({
  required String fileName,
  required String csv,
}) async {
  try {
    final directory = Directory.systemTemp;
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsString(csv, flush: true);
    return file.path;
  } catch (e) {
    return null;
  }
}
