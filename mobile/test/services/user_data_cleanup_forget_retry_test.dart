// ABOUTME: Preserves a new forget-account request when earlier cleanup resumes.
// ABOUTME: Does not widen the retained cleanup intent to another account.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('clearUserSpecificData forget retries', () {
    for (final sameOwner in [true, false]) {
      test(
        'resumed identity cleanup does not consume '
        '${sameOwner ? 'the same' : 'another'} owner forget request',
        () async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final service = UserDataCleanupService(prefs);
          final alice = 'a' * 64;
          final bob = 'b' * 64;
          final requestedOwner = sameOwner ? alice : bob;
          final delivered = <({String? owner, bool delete, bool forget})>[];
          var failFirst = true;
          service.onDatabaseCleanup =
              ({
                String? userPubkey,
                bool deleteUserData = false,
                bool preserveActiveSession = false,
                bool forgetAccount = false,
              }) async {
                delivered.add((
                  owner: userPubkey,
                  delete: deleteUserData,
                  forget: forgetAccount,
                ));
                if (failFirst) {
                  failFirst = false;
                  throw StateError('The first required database sweep failed');
                }
              };

          await expectLater(
            service.clearUserSpecificData(
              userPubkey: alice,
              isIdentityChange: true,
            ),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(PendingAccountCleanup.read(prefs)?.userPubkey, alice);

          await service.clearUserSpecificData(
            userPubkey: requestedOwner,
            forgetAccount: true,
          );

          expect(delivered, [
            (owner: alice, delete: false, forget: false),
            (owner: alice, delete: false, forget: false),
            (owner: requestedOwner, delete: false, forget: true),
          ]);
          expect(PendingAccountCleanup.read(prefs), isNull);
        },
      );
    }

    test(
      'inactive full deletion covers forget without clearing the active owner',
      () async {
        final alice = 'a' * 64;
        final bob = 'b' * 64;
        SharedPreferences.setMockInitialValues({
          'current_user_pubkey_hex': bob,
          'vine_drafts': 'Bob drafts',
          UserDataCleanupService.legacyDraftOwnerKey: bob,
        });
        final prefs = await SharedPreferences.getInstance();
        final service = UserDataCleanupService(prefs);
        final lease = CuratedListSessionCoordinator.forPreferences(prefs)
            .acquire();
        expect(lease.isCurrent, isTrue);
        final delivered =
            <({String? owner, bool delete, bool forget, bool preserve})>[];
        service.onDatabaseCleanup =
            ({
              String? userPubkey,
              bool deleteUserData = false,
              bool preserveActiveSession = false,
              bool forgetAccount = false,
            }) async {
              delivered.add((
                owner: userPubkey,
                delete: deleteUserData,
                forget: forgetAccount,
                preserve: preserveActiveSession,
              ));
            };
        await PendingAccountCleanup(
          userPubkey: alice,
          isIdentityChange: false,
          deleteUserData: true,
          preserveActiveSession: true,
        ).record(prefs);

        await service.clearUserSpecificData(
          userPubkey: alice,
          forgetAccount: true,
        );

        expect(delivered, [
          (owner: alice, delete: true, forget: false, preserve: true),
        ]);
        expect(prefs.getString('current_user_pubkey_hex'), bob);
        expect(prefs.getString('vine_drafts'), 'Bob drafts');
        expect(
          prefs.getString(UserDataCleanupService.legacyDraftOwnerKey),
          bob,
        );
        expect(lease.isCurrent, isTrue);
        expect(PendingAccountCleanup.read(prefs), isNull);
      },
    );
  });
}
