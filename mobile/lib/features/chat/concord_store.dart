// ABOUTME: Stores encrypted Concord wraps and outbox state in the app database.
// ABOUTME: Isolates each account and relay/channel scope without storing keys.

import 'package:concord_repository/concord_repository.dart';
import 'package:db_client/db_client.dart';

class DriftConcordStore implements AccountScopedStore {
  DriftConcordStore({
    required this.dao,
    required this.account,
    required this.scope,
  });
  final ConcordStoreDao dao;
  final String account;
  final String scope;
  @override
  Future<void> put(String key, String value) =>
      dao.put(account: account, scope: scope, key: key, value: value);
  @override
  Future<String?> get(String key) =>
      dao.get(account: account, scope: scope, key: key);
  @override
  Future<void> remove(String key) =>
      dao.remove(account: account, scope: scope, key: key);
  @override
  Future<void> clearAccount() => dao.clearAccount(account);
}
