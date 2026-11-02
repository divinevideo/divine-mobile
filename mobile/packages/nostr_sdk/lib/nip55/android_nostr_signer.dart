// ABOUTME: Android Nostr Signer implementation for NIP-55 external signing.
// ABOUTME: Handles communication with external Android signer apps via content providers and intents.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:android_content_provider/android_content_provider.dart';
import 'package:nostr_sdk/utils/string_util.dart';
import 'package:synchronized/synchronized.dart';

import '../android_plugin/android_plugin.dart';
import '../android_plugin/android_plugin_intent.dart';
import '../event.dart';
import '../nip19/nip19.dart';
import '../signer/nostr_signer.dart';

///
/// Android Local Nostr Signer
///
/// Notice:
/// havn't implement get_relays method.
/// many methods call content_resolve_query first and than start_activity_for_result.
/// many methods return signature field maybe later will change to result field, so client should get signature field first and try result field if signature field not exist.
/// methods calling should be one-by-one, if they call together it will call some call in signer can't get the calling package name.
///
class AndroidNostrSigner implements NostrSigner {
  static const String uriPre = "nostrsigner";

  static const String actionView = "android.intent.action.VIEW";

  static bool isAndroidNostrSignerKey(String key) {
    if (key.startsWith(uriPre)) {
      return true;
    }
    return false;
  }

  static String getPubkeyFromKey(String key) {
    var strs = key.split(":");
    if (strs.length >= 2) {
      return strs[1].split("?")[0];
    }

    return key;
  }

  static String? getPackageFromKey(String key) {
    var strs = key.split("package=");
    if (strs.length >= 2) {
      return strs[1];
    }

    return key;
  }

  AndroidNostrSigner({String? pubkey, String? package}) {
    _pubkey = pubkey;
    _package = package;
    if (pubkey != null) {
      _npub = Nip19.encodePubKey(pubkey);
    }
  }

  final _lock = Lock(reentrant: true);

  Duration timeout = const Duration(seconds: 300);

  String? _pubkey;

  String? _npub;

  String? _package;

  String? getPackage() {
    return _package;
  }

  AndroidPluginIntent _genIntent() {
    var intent = AndroidPluginIntent();
    intent.setAction(actionView);
    if (StringUtil.isNotBlank(_package)) {
      intent.setPackage(_package!);
    }

    return intent;
  }

  @override
  Future<String?> decrypt(pubkey, ciphertext) async {
    return _lock.synchronized(() async {
      var queryResult = await _contentResolverQuery(
        "NIP04_DECRYPT",
        [ciphertext, pubkey, _npub!],
        ["signature", "result", "rejected"],
      );
      if (hasResult(queryResult)) {
        return getResult(queryResult);
      }

      if (isRejected(queryResult)) {
        return null;
      }

      var intent = _genIntent();
      intent.setData("$uriPre:$ciphertext");

      intent.putExtra("type", "nip04_decrypt");
      intent.putExtra("current_user", _npub);
      intent.putExtra("pubKey", pubkey);

      var result = await AndroidPlugin.startForResult(intent);
      if (result != null) {
        var signature = result.data.getExtra("signature");
        if (signature != null && signature is String) {
          return signature;
        }

        signature = result.data.getExtra("result");
        if (signature != null && signature is String) {
          return signature;
        }
      }

      return null;
    }, timeout: timeout);
  }

  @override
  Future<String?> encrypt(pubkey, plaintext) async {
    return _lock.synchronized(() async {
      var queryResult = await _contentResolverQuery(
        "NIP04_ENCRYPT",
        [plaintext, pubkey, _npub!],
        ["signature", "result", "rejected"],
      );
      if (hasResult(queryResult)) {
        return getResult(queryResult);
      }

      if (isRejected(queryResult)) {
        return null;
      }

      var intent = _genIntent();
      intent.setData("$uriPre:$plaintext");

      intent.putExtra("type", "nip04_encrypt");
      intent.putExtra("current_user", _npub);
      intent.putExtra("pubKey", pubkey);

      var result = await AndroidPlugin.startForResult(intent);
      if (result != null) {
        var signature = result.data.getExtra("signature");
        if (signature != null && signature is String) {
          return signature;
        }

        signature = result.data.getExtra("result");
        if (signature != null && signature is String) {
          return signature;
        }
      }

      return null;
    }, timeout: timeout);
  }

