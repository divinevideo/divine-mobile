import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'platform_util.dart';

class DBUtil {
  // static Future<String> getPath(String dbName) async {
  //   String path = dbName;

  //   if (!PlatformUtil.isWeb()) {
  //     if (Platform.isLinux) {
  //       var databasesPath = Platform.environment["HOME"];
  //       path = join(databasesPath!, ".dart_tool", "sqflite_common_ffi",
  //           "databases", dbName);
  //     } else {
  //       var databasesPath = await getDatabasesPath();
  //       path = join(databasesPath, dbName);
  //     }
  //   }

  //   return path;
  // }
  static Future<String> getPath(
    String appName,
    String dbName,
  ) async {
    String path = dbName;

    if (!PlatformUtil.isWeb()) {
      var docDir = await getApplicationDocumentsDirectory();
      var docDirPath = docDir.absolute.path;
      return join(docDirPath, appName, "database", dbName);
    }

    return path;
  }
}
