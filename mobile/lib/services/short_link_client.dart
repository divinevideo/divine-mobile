// ABOUTME: Creates external short links with bounded anonymous HTTP requests and canonical fallback.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/utils/short_link_url.dart';

class ShortLinkClient {
  ShortLinkClient({
    required http.Client client,
    this.enabled = false,
  }) : _client = client;

  static const endpoint = 'https://gateway.divine.video/api/links';
  final http.Client _client;
  final bool enabled;
  final _cache = <String, String>{};
  final _pending = <String, Future<String>>{};
  final _aborts = <Completer<void>>{};
  bool _closed = false;

  Future<String> shorten(String target) {
    if (!enabled || _closed || !isShortLinkDestination(target)) {
      return Future.value(target);
    }
    final cached = _cache[target];
    if (cached != null) return Future.value(cached);
    final current = _pending[target];
    if (current != null) return current;
    late final Future<String> pending;
    pending = _withinBudget(target)
        .then((url) {
          if (!_closed && url != target) {
            if (_cache.length >= 100) _cache.remove(_cache.keys.first);
            _cache[target] = url;
          }
          return _closed ? target : url;
        })
        .whenComplete(() {
          if (identical(_pending[target], pending)) {
            unawaited(_pending.remove(target));
          }
        });
    _pending[target] = pending;
    return pending;
  }

  Future<String> _withinBudget(String target) async {
    final abort = Completer<void>();
    _aborts.add(abort);
    try {
      return await _create(target, abort).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          return target;
        },
      );
    } catch (_) {
      return target;
    } finally {
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
    }
  }

  Future<String> _create(String target, Completer<void> abort) async {
    final body = jsonEncode({'url': target});
    final request =
        http.AbortableRequest(
            'POST',
            Uri.parse(endpoint),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers['Content-Type'] = 'application/json'
          ..body = body;
    final response = await _client.send(request);
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 4096) return target;
      bytes.addAll(chunk);
    }
    if (![200, 201].contains(response.statusCode) ||
        _closed ||
        abort.isCompleted) {
      return target;
    }
    final mapping = jsonDecode(utf8.decode(bytes));
    if (mapping is! Map<String, dynamic> ||
        mapping['url'] != target ||
        mapping['code'] is! String) {
      return target;
    }
    final code = mapping['code'] as String;
    final shortUrl = 'https://divine.video/l/$code';
    if (!RegExp(r'^[A-Za-z0-9]{8}$').hasMatch(code) ||
        mapping['short_url'] != shortUrl) {
      return target;
    }
    return shortUrl;
  }

  void close() {
    _closed = true;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _aborts.clear();
    _cache.clear();
    _pending.clear();
  }
}
