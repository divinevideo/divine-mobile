import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart' show Builder, SizedBox, Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show MaterialPageRoute, Navigator, TextButton;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show DmFileMetadata;
import 'package:openvine/collab_room/bloc/collab_room_part_cubit.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/collab_room/view/collab_room_part_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../helpers/test_provider_overrides.dart';
import 'collab_room_test_fixtures.dart';

class _MockCollabRoomPartCubit extends MockCubit<CollabRoomPartState>
    implements CollabRoomPartCubit {}

/// A player that only tracks play and pause.
class _FakePlayer extends DivineVideoPlayerController {
  _FakePlayer() : super();

  final _states = StreamController<DivineVideoPlayerState>.broadcast();
  DivineVideoPlayerState _state = const DivineVideoPlayerState(
    status: PlaybackStatus.playing,
  );

  @override
  DivineVideoPlayerState get state => _state;

  @override
  Stream<DivineVideoPlayerState> get stateStream => _states.stream;

  void _set(PlaybackStatus status) {
    _state = DivineVideoPlayerState(status: status);
    _states.add(_state);
  }

  @override
  Future<void> play() async => _set(PlaybackStatus.playing);

  @override
  Future<void> pause() async => _set(PlaybackStatus.paused);

  @override
  Future<void> dispose() => _states.close();
}

class _MockCollabRoomService extends Mock implements CollabRoomService {}

/// An editor holding a finished render, dropped when the session is cleared.
class _RenderedEditor extends VideoEditorNotifier {
  _RenderedEditor(this._clip);

  final DivineVideoClip _clip;

  @override
  VideoEditorProviderState build() =>
      VideoEditorProviderState(finalRenderedClip: _clip);

  void dropRender() => state = VideoEditorProviderState();

  @override
  Future<void> cancelRenderVideo() async {}
}

/// Clears the part session as the app does: the render goes with it.
class _ClearingPublish extends VideoPublishNotifier {
  int clears = 0;

  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    clears++;
    (ref.read(videoEditorProvider.notifier) as _RenderedEditor).dropRender();
  }
}

