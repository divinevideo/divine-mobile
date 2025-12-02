import 'package:mime/mime.dart';

import '../utils/string_util.dart';

class UploadUtil {
  static String getFileType(String filePath) {
    var fileType = lookupMimeType(filePath);
    if (StringUtil.isBlank(fileType)) {
      fileType = "image/jpeg";
    }

    return fileType!;
  }
}
