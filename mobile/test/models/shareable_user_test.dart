// ABOUTME: Tests for ShareableUser, the recipient identity of the share sheet.
// ABOUTME: Covers how a cached profile becomes the row's name and handle.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/shareable_user.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  final recipientPubkey = testPubkeyFromSeed(2);

  group(ShareableUser, () {
    group('fromProfile', () {
      UserProfile profileWith({
        String? nip05,
        String? name,
        String? displayName,
      }) {
        return UserProfile(
          pubkey: recipientPubkey,
          rawData: const {},
          createdAt: DateTime.now(),
          eventId: 'event-handle',
          nip05: nip05,
          name: name,
          displayName: displayName,
        );
      }

      test('uses the full divine nip05 rather than the short form', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(nip05: 'bob@divine.video', name: 'bob'),
        );

        expect(user.handle, equals('@bob.divine.video'));
      });

      test('keeps an external nip05 verbatim, without a leading @', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(nip05: 'dana@nostrplebs.com', name: 'dana'),
        );

        expect(user.handle, equals('dana@nostrplebs.com'));
      });

      test('trims display nip05 before rendering it as a handle', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(nip05: '  dana@nostrplebs.com  ', name: 'dana'),
        );

        expect(user.handle, equals('dana@nostrplebs.com'));
      });

      test('falls back to name when nip05 is blank after trimming', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(nip05: '   ', name: 'dana'),
        );

        expect(user.handle, equals('@dana'));
      });

      test('falls back to name when nip05 is not handle-shaped', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(nip05: 'dana', name: 'fallback'),
        );

        expect(user.handle, equals('@fallback'));
      });

      test('falls back to name when nip05 is only an at sign', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(nip05: '@', name: 'fallback'),
        );

        expect(user.handle, equals('@fallback'));
      });

      test('falls back to name when nip05 contains whitespace', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(nip05: 'dana @nostrplebs.com', name: 'fallback'),
        );

        expect(user.handle, equals('@fallback'));
      });

      test('falls back to an @-prefixed name when there is no nip05', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(name: 'alice'),
        );

        expect(user.handle, equals('@alice'));
      });

      test('does not double the @ on an email-shaped name', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(name: 'dana@nostrplebs.com'),
        );

        expect(user.handle, equals('dana@nostrplebs.com'));
      });

      test('does not double the @ on an already-prefixed name', () {
        final user = ShareableUser.fromProfile(
          recipientPubkey,
          profileWith(name: '@dana'),
        );

        expect(user.handle, equals('@dana'));
      });

      test(
        'leaves the handle null when the profile has no nip05 and no name',
        () {
          final user = ShareableUser.fromProfile(
            recipientPubkey,
            profileWith(displayName: 'Display Only'),
          );

          expect(user.handle, isNull);
          expect(user.displayName, equals('Display Only'));
        },
      );

      test('leaves the handle null when there is no profile at all', () {
        final user = ShareableUser.fromProfile(recipientPubkey, null);

        expect(user.handle, isNull);
        expect(user.displayName, isNull);
        expect(user.pubkey, equals(recipientPubkey));
      });
    });
  });
}
