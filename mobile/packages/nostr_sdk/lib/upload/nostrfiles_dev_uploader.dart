// ABOUTME: Handles file uploads to nostrfiles.dev media hosting service.
// ABOUTME: Supports base64 and file path inputs for image uploads.

import 'package:dio/dio.dart';

import '../utils/base64.dart';

class NostrfilesDevUploader {
  static var dio = Dio();

  static const String uploadAction = "https://nostrfiles.dev/upload_image";

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
    if (body is Map<String, dynamic>) {
      return body["url"] as String;
    }

    return null;
  }
}
