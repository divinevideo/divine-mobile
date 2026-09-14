// ABOUTME: Tests support-chat opening outcomes and duplicate-tap suppression
// ABOUTME: Pins the loading state used while deferred SDK startup settles

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/support_contact/support_contact_cubit.dart';

const _emailRequest = SupportContactEmailRequest(
  toEmail: 'support@example.com',
  subject: 'Support',
  body: 'Tell us what happened.',
  messagingUnavailableNote: 'Chat unavailable.',
  messagingFailedNote: 'Messages failed.',
);

void main() {
  group(SupportContactCubit, () {
    blocTest<SupportContactCubit, SupportContactState>(
      'reports opened when native support opens',
      build: () => SupportContactCubit(openSupportMessages: () async => true),
      act: (cubit) => cubit.open(_emailRequest),
      expect: () => const [
        SupportContactState(status: SupportContactStatus.opening),
        SupportContactState(status: SupportContactStatus.messagingOpened),
      ],
    );

    blocTest<SupportContactCubit, SupportContactState>(
      'requests fallback when native support is unavailable',
      build: () => SupportContactCubit(
        openSupportMessages: () async => false,
        composeEmail: ({
          required toEmail,
          required subject,
          required body,
          sharePositionOrigin,
        }) async {},
      ),
      act: (cubit) => cubit.open(_emailRequest),
      expect: () => const [
        SupportContactState(status: SupportContactStatus.opening),
        SupportContactState(status: SupportContactStatus.emailOpened),
      ],
    );

    blocTest<SupportContactCubit, SupportContactState>(
      'requests fallback when the opener throws instead of returning',
      // A throwing opener must not strand the tile on `opening` with the tap
      // disabled and no email fallback — that is the #8921 failure this cubit
      // exists to prevent.
      build: () => SupportContactCubit(
        openSupportMessages: () async => throw Exception('native crash'),
        composeEmail: ({
          required toEmail,
          required subject,
          required body,
          sharePositionOrigin,
        }) async {},
      ),
      act: (cubit) => cubit.open(_emailRequest),
      expect: () => const [
        SupportContactState(status: SupportContactStatus.opening),
        SupportContactState(status: SupportContactStatus.emailOpened),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<SupportContactCubit, SupportContactState>(
      'uses the unavailable note when native support is unavailable',
      build: () => SupportContactCubit(
        supportMessagesAvailable: false,
        composeEmail:
            ({
              required toEmail,
              required subject,
              required body,
              sharePositionOrigin,
            }) async {
              expect(body, 'Chat unavailable.\n\nTell us what happened.');
            },
      ),
      act: (cubit) => cubit.open(_emailRequest),
      expect: () => const [
        SupportContactState(status: SupportContactStatus.opening),
        SupportContactState(status: SupportContactStatus.emailOpened),
      ],
    );

    blocTest<SupportContactCubit, SupportContactState>(
      'reports email failure when the fallback cannot open',
      build: () => SupportContactCubit(
        openSupportMessages: () async => false,
        composeEmail: ({
          required toEmail,
          required subject,
          required body,
          sharePositionOrigin,
        }) async => throw Exception('email failed'),
      ),
      act: (cubit) => cubit.open(_emailRequest),
      expect: () => const [
        SupportContactState(status: SupportContactStatus.opening),
        SupportContactState(status: SupportContactStatus.emailFailed),
      ],
      errors: () => [isA<Exception>()],
    );

    test('ignores a second open while the first is in flight', () async {
      final gate = Completer<bool>();
      var calls = 0;
      final cubit = SupportContactCubit(
        openSupportMessages: () {
          calls++;
          return gate.future;
        },
      );

      final first = cubit.open(_emailRequest);
      final second = cubit.open(_emailRequest);
      expect(calls, 1);

      gate.complete(true);
      await Future.wait([first, second]);
      expect(calls, 1);
      await cubit.close();
    });
  });
}
