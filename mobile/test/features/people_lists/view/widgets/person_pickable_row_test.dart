// ABOUTME: Widget tests for PersonPickableRow tap-to-select affordance.
// ABOUTME: Covers enabled/disabled states, checkbox rendering, and tap wiring.

import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/features/people_lists/view/widgets/person_pickable_row.dart';
import 'package:openvine/l10n/l10n.dart';

// Full-length Nostr pubkeys — never truncate anywhere in this file.
const String _pubkey =
    'abababababababababababababababababababababababababababababababab';

void main() {
  group(PersonPickableRow, () {
    Widget buildSubject({
      required bool isSelected,
      required bool enabled,
      VoidCallback? onTap,
      String? displayName = 'Ada Lovelace',
      String? handle = '@ada',
      int? videoCount,
      DateTime? lastPostedAt,
      bool isFollowing = false,
      bool isFollower = false,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PersonPickableRow(
            videoCount: videoCount,
            lastPostedAt: lastPostedAt,
            candidate: PeopleListCandidate(
              pubkey: _pubkey,
              displayName: displayName,
              handle: handle,
              isFollowing: isFollowing,
              isFollower: isFollower,
            ),
            isSelected: isSelected,
            enabled: enabled,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    testWidgets(
      'renders relationship, count and recent post from supplied facts',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            isSelected: false,
            enabled: true,
            isFollowing: true,
            isFollower: true,
            videoCount: 18,
            lastPostedAt: clock.now().subtract(const Duration(hours: 2)),
          ),
        );
        expect(
          find.text(
            '${l10n.socialProofMutual} · @ada · ${l10n.searchUserVideoCount(18, '18')} · '
            '${l10n.userRowPosted(l10n.timeAgo(l10n.timeShortHours(2)))}',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('missing handle leaves activity visible in a narrow row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        buildSubject(
          isSelected: false,
          enabled: true,
          handle: null,
          videoCount: 18,
          lastPostedAt: clock.now().subtract(const Duration(hours: 2)),
        ),
      );
      final activity = find.text(
        '${l10n.searchUserVideoCount(18, '18')} · '
        '${l10n.userRowPosted(l10n.timeAgo(l10n.timeShortHours(2)))}',
      );
      expect(activity, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(activity).didExceedMaxLines,
        isFalse,
      );
      expect(find.textContaining(_pubkey), findsNothing);
    });

    testWidgets('renders display name and handle', (tester) async {
      await tester.pumpWidget(
        buildSubject(isSelected: false, enabled: true),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('@ada'), findsOneWidget);
    });

    testWidgets(
      'checkbox is unselected when enabled and not selected',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(isSelected: false, enabled: true),
        );

        final checkbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(checkbox.state, equals(DivineCheckboxState.unselected));
      },
    );

    testWidgets(
      'checkbox is selected when enabled and selected',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(isSelected: true, enabled: true),
        );

        final checkbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(checkbox.state, equals(DivineCheckboxState.selected));
      },
    );

    testWidgets(
      'checkbox renders disabled sprite state when enabled is false',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(isSelected: true, enabled: false),
        );

        final checkbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(checkbox.state, equals(DivineCheckboxState.disabled));
      },
    );

    testWidgets(
      'tapping the row calls onTap when enabled',
      (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          buildSubject(
            isSelected: false,
            enabled: true,
            onTap: () => tapped++,
          ),
        );

        await tester.tap(find.byType(PersonPickableRow));
        await tester.pump();

        expect(tapped, equals(1));
      },
    );

    testWidgets(
      'tapping the row does nothing when disabled',
      (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          buildSubject(
            isSelected: true,
            enabled: false,
            onTap: () => tapped++,
          ),
        );

        await tester.tap(find.byType(PersonPickableRow));
        await tester.pump();

        expect(tapped, equals(0));
      },
    );

    testWidgets(
      'preserves full pubkey in semantic identifier',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(isSelected: false, enabled: true),
        );

        // The pubkey appears untruncated somewhere in the row semantics so
        // integration tests and screen readers can target specific rows.
        final semantics = find.bySemanticsIdentifier(
          'person_pickable_row_$_pubkey',
        );
        expect(semantics, findsOneWidget);
      },
    );

    testWidgets(
      'falls back to pubkey-derived display name when candidate has none',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            isSelected: false,
            enabled: true,
            displayName: null,
            handle: null,
          ),
        );

        expect(find.byType(PersonPickableRow), findsOneWidget);
        expect(
          find.text(UserProfile.defaultDisplayNameFor(_pubkey)),
          findsOneWidget,
        );
        expect(find.text(_pubkey), findsNothing);
      },
    );
  });
}
