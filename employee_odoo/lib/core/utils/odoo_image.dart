import 'dart:convert';

/// Validates Odoo base64 image fields before [MemoryImage] decode.
class OdooImage {
  OdooImage._();

  static String? sanitize(dynamic value) {
    if (value == false || value == null) return null;
    if (value is! String || value.trim().isEmpty) return null;

    final raw = value.trim();
    try {
      final bytes = base64Decode(raw);
      if (bytes.isEmpty || !_looksLikeImage(bytes)) return null;
      return raw;
    } catch (_) {
      return null;
    }
  }

  static bool _looksLikeImage(List<int> bytes) {
    if (bytes.length < 4) return false;
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WebP (RIFF....WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }
}