  @override
  Future<String?> getPublicKey() async {
    if (_pubkey != null) {
      return _pubkey;
    }

    List<Map<String, dynamic>> permissions = [];
    permissions.add({'type': 'sign_event', 'kind': 22242});
    permissions.add({'type': 'sign_event', 'kind': 27235});
    permissions.add({'type': 'nip04_encrypt'});
    permissions.add({'type': 'nip44_encrypt'});
    permissions.add({'type': 'nip04_decrypt'});
    permissions.add({'type': 'nip44_decrypt'});
    permissions.add({'type': 'get_public_key'});

    var intent = _genIntent();
    intent.setData("$uriPre:");

    intent.putExtra("type", "get_public_key");
    intent.putExtra("permissions", jsonEncode(permissions));

    developer.log(
      '[AndroidNostrSigner] getPublicKey: sending intent '
      'package=$_package',
    );

    return _lock.synchronized(() async {
      var result = await AndroidPlugin.startForResult(intent);
      developer.log(
        '[AndroidNostrSigner] getPublicKey: result=${result != null ? "non-null" : "null"}',
      );
      if (result != null) {
        var package = result.data.getExtra("package");
        developer.log('[AndroidNostrSigner] getPublicKey: package=$package');
        _package = package;

        var signature = result.data.getExtra("signature");
        // Despite the extra's name, get_public_key returns the npub here (see
        // the isPubkey branch below), so this is public data — logged whole so
        // the identity Amber handed back is greppable against relay traffic.
        developer.log(
          '[AndroidNostrSigner] getPublicKey: '
          'signature=${signature == null ? "null" : "${signature.runtimeType}:$signature"}, '
          'result_extra=${result.data.getExtra("result")}',
        );
        if (signature != null && signature is String) {
          if (Nip19.isPubkey(signature)) {
            // npub
            _npub = signature;
            _pubkey = Nip19.decode(signature);
          } else {
            // hex pubkey
            _pubkey = signature;
            _npub = Nip19.encodePubKey(signature);
          }
          return _pubkey;
        }

        // Try result extra as fallback
        var resultExtra = result.data.getExtra("result");
        if (resultExtra != null && resultExtra is String) {
          developer.log(
            '[AndroidNostrSigner] getPublicKey: using result extra as fallback',
          );
          if (Nip19.isPubkey(resultExtra)) {
            _npub = resultExtra;
            _pubkey = Nip19.decode(resultExtra);
          } else {
            _pubkey = resultExtra;
            _npub = Nip19.encodePubKey(resultExtra);
          }
          return _pubkey;
        }
      }

      return null;
    }, timeout: timeout);
  }

  @override
  Future<Map?> getRelays() async {
    return {};
  }

  @override
  Future<String?> nip44Decrypt(pubkey, ciphertext) async {
    return _lock.synchronized(() async {
      var queryResult = await _contentResolverQuery(
        "NIP44_DECRYPT",
        [ciphertext, pubkey, _npub!],
        ["signature", "result", "rejected"],
      );
      if (hasResult(queryResult)) {
        return getResult(queryResult);
      }

      if (isRejected(queryResult)) {
        return null;
      }

      var intent = _genIntent();
      intent.setData("$uriPre:$ciphertext");

      intent.putExtra("type", "nip44_decrypt");
      intent.putExtra("current_user", _npub);
      intent.putExtra("pubKey", pubkey);

      var result = await AndroidPlugin.startForResult(intent).timeout(timeout);
      if (result != null) {
        var signature = result.data.getExtra("signature");
        if (signature != null && signature is String) {
          return signature;
        }

        signature = result.data.getExtra("result");
        if (signature != null && signature is String) {
          return signature;
        }
      }

      return null;
    }, timeout: timeout);
  }

  @override
  Future<String?> nip44Encrypt(pubkey, plaintext) async {
    return _lock.synchronized(() async {
      var queryResult = await _contentResolverQuery(
        "NIP44_ENCRYPT",
        [plaintext, pubkey, _npub!],
        ["signature", "result", "rejected"],
      );
      if (hasResult(queryResult)) {
        return getResult(queryResult);
      }

      if (isRejected(queryResult)) {
        return null;
      }

      var intent = _genIntent();
      intent.setData("$uriPre:$plaintext");

      intent.putExtra("type", "nip44_encrypt");
      intent.putExtra("current_user", _npub);
      intent.putExtra("pubKey", pubkey);

      var result = await AndroidPlugin.startForResult(intent);
      if (result != null) {
        var signature = result.data.getExtra("signature");
        if (signature != null && signature is String) {
          return signature;
        }

        signature = result.data.getExtra("result");
        if (signature != null && signature is String) {
          return signature;
        }
      }

      return null;
    }, timeout: timeout);
  }

  @override
  Future<Event?> signEvent(Event event) =>
      _signEvent(event, allowUserInteraction: true);

  /// Signs only with a previously approved content-resolver permission.
  ///
  /// A missing permission or unavailable provider never launches signer UI.
  Future<Event?> signEventWithoutUserInteraction(Event event) =>
      _signEvent(event, allowUserInteraction: false);

