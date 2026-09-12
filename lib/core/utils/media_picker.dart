import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PickedMedia {
  const PickedMedia({required this.bytes, required this.filename, required this.mimeType});

  final List<int> bytes;
  final String filename;
  final String mimeType;
}

class MediaPicker {
  const MediaPicker._();

  static final ImagePicker _picker = ImagePicker();

  static Future<PickedMedia?> pick(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (file == null) {
      return null;
    }
    final Uint8List bytes = await file.readAsBytes();
    return PickedMedia(
      bytes: bytes,
      filename: _safeName(file.name),
      mimeType: _mimeFor(_safeName(file.name)),
    );
  }

  static String _mimeFor(String filename) {
    final String lower = filename.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static String _safeName(String value) {
    final String name = value.replaceAll('\\', '/').split('/').last.trim();
    if (name.isEmpty) {
      return 'doctry.jpg';
    }
    final int dot = name.lastIndexOf('.');
    if (dot <= 0) {
      return '$name.jpg';
    }
    final String extension = name.substring(dot).toLowerCase();
    const List<String> allowed = <String>['.jpg', '.jpeg', '.png', '.webp', '.bmp'];
    if (!allowed.contains(extension)) {
      return '${name.substring(0, dot)}.jpg';
    }
    if (extension == '.bmp') {
      // Le backend n'accepte pas le BMP : on renomme en jpg par precaution.
      return '${name.substring(0, dot)}.jpg';
    }
    return name;
  }
}
