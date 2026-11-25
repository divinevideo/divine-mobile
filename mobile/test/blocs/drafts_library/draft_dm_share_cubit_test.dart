import 'dart:io';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/drafts_library/draft_dm_share_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/video_dm_outbox.dart';
import 'package:path/path.dart' as path;
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockOutbox extends Mock implements VideoDmOutbox {}

const _sender =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _recipient =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _draftId = 'saved-draft';

void main() {
  late Directory directory;
  late File source;
  late File output;
  late _MockOutbox outbox;
  late DraftDmShareCubit cubit;
  late DivineVideoDraft? draft;
  late bool ownsSession;
  late bool exported;
  late Future<File> Function() export;
  late DmSendPolicyDecision policy;
  late bool blocked;
  late String? coverBlurhash;
  final conversationId = DmRepository.computeConversationId([
    _sender,
    _recipient,
  ]);

  DivineVideoClip clip(File file) => DivineVideoClip(
    id: path.basenameWithoutExtension(file.path),
    video: EditorVideo.file(file.path),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime.utc(2026),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: AspectRatio.vertical,
  );

  void send({required File file}) => outbox.sendDraft(
    conversationId: conversationId,
    recipientPubkey: _recipient,
    file: file,
    title: 'Feedback draft',
    blurhash: coverBlurhash,
  );

  setUpAll(() => registerFallbackValue(File('project.divinedraft')));

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('draft-share-test-');
    addTearDown(() => directory.delete(recursive: true));

    source = await File(path.join(directory.path, 'source.mp4')).writeAsString(
      'source',
    );
    output = File(path.join(directory.path, 'project.divinedraft'));
    draft = DivineVideoDraft.create(
      id: _draftId,
      clips: [clip(source)],
      title: 'Feedback draft',
      description: '',
      hashtags: const {},
      selectedApproach: 'default',
    );
    ownsSession = true;
    exported = false;
    policy = DmSendPolicyDecision.allowed;
    blocked = false;
    coverBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
    export = () => output.writeAsString('export');
    outbox = _MockOutbox();
    cubit = DraftDmShareCubit(
      senderPubkey: _sender,
      recipientPubkey: _recipient,
      loadDraft: (id) async => id == _draftId ? draft : null,
      exportDraft: (draftToExport) {
        expect(draftToExport, same(draft));
        exported = true;
        return export();
      },
      readCoverBlurhash: (draftToRead) async {
        expect(draftToRead, same(draft));
        return coverBlurhash;
      },
      ownsSession: () => ownsSession,
      sendPolicy: (_) async => policy,
      isBlocked: (pubkey) => pubkey == _recipient && blocked,
      outbox: outbox,
    );
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
  });

  group(DraftDmShareCubit, () {
    group('send', () {
      test('hands a new export to the one-to-one outbox only once', () async {
        await Future.wait([cubit.send(_draftId), cubit.send(_draftId)]);

        expect(exported, isTrue);
        expect(cubit.state, DraftDmShareState.queued);
        verify(() => send(file: output)).called(1);
        expect(await source.readAsString(), 'source');
        expect(output.existsSync(), isTrue);
      });

      test("sends the draft's title and cover blurhash", () async {
        await cubit.send(_draftId);

        verify(
          () => outbox.sendDraft(
            conversationId: conversationId,
            recipientPubkey: _recipient,
            file: output,
            title: 'Feedback draft',
            blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          ),
        ).called(1);
      });

      test('still sends when the cover cannot be read', () async {
        coverBlurhash = null;

        await cubit.send(_draftId);

        expect(cubit.state, DraftDmShareState.queued);
        verify(
          () => outbox.sendDraft(
            conversationId: conversationId,
            recipientPubkey: _recipient,
            file: output,
            title: 'Feedback draft',
          ),
        ).called(1);
      });

      test('reports an export failure without sending the source', () async {
        export = () async => throw StateError('export failed');

        await cubit.send(_draftId);

        expect(cubit.state, DraftDmShareState.failed);
        verifyZeroInteractions(outbox);
        expect(source.existsSync(), isTrue);
      });

      test('cleans up if the account switches while exporting', () async {
        export = () async {
          ownsSession = false;
          return output.writeAsString('abandoned export');
        };

        await cubit.send(_draftId);

        expect(cubit.state, DraftDmShareState.accountChanged);
        expect(output.existsSync(), isFalse);
        verifyZeroInteractions(outbox);
      });

      test('cleans up if the confirmation closes while exporting', () async {
        export = () async {
          await cubit.close();
          return output.writeAsString('cancelled export');
        };

        await cubit.send(_draftId);

        expect(output.existsSync(), isFalse);
        verifyZeroInteractions(outbox);
      });

      test('rechecks recipient permissions after exporting', () async {
        export = () async {
          policy = DmSendPolicyDecision.temporarilyBlocked;
          return output.writeAsString('blocked export');
        };

        await cubit.send(_draftId);

        expect(cubit.state, DraftDmShareState.blocked);
        expect(output.existsSync(), isFalse);
        verifyZeroInteractions(outbox);
      });

      test(
        'does not export or send for a recipient the user has blocked',
        () async {
          blocked = true;

          await cubit.send(_draftId);

          expect(exported, isFalse);
          expect(cubit.state, DraftDmShareState.recipientBlockedByUs);
          verifyZeroInteractions(outbox);
        },
      );
    });
  });
}
