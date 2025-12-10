import 'client_connected.dart';
import 'relay_type.dart';

class RelayStatus {
  int relayType;

  String addr;

  bool writeAccess;

  bool readAccess;

  bool alwaysAuth;

  RelayStatus(
    this.addr, {
    this.relayType = RelayType.normal,
    this.writeAccess = true,
    this.readAccess = true,
    this.alwaysAuth = false,
  });

  int connected = ClientConnected.disconnect;

  // bool noteAble = true;
  // bool dmAble = true;
  // bool profileAble = true;
  // bool globalAble = true;

  int _noteReceived = 0;

  int get noteReceived => _noteReceived;

  bool authed = false;

  void noteReceive({DateTime? dt}) {
    _noteReceived++;
    dt ??= DateTime.now();
    lastNoteTime = dt;
  }

  int _queryNum = 0;

  int get queryNum => _queryNum;

  void onQuery({DateTime? dt}) {
    _queryNum++;
    dt ??= DateTime.now();
    lastQueryTime = dt;
  }

  int _error = 0;

  int get error => _error;

  void onError({DateTime? dt}) {
    _error++;
    dt ??= DateTime.now();
    lastErrorTime = dt;
  }

  DateTime connectTime = DateTime.now();

  DateTime? lastQueryTime;

  DateTime? lastNoteTime;

  DateTime? lastErrorTime;
}
