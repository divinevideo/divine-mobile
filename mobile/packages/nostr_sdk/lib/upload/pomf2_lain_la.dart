import 'package:dio/dio.dart';
import 'package:nostr_sdk/upload/upload_util.dart';
import 'package:http_parser/src/media_type.dart';

import '../utils/base64.dart';
import 'nostr_build_uploader.dart';

class Pomf2LainLa {
  static const String UPLOAD_ACTION = "https://pomf2.lain.la/upload.php";

  static Future<String?> upload(String filePath, {String? fileName}) async {
    // final dio = Dio();
    // dio.interceptors.add(PrettyDioLogger(requestBody: true));
    var fileType = UploadUtil.getFileType(filePath);
    MultipartFile? multipartFile;
    if (BASE64.check(filePath)) {
      var bytes = BASE64.toData(filePath);
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
    var response =
        await NostrBuildUploader.dio.post(UPLOAD_ACTION, data: formData);
    var body = response.data;
    if (body is Map<String, dynamic>) {
      return body["files"][0]["url"];
    }
    return null;
  }
}
