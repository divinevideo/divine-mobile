// ABOUTME: Tests encrypted collaborator invite payload construction.
// ABOUTME: Verifies collab invites are NIP-17 DMs with structured tags.

import 'dart:ui' show Locale;

import 'package:collection/collection.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/collaborator_invite_service.dart';

class _MockDmRepository extends Mock implements DmRepository {}

const _deepEquals = DeepCollectionEquality();

bool _containsTag(List<List<String>> tags, List<String> expected) {
  return tags.any((tag) => _deepEquals.equals(tag, expected));
}

void main() {
  late _MockDmRepository dmRepository;
  late CollaboratorInviteService service;

  const creatorPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const videoAddress =
      '34236:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:video-id';

  setUp(() {
    dmRepository = _MockDmRepository();
    service = CollaboratorInviteService(dmRepository: dmRepository);
  });

  group('sendInvite', () {
    test('sends readable invite content with structured collab tags', () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor-id',
          messageEventId: 'message-id',
          recipientPubkey: collaboratorPubkey,
        ),
      );

      final result = await service.sendInvite(
        collaboratorPubkey: collaboratorPubkey,
        creatorPubkey: creatorPubkey,
        videoAddress: videoAddress,
        title: 'Skate loop',
        thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
      );

      expect(result.success, isTrue);

      final verification = verify(
        () => dmRepository.sendMessage(
          recipientPubkey: collaboratorPubkey,
          content: captureAny(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: captureAny(named: 'additionalTags'),
          skipNip04Fallback: captureAny(named: 'skipNip04Fallback'),
        ),
      );

      final content = verification.captured[0] as String;
      final tags = verification.captured[1] as List<List<String>>;
      final skipNip04Fallback = verification.captured[2] as bool;

      expect(content, contains('Skate loop'));
      expect(content, contains('collaborate'));
      expect(
        content,
        contains('https://divine.video/video/video-id'),
        reason:
            'Plaintext fallback must include a divine.video URL so non-Divine '
            'Nostr clients can preview the video and verify the invite '
            'matches a real video before accepting (#3942).',
      );
      // The d tag alone can name another account's video (#10929).
      expect(
        content,
        contains('https://divine.video/video/video-id?author=$creatorPubkey'),
      );
      expect(_containsTag(tags, const ['divine', 'collab-invite']), isTrue);
      expect(
        _containsTag(tags, const [
          'a',
          videoAddress,
          'wss://relay.divine.video',
          'root',
        ]),
        isTrue,
      );
      expect(_containsTag(tags, const ['p', creatorPubkey]), isTrue);
      expect(_containsTag(tags, const ['role', 'Collaborator']), isTrue);
      expect(_containsTag(tags, const ['title', 'Skate loop']), isTrue);
      expect(
        _containsTag(tags, const [
          'thumb',
          'https://cdn.example.com/thumb.jpg',
        ]),
        isTrue,
      );
      // Structured invites must skip the NIP-04 legacy fallback — the
      // fallback would publish a duplicate plaintext message (#3559).
      expect(skipNip04Fallback, isTrue);
    });

    test(
      'preserves retryable-pending without reporting a hard failure',
      () async {
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'Recipient DM inbox unreadable; published to the fallback pool',
            retryablePending: true,
            queuedRumorId: 'queued-rumor-id',
          ),
        );

        final result = await service.sendInvite(
          collaboratorPubkey: collaboratorPubkey,
          creatorPubkey: creatorPubkey,
          videoAddress: videoAddress,
        );

        expect(result.success, isFalse);
        expect(result.retryablePending, isTrue);
        expect(result.error, isNull);
        expect(
          CollaboratorInviteBatchResult(
            results: {collaboratorPubkey: result},
          ).hasFailures,
          isFalse,
        );
      },
    );

    test(
      'content endsWith invitePlaintextSuffix (contract for UI suppression)',
      () async {
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: 'rumor-id',
            messageEventId: 'message-id',
            recipientPubkey: collaboratorPubkey,
          ),
        );

        await service.sendInvite(
          collaboratorPubkey: collaboratorPubkey,
          creatorPubkey: creatorPubkey,
          videoAddress: videoAddress,
          title: 'Skate loop',
        );

        final captured =
            verify(
                  () => dmRepository.sendMessage(
                    recipientPubkey: collaboratorPubkey,
                    content: captureAny(named: 'content'),
                    replyToId: any(named: 'replyToId'),
                    additionalTags: any(named: 'additionalTags'),
                    skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  ),
                ).captured.single
                as String;

        expect(
          captured.endsWith(CollaboratorInviteService.invitePlaintextSuffix),
          isTrue,
          reason:
              '_buildContent must end with invitePlaintextSuffix so the '
              'conversation view can suppress legacy NIP-04 duplicates (#3559)',
        );
      },
    );

    test('includes divine.video URL when title is missing', () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor-id',
          messageEventId: 'message-id',
          recipientPubkey: collaboratorPubkey,
        ),
      );

      await service.sendInvite(
        collaboratorPubkey: collaboratorPubkey,
        creatorPubkey: creatorPubkey,
        videoAddress: videoAddress,
      );

      final captured =
          verify(
                () => dmRepository.sendMessage(
                  recipientPubkey: collaboratorPubkey,
                  content: captureAny(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  additionalTags: any(named: 'additionalTags'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                ),
              ).captured.single
              as String;

      expect(captured, contains('https://divine.video/video/video-id'));
      expect(
        captured.endsWith(CollaboratorInviteService.invitePlaintextSuffix),
        isTrue,
      );
    });

    test('URL stableId matches the d-tag of the videoAddress', () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor-id',
          messageEventId: 'message-id',
          recipientPubkey: collaboratorPubkey,
        ),
      );

      const otherVideoAddress =
          '34236:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:custom-d-tag';

      await service.sendInvite(
        collaboratorPubkey: collaboratorPubkey,
        creatorPubkey: creatorPubkey,
        videoAddress: otherVideoAddress,
        title: 'Highlight reel',
      );

      final captured =
          verify(
                () => dmRepository.sendMessage(
                  recipientPubkey: collaboratorPubkey,
                  content: captureAny(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  additionalTags: any(named: 'additionalTags'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                ),
              ).captured.single
              as String;

      expect(
        captured,
        contains('https://divine.video/video/custom-d-tag'),
        reason:
            'URL must use the d-tag (third segment of the parameterized '
            'addressable) so it deep-links via the existing /video/:id route.',
      );
      expect(
        captured,
        isNot(contains('https://divine.video/video/video-id')),
        reason: 'URL must reflect the videoAddress passed in, not a default.',
      );
    });

    test('preserves colons inside d-tag stableId in URL', () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor-id',
          messageEventId: 'message-id',
          recipientPubkey: collaboratorPubkey,
        ),
      );

      // NIP-01 doesn't reserve `:` in d-tags. A naive split-on-colon parser
      // truncates everything past the third segment, producing
      // `https://divine.video/video/foo` for a stableId of `foo:bar`.
      const colonyVideoAddress =
          '34236:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:foo:bar';

      await service.sendInvite(
        collaboratorPubkey: collaboratorPubkey,
        creatorPubkey: creatorPubkey,
        videoAddress: colonyVideoAddress,
        title: 'Edge case',
      );

      final captured =
          verify(
                () => dmRepository.sendMessage(
                  recipientPubkey: collaboratorPubkey,
                  content: captureAny(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  additionalTags: any(named: 'additionalTags'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                ),
              ).captured.single
              as String;

      expect(
        captured,
        contains('https://divine.video/video/foo:bar'),
        reason:
            'd-tag is everything after kind:pubkey: — colons within it must '
            'survive into the URL so divine.video can resolve the stableId.',
      );
    });

    test(
      'localized DM body for non-English locale still contains the video URL',
      () async {
        // Translators must preserve the {url} placeholder. Without an
        // assertion on the resolved body, a translator could silently drop
        // the URL and the only signal would be a missing tappable preview
        // in non-English clients (the bug this PR fixes).
        final esService = CollaboratorInviteService(
          dmRepository: dmRepository,
          l10n: lookupAppLocalizations(const Locale('es')),
        );
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: 'rumor-id',
            messageEventId: 'message-id',
            recipientPubkey: collaboratorPubkey,
          ),
        );

        await esService.sendInvite(
          collaboratorPubkey: collaboratorPubkey,
          creatorPubkey: creatorPubkey,
          videoAddress: videoAddress,
          title: 'Skate loop',
        );

        final captured =
            verify(
                  () => dmRepository.sendMessage(
                    recipientPubkey: collaboratorPubkey,
                    content: captureAny(named: 'content'),
                    replyToId: any(named: 'replyToId'),
                    additionalTags: any(named: 'additionalTags'),
                    skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  ),
                ).captured.single
                as String;

        expect(captured, contains('https://divine.video/video/video-id'));
        expect(captured, contains('Skate loop'));
        // Sanity-check that we actually produced the Spanish body — not
        // the English fallback that lookupAppLocalizations could silently
        // return if the locale failed to resolve.
        expect(
          captured,
          contains('colaborar'),
          reason: 'Spanish body should contain the translated verb.',
        );
      },
    );

    test(
      'localized untitled DM body for non-English locale still contains URL',
      () async {
        final esService = CollaboratorInviteService(
          dmRepository: dmRepository,
          l10n: lookupAppLocalizations(const Locale('es')),
        );
        when(
          () => dmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: 'rumor-id',
            messageEventId: 'message-id',
            recipientPubkey: collaboratorPubkey,
          ),
        );

        await esService.sendInvite(
          collaboratorPubkey: collaboratorPubkey,
          creatorPubkey: creatorPubkey,
          videoAddress: videoAddress,
        );

        final captured =
            verify(
                  () => dmRepository.sendMessage(
                    recipientPubkey: collaboratorPubkey,
                    content: captureAny(named: 'content'),
                    replyToId: any(named: 'replyToId'),
                    additionalTags: any(named: 'additionalTags'),
                    skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  ),
                ).captured.single
                as String;

        expect(captured, contains('https://divine.video/video/video-id'));
      },
    );

    test('returns failure when encrypted DM send fails', () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.failure('relay unavailable'),
      );

      final result = await service.sendInvite(
        collaboratorPubkey: collaboratorPubkey,
        creatorPubkey: creatorPubkey,
        videoAddress: videoAddress,
      );

      expect(result.success, isFalse);
      expect(result.error, 'relay unavailable');
    });
  });

  group('hasInvitePlaintextSuffix', () {
    test('matches the current wire text', () {
      expect(
        CollaboratorInviteService.hasInvitePlaintextSuffix(
          'You were invited to collaborate on Skate loop: https://x\n\n'
          'Open Divine to review and accept.',
        ),
        isTrue,
      );
    });

    // Nostr events are immutable: correcting the ARB casing did not rewrite
    // the invites already on relays. Matching only the new spelling would
    // un-suppress every one of them and put the useless plaintext bubble
    // back in the conversation (#3559). These spellings are written out
    // rather than read from `legacyInvitePlaintextSuffixes`, so that
    // dropping an entry from that list fails here instead of shrinking the
    // assertion along with it.
    const historicalWireTexts = ['Open diVine to review and accept.'];

    for (final legacy in historicalWireTexts) {
      test('still matches invites published as "$legacy"', () {
        expect(
          CollaboratorInviteService.hasInvitePlaintextSuffix(
            'You were invited to collaborate on Skate loop: https://x\n\n'
            '$legacy',
          ),
          isTrue,
          reason: 'legacy wire text $legacy must stay suppressed',
        );
      });
    }

    test('leaves an ordinary message alone', () {
      expect(
        CollaboratorInviteService.hasInvitePlaintextSuffix('hey, see this?'),
        isFalse,
      );
    });
  });
}
