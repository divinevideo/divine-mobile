// ABOUTME: Deeply immutable full-list values for thumbnail dependency selection.
// ABOUTME: Keeps mutable input arrays from aliasing previous selected values.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// A full owned-list snapshot, compared by value for thumbnail hydration.
///
/// Serialization includes metadata as well as membership, and captures new
/// model fields without maintaining a second list of fields here.
class CuratedListsSnapshot extends Equatable {
  CuratedListsSnapshot(List<CuratedList> lists)
    : _rows = List.unmodifiable(
        lists.map((list) => _freezeMap(list.toJson())),
      );

  final List<Map<String, dynamic>> _rows;

  /// Restores independent model copies from the captured values.
  List<CuratedList> get lists =>
      List.unmodifiable(_rows.map(CuratedList.fromJson));

  @override
  List<Object?> get props => [_rows];
}

Map<String, dynamic> _freezeMap(Map<String, dynamic> value) => Map.unmodifiable(
  value.map((key, value) => MapEntry(key, _freeze(value))),
);

Object? _freeze(Object? value) => switch (value) {
  final Map<String, dynamic> map => _freezeMap(map),
  final List<dynamic> list => List<Object?>.unmodifiable(list.map(_freeze)),
  _ => value,
};
