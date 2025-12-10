import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

import '../event.dart';
import '../event_kind.dart';
import '../nip96/nip96_info_loader.dart';
import '../nostr.dart';
import '../utils/base64.dart';
import '../utils/hash_util.dart';
import '../utils/string_util.dart';

class NIP96Uploader {
  static var dio = Dio();

  static Future<String?> upload(
    Nostr nostr,
    String serverUrl,
    String filePath, {
    String? fileName,
  }) async {
    var sa = await NIP96InfoLoader.getInstance().getServerAdaptation(serverUrl);
    if (sa == null || StringUtil.isBlank(sa.apiUrl)) {
      return null;
    }
    // log(jsonEncode(sa.toJson()));

    bool isNip98Required = false;
    if (sa.plans != null &&
        sa.plans != null &&
        sa.plans!.free != null &&
        sa.plans!.free!.isNip98Required != null) {
      isNip98Required = sa.plans!.free!.isNip98Required!;
    }

    String? payload;
    MultipartFile? multipartFile;
    Uint8List? bytes;
    if (Base64Util.check(filePath)) {
      bytes = Base64Util.toData(filePath);
    } else {
      var file = File(filePath);
      bytes = file.readAsBytesSync();

      if (StringUtil.isBlank(fileName)) {
        fileName = filePath.split("/").last;
      }
    }

    if (bytes.isEmpty) {
      return null;
    }

    // log("file size is ${bytes.length}");

    payload = HashUtil.sha256Bytes(bytes);
    multipartFile = MultipartFile.fromBytes(bytes, filename: fileName);

    Map<String, String>? headers = {};
    if (StringUtil.isNotBlank(fileName)) {
      var mt = lookupMimeType(fileName!);
      if (StringUtil.isNotBlank(mt)) {
        headers["Content-Type"] = mt!;
      }
    }
    if (StringUtil.isBlank(headers["Content-Type"])) {
      if (multipartFile.contentType != null) {
        headers["Content-Type"] = multipartFile.contentType!.mimeType;
      } else {
        headers["Content-Type"] = "multipart/form-data";
      }
    }

    if (isNip98Required) {
      var tags = [];
      tags.add(["u", sa.apiUrl]);
      tags.add(["method", "POST"]);
      if (StringUtil.isNotBlank(payload)) {
        tags.add(["payload", payload]);
      }
      var nip98Event = Event(nostr.publicKey, EventKind.httpAuth, tags, "");

      await nostr.signEvent(nip98Event);
      // log(jsonEncode(nip98Event.toJson()));
      // NIP-98 spec requires standard base64 encoding (not base64url)
      headers["Authorization"] =
          "Nostr ${base64.encode(utf8.encode(jsonEncode(nip98Event.toJson())))}";

      // log(jsonEncode(headers));
    }

    var formData = FormData.fromMap({"file": multipartFile});
    // log(formData.toString());
    try {
      var response = await dio.post(
        sa.apiUrl!,
        data: formData,
        options: Options(headers: headers),
      );
      var body = response.data;
      // log(jsonEncode(response.data));
      if (body is Map<String, dynamic> &&
          body["status"] == "success" &&
          body["nip94_event"] != null) {
        var nip94Event = body["nip94_event"];
        if (nip94Event["tags"] != null) {
          for (var tag in nip94Event["tags"]) {
            if (tag is List && tag.length > 1) {
              var k = tag[0];
              var v = tag[1];

              if (k == "url") {
                return v;
              }
            }
          }
        }
      }
    } catch (e) {
      log("nostr.build nip96 upload exception:");
      log('$e');
    }

    return null;
  }
}
