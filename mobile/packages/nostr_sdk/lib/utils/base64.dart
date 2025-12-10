// ABOUTME: Utility class for base64 encoding/decoding of image data.
// ABOUTME: Handles data URI format detection and conversion for image uploads.

import 'dart:convert';
import 'dart:typed_data';

class Base64Util {
  static const String pngPrefix = "data:image/png;base64,";

  static const String prefix = "data:image/";

  static bool check(String str) {
    return str.indexOf(prefix) == 0;
  }

  static Uint8List toData(String base64Str) {
    var text = base64Str.replaceFirst(prefix, "");
    var index = text.indexOf(";base64,");
    if (index > -1) {
      text = text.substring(index + 8);
    }
    return const Base64Decoder().convert(text);
  }

  static String toBase64(Uint8List data) {
    var base64Str = base64Encode(data);
    return "${Base64Util.pngPrefix}$base64Str";
  }
}
