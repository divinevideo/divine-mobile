import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('BadgeRepository', () {
    late _MockNostrClient nostrClient;
    late SharedPreferences preferences;
    late Event? Function() lastSignedEvent;
    late BadgeRepository repository;
    late Event? signedEvent;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Filter());
      registerFallbackValue(_event(id: _eventId(999), pubkey: _pubkey(999)));
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      nostrClient = _MockNostrClient();
      signedEvent = null;
      lastSignedEvent = () => signedEvent;

      when(() => nostrClient.queryEvents(any())).thenAnswer((_) async => []);
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments.single as Event;
        return _acceptedPublishOutcome(event);
      });

      repository = BadgeRepository(
        nostrClient: nostrClient,
        sharedPreferences: preferences,
        currentPubkey: () => _pubkey(1),
        signEvent: ({required kind, required content, required tags}) async {
          return signedEvent = _event(
            id: _eventId(900 + kind),
            pubkey: _pubkey(1),
            kind: kind,
            tags: tags,
            content: content,
          );
        },
      );
    });

    test('subscriptions publish a public addressable event and sync', () async {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'daily-diviner',
      );

      final saved = await repository.setSubscription(
        coordinate,
        subscribed: true,
      );

      expect(saved, {coordinate});
      expect(lastSignedEvent()?.kind, EventKind.appSpecificData);
      expect(lastSignedEvent()?.tags, [
        ['d', 'divine.badge_subscriptions'],
        ['a', coordinate.value],
      ]);
      expect(await repository.loadSubscriptions(), {coordinate});

      final published = lastSignedEvent()!;
      when(() => nostrClient.queryEvents(any())).thenAnswer(
        (_) async => [published],
      );
      final otherDevice = BadgeRepository(
        nostrClient: nostrClient,
        sharedPreferences: preferences,
        currentPubkey: () => _pubkey(1),
        signEvent: ({required kind, required content, required tags}) async =>
            null,
      );
      expect(await otherDevice.loadSubscriptions(), {coordinate});
    });

    test('subscription mutation refuses a partial relay read', () async {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: true, noRelays: false),
      );

      await expectLater(
        repository.setSubscription(
          BadgeCoordinate(pubkey: _pubkey(2), identifier: 'daily-diviner'),
          subscribed: true,
        ),
        throwsStateError,
      );
      verifyNever(() => nostrClient.publishEventAwaitOk(any()));
    });

    test('subscriptions prefer the newest event and can be removed', () async {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'daily-diviner',
      );
      final older = _event(
        id: _eventId(1),
        pubkey: _pubkey(1),
        kind: EventKind.appSpecificData,
        createdAt: 999,
        tags: [
          ['d', 'divine.badge_subscriptions'],
        ],
      );
      final newer = _event(
        id: _eventId(2),
        pubkey: _pubkey(1),
        kind: EventKind.appSpecificData,
        tags: [
          ['d', 'divine.badge_subscriptions'],
          ['a', coordinate.value],
        ],
      );
      when(() => nostrClient.queryEvents(any())).thenAnswer(
        (_) async => [older, newer],
      );
      expect(await repository.loadSubscriptions(), {coordinate});

      await repository.setSubscription(coordinate, subscribed: true);
      when(() => nostrClient.queryEvents(any())).thenAnswer(
        (_) async => [older],
      );
      expect(await repository.loadSubscriptions(), {coordinate});

      final sameSecondHigherId = _event(
        id: _eventId(900000),
        pubkey: _pubkey(1),
        kind: EventKind.appSpecificData,
        tags: [
          ['d', 'divine.badge_subscriptions'],
        ],
      );
      when(() => nostrClient.queryEvents(any())).thenAnswer(
        (_) async => [sameSecondHigherId],
      );
      expect(await repository.loadSubscriptions(), {coordinate});

      expect(
        await repository.setSubscription(coordinate, subscribed: false),
        isEmpty,
      );
      expect(lastSignedEvent()?.tags, [
        ['d', 'divine.badge_subscriptions'],
      ]);
    });

    test('loads the latest definitions from curated issuers', () async {
      final issuer = _pubkey(2);
      final secondIssuer = _pubkey(3);
      when(() => nostrClient.readAllEvents(any())).thenAnswer((
        invocation,
      ) async {
        final filter = invocation.positionalArguments.single as Filter;
        final author = filter.authors!.single;
        return PagedQueryResult(
          events: author == issuer
              ? [
                  _definitionEvent(
                    pubkey: issuer,
                    dTag: 'daily',
                    name: 'Old name',
                    id: _eventId(10),
                    createdAt: 900,
                  ),
                  _definitionEvent(
                    pubkey: issuer,
                    dTag: 'daily',
                    name: 'Daily',
                    id: _eventId(11),
                  ),
                ]
              : [
                  _definitionEvent(
                    pubkey: secondIssuer,
                    dTag: 'weekly',
                    name: 'Weekly',
                    id: _eventId(12),
                  ),
                ],
          isComplete: true,
          pages: 1,
        );
      });

      final definitions = await repository.loadDefinitionsByIssuers([
        'not-a-pubkey',
        issuer,
        issuer,
        secondIssuer,
      ]);

      expect(definitions.map((definition) => definition.name), [
        'Daily',
        'Weekly',
      ]);
      verify(() => nostrClient.readAllEvents(any())).called(2);
    });

    test('rejects an incomplete curated definition walk', () async {
      when(() => nostrClient.readAllEvents(any())).thenAnswer(
        (_) async => const PagedQueryResult(
          events: [],
          isComplete: false,
          pages: 1,
        ),
      );

      await expectLater(
        repository.loadDefinitionsByIssuers([_pubkey(2)]),
        throwsStateError,
      );
    });

    test(
      'accepted holders include recipients beyond a 200-event page',
      () async {
        final coordinate = BadgeCoordinate(
          pubkey: _pubkey(2),
          identifier: 'daily-diviner',
        );
        final recipients = [for (var i = 10; i < 215; i++) _pubkey(i)];
        when(() => nostrClient.readAllEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filter = invocation.positionalArguments.single as Filter;
          if (filter.kinds?.contains(EventKind.eventDeletion) == true) {
            return const PagedQueryResult(
              events: [],
              isComplete: true,
              pages: 1,
            );
          }
          if (filter.kinds?.contains(EventKind.profileBadges) == true) {
            return PagedQueryResult(
              events: [
                for (final pubkey in filter.authors ?? const <String>[])
                  _profileBadgesEvent(
                    id: _eventId(500 + recipients.indexOf(pubkey)),
                    pubkey: pubkey,
                    tags: [
                      ['a', coordinate.value],
                      ['e', _eventId(100 + recipients.indexOf(pubkey))],
                    ],
                  ),
              ],
              isComplete: true,
              pages: 1,
            );
          }
          if (filter.kinds?.contains(EventKind.badgeSet) == true) {
            return const PagedQueryResult(
              events: [],
              isComplete: true,
              pages: 1,
            );
          }
          return PagedQueryResult(
            events: [
              for (var i = 0; i < recipients.length; i++)
                _awardEvent(
                  id: _eventId(i + 100),
                  issuerPubkey: coordinate.pubkey,
                  definitionCoordinate: coordinate.value,
                  recipients: [recipients[i]],
                ),
            ],
            isComplete: true,
            pages: 2,
          );
        });
        final holders = await repository.loadAcceptedHolders(coordinate);

        expect(holders, recipients.toSet());
      },
    );

    test('accepted holders reject an incomplete relay walk', () async {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'daily-diviner',
      );
      when(() => nostrClient.readAllEvents(any())).thenAnswer((_) async {
        return const PagedQueryResult(
          events: [],
          isComplete: false,
          pages: 1,
        );
      });

      await expectLater(
        repository.loadAcceptedHolders(coordinate),
        throwsStateError,
      );
    });

    test('accepted holders reject an incomplete profile read', () async {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'daily-diviner',
      );
      when(() => nostrClient.readAllEvents(any())).thenAnswer((
        invocation,
      ) async {
        final filter = invocation.positionalArguments.single as Filter;
        if (filter.kinds?.contains(EventKind.badgeAward) == true) {
          return PagedQueryResult(
            events: [
              _awardEvent(
                id: _eventId(50),
                issuerPubkey: coordinate.pubkey,
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(3)],
              ),
            ],
            isComplete: true,
            pages: 1,
          );
        }
        return PagedQueryResult(
          events: const [],
          isComplete: filter.kinds?.contains(EventKind.profileBadges) != true,
          pages: 1,
        );
      });

      await expectLater(
        repository.loadAcceptedHolders(coordinate),
        throwsStateError,
      );
    });

    test('accepted holders reject an incomplete revocation read', () async {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'daily-diviner',
      );
      when(() => nostrClient.readAllEvents(any())).thenAnswer((
        invocation,
      ) async {
        final filter = invocation.positionalArguments.single as Filter;
        final isDeletion =
            filter.kinds?.contains(EventKind.eventDeletion) == true;
        return PagedQueryResult(
          events: isDeletion
              ? []
              : [
                  _awardEvent(
                    id: _eventId(50),
                    issuerPubkey: coordinate.pubkey,
                    definitionCoordinate: coordinate.value,
                    recipients: [_pubkey(3)],
                  ),
                ],
          isComplete: !isDeletion,
          pages: 1,
        );
      });

      await expectLater(
        repository.loadAcceptedHolders(coordinate),
        throwsStateError,
      );
    });

    test('accepted holders exclude issuer-revoked awards', () async {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'daily-diviner',
      );
      final award = _awardEvent(
        id: _eventId(50),
        issuerPubkey: coordinate.pubkey,
        definitionCoordinate: coordinate.value,
        recipients: [_pubkey(3)],
      );
      when(() => nostrClient.readAllEvents(any())).thenAnswer((
        invocation,
      ) async {
        final filter = invocation.positionalArguments.single as Filter;
        return PagedQueryResult(
          events: filter.kinds?.contains(EventKind.eventDeletion) == true
              ? [
                  _event(
                    id: _eventId(51),
                    pubkey: coordinate.pubkey,
                    kind: EventKind.eventDeletion,
                    tags: [
                      ['e', award.id],
                    ],
                  ),
                ]
              : [award],
          isComplete: true,
          pages: 1,
        );
      });

      expect(await repository.loadAcceptedHolders(coordinate), isEmpty);
    });

    test(
      'accepted holders exclude a recipient who removed the badge',
      () async {
        final coordinate = BadgeCoordinate(
          pubkey: _pubkey(2),
          identifier: 'daily-diviner',
        );
        when(() => nostrClient.readAllEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filter = invocation.positionalArguments.single as Filter;
          return PagedQueryResult(
            events: filter.kinds?.contains(EventKind.badgeAward) == true
                ? [
                    _awardEvent(
                      id: _eventId(50),
                      issuerPubkey: coordinate.pubkey,
                      definitionCoordinate: coordinate.value,
                      recipients: [_pubkey(3)],
                    ),
                  ]
                : [],
            isComplete: true,
            pages: 1,
          );
        });
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(3)}': [
            _profileBadgesEvent(
              id: _eventId(51),
              pubkey: _pubkey(3),
              tags: [],
            ),
          ],
        });

        expect(await repository.loadAcceptedHolders(coordinate), isEmpty);
      },
    );

    test('loadAwardedBadges marks awards accepted by profile badges', () async {
      final award = _awardEvent(
        id: _eventId(1),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );
      final profileBadges = _profileBadgesEvent(
        id: _eventId(2),
        pubkey: _pubkey(1),
        tags: [
          ['a', '30009:${_pubkey(2)}:daily-diviner'],
          ['e', _eventId(1)],
        ],
      );
      final definition = _definitionEvent(
        pubkey: _pubkey(2),
        dTag: 'daily-diviner',
        name: 'Diviner of the Day',
      );
      _stubQueries(nostrClient, {
        'awarded': [award],
        'profileCurrent:${_pubkey(1)}': [profileBadges],
        'definition:30009:${_pubkey(2)}:daily-diviner': [definition],
      });

      final awards = await repository.loadAwardedBadges();

      expect(awards, hasLength(1));
      expect(awards.single.awardEventId, _eventId(1));
      expect(awards.single.isAccepted, isTrue);
      expect(awards.single.definition?.name, 'Diviner of the Day');
      expect(awards.single.isHidden, isFalse);
    });

    test(
      'loadAwardedBadges marks a newer re-award accepted by coordinate',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final olderAward = _awardEvent(
          id: _eventId(1),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final newerAward = _awardEvent(
          id: _eventId(2),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
          createdAt: 2000,
        );
        final profileBadges = _profileBadgesEvent(
          id: _eventId(3),
          pubkey: _pubkey(1),
          tags: [
            ['a', coordinate],
            ['e', _eventId(1)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [olderAward, newerAward],
          'profileCurrent:${_pubkey(1)}': [profileBadges],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards, hasLength(1));
        expect(awards.single.awardEventId, _eventId(2));
        expect(awards.single.isAccepted, isTrue);
      },
    );

    test(
      'loadAwardedBadges reads legacy profile badges compatibility',
      () async {
        final award = _awardEvent(
          id: _eventId(3),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: '30009:${_pubkey(2)}:legacy-diviner',
          recipients: [_pubkey(1)],
        );
        final legacyProfileBadges = _event(
          id: _eventId(4),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          tags: [
            ['d', 'profile_badges'],
            ['a', '30009:${_pubkey(2)}:legacy-diviner'],
            ['e', _eventId(3)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileLegacy:${_pubkey(1)}': [legacyProfileBadges],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isTrue);
      },
    );

    test(
      'loadAcceptedBadgesForProfile returns badge definitions for profile',
      () async {
        final award = _awardEvent(
          id: _eventId(15),
          issuerPubkey: _pubkey(3),
          definitionCoordinate: '30009:${_pubkey(3)}:daily-diviner',
          recipients: [_pubkey(2), _pubkey(4)],
        );
        final profileBadges = _profileBadgesEvent(
          id: _eventId(14),
          pubkey: _pubkey(2),
          tags: [
            ['a', '30009:${_pubkey(3)}:daily-diviner'],
            ['e', _eventId(15)],
          ],
        );
        final definition = _definitionEvent(
          pubkey: _pubkey(3),
          dTag: 'daily-diviner',
          name: 'Diviner of the Day',
          description: 'A daily badge for people who keep the network weird.',
          thumbnails: ['https://example.com/daily-diviner-thumb.png'],
        );
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(2)}': [profileBadges],
          'definition:30009:${_pubkey(3)}:daily-diviner': [definition],
          'ids:${_eventId(15)}': [award],
        });

        final badges = await repository.loadAcceptedBadgesForProfile(
          _pubkey(2),
        );

        expect(badges, hasLength(1));
        expect(
          badges.single.definitionCoordinate,
          '30009:${_pubkey(3)}:daily-diviner',
        );
        expect(badges.single.awardEventId, _eventId(15));
        expect(badges.single.displayName, 'Diviner of the Day');
        expect(
          badges.single.description,
          'A daily badge for people who keep the network weird.',
        );
        expect(
          badges.single.imageUrl,
          'https://example.com/daily-diviner-thumb.png',
        );
        expect(badges.single.award?.event.id, _eventId(15));
        expect(badges.single.issuerPubkey, _pubkey(3));
        expect(badges.single.recipientPubkeys, [_pubkey(2), _pubkey(4)]);
      },
    );

    test(
      'loadAcceptedBadgesForProfile keeps a badge when the award is unavailable',
      () async {
        final coordinate = '30009:${_pubkey(3)}:daily-diviner';
        final profileBadges = _profileBadgesEvent(
          id: _eventId(16),
          pubkey: _pubkey(2),
          tags: [
            ['a', coordinate],
            ['e', _eventId(17)],
          ],
        );
        final definition = _definitionEvent(
          pubkey: _pubkey(3),
          dTag: 'daily-diviner',
          name: 'Diviner of the Day',
        );
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(2)}': [profileBadges],
          'definition:$coordinate': [definition],
        });

        final badges = await repository.loadAcceptedBadgesForProfile(
          _pubkey(2),
        );

        expect(badges, hasLength(1));
        expect(badges.single.definitionCoordinate, coordinate);
        expect(badges.single.award, isNull);
      },
    );

    test('acceptAward publishes a kind 10008 profile badges event', () async {
      final award = _awardEvent(
        id: _eventId(5),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );
      final existingProfileBadges = _profileBadgesEvent(
        id: _eventId(6),
        pubkey: _pubkey(1),
        tags: [
          ['a', '30009:${_pubkey(3)}:weekly-diviner'],
          ['e', _eventId(7)],
        ],
      );
      _stubQueries(nostrClient, {
        'profileCurrent:${_pubkey(1)}': [existingProfileBadges],
      });

      await repository.acceptAward(
        BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
      );

      final event = lastSignedEvent();
      expect(event, isNotNull);
      expect(event!.kind, EventKind.profileBadges);
      expect(event.tags, [
        ['a', '30009:${_pubkey(3)}:weekly-diviner'],
        ['e', _eventId(7)],
        ['a', '30009:${_pubkey(2)}:daily-diviner'],
        ['e', _eventId(5)],
      ]);
      verify(() => nostrClient.publishEventAwaitOk(event)).called(1);
    });

    test('removeAward publishes kind 10008 without the removed pair', () async {
      final award = _awardEvent(
        id: _eventId(8),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );
      final existingProfileBadges = _profileBadgesEvent(
        id: _eventId(9),
        pubkey: _pubkey(1),
        tags: [
          ['a', '30009:${_pubkey(2)}:daily-diviner'],
          ['e', _eventId(8)],
          ['a', '30009:${_pubkey(3)}:weekly-diviner'],
          ['e', _eventId(10)],
        ],
      );
      _stubQueries(nostrClient, {
        'profileCurrent:${_pubkey(1)}': [existingProfileBadges],
      });

      await repository.removeAward(
        BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
      );

      final event = lastSignedEvent();
      expect(event, isNotNull);
      expect(event!.kind, EventKind.profileBadges);
      expect(event.tags, [
        ['a', '30009:${_pubkey(3)}:weekly-diviner'],
        ['e', _eventId(10)],
      ]);
      verify(() => nostrClient.publishEventAwaitOk(event)).called(1);
    });

    test(
      'removeAward removes the accepted badge coordinate when ids differ',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final newerAward = _awardEvent(
          id: _eventId(11),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final existingProfileBadges = _profileBadgesEvent(
          id: _eventId(12),
          pubkey: _pubkey(1),
          tags: [
            ['a', coordinate],
            ['e', _eventId(8)],
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(10)],
          ],
        );
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(1)}': [existingProfileBadges],
        });

        await repository.removeAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(newerAward)!),
        );

        expect(lastSignedEvent()!.tags, [
          ['a', '30009:${_pubkey(3)}:weekly-diviner'],
          ['e', _eventId(10)],
        ]);
      },
    );

    group('a badge pinned without a reachable award', () {
      final coordinate = '30009:${_pubkey(3)}:unwanted';

      void stubPinOnly() {
        _stubQueries(nostrClient, {
          'awarded': const [],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(50),
              pubkey: _pubkey(1),
              createdAt: 4000,
              tags: [
                ['a', coordinate],
                ['e', _eventId(51)],
              ],
            ),
          ],
        });
      }

      test('is still listed so it can be taken off the profile', () async {
        stubPinOnly();

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.definitionCoordinate, coordinate);
        expect(awards.single.awardEventId, _eventId(51));
        expect(awards.single.isAccepted, isTrue);
        expect(awards.single.hasAwardEvent, isFalse);
        expect(awards.single.awardedAt, 4000);
      });

      test('cannot be dismissed, only removed', () async {
        stubPinOnly();

        await repository.hideAward(coordinate);

        expect((await repository.loadAwardedBadges()).single.isHidden, isFalse);
      });

      test('removeAward unpins it', () async {
        stubPinOnly();
        final award = (await repository.loadAwardedBadges()).single;

        await repository.removeAward(award);

        expect(lastSignedEvent()!.tags, isEmpty);
      });

      test('is not listed twice when the pin names it twice', () async {
        _stubQueries(nostrClient, {
          'awarded': const [],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(52),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate],
                ['e', _eventId(51)],
                ['a', coordinate],
                ['e', _eventId(53)],
              ],
            ),
          ],
        });

        expect(await repository.loadAwardedBadges(), hasLength(1));
      });

      test('gives way to the award once it is reachable again', () async {
        _stubQueries(nostrClient, {
          'awarded': [
            _awardEvent(
              id: _eventId(51),
              issuerPubkey: _pubkey(3),
              definitionCoordinate: coordinate,
              recipients: [_pubkey(1)],
            ),
          ],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(50),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate],
                ['e', _eventId(51)],
              ],
            ),
          ],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards, hasLength(1));
        expect(awards.single.hasAwardEvent, isTrue);
      });

      test('lists multiple orphan pins in a stable coordinate order', () async {
        final issuer = _pubkey(3);
        final coordA = '30009:$issuer:aaa';
        final coordB = '30009:$issuer:bbb';
        _stubQueries(nostrClient, {
          'awarded': const [],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(54),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordB],
                ['e', _eventId(55)],
                ['a', coordA],
                ['e', _eventId(56)],
              ],
            ),
          ],
        });

        final awards = await repository.loadAwardedBadges();

        expect(
          awards.map((award) => award.definitionCoordinate),
          [coordA, coordB],
        );
      });
    });

    test('hideAward stores a local per-user dismissal', () async {
      final award = _awardEvent(
        id: _eventId(11),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );
      _stubQueries(nostrClient, {
        'awarded': [award],
      });

      await repository.hideAward('30009:${_pubkey(2)}:daily-diviner');

      // Still returned, flagged rather than dropped, so it can be restored.
      final awards = await repository.loadAwardedBadges();
      expect(awards.single.isHidden, isTrue);
      expect(
        preferences.getStringList(
          'dismissed_badge_coordinates_${_pubkey(1)}',
        ),
        ['30009:${_pubkey(2)}:daily-diviner'],
      );
    });

    test('hideAward survives the same badge being awarded again', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      final first = _awardEvent(
        id: _eventId(11),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      final reAward = _awardEvent(
        id: _eventId(12),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
        createdAt: 2000,
      );
      _stubQueries(nostrClient, {
        'awarded': [first],
      });
      await repository.hideAward(coordinate);

      _stubQueries(nostrClient, {
        'awarded': [first, reAward],
      });

      final awards = await repository.loadAwardedBadges();
      expect(awards.single.awardEventId, _eventId(12));
      expect(awards.single.isHidden, isTrue);
    });

    test('a dismissal stored per award event migrates to its badge', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      final dismissed = _awardEvent(
        id: _eventId(13),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      final reAward = _awardEvent(
        id: _eventId(14),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
        createdAt: 2000,
      );
      await preferences.setStringList('dismissed_badge_awards_${_pubkey(1)}', [
        _eventId(13),
      ]);
      _stubQueries(nostrClient, {
        'awarded': [dismissed, reAward],
      });

      final awards = await repository.loadAwardedBadges();

      expect(awards.single.isHidden, isTrue);
      expect(
        preferences.getStringList(
          'dismissed_badge_coordinates_${_pubkey(1)}',
        ),
        [coordinate],
      );
      expect(
        preferences.getStringList('dismissed_badge_awards_${_pubkey(1)}'),
        isNull,
      );
    });

    test('a dismissal never hides a badge pinned to the profile', () async {
      // Reachable from data an older build left behind: reject award A,
      // the issuer re-awards the badge as B, the old per-award dismissal
      // no longer matches so the row comes back, the user accepts it. The
      // migration then maps A onto the badge — and hiding it would strand
      // the badge on the profile, since the hidden section only restores.
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      await preferences.setStringList('dismissed_badge_awards_${_pubkey(1)}', [
        _eventId(60),
      ]);
      _stubQueries(nostrClient, {
        'awarded': [
          _awardEvent(
            id: _eventId(60),
            issuerPubkey: _pubkey(2),
            definitionCoordinate: coordinate,
            recipients: [_pubkey(1)],
          ),
          _awardEvent(
            id: _eventId(61),
            issuerPubkey: _pubkey(2),
            definitionCoordinate: coordinate,
            recipients: [_pubkey(1)],
            createdAt: 2000,
          ),
        ],
        'profileCurrent:${_pubkey(1)}': [
          _profileBadgesEvent(
            id: _eventId(62),
            pubkey: _pubkey(1),
            createdAt: 3000,
            tags: [
              ['a', coordinate],
              ['e', _eventId(61)],
            ],
          ),
        ],
      });

      final awards = await repository.loadAwardedBadges();

      expect(awards.single.isAccepted, isTrue);
      expect(awards.single.isHidden, isFalse);
    });

    test(
      'the dismissal takes effect again once the badge is unpinned',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(63),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(64),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate],
                ['e', _eventId(63)],
              ],
            ),
          ],
        });
        await repository.hideAward(coordinate);
        expect((await repository.loadAwardedBadges()).single.isHidden, isFalse);

        _stubQueries(nostrClient, {
          'awarded': [award],
        });

        expect((await repository.loadAwardedBadges()).single.isHidden, isTrue);
      },
    );

    test('a dismissal whose award is unavailable is kept for later', () async {
      await preferences.setStringList('dismissed_badge_awards_${_pubkey(1)}', [
        _eventId(15),
      ]);

      await repository.loadAwardedBadges();

      expect(
        preferences.getStringList('dismissed_badge_awards_${_pubkey(1)}'),
        [_eventId(15)],
      );
    });

    test('migrating one dismissal leaves the unresolved one behind', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      await preferences.setStringList('dismissed_badge_awards_${_pubkey(1)}', [
        _eventId(18),
        _eventId(19),
      ]);
      _stubQueries(nostrClient, {
        'awarded': [
          _awardEvent(
            id: _eventId(18),
            issuerPubkey: _pubkey(2),
            definitionCoordinate: coordinate,
            recipients: [_pubkey(1)],
          ),
        ],
      });

      await repository.loadAwardedBadges();

      expect(
        preferences.getStringList(
          'dismissed_badge_coordinates_${_pubkey(1)}',
        ),
        [coordinate],
      );
      expect(
        preferences.getStringList('dismissed_badge_awards_${_pubkey(1)}'),
        [_eventId(19)],
      );
    });

    group('a hidden issuer', () {
      late BadgeRepository blocked;

      setUp(() {
        blocked = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => _pubkey(1),
          signEvent: ({required kind, required content, required tags}) async =>
              null,
          isHiddenPubkey: (pubkey) => pubkey == _pubkey(3),
        );
      });

      test('has its unaccepted awards dropped', () async {
        _stubQueries(nostrClient, {
          'awarded': [
            _awardEvent(
              id: _eventId(16),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
              recipients: [_pubkey(1)],
            ),
            _awardEvent(
              id: _eventId(17),
              issuerPubkey: _pubkey(3),
              definitionCoordinate: '30009:${_pubkey(3)}:unwanted',
              recipients: [_pubkey(1)],
            ),
          ],
        });

        final awards = await blocked.loadAwardedBadges();

        expect(awards.single.awardEventId, _eventId(16));
      });

      test('keeps an award the user already accepted', () async {
        final coordinate = '30009:${_pubkey(3)}:unwanted';
        _stubQueries(nostrClient, {
          'awarded': [
            _awardEvent(
              id: _eventId(17),
              issuerPubkey: _pubkey(3),
              definitionCoordinate: coordinate,
              recipients: [_pubkey(1)],
            ),
          ],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(18),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate],
                ['e', _eventId(17)],
              ],
            ),
          ],
        });

        final awards = await blocked.loadAwardedBadges();

        // Pinned to the profile, so it has to stay reachable to be removed.
        expect(awards.single.isAccepted, isTrue);
      });
    });

    test('loadAwardedBadges loads each unique definition once', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      final awardA = _awardEvent(
        id: _eventId(20),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      final awardB = _awardEvent(
        id: _eventId(21),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      final definition = _definitionEvent(
        pubkey: _pubkey(2),
        dTag: 'daily-diviner',
        name: 'Diviner of the Day',
      );
      final callCounts = _stubQueries(nostrClient, {
        'awarded': [awardA, awardB],
        'definition:$coordinate': [definition],
      });

      final awards = await repository.loadAwardedBadges();

      // Both awards name the same badge, so they collapse to one card; the
      // definition is still only fetched once for the pair.
      expect(awards, hasLength(1));
      expect(
        awards.map((award) => award.definition?.name),
        everyElement('Diviner of the Day'),
      );
      expect(callCounts['definition:$coordinate'], 1);
    });

    test('loadAwardedBadges keeps only the newest award per badge', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      final older = _awardEvent(
        id: _eventId(20),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      final newer = _awardEvent(
        id: _eventId(21),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
        createdAt: 2000,
      );
      _stubQueries(nostrClient, {
        'awarded': [older, newer],
      });

      final awards = await repository.loadAwardedBadges();

      // Listing both would leave a row that can never resolve: the profile
      // badge list references exactly one award per badge.
      expect(awards, hasLength(1));
      expect(awards.single.awardEventId, _eventId(21));
    });

    test(
      'loadIssuedBadges checks each unique recipient once across awards',
      () async {
        final coordinate = '30009:${_pubkey(1)}:creator-badge';
        final awardA = _awardEvent(
          id: _eventId(32),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(2)],
        );
        final awardB = _awardEvent(
          id: _eventId(33),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(2)],
        );
        final callCounts = _stubQueries(nostrClient, {
          'issued': [awardA, awardB],
        });

        final issued = await repository.loadIssuedBadges();

        // One badge, one recipient — the second award supersedes the first
        // instead of adding a row that can never resolve.
        expect(issued, hasLength(1));
        expect(issued.single.recipients, hasLength(1));
        expect(callCounts['profileCurrent:${_pubkey(2)}'], 1);
        expect(callCounts['profileLegacy:${_pubkey(2)}'], 1);
        expect(callCounts['definition:$coordinate'], 1);
      },
    );

    test(
      'loadDashboard shares the own profile badges lookup between halves',
      () async {
        final awardedAward = _awardEvent(
          id: _eventId(22),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
          recipients: [_pubkey(1)],
        );
        final selfIssuedAward = _awardEvent(
          id: _eventId(23),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: '30009:${_pubkey(1)}:creator-badge',
          recipients: [_pubkey(1)],
        );
        final callCounts = _stubQueries(nostrClient, {
          'awarded': [awardedAward],
          'issued': [selfIssuedAward],
        });

        final dashboard = await repository.loadDashboard();

        expect(dashboard.awarded, hasLength(1));
        expect(dashboard.issued, hasLength(1));
        expect(callCounts['profileCurrent:${_pubkey(1)}'], 1);
        expect(callCounts['profileLegacy:${_pubkey(1)}'], 1);
      },
    );

    test('loadAwardedBadges rethrows when a definition query fails', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      final award = _awardEvent(
        id: _eventId(24),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      _stubQueries(
        nostrClient,
        {
          'awarded': [award],
        },
        errorsByQueryKey: {
          'definition:$coordinate': Exception('relay unavailable'),
        },
      );

      await expectLater(repository.loadAwardedBadges(), throwsException);
    });

    test(
      'loadIssuedBadges preserves recipient order under concurrency',
      () async {
        final coordinate = '30009:${_pubkey(1)}:creator-badge';
        final award = _awardEvent(
          id: _eventId(25),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(2), _pubkey(3)],
        );
        final acceptance = _profileBadgesEvent(
          id: _eventId(26),
          pubkey: _pubkey(3),
          tags: [
            ['a', coordinate],
            ['e', _eventId(25)],
          ],
        );
        _stubQueries(
          nostrClient,
          {
            'issued': [award],
            'profileCurrent:${_pubkey(3)}': [acceptance],
          },
          delaysByQueryKey: {
            'profileCurrent:${_pubkey(2)}': const Duration(milliseconds: 40),
            'profileCurrent:${_pubkey(3)}': const Duration(milliseconds: 1),
          },
        );

        final issued = await repository.loadIssuedBadges();

        final recipients = issued.single.recipients;
        expect(
          [for (final recipient in recipients) recipient.pubkey],
          [_pubkey(2), _pubkey(3)],
        );
        expect(recipients[0].isAccepted, isFalse);
        expect(recipients[1].isAccepted, isTrue);
      },
    );

    test(
      'loadAwardedBadges uses newer legacy profile badges over older current',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(27),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final olderCurrentProfileBadges = _profileBadgesEvent(
          id: _eventId(28),
          pubkey: _pubkey(1),
          tags: [
            ['a', coordinate],
            ['e', _eventId(27)],
          ],
        );
        final newerLegacyWithoutAward = _event(
          id: _eventId(29),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          createdAt: 2000,
          tags: [
            ['d', 'profile_badges'],
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(30)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [olderCurrentProfileBadges],
          'profileLegacy:${_pubkey(1)}': [newerLegacyWithoutAward],
        });

        final awards = await repository.loadAwardedBadges();

        // The list is length 2: the winning list pins a different badge,
        // so this one is unaccepted, and that other pin has no award event
        // and is listed on its own.
        expect(awards, hasLength(2));
        expect(_byCoordinate(awards, coordinate).isAccepted, isFalse);
      },
    );

    test(
      'loadAwardedBadges uses newer current profile badges over older legacy',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(34),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final newerCurrentProfileBadges = _profileBadgesEvent(
          id: _eventId(35),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: [
            ['a', coordinate],
            ['e', _eventId(34)],
          ],
        );
        final olderLegacyWithoutAward = _event(
          id: _eventId(36),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          createdAt: 2000,
          tags: [
            ['d', 'profile_badges'],
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(37)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [newerCurrentProfileBadges],
          'profileLegacy:${_pubkey(1)}': [olderLegacyWithoutAward],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isTrue);
      },
    );

    test(
      'loadAwardedBadges treats newer empty profile badges as authoritative',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(38),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final newerEmptyProfileBadges = _profileBadgesEvent(
          id: _eventId(39),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: const [],
        );
        final olderLegacyWithAward = _event(
          id: _eventId(40),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          createdAt: 2000,
          tags: [
            ['d', 'profile_badges'],
            ['a', coordinate],
            ['e', _eventId(38)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [newerEmptyProfileBadges],
          'profileLegacy:${_pubkey(1)}': [olderLegacyWithAward],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isFalse);
      },
    );

    test(
      'loadAwardedBadges prefers current profile badges when timestamps tie',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(41),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final currentProfileBadges = _profileBadgesEvent(
          id: _eventId(43),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: [
            ['a', coordinate],
            ['e', _eventId(41)],
          ],
        );
        final legacyWithoutAward = _event(
          id: _eventId(42),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          createdAt: 3000,
          tags: [
            ['d', 'profile_badges'],
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(44)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [currentProfileBadges],
          'profileLegacy:${_pubkey(1)}': [legacyWithoutAward],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isTrue);
      },
    );

    test(
      'loadAwardedBadges uses lowest event id when same-kind timestamps tie',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(46),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final higherIdWithAward = _profileBadgesEvent(
          id: _eventId(48),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: [
            ['a', coordinate],
            ['e', _eventId(46)],
          ],
        );
        final lowerIdWithoutAward = _profileBadgesEvent(
          id: _eventId(47),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: [
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(49)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [
            higherIdWithAward,
            lowerIdWithoutAward,
          ],
        });

        final awards = await repository.loadAwardedBadges();

        // The list is length 2: the winning list pins a different badge,
        // so this one is unaccepted, and that other pin has no award event
        // and is listed on its own.
        expect(awards, hasLength(2));
        expect(_byCoordinate(awards, coordinate).isAccepted, isFalse);
      },
    );

    test(
      'loadIssuedBadges caps recipient checks at recipientCheckLimit',
      () async {
        final award = _awardEvent(
          id: _eventId(31),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: '30009:${_pubkey(1)}:creator-badge',
          recipients: [_pubkey(2), _pubkey(3), _pubkey(4)],
        );
        final callCounts = _stubQueries(nostrClient, {
          'issued': [award],
        });

        final issued = await repository.loadIssuedBadges(
          recipientCheckLimit: 2,
        );

        // Everyone awarded is listed; the limit bounds the acceptance
        // lookups, so the recipient past it carries no status rather than
        // being dropped from the list.
        expect(
          [for (final recipient in issued.single.recipients) recipient.pubkey],
          [_pubkey(2), _pubkey(3), _pubkey(4)],
        );
        expect(
          [
            for (final recipient in issued.single.recipients)
              recipient.isAccepted,
          ],
          [false, false, null],
        );
        expect(callCounts['profileCurrent:${_pubkey(4)}'], isNull);
      },
    );

    test(
      'loadIssuedBadges marks recipients accepted when they publish award',
      () async {
        final issuedAward = _awardEvent(
          id: _eventId(12),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: '30009:${_pubkey(1)}:creator-badge',
          recipients: [_pubkey(2)],
        );
        final recipientProfileBadges = _profileBadgesEvent(
          id: _eventId(13),
          pubkey: _pubkey(2),
          tags: [
            ['a', '30009:${_pubkey(1)}:creator-badge'],
            ['e', _eventId(12)],
          ],
        );
        _stubQueries(nostrClient, {
          'issued': [issuedAward],
          'profileCurrent:${_pubkey(2)}': [recipientProfileBadges],
        });

        final issued = await repository.loadIssuedBadges();

        expect(issued, hasLength(1));
        expect(issued.single.coordinate, '30009:${_pubkey(1)}:creator-badge');
        expect(issued.single.recipients.single.pubkey, _pubkey(2));
        expect(issued.single.recipients.single.isAccepted, isTrue);
      },
    );

    test(
      'acceptAward keeps an already-accepted award and preserves relay hints',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(42),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final existingProfileBadges = _profileBadgesEvent(
          id: _eventId(43),
          pubkey: _pubkey(1),
          tags: [
            ['a', coordinate],
            ['e', _eventId(42), 'wss://relay.divine.video'],
          ],
        );
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(1)}': [existingProfileBadges],
        });

        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        final event = lastSignedEvent();
        expect(event, isNotNull);
        expect(event!.tags, [
          ['a', coordinate],
          ['e', _eventId(42), 'wss://relay.divine.video'],
        ]);
      },
    );

    test('acceptAward replaces an earlier award for the same badge', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      final newer = _awardEvent(
        id: _eventId(45),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
        createdAt: 2000,
      );
      _stubQueries(nostrClient, {
        'profileCurrent:${_pubkey(1)}': [
          _profileBadgesEvent(
            id: _eventId(46),
            pubkey: _pubkey(1),
            tags: [
              ['a', coordinate],
              ['e', _eventId(44)],
            ],
          ),
        ],
      });

      await repository.acceptAward(
        BadgeAwardViewData(award: Nip58BadgeParser.parseAward(newer)!),
      );

      // One a/e pair per badge: a second pair for the same coordinate
      // renders the badge twice on the profile.
      expect(lastSignedEvent()!.tags, [
        ['a', coordinate],
        ['e', _eventId(45)],
      ]);
    });

    test(
      'loadAwardedBadges drops awards not signed by the badge issuer',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        _stubQueries(nostrClient, {
          'awarded': [
            _awardEvent(
              id: _eventId(47),
              // Anyone can publish a kind 8 pointing at someone else's
              // coordinate; the p filter alone would let it through.
              issuerPubkey: _pubkey(3),
              definitionCoordinate: coordinate,
              recipients: [_pubkey(1)],
            ),
          ],
        });

        expect(await repository.loadAwardedBadges(), isEmpty);
      },
    );

    test('acceptAward throws a StateError when signing fails', () async {
      final failingRepository = BadgeRepository(
        nostrClient: nostrClient,
        sharedPreferences: preferences,
        currentPubkey: () => _pubkey(1),
        signEvent: ({required kind, required content, required tags}) async =>
            null,
      );
      final award = _awardEvent(
        id: _eventId(44),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );

      await expectLater(
        failingRepository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'acceptAward throws a BadgePublishException when no relay accepts',
      () async {
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.single as Event;
          return _rejectedPublishOutcome(event);
        });
        final award = _awardEvent(
          id: _eventId(45),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
          recipients: [_pubkey(1)],
        );

        await expectLater(
          repository.acceptAward(
            BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
          ),
          throwsA(
            isA<BadgePublishException>()
                .having(
                  (error) => error.outcome.acceptedBy,
                  'acceptedBy',
                  isEmpty,
                )
                .having(
                  (error) => error.toString(),
                  'toString',
                  contains('Could not publish profile badges event'),
                ),
          ),
        );
        verifyNever(() => nostrClient.publishEvent(any()));
      },
    );

    test('acceptAward throws a StateError without a current pubkey', () async {
      // A WORKING signer is injected so the only possible StateError source is
      // the missing-pubkey guard. If that guard were removed the signer would
      // succeed and this test would fail — so it can fail for the right reason
      // rather than being satisfied by an unrelated null-signer StateError.
      final anonymousRepository = BadgeRepository(
        nostrClient: nostrClient,
        sharedPreferences: preferences,
        currentPubkey: () => null,
        signEvent: ({required kind, required content, required tags}) async =>
            _event(
              id: _eventId(946),
              pubkey: _pubkey(1),
              kind: kind,
              tags: tags,
              content: content,
            ),
      );
      final award = _awardEvent(
        id: _eventId(46),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );

      await expectLater(
        anonymousRepository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Cannot load badges without a current pubkey',
          ),
        ),
      );
    });

    test(
      'acceptAward bases new profile badges on the newest of multiple events',
      () async {
        final award = _awardEvent(
          id: _eventId(47),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
          recipients: [_pubkey(1)],
        );
        final olderProfileBadges = _event(
          id: _eventId(48),
          pubkey: _pubkey(1),
          kind: EventKind.profileBadges,
          createdAt: 500,
          tags: [
            ['a', '30009:${_pubkey(3)}:older-badge'],
            ['e', _eventId(49)],
          ],
        );
        final newerProfileBadges = _event(
          id: _eventId(50),
          pubkey: _pubkey(1),
          kind: EventKind.profileBadges,
          createdAt: 2000,
          tags: [
            ['a', '30009:${_pubkey(3)}:newer-badge'],
            ['e', _eventId(51)],
          ],
        );
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(1)}': [
            olderProfileBadges,
            newerProfileBadges,
          ],
        });

        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        final event = lastSignedEvent();
        expect(event, isNotNull);
        expect(event!.tags, [
          ['a', '30009:${_pubkey(3)}:newer-badge'],
          ['e', _eventId(51)],
          ['a', '30009:${_pubkey(2)}:daily-diviner'],
          ['e', _eventId(47)],
        ]);
      },
    );

    group('loadCreatedBadges', () {
      test(
        'keeps the newest definition per identifier, newest first',
        () async {
          _stubQueries(nostrClient, {
            'created:${_pubkey(1)}': [
              _definitionEvent(
                id: _eventId(60),
                pubkey: _pubkey(1),
                dTag: 'scene-stealer',
                name: 'Scene Stealer',
              ),
              _definitionEvent(
                id: _eventId(61),
                pubkey: _pubkey(1),
                dTag: 'scene-stealer',
                name: 'Scene Stealer v2',
                createdAt: 3000,
              ),
              _definitionEvent(
                id: _eventId(62),
                pubkey: _pubkey(1),
                dTag: 'loop-of-the-week',
                name: 'Loop of the Week',
                createdAt: 2000,
              ),
              // Missing the `d` tag, so it is not a definition at all.
              _event(
                id: _eventId(63),
                pubkey: _pubkey(1),
                kind: EventKind.badgeDefinition,
                tags: const [
                  ['name', 'Nameless'],
                ],
              ),
            ],
          });

          final created = await repository.loadCreatedBadges();

          expect(created.map((badge) => badge.displayName), [
            'Scene Stealer v2',
            'Loop of the Week',
          ]);
          expect(created.first.coordinate, '30009:${_pubkey(1)}:scene-stealer');
        },
      );

      // A definition with no `name` tag falls back to the identifier, which
      // is raw event text. The headless flutter_tester does not throw on a
      // lone surrogate — only the real engine does — so this asserts the
      // value rather than a rendered badge row.
      test(
        'replaces a lone surrogate in the identifier fallback name',
        () async {
          final dTag = 'scene${String.fromCharCode(0xD83D)}stealer';
          _stubQueries(nostrClient, {
            'created:${_pubkey(1)}': [
              // No `name` tag, so displayName falls back to the identifier.
              _event(
                id: _eventId(90),
                pubkey: _pubkey(1),
                kind: EventKind.badgeDefinition,
                tags: [
                  ['d', dTag],
                ],
              ),
            ],
          });

          final created = await repository.loadCreatedBadges();

          expect(created.single.displayName, 'scene\u{FFFD}stealer');
          // The address keeps the raw identifier: sanitizing it would point
          // at a badge that does not exist.
          expect(created.single.coordinate, '30009:${_pubkey(1)}:$dTag');
        },
      );

      test('counts awards and distinct recipients per definition', () async {
        const coordinate = 'scene-stealer';
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(64),
              pubkey: _pubkey(1),
              dTag: coordinate,
              name: 'Scene Stealer',
            ),
          ],
          'issued': [
            _awardEvent(
              id: _eventId(65),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: '30009:${_pubkey(1)}:$coordinate',
              recipients: [_pubkey(2), _pubkey(3)],
            ),
            _awardEvent(
              id: _eventId(66),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: '30009:${_pubkey(1)}:$coordinate',
              recipients: [_pubkey(3)],
            ),
            // Award for a badge the user never defined.
            _awardEvent(
              id: _eventId(67),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: '30009:${_pubkey(1)}:other',
              recipients: [_pubkey(4)],
            ),
          ],
        });

        final created = await repository.loadCreatedBadges();

        expect(created.single.awardCount, 2);
        expect(created.single.recipientCount, 2);
      });

      test('reports no awards for a definition nobody received', () async {
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(68),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: 'https://media.divine.video/scene.png',
            ),
          ],
        });

        final created = await repository.loadCreatedBadges();

        expect(created.single.awardCount, 0);
        expect(created.single.recipientCount, 0);
        expect(created.single.imageUrl, 'https://media.divine.video/scene.png');
      });

      test('falls back to the thumbnail when there is no image', () async {
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(69),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
              thumbnails: const ['https://media.divine.video/thumb.png'],
            ),
          ],
        });

        final created = await repository.loadCreatedBadges();

        expect(created.single.imageUrl, 'https://media.divine.video/thumb.png');
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.loadCreatedBadges(),
          throwsA(isA<StateError>()),
        );
      });
    });

    test('loadIssuedBadges lists newest badge first and names it', () async {
      _stubQueries(nostrClient, {
        'issued': [
          _awardEvent(
            id: _eventId(80),
            issuerPubkey: _pubkey(1),
            definitionCoordinate: '30009:${_pubkey(1)}:older-badge',
            recipients: [_pubkey(2)],
          ),
          _awardEvent(
            id: _eventId(81),
            issuerPubkey: _pubkey(1),
            definitionCoordinate: '30009:${_pubkey(1)}:newer-badge',
            recipients: [_pubkey(3)],
            createdAt: 5000,
          ),
        ],
        'definition:30009:${_pubkey(1)}:newer-badge': [
          _definitionEvent(
            id: _eventId(82),
            pubkey: _pubkey(1),
            dTag: 'newer-badge',
            name: 'Newer Badge',
          ),
        ],
      });

      final issued = await repository.loadIssuedBadges();

      expect(issued.map((badge) => badge.displayName), [
        'Newer Badge',
        // No definition on the relay, so the identifier stands in.
        'older-badge',
      ]);
    });

    group('accepting reflects before the relay serves the write back', () {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      late Event award;

      setUp(() {
        award = _awardEvent(
          id: _eventId(70),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
      });

      test('a reload right after accepting shows the badge accepted', () async {
        // The relay OKs the kind:10008 but keeps serving the previous list,
        // which is the window the dashboard used to render as "not accepted"
        // until the user pulled to refresh.
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(71),
              pubkey: _pubkey(1),
              tags: const [],
              createdAt: 500,
            ),
          ],
        });

        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        expect(
          (await repository.loadAwardedBadges()).single.isAccepted,
          isTrue,
        );
      });

      test('a genuinely newer list from another device still wins', () async {
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(72),
              pubkey: _pubkey(1),
              tags: const [],
              // The signer stamps the published event with createdAt 1000.
              createdAt: 4000,
            ),
          ],
        });

        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        expect(
          (await repository.loadAwardedBadges()).single.isAccepted,
          isFalse,
        );
      });

      test('another account does not inherit the published list', () async {
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': const [],
        });
        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        final badges = await repository.loadAcceptedBadgesForProfile(
          _pubkey(2),
        );

        expect(badges, isEmpty);
      });
    });

    group('editing reflects before the relay serves the write back', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(1),
        identifier: 'scene-stealer',
      );

      /// The relay keeps answering with the pre-edit definition, which is the
      /// window the badge used to keep its old name in.
      void stubStaleDefinition() {
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(60),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Old Name',
              createdAt: 500,
            ),
          ],
          'definition:${coordinate.value}': [
            _definitionEvent(
              id: _eventId(61),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Old Name',
              createdAt: 500,
            ),
          ],
        });
      }

      Future<void> publishEdit() => repository.saveDefinition(
        const BadgeDefinitionDraft(
          identifier: 'scene-stealer',
          name: 'New Name',
          imageUrl: _artworkUrl,
        ),
      );

      test('the detail page shows the edited name right away', () async {
        stubStaleDefinition();
        await publishEdit();

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.definition?.name, 'New Name');
      });

      test('the created list shows the edited name right away', () async {
        stubStaleDefinition();
        await publishEdit();

        final created = await repository.loadCreatedBadges();

        expect(created.single.displayName, 'New Name');
      });

      test('a brand-new badge appears before the relay serves it', () async {
        await publishEdit();

        expect(await repository.loadCreatedIdentifiers(), {'scene-stealer'});
      });

      test('an edit made on another device still wins', () async {
        await publishEdit();
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              id: _eventId(62),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Newer Elsewhere',
              // The signer stamps the published event with createdAt 1000.
              createdAt: 4000,
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.definition?.name, 'Newer Elsewhere');
      });

      test('a deleted badge is not served back out of memory', () async {
        await publishEdit();

        await repository.deleteBadge(coordinate);

        expect(await repository.loadCreatedIdentifiers(), isEmpty);
      });

      test('a refused deletion leaves the badge in place', () async {
        await publishEdit();
        // The relay refuses a deletion for a badge it has only just accepted,
        // which is exactly when it is not serving the definition back yet.
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          return _rejectedPublishOutcome(
            invocation.positionalArguments.single as Event,
          );
        });

        await expectLater(
          repository.deleteBadge(coordinate),
          throwsA(isA<BadgePublishException>()),
        );

        expect(await repository.loadCreatedIdentifiers(), {'scene-stealer'});
      });
    });

    group('unhideAward', () {
      test('puts a dismissed award back on the awarded list', () async {
        _stubQueries(nostrClient, {
          'awarded': [
            _awardEvent(
              id: _eventId(84),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
              recipients: [_pubkey(1)],
            ),
          ],
        });
        await repository.hideAward('30009:${_pubkey(2)}:daily-diviner');

        await repository.unhideAward('30009:${_pubkey(2)}:daily-diviner');

        expect((await repository.loadAwardedBadges()).single.isHidden, isFalse);
        expect(
          preferences.getStringList(
            'dismissed_badge_coordinates_${_pubkey(1)}',
          ),
          isEmpty,
        );
      });

      test('does nothing for a badge that was never dismissed', () async {
        await repository.unhideAward('30009:${_pubkey(2)}:weekly-diviner');

        expect(
          preferences.getStringList(
            'dismissed_badge_coordinates_${_pubkey(1)}',
          ),
          isNull,
        );
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.unhideAward('30009:${_pubkey(2)}:daily-diviner'),
          throwsA(isA<StateError>()),
        );
      });
    });

    test('loadDashboard keeps dismissed awards out of awarded', () async {
      _stubQueries(nostrClient, {
        'awarded': [
          _awardEvent(
            id: _eventId(87),
            issuerPubkey: _pubkey(2),
            definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
            recipients: [_pubkey(1)],
          ),
          _awardEvent(
            id: _eventId(88),
            issuerPubkey: _pubkey(2),
            definitionCoordinate: '30009:${_pubkey(2)}:weekly-diviner',
            recipients: [_pubkey(1)],
          ),
        ],
      });
      await repository.hideAward('30009:${_pubkey(2)}:weekly-diviner');

      final dashboard = await repository.loadDashboard();

      expect(dashboard.awarded.single.awardEventId, _eventId(87));
      expect(dashboard.hidden.single.awardEventId, _eventId(88));
    });

    group('loadCreatedIdentifiers', () {
      test('collapses replaced definitions to one identifier', () async {
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(94),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
            _definitionEvent(
              id: _eventId(95),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer v2',
              createdAt: 3000,
            ),
            _definitionEvent(
              id: _eventId(96),
              pubkey: _pubkey(1),
              dTag: 'loop-of-the-week',
              name: 'Loop of the Week',
            ),
          ],
        });

        expect(await repository.loadCreatedIdentifiers(), {
          'scene-stealer',
          'loop-of-the-week',
        });
      });

      test('is empty when the user has published no badges', () async {
        expect(await repository.loadCreatedIdentifiers(), isEmpty);
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.loadCreatedIdentifiers(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('loadBadgeDetail', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'scene-stealer',
      );

      test('resolves definition, awardees, and viewer acceptance', () async {
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              pubkey: _pubkey(2),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
          ],
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(70),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(1), _pubkey(3)],
            ),
          ],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(71),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate.value],
                ['e', _eventId(70)],
              ],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.definition?.name, 'Scene Stealer');
        expect(detail.isOwner, isFalse);
        expect(detail.recipients.map((r) => r.pubkey), [
          _pubkey(1),
          _pubkey(3),
        ]);
        expect(detail.recipients.first.isAccepted, isTrue);
        expect(detail.recipients.first.awardEventId, _eventId(70));
        expect(detail.recipients.last.isAccepted, isFalse);
        expect(detail.viewerAward?.awardEventId, _eventId(70));
        expect(detail.viewerAward?.isAccepted, isTrue);
      });

      test('marks the viewer among the recipients', () async {
        // The confirmation copy differs for your own award, and the UI should
        // not have to look up the signed-in pubkey to find that out.
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(79),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(1), _pubkey(3)],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(
          {
            for (final recipient in detail.recipients)
              recipient.pubkey: recipient.isViewer,
          },
          {_pubkey(1): true, _pubkey(3): false},
        );
      });

      test('marks a newer viewer re-award accepted by coordinate', () async {
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              pubkey: _pubkey(2),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
          ],
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(70),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(1)],
            ),
            _awardEvent(
              id: _eventId(71),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(1)],
              createdAt: 2000,
            ),
          ],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(72),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate.value],
                ['e', _eventId(70)],
              ],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.viewerAward?.awardEventId, _eventId(71));
        expect(detail.viewerAward?.isAccepted, isTrue);
      });

      test('marks the viewer as owner for their own badge', () async {
        final ownCoordinate = BadgeCoordinate(
          pubkey: _pubkey(1),
          identifier: 'scene-stealer',
        );
        _stubQueries(nostrClient, {
          'awardsFor:${ownCoordinate.value}': [
            _awardEvent(
              id: _eventId(72),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: ownCoordinate.value,
              recipients: [_pubkey(3)],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(ownCoordinate);

        expect(detail.isOwner, isTrue);
        expect(detail.definition, isNull);
        expect(detail.viewerAward, isNull);
      });

      test(
        'keeps the newest award when a recipient was awarded twice',
        () async {
          _stubQueries(nostrClient, {
            'awardsFor:${coordinate.value}': [
              _awardEvent(
                id: _eventId(73),
                issuerPubkey: _pubkey(2),
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(3)],
              ),
              _awardEvent(
                id: _eventId(74),
                issuerPubkey: _pubkey(2),
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(3)],
                createdAt: 5000,
              ),
            ],
          });

          final detail = await repository.loadBadgeDetail(coordinate);

          expect(detail.recipients.single.awardEventId, _eventId(74));
        },
      );

      test('drops awards whose coordinate does not match', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(75),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: '30009:${_pubkey(2)}:other-badge',
              recipients: [_pubkey(3)],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.recipients, isEmpty);
      });

      test('caps acceptance checks but always includes the viewer', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(76),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(3), _pubkey(4), _pubkey(1)],
            ),
          ],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(77),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate.value],
                ['e', _eventId(76)],
              ],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(
          coordinate,
          recipientCheckLimit: 1,
        );

        // Everyone is listed. Acceptance is resolved for the first one and
        // for the viewer; the one in between is left unknown rather than
        // reported as waiting.
        expect(detail.recipients.map((r) => r.pubkey), [
          _pubkey(3),
          _pubkey(4),
          _pubkey(1),
        ]);
        expect(detail.recipients.map((r) => r.isAccepted), [false, null, true]);
        expect(detail.viewerAward?.isAccepted, isTrue);
      });

      test('reports no viewer award when signed out', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(78),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(3)],
            ),
          ],
        });

        final detail = await anonymous.loadBadgeDetail(coordinate);

        expect(detail.isOwner, isFalse);
        expect(detail.viewerAward, isNull);
        expect(detail.recipients, hasLength(1));
      });
    });

    group('loadClaimantPubkeys', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'scene-stealer',
      );

      test(
        'queries profile badge claims by coordinate across both kinds',
        () async {
          final callCounts = _stubQueries(nostrClient, {
            'profileClaims:${coordinate.value}': [
              _profileBadgesEvent(
                id: _eventId(80),
                pubkey: _pubkey(3),
                tags: [
                  ['a', coordinate.value],
                  ['e', _eventId(70)],
                ],
              ),
              _profileBadgesEvent(
                id: _eventId(81),
                pubkey: _pubkey(4),
                kind: EventKind.badgeSet,
                tags: [
                  ['d', 'profile_badges'],
                  ['a', coordinate.value],
                  ['e', _eventId(71)],
                ],
              ),
            ],
            'profileCurrentBatch:${_pubkey(3)},${_pubkey(4)}': [
              _profileBadgesEvent(
                id: _eventId(82),
                pubkey: _pubkey(3),
                tags: [
                  ['a', coordinate.value],
                  ['e', _eventId(70)],
                ],
              ),
              _profileBadgesEvent(
                id: _eventId(83),
                pubkey: _pubkey(4),
                kind: EventKind.badgeSet,
                tags: [
                  ['d', 'profile_badges'],
                  ['a', coordinate.value],
                  ['e', _eventId(71)],
                ],
              ),
            ],
          });

          final claimants = await repository.loadClaimantPubkeys(coordinate);

          expect(claimants, {_pubkey(3), _pubkey(4)});
          final capturedFilters = verify(
            () => nostrClient.queryEvents(captureAny()),
          ).captured;
          final claimFilter = (capturedFilters.first as List<Filter>).single;
          expect(
            claimFilter.kinds,
            containsAll([EventKind.profileBadges, EventKind.badgeSet]),
          );
          expect(claimFilter.a, [coordinate.value]);
          expect(
            callCounts['profileCurrentBatch:${_pubkey(3)},${_pubkey(4)}'],
            1,
          );
          expect(callCounts['profileCurrent:${_pubkey(3)}'], isNull);
        },
      );

      test(
        'drops candidates whose newest profile badges removed the badge',
        () async {
          final otherCoordinate = BadgeCoordinate(
            pubkey: _pubkey(2),
            identifier: 'other-badge',
          );
          _stubQueries(nostrClient, {
            'profileClaims:${coordinate.value}': [
              _profileBadgesEvent(
                id: _eventId(84),
                pubkey: _pubkey(3),
                tags: [
                  ['a', coordinate.value],
                  ['e', _eventId(70)],
                ],
              ),
            ],
            'profileCurrent:${_pubkey(3)}': [
              _profileBadgesEvent(
                id: _eventId(85),
                pubkey: _pubkey(3),
                createdAt: 2000,
                tags: [
                  ['a', otherCoordinate.value],
                  ['e', _eventId(72)],
                ],
              ),
            ],
          });

          final claimants = await repository.loadClaimantPubkeys(coordinate);

          expect(claimants, isEmpty);
        },
      );

      test(
        'excludes the current viewer before loading latest claim state',
        () async {
          _stubQueries(nostrClient, {
            'profileClaims:${coordinate.value}': [
              _profileBadgesEvent(
                id: _eventId(87),
                pubkey: _pubkey(1),
                tags: [
                  ['a', coordinate.value],
                  ['e', _eventId(70)],
                ],
              ),
              _profileBadgesEvent(
                id: _eventId(88),
                pubkey: _pubkey(3),
                tags: [
                  ['a', coordinate.value],
                  ['e', _eventId(71)],
                ],
              ),
            ],
            'profileCurrent:${_pubkey(3)}': [
              _profileBadgesEvent(
                id: _eventId(89),
                pubkey: _pubkey(3),
                tags: [
                  ['a', coordinate.value],
                  ['e', _eventId(71)],
                ],
              ),
            ],
          });

          final claimants = await repository.loadClaimantPubkeys(coordinate);

          expect(claimants, {_pubkey(3)});
          final capturedFilters = verify(
            () => nostrClient.queryEvents(captureAny()),
          ).captured.cast<List<Filter>>();
          final authorFilters = capturedFilters
              .expand((filters) => filters)
              .where((filter) => filter.authors?.isNotEmpty == true);
          expect(
            authorFilters.every(
              (filter) => filter.authors?.contains(_pubkey(1)) == false,
            ),
            isTrue,
          );
        },
      );

      test('checks claimant candidates in bounded author chunks', () async {
        final candidates = [
          for (var i = 0; i < 101; i++)
            _profileBadgesEvent(
              id: _eventId(1000 + i),
              pubkey: _pubkey(10 + i),
              tags: [
                ['a', coordinate.value],
                ['e', _eventId(2000 + i)],
              ],
            ),
        ];
        _stubQueries(nostrClient, {
          'profileClaims:${coordinate.value}': candidates,
          'profileCurrentBatch:${[
            for (var i = 0; i < 100; i++) _pubkey(10 + i),
          ].join(',')}': candidates
              .take(100)
              .toList(growable: false),
          'profileCurrent:${_pubkey(110)}': [candidates.last],
        });

        final claimants = await repository.loadClaimantPubkeys(coordinate);

        expect(claimants, hasLength(101));
        final capturedFilters = verify(
          () => nostrClient.queryEvents(captureAny()),
        ).captured.cast<List<Filter>>();
        final authorFilterGroups = capturedFilters
            .where((filters) => filters.any((filter) => filter.authors != null))
            .toList(growable: false);
        expect(authorFilterGroups, hasLength(2));
        expect(authorFilterGroups.first.first.authors, hasLength(100));
        expect(authorFilterGroups.last.first.authors, [_pubkey(110)]);
      });

      test(
        'ignores non-profile legacy badge sets returned by the relay',
        () async {
          _stubQueries(nostrClient, {
            'profileClaims:${coordinate.value}': [
              _profileBadgesEvent(
                id: _eventId(86),
                pubkey: _pubkey(3),
                kind: EventKind.badgeSet,
                tags: [
                  ['d', 'not_profile_badges'],
                  ['a', coordinate.value],
                  ['e', _eventId(70)],
                ],
              ),
            ],
          });

          final claimants = await repository.loadClaimantPubkeys(coordinate);

          expect(claimants, isEmpty);
          verify(() => nostrClient.queryEvents(any())).called(1);
        },
      );
    });

    group('saveDefinition', () {
      test('publishes a kind 30009 definition', () async {
        final definition = await repository.saveDefinition(
          const BadgeDefinitionDraft(
            identifier: ' scene-stealer ',
            name: ' Scene Stealer ',
            description: ' Steals the scroll. ',
            imageUrl: 'https://media.divine.video/scene.png',
            thumbnailUrl: 'https://media.divine.video/scene-thumb.png',
          ),
        );

        final event = lastSignedEvent()!;
        expect(event.kind, EventKind.badgeDefinition);
        expect(event.tags, [
          ['d', 'scene-stealer'],
          ['name', 'Scene Stealer'],
          ['description', 'Steals the scroll.'],
          ['image', 'https://media.divine.video/scene.png'],
          ['thumb', 'https://media.divine.video/scene-thumb.png'],
        ]);
        expect(definition.dTag, 'scene-stealer');
        expect(definition.coordinate, '30009:${_pubkey(1)}:scene-stealer');
      });

      test('omits the thumbnail and description tags when unset', () async {
        await repository.saveDefinition(
          const BadgeDefinitionDraft(
            identifier: 'scene-stealer',
            name: 'Scene Stealer',
            imageUrl: _artworkUrl,
          ),
        );

        // An empty description tag parses back as '' rather than null, which
        // reads downstream as "has a description" and renders a blank line.
        expect(lastSignedEvent()!.tags, [
          ['d', 'scene-stealer'],
          ['name', 'Scene Stealer'],
          ['image', _artworkUrl],
        ]);
      });

      test('rejects a draft without artwork', () async {
        await expectLater(
          repository.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: '  ',
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects a draft without an identifier', () async {
        await expectLater(
          repository.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: '  ',
              name: 'Scene Stealer',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects a draft without a name', () async {
        await expectLater(
          repository.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: '  ',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('throws a StateError when signing fails', () async {
        final unsigned = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => _pubkey(1),
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          unsigned.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Could not sign badge definition event',
            ),
          ),
        );
      });

      test(
        'throws a StateError when the signed event is not a definition',
        () async {
          final stripped = BadgeRepository(
            nostrClient: nostrClient,
            sharedPreferences: preferences,
            currentPubkey: () => _pubkey(1),
            signEvent:
                ({required kind, required content, required tags}) async =>
                    _event(id: _eventId(80), pubkey: _pubkey(1), kind: kind),
          );

          await expectLater(
            stripped.saveDefinition(
              const BadgeDefinitionDraft(
                identifier: 'scene-stealer',
                name: 'Scene Stealer',
                imageUrl: _artworkUrl,
              ),
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'Signed badge definition event is not parseable',
              ),
            ),
          );
        },
      );

      test('throws a BadgePublishException when no relay accepts', () async {
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          return _rejectedPublishOutcome(
            invocation.positionalArguments.single as Event,
          );
        });

        await expectLater(
          repository.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(isA<BadgePublishException>()),
        );
      });
    });

    group('awardBadge', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(1),
        identifier: 'scene-stealer',
      );

      test('publishes a kind 8 award with deduplicated recipients', () async {
        final award = await repository.awardBadge(
          coordinate: coordinate,
          recipientPubkeys: [_pubkey(2), _pubkey(2), 'not-a-key', _pubkey(3)],
        );

        final event = lastSignedEvent()!;
        expect(event.kind, EventKind.badgeAward);
        expect(event.tags, [
          ['a', coordinate.value],
          ['p', _pubkey(2)],
          ['p', _pubkey(3)],
        ]);
        expect(award.recipientPubkeys, [_pubkey(2), _pubkey(3)]);
      });

      test("refuses to award someone else's badge", () async {
        await expectLater(
          repository.awardBadge(
            coordinate: BadgeCoordinate(
              pubkey: _pubkey(2),
              identifier: 'scene-stealer',
            ),
            recipientPubkeys: [_pubkey(3)],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Cannot award a badge issued by someone else',
            ),
          ),
        );
        expect(lastSignedEvent(), isNull);
      });

      test('rejects an award without a usable recipient', () async {
        await expectLater(
          repository.awardBadge(
            coordinate: coordinate,
            recipientPubkeys: const ['not-a-key'],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.awardBadge(
            coordinate: coordinate,
            recipientPubkeys: [_pubkey(2)],
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('throws a StateError when signing fails', () async {
        final unsigned = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => _pubkey(1),
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          unsigned.awardBadge(
            coordinate: coordinate,
            recipientPubkeys: [_pubkey(2)],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Could not sign badge award event',
            ),
          ),
        );
      });

      test(
        'throws a StateError when the signed event is not an award',
        () async {
          final stripped = BadgeRepository(
            nostrClient: nostrClient,
            sharedPreferences: preferences,
            currentPubkey: () => _pubkey(1),
            signEvent:
                ({required kind, required content, required tags}) async =>
                    _event(id: _eventId(81), pubkey: _pubkey(1), kind: kind),
          );

          await expectLater(
            stripped.awardBadge(
              coordinate: coordinate,
              recipientPubkeys: [_pubkey(2)],
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'Signed badge award event is not parseable',
              ),
            ),
          );
        },
      );
    });

    group('revokeAward', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(1),
        identifier: 'scene-stealer',
      );

      test(
        'republishes for the others before deleting the shared award',
        () async {
          _stubQueries(nostrClient, {
            'awardsFor:${coordinate.value}': [
              _awardEvent(
                id: _eventId(60),
                issuerPubkey: _pubkey(1),
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(2), _pubkey(3)],
              ),
              _awardEvent(
                id: _eventId(61),
                issuerPubkey: _pubkey(1),
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(4)],
              ),
            ],
          });

          await repository.revokeAward(
            coordinate: coordinate,
            recipientPubkey: _pubkey(2),
          );

          final published = verify(
            () => nostrClient.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          // The replacement goes first: a refused deletion then leaves
          // everybody holding what they already had.
          expect(published.map((event) => event.kind), [
            EventKind.badgeAward,
            EventKind.eventDeletion,
          ]);
          expect(published.first.tags, [
            ['a', coordinate.value],
            ['p', _pubkey(3)],
          ]);
          // Only the award naming the revoked recipient, and no `a` tag —
          // that would take the badge definition down with it.
          expect(published.last.tags, [
            ['e', _eventId(60)],
            ['k', '${EventKind.badgeAward}'],
          ]);
        },
      );

      test('deletes outright when nobody else was named', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(62),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2)],
            ),
          ],
        });

        await repository.revokeAward(
          coordinate: coordinate,
          recipientPubkey: _pubkey(2),
        );

        final published = verify(
          () => nostrClient.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published, hasLength(1));
        expect(published.single.kind, EventKind.eventDeletion);
        expect(published.single.tags, [
          ['e', _eventId(62)],
          ['k', '${EventKind.badgeAward}'],
        ]);
      });

      test(
        'ignores malformed bystanders and still deletes the award',
        () async {
          _stubQueries(nostrClient, {
            'awardsFor:${coordinate.value}': [
              _awardEvent(
                id: _eventId(72),
                issuerPubkey: _pubkey(1),
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(2), 'npub1notavalidptag'],
              ),
            ],
          });

          await repository.revokeAward(
            coordinate: coordinate,
            recipientPubkey: _pubkey(2),
          );

          final published = verify(
            () => nostrClient.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          expect(published, hasLength(1));
          expect(published.single.kind, EventKind.eventDeletion);
        },
      );

      test('keeps valid bystanders and drops malformed p tags', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(73),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2), 'npub1notavalidptag', _pubkey(3)],
            ),
          ],
        });

        await repository.revokeAward(
          coordinate: coordinate,
          recipientPubkey: _pubkey(2),
        );

        final published = verify(
          () => nostrClient.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published.first.tags, [
          ['a', coordinate.value],
          ['p', _pubkey(3)],
        ]);
      });

      test('reuses an existing replacement when retrying deletion', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(74),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2), _pubkey(3)],
            ),
            _awardEvent(
              id: _eventId(75),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(3)],
            ),
          ],
        });

        await repository.revokeAward(
          coordinate: coordinate,
          recipientPubkey: _pubkey(2),
        );

        final published = verify(
          () => nostrClient.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published, hasLength(1));
        expect(published.single.kind, EventKind.eventDeletion);
        expect(published.single.tags, [
          ['e', _eventId(74)],
          ['k', '${EventKind.badgeAward}'],
        ]);
      });

      test('revokes every award naming them, not just the newest', () async {
        // Leaving the older one behind would put them straight back on the
        // recipient list, which resolves someone through their newest award.
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(63),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2)],
            ),
            _awardEvent(
              id: _eventId(64),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2), _pubkey(3)],
              createdAt: 2000,
            ),
          ],
        });

        await repository.revokeAward(
          coordinate: coordinate,
          recipientPubkey: _pubkey(2),
        );

        final published = verify(
          () => nostrClient.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published.last.tags, [
          ['e', _eventId(64)],
          ['e', _eventId(63)],
          ['k', '${EventKind.badgeAward}'],
        ]);
      });

      test('publishes nothing when no award names the recipient', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(65),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(3)],
            ),
          ],
        });

        await repository.revokeAward(
          coordinate: coordinate,
          recipientPubkey: _pubkey(2),
        );

        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('takes down your own pin when you revoke yourself', () async {
        // The award goes, but the pin is a separate event of the viewer's
        // own — left behind, the badge keeps rendering on their profile.
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(67),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(1)],
            ),
          ],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(68),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate.value],
                ['e', _eventId(67)],
              ],
            ),
          ],
        });

        await repository.revokeAward(
          coordinate: coordinate,
          recipientPubkey: _pubkey(1),
        );

        final published = verify(
          () => nostrClient.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published.map((event) => event.kind), [
          EventKind.eventDeletion,
          EventKind.profileBadges,
        ]);
        expect(published.last.tags, isEmpty);
      });

      test('unpins on a retry after the awards are already gone', () async {
        // The first attempt deleted the award but failed before the unpin,
        // so the retry finds no award to revoke and must still get there.
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(69),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate.value],
                ['e', _eventId(67)],
              ],
            ),
          ],
        });

        await repository.revokeAward(
          coordinate: coordinate,
          recipientPubkey: _pubkey(1),
        );

        final published = verify(
          () => nostrClient.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published.single.kind, EventKind.profileBadges);
      });

      test('leaves the profile badge list alone for anyone else', () async {
        // Their pin is their own event; publishing ours would not reach it.
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(70),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2)],
            ),
          ],
        });

        await repository.revokeAward(
          coordinate: coordinate,
          recipientPubkey: _pubkey(2),
        );

        final published = verify(
          () => nostrClient.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published.single.kind, EventKind.eventDeletion);
      });

      test(
        'publishes no profile list when the badge was never pinned',
        () async {
          _stubQueries(nostrClient, {
            'awardsFor:${coordinate.value}': [
              _awardEvent(
                id: _eventId(71),
                issuerPubkey: _pubkey(1),
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(1)],
              ),
            ],
          });

          await repository.revokeAward(
            coordinate: coordinate,
            recipientPubkey: _pubkey(1),
          );

          final published = verify(
            () => nostrClient.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          expect(published.single.kind, EventKind.eventDeletion);
        },
      );

      test("refuses to revoke someone else's badge", () async {
        await expectLater(
          repository.revokeAward(
            coordinate: BadgeCoordinate(
              pubkey: _pubkey(2),
              identifier: 'scene-stealer',
            ),
            recipientPubkey: _pubkey(3),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Cannot revoke a badge issued by someone else',
            ),
          ),
        );
        expect(lastSignedEvent(), isNull);
      });

      test('refuses a recipient that is not a hex pubkey', () async {
        await expectLater(
          repository.revokeAward(
            coordinate: coordinate,
            recipientPubkey: 'npub1notdecodedhere',
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(lastSignedEvent(), isNull);
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.revokeAward(
            coordinate: coordinate,
            recipientPubkey: _pubkey(2),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('throws a BadgePublishException when no relay accepts', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(66),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2)],
            ),
          ],
        });
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          return _rejectedPublishOutcome(
            invocation.positionalArguments.single as Event,
          );
        });

        await expectLater(
          repository.revokeAward(
            coordinate: coordinate,
            recipientPubkey: _pubkey(2),
          ),
          throwsA(isA<BadgePublishException>()),
        );
      });
    });

    group('deleteBadge', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(1),
        identifier: 'scene-stealer',
      );

      test('requests deletion of the definition and its awards', () async {
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              id: _eventId(90),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
          ],
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(91),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2)],
            ),
            _awardEvent(
              id: _eventId(92),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(3)],
            ),
          ],
        });

        await repository.deleteBadge(coordinate);

        final event = lastSignedEvent()!;
        expect(event.kind, EventKind.eventDeletion);
        expect(event.tags, [
          ['a', coordinate.value],
          ['e', _eventId(90)],
          ['e', _eventId(91)],
          ['e', _eventId(92)],
          ['k', '${EventKind.badgeDefinition}'],
          ['k', '${EventKind.badgeAward}'],
        ]);
      });

      test('leaves out the award kind when nothing was awarded', () async {
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              id: _eventId(93),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
          ],
        });

        await repository.deleteBadge(coordinate);

        expect(lastSignedEvent()!.tags, [
          ['a', coordinate.value],
          ['e', _eventId(93)],
          ['k', '${EventKind.badgeDefinition}'],
        ]);
      });

      test('still deletes when no definition event was found', () async {
        await repository.deleteBadge(coordinate);

        expect(lastSignedEvent()!.tags, [
          ['a', coordinate.value],
          ['k', '${EventKind.badgeDefinition}'],
        ]);
      });

      test("refuses to delete someone else's badge", () async {
        await expectLater(
          repository.deleteBadge(
            BadgeCoordinate(pubkey: _pubkey(2), identifier: 'scene-stealer'),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Cannot delete a badge issued by someone else',
            ),
          ),
        );
        expect(lastSignedEvent(), isNull);
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.deleteBadge(coordinate),
          throwsA(isA<StateError>()),
        );
      });

      test('throws a BadgePublishException when no relay accepts', () async {
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          return _rejectedPublishOutcome(
            invocation.positionalArguments.single as Event,
          );
        });

        await expectLater(
          repository.deleteBadge(coordinate),
          throwsA(isA<BadgePublishException>()),
        );
      });
    });

    test('loadDashboard reads the issued awards query once', () async {
      final callCounts = _stubQueries(nostrClient, {
        'created:${_pubkey(1)}': [
          _definitionEvent(
            id: _eventId(82),
            pubkey: _pubkey(1),
            dTag: 'scene-stealer',
            name: 'Scene Stealer',
          ),
        ],
        'issued': [
          _awardEvent(
            id: _eventId(83),
            issuerPubkey: _pubkey(1),
            definitionCoordinate: '30009:${_pubkey(1)}:scene-stealer',
            recipients: [_pubkey(2)],
          ),
        ],
      });

      final dashboard = await repository.loadDashboard();

      expect(dashboard.created.single.awardCount, 1);
      expect(dashboard.issued, hasLength(1));
      expect(callCounts['issued'], 1);
    });
  });

  group(ProfileBadgeViewData, () {
    test('exposes issuer, recipients, deduplicated unique recipients, and a '
        'coordinate-derived name when no definition is present', () {
      final coordinate = '30009:${_pubkey(5)}:daily-diviner';
      final award = Nip58BadgeParser.parseAward(
        _awardEvent(
          id: _eventId(40),
          issuerPubkey: _pubkey(5),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(6), _pubkey(6), _pubkey(7)],
        ),
      )!;
      final viewData = ProfileBadgeViewData(
        badge: Nip58ProfileBadgeRef(
          definitionCoordinate: coordinate,
          awardEventId: _eventId(40),
        ),
        award: award,
      );

      expect(viewData.issuerPubkey, _pubkey(5));
      expect(viewData.recipientPubkeys, [_pubkey(6), _pubkey(6), _pubkey(7)]);
      expect(viewData.uniqueRecipientPubkeys, [_pubkey(6), _pubkey(7)]);
      expect(viewData.displayName, 'daily-diviner');
      expect(viewData.description, isNull);
      expect(viewData.imageUrl, isNull);
    });

    // The coordinate comes from someone else's `a` tag, so the fallback name
    // is remote text too. The headless flutter_tester does not throw on a lone
    // surrogate — only the real engine does — so this asserts the value.
    test('replaces a lone surrogate in the coordinate-derived name', () {
      final coordinate =
          '30009:${_pubkey(5)}:daily${String.fromCharCode(0xD83D)}diviner';
      final viewData = ProfileBadgeViewData(
        badge: Nip58ProfileBadgeRef(
          definitionCoordinate: coordinate,
          awardEventId: _eventId(40),
        ),
      );

      expect(viewData.displayName, 'daily�diviner');
    });

    test('replaces a lone surrogate in a coordinate with no d-tag', () {
      final viewData = ProfileBadgeViewData(
        badge: Nip58ProfileBadgeRef(
          definitionCoordinate: 'broken${String.fromCharCode(0xDE00)}',
          awardEventId: _eventId(40),
        ),
      );

      expect(viewData.displayName, 'broken�');
    });
  });

  group(BadgeAwardViewData, () {
    test('exposes award id, coordinate, and a coordinate-derived name when no '
        'definition is present', () {
      final coordinate = '30009:${_pubkey(8)}:weekly-diviner';
      final award = Nip58BadgeParser.parseAward(
        _awardEvent(
          id: _eventId(41),
          issuerPubkey: _pubkey(8),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        ),
      )!;
      final viewData = BadgeAwardViewData(award: award);

      expect(viewData.awardEventId, _eventId(41));
      expect(viewData.definitionCoordinate, coordinate);
      expect(viewData.displayName, 'weekly-diviner');
      expect(viewData.imageUrl, isNull);
    });

    test(
      'prefers the definition name and image when a definition is present',
      () {
        final coordinate = '30009:${_pubkey(8)}:weekly-diviner';
        final award = Nip58BadgeParser.parseAward(
          _awardEvent(
            id: _eventId(41),
            issuerPubkey: _pubkey(8),
            definitionCoordinate: coordinate,
            recipients: [_pubkey(1)],
          ),
        )!;
        final definition = Nip58BadgeParser.parseDefinition(
          _definitionEvent(
            pubkey: _pubkey(8),
            dTag: 'weekly-diviner',
            name: 'Weekly Diviner',
            imageUrl: 'https://media.divine.video/weekly.png',
          ),
        )!;
        final viewData = BadgeAwardViewData(
          award: award,
          definition: definition,
        );

        expect(viewData.displayName, 'Weekly Diviner');
        expect(viewData.imageUrl, 'https://media.divine.video/weekly.png');
      },
    );
  });
}

