// ABOUTME: Tests the app-wide saved sounds BLoC changes with account storage.
// ABOUTME: Ensures an old account BLoC closes before the next bucket is shown.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopProbe implements SavedSoundMediaProbe {
  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}

class _MockSoundSyncRepository extends Mock implements SoundSyncRepository {}

SavedSound _record(String id) => SavedSound.fromLegacy(
  AudioEvent(
    id: id,
    pubkey: 'creator',
    createdAt: 1,
    url: 'https://example.com/$id.m4a',
  ),
);

void main() {
  group(SavedSoundsScope, () {
    testWidgets('closes account A bloc and loads only account B records', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final serviceA = SavedSoundsService(preferences, pubkeyHex: 'account-a');
      final serviceB = SavedSoundsService(preferences, pubkeyHex: 'account-b');
      await serviceA.saveSavedSound(_record('sound-a'));
      await serviceB.saveSavedSound(_record('sound-b'));

      SavedSoundsBloc? visibleBloc;

      Widget app(SavedSoundsService service) => MaterialApp(
        home: SavedSoundsScope(
          service: service,
          mediaProbe: _NoopProbe(),
          child: Builder(
            builder: (context) {
              visibleBloc = context.read<SavedSoundsBloc>();
              return BlocBuilder<SavedSoundsBloc, SavedSoundsState>(
                builder: (context, state) => Text(
                  state.sounds.map((sound) => sound.id).join(','),
                  textDirection: TextDirection.ltr,
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpWidget(app(serviceA));
      await tester.pump();
      final accountABloc = visibleBloc!;
      expect(find.text('sound-a'), findsOneWidget);

      await tester.pumpWidget(app(serviceB));
      await tester.pump();

      expect(accountABloc.isClosed, isTrue);
      expect(visibleBloc, isNot(same(accountABloc)));
      expect(find.text('sound-b'), findsOneWidget);
      expect(find.text('sound-a'), findsNothing);
    });

    testWidgets(
      'the bloc re-points to a new sync repository without remounting '
      '(#6480)',
      (tester) async {
        // SavedSoundsScope sits above MaterialApp.router in main.dart, so
        // keying its BlocProvider on the resolved sync repository — which
        // resolves asynchronously, well after this scope mounts — would
        // re-inflate the whole app shell every time (#6477/#6480). The
        // bloc instead subscribes to syncRepositoryStream and re-points its
        // dependency in place.
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final service = SavedSoundsService(preferences, pubkeyHex: 'account-a');
        final controller = StreamController<SoundSyncRepository?>();
        addTearDown(controller.close);
        final childKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: SavedSoundsScope(
              service: service,
              mediaProbe: _NoopProbe(),
              syncRepositoryStream: controller.stream,
              child: SizedBox.shrink(key: childKey),
            ),
          ),
        );
        await tester.pump();
        final bloc = childKey.currentContext!.read<SavedSoundsBloc>();

        controller.add(_MockSoundSyncRepository());
        await tester.pump();
        await tester.pump();

        expect(
          childKey.currentContext!.read<SavedSoundsBloc>(),
          same(bloc),
          reason:
              'a stream emission must re-point the existing bloc, not '
              'replace it',
        );
        expect(bloc.isClosed, isFalse);
      },
    );
  });
}
