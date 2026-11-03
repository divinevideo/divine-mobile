import 'package:models/models.dart' show AudioEvent;

/// Divine's sounds for a list: the ones the app ships, each tied to the event
/// Divine published for it, then the published ones the app does not ship.
///
/// A published sound names the shipped sound it stands for in its
/// [AudioEvent.divineSoundId]. The shipped sound keeps its local file, for
/// instant and offline playback, and takes the event's id as its
/// [AudioEvent.linkedEventId], so a video made with it references the event
/// instead of passing the audio off as its creator's own. A shipped sound
/// with no published event stays as it is. When Divine published one sound
/// more than once, the newest event in [published] (which comes newest
/// first) is the one it is tied to, and the others are dropped.
List<AudioEvent> linkDivineSounds({
  required List<AudioEvent> shipped,
  required List<AudioEvent> published,
}) {
  const shippedPrefix = '${AudioEvent.bundledMarker}_';
  final shippedIds = {
    for (final sound in shipped)
      if (sound.id.startsWith(shippedPrefix))
        sound.id.substring(shippedPrefix.length),
  };
  final eventByShippedId = <String, AudioEvent>{};
  final notShipped = <AudioEvent>[];
  for (final event in published) {
    final shippedId = event.divineSoundId;
    if (shippedId != null && shippedIds.contains(shippedId)) {
      eventByShippedId.putIfAbsent(shippedId, () => event);
    } else {
      notShipped.add(event);
    }
  }
  return [
    for (final sound in shipped)
      switch (eventByShippedId[sound.id.replaceFirst(shippedPrefix, '')]) {
        final event? => sound.copyWith(linkedEventId: event.id),
        null => sound,
      },
    ...notShipped,
  ];
}
