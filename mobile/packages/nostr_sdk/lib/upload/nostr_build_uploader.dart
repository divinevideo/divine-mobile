// ABOUTME: Handles file uploads to nostr.build media hosting service.
// ABOUTME: Provides shared Dio instance and upload functionality for Nostr media.

import 'package:dio/dio.dart';

import '../utils/base64.dart';

class NostrBuildUploader {
  static var dio = Dio();

  static const String uploadAction = "https://nostr.build/api/v2/upload/files";

  static Future<String?> upload(String filePath, {String? fileName}) async {
    MultipartFile? multipartFile;
    if (Base64Util.check(filePath)) {
      var bytes = Base64Util.toData(filePath);
      multipartFile = MultipartFile.fromBytes(bytes, filename: fileName);
    } else {
      multipartFile = await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      );
    }

    var formData = FormData.fromMap({"file": multipartFile});
    var response = await dio.post(uploadAction, data: formData);
    var body = response.data;
    if (body is Map<String, dynamic> && body["status"] == "success") {
      return body["data"][0]["url"];
    }

    return null;
  }
}
