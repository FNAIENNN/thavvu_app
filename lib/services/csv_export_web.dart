// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation: creates a Blob and clicks an invisible anchor so the
/// browser starts a normal file download (works on Chrome / Firefox / Safari).
Future<String?> downloadCsv({
  required String fileName,
  required String csv,
}) async {
  final bytes = Uint8List.fromList(csv.codeUnits);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return null; // Browser owns the download; no local path to report.
}
