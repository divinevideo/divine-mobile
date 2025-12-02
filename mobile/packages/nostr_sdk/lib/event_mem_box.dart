import 'event.dart';
import 'relay/relay.dart';
import 'utils/find_event_interface.dart';

/// a memory event box
/// use to hold event received from relay and offer event List to ui
class EventMemBox implements FindEventInterface {
  List<Event> _eventList = [];

  Map<String, Event> _idMap = {};

  bool sortAfterAdd;

  EventMemBox({this.sortAfterAdd = true});

  static EventMemBox clone(EventMemBox eventBox) {
    var emb = EventMemBox(sortAfterAdd: eventBox.sortAfterAdd);
    emb._eventList = eventBox._eventList;
    emb._idMap = eventBox._idMap;
    return emb;
  }

  @override
  List<Event> findEvent(String str, {int? limit = 5}) {
    List<Event> list = [];
    for (var event in _eventList) {
      if (event.content.contains(str)) {
        list.add(event);

        if (limit != null && list.length >= limit) {
          break;
        }
      }
    }
    return list;
  }

  Event? get newestEvent {
    if (_eventList.isEmpty) {
      return null;
    }
    return _eventList.first;
  }

  Event? get oldestEvent {
    if (_eventList.isEmpty) {
      return null;
    }
    return _eventList.last;
  }

  // find event oldest createdAt by relay
  OldestCreatedAtByRelayResult oldestCreatedAtByRelay(List<Relay> relays,
      [int? initTime]) {
    OldestCreatedAtByRelayResult result = OldestCreatedAtByRelayResult();
    Map<String, Relay> relayMap = {};
    for (var relay in relays) {
      relayMap[relay.url] = relay;
    }

    var length = _eventList.length;
    for (var index = length - 1; index > -1; index--) {
      var event = _eventList[index];
      if (event.cacheEvent) {
        // local event, don't handle sources
        continue;
      }

      for (var source in event.sources) {
        if (relayMap[source] != null) {
          // log("$source findCreatedAt $length $index ${length - index}");
          result.createdAtMap[source] = event.createdAt;
          relayMap.remove(source);
        }
      }

      if (relayMap.isEmpty) {
        break;
      }
    }

    if (relayMap.isNotEmpty && initTime != null) {
      for (var relay in relayMap.values) {
        result.createdAtMap[relay.url] = initTime;
      }
    }

    // count av createdAt
    var it = result.createdAtMap.values;
    var relayNum = it.length;
    double counter = 0;
    for (var value in it) {
      counter += value;
    }
    if (relayNum > 1) {
      result.avCreatedAt = counter ~/ relayNum;
    } else {
      result.avCreatedAt = counter.toInt();
    }

    return result;
  }

  void sort() {
    _eventList.sort((event1, event2) {
      return event2.createdAt - event1.createdAt;
    });
  }

  bool delete(String id) {
    if (_idMap[id] == null) {
      return false;
    }

    _idMap.remove(id);
    _eventList.removeWhere((element) => element.id == id);

    return true;
  }

  bool add(Event event) {
    var oldEvent = _idMap[event.id];
    if (oldEvent != null) {
      if (!event.cacheEvent && event.sources.isNotEmpty) {
        // only the remote event need to set sources
        if (oldEvent.cacheEvent) {
          // this event is local event, so clean the sources.
          oldEvent.sources.clear();
          // clean sources and this event isn't local event.
          oldEvent.cacheEvent = false;
        }
        if (!oldEvent.sources.contains(event.sources[0])) {
          oldEvent.sources.add(event.sources[0]);
        }
      }
      return false;
    }

    _idMap[event.id] = event;
    _eventList.add(event);
    if (sortAfterAdd) {
      sort();
    }
    return true;
  }

  bool addList(List<Event> list) {
    bool added = false;
    for (var event in list) {
      var oldEvent = _idMap[event.id];
      if (oldEvent == null) {
        _idMap[event.id] = event;
        _eventList.add(event);
        added = true;
      } else {
        if (event.sources.isNotEmpty &&
            !oldEvent.sources.contains(event.sources[0])) {
          oldEvent.sources.add(event.sources[0]);
        }
      }
    }

    if (added && sortAfterAdd) {
      sort();
    }

    return added;
  }

  void addBox(EventMemBox b) {
    var all = b.all();
    addList(all);
  }

  bool isEmpty() {
    return _eventList.isEmpty;
  }

  int length() {
    return _eventList.length;
  }

  List<Event> all() {
    return _eventList;
  }

  List<Event> listByPubkey(String pubkey) {
    List<Event> list = [];
    for (var event in _eventList) {
      if (event.pubkey == pubkey) {
        list.add(event);
      }
    }
    return list;
  }

  List<Event> suList(int start, int limit) {
    var length = _eventList.length;
    if (start > length) {
      return [];
    }
    if (start + limit > length) {
      return _eventList.sublist(start, length);
    }
    return _eventList.sublist(start, limit);
  }

  Event? get(int index) {
    if (_eventList.length < index) {
      return null;
    }

    return _eventList[index];
  }

  Event? getById(String id) {
    return _idMap[id];
  }

  void clear() {
    _eventList.clear();
    _idMap.clear();
  }
}

class OldestCreatedAtByRelayResult {
  Map<String, int> createdAtMap = {};

  int avCreatedAt = 0;
}
