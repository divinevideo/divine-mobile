/// Private native playback entry. See docs/testing/b2-playback-qa.md.
library;

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:models/models.dart';

/// Runs only when explicitly selected as the debug application's entry point.
void main() {
  if (!kDebugMode) throw StateError('Playback QA requires a debug build');
  WidgetsFlutterBinding.ensureInitialized();
  final initialVideo = b2QaInitialVideo(
    const String.fromEnvironment('B2_QA_ORIGINAL_URL'),
  );
  const rendition = String.fromEnvironment('B2_QA_RENDITION_URL');
  runApp(
    BlocProvider(
      create: (_) {
        final cubit = B2PlaybackQaCubit(
          initialVideo: initialVideo,
          controller: DivineVideoPlayerController(
            useTexture: true,
            debugLabel: 'private-playback-qa',
          ),
          rendition: rendition.isEmpty ? null : rendition,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _QaPlayer(),
    ),
  );
}

/// Builds an in-memory fixture; no event is signed, persisted or published.
VideoEvent b2QaInitialVideo(String originalUrl) {
  // Reuse the production eligibility check without performing a request.
  if (b2OriginalPlaybackUrl(originalUrl) == null) {
    throw ArgumentError('Supply an eligible public canonical original URL');
  }
  final video = VideoEvent(
    id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    pubkey: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    createdAt: 0,
    content: '',
    timestamp: DateTime.utc(2026),
    videoUrl: originalUrl,
  );
  return video;
}

/// Current private QA session, separate from production app state.
class B2PlaybackQaState {
  /// Creates a session observation.
  const B2PlaybackQaState({
    this.initialized = false,
    this.source,
    this.failed = false,
  });

  /// Whether the native controller is ready for its view.
  final bool initialized;

  /// The actual source opened by the production fallback loader.
  final String? source;

  /// Whether source preparation failed.
  final bool failed;
}

/// Owns the real native controller and the production source-loading path.
class B2PlaybackQaCubit extends Cubit<B2PlaybackQaState> {
  /// Creates an isolated in-memory session without production bootstrap.
  B2PlaybackQaCubit({
    required this.initialVideo,
    required this.controller,
    this.rendition,
  }) : super(const B2PlaybackQaState());

  /// Fixture supplied by the operator, never fetched from a relay.
  final VideoEvent initialVideo;

  /// The native player used by this session.
  final DivineVideoPlayerController controller;

  /// Optional normal rendition to resolve before the original fallback.
  final String? rendition;

  Future<void>? _loading;

  /// Opens the normal source ladder and starts native looping playback.
  Future<void> load() =>
      isClosed ? Future<void>.value() : _loading ??= _loadSession();

  Future<void> _loadSession() async {
    try {
      await controller.initialize();
      if (isClosed) return;
      emit(const B2PlaybackQaState(initialized: true));
      final (source, _) = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: resolvePlaybackSources(
          initialVideo,
          urlResolver: rendition == null ? null : (_) => rendition,
          preferB2Original: true,
        ),
        log: (_) {},
        trimToCommonTrackEnd: true,
        applyTypedFailoverPolicy: true,
        isLoadCurrent: () => !isClosed,
      );
      if (isClosed) return;
      await controller.setLooping(looping: true);
      if (isClosed) return;
      await controller.play();
      if (!isClosed) emit(B2PlaybackQaState(initialized: true, source: source));
    } on Object {
      if (!isClosed) emit(const B2PlaybackQaState(failed: true));
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    // Native creation must finish before disposal. Disposing before initialize
    // completes cannot release a player that has not been created yet.
    await _loading;
    await controller.dispose();
  }
}

class _QaPlayer extends StatelessWidget {
  const _QaPlayer();

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: VineTheme.backgroundColor,
      child: SafeArea(
        child: BlocBuilder<B2PlaybackQaCubit, B2PlaybackQaState>(
          builder: (context, state) {
            final controller = context.read<B2PlaybackQaCubit>().controller;
            return Column(
              children: [
                if (state.initialized)
                  Expanded(child: DivineVideoPlayer(controller: controller)),
                Text(
                  state.failed ? 'Source failed' : state.source ?? 'Loading',
                  style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
                ),
                StreamBuilder<DivineVideoPlayerState>(
                  stream: controller.stateStream,
                  initialData: controller.state,
                  builder: (_, snapshot) => Text(
                    'Native frame: ${snapshot.data?.isFirstFrameRendered ?? false}',
                    style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
