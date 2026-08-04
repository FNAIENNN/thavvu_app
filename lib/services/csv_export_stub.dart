/// Fallback stub for platforms that are neither web nor io (should not
/// happen in practice). Keeps the conditional import graph complete.
Future<String?> downloadCsv({
  required String fileName,
  required String csv,
}) async {
  return null;
}
