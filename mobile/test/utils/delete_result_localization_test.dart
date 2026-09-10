// ABOUTME: Tests the DeleteResult -> localized-string mapping for deletes.
// ABOUTME: Pins that only a partly-accepted delete gets the caveat copy.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/utils/delete_result_localization.dart';

void main() {
  Future<BuildContext> pumpContext(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  group('localizedPartialDeleteMessage', () {
    testWidgets('returns the caveat copy when only some relays accepted', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        localizedPartialDeleteMessage(
          context,
          DeleteResult.createSuccess(
            'delete-event-id',
            acceptance: DeleteAcceptance.someRelays,
          ),
        ),
        equals(l10n.shareMenuDeletePartiallyConfirmed),
      );
    });

    testWidgets('returns null when every relay accepted', (tester) async {
      final context = await pumpContext(tester);

      expect(
        localizedPartialDeleteMessage(
          context,
          DeleteResult.createSuccess(
            'delete-event-id',
            acceptance: DeleteAcceptance.everyRelay,
          ),
        ),
        isNull,
      );
    });

    testWidgets('returns null for a failed delete and for no result at all', (
      tester,
    ) async {
      final context = await pumpContext(tester);

      expect(
        localizedPartialDeleteMessage(
          context,
          DeleteResult.failure('nope', DeleteFailureKind.relayRejected),
        ),
        isNull,
      );
      expect(localizedPartialDeleteMessage(context, null), isNull);
    });

    testWidgets('reads the caveat from l10n rather than a hardcoded string', (
      tester,
    ) async {
      final context = await pumpContext(tester, locale: const Locale('de'));

      expect(
        localizedPartialDeleteMessage(
          context,
          DeleteResult.createSuccess(
            'delete-event-id',
            acceptance: DeleteAcceptance.someRelays,
          ),
        ),
        equals(
          lookupAppLocalizations(
            const Locale('de'),
          ).shareMenuDeletePartiallyConfirmed,
        ),
      );
    });
  });

  group('localizedDeleteFailureMessage', () {
    testWidgets('maps every failure kind to distinct, non-empty copy', (
      tester,
    ) async {
      final context = await pumpContext(tester);

      final messages = DeleteFailureKind.values
          .map(
            (kind) => localizedDeleteFailureMessage(
              context,
              DeleteResult.failure('diagnostic', kind),
            ),
          )
          .toList();

      expect(messages.every((m) => m.isNotEmpty), isTrue);
      expect(
        messages.toSet(),
        hasLength(messages.length),
        reason: 'two failure kinds resolve to the same copy',
      );
    });

    testWidgets('returns an empty string for a successful delete', (
      tester,
    ) async {
      final context = await pumpContext(tester);

      expect(
        localizedDeleteFailureMessage(
          context,
          DeleteResult.createSuccess(
            'delete-event-id',
            acceptance: DeleteAcceptance.someRelays,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('localizedOwnerVideoDeleteSuccessMessage', () {
    testWidgets('maps every cleanup outcome to user-facing copy', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        localizedOwnerVideoDeleteSuccessMessage(
          context,
          const OwnerVideoOperationState(
            deleteStatus: OwnerVideoDeleteStatus.success,
            cleanupStatus: OwnerVideoCleanupStatus.confirmed,
          ),
        ),
        l10n.shareMenuDeleteCleanupConfirmed,
      );
      expect(
        localizedOwnerVideoDeleteSuccessMessage(
          context,
          const OwnerVideoOperationState(
            deleteStatus: OwnerVideoDeleteStatus.success,
            cleanupStatus: OwnerVideoCleanupStatus.delayed,
          ),
        ),
        l10n.shareMenuDeleteCleanupDelayed,
      );
      expect(
        localizedOwnerVideoDeleteSuccessMessage(
          context,
          const OwnerVideoOperationState(
            deleteStatus: OwnerVideoDeleteStatus.success,
            cleanupStatus: OwnerVideoCleanupStatus.failed,
          ),
        ),
        l10n.shareMenuDeleteCleanupFailed,
      );
      expect(
        localizedOwnerVideoDeleteSuccessMessage(
          context,
          const OwnerVideoOperationState(
            deleteStatus: OwnerVideoDeleteStatus.success,
            cleanupStatus: OwnerVideoCleanupStatus.unavailable,
          ),
        ),
        l10n.shareMenuDeleteCleanupConfirmed,
      );
      expect(
        localizedOwnerVideoDeleteSuccessMessage(
          context,
          const OwnerVideoOperationState(
            deleteStatus: OwnerVideoDeleteStatus.success,
            cleanupStatus: OwnerVideoCleanupStatus.inProgress,
          ),
        ),
        l10n.shareMenuDeleteCleanupInProgress,
      );
    });
  });
}
