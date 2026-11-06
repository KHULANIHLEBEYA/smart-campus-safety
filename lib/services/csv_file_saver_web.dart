import 'dart:convert';
import 'dart:html' as html;

/// Trigger a browser download without requiring a native MethodChannel.
Future<bool> downloadCsvFile(String fileName, String contents) async {
  final blob = html.Blob(
    <Object>[utf8.encode(contents)],
    'text/csv;charset=utf-8',
  );
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: objectUrl)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  // Give Chrome time to start reading the blob before releasing its URL.
  Future<void>.delayed(const Duration(seconds: 1), () {
    html.Url.revokeObjectUrl(objectUrl);
  });
  return true;
}
