// ABOUTME: Tests for RemixConsentRepository — reads a creator's account-wide
// ABOUTME: remix block from their raw kind 0 and fails closed on any doubt.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/remix_consent_repository.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group(RemixConsentRepository, () {
    const authorPubkey =
        'b1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const otherPubkey =
        'c1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const defaultRelayUrl = 'wss://relay.divine.test';

    /// How long a relay that never answers holds a settled read open.
    const relayTimeout = Duration(seconds: 5);

    const conclusiveMiss = (profile: null, conclusive: true);
    const inconclusiveMiss = (profile: null, conclusive: false);

    late _MockProfileRepository profileRepository;
    late RemixConsentRepository repository;

    UserProfile profileWith(
      Map<String, dynamic> rawData, {
      String pubkey = authorPubkey,
    }) => UserProfile(
      pubkey: pubkey,
      rawData: rawData,
      createdAt: DateTime.utc(2026),
      eventId: 'e' * 64,
    );

    final blocking = profileWith(const {divineAllowVideoReuseKey: false});

    /// Answers the read of every connected relay.
    void stubWiderRead(Future<FreshProfileRead> Function() answer) {
      when(
        () => profileRepository.readRawProfileFromRelays(pubkey: authorPubkey),
      ).thenAnswer((_) => answer());
    }

    /// Answers the read of the default relay alone.
    void stubDefaultRelayRead(Future<FreshProfileRead> Function() answer) {
      when(
        () => profileRepository.readRawProfileFromRelays(
          pubkey: authorPubkey,
          onlyRelayUrl: defaultRelayUrl,
        ),
      ).thenAnswer((_) => answer());
    }

    /// A read that answers [read] once [after] has passed.
    Future<FreshProfileRead> Function() answersAfter(
      Duration after,
      FreshProfileRead read,
    ) => () {
      final answer = Completer<FreshProfileRead>();
      Timer(after, () => answer.complete(read));
      return answer.future;
    };

    /// Runs [consentFor] in fake time and reports what it answered and when.
    ({RemixConsent? consent, Duration? at}) consentInFakeTime(
      FakeAsync async, {
      Duration elapse = const Duration(seconds: 10),
    }) {
      RemixConsent? consent;
      Duration? at;
      unawaited(
        repository.consentFor(authorPubkey).then((value) {
          consent = value;
          at = async.elapsed;
        }),
      );
      async.elapse(elapse);
      return (consent: consent, at: at);
    }

    setUp(() {
      profileRepository = _MockProfileRepository();
      repository = RemixConsentRepository(
        profileRepository: profileRepository,
        defaultRelayUrl: defaultRelayUrl,
      );
      // Unless a test says otherwise, the default relay never answers.
      stubDefaultRelayRead(() => Completer<FreshProfileRead>().future);
    });

    group('consentFor', () {
      test('is blocked when the kind 0 carries a JSON false', () async {
        stubWiderRead(() async => (profile: blocking, conclusive: true));

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.blocked,
        );
      });

      test('is allowed when the key is absent', () async {
        stubWiderRead(
          () async => (
            profile: profileWith(const {'name': 'alice'}),
            conclusive: true,
          ),
        );

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.allowed,
        );
      });

      test('is allowed when the key is true', () async {
        stubWiderRead(
          () async => (
            profile: profileWith(const {divineAllowVideoReuseKey: true}),
            conclusive: true,
          ),
        );

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.allowed,
        );
      });

      test('is allowed when the author confirmably has no kind 0', () async {
        stubWiderRead(() async => conclusiveMiss);

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.allowed,
        );
      });

      test('asks every relay and the default relay at once', () {
        fakeAsync((async) {
          stubWiderRead(answersAfter(relayTimeout, inconclusiveMiss));

          unawaited(repository.consentFor(authorPubkey));
          async.flushMicrotasks();

          verify(
            () => profileRepository.readRawProfileFromRelays(
              pubkey: authorPubkey,
            ),
          ).called(1);
          verify(
            () => profileRepository.readRawProfileFromRelays(
              pubkey: authorPubkey,
              onlyRelayUrl: defaultRelayUrl,
            ),
          ).called(1);
          async.elapse(relayTimeout);
        });
      });

      test('is unknown when the profile belongs to someone else', () async {
        stubWiderRead(
          () async => (
            profile: profileWith(const {}, pubkey: otherPubkey),
            conclusive: true,
          ),
        );
        stubDefaultRelayRead(() async => inconclusiveMiss);

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.unknown,
        );
      });

      test('is unknown when both reads throw', () async {
        stubWiderRead(() async => throw Exception('relay down'));
        stubDefaultRelayRead(() async => throw Exception('socket closed'));

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.unknown,
        );
      });

      group('when a read fails with an Error', () {
        test('completes with the error instead of hanging', () {
          fakeAsync((async) {
            stubWiderRead(() async => throw TypeError());
            stubDefaultRelayRead(answersAfter(relayTimeout, inconclusiveMiss));

            Object? error;
            unawaited(
              repository
                  .consentFor(authorPubkey)
                  .then<void>(
                    (_) {},
                    onError: (Object e) => error = e,
                  ),
            );
            async.elapse(Duration.zero);

            expect(error, isA<TypeError>());
          });
        });

        test('completes when both reads fail with an Error', () async {
          stubWiderRead(() async => throw TypeError());
          stubDefaultRelayRead(() async => throw TypeError());

          await expectLater(
            repository.consentFor(authorPubkey),
            throwsA(isA<TypeError>()),
          );
        });

        test('keeps an answer another read already settled', () {
          fakeAsync((async) {
            stubDefaultRelayRead(
              () async => (profile: blocking, conclusive: true),
            );
            stubWiderRead(() {
              final failure = Completer<FreshProfileRead>();
              Timer(
                const Duration(seconds: 1),
                () => failure.completeError(TypeError()),
              );
              return failure.future;
            });

            final result = consentInFakeTime(async);

            expect(result.consent, RemixConsent.blocked);
            expect(result.at, Duration.zero);
          });
        });
      });

      test('completes as unknown when a read fails with an Exception', () {
        fakeAsync((async) {
          stubWiderRead(() async => throw Exception('relay down'));
          stubDefaultRelayRead(answersAfter(relayTimeout, inconclusiveMiss));

          final result = consentInFakeTime(async);

          expect(result.consent, RemixConsent.unknown);
          expect(result.at, relayTimeout);
        });
      });

      group('while another relay stays silent', () {
        setUp(() {
          stubWiderRead(answersAfter(relayTimeout, inconclusiveMiss));
          stubDefaultRelayRead(answersAfter(relayTimeout, inconclusiveMiss));
        });

        test('is allowed as soon as the default relay confirms no kind 0', () {
          fakeAsync((async) {
            stubDefaultRelayRead(
              answersAfter(const Duration(milliseconds: 100), conclusiveMiss),
            );

            final result = consentInFakeTime(async);

            expect(result.consent, RemixConsent.allowed);
            expect(result.at, const Duration(milliseconds: 100));
          });
        });

        test(
          'is unknown at the timeout when the default relay is silent too',
          () {
            fakeAsync((async) {
              RemixConsent? consent;
              unawaited(
                repository
                    .consentFor(authorPubkey)
                    .then((value) => consent = value),
              );

              async.elapse(relayTimeout - const Duration(milliseconds: 1));
              expect(consent, isNull);
              async.elapse(const Duration(milliseconds: 1));
              expect(consent, RemixConsent.unknown);
            });
          },
        );

        test('is blocked as soon as the default relay holds a JSON false', () {
          fakeAsync((async) {
            stubDefaultRelayRead(
              answersAfter(
                const Duration(milliseconds: 100),
                (profile: blocking, conclusive: true),
              ),
            );

            final result = consentInFakeTime(async);

            expect(result.consent, RemixConsent.blocked);
            expect(result.at, const Duration(milliseconds: 100));
          });
        });

        test('is allowed when the default relay kind 0 does not block', () {
          fakeAsync((async) {
            stubDefaultRelayRead(
              () async => (
                profile: profileWith(const {'name': 'alice'}),
                conclusive: true,
              ),
            );

            final result = consentInFakeTime(async);

            expect(result.consent, RemixConsent.allowed);
            expect(result.at, Duration.zero);
          });
        });

        test('is unknown when the default relay answers for someone else', () {
          fakeAsync((async) {
            stubDefaultRelayRead(
              () async => (
                profile: profileWith(const {}, pubkey: otherPubkey),
                conclusive: true,
              ),
            );

            expect(consentInFakeTime(async).consent, RemixConsent.unknown);
          });
        });

        test('is unknown when the default relay read throws', () {
          fakeAsync((async) {
            stubDefaultRelayRead(() async => throw Exception('socket closed'));

            expect(consentInFakeTime(async).consent, RemixConsent.unknown);
          });
        });
      });

      group('a JSON false seen in an incomplete read', () {
        test('blocks even when the default relay then answers empty', () {
          fakeAsync((async) {
            stubWiderRead(
              answersAfter(
                const Duration(seconds: 1),
                (profile: blocking, conclusive: false),
              ),
            );
            stubDefaultRelayRead(
              answersAfter(const Duration(seconds: 2), conclusiveMiss),
            );

            final result = consentInFakeTime(async);

            expect(result.consent, RemixConsent.blocked);
            expect(result.at, const Duration(seconds: 1));
          });
        });

        test('blocks when the default relay read is the incomplete one', () {
          fakeAsync((async) {
            stubWiderRead(answersAfter(relayTimeout, inconclusiveMiss));
            stubDefaultRelayRead(
              () async => (profile: blocking, conclusive: false),
            );

            expect(consentInFakeTime(async).consent, RemixConsent.blocked);
          });
        });
      });

      group('within a session', () {
        test('remembers a default-relay confirmed miss', () {
          fakeAsync((async) {
            stubWiderRead(answersAfter(relayTimeout, inconclusiveMiss));
            stubDefaultRelayRead(
              answersAfter(const Duration(milliseconds: 100), conclusiveMiss),
            );
            expect(consentInFakeTime(async).consent, RemixConsent.allowed);
            clearInteractions(profileRepository);

            final again = consentInFakeTime(async, elapse: Duration.zero);

            expect(again.consent, RemixConsent.allowed);
            expect(again.at, async.elapsed);
            verifyNever(
              () => profileRepository.readRawProfileFromRelays(
                pubkey: any(named: 'pubkey'),
                onlyRelayUrl: any(named: 'onlyRelayUrl'),
              ),
            );
          });
        });

        test('does not remember a miss after a JSON false', () {
          fakeAsync((async) {
            stubDefaultRelayRead(
              () async => (profile: blocking, conclusive: true),
            );
            stubWiderRead(
              answersAfter(const Duration(seconds: 1), conclusiveMiss),
            );
            expect(consentInFakeTime(async).consent, RemixConsent.blocked);

            expect(consentInFakeTime(async).consent, RemixConsent.blocked);
            verify(
              () => profileRepository.readRawProfileFromRelays(
                pubkey: authorPubkey,
                onlyRelayUrl: defaultRelayUrl,
              ),
            ).called(2);
          });
        });

        test('forgets a remembered miss once a JSON false turns up', () {
          fakeAsync((async) {
            stubDefaultRelayRead(
              answersAfter(const Duration(milliseconds: 100), conclusiveMiss),
            );
            stubWiderRead(
              answersAfter(
                const Duration(seconds: 1),
                (profile: blocking, conclusive: false),
              ),
            );
            expect(consentInFakeTime(async).consent, RemixConsent.allowed);

            clearInteractions(profileRepository);

            // Asked again rather than answered from the memo.
            consentInFakeTime(async);
            verify(
              () => profileRepository.readRawProfileFromRelays(
                pubkey: authorPubkey,
              ),
            ).called(1);
          });
        });

        test('remembers a miss every relay confirmed', () async {
          stubWiderRead(() async => conclusiveMiss);
          await repository.consentFor(authorPubkey);
          clearInteractions(profileRepository);

          expect(
            await repository.consentFor(authorPubkey.toUpperCase()),
            RemixConsent.allowed,
          );
          verifyNever(
            () => profileRepository.readRawProfileFromRelays(
              pubkey: any(named: 'pubkey'),
              onlyRelayUrl: any(named: 'onlyRelayUrl'),
            ),
          );
        });

        test('reads again after an answer that was not a miss', () async {
          stubWiderRead(
            () async => (
              profile: profileWith(const {'name': 'alice'}),
              conclusive: true,
            ),
          );
          await repository.consentFor(authorPubkey);
          clearInteractions(profileRepository);

          await repository.consentFor(authorPubkey);

          verify(
            () => profileRepository.readRawProfileFromRelays(
              pubkey: authorPubkey,
            ),
          ).called(1);
        });
      });
    });
  });
}
