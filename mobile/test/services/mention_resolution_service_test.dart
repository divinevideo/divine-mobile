import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bobPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _carolPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _frankPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _onePubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _twoPubkey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _threePubkey =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _fourPubkey =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _fivePubkey =
    '5555555555555555555555555555555555555555555555555555555555555555';

void main() {
  late _MockProfileRepository profileRepository;
  late MentionResolutionService service;

  setUp(() {
    profileRepository = _MockProfileRepository();
    service = MentionResolutionService(profileRepository: profileRepository);
  });

  group('resolveTextMentions', () {
    test(
      'canonicalizes selected mentions and records full hex pubkeys',
      () async {
        final aliceNpub = NostrKeyUtils.encodePubKey(_alicePubkey);

        final result = await service.resolveTextMentions(
          rawText: 'hi @alice',
          selectedMentions: const [
            MentionBinding(display: 'alice', pubkey: _alicePubkey),
          ],
        );

        expect(result.canonicalText, equals('hi nostr:$aliceNpub'));
        expect(result.resolvedPubkeys, equals([_alicePubkey]));
        expect(result.unresolvedTokens, isEmpty);
        verifyNever(
          () => profileRepository.searchUsersLocally(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        );
        verifyNever(
          () => profileRepository.searchUsersFromApi(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    test(
      'accepts selected npub bindings and canonicalizes with full hex',
      () async {
        final aliceNpub = NostrKeyUtils.encodePubKey(_alicePubkey);

        final result = await service.resolveTextMentions(
          rawText: 'hi @alice',
          selectedMentions: [
            MentionBinding(display: '@alice', pubkey: aliceNpub),
          ],
        );

        expect(result.canonicalText, equals('hi nostr:$aliceNpub'));
        expect(result.resolvedPubkeys, equals([_alicePubkey]));
      },
    );

    test(
      'skips selected bindings whose token is no longer in the text',
      () async {
        final result = await service.resolveTextMentions(
          rawText: 'hi there',
          selectedMentions: const [
            MentionBinding(display: 'alice', pubkey: _alicePubkey),
          ],
        );

        expect(result.canonicalText, equals('hi there'));
        expect(result.resolvedPubkeys, isEmpty);
        expect(result.unresolvedTokens, isEmpty);
      },
    );

    test(
      'skips ranged selected bindings when the range no longer matches',
      () async {
        final result = await service.resolveTextMentions(
          rawText: 'hi xxxx',
          selectedMentions: const [
            MentionBinding(
              display: 'alice',
              pubkey: _alicePubkey,
              start: 3,
              end: 7,
            ),
          ],
        );

        expect(result.canonicalText, equals('hi xxxx'));
        expect(result.resolvedPubkeys, isEmpty);
      },
    );

    test(
      'uses newest selected binding for the same visible token range',
      () async {
        final bobNpub = NostrKeyUtils.encodePubKey(_bobPubkey);

        final result = await service.resolveTextMentions(
          rawText: 'hi @alice',
          selectedMentions: const [
            MentionBinding(
              display: 'alice',
              pubkey: _alicePubkey,
              start: 3,
              end: 9,
            ),
            MentionBinding(
              display: 'alice',
              pubkey: _bobPubkey,
              start: 3,
              end: 9,
            ),
          ],
        );

        expect(result.canonicalText, equals('hi nostr:$bobNpub'));
        expect(result.resolvedPubkeys, equals([_bobPubkey]));
      },
    );

    test(
      'keeps selected mention when text is inserted before its old range',
      () async {
        final aliceNpub = NostrKeyUtils.encodePubKey(_alicePubkey);

        final result = await service.resolveTextMentions(
          rawText: 'well hi @alice',
          selectedMentions: const [
            MentionBinding(
              display: 'alice',
              pubkey: _alicePubkey,
              start: 3,
              end: 9,
            ),
          ],
        );

        expect(result.canonicalText, equals('well hi nostr:$aliceNpub'));
        expect(result.resolvedPubkeys, equals([_alicePubkey]));
      },
    );

    test(
      'resolves exact cached typed mentions and excludes emails and URLs',
      () async {
        final aliceNpub = NostrKeyUtils.encodePubKey(_alicePubkey);
        when(
          () => profileRepository.searchUsersLocally(
            query: 'alice',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [_profile(_alicePubkey, name: 'alice')]);

        final result = await service.resolveTextMentions(
          rawText: 'hi @alice email me@bob.com https://divine.video/@carol',
        );

        expect(
          result.canonicalText,
          equals(
            'hi nostr:$aliceNpub email me@bob.com https://divine.video/@carol',
          ),
        );
        expect(result.resolvedPubkeys, equals([_alicePubkey]));
        expect(result.unresolvedTokens, isEmpty);
        verify(
          () => profileRepository.searchUsersLocally(
            query: 'alice',
            limit: any(named: 'limit'),
          ),
        ).called(1);
        verifyNever(
          () => profileRepository.searchUsersLocally(
            query: 'bob',
            limit: any(named: 'limit'),
          ),
        );
        verifyNever(
          () => profileRepository.searchUsersLocally(
            query: 'carol',
            limit: any(named: 'limit'),
          ),
        );
        verifyNever(
          () => profileRepository.searchUsersFromApi(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    test('leaves ambiguous typed matches unchanged', () async {
      when(
        () => profileRepository.searchUsersLocally(
          query: 'alex',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          _profile(_alicePubkey, name: 'alex'),
          _profile(_bobPubkey, displayName: 'Alex'),
        ],
      );
      when(
        () => profileRepository.searchUsersFromApi(
          query: 'alex',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const []);

      final result = await service.resolveTextMentions(rawText: 'hi @alex');

      expect(result.canonicalText, equals('hi @alex'));
      expect(result.resolvedPubkeys, isEmpty);
      expect(result.unresolvedTokens, equals(['alex']));
    });

    test(
      'uses exact API matches after cache miss and caps remote lookups at five',
      () async {
        final pubkeysByToken = {
          'one': _onePubkey,
          'two': _twoPubkey,
          'three': _threePubkey,
          'four': _fourPubkey,
          'five': _fivePubkey,
          'six': _frankPubkey,
        };
        final remoteQueries = <String>[];
        when(
          () => profileRepository.searchUsersLocally(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => profileRepository.searchUsersFromApi(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((invocation) async {
          final query = invocation.namedArguments[#query] as String;
          remoteQueries.add(query);
          return [_profile(pubkeysByToken[query]!, name: query)];
        });

        final result = await service.resolveTextMentions(
          rawText: '@one @two @three @four @five @six',
        );

        expect(remoteQueries, equals(['one', 'two', 'three', 'four', 'five']));
        expect(
          result.resolvedPubkeys,
          equals([
            _onePubkey,
            _twoPubkey,
            _threePubkey,
            _fourPubkey,
            _fivePubkey,
          ]),
        );
        expect(result.canonicalText, contains('@six'));
        expect(result.unresolvedTokens, equals(['six']));
      },
    );

    test(
      'keeps typed self matches unresolved unless explicitly selected',
      () async {
        when(
          () => profileRepository.searchUsersLocally(
            query: 'alice',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [_profile(_alicePubkey, name: 'alice')]);
        when(
          () => profileRepository.searchUsersFromApi(
            query: 'alice',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => const []);

        final typed = await service.resolveTextMentions(
          rawText: 'hi @alice',
          currentUserPubkey: _alicePubkey,
        );
        final selected = await service.resolveTextMentions(
          rawText: 'hi @alice',
          selectedMentions: const [
            MentionBinding(display: 'alice', pubkey: _alicePubkey),
          ],
          currentUserPubkey: _alicePubkey,
        );

        expect(typed.canonicalText, equals('hi @alice'));
        expect(typed.resolvedPubkeys, isEmpty);
        expect(typed.unresolvedTokens, equals(['alice']));
        expect(selected.resolvedPubkeys, equals([_alicePubkey]));
        expect(selected.canonicalText, contains('nostr:npub1'));
      },
    );

    test('returns selected mentions when typed lookup fails', () async {
      final aliceNpub = NostrKeyUtils.encodePubKey(_alicePubkey);
      when(
        () => profileRepository.searchUsersLocally(
          query: 'bob',
          limit: any(named: 'limit'),
        ),
      ).thenThrow(Exception('cache unavailable'));

      final result = await service.resolveTextMentions(
        rawText: '@alice @bob',
        selectedMentions: const [
          MentionBinding(display: 'alice', pubkey: _alicePubkey),
        ],
      );

      expect(result.canonicalText, equals('nostr:$aliceNpub @bob'));
      expect(result.resolvedPubkeys, equals([_alicePubkey]));
      expect(result.unresolvedTokens, equals(['bob']));
    });

    test('bounds typed resolution with one total timeout', () async {
      final stalledLookup = Completer<List<UserProfile>>();
      service = MentionResolutionService(
        profileRepository: profileRepository,
        typedResolutionTimeout: const Duration(milliseconds: 1),
      );
      when(
        () => profileRepository.searchUsersLocally(
          query: 'alice',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => stalledLookup.future);

      final result = await service.resolveTextMentions(rawText: 'hi @alice');

      expect(result.canonicalText, equals('hi @alice'));
      expect(result.resolvedPubkeys, isEmpty);
      expect(result.unresolvedTokens, equals(['alice']));
    });

    // A handle carrying a dot or a hyphen used to tokenize only up to the
    // separator, so `@OG-AB` searched for `OG` and canonicalized to whoever
    // owned that shorter handle — a p tag naming the wrong person.
    group('handles containing dots and hyphens', () {
      test('resolves the whole hyphenated handle, not its prefix', () async {
        final bobNpub = NostrKeyUtils.encodePubKey(_bobPubkey);
        when(
          () => profileRepository.searchUsersLocally(
            query: 'OG-AB',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [_profile(_bobPubkey, name: 'OG-AB')]);

        final result = await service.resolveTextMentions(
          rawText: 'dedicated to my home-girl @OG-AB',
        );

        expect(
          result.canonicalText,
          equals('dedicated to my home-girl nostr:$bobNpub'),
        );
        expect(result.resolvedPubkeys, equals([_bobPubkey]));
        expect(result.unresolvedTokens, isEmpty);
        verifyNever(
          () => profileRepository.searchUsersLocally(
            query: 'OG',
            limit: any(named: 'limit'),
          ),
        );
      });

      test(
        'does not resolve a hyphenated handle to its prefix owner',
        () async {
          when(
            () => profileRepository.searchUsersLocally(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [_profile(_alicePubkey, name: 'OG')]);
          when(
            () => profileRepository.searchUsersFromApi(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [_profile(_alicePubkey, name: 'OG')]);

          final result = await service.resolveTextMentions(
            rawText: 'hi @OG-AB',
          );

          expect(result.canonicalText, equals('hi @OG-AB'));
          expect(result.resolvedPubkeys, isEmpty);
        },
      );

      test('searches a dotted handle as typed', () async {
        final carolNpub = NostrKeyUtils.encodePubKey(_carolPubkey);
        when(
          () => profileRepository.searchUsersLocally(
            query: 'ickynicki.v2',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [_profile(_carolPubkey, name: 'ickynicki.v2')],
        );

        final result = await service.resolveTextMentions(
          rawText: 'inspired by @ickynicki.v2',
        );

        expect(result.canonicalText, equals('inspired by nostr:$carolNpub'));
        expect(result.resolvedPubkeys, equals([_carolPubkey]));
      });

      test(
        'resolves handles that differ only by separators independently',
        () async {
          final aliceNpub = NostrKeyUtils.encodePubKey(_alicePubkey);
          final bobNpub = NostrKeyUtils.encodePubKey(_bobPubkey);
          when(
            () => profileRepository.searchUsersLocally(
              query: 'og-ab',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [_profile(_bobPubkey, name: 'og-ab')]);
          when(
            () => profileRepository.searchUsersLocally(
              query: 'ogab',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [_profile(_alicePubkey, name: 'ogab')]);

          final result = await service.resolveTextMentions(
            rawText: 'shoutout @og-ab and @ogab',
          );

          expect(
            result.canonicalText,
            equals('shoutout nostr:$bobNpub and nostr:$aliceNpub'),
          );
          expect(result.resolvedPubkeys, equals([_bobPubkey, _alicePubkey]));
          expect(result.unresolvedTokens, isEmpty);
        },
      );
    });
  });

  group('buildGenericMentionPTags', () {
    test(
      'dedupes full pubkeys and excludes invalid and collaborator pubkeys',
      () {
        final tags = service.buildGenericMentionPTags(
          pubkeys: const [
            _alicePubkey,
            'not-a-pubkey',
            _bobPubkey,
            _alicePubkey,
            _carolPubkey,
          ],
          collaboratorPubkeys: const [_bobPubkey],
        );

        expect(
          tags,
          equals(const [
            ['p', _alicePubkey, 'wss://relay.divine.video', 'mention'],
            ['p', _carolPubkey, 'wss://relay.divine.video', 'mention'],
          ]),
        );
      },
    );
  });
}

UserProfile _profile(
  String pubkey, {
  String? name,
  String? displayName,
  String? nip05,
}) {
  return UserProfile(
    pubkey: pubkey,
    name: name,
    displayName: displayName,
    nip05: nip05,
    rawData: const {},
    createdAt: DateTime.utc(2026),
    eventId: 'event-$pubkey',
  );
}
