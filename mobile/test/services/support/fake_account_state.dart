import 'dart:async';

import 'package:account_state_repository/account_state_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Deterministic repository boundary for app adapter tests. The reusable
/// package separately exercises encrypted relay transport and durable journals.
class FakeAccountState extends Fake implements AccountStateRepository {
  FakeAccountState(this.pubkey, [Map<String, Object?> initial = const {}])
    : data = Map.of(initial);

  @override
  final String pubkey;
  final Map<String, Object?> data;
  final _changes = StreamController<Map<String, Object?>>.broadcast(sync: true);
  int localWrites = 0;
  Completer<void>? pendingWrite;

  @override
  Map<String, Object?> get values => Map.unmodifiable(data);
  @override
  Object? value(String key) => data[key];
  @override
  bool contains(String key) => data.containsKey(key);
  @override
  Stream<Map<String, Object?>> get changes => _changes.stream;
  @override
  Future<void> setValue(String key, Object? value) => setValues({key: value});
  @override
  Future<void> setValues(Map<String, Object?> values) async {
    await pendingWrite?.future;
    ++localWrites;
    data.addAll(values);
    _changes.add(this.values);
  }

  @override
  Future<void> seed(Map<String, Object?> values) async {
    for (final entry in values.entries) {
      data.putIfAbsent(entry.key, () => entry.value);
    }
  }

  void receive(Map<String, Object?> values) {
    data.addAll(values);
    _changes.add(this.values);
  }

  @override
  Future<void> close() => _changes.close();
}
