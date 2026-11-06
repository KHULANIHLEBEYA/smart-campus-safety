import 'csv_file_saver_stub.dart'
    if (dart.library.html) 'csv_file_saver_web.dart' as platform;

/// Downloads a CSV in browser targets. Native Android uses the Save As picker
/// channel directly from the incident register instead.
Future<bool> downloadCsvFile(String fileName, String contents) {
  return platform.downloadCsvFile(fileName, contents);
}
