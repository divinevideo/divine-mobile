// ABOUTME: Widget tests for the edit-profile form's non-editable cards.
// ABOUTME: Covers the select row's two states and what each announces.

import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(body: child),
      ),
    );
  }

  group(ProfileSelectRow, () {
    testWidgets('shows the label alone as a placeholder', (tester) async {
      await pump(
        tester,
        ProfileSelectRow(label: 'Banner color', onTap: () {}),
      );

      expect(find.text('Banner color'), findsOneWidget);
    });

    testWidgets('lifts the label into a caption above the value', (
      tester,
    ) async {
      await pump(
        tester,
        ProfileSelectRow(
          label: 'Banner color',
          value: 'Lime',
          onTap: () {},
        ),
      );

      expect(find.text('Banner color'), findsOneWidget);
      expect(find.text('Lime'), findsOneWidget);
    });

    testWidgets('announces the selection alongside the label', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        ProfileSelectRow(
          label: 'Banner color',
          value: 'Lime',
          onTap: () {},
        ),
      );

      // The card excludes its own subtree from semantics, so a value left off
      // the node is silent — the reason this assertion exists.
      final node = tester.getSemantics(find.byType(ProfileSelectRow));
      expect(node.label, 'Banner color');
      expect(node.value, 'Lime');

      handle.dispose();
    });

    testWidgets('announces no value when nothing is selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        ProfileSelectRow(label: 'Banner color', onTap: () {}),
      );

      final node = tester.getSemantics(find.byType(ProfileSelectRow));
      expect(node.label, 'Banner color');
      expect(node.value, isEmpty);

      handle.dispose();
    });

    testWidgets('a null onTap disables the row', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const ProfileSelectRow(label: 'Soon', onTap: null));

      final node = tester.getSemantics(find.byType(ProfileSelectRow));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);

      handle.dispose();
    });

    testWidgets('taps call back', (tester) async {
      var taps = 0;
      await pump(
        tester,
        ProfileSelectRow(label: 'Banner color', onTap: () => taps++),
      );

      await tester.tap(find.byType(ProfileSelectRow));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a screen reader can activate the row', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pump(
        tester,
        ProfileSelectRow(label: 'Banner color', onTap: () => taps++),
      );

      // The card excludes its own subtree, which drops the ink well's tap
      // action — so the announcing node has to carry one itself or the row is
      // a button VoiceOver/TalkBack cannot press.
      final node = tester.getSemantics(find.byType(ProfileSelectRow));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      tester.semantics.tap(find.semantics.byLabel('Banner color'));
      await tester.pump();

      expect(taps, 1);
      handle.dispose();
    });
  });

  group(ProfileValueRow, () {
    testWidgets('keeps the whole value rather than shortening it', (
      tester,
    ) async {
      const npub =
          'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';
      await pump(
        tester,
        const ProfileValueRow(
          label: 'Public key (npub)',
          value: npub,
          trailing: SizedBox.shrink(),
        ),
      );

      expect(find.text(npub), findsOneWidget);
    });
  });
}
