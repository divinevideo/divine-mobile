// ABOUTME: Widget tests for the banner colour picker sheet.
// ABOUTME: Covers the palette, the "no colour" swatch, the selection marker,
// ABOUTME: and the back button that returns to the sheet it came from.

import 'dart:ui' show Tristate;

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/banner_color_swatches.dart';

import '../../helpers/finders.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('showBannerColorSheet', () {
    late _MockProfileEditorBloc bloc;

    setUp(() {
      bloc = _MockProfileEditorBloc();
      when(() => bloc.state).thenReturn(const ProfileEditorState());
    });

    /// Pumps a host screen and opens the sheet.
    ///
    /// Returns a holder rather than the result itself: the sheet is still open
    /// when this returns, so its value only lands after the pop settles. Read
    /// the holder then, not at the call site.
    Future<List<bool?>> openSheet(WidgetTester tester) async {
      final result = <bool?>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<ProfileEditorBloc>.value(
            value: bloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result.add(await showBannerColorSheet(context, bloc));
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    Finder swatchOf(BannerSwatch swatch) => find.byKey(
      ValueKey('profile_banner_color_swatch_preset_${swatch.index}'),
    );

    testWidgets('renders the title and every swatch in the palette', (
      tester,
    ) async {
      await openSheet(tester);

      expect(
        find.text(l10n.profileSetupBannerColorPickerTitle),
        findsOneWidget,
      );
      for (final swatch in BannerSwatch.values) {
        expect(swatchOf(swatch), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('profile_banner_color_swatch_none')),
        findsOneWidget,
      );
    });

    testWidgets('names the staged colour above the grid', (tester) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(pendingBannerColor: VineTheme.accentPink),
      );
      await openSheet(tester);

      expect(find.text(l10n.profileSetupBannerColorPink), findsOneWidget);
    });

    testWidgets('names the empty selection when no colour is staged', (
      tester,
    ) async {
      await openSheet(tester);

      // Once as the heading, once as the label of the swatch itself.
      expect(find.text(l10n.profileSetupBannerColorNone), findsWidgets);
    });

    testWidgets('tapping a swatch stages that colour and closes the sheet', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(swatchOf(BannerSwatch.orange));
      await tester.pumpAndSettle();

      final captured = verify(() => bloc.add(captureAny())).captured;
      final selected = captured.whereType<ProfileBannerColorSelected>();
      expect(selected, hasLength(1));
      expect(selected.single.color, VineTheme.accentOrange);
      expect(find.text(l10n.profileSetupBannerColorPickerTitle), findsNothing);
    });

    testWidgets('the no-colour swatch clears the banner', (tester) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(pendingBannerColor: VineTheme.accentPink),
      );
      await openSheet(tester);

      await tester.tap(
        find.byKey(const ValueKey('profile_banner_color_swatch_none')),
      );
      await tester.pumpAndSettle();

      final captured = verify(() => bloc.add(captureAny())).captured;
      expect(captured.whereType<ProfileBannerCleared>(), hasLength(1));
    });

    testWidgets('offers a custom-colour swatch alongside the palette', (
      tester,
    ) async {
      await openSheet(tester);

      expect(
        find.byKey(const ValueKey('profile_banner_color_swatch_custom')),
        findsOneWidget,
      );
    });

    testWidgets('a colour outside the palette reads as custom, and marks the '
        'custom swatch', (tester) async {
      when(() => bloc.state).thenReturn(
        // Nothing in BannerSwatch carries this.
        const ProfileEditorState(pendingBannerColor: Color(0xFF123456)),
      );
      await openSheet(tester);

      expect(find.text(l10n.profileSetupBannerColorCustom), findsWidgets);
      final custom = tester.getSemantics(
        find.byKey(const ValueKey('profile_banner_color_swatch_custom')),
      );
      expect(custom.flagsCollection.isSelected, Tristate.isTrue);
      // The empty selection must not also claim it.
      final none = tester.getSemantics(
        find.byKey(const ValueKey('profile_banner_color_swatch_none')),
      );
      expect(none.flagsCollection.isSelected, Tristate.isFalse);
    });

    testWidgets('marks the staged colour as selected, and only it', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(pendingBannerColor: VineTheme.accentViolet),
      );
      await openSheet(tester);

      final selected = tester.getSemantics(swatchOf(BannerSwatch.violet));
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      final other = tester.getSemantics(swatchOf(BannerSwatch.lime));
      expect(other.flagsCollection.isSelected, Tristate.isFalse);
    });

    testWidgets('backing out reports it so the caller can reopen its sheet', (
      tester,
    ) async {
      final result = await openSheet(tester);
      expect(result, isEmpty, reason: 'sheet is still open');

      await tester.tap(findByTooltip(l10n.commonBack));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupBannerColorPickerTitle), findsNothing);
      // The value itself, not just the close: `_openBannerActions` reopens the
      // banner sheet only on `true`, so popping bare turns back into a dead end.
      expect(result, [isTrue]);
    });
  });
}