/// Stubs [NostrClient.queryEvents] with answer-keyed canned events and
/// returns a live map of query-key invocation counts for dedup assertions.
Map<String, int> _stubQueries(
  _MockNostrClient nostrClient,
  Map<String, List<Event>> eventsByQueryKey, {
  Map<String, Duration> delaysByQueryKey = const {},
  Map<String, Exception> errorsByQueryKey = const {},
}) {
  final callCounts = <String, int>{};
  when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) async {
    final filters = invocation.positionalArguments.single as List<Filter>;
    final events = <Event>[];
    for (final filter in filters) {
      final key = _queryKey(filter);
      callCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
      final delay = delaysByQueryKey[key];
      if (delay != null) {
        await Future<void>.delayed(delay);
      }
      final error = errorsByQueryKey[key];
      if (error != null) {
        throw error;
      }
      events.addAll(eventsByQueryKey[key] ?? const <Event>[]);
    }
    return events;
  });
  return callCounts;
}

String _queryKey(Filter filter) {
  if (filter.ids?.isNotEmpty == true) {
    return 'ids:${filter.ids!.join(',')}';
  }
  // Checked before `issued`: an issuer's own coordinate query carries both
  // `authors` and `a`, and only the `a` form is the detail-page lookup.
  if (filter.kinds?.contains(EventKind.badgeAward) == true &&
      filter.a?.isNotEmpty == true) {
    return 'awardsFor:${filter.a!.single}';
  }
  if (filter.kinds?.contains(EventKind.profileBadges) == true &&
      filter.kinds?.contains(EventKind.badgeSet) == true &&
      filter.a?.isNotEmpty == true) {
    return 'profileClaims:${filter.a!.single}';
  }
  if (filter.kinds?.contains(EventKind.badgeDefinition) == true &&
      filter.authors?.isNotEmpty == true &&
      filter.d == null) {
    return 'created:${filter.authors!.single}';
  }
  if (filter.kinds?.contains(EventKind.badgeAward) == true &&
      filter.p?.contains(_pubkey(1)) == true) {
    return 'awarded';
  }
  if (filter.kinds?.contains(EventKind.badgeAward) == true &&
      filter.authors?.contains(_pubkey(1)) == true) {
    return 'issued';
  }
  if (filter.kinds?.contains(EventKind.profileBadges) == true &&
      filter.authors?.isNotEmpty == true) {
    return filter.authors!.length == 1
        ? 'profileCurrent:${filter.authors!.single}'
        : 'profileCurrentBatch:${filter.authors!.join(',')}';
  }
  if (filter.kinds?.contains(EventKind.badgeSet) == true &&
      filter.authors?.isNotEmpty == true &&
      filter.d?.contains('profile_badges') == true) {
    return filter.authors!.length == 1
        ? 'profileLegacy:${filter.authors!.single}'
        : 'profileLegacyBatch:${filter.authors!.join(',')}';
  }
  if (filter.kinds?.contains(EventKind.badgeDefinition) == true &&
      filter.authors?.isNotEmpty == true &&
      filter.d?.isNotEmpty == true) {
    return 'definition:${EventKind.badgeDefinition}:${filter.authors!.single}:${filter.d!.single}';
  }
  return 'unknown';
}

