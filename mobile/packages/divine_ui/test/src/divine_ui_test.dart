import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('VineTheme', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Prevent GoogleFonts from trying to fetch fonts at runtime
      GoogleFonts.config.allowRuntimeFetching = false;
    });
    group('colors', () {
      test('has correct vineGreen color', () {
        expect(VineTheme.vineGreen, const Color(0xFF27C58B));
      });

      test('has correct vineGreenDark color', () {
        expect(VineTheme.vineGreenDark, const Color(0xFF009A72));
      });

      test('has correct vineGreenLight color', () {
        expect(VineTheme.vineGreenLight, const Color(0xFFD0FBCB));
      });

      test('has correct backgroundColor', () {
        expect(VineTheme.backgroundColor, const Color(0xFF000000));
      });

      test('has correct cardBackground', () {
        expect(VineTheme.cardBackground, const Color(0xFF1A1A1A));
      });

      test('has correct surface colors', () {
        expect(VineTheme.surfaceBackground, const Color(0xFF00150D));
        expect(VineTheme.onSurface, const Color(0xF2FFFFFF));
        expect(VineTheme.onSurfaceMuted, const Color(0x80FFFFFF));
      });

      test('has correct navigation colors', () {
        expect(VineTheme.primary, const Color(0xFF27C58B));
        expect(VineTheme.navGreen, const Color(0xFF00150D));
        expect(VineTheme.iconButtonBackground, const Color(0xFF032017));
        expect(VineTheme.tabIconInactive, const Color(0xFF40504A));
        expect(VineTheme.tabIndicatorGreen, const Color(0xFF27C58B));
        expect(VineTheme.cameraButtonGreen, const Color(0xFF00B386));
      });

      test('has correct text colors', () {
        expect(VineTheme.primaryText, const Color(0xFFFFFFFF));
        expect(VineTheme.secondaryText, const Color(0xFFBBBBBB));
        expect(VineTheme.lightText, const Color(0xFF888888));
        expect(VineTheme.whiteText, Colors.white);
      });

      test('has correct accent colors', () {
        expect(VineTheme.likeRed, const Color(0xFFE53E3E));
        expect(VineTheme.commentBlue, const Color(0xFF3182CE));
      });

      test('has correct utility colors', () {
        expect(VineTheme.darkOverlay, const Color(0x88000000));
        expect(VineTheme.scrim30, const Color(0x4D000000));
        expect(VineTheme.shadow25, const Color(0x40000000));
        expect(VineTheme.alphaLight25, const Color(0x40FFFFFF));
        expect(VineTheme.outlineVariant, const Color(0xFF254136));
        expect(VineTheme.borderWhite25, const Color(0x40FFFFFF));
        expect(VineTheme.outlineDisabled, const Color(0xFF001A12));
        expect(VineTheme.containerLow, const Color(0xFF0E2B21));
        expect(VineTheme.surfaceContainer, const Color(0xFF032017));
        expect(VineTheme.surfaceContainerHigh, const Color(0xFF000A06));
      });
    });

    group('VineThemeColors', () {
      // Every semantic token, so adding a field to the palette without
      // wiring it through copyWith/lerp/== fails here instead of silently
      // staying dark in light mode.
      final tokens = <String, Color Function(VineThemeColors)>{
        'background': (c) => c.background,
        'card': (c) => c.card,
        'mediaCard': (c) => c.mediaCard,
        'surface': (c) => c.surface,
        'surfaceContainer': (c) => c.surfaceContainer,
        'surfaceContainerHigh': (c) => c.surfaceContainerHigh,
        'containerLow': (c) => c.containerLow,
        'primaryContainer': (c) => c.primaryContainer,
        'nav': (c) => c.nav,
        'onNav': (c) => c.onNav,
        'onNavMuted': (c) => c.onNavMuted,
        'iconButton': (c) => c.iconButton,
        'onIconButton': (c) => c.onIconButton,
        'ghostFill': (c) => c.ghostFill,
        'primaryText': (c) => c.primaryText,
        'secondaryText': (c) => c.secondaryText,
        'mutedText': (c) => c.mutedText,
        'onSurface': (c) => c.onSurface,
        'onSurfaceVariant': (c) => c.onSurfaceVariant,
        'onSurfaceMuted': (c) => c.onSurfaceMuted,
        'outline': (c) => c.outline,
        'outlineMuted': (c) => c.outlineMuted,
        'outlineDisabled': (c) => c.outlineDisabled,
        'disabled': (c) => c.disabled,
        'skeleton': (c) => c.skeleton,
        'errorContainer': (c) => c.errorContainer,
        'onErrorContainer': (c) => c.onErrorContainer,
        'accentPositive': (c) => c.accentPositive,
        'accentWarning': (c) => c.accentWarning,
        'accentBrand': (c) => c.accentBrand,
        'controlSelectedFill': (c) => c.controlSelectedFill,
        'controlFill': (c) => c.controlFill,
        'controlOutline': (c) => c.controlOutline,
        'inverseSurface': (c) => c.inverseSurface,
        'inverseOnSurface': (c) => c.inverseOnSurface,
        'mediaChrome': (c) => c.mediaChrome,
        'mediaChromeForeground': (c) => c.mediaChromeForeground,
      };

      // Accent chips are pairs, not flat colors, so they cannot live in
      // `tokens`. Same purpose: a new chip that skips copyWith/lerp/== fails
      // here rather than silently staying dark on a light page.
      final chipTokens = <String, VineAccentChip Function(VineThemeColors)>{
        'accentChipOrange': (c) => c.accentChipOrange,
        'accentChipYellow': (c) => c.accentChipYellow,
        'accentChipBlue': (c) => c.accentChipBlue,
        'accentChipLime': (c) => c.accentChipLime,
        'accentChipPink': (c) => c.accentChipPink,
        'accentChipViolet': (c) => c.accentChipViolet,
        'accentChipGreen': (c) => c.accentChipGreen,
      };

      VineThemeColors paint(Color color) => VineThemeColors(
        background: color,
        card: color,
        mediaCard: color,
        surface: color,
        surfaceContainer: color,
        surfaceContainerHigh: color,
        containerLow: color,
        primaryContainer: color,
        nav: color,
        onNav: color,
        onNavMuted: color,
        iconButton: color,
        onIconButton: color,
        ghostFill: color,
        primaryText: color,
        secondaryText: color,
        mutedText: color,
        onSurface: color,
        onSurfaceVariant: color,
        onSurfaceMuted: color,
        outline: color,
        outlineMuted: color,
        outlineDisabled: color,
        disabled: color,
        skeleton: color,
        errorContainer: color,
        onErrorContainer: color,
        accentPositive: color,
        accentWarning: color,
        accentBrand: color,
        controlSelectedFill: color,
        controlFill: color,
        controlOutline: color,
        accentChipOrange: VineAccentChip(container: color, onContainer: color),
        accentChipYellow: VineAccentChip(container: color, onContainer: color),
        accentChipBlue: VineAccentChip(container: color, onContainer: color),
        accentChipLime: VineAccentChip(container: color, onContainer: color),
        accentChipPink: VineAccentChip(container: color, onContainer: color),
        accentChipViolet: VineAccentChip(container: color, onContainer: color),
        accentChipGreen: VineAccentChip(container: color, onContainer: color),
        inverseSurface: color,
        inverseOnSurface: color,
        mediaChrome: color,
        mediaChromeForeground: color,
      );

      test('copyWith replaces each semantic color', () {
        final copied = VineTheme.darkColors.copyWith(
          background: const Color(0xFF000001),
          card: const Color(0xFF000002),
          surface: const Color(0xFF000003),
          surfaceContainer: const Color(0xFF000004),
          surfaceContainerHigh: const Color(0xFF000005),
          containerLow: const Color(0xFF000011),
          nav: const Color(0xFF000006),
          iconButton: const Color(0xFF000007),
          onIconButton: const Color(0xFF00001C),
          ghostFill: const Color(0xFF00001F),
          primaryText: const Color(0xFF000008),
          secondaryText: const Color(0xFF000009),
          mutedText: const Color(0xFF00000A),
          onSurface: const Color(0xFF00000B),
          onSurfaceVariant: const Color(0xFF00000C),
          onSurfaceMuted: const Color(0xFF000012),
          outline: const Color(0xFF00000D),
          outlineMuted: const Color(0xFF000013),
          outlineDisabled: const Color(0xFF000014),
          disabled: const Color(0xFF00000E),
          skeleton: const Color(0xFF000015),
          errorContainer: const Color(0xFF000016),
          onErrorContainer: const Color(0xFF000017),
          accentPositive: const Color(0xFF00001A),
          accentWarning: const Color(0xFF00001B),
          accentBrand: const Color(0xFF000020),
          controlSelectedFill: const Color(0xFF000021),
          controlFill: const Color(0xFF000022),
          controlOutline: const Color(0xFF000023),
          accentChipOrange: const VineAccentChip(
            container: Color(0xFF00001D),
            onContainer: Color(0xFF00001E),
          ),
          inverseSurface: const Color(0xFF000018),
          inverseOnSurface: const Color(0xFF000019),
          mediaChrome: const Color(0xFF00000F),
          mediaChromeForeground: const Color(0xFF000010),
        );

        expect(copied.background, const Color(0xFF000001));
        expect(copied.card, const Color(0xFF000002));
        expect(copied.surface, const Color(0xFF000003));
        expect(copied.surfaceContainer, const Color(0xFF000004));
        expect(copied.surfaceContainerHigh, const Color(0xFF000005));
        expect(copied.containerLow, const Color(0xFF000011));
        expect(copied.nav, const Color(0xFF000006));
        expect(copied.iconButton, const Color(0xFF000007));
        expect(copied.onIconButton, const Color(0xFF00001C));
        expect(copied.ghostFill, const Color(0xFF00001F));
        expect(copied.primaryText, const Color(0xFF000008));
        expect(copied.secondaryText, const Color(0xFF000009));
        expect(copied.mutedText, const Color(0xFF00000A));
        expect(copied.onSurface, const Color(0xFF00000B));
        expect(copied.onSurfaceVariant, const Color(0xFF00000C));
        expect(copied.onSurfaceMuted, const Color(0xFF000012));
        expect(copied.outline, const Color(0xFF00000D));
        expect(copied.outlineMuted, const Color(0xFF000013));
        expect(copied.outlineDisabled, const Color(0xFF000014));
        expect(copied.disabled, const Color(0xFF00000E));
        expect(copied.skeleton, const Color(0xFF000015));
        expect(copied.errorContainer, const Color(0xFF000016));
        expect(copied.onErrorContainer, const Color(0xFF000017));
        expect(copied.accentPositive, const Color(0xFF00001A));
        expect(copied.accentWarning, const Color(0xFF00001B));
        expect(copied.accentBrand, const Color(0xFF000020));
        expect(copied.controlSelectedFill, const Color(0xFF000021));
        expect(copied.controlFill, const Color(0xFF000022));
        expect(copied.controlOutline, const Color(0xFF000023));
        expect(
          copied.accentChipOrange,
          const VineAccentChip(
            container: Color(0xFF00001D),
            onContainer: Color(0xFF00001E),
          ),
        );
        expect(copied.inverseSurface, const Color(0xFF000018));
        expect(copied.inverseOnSurface, const Color(0xFF000019));
        expect(copied.mediaChrome, const Color(0xFF00000F));
        expect(copied.mediaChromeForeground, const Color(0xFF000010));
      });

      test(
        'copyWith keeps existing colors when no replacements are supplied',
        () {
          expect(VineTheme.darkColors.copyWith(), VineTheme.darkColors);
        },
      );

      test('lerp interpolates each semantic color', () {
        final midpoint = paint(Colors.black).lerp(paint(Colors.white), 0.5);
        final expected = Color.lerp(Colors.black, Colors.white, 0.5);

        for (final token in tokens.entries) {
          expect(token.value(midpoint), expected, reason: token.key);
        }
        for (final chip in chipTokens.entries) {
          expect(chip.value(midpoint).container, expected, reason: chip.key);
          expect(chip.value(midpoint).onContainer, expected, reason: chip.key);
        }
      });

      test('lerp returns this when the other palette is null', () {
        expect(VineTheme.darkColors.lerp(null, 0.5), VineTheme.darkColors);
      });

      test('uses value equality and hashCode', () {
        final copy = VineTheme.darkColors.copyWith();

        expect(copy, VineTheme.darkColors);
        expect(copy.hashCode, VineTheme.darkColors.hashCode);
        expect(copy, isNot(VineTheme.lightColors));
      });

      test('every token differs between the light and dark palettes', () {
        for (final token in tokens.entries) {
          expect(
            token.value(VineTheme.lightColors),
            isNot(token.value(VineTheme.darkColors)),
            reason: '${token.key} is identical in both palettes',
          );
        }
      });

      test('mediaCard keeps neutral10 on the dark palette', () {
        // The chat bubble frame and the classic recorder's progress track
        // both had this exact value before the light-mode migration.
        expect(VineTheme.darkColors.mediaCard, VineTheme.neutral10);
      });

      test('mediaCard stays distinct from the surfaces it sits on', () {
        // Drawn on `surface` (chat) and `surfaceContainerHigh` (recorder);
        // matching either makes the element vanish, which is how the light
        // progress track disappeared when mediaCard shared #E7E4E1 with
        // surfaceContainerHigh.
        for (final colors in [VineTheme.darkColors, VineTheme.lightColors]) {
          expect(colors.mediaCard, isNot(colors.surface));
          expect(colors.mediaCard, isNot(colors.surfaceContainerHigh));
        }
      });

      test('a single changed token breaks equality', () {
        for (final token in tokens.keys) {
          final changed = paint(Colors.black).copyWith(
            background: token == 'background' ? Colors.white : null,
            card: token == 'card' ? Colors.white : null,
            mediaCard: token == 'mediaCard' ? Colors.white : null,
            surface: token == 'surface' ? Colors.white : null,
            surfaceContainer: token == 'surfaceContainer' ? Colors.white : null,
            surfaceContainerHigh: token == 'surfaceContainerHigh'
                ? Colors.white
                : null,
            containerLow: token == 'containerLow' ? Colors.white : null,
            primaryContainer: token == 'primaryContainer' ? Colors.white : null,
            nav: token == 'nav' ? Colors.white : null,
            onNav: token == 'onNav' ? Colors.white : null,
            onNavMuted: token == 'onNavMuted' ? Colors.white : null,
            iconButton: token == 'iconButton' ? Colors.white : null,
            onIconButton: token == 'onIconButton' ? Colors.white : null,
            ghostFill: token == 'ghostFill' ? Colors.white : null,
            primaryText: token == 'primaryText' ? Colors.white : null,
            secondaryText: token == 'secondaryText' ? Colors.white : null,
            mutedText: token == 'mutedText' ? Colors.white : null,
            onSurface: token == 'onSurface' ? Colors.white : null,
            onSurfaceVariant: token == 'onSurfaceVariant' ? Colors.white : null,
            onSurfaceMuted: token == 'onSurfaceMuted' ? Colors.white : null,
            outline: token == 'outline' ? Colors.white : null,
            outlineMuted: token == 'outlineMuted' ? Colors.white : null,
            outlineDisabled: token == 'outlineDisabled' ? Colors.white : null,
            disabled: token == 'disabled' ? Colors.white : null,
            skeleton: token == 'skeleton' ? Colors.white : null,
            errorContainer: token == 'errorContainer' ? Colors.white : null,
            onErrorContainer: token == 'onErrorContainer' ? Colors.white : null,
            accentPositive: token == 'accentPositive' ? Colors.white : null,
            accentWarning: token == 'accentWarning' ? Colors.white : null,
            accentBrand: token == 'accentBrand' ? Colors.white : null,
            controlSelectedFill: token == 'controlSelectedFill'
                ? Colors.white
                : null,
            controlFill: token == 'controlFill' ? Colors.white : null,
            controlOutline: token == 'controlOutline' ? Colors.white : null,
            inverseSurface: token == 'inverseSurface' ? Colors.white : null,
            inverseOnSurface: token == 'inverseOnSurface' ? Colors.white : null,
            mediaChrome: token == 'mediaChrome' ? Colors.white : null,
            mediaChromeForeground: token == 'mediaChromeForeground'
                ? Colors.white
                : null,
          );

          expect(changed, isNot(paint(Colors.black)), reason: token);
        }

        const white = VineAccentChip(
          container: Colors.white,
          onContainer: Colors.white,
        );
        for (final chip in chipTokens.keys) {
          final changed = paint(Colors.black).copyWith(
            accentChipOrange: chip == 'accentChipOrange' ? white : null,
            accentChipYellow: chip == 'accentChipYellow' ? white : null,
            accentChipBlue: chip == 'accentChipBlue' ? white : null,
            accentChipLime: chip == 'accentChipLime' ? white : null,
            accentChipPink: chip == 'accentChipPink' ? white : null,
            accentChipViolet: chip == 'accentChipViolet' ? white : null,
            accentChipGreen: chip == 'accentChipGreen' ? white : null,
          );

          expect(changed, isNot(paint(Colors.black)), reason: chip);
        }
      });
    });

    group('context.vineColors', () {
      setUp(() => VineThemeColors.debugFallbackCount = 0);
      tearDown(() => VineThemeColors.debugFallbackCount = 0);

      testWidgets('resolves the palette of the active theme', (tester) async {
        late VineThemeColors light;
        late VineThemeColors dark;

        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.lightTheme,
            home: Builder(
              builder: (context) {
                light = context.vineColors;
                return Theme(
                  data: VineTheme.theme,
                  child: Builder(
                    builder: (context) {
                      dark = context.vineColors;
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        );

        expect(light, VineTheme.lightColors);
        expect(dark, VineTheme.darkColors);
        expect(VineThemeColors.debugFallbackCount, 0);
      });

      testWidgets('falls back to the dark palette without the extension', (
        tester,
      ) async {
        late VineThemeColors colors;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                colors = context.vineColors;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(colors, VineTheme.darkColors);
        expect(
          VineThemeColors.debugFallbackCount,
          1,
          reason: 'A themeless resolution has to be observable in debug.',
        );
      });

      testWidgets('survives routes pushed over the light theme', (
        tester,
      ) async {
        // The realistic production leak: a route or dialog builds its subtree
        // from a fresh ThemeData, the extension is gone, and every widget in
        // it renders dark tokens on a light page with nothing to detect it.
        late VineThemeColors dialogColors;
        late VineThemeColors sheetColors;

        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) {
                          dialogColors = context.vineColors;
                          return const SizedBox.shrink();
                        },
                      ),
                      child: const Text('dialog'),
                    ),
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (context) {
                          sheetColors = context.vineColors;
                          return const SizedBox.shrink();
                        },
                      ),
                      child: const Text('sheet'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('dialog'));
        await tester.pumpAndSettle();
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('sheet'));
        await tester.pumpAndSettle();

        expect(dialogColors, VineTheme.lightColors);
        expect(sheetColors, VineTheme.lightColors);
        expect(
          VineThemeColors.debugFallbackCount,
          0,
          reason: 'Overlay routes must keep the light palette.',
        );
      });
    });

    group('typography - display fonts', () {
      testWidgets('displayLargeFont returns correct style', (tester) async {
        final style = VineTheme.displayLargeFont();
        expect(style.fontSize, 57);
        expect(style.fontWeight, FontWeight.w700);
      });

      testWidgets('displayMediumFont returns correct style', (tester) async {
        final style = VineTheme.displayMediumFont();
        expect(style.fontSize, 45);
        expect(style.fontWeight, FontWeight.w700);
      });

      testWidgets('displaySmallFont returns correct style', (tester) async {
        final style = VineTheme.displaySmallFont();
        expect(style.fontSize, 36);
        expect(style.fontWeight, FontWeight.w700);
      });
    });

    group('typography - headline fonts', () {
      testWidgets('headlineLargeFont returns correct style', (tester) async {
        final style = VineTheme.headlineLargeFont();
        expect(style.fontSize, 32);
        expect(style.fontWeight, FontWeight.w700);
      });

      testWidgets('headlineMediumFont returns correct style', (tester) async {
        final style = VineTheme.headlineMediumFont();
        expect(style.fontSize, 28);
        expect(style.fontWeight, FontWeight.w700);
      });

      testWidgets('headlineSmallFont returns correct style', (tester) async {
        final style = VineTheme.headlineSmallFont();
        expect(style.fontSize, 24);
        expect(style.fontWeight, FontWeight.w700);
      });
    });

    group('typography - title fonts', () {
      testWidgets('titleLargeFont returns correct style', (tester) async {
        final style = VineTheme.titleLargeFont();
        expect(style.fontSize, 22);
        expect(style.fontWeight, FontWeight.w800);
      });

      testWidgets('titleMediumFont returns correct style', (tester) async {
        final style = VineTheme.titleMediumFont();
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w800);
      });

      testWidgets('titleSmallFont returns correct style', (tester) async {
        final style = VineTheme.titleSmallFont();
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w800);
      });

      testWidgets('titleTinyFont returns correct style', (tester) async {
        final style = VineTheme.titleTinyFont();
        expect(style.fontSize, 12);
        expect(style.fontWeight, FontWeight.w800);
        expect(style.letterSpacing, 0.1);
      });

      testWidgets('statNumberFont returns correct style', (tester) async {
        final style = VineTheme.statNumberFont();
        expect(style.fontSize, 20);
        expect(style.fontWeight, FontWeight.w800);
        expect(style.height, 28 / 20);
        expect(style.letterSpacing, 0);
      });
    });

    group('typography - body fonts', () {
      testWidgets('bodyLargeFont returns correct style', (tester) async {
        final style = VineTheme.bodyLargeFont();
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w400);
      });

      testWidgets('bodyMediumFont returns correct style', (tester) async {
        final style = VineTheme.bodyMediumFont();
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w400);
      });

      testWidgets('bodySmallFont returns correct style', (tester) async {
        final style = VineTheme.bodySmallFont();
        expect(style.fontSize, 12);
        expect(style.fontWeight, FontWeight.w400);
      });

      testWidgets('bodyTinyFont returns correct style', (tester) async {
        final style = VineTheme.bodyTinyFont();
        expect(style.fontSize, 10);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.height, 14 / 10);
        expect(style.letterSpacing, 0.4);
      });

      testWidgets('bodyTinyFont is the smallest body size', (tester) async {
        expect(
          VineTheme.bodyTinyFont().fontSize,
          lessThan(VineTheme.bodySmallFont().fontSize!),
        );
      });
    });

    group('typography - label fonts', () {
      testWidgets('labelLargeFont returns correct style', (tester) async {
        final style = VineTheme.labelLargeFont();
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w600);
      });

      testWidgets('labelMediumFont returns correct style', (tester) async {
        final style = VineTheme.labelMediumFont();
        expect(style.fontSize, 12);
        expect(style.fontWeight, FontWeight.w600);
      });

      testWidgets('captionPillFont returns Chivo Mono 300 16/24/0.5', (
        tester,
      ) async {
        final style = VineTheme.captionPillFont();
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w300);
        expect(style.height, 24 / 16);
        expect(style.letterSpacing, 0.5);
        expect(style.color, isNull);
      });

      testWidgets('captionPillFont accepts a color override', (tester) async {
        final style = VineTheme.captionPillFont(color: VineTheme.vineGreen);
        expect(style.color, VineTheme.vineGreen);
      });

      testWidgets('codeFont returns Chivo Mono 300 13/20/0.25', (tester) async {
        final style = VineTheme.codeFont();
        expect(style.fontSize, 13);
        expect(style.fontWeight, FontWeight.w300);
        expect(style.height, 20 / 13);
        expect(style.letterSpacing, 0.25);
        expect(style.color, isNull);
      });

      testWidgets('codeFont accepts a color override', (tester) async {
        final style = VineTheme.codeFont(color: VineTheme.vineGreen);
        expect(style.color, VineTheme.vineGreen);
      });

      testWidgets('labelSmallFont returns correct style', (tester) async {
        final style = VineTheme.labelSmallFont();
        expect(style.fontSize, 11);
        expect(style.fontWeight, FontWeight.w600);
      });
    });

    group('tabTextStyle', () {
      testWidgets('leaves the color to the ambient text style', (tester) async {
        final style = VineTheme.tabTextStyle();

        expect(style.fontSize, 18);
        expect(style.fontWeight, FontWeight.w800);
        expect(style.height, 24 / 18);
        expect(style.color, isNull);
      });

      testWidgets('returns TextStyle with custom color', (tester) async {
        final style = VineTheme.tabTextStyle(color: Colors.green);

        expect(style.color, Colors.green);
      });
    });

    group('buttonBoxShadowsFor', () {
      test('keeps the Figma emboss pair on the dark palette', () {
        expect(
          VineTheme.buttonBoxShadowsFor(VineTheme.darkColors),
          VineTheme.buttonBoxShadows,
        );
      });

      test('goes flat on the light palette', () {
        // The buttons paint their decoration through `Ink`, and Material
        // hard-clips ink features to its own bounds, so an outward drop
        // shadow is cut off at the button edge and reads as a hard line.
        // Light-mode fills separate themselves without one.
        expect(VineTheme.buttonBoxShadowsFor(VineTheme.lightColors), isNull);
      });
    });

    group('theme', () {
      test('returns the same instance across accesses', () {
        // Referential stability keeps MaterialApp's internal AnimatedTheme
        // from re-running ThemeData.lerp on every rebuild above it. Reverting
        // `theme` to a getter would break this and reintroduce the lerp
        // cascade, so pin the identity here.
        expect(identical(VineTheme.theme, VineTheme.theme), isTrue);
      });

      test('returns ThemeData with dark brightness', () {
        final theme = VineTheme.theme;

        expect(theme.brightness, Brightness.dark);
      });

      test('provides a stable light theme with semantic colors', () {
        final theme = VineTheme.lightTheme;
        final colors = theme.extension<VineThemeColors>();

        expect(theme.brightness, Brightness.light);
        expect(theme.scaffoldBackgroundColor, VineTheme.lightColors.background);
        expect(colors, VineTheme.lightColors);
        expect(colors?.primaryText, const Color(0xFF07241B));
      });

      test('flips status-bar icons to dark over the light app bar', () {
        expect(
          VineTheme.lightTheme.appBarTheme.systemOverlayStyle,
          VineTheme.lightStatusBarStyle,
        );
        expect(
          VineTheme.lightTheme.appBarTheme.backgroundColor,
          VineTheme.lightColors.nav,
        );
        expect(
          VineTheme.lightTheme.appBarTheme.foregroundColor,
          VineTheme.lightColors.onNav,
        );
      });

      test('keeps light status-bar icons over the dark app bar', () {
        expect(
          VineTheme.theme.appBarTheme.systemOverlayStyle,
          VineTheme.statusBarStyle,
        );
      });

      test('returns ThemeData with correct primaryColor', () {
        final theme = VineTheme.theme;

        expect(theme.primaryColor, VineTheme.vineGreen);
      });

      test('returns ThemeData with correct scaffoldBackgroundColor', () {
        final theme = VineTheme.theme;

        expect(theme.scaffoldBackgroundColor, VineTheme.backgroundColor);
      });

      test('returns ThemeData with correct appBarTheme', () {
        final theme = VineTheme.theme;

        expect(theme.appBarTheme.backgroundColor, VineTheme.darkColors.nav);
        expect(theme.appBarTheme.foregroundColor, VineTheme.darkColors.onNav);
        expect(theme.appBarTheme.elevation, 1);
        expect(theme.appBarTheme.centerTitle, true);
      });

      test('returns ThemeData with correct textTheme', () {
        final theme = VineTheme.theme;

        expect(theme.textTheme.displayLarge?.color, VineTheme.primaryText);
        expect(theme.textTheme.displayLarge?.fontSize, 24);
        expect(theme.textTheme.titleLarge?.color, VineTheme.primaryText);
        expect(theme.textTheme.bodyLarge?.color, VineTheme.primaryText);
        expect(theme.textTheme.bodyMedium?.color, VineTheme.secondaryText);
        expect(theme.textTheme.bodySmall?.color, VineTheme.lightText);
      });

      test('returns ThemeData with correct cardTheme', () {
        final theme = VineTheme.theme;

        expect(theme.cardTheme.color, VineTheme.cardBackground);
        expect(theme.cardTheme.elevation, 2);
      });

      test('returns ThemeData with correct elevatedButtonTheme', () {
        final theme = VineTheme.theme;
        final buttonStyle = theme.elevatedButtonTheme.style;

        expect(buttonStyle, isNotNull);
      });
    });
  });
}
