// ABOUTME: Handles file uploads to void.cat media hosting service.
// ABOUTME: Supports base64 and file path inputs with SHA-256 digest verification.

import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:nostr_sdk/upload/upload_util.dart';

import '../utils/base64.dart';
import '../utils/string_util.dart';
import 'nostr_build_uploader.dart';

class VoidCatUploader {
  static const String uploadAction = "https://void.cat/upload?cli=true";

  static Future<String?> upload(String filePath, {String? fileName}) async {
    var extName = "";

    Uint8List? bytes;
    if (Base64Util.check(filePath)) {
      bytes = Base64Util.toData(filePath);
    } else {
      var tempFile = File(filePath);
      bytes = await tempFile.readAsBytes();

      if (StringUtil.isBlank(fileName)) {
        fileName = filePath.split("/").last;
      }
    }

    if (StringUtil.isNotBlank(fileName)) {
      extName = fileName!.split(".").last;
    }

    var digest = sha256.convert(bytes);
    var fileHex = hex.encode(digest.bytes);

    Map<String, dynamic> headers = {};
    headers["content-type"] = "application/octet-stream";
    headers["v-full-digest"] = fileHex;

    var fileType = UploadUtil.getFileType(filePath);
    headers["v-content-type"] = fileType;
    if (StringUtil.isNotBlank(fileName)) {
      headers["V-Filename"] = fileName;
    }

    var response = await NostrBuildUploader.dio.post<String>(
      uploadAction,
      data: Stream.fromIterable(bytes.map((e) => [e])),
      options: Options(headers: headers),
    );
    var body = response.data;

    if (body != null && body.contains('"ok":false')) {
      return null;
    }

    if (StringUtil.isNotBlank(body) && StringUtil.isNotBlank(extName)) {
      body = "$body.$extName";
    }

    return body;
  }
}
