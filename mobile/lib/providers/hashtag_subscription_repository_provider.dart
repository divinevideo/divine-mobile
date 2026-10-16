// ABOUTME: Account-scoped dependency wiring for local hashtag subscriptions.
// ABOUTME: Anonymous sessions cannot create or persist followed hashtags.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hashtag_subscription_repository/hashtag_subscription_repository.dart';
import 'package:openvine/features/hashtag_follows/data/shared_preferences_hashtag_subscription_store.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';

final hashtagSubscriptionRepositoryProvider =
    Provider<HashtagSubscriptionRepository?>((ref) {
      ref.watch(currentAuthStateProvider);
      final auth = ref.watch(authServiceProvider);
      final pubkey = auth.currentPublicKeyHex;
      if (!auth.isAuthenticated || pubkey == null) return null;
      final repository = HashtagSubscriptionRepository(
        store: SharedPreferencesHashtagSubscriptionStore(
          prefs: ref.watch(sharedPreferencesProvider),
          pubkey: pubkey,
        ),
      );
      ref.onDispose(() => unawaited(repository.dispose()));
      return repository;
    });
