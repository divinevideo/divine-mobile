// ABOUTME: Unit tests for the Add sound cubit's lifecycle: copy, private save,
// ABOUTME: public share, retry, cleanup, account guard, and close behaviour.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/add_sound/add_sound_cubit.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/local_audio_event_publisher.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';

class _MockPublisher extends Mock implements LocalAudioEventPublisher {}

class _FakeAudioEvent extends Fake implements AudioEvent {}

class _FakeAttribution extends Fake implements AudioShareAttribution {}

const _self =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _soundEventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Event _publishedEvent() => Event.fromJson({
  'id': _soundEventId,
  'pubkey': _self,
  'created_at': 0,
  'kind': 1063,
  'tags': [
    ['url', 'https://cdn.example/pick.mp3'],
    ['title', 'pick'],
    ['allow_audio_reuse', 'true'],
  ],
  'content': '',
  'sig': 'sig',
});

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAudioEvent());
    registerFallbackValue(_FakeAttribution());
  });

  group(AddSoundCubit, () {
    late Directory root;
    late Directory storageDir;
    late File source;
    late List<String> reclaimed;
    late List<AudioEvent> savedSounds;
    late String? lastSavedLabel;
    late String? accountId;
    late Future<Duration?> Function(File file) durationFn;
    late _MockPublisher publisher;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('add_sound_cubit_test_');
      storageDir = Directory('${root.path}/storage')..createSync();
      source = File('${root.path}/pick.mp3')..writeAsBytesSync([1, 2, 3]);
      reclaimed = <String>[];
      savedSounds = <AudioEvent>[];
      lastSavedLabel = null;
      accountId = 'account-a';
      durationFn = (_) async => const Duration(seconds: 3);
      publisher = _MockPublisher();
    });

    tearDown(() async {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    AddSoundCubit build({
      AudioImportFilePicker? pickFile,
      SavedSoundSaver? saveSound,
    }) {
      return AddSoundCubit(
        importService: LocalAudioImportService(
          storageRootProvider: () async => storageDir,
          durationResolver: durationFn,
          clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ),
        pickFile:
            pickFile ??
            () async =>
                AudioImportPickedFile(path: source.path, name: 'pick.mp3'),
        saveSound:
            saveSound ??
            (audio, {String? personalLabel}) async {
              savedSounds.add(audio);
              lastSavedLabel = personalLabel;
              return SavedSoundSaveResult.saved;
            },
        reclaimAudio: (path) async => reclaimed.add(path),
        viewerAccountId: () => accountId,
        publisher: () => publisher,
        publisherName: 'Alice',
        publisherPubkey: _self,
      );
    }

    void stubPublish(Future<LocalAudioPublishResult> Function() answer) {
      when(
        () => publisher.publish(
          audio: any(named: 'audio'),
          attribution: any(named: 'attribution'),
          allowAudioReuse: any(named: 'allowAudioReuse'),
        ),
      ).thenAnswer((_) => answer());
    }

    Future<AddSoundCubit> sharingCubit({SavedSoundSaver? saveSound}) async {
      final cubit = build(saveSound: saveSound);
      await cubit.pickFileAndImport();
      cubit.setSharePublicly(true);
      return cubit;
    }

    group('pickFileAndImport', () {
      test('copies the picked file and seeds an own-work credit', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(cubit.state.status, AddSoundStatus.ready);
        expect(
          await File(cubit.state.audio!.localFilePath!).readAsBytes(),
          equals([1, 2, 3]),
        );
        expect(
          cubit.state.attribution,
          const AudioShareAttribution(
            title: 'pick',
            creatorName: 'Alice',
            creatorPubkey: _self,
            publicTags: [],
            confirmedOwnWork: true,
          ),
        );
        expect(cubit.state.sharePublicly, isFalse);
        expect(reclaimed, isEmpty);
      });

      test('a cancelled pick returns to idle without reclaiming', () async {
        final cubit = build(pickFile: () async => null);
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(cubit.state.status, AddSoundStatus.idle);
        expect(reclaimed, isEmpty);
      });

      test('a new pick replaces the file and reclaims the old copy', () async {
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.pickFileAndImport();
        final first = cubit.state.audio!;

        await cubit.pickFileAndImport();

        expect(cubit.state.status, AddSoundStatus.ready);
        expect(cubit.state.audio!.id, isNot(first.id));
        expect(reclaimed, equals([first.localFilePath]));
      });

      test('a cancelled or failed re-pick keeps the current file', () async {
        AudioImportPickedFile? nextPick = AudioImportPickedFile(
          path: source.path,
          name: 'pick.mp3',
        );
        final cubit = build(pickFile: () async => nextPick);
        addTearDown(cubit.close);
        await cubit.pickFileAndImport();
        final first = cubit.state.audio!;

        nextPick = null;
        await cubit.pickFileAndImport();
        expect(cubit.state.status, AddSoundStatus.ready);
        expect(cubit.state.audio, same(first));

        nextPick = AudioImportPickedFile(path: source.path, name: 'notes.txt');
        await cubit.pickFileAndImport();
        expect(cubit.state.status, AddSoundStatus.ready);
        expect(cubit.state.audio, same(first));
        expect(cubit.state.failure, AddSoundFailure.unsupportedFormat);
        expect(reclaimed, isEmpty);
      });

      test('an unsupported extension reports an unsupported format', () async {
        final cubit = build(
          pickFile: () async =>
              AudioImportPickedFile(path: source.path, name: 'notes.txt'),
        );
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(cubit.state.status, AddSoundStatus.idle);
        expect(cubit.state.failure, AddSoundFailure.unsupportedFormat);
      });

      test('a decoder failure reports unreadable and leaves no copy', () async {
        durationFn = (_) async => throw const FormatException('bad audio');
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(cubit.state.failure, AddSoundFailure.unreadableFile);
        expect(storageDir.listSync(recursive: true), isEmpty);
        expect(reclaimed, isEmpty);
      });

      test(
        'a file the picker could not hand over reports unreadable',
        () async {
          final cubit = build(pickFile: () async => throw StateError('copy'));
          addTearDown(cubit.close);

          await cubit.pickFileAndImport();

          expect(cubit.state.status, AddSoundStatus.idle);
          expect(cubit.state.failure, AddSoundFailure.unreadableFile);
        },
      );

      test('an account change abandons and reclaims the copy', () async {
        durationFn = (_) async {
          accountId = 'account-b';
          return const Duration(seconds: 3);
        };
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(cubit.state.failure, AddSoundFailure.accountChanged);
        expect(reclaimed, hasLength(1));
        expect(cubit.state.audio, isNull);
      });
    });

    group('updateAttribution', () {
      test('credits the publisher pubkey only while it is own work', () async {
        final cubit = await sharingCubit();
        addTearDown(cubit.close);

        cubit.updateAttribution(
          cubit.state.attribution!.copyWith(
            creatorName: 'Bucket drummer',
            confirmedOwnWork: false,
            sourceUrl: 'https://example.com/source',
          ),
        );
        expect(cubit.state.attribution?.creatorPubkey, isNull);
        expect(cubit.state.attribution?.creatorName, 'Bucket drummer');
        expect(cubit.state.canSave, isTrue);

        cubit.updateAttribution(
          cubit.state.attribution!.copyWith(confirmedOwnWork: true),
        );
        expect(cubit.state.attribution?.creatorPubkey, _self);
      });

      test('an incomplete credit blocks only a public save', () async {
        final cubit = await sharingCubit();
        addTearDown(cubit.close);

        cubit.updateAttribution(
          cubit.state.attribution!.copyWith(confirmedOwnWork: false),
        );
        expect(cubit.state.canSave, isFalse);

        cubit.setSharePublicly(false);
        expect(cubit.state.canSave, isTrue);
      });
    });

    group('save privately', () {
      test('persists the copy with a trimmed private name', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        await cubit.save(personalLabel: '  My loop  ');

        expect(cubit.state.status, AddSoundStatus.saved);
        expect(cubit.state.savedResult, SavedSoundSaveResult.saved);
        expect(savedSounds.single.isLocalImport, isTrue);
        expect(lastSavedLabel, 'My loop');
        verifyNever(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        );
      });

      test('a blank name is passed through as no label', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        await cubit.save(personalLabel: '   ');

        expect(lastSavedLabel, isNull);
      });

      test('a failed save keeps the copy and can be retried', () async {
        var attempts = 0;
        final cubit = build(
          saveSound: (audio, {String? personalLabel}) async {
            attempts++;
            if (attempts == 1) throw StateError('disk full');
            return SavedSoundSaveResult.saved;
          },
        );
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        await cubit.save();

        expect(cubit.state.status, AddSoundStatus.ready);
        expect(cubit.state.failure, AddSoundFailure.saveFailed);
        // The copy must survive so Retry writes the same file, not a new pick.
        expect(cubit.state.audio, isNotNull);
        expect(reclaimed, isEmpty);

        await cubit.save();

        expect(cubit.state.status, AddSoundStatus.saved);
        expect(cubit.state.failure, isNull);
        expect(reclaimed, isEmpty);
      });

      test('an account change before save abandons the copy', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        accountId = 'account-b';
        await cubit.save();

        expect(cubit.state.failure, AddSoundFailure.accountChanged);
        expect(reclaimed, hasLength(1));
        expect(savedSounds, isEmpty);
      });

      test('a second save while one is in flight is ignored', () async {
        final completer = Completer<SavedSoundSaveResult>();
        var saveCalls = 0;
        final cubit = build(
          saveSound: (audio, {String? personalLabel}) {
            saveCalls++;
            return completer.future;
          },
        );
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        final first = cubit.save();
        final second = cubit.save();

        expect(saveCalls, 1);

        completer.complete(SavedSoundSaveResult.saved);
        await first;
        await second;
        expect(cubit.state.status, AddSoundStatus.saved);
      });
    });

    group('save publicly', () {
      test(
        'publishes a reusable sound and saves the published record',
        () async {
          stubPublish(() async => LocalAudioPublished(_publishedEvent()));
          final cubit = await sharingCubit();
          addTearDown(cubit.close);

          await cubit.save(personalLabel: 'ignored when public');

          expect(cubit.state.status, AddSoundStatus.saved);
          expect(cubit.state.publishedSound?.id, _soundEventId);
          expect(savedSounds.single.id, _soundEventId);
          expect(lastSavedLabel, isNull);
          verify(
            () => publisher.publish(
              audio: any(named: 'audio'),
              attribution: cubit.state.attribution!,
              allowAudioReuse: true,
            ),
          ).called(1);
        },
      );

      test('maps a failed publish back to ready and saves nothing', () async {
        stubPublish(
          () async => const LocalAudioPublishFailed(
            LocalAudioPublishFailure.uploadFailed,
          ),
        );
        final cubit = await sharingCubit();
        addTearDown(cubit.close);

        await cubit.save();

        expect(cubit.state.status, AddSoundStatus.ready);
        expect(cubit.state.failure, AddSoundFailure.publishFailed);
        expect(cubit.state.isPublished, isFalse);
        expect(cubit.state.canSave, isTrue);
        expect(savedSounds, isEmpty);
      });

      test('names a signed-out identity as its own failure', () async {
        stubPublish(
          () async => const LocalAudioPublishFailed(
            LocalAudioPublishFailure.notAuthenticated,
          ),
        );
        final cubit = await sharingCubit();
        addTearDown(cubit.close);

        await cubit.save();

        expect(cubit.state.failure, AddSoundFailure.notSignedIn);
      });

      test('surfaces an account restriction', () async {
        stubPublish(
          () async => throw const AccountRestrictedPublishException(
            reason: 'blocked: pubkey is suspended',
            source: AccountRestrictionSource.webSocket,
          ),
        );
        final cubit = await sharingCubit();
        addTearDown(cubit.close);

        await cubit.save();

        expect(cubit.state.status, AddSoundStatus.ready);
        expect(cubit.state.failure, AddSoundFailure.accountRestricted);
      });

      test('retries a failed library write without publishing again', () async {
        stubPublish(() async => LocalAudioPublished(_publishedEvent()));
        var attempts = 0;
        final cubit = await sharingCubit(
          saveSound: (audio, {String? personalLabel}) async {
            attempts++;
            if (attempts == 1) throw StateError('disk full');
            savedSounds.add(audio);
            return SavedSoundSaveResult.saved;
          },
        );
        addTearDown(cubit.close);

        await cubit.save();

        expect(cubit.state.failure, AddSoundFailure.saveFailed);
        expect(cubit.state.isPublished, isTrue);
        // The pending row is bound to the published record, so the file and
        // the share choice are locked.
        expect(cubit.state.canEdit, isFalse);
        expect(cubit.state.canSave, isTrue);

        await cubit.save();

        expect(cubit.state.status, AddSoundStatus.saved);
        expect(savedSounds.single.id, _soundEventId);
        verify(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).called(1);
      });
    });

    group('close', () {
      test('reclaims an unsaved copy', () async {
        final cubit = build();
        await cubit.pickFileAndImport();

        await cubit.close();

        expect(reclaimed, hasLength(1));
      });

      test('does not reclaim a privately saved sound', () async {
        final cubit = build();
        await cubit.pickFileAndImport();
        await cubit.save();

        await cubit.close();

        expect(reclaimed, isEmpty);
      });

      test('reclaims the local copy of a publicly shared sound', () async {
        stubPublish(() async => LocalAudioPublished(_publishedEvent()));
        final cubit = await sharingCubit();
        final copiedPath = cubit.state.audio!.localFilePath;
        await cubit.save();

        await cubit.close();

        // The library row is the published record, served from its URL, so
        // nothing references the local copy any more.
        expect(reclaimed, equals([copiedPath]));
      });

      test('reclaims the copy when the in-flight save then fails', () async {
        final completer = Completer<SavedSoundSaveResult>();
        final cubit = build(
          saveSound: (audio, {String? personalLabel}) => completer.future,
        );

        await cubit.pickFileAndImport();
        final copiedPath = cubit.state.audio!.localFilePath;
        final save = cubit.save();
        // close() hands ownership of the copy to the in-flight save.
        await cubit.close();
        expect(reclaimed, isEmpty);

        completer.completeError(StateError('disk full'));
        await save;

        // The save never took ownership, so nothing else will ever reclaim it.
        expect(reclaimed, equals([copiedPath]));
      });

      test('does not reclaim a copy whose save then succeeds', () async {
        final completer = Completer<SavedSoundSaveResult>();
        final cubit = build(
          saveSound: (audio, {String? personalLabel}) => completer.future,
        );

        await cubit.pickFileAndImport();
        final save = cubit.save();
        await cubit.close();

        completer.complete(SavedSoundSaveResult.saved);
        await save;

        expect(reclaimed, isEmpty);
      });
    });
  });
}
