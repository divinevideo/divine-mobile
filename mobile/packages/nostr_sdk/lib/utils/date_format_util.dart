class DateFormatUtil {
  static String format(int t) {
    var dt = DateTime.fromMillisecondsSinceEpoch(t * 1000);
    return "${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute}";
  }
}
