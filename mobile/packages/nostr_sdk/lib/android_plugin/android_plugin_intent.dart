import '../utils/string_util.dart';

/// AndroidPluginIntnet
/// Some code are from https://pub.dev/packages/intent
class AndroidPluginIntent {
  String? _action;
  String? _type;
  String? _package;
  String? _data;
  late List<String> _category;
  late List<int> _flag;
  late Map<String, dynamic> _extra;
  late Map<String, String> _typeInfo;

  AndroidPluginIntent() {
    _category = [];
    _flag = [];
    _extra = {};
    _typeInfo = {};
  }

  /// Adds category for this intent
  ///
  /// Supported values can be found in Category class
  addCategory(String category) => _category.add(category);

  List<String> getCategory() {
    return _category;
  }

  /// Sets flags for intent
  ///
  /// Get possible flag values from Flag class
  addFlag(int flag) => _flag.add(flag);

  List<int> getFlag() {
    return _flag;
  }

  /// Aims to handle type information for extra data attached
  /// encodes type information as string, passed through PlatformChannel,
  /// and finally gets unpacked in platform specific code ( Kotlin )
  ///
  /// TypedExtra class holds predefined constants ( type information ),
  /// consider using those
  putExtra(String extra, dynamic data, {String? type, bool setType = true}) {
    _extra[extra] = data;
    if (type != null) {
      _typeInfo[extra] = type;
    } else {
      if (setType) {
        if (data is bool) {
          type = "boolean";
          // } else if (data is bool) {
          //   type = "byte";
          // } else if (data is bool) {
          //   type = "short";
        } else if (data is int) {
          type = "int";
          // } else if (data is bool) {
          //   type = "long";
          // } else if (data is bool) {
          //   type = "float";
        } else if (data is double) {
          type = "double";
          // } else if (data is bool) {
          //   type = "char";
        } else if (data is String) {
          type = "String";
        } else if (data is List<bool>) {
          type = "boolean[]";
          // } else if (data is bool) {
          //   type = "byte[]";
          // } else if (data is bool) {
          //   type = "short[]";
        } else if (data is List<int>) {
          type = "int[]";
          // } else if (data is bool) {
          //   type = "long[]";
          // } else if (data is bool) {
          //   type = "float[]";
        } else if (data is List<double>) {
          type = "double[]";
          // } else if (data is bool) {
          //   type = "char[]";
        } else if (data is List<String>) {
          type = "String[]";
        }

        if (StringUtil.isNotBlank(type)) {
          _typeInfo[extra] = type!;
        }
      }
    }
  }

  /// Sets what action this intent is supposed to do
  ///
  /// Possible values can be found in Action class
  setAction(String action) => _action = action;

  String? getAction() {
    return _action;
  }

  /// Sets data type or mime-type
  setType(String type) => _type = type;

  String? getType() {
    return _type;
  }

  /// Explicitly sets package information using which
  /// Intent to be resolved, preventing chooser from showing up
  setPackage(String package) => _package = package;

  String? getPackage() {
    return _package;
  }

  /// Sets data, on which intent will perform selected action
  setData(String data) => _data = data;

  String? getData() {
    return _data;
  }

  dynamic getExtra(String key) {
    return _extra[key];
  }

  Map<String, dynamic> toArgs() {
    Map<String, dynamic> parameters = {};

    if (_action != null) parameters['action'] = _action;
    if (_type != null) parameters['type'] = _type;
    if (_package != null) parameters['package'] = _package;
    if (_data != null) parameters['data'] = _data;
    if (_category.isNotEmpty) parameters['category'] = _category;
    if (_flag.isNotEmpty) parameters['flag'] = _flag;
    if (_extra.isNotEmpty) parameters['extra'] = _extra;
    if (_typeInfo.isNotEmpty) parameters['typeInfo'] = _typeInfo;

    return parameters;
  }
}
