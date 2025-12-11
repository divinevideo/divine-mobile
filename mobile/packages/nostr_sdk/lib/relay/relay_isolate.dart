// ABOUTME: Relay implementation that runs in a separate isolate for performance.
// ABOUTME: Handles JSON decoding and event signature checks off the main thread.

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
      relayStatus.connected = ClientConnected.connecting;
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
      if (relayStatus.connected == ClientConnected.connected) {
        // relay has bean connected, return true, but also send a connect message.
        mainToSubSendPort!.send(RelayIsolateMsgs.connect);
        return true;
      } else {
        // haven't connected
        if (relayConnectResultComplete != null) {
          return relayConnectResultComplete!.future;
        } else {
          // this maybe relay had disconnect after connected, try to connected again.
          if (mainToSubSendPort != null) {
            relayStatus.connected = ClientConnected.connecting;
            // send connect msg
            mainToSubSendPort!.send(RelayIsolateMsgs.connect);
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
    if (relayStatus.connected != ClientConnected.disconnect) {
      relayStatus.connected = ClientConnected.disconnect;
      if (mainToSubSendPort != null) {
        mainToSubSendPort!.send(RelayIsolateMsgs.disConnect);
      }
    }
  }

  @override
  bool send(List message, {bool? forceSend}) {
    if (forceSend == true ||
        (mainToSubSendPort != null &&
            relayStatus.connected == ClientConnected.connected)) {
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
        if (data.toJson != null) {
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
        if (message == RelayIsolateMsgs.connected) {
          // print("$url receive connected status!");
          relayStatus.connected = ClientConnected.connected;
          if (relayStatusCallback != null) {
            relayStatusCallback!();
          }
          _relayConnectComplete(true);
        } else if (message == RelayIsolateMsgs.disConnected) {
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
  static const int connect = 1;

  static const int disConnect = 2;

  static const int connected = 101;

  static const int disConnected = 102;
}
