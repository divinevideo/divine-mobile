import '../event.dart';
import '../event_kind.dart' as kind;
import '../utils/string_util.dart';

class BadgeDefinition {
  final String pubkey;

  final String d;

  final String? name;

  final String? description;

  final String? image;

  final String? thumb;

  final int updatedAt;

  BadgeDefinition(
    this.pubkey,
    this.d,
    this.updatedAt, {
    this.name,
    this.description,
    this.image,
    this.thumb,
  });

  static BadgeDefinition? loadFromEvent(Event event) {
    String pubkey = event.pubkey;
    String? d;
    String? name;
    String? description;
    String? image;
    String? thumb;

    if (event.kind == kind.EventKind.badgeDefinition) {
      for (var tag in event.tags) {
        if (tag.length > 1) {
          var key = tag[0];
          var value = tag[1];
          if (key == "d") {
            d = value;
          } else if (key == "name") {
            name = value;
          } else if (key == "description") {
            description = value;
          } else if (key == "image") {
            image = value;
          } else if (key == "thumb") {
            thumb = value;
          }
        }
      }

      if (StringUtil.isNotBlank(d)) {
        return BadgeDefinition(
          pubkey,
          d!,
          event.createdAt,
          name: name,
          description: description,
          image: image,
          thumb: thumb,
        );
      }
    }
    return null;
  }
}
