// ABOUTME: GoRouter extra codec that keeps non-JSON route arguments alive
// ABOUTME: when the router re-reads its own route state (#9292).

import 'dart:convert';
import 'dart:math';

/// Encodes GoRouter `extra` values so that re-reading route state in the same
/// process returns the original objects.
///
/// go_router re-decodes its reported route state on every `refresh()`, when
/// the Router is mounted again, and on web back/forward. Without a codec it
/// JSON-encodes each `extra`, so an argument object such as
/// `PooledFullscreenVideoFeedArgs` comes back as `null` and its route falls
/// back to a degraded screen.
///
/// JSON-native values are stored by value. Any other object is stored as a
/// stable id in a weak registry, so the encoded state stays JSON-safe for the
/// platform channel and unchanged across reports, and decoding returns the
/// same object while it is alive. An unknown id, a record, a non-finite number
/// or malformed state decodes to `null`, which routes already handle because
/// `extra` is only a warm-start cache.
class RouteExtraCodec extends Codec<Object?, Object?> {
  /// Creates a codec with its own registry.
  RouteExtraCodec() : this._(_RouteExtraRegistry());

  RouteExtraCodec._(_RouteExtraRegistry registry)
    : encoder = _RouteExtraEncoder(registry),
      decoder = _RouteExtraDecoder(registry);

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
      _refKind => switch (input[_idKey]) {
        final String id => _registry.objectFor(id),
        _ => null,
      },
      _ => null,
    };
  }
}
