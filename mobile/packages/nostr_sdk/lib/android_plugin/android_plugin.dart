import 'package:flutter/services.dart';

import 'android_plugin_activity_result.dart';
import 'android_plugin_intent.dart';

class AndroidPlugin {
  static const MethodChannel _channel = MethodChannel('nostrmoPlugin');

  static Future<String?> getPlatformVersion() async {
    return await _channel.invokeMethod<String>("getPlatformVersion");
  }

  static Future<bool?> existAndroidNostrSigner() async {
    return await _channel.invokeMethod<bool>("existAndroidNostrSigner");
  }

  static Future<AndroidPluginActivityResult?> startForResult(
      AndroidPluginIntent intent) async {
    var resultMap = await _channel.invokeMethod<Map>(
        "startActivityForResult", intent.toArgs());
    if (resultMap != null) {
      var intent = AndroidPluginIntent();
      var intentMap = resultMap["intent"];

      if (intentMap != null) {
        {
          var value = intentMap["action"];
          if (value != null) {
            intent.setAction(value);
          }
        }
        {
          var value = intentMap["package"];
          if (value != null) {
            intent.setPackage(value);
          }
        }
        {
          var value = intentMap["data"];
          if (value != null) {
            intent.setData(value);
          }
        }
        {
          var value = intentMap["flags"];
          if (value != null) {
            intent.addFlag(value);
          }
        }
        {
          var value = intentMap["categories"];
          if (value != null) {
            intent.addCategory(value);
          }
        }
        {
          var value = intentMap["type"];
          if (value != null) {
            intent.setType(value);
          }
        }
        {
          var value = intentMap["extras"];
          if (value != null && value is Map) {
            var entries = value.entries;
            for (var entry in entries) {
              var key = entry.key;
              var value = entry.value;
              if (key is String) {
                intent.putExtra(key, value, setType: false);
              }
            }
          }
        }

        var resultCode = resultMap["resultCode"];
        return AndroidPluginActivityResult(resultCode, intent);
      }
    }

    return null;
  }
}
