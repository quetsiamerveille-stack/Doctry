import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> saveBytes(List<int> bytes, String filename) async {
  Directory? base;
  try {
    base = await getDownloadsDirectory();
  } catch (_) {
    base = null;
  }
  if (base == null) {
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
  }
  base ??= await getApplicationDocumentsDirectory();

  final Directory folder = Directory('${base.path}${Platform.pathSeparator}DOCTRY');
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final File file = File('${folder.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
