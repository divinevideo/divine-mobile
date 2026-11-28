// ABOUTME: GoRouter extra codec that keeps non-JSON route arguments alive
// ABOUTME: when the router re-reads its own route state (#9292).

import 'dart:convert';
import 'dart:math';

import 'package:openvine/router/routes/route_extras.dart';

/// Encodes GoRouter `extra` values so that re-reading route state in the same
/// process returns the original objects.
///
/// go_router re-decodes its reported route state on every `refresh()`, when
/// the Router is mounted again, and on web back/forward. Without a codec it
/// JSON-encodes each `extra`, so an argument object such as
/// `PooledFullscreenVideoFeedArgs` comes back as `null` and its route falls
/// back to a degraded screen.
///
/// JSON-native values and the video-detail privacy flag survive process loss.
/// Other objects remain in a weak registry. Its opaque references keep repeated
/// reports stable and preserve warm state while the object is alive. A missing
/// reference drops the warm state; a saved video detail still carries its
/// playback privacy flag.
class RouteExtraCodec extends Codec<Object?, Object?> {
  /// Creates a codec with its own registry.
  RouteExtraCodec() : this._(_RouteExtraRegistry());

  RouteExtraCodec._(_RouteExtraRegistry registry)
    : encoder = _RouteExtraEncoder(registry),
      decoder = _RouteExtraDecoder(registry);

  /// An old video detail entry stored only a weak reference. Its origin cannot
  /// be recovered once the registry is gone. Keep a live extra when available.
  static Object? protectLegacyVideoReference(Object? encoded) =>
      switch (encoded) {
        {_kindKey: _refKind, _idKey: final String id} => {
          _kindKey: _videoKind,
          _idKey: id,
          _valueKey: true,
        },
        _ => encoded,
      };

  /// Whether playback from this saved detail should omit attributed metrics.
  static bool hasPrivateVideoOrigin(Object? encoded) =>
      encoded is Map &&
      encoded[_kindKey] == _videoKind &&
      encoded[_valueKey] != false;

  @override
  final Converter<Object?, Object?> encoder;

  @override
  final Converter<Object?, Object?> decoder;
}

const _kindKey = 'kind';
const _valueKey = 'value';
const _idKey = 'id';
const _jsonKind = 'json';
const _refKind = 'ref';
const _videoKind = 'videoDetail';

class _RouteExtraRegistry {
  // Route state can outlive this registry: browser history keeps it across a
  // page reload and hands it to the next router after an account switch. A
  // random prefix keeps a stale id from naming a different live object.
  final String _prefix = _randomPrefix();
  final Expando<String> _ids = Expando<String>('RouteExtraCodec ids');
  final Map<String, WeakReference<Object>> _objects = {};
  var _nextId = 0;

  String idFor(Object object) {
    final existing = _ids[object];
    if (existing != null) return existing;

    _objects.removeWhere((_, reference) => reference.target == null);
    final id = '$_prefix-${_nextId++}';
    _ids[object] = id;
    _objects[id] = WeakReference(object);
    return id;
  }

  Object? objectFor(String id) => _objects[id]?.target;

  static String _randomPrefix() {
    final random = Random();
    // 0x7fffffff rather than a shift: `1 << 32` is 0 on the web.
    return '${random.nextInt(0x7fffffff).toRadixString(16)}'
        '${random.nextInt(0x7fffffff).toRadixString(16)}';
  }
}

class _RouteExtraEncoder extends Converter<Object?, Object?> {
  const _RouteExtraEncoder(this._registry);

  final _RouteExtraRegistry _registry;

  @override
  Object? convert(Object? input) {
    if (input is VideoDetailRouteExtra) {
      return {
        _kindKey: _videoKind,
        _idKey: _registry.idFor(input),
        _valueKey: input.fromMessage,
      };
    }
    if (_isJsonNative(input)) {
      return {_kindKey: _jsonKind, _valueKey: input};
    }
    // A non-finite number or a record cannot key an Expando or back a
    // WeakReference, so it gets the same null a JSON round trip gives it.
    if (input == null || input is num || input is Record) return null;
    return {_kindKey: _refKind, _idKey: _registry.idFor(input)};
  }

  static bool _isJsonNative(Object? value) => switch (value) {
    null || bool() || String() => true,
    final num number => number.isFinite,
    final List<Object?> list => list.every(_isJsonNative),
    final Map<Object?, Object?> map => map.entries.every(
      (entry) => entry.key is String && _isJsonNative(entry.value),
    ),
    _ => false,
  };
}

class _RouteExtraDecoder extends Converter<Object?, Object?> {
  const _RouteExtraDecoder(this._registry);

  final _RouteExtraRegistry _registry;

  @override
  Object? convert(Object? input) {
    if (input is! Map) return null;
    return switch (input[_kindKey]) {
      _jsonKind => input[_valueKey],
      _videoKind => _restoreVideo(input),
      _refKind => switch (input[_idKey]) {
        final String id => _registry.objectFor(id),
        _ => null,
      },
      _ => null,
    };
  }

  VideoDetailRouteExtra _restoreVideo(Map<Object?, Object?> saved) {
    final id = saved[_idKey];
    final live = id is String ? _registry.objectFor(id) : null;
    if (live is VideoDetailRouteExtra) return live;
    return VideoDetailRouteExtra(
      fromMessage: RouteExtraCodec.hasPrivateVideoOrigin(saved),
    );
  }
}
