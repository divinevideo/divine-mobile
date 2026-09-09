// ABOUTME: Unmodifiable collection views that compare equal when they wrap the
// ABOUTME: same source, so `select` on a state collection can still memoise.

import 'dart:collection';

import 'package:meta/meta.dart';

/// An [UnmodifiableListView] that compares equal to another view over the same
/// source list.
///
/// A state getter has to hand out a fresh view on every read — it cannot cache
/// one in a field without giving up its `const` constructor. `dart:collection`
/// views inherit identity `==`, so two reads of the same unchanged field never
/// compare equal, and `ref.watch(fooProvider.select((s) => s.items))` re-fires
/// on every unrelated state change. Freezed shipped these three wrappers for
/// exactly that reason; the handwritten state models keep them.
///
/// Equality is deliberately identity of the *source*, matching freezed: the
/// question a selector asks is "did this field get replaced", and the source
/// list survives a `copyWith` that does not touch it.
@immutable
class EqualUnmodifiableListView<T> extends UnmodifiableListView<T> {
  /// Wraps [_source] without copying it.
  EqualUnmodifiableListView(this._source) : super(_source);

  final Iterable<T> _source;

  @override
  bool operator ==(Object other) {
    return other is EqualUnmodifiableListView<T> &&
        other.runtimeType == runtimeType &&
        other._source == _source;
  }

  @override
  int get hashCode => Object.hash(runtimeType, _source);
}

/// An [UnmodifiableSetView] that compares equal to another view over the same
/// source set. See [EqualUnmodifiableListView].
@immutable
class EqualUnmodifiableSetView<T> extends UnmodifiableSetView<T> {
  /// Wraps [_source] without copying it.
  EqualUnmodifiableSetView(this._source) : super(_source);

  final Set<T> _source;

  @override
  bool operator ==(Object other) {
    return other is EqualUnmodifiableSetView<T> &&
        other.runtimeType == runtimeType &&
        other._source == _source;
  }

  @override
  int get hashCode => Object.hash(runtimeType, _source);
}

/// An [UnmodifiableMapView] that compares equal to another view over the same
/// source map. See [EqualUnmodifiableListView].
@immutable
class EqualUnmodifiableMapView<K, V> extends UnmodifiableMapView<K, V> {
  /// Wraps [_source] without copying it.
  EqualUnmodifiableMapView(this._source) : super(_source);

  final Map<K, V> _source;

  @override
  bool operator ==(Object other) {
    return other is EqualUnmodifiableMapView<K, V> &&
        other.runtimeType == runtimeType &&
        other._source == _source;
  }

  @override
  int get hashCode => Object.hash(runtimeType, _source);
}
