import 'csv_export_stub.dart'
    if (dart.library.html) 'csv_export_web.dart'
    if (dart.library.io) 'csv_export_io.dart';

/// Downloads a CSV string as a file on the current platform.
///
///  - Web: triggers a browser download via a Blob + anchor click.
///  - IO (mobile/desktop): writes the file under a platform downloads
///    directory and returns the absolute path.
///  - Unsupported platforms: returns null (no-op).
///
/// Returns the saved file path when written locally, otherwise null.
Future<String?> downloadCsvFile({
  required String fileName,
  required String csv,
}) {
  return downloadCsv(fileName: fileName, csv: csv);
}

/// Escapes a single CSV field per RFC 4180: double quotes are doubled and
/// fields containing commas / quotes / newlines are quoted.
String csvField(String value) {
  final cleaned = value.replaceAll('"', '""');
  if (cleaned.contains(',') ||
      cleaned.contains('"') ||
      cleaned.contains('\n') ||
      cleaned.contains('\r')) {
    return '"$cleaned"';
  }
  return cleaned;
}

/// Joins a row of fields into one CSV line.
String csvRow(List<String> fields) => fields.map(csvField).join(',');