Event _awardEvent({
  required String id,
  required String issuerPubkey,
  required String definitionCoordinate,
  required List<String> recipients,
  int createdAt = 1000,
}) {
  return _event(
    id: id,
    pubkey: issuerPubkey,
    kind: EventKind.badgeAward,
    createdAt: createdAt,
    tags: [
      ['a', definitionCoordinate],
      for (final recipient in recipients) ['p', recipient],
    ],
  );
}

Event _profileBadgesEvent({
  required String id,
  required String pubkey,
  required List<List<String>> tags,
  int kind = EventKind.profileBadges,
  int createdAt = 1000,
}) {
  return _event(
    id: id,
    pubkey: pubkey,
    kind: kind,
    tags: tags,
    createdAt: createdAt,
  );
}

PublishOutcome _acceptedPublishOutcome(Event event) {
  return PublishOutcome(
    eventId: event.id,
    acceptedBy: const ['wss://relay.divine.video'],
    rejectedBy: const {},
    noResponseFrom: const [],
  );
}

PublishOutcome _rejectedPublishOutcome(Event event) {
  return PublishOutcome(
    eventId: event.id,
    acceptedBy: const [],
    rejectedBy: const {
      'wss://relay.divine.video': 'blocked: kind 10008 not in allowed list',
    },
    noResponseFrom: const [],
  );
}

Event _definitionEvent({
  required String pubkey,
  required String dTag,
  required String name,
  String? description,
  String? imageUrl,
  List<String> thumbnails = const [],
  String? id,
  int createdAt = 1000,
}) {
  return _event(
    id: id ?? _eventId(100),
    pubkey: pubkey,
    kind: EventKind.badgeDefinition,
    createdAt: createdAt,
    tags: [
      ['d', dTag],
      ['name', name],
      if (description != null) ['description', description],
      if (imageUrl != null) ['image', imageUrl],
      for (final thumbnail in thumbnails) ['thumb', thumbnail],
    ],
  );
}

Event _event({
  required String id,
  required String pubkey,
  int kind = 1,
  List<List<String>> tags = const [],
  int createdAt = 1000,
  String content = '',
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': '',
  });
}

const _artworkUrl = 'https://media.divine.video/scene.png';

BadgeAwardViewData _byCoordinate(
  List<BadgeAwardViewData> awards,
  String coordinate,
) {
  return awards.firstWhere(
    (award) => award.definitionCoordinate == coordinate,
  );
}

String _eventId(int seed) => seed.toRadixString(16).padLeft(64, '0');

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');
