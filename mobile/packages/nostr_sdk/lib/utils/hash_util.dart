import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;

class HashUtil {
  static String md5(String source) {
    var content = const Utf8Encoder().convert(source);
    var digest = crypto.md5.convert(content);
    // digest.toString()
    return hex.encode(digest.bytes);
  }

  static String md5Bytes(List<int> content) {
    var digest = crypto.md5.convert(content);
    return hex.encode(digest.bytes);
  }

  static String sha1Bytes(List<int> content) {
    var digest = crypto.sha1.convert(content);
    return hex.encode(digest.bytes);
  }

  static String sha256Bytes(List<int> content) {
    var digest = crypto.sha256.convert(content);
    return hex.encode(digest.bytes);
  }
}
