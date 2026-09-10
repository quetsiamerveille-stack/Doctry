import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PickedMedia {
  const PickedMedia({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
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
    return PickedMedia(bytes: bytes, filename: _safeName(file.name));
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
    return allowed.contains(extension) ? name : '${name.substring(0, dot)}.jpg';
  }
}
