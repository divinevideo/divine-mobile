class SpiderUtil {
  static String subUntil(String content, String before, String end) {
    var beforeLength = before.length;
    var index = content.indexOf(before);
    if (index < 0) {
      return "";
    }

    var index2 = content.indexOf(end, index + beforeLength);
    if (index2 <= 0) {
      return "";
    }

    return content.substring(index + beforeLength, index2);
  }
}
