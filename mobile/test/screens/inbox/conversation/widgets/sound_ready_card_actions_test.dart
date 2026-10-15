import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/router/recorder_sound_selection.dart';
import 'package:openvine/screens/inbox/conversation/widgets/sound_request_card.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

class _Repository extends Mock implements SoundRequestsRepository {}

class _Library extends Mock implements SavedSoundsBloc {}

const creator =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const viewer =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const request =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const soundId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const address = '34236:$creator:clip';
void main() {
  testWidgets(
    'ready reply saves explicitly, reflects removal, and hands sound to creation',
    (tester) async {
      final repo = _Repository();
      final library = _Library();
      final updates = StreamController<SavedSoundsState>.broadcast();
      addTearDown(updates.close);
      var libraryState = const SavedSoundsState();
      final audio = AudioEvent(
        id: soundId,
        pubkey: creator,
        createdAt: 1,
        url: 'https://example.com/sound.wav',
      );
      const message = SoundRequestMessage(
        kind: SoundRequestMessageKind.ready,
        messageId: soundId,
        senderPubkey: creator,
        recipientPubkey: viewer,
        videoAddress: address,
        creatorPubkey: creator,
        requestId: request,
        audioEventId: soundId,
      );
      when(() => repo.ownerPubkey).thenReturn(viewer);
      when(repo.watchState).thenAnswer(
        (_) => Stream.value(
          const SoundRequestSnapshot(
            requests: {
              request: SoundRequestEntry(
                id: request,
                requester: viewer,
                videoAddress: address,
                status: SoundRequestStatus.ready,
                audioEventId: soundId,
              ),
            },
          ),
        ),
      );
      when(repo.start).thenAnswer((_) async {});
      when(() => repo.sourceVideo(address)).thenAnswer(
        (_) async => VideoEvent(
          id: 'e' * 64,
          pubkey: creator,
          createdAt: 1,
          content: 'clip',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
      when(() => repo.resolveReady(message)).thenAnswer((_) async => audio);
      when(() => library.state).thenAnswer((_) => libraryState);
      when(() => library.stream).thenAnswer((_) => updates.stream);
      var saves = 0;
      when(() => library.saveSound(audio)).thenAnswer((_) async {
        saves++;
        libraryState = SavedSoundsState(sounds: [SavedSound.fromLegacy(audio)]);
        updates.add(libraryState);
        return SavedSoundSaveResult.saved;
      });
      final cubit = SoundRequestsCubit();
      await cubit.connect(repo);
      addTearDown(cubit.close);
      RecorderSoundSelection? selection;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SoundRequestCard(message: message, isSent: false),
            ),
          ),
          GoRoute(
            path: VideoRecorderScreen.path,
            builder: (_, state) {
              selection = (state.extra! as RecorderSoundSelection)!;
              return const Scaffold(body: Text('Creation'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider<SavedSoundsBloc>.value(value: library),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(saves, 0);
      await tester.tap(find.text('Save to My Sounds'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('Saved'), findsOneWidget);
      expect(selection, isNull);
      libraryState = const SavedSoundsState();
      updates.add(libraryState);
      await tester.pumpAndSettle();
      expect(find.text('Save to My Sounds'), findsOneWidget);
      await tester.tap(find.text('Use this sound'));
      await tester.pumpAndSettle();
      expect(find.text('Creation'), findsOneWidget);
      expect(selection?.sound.id, soundId);
      expect(selection?.ownerPubkey, viewer);
      expect(saves, 1);
    },
  );
}
