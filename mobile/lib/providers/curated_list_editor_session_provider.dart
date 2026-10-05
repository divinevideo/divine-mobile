// ABOUTME: Account-bound access used by list editors that outlive their route.
// ABOUTME: Invalidates before an account container or its auth provider is disposed.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/services/curated_list_service.dart';

/// Keeps an async editor from reading a provider after its account is gone.
final curatedListEditorSessionProvider = Provider<CuratedListEditorSession>((
  ref,
) {
  final auth = ref.watch(authServiceProvider);
  final session = CuratedListEditorSession._(
    currentOwner: () => auth.currentPublicKeyHex,
    resolveService: () => ref.read(curatedListsStateProvider.notifier).service,
  );
  ref.onDispose(session._invalidate);
  return session;
});

/// Captured account lifetime for a form or picker opened from that account.
class CuratedListEditorSession {
  CuratedListEditorSession._({
    required String? Function() currentOwner,
    required CuratedListService? Function() resolveService,
  }) : _currentOwner = currentOwner,
       _resolveService = resolveService;

  final String? Function() _currentOwner;
  final CuratedListService? Function() _resolveService;
  bool _active = true;

  /// Answers null once the account scope leaves, without accessing its providers.
  String? get currentOwnerPubkey => _active ? _currentOwner() : null;

  /// Resolves the current relay-backed service only while this account is alive.
  CuratedListService? get service => _active ? _resolveService() : null;

  void _invalidate() => _active = false;
}
