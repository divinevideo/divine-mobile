import '../event.dart';

abstract class EventFilter {
  // if this event should be filter, return true;
  bool check(Event e);
}
