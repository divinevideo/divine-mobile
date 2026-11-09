// ABOUTME: Requires a rendered consent preview before the clip is accepted.
import 'dart:async';

import 'package:bloc/bloc.dart';

/// The native surface mounts during decoding, before a frame can be rendered.
enum MinorConsentPlaybackState { loading, decoding, ready, failure }

class MinorConsentPlaybackCubit extends Cubit<MinorConsentPlaybackState> {
  MinorConsentPlaybackCubit() : super(MinorConsentPlaybackState.loading);

  static const previewTimeout = Duration(seconds: 15);
  final _closed = Completer<bool>();
  final _subscriptions = <StreamSubscription<bool>>[];

  Future<void> load(
    Future<void> Function() prepare, {
    Future<bool> Function()? waitForFrame,
    Stream<bool> Function()? errors,
  }) async {
    if (isClosed) return;
    emit(MinorConsentPlaybackState.loading);
    final failed = Completer<bool>();
    try {
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      await prepare();
      if (isClosed) return;
      final subscription = errors?.call().listen((error) {
        if (!error) return;
        if (!failed.isCompleted) failed.complete(false);
        if (!isClosed) emit(MinorConsentPlaybackState.failure);
      });
      if (subscription != null) _subscriptions.add(subscription);
      emit(MinorConsentPlaybackState.decoding);
      final rendered = await Future.any([
        waitForFrame?.call() ?? Future.value(true),
        failed.future,
        _closed.future,
      ]).timeout(previewTimeout, onTimeout: () => false);
      if (!isClosed) {
        emit(
          rendered
              ? MinorConsentPlaybackState.ready
              : MinorConsentPlaybackState.failure,
        );
      }
    } catch (error, stack) {
      addError(error, stack);
      if (!isClosed) emit(MinorConsentPlaybackState.failure);
    }
  }

  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete(false);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await super.close();
  }
}
