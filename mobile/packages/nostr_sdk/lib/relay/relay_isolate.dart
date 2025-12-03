import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'client_connected.dart';
import 'relay.dart';
import 'relay_isolate_worker.dart';

// The real relay, whick is run in other isolate.
// It can move jsonDecode and event id check and sign check from main Isolate
class RelayIsolate extends Relay {
  bool eventSignCheck;

  String? relayNetwork;

  RelayIsolate(
    super.url,
    super.relayStatus, {
    this.eventSignCheck = false,
    this.relayNetwork,
  });

  Isolate? isolate;

  ReceivePort? subToMainReceivePort;

  SendPort? mainToSubSendPort;

  Completer<bool>? relayConnectResultComplete;

  @override
  Future<bool> doConnect() async {
    if (subToMainReceivePort == null) {
      relayStatus.connected = ClientConnected.CONNECTING;
      getRelayInfo(url);

      // never run isolate, begin to run
      subToMainReceivePort = ReceivePort("relay_stm_$url");
      subToMainListener(subToMainReceivePort!);

      relayConnectResultComplete = Completer();
      isolate = await Isolate.spawn(
        RelayIsolateWorker.runRelayIsolate,
        RelayIsolateConfig(
          url: url,
          subToMainSendPort: subToMainReceivePort!.sendPort,
          eventCheck: eventSignCheck,
          network: relayNetwork,
        ),
      );
      // isolate has run and return a completer.future, wait for subToMain msg to complete this completer.
      return await relayConnectResultComplete!.future;
    } else {
      // the isolate had bean run
      if (relayStatus.connected == ClientConnected.CONNECTED) {
        // relay has bean connected, return true, but also send a connect message.
        mainToSubSendPort!.send(RelayIsolateMsgs.CONNECT);
        return true;
      } else {
        // haven't connected
        if (relayConnectResultComplete != null) {
          return relayConnectResultComplete!.future;
        } else {
          // this maybe relay had disconnect after connected, try to connected again.
          if (mainToSubSendPort != null) {
            relayStatus.connected = ClientConnected.CONNECTING;
            // send connect msg
            mainToSubSendPort!.send(RelayIsolateMsgs.CONNECT);
            // wait connected msg.
            relayConnectResultComplete = Completer();
            return await relayConnectResultComplete!.future;
          }
        }
      }
    }

    return false;
  }

  @override
  Future<void> disconnect() async {
    if (relayStatus.connected != ClientConnected.DISCONNECT) {
      relayStatus.connected = ClientConnected.DISCONNECT;
      if (mainToSubSendPort != null) {
        mainToSubSendPort!.send(RelayIsolateMsgs.DIS_CONNECT);
      }
    }
  }

  @override
  bool send(List message, {bool? forceSend}) {
    if (forceSend == true ||
        (mainToSubSendPort != null &&
            relayStatus.connected == ClientConnected.CONNECTED)) {
      // Defensive serialization: Ensure all data is JSON-serializable
      final sanitizedMessage = sanitizeForJson(message);
      final encoded = jsonEncode(sanitizedMessage);
      // log(encoded);
      mainToSubSendPort!.send(encoded);
      return true;
    }

    return false;
  }

  /// Recursively sanitize data structures to ensure JSON serializability
  dynamic sanitizeForJson(dynamic data) {
    if (data == null) {
      return null;
    } else if (data is String || data is num || data is bool) {
      return data;
    } else if (data is List) {
      return data.map((item) => sanitizeForJson(item)).toList();
    } else if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        // Ensure keys are strings
        final stringKey = key.toString();
        result[stringKey] = sanitizeForJson(value);
      });
      return result;
    } else {
      // For any other type, try to convert to JSON-compatible format
      try {
        // If it has a toJson method, use it
        if (data is dynamic && data.toJson != null) {
          return sanitizeForJson(data.toJson());
        }
      } catch (e) {
        // Ignore toJson errors and fall through
      }

      // As last resort, convert to string
      return data.toString();
    }
  }

  void subToMainListener(ReceivePort receivePort) {
    receivePort.listen((message) {
      if (message is int) {
        // this is const msg.
        // print("msg is $message $url");
        if (message == RelayIsolateMsgs.CONNECTED) {
          // print("$url receive connected status!");
          relayStatus.connected = ClientConnected.CONNECTED;
          if (relayStatusCallback != null) {
            relayStatusCallback!();
          }
          _relayConnectComplete(true);
        } else if (message == RelayIsolateMsgs.DIS_CONNECTED) {
          onError("Websocket error $url", reconnect: true);
          _relayConnectComplete(false);
        }
      } else if (message is List && onMessage != null) {
        onMessage!(this, message);
      } else if (message is SendPort) {
        mainToSubSendPort = message;
      }
    });
  }

  void _relayConnectComplete(bool result) {
    if (relayConnectResultComplete != null) {
      relayConnectResultComplete!.complete(result);
      relayConnectResultComplete = null;
    }
  }

  @override
  void dispose() {
    if (isolate != null) {
      isolate!.kill();
    }
  }
}

class RelayIsolateConfig {
  final String url;
  final SendPort subToMainSendPort;
  final bool eventCheck;
  String? network;

  RelayIsolateConfig({
    required this.url,
    required this.subToMainSendPort,
    required this.eventCheck,
    this.network,
  });
}

class RelayIsolateMsgs {
  static const int CONNECT = 1;

  static const int DIS_CONNECT = 2;

  static const int CONNECTED = 101;

  static const int DIS_CONNECTED = 102;
}
