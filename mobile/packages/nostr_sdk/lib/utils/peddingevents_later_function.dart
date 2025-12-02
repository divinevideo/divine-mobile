import '../event.dart';

mixin PenddingEventsLaterFunction {
  int laterTimeMS = 200;

  bool latering = false;

  List<Event> penddingEvents = [];

  bool _running = true;

  void later(Event event, Function(List<Event>) func, Function? completeFunc) {
    penddingEvents.add(event);
    if (latering) {
      return;
    }

    latering = true;
    Future.delayed(Duration(milliseconds: laterTimeMS), () {
      if (!_running) {
        return;
      }

      latering = false;
      func(penddingEvents);
      penddingEvents.clear();
      if (completeFunc != null) {
        completeFunc();
      }
    });
  }

  void disposeLater() {
    _running = false;
  }
}