void main() {
  group(CollabRoomPartPage, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final rendered = DivineVideoClip(
      id: 'rendered',
      video: EditorVideo.file(File('/part.mp4')),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );
    final room = twoPersonRoom(
      owner: sam,
      phase: CollabRoomPhase.recording,
      samStatus: CollabRoomMemberStatus.joined,
    );
    const upload = (
      url: 'https://media.example/part',
      metadata: DmFileMetadata(
        fileType: 'video/mp4',
        encryptionAlgorithm: 'aes-gcm',
        decryptionKey: 'key',
        decryptionNonce: 'nonce',
        fileHash:
            '2222222222222222222222222222222222222222222222222222222222222222',
      ),
    );

    setUpAll(() {
      registerFallbackValue(File(''));
      registerFallbackValue(room);
      registerFallbackValue(upload);
    });

    testWidgets('keeps showing the part while it slides away after sending', (
      tester,
    ) async {
      final service = _MockCollabRoomService();
      when(() => service.watchRoom(roomId))
          .thenAnswer((_) => Stream.value(room));
      when(
        () => service.uploadPart(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => upload);
      when(() => service.handInPart(any(), any())).thenAnswer((_) async {});
      final publish = _ClearingPublish();
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            collabRoomServiceProvider.overrideWithValue(service),
            videoEditorProvider.overrideWith(() => _RenderedEditor(rendered)),
            videoPublishProvider.overrideWith(() => publish),
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                ProviderScope.containerOf(context)
                    .read(collabRoomPartProvider.notifier)
                    .set(
                      const CollabRoomPartContext(
                        roomId: roomId,
                        cellAspectRatio: 9 / 32,
                        me: sam,
                      ),
                    );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CollabRoomPartPage(roomId: roomId),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.collabRoomPartSendButton), findsOneWidget);

      await tester.tap(find.text(l10n.collabRoomPartSendButton));
      await tester.pump();
      await tester.pump();
      // Halfway out: the part, not an error and not a render starting over.
      await tester.pump(const Duration(milliseconds: 100));

      expect(publish.clears, 1);
      expect(find.text(l10n.collabRoomMissing), findsNothing);
      expect(find.text(l10n.collabRoomPartRendering), findsNothing);
      expect(find.text(l10n.collabRoomPartSendButton), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CollabRoomPartPage), findsNothing);
    });
  });

  group(CollabRoomPartView, () {
    late _MockCollabRoomPartCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));
    final rendered = DivineVideoClip(
      id: 'rendered',
      video: EditorVideo.file(File('/part.mp4')),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );

    setUpAll(() => registerFallbackValue(File('')));

    setUp(() {
      cubit = _MockCollabRoomPartCubit();
      when(() => cubit.state).thenReturn(const CollabRoomPartState());
    });

    Future<void> pump(
      WidgetTester tester, {
      DivineVideoClip? clip,
      bool failed = false,
      void Function()? onRetry,
    }) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<CollabRoomPartCubit>.value(
            value: cubit,
            child: CollabRoomPartView(
              renderedClip: clip,
              renderFailed: failed,
              onRetryRender: onRetry ?? () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('the render in progress', (tester) async {
        await pump(tester);
        expect(find.text(l10n.collabRoomPartRendering), findsOneWidget);
      });

      testWidgets('how far the upload got', (tester) async {
        when(
          () => cubit.state,
        ).thenReturn(const CollabRoomPartState(uploadProgress: 0.42));
        await pump(tester, clip: rendered);

        expect(find.text(l10n.collabRoomPartUploading('42%')), findsOneWidget);
      });

      testWidgets('an upload that is done', (tester) async {
        when(
          () => cubit.state,
        ).thenReturn(const CollabRoomPartState(uploadProgress: 1));
        await pump(tester, clip: rendered);

        expect(find.text(l10n.collabRoomPartUploaded), findsOneWidget);
      });

      testWidgets('a failed render with retry', (tester) async {
        var retried = 0;
        await pump(tester, failed: true, onRetry: () => retried++);

        expect(find.text(l10n.collabRoomPartRenderFailed), findsOneWidget);
        await tester.tap(find.text(l10n.commonRetry));
        expect(retried, 1);
      });
    });

    group('interactions', () {
      testWidgets('sending hands the rendered file to the cubit', (
        tester,
      ) async {
        when(() => cubit.send(any())).thenAnswer((_) async {});
        await pump(tester, clip: rendered);

        await tester.tap(find.text(l10n.collabRoomPartSendButton));

        final sent =
            verify(() => cubit.send(captureAny())).captured.single as File;
        expect(sent.path, '/part.mp4');
      });
    });
  });

  group(CollabRoomPartPreviewToggle, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    testWidgets('pauses on a tap and plays again on the next', (tester) async {
      final player = _FakePlayer();
      addTearDown(player.dispose);
      await tester.pumpWidget(
        testMaterialApp(
          home: CollabRoomPartPreviewToggle(
            controller: player,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(find.byType(DivineIcon), findsNothing);

      await tester.tap(
        find.bySemanticsLabel(l10n.videoMetadataPausePreviewSemanticLabel),
      );
      await tester.pump();
      expect(player.state.status, PlaybackStatus.paused);
      expect(find.byType(DivineIcon), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel(l10n.videoMetadataPlayPreviewSemanticLabel),
      );
      await tester.pump();
      expect(player.state.status, PlaybackStatus.playing);
      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('shows no play button while buffering', (tester) async {
      final player = _FakePlayer().._set(PlaybackStatus.buffering);
      addTearDown(player.dispose);
      await tester.pumpWidget(
        testMaterialApp(
          home: CollabRoomPartPreviewToggle(
            controller: player,
            child: const SizedBox.expand(),
          ),
        ),
      );

      expect(find.byType(DivineIcon), findsNothing);
    });
  });
}