  static const _nonInteractiveSigningTimeout = Duration(seconds: 6);

  Future<Event?> _signEvent(
    Event event, {
    required bool allowUserInteraction,
  }) async {
    var eventMap = event.toJson();
    var eventJson = jsonEncode(eventMap);

    return _lock.synchronized(() async {
      final query = _contentResolverQuery(
        "SIGN_EVENT",
        [eventJson, "", _npub!],
        ["signature", "result", "event", "rejected"],
      );
      final queryResult = allowUserInteraction
          ? await query
          : await query.timeout(_nonInteractiveSigningTimeout);
      if (hasResult(queryResult)) {
        event.sig = getResult(queryResult)!;
        return event;
      }

      if (isRejected(queryResult) || !allowUserInteraction) {
        return null;
      }

      var intent = _genIntent();
      intent.setData("$uriPre:$eventJson");

      intent.putExtra("type", "sign_event");
      intent.putExtra("current_user", _npub);
      intent.putExtra("id", event.id);

      var result = await AndroidPlugin.startForResult(intent);
      if (result != null) {
        var signature = result.data.getExtra("signature");
        if (signature != null && signature is String) {
          event.sig = signature;
          return event;
        }

        signature = result.data.getExtra("result");
        if (signature != null && signature is String) {
          event.sig = signature;
          return event;
        }
      }

      return null;
    }, timeout: allowUserInteraction ? timeout : _nonInteractiveSigningTimeout);
  }

  bool isRejected(Map<String, Object?> queryResult) {
    if (queryResult.isNotEmpty && queryResult.containsKey("rejected")) {
      return true;
    }
    return false;
  }

  bool hasResult(Map<String, Object?> queryResult) {
    if (queryResult.isNotEmpty &&
        ((queryResult.containsKey("signature") &&
                queryResult["signature"] != null &&
                queryResult["signature"] is String) ||
            queryResult.containsKey("result") &&
                queryResult["result"] != null &&
                queryResult["result"] is String)) {
      return true;
    }
    return false;
  }

  String? getResult(Map<String, Object?> queryResult) {
    if (queryResult.isNotEmpty) {
      if (queryResult.containsKey("signature") &&
          queryResult["signature"] != null &&
          queryResult["signature"] is String) {
        return queryResult["signature"] as String;
      } else if (queryResult.containsKey("result") &&
          queryResult["result"] != null &&
          queryResult["result"] is String) {
        return queryResult["result"] as String;
      }
    }
    return null;
  }

  Future<Map<String, Object?>> _getValuesFromCursor(
    NativeCursor? cursor,
    List<String> columnNames,
  ) async {
    Map<String, Object?> resultMap = {};
    if (cursor == null || !(await cursor.moveToFirst())) {
      return resultMap;
    }

    var getIndexBatch = cursor.batchedGet();
    for (var name in columnNames) {
      getIndexBatch.getColumnIndex(name);
    }
    var columnIndexList = await getIndexBatch.commit();

    Map<int, String> columnIndexMap = {};
    int valueGetIndex = 0;
    var length = min(columnIndexList.length, columnNames.length);
    var getValueBatch = cursor.batchedGet();
    for (var i = 0; i < length; i++) {
      var columnIndexObj = columnIndexList[i];
      var columnName = columnNames[i];
      if (columnIndexObj is int && columnIndexObj >= 0) {
        getValueBatch.getString(columnIndexObj);

        columnIndexMap[valueGetIndex++] = columnName;
      }
    }

    var values = await getValueBatch.commit();
    for (var i = 0; i < values.length; i++) {
      var value = values[i];

      var columnName = columnIndexMap[i];
      if (StringUtil.isNotBlank(columnName)) {
        resultMap[columnName!] = value;
      }
    }

    return resultMap;
  }

  Future<Map<String, Object?>> _contentResolverQuery(
    String method,
    List<String> args,
    List<String> valueNames,
  ) async {
    if (StringUtil.isBlank(_package)) {
      developer.log(
        '[AndroidNostrSigner] _contentResolverQuery: skipping $method '
        '- no package set',
      );
      return {};
    }

    try {
      final uri = "content://$_package.$method";
      developer.log('[AndroidNostrSigner] _contentResolverQuery: $uri');
      var cursor = await AndroidContentResolver.instance.query(
        uri: uri,
        projection: args,
      );
      var values = await _getValuesFromCursor(cursor, valueNames);
      developer.log(
        '[AndroidNostrSigner] _contentResolverQuery: $method '
        'returned ${values.keys.join(", ")}',
      );
      return values;
    } catch (e) {
      developer.log(
        '[AndroidNostrSigner] _contentResolverQuery: $method exception: $e',
      );
    }

    return {};
  }

  @override
  void close() {}
}
