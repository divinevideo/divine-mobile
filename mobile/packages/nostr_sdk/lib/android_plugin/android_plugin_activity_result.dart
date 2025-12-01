import 'android_plugin_intent.dart';

class AndroidPluginActivityResult {
  int? resultCode;

  AndroidPluginIntent data;

  AndroidPluginActivityResult(this.resultCode, this.data);
}
