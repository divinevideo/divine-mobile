// ABOUTME: Presents confirmed hashtag follows and pending writes to the UI.
// ABOUTME: Owns loading, retry and error state without Flutter dependencies.
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtag_subscription_repository/hashtag_subscription_repository.dart';

class HashtagFollowsState extends Equatable {
  const HashtagFollowsState({
    this.subscriptions = const [],
    this.isLoading = true,
    this.hasReadError = false,
    this.hasWriteError = false,
    this.pendingTags = const {},
  });

  final List<HashtagSubscription> subscriptions;
  final bool isLoading;
  final bool hasReadError;
  final bool hasWriteError;
  final Set<String> pendingTags;

  @override
  List<Object> get props => [
    subscriptions,
    isLoading,
    hasReadError,
    hasWriteError,
    pendingTags,
  ];
}

class HashtagFollowsCubit extends Cubit<HashtagFollowsState> {
  HashtagFollowsCubit({required HashtagSubscriptionRepository repository})
    : _repository = repository,
      super(const HashtagFollowsState()) {
    _subscription = repository.subscriptionsStream.listen((tags) {
      if (!isClosed) _update(subscriptions: tags);
    });
  }

  final HashtagSubscriptionRepository _repository;
  late final StreamSubscription<List<HashtagSubscription>> _subscription;

  Future<void> initialize() async {
    if (isClosed || (state.isLoading && _initializing)) return;
    _initializing = true;
    _update(isLoading: true, hasReadError: false);
    try {
      await _repository.initialize();
      if (!isClosed) {
        _update(subscriptions: _repository.subscriptions, isLoading: false);
      }
    } on Exception {
      if (!isClosed) _update(isLoading: false, hasReadError: true);
    } finally {
      _initializing = false;
    }
  }

  bool _initializing = false;

  Future<void> follow(String tag) => _change(tag, follow: true);
  Future<void> unfollow(String tag) => _change(tag, follow: false);
  void dismissWriteError() => _update(hasWriteError: false);

  Future<void> _change(String value, {required bool follow}) async {
    if (isClosed || state.isLoading || state.hasReadError) return;
    if (!HashtagSubscription.isValid(value)) {
      _update(hasWriteError: true);
      return;
    }
    final tag = HashtagSubscription.fromTag(value).canonicalTag;
    if (state.pendingTags.contains(tag)) return;
    _update(pendingTags: {...state.pendingTags, tag}, hasWriteError: false);
    try {
      if (follow) {
        await _repository.follow(value);
      } else {
        await _repository.unfollow(value);
      }
      if (!isClosed) _update(subscriptions: _repository.subscriptions);
    } on Exception {
      if (!isClosed) _update(hasWriteError: true);
    } finally {
      if (!isClosed) {
        _update(pendingTags: {...state.pendingTags}..remove(tag));
      }
    }
  }

  void _update({
    List<HashtagSubscription>? subscriptions,
    bool? isLoading,
    bool? hasReadError,
    bool? hasWriteError,
    Set<String>? pendingTags,
  }) {
    if (isClosed) return;
    emit(
      HashtagFollowsState(
        subscriptions: subscriptions ?? state.subscriptions,
        isLoading: isLoading ?? state.isLoading,
        hasReadError: hasReadError ?? state.hasReadError,
        hasWriteError: hasWriteError ?? state.hasWriteError,
        pendingTags: Set.unmodifiable(pendingTags ?? state.pendingTags),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
