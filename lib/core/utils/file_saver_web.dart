import 'dart:convert';

import 'package:web/web.dart' as web;

Future<String> saveBytes(List<int> bytes, String filename) async {
  final String encoded = base64Encode(bytes);
  final web.HTMLAnchorElement anchor =
      web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = 'data:application/octet-stream;base64,$encoded';
  anchor.download = filename;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return filename;
}
