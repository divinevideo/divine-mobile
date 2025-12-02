import '../event.dart';
import '../utils/string_util.dart';

class TorrentInfo {
  String? title;

  String btih;

  List<String>? trackers;

  List<TorrentFileInfo>? files;

  List<String>? references;

  List<String>? tags;

  TorrentInfo({
    this.title,
    required this.btih,
    this.trackers,
    this.files,
    this.references,
    this.tags,
  });

  static TorrentInfo? fromEvent(Event event) {
    String? title;
    String? btih;
    List<String> trackers = [];
    List<TorrentFileInfo> files = [];
    List<String> references = [];
    List<String> tags = [];

    for (var tag in event.tags) {
      var tagLength = tag.length;
      if (tagLength > 1) {
        var k = tag[0];
        var v = tag[1];

        if (StringUtil.isBlank(v)) {
          continue;
        }

        if (k == "title") {
          title = v;
        } else if (k == "x" || k == "btih") {
          btih = v;
        } else if (k == "tracker") {
          trackers.add(v);
        } else if (k == "file") {
          if (tagLength > 2) {
            var size = int.tryParse(tag[2]);
            if (size == null) {
              var sizeDouble = double.tryParse(tag[2]);
              if (sizeDouble != null) {
                size = sizeDouble.toInt();
              }
            }

            size ??= 0;
            if (v is String && v.contains("padding_file")) {
              continue;
            }

            files.add(TorrentFileInfo(v, size));
          }
        } else if (k == "i") {
          references.add(v);
        } else if (k == "t") {
          tags.add(v);
        }
      }
    }

    if (StringUtil.isBlank(btih)) {
      return null;
    }

    return TorrentInfo(
      btih: btih!,
      title: title,
      trackers: trackers,
      files: files,
      references: references,
      tags: tags,
    );
  }
}

class TorrentFileInfo {
  String file;

  int size;

  TorrentFileInfo(this.file, this.size);
}
