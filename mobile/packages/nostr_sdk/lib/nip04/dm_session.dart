import '../event.dart';
import '../event_mem_box.dart';

class DMSession {
  final String pubkey;

  EventMemBox _box = EventMemBox();

  DMSession({required this.pubkey});

  DMSession clone() {
    return DMSession(pubkey: pubkey).._box = _box;
  }

  bool addEvent(Event event) {
    return _box.add(event);
  }

  void addEvents(List<Event> events) {
    _box.addList(events);
  }

  Event? get newestEvent {
    return _box.newestEvent;
  }

  int length() {
    return _box.length();
  }

  Event? get(int index) {
    if (_box.length() <= index) {
      return null;
    }

    return _box.get(index);
  }

  int lastTime() {
    return _box.newestEvent!.createdAt;
  }
}
