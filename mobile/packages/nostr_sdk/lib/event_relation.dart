import 'aid.dart';
import 'event.dart';
import 'event_kind.dart';
import 'nip19/nip19.dart';
import 'nip19/nip19_tlv.dart';
import 'nip94/file_metadata.dart';
import 'utils/spider_util.dart';

/// This class is designed for get the relation from event, but it seam to used for get tagInfo from event before event_main display.
class EventRelation {
  late String id;

  late String pubkey;

  List<String> tagPList = [];

  List<String> tagEList = [];

  String? rootPubkey;

  String? rootId;

  String? rootRelayAddr;

  int? rootKind;

  String? replyId;

  String? replyRelayAddr;

  String? replyPubkey;

  int? replyKind;

  String? subject;

  bool warning = false;

  AId? aId;

  String? zapraiser;

  String? dTag;

  String? type;

  List<EventZapInfo> zapInfos = [];

  String? innerZapContent;

  Map<String, FileMetadata> fileMetadatas = {};

  String? get replyOrRootId {
    return replyId ?? rootId;
  }

  String? get replyOrRootRelayAddr {
    return replyId != null ? replyRelayAddr : rootRelayAddr;
  }

  EventRelation.fromEvent(Event event) {
    id = event.id;
    pubkey = event.pubkey;

    bool isComment = event.kind == EventKind.comment;

    Map<String, int> pMap = {};
    var length = event.tags.length;
    for (var i = 0; i < length; i++) {
      var tag = event.tags[i];

      var mentionStr = "#[$i]";
      if (event.content.contains(mentionStr)) {
        continue;
      }

      var tagLength = tag.length;
      if (tagLength > 1 && tag[1] is String) {
        var tagKey = tag[0];
        var value = tag[1] as String;
        if (tagKey == "p") {
          // check if is Text Note References
          var nip19Str = "nostr:${Nip19.encodePubKey(value)}";
          if (event.content.contains(nip19Str)) {
            continue;
          }
          nip19Str =
              "nostr:${NIP19Tlv.encodeNprofile(Nprofile(pubkey: value))}";
          if (event.content.contains(nip19Str)) {
            continue;
          }

          pMap[value] = 1;
        } else if (tagKey == "e") {
          if (isComment) {
            // is comment!
            // reply event id
            replyId = value;
            if (tagLength > 2) {
              replyRelayAddr = tag[2];
            }
            if (tagLength > 3) {
              replyPubkey = tag[3];
            }
          } else {
            // not comment or root event or old style comment
            if (tagLength > 3) {
              var marker = tag[3];
              if (marker == "root") {
                rootId = value;
                rootRelayAddr = tag[2];
                if (tagLength > 4) {
                  rootPubkey = tag[4];
                }
              } else if (marker == "reply") {
                replyId = value;
                replyRelayAddr = tag[2];
                if (tagLength > 4) {
                  replyPubkey = tag[4];
                }
              } else if (marker == "mention") {
                continue;
              }
            }
          }
          tagEList.add(value);
        } else if (tagKey == "subject" || tagKey == "title") {
          subject = value;
        } else if (tagKey == "content-warning") {
          warning = true;
        } else if (tagKey == "a") {
          aId = AId.fromString(value);
        } else if (tagKey == "zapraiser") {
          zapraiser = value;
        } else if (tagKey == "d") {
          dTag = value;
        } else if (tagKey == "type") {
          type = value;
        } else if (tagKey == "zap" && tagLength > 3) {
          var zapInfo = EventZapInfo.fromTags(tag);
          zapInfos.add(zapInfo);
        } else if (tagKey == "description" && event.kind == EventKind.zap) {
          innerZapContent = SpiderUtil.subUntil(value, '"content":"', '",');
        } else if (tagKey == "imeta") {
          var fileMetadata = FileMetadata.fromNIP92Tag(tag);
          if (fileMetadata != null) {
            fileMetadatas[fileMetadata.url] = fileMetadata;
          }
        } else if (tagKey == "K") {
          rootKind = int.tryParse(value);
        } else if (tagKey == "k") {
          replyKind = int.tryParse(value);
        } else if (tagKey == "P") {
          rootPubkey = value;
        } else if (tagKey == "p") {
          replyPubkey = value;
        } else if (isComment) {
          if (tagKey == "A" || tagKey == "E" || tagKey == "I") {
            if (tagKey == "A") {
              // don't handle now.
            } else if (tagKey == "E") {
              // root event id
              rootId = value;
              if (tagLength > 2) {
                rootRelayAddr = tag[2];
              }
              if (tagLength > 3) {
                rootPubkey = tag[3];
              }
              tagEList.add(value);
            } else if (tagKey == "I") {
              // don't handle now.
            }
          }
        }
      }
    }

    var tagELength = tagEList.length;
    if (tagELength == 1 && rootId == null && replyId == null) {
      rootId = tagEList[0];
    } else if (tagELength > 1) {
      if (rootId == null && replyId == null) {
        rootId = tagEList.first;
        replyId = tagEList.last;
      } else if (rootId != null && replyId == null) {
        for (var i = tagELength - 1; i > -1; i--) {
          var id = tagEList[i];
          if (id != rootId) {
            replyId = id;
          }
        }
      } else if (rootId == null && replyId != null) {
        for (var i = 0; i < tagELength; i++) {
          var id = tagEList[i];
          if (id != replyId) {
            rootId = id;
          }
        }
      } else {
        rootId ??= tagEList.first;
        replyId ??= tagEList.last;
      }
    }

    if (rootId != null && replyId == rootId && rootRelayAddr == null) {
      rootRelayAddr = replyRelayAddr;
    }

    pMap.remove(event.pubkey);
    tagPList.addAll(pMap.keys);
  }

  static String getInnerZapContent(Event event) {
    String innerContent = "";
    for (var tag in event.tags) {
      var tagLength = tag.length;
      if (tagLength > 1) {
        var k = tag[0];
        var v = tag[1];
        if (k == "description") {
          innerContent = SpiderUtil.subUntil(v, '"content":"', '",');
          break;
        }
      }
    }

    return innerContent;
  }
}

class EventZapInfo {
  late String pubkey;

  late String relayAddr;

  late double weight;

  EventZapInfo(this.pubkey, this.relayAddr, this.weight);

  factory EventZapInfo.fromTags(List tag) {
    var pubkey = tag[1] as String;
    var relayAddr = tag[2] as String;
    var sourceWeidght = tag[3];
    double weight = 1;
    if (sourceWeidght is String) {
      weight = double.parse(sourceWeidght);
    } else if (sourceWeidght is double) {
      weight = sourceWeidght;
    } else if (sourceWeidght is int) {
      weight = sourceWeidght.toDouble();
    }

    return EventZapInfo(pubkey, relayAddr, weight);
  }
}
