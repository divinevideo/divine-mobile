// ABOUTME: Handles file uploads to pomf2.lain.la media hosting service.
// ABOUTME: Supports base64 and file path inputs with content type detection.

import 'package:dio/dio.dart';
import 'package:nostr_sdk/upload/upload_util.dart';
import 'package:http_parser/http_parser.dart';

import '../utils/base64.dart';
import 'nostr_build_uploader.dart';

class Pomf2LainLa {
  static const String uploadAction = "https://pomf2.lain.la/upload.php";

  static Future<String?> upload(String filePath, {String? fileName}) async {
    var fileType = UploadUtil.getFileType(filePath);
    MultipartFile? multipartFile;
    if (Base64Util.check(filePath)) {
      var bytes = Base64Util.toData(filePath);
      multipartFile = MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType.parse(fileType),
      );
    } else {
      multipartFile = await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse(fileType),
      );
    }

    var formData = FormData.fromMap({"files[]": multipartFile});
    var response = await NostrBuildUploader.dio.post(
      uploadAction,
      data: formData,
    );
    var body = response.data;
    if (body is Map<String, dynamic>) {
      return body["files"][0]["url"];
    }
    return null;
  }
}
