import 'dart:isolate';

import 'event.dart';

/// An event check isolate. There are some test code, it may be deleted by some reason.
class EventSignChecker {
  final int workernum;

  Function(EventSignCheckArg)? onEventSignChecked;

  EventSignChecker._internal({required this.workernum});

  static EventSignChecker init(int workerNum) {
    var checker = EventSignChecker._internal(workernum: workerNum);
    checker._run();
    return checker;
  }

  void checkEvent(EventSignCheckArg arg) {
    var sp = _sendPorts[_index];
    sp.send(arg);

    _index++;
    _index = _index % _length;
  }

  int _index = 0;

  int _length = 0;

  final List<SendPort> _sendPorts = [];

  void _run() {
    for (var i = 0; i < workernum; i++) {
      ReceivePort subToMainReceivePort = ReceivePort();
      var subToMainSendPort = subToMainReceivePort.sendPort;
      // list sub to main message
      subToMainListener(subToMainReceivePort);
      // run a sub isolate
      Isolate.spawn(eventSignCheckWorker, subToMainSendPort);
    }
  }

  void subToMainListener(ReceivePort receivePort) {
    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPorts.add(message);
        _length = _sendPorts.length;
      } else if (message is EventSignCheckArg) {
        // this must be an checked event
        print("message check return from sub!");
        print(onEventSignChecked);
        if (onEventSignChecked != null) {
          onEventSignChecked!(message);
        }
      }
    });
  }

  void eventSignCheckWorker(SendPort subToMainSendPort) {
    ReceivePort mainToSubReceivePort = ReceivePort();
    var mainToSubSendPort = mainToSubReceivePort.sendPort;
    subToMainSendPort.send(mainToSubSendPort);

    mainToSubReceivePort.listen((message) {
      if (message is EventSignCheckArg) {
        // this is an event need checked
        if (message.event.isValid && message.event.isSigned) {
          // check success, send it back.
          print("message check success!");
          subToMainSendPort.send(message);
        } else {
          print("oh no! message check fail!");
        }
      }
    });
  }
}

class EventSignCheckArg {
  String subId;

  Event event;

  EventSignCheckArg({
    required this.subId,
    required this.event,
  });
}
