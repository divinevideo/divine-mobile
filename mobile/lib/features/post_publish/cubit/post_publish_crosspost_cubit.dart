// ABOUTME: Decides what the post-publish confirmation offers for crossposting:
// ABOUTME: crosspost this video, set crossposting up, reconnect, or nothing.

import 'package:analytics/analytics.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/crossposting/crossposting_analytics.dart';
import 'package:openvine/repositories/crossposting_repository.dart';

part 'post_publish_crosspost_state.dart';

/// Loads the creator's crossposting settings once and picks the single
/// crossposting prompt the post-publish confirmation shows.
///
/// Automatic mode needs no prompt: the service already posts the video.
class PostPublishCrosspostCubit extends Cubit<PostPublishCrosspostState>
    with CloseGuardedEmit<PostPublishCrosspostState> {
  PostPublishCrosspostCubit({
    required CrosspostingRepository repository,
    required AnalyticsEventSink analytics,
  }) : _repository = repository,
       _analytics = analytics,
       super(const PostPublishCrosspostState());

  final CrosspostingRepository _repository;
  final AnalyticsEventSink _analytics;

  Future<void> load() async {
    final PostPublishCrosspostState next;
    try {
      next = _stateFor(await _repository.loadSettings());
    } on Exception catch (error, stackTrace) {
      // A crosspost suggestion is optional; the confirmation stands without
      // it, so a failed load hides the prompt rather than surfacing an error.
      addError(error, stackTrace);
      emitIfOpen(
        const PostPublishCrosspostState(
          prompt: PostPublishCrosspostPrompt.none,
        ),
      );
      return;
    }
    if (!emitIfOpen(next)) return;
    final cta = _ctaFor(next.prompt);
    if (cta == null) return;
    await logCrosspostCtaShown(
      _analytics,
      surface: CrosspostCtaSurface.postPublish,
      cta: cta,
    );
  }

  /// Records a tap on the prompt's call to action, if it has one.
  Future<void> recordTap() async {
    final cta = _ctaFor(state.prompt);
    if (cta == null) return;
    await logCrosspostCtaTapped(
      _analytics,
      surface: CrosspostCtaSurface.postPublish,
      cta: cta,
    );
  }

  static PostPublishCrosspostState _stateFor(
    List<CrosspostingPlatformSettings> settings,
  ) {
    final manual = [
      for (final platform in settings)
        if (platform.isConnected && platform.mode == CrosspostingMode.manual)
          platform.connection!,
    ];
    if (manual.isNotEmpty) {
      return PostPublishCrosspostState(
        prompt: PostPublishCrosspostPrompt.crosspost,
        platforms: [for (final connection in manual) connection.platform],
        connections: manual,
      );
    }

    final needsReauth = [
      for (final platform in settings)
        if (platform.needsReauth) platform.platform,
    ];
    if (needsReauth.isNotEmpty) {
      return PostPublishCrosspostState(
        prompt: PostPublishCrosspostPrompt.reconnect,
        platforms: needsReauth,
      );
    }

    final automatic = [
      for (final platform in settings)
        if (platform.isConnected && platform.mode == CrosspostingMode.automatic)
          platform.platform,
    ];
    if (automatic.isNotEmpty) {
      return PostPublishCrosspostState(
        prompt: PostPublishCrosspostPrompt.automatic,
        platforms: automatic,
      );
    }

    // A connected platform switched off is a choice, not a gap to fill.
    final anyConnected = settings.any((platform) => platform.isConnected);
    if (settings.isEmpty || anyConnected) {
      return const PostPublishCrosspostState(
        prompt: PostPublishCrosspostPrompt.none,
      );
    }
    return PostPublishCrosspostState(
      prompt: PostPublishCrosspostPrompt.setUp,
      platforms: [settings.first.platform],
    );
  }

  static CrosspostCta? _ctaFor(PostPublishCrosspostPrompt prompt) =>
      switch (prompt) {
        PostPublishCrosspostPrompt.crosspost => CrosspostCta.crosspostVideo,
        PostPublishCrosspostPrompt.setUp => CrosspostCta.connect,
        PostPublishCrosspostPrompt.reconnect => CrosspostCta.reconnect,
        PostPublishCrosspostPrompt.loading ||
        PostPublishCrosspostPrompt.none ||
        PostPublishCrosspostPrompt.automatic => null,
      };
}
