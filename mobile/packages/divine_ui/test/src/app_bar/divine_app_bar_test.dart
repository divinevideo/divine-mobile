// MaterialIconSource is deprecated but still fully supported; these tests
// intentionally exercise it to guard that support, not migrate off it.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('DiVineAppBar', () {
    Widget buildTestWidget({
      String? title,
      Widget? titleWidget,
      String? subtitle,
      DiVineAppBarTitleMode titleMode = DiVineAppBarTitleMode.simple,
      VoidCallback? onTitleTap,
      Widget? titleSuffix,
      bool showBackButton = false,
      VoidCallback? onBackPressed,
      Object? backButtonHeroTag,
      bool showMenuButton = false,
      VoidCallback? onMenuPressed,
      IconSource? leadingIcon,
      VoidCallback? onLeadingPressed,
      bool expandLeadingHitArea = false,
      List<DiVineAppBarAction> actions = const [],
      List<Widget> customActions = const [],
      DiVineAppBarBackgroundMode backgroundMode =
          DiVineAppBarBackgroundMode.solid,
      DiVineAppBarGradient? gradient,
      Color? backgroundColor,
      DiVineAppBarStyle? style,
      SystemUiOverlayStyle? systemOverlayStyle,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          appBar: DiVineAppBar(
            title: title,
            titleWidget: titleWidget,
            subtitle: subtitle,
            titleMode: titleMode,
            onTitleTap: onTitleTap,
            titleSuffix: titleSuffix,
            showBackButton: showBackButton,
            onBackPressed: onBackPressed,
            backButtonHeroTag: backButtonHeroTag,
            showMenuButton: showMenuButton,
            onMenuPressed: onMenuPressed,
            leadingIcon: leadingIcon,
            onLeadingPressed: onLeadingPressed,
            expandLeadingHitArea: expandLeadingHitArea,
            actions: actions,
            customActions: customActions,
            backgroundMode: backgroundMode,
            gradient: gradient,
            backgroundColor: backgroundColor,
            style: style,
            systemOverlayStyle: systemOverlayStyle,
          ),
          body: const SizedBox(),
        ),
      );
    }

    group('title', () {
      testWidgets('renders simple title', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Settings'));

        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('renders titleWidget instead of title string', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(titleWidget: const Text('Custom Widget')),
        );

        expect(find.text('Custom Widget'), findsOneWidget);
      });

      testWidgets('renders subtitle when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Title', subtitle: 'Subtitle text'),
        );

        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Subtitle text'), findsOneWidget);
      });

      testWidgets('renders titleSuffix after title', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Test', titleSuffix: const Text('SUFFIX')),
        );

        expect(find.text('Test'), findsOneWidget);
        expect(find.text('SUFFIX'), findsOneWidget);
      });
    });

    group('title modes', () {
      testWidgets('simple mode is not tappable', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(title: 'Test', onTitleTap: () => tapped = true),
        );

        await tester.tap(find.text('Test'));
        expect(tapped, isFalse);
      });

      testWidgets('tappable mode calls onTitleTap', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.tappable,
            onTitleTap: () => tapped = true,
          ),
        );

        await tester.tap(find.text('Test'));
        expect(tapped, isTrue);
      });

      testWidgets('dropdown mode shows caret icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.dropdown,
            onTitleTap: () {},
          ),
        );

        expect(find.byType(SvgPicture), findsWidgets);
      });

      testWidgets('dropdown mode is tappable', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.dropdown,
            onTitleTap: () => tapped = true,
          ),
        );

        await tester.tap(find.text('Test'));
        expect(tapped, isTrue);
      });
    });

    group('leading', () {
      testWidgets('shows back button when showBackButton is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Test', showBackButton: true),
        );

        expect(find.byType(DivineAppBarIconButton), findsOneWidget);
      });

      testWidgets('back button calls onBackPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            onBackPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(DivineAppBarIconButton));
        expect(pressed, isTrue);
      });

      testWidgets('back button wraps in Hero when backButtonHeroTag is set', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            backButtonHeroTag: 'back-hero',
          ),
        );

        expect(find.byType(Hero), findsOneWidget);
        final hero = tester.widget<Hero>(find.byType(Hero));
        expect(hero.tag, 'back-hero');
      });

      testWidgets('shows menu button when showMenuButton is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showMenuButton: true,
            onMenuPressed: () {},
          ),
        );

        expect(find.byType(DivineAppBarIconButton), findsOneWidget);
      });

      testWidgets('menu button calls onMenuPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showMenuButton: true,
            onMenuPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(DivineAppBarIconButton));
        expect(pressed, isTrue);
      });

      testWidgets('shows custom leading icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            leadingIcon: const MaterialIconSource(Icons.close),
            onLeadingPressed: () {},
          ),
        );

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('custom leading calls onLeadingPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            leadingIcon: const MaterialIconSource(Icons.close),
            onLeadingPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(DivineAppBarIconButton));
        expect(pressed, isTrue);
      });

      testWidgets('no leading when all options are false', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        expect(find.byType(DivineAppBarIconButton), findsNothing);
      });

      testWidgets('default leading variants are anchored to their own ids', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            onBackPressed: () {},
          ),
        );

        expect(find.bySemanticsIdentifier('back_button'), findsOneWidget);

        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showMenuButton: true,
            onMenuPressed: () {},
          ),
        );

        expect(find.bySemanticsIdentifier('menu_button'), findsOneWidget);
        expect(find.bySemanticsIdentifier('back_button'), findsNothing);

        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            leadingIcon: const SvgIconSource(DiVineAppBarLeading.menuIconAsset),
            onLeadingPressed: () {},
          ),
        );

        expect(
          find.bySemanticsIdentifier('leading_action_button'),
          findsOneWidget,
        );
        expect(find.bySemanticsIdentifier('back_button'), findsNothing);
      });

      testWidgets('expandLeadingHitArea routes taps in the empty part of the '
          'leading slot to onBackPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            onBackPressed: () => pressed = true,
            expandLeadingHitArea: true,
            style: DiVineAppBarStyle.overMediaStyle.copyWith(
              horizontalPadding: 12,
              leadingWidth: 72,
            ),
          ),
        );

        // Tap inside the slot but outside the visible 48 × 48 icon
        // button (which lives at x ∈ [12, 60]).
        final iconButtonRect = tester.getRect(
          find.byType(DivineAppBarIconButton),
        );
        final tapPoint = Offset(
          iconButtonRect.right + 4,
          iconButtonRect.center.dy,
        );
        await tester.tapAt(tapPoint);
        expect(pressed, isTrue);
      });

      testWidgets(
        'expandLeadingHitArea keeps the label on the node that is actually '
        'tappable',
        (tester) async {
          var pressed = false;
          await tester.pumpWidget(
            buildTestWidget(
              title: 'Test',
              showBackButton: true,
              onBackPressed: () => pressed = true,
              expandLeadingHitArea: true,
            ),
          );

          // AbsorbPointer stops the inner button receiving pointers, so the
          // announced node has to be the outer one -- otherwise assistive
          // tech and UI tests both target something inert.
          final node = tester.getSemantics(
            find.bySemanticsIdentifier('back_button'),
          );
          // MaterialLocalizations.backButtonTooltip — 'Back' in English,
          // translated by material_ui everywhere else.
          expect(node.label, 'Back');
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );

          await tester.tap(find.bySemanticsIdentifier('back_button'));
          expect(pressed, isTrue);
        },
      );

      testWidgets(
        'expandLeadingHitArea anchors each leading variant to its own id',
        (tester) async {
          // One widget renders all three variants, so a single hardcoded id
          // would label a menu or a custom leading action 'back_button'.
          await tester.pumpWidget(
            buildTestWidget(
              title: 'Test',
              showMenuButton: true,
              onMenuPressed: () {},
              expandLeadingHitArea: true,
            ),
          );

          expect(find.bySemanticsIdentifier('menu_button'), findsOneWidget);
          expect(find.bySemanticsIdentifier('back_button'), findsNothing);

          await tester.pumpWidget(
            buildTestWidget(
              title: 'Test',
              leadingIcon: const SvgIconSource(
                DiVineAppBarLeading.menuIconAsset,
              ),
              onLeadingPressed: () {},
              expandLeadingHitArea: true,
            ),
          );

          expect(
            find.bySemanticsIdentifier('leading_action_button'),
            findsOneWidget,
          );
          expect(find.bySemanticsIdentifier('back_button'), findsNothing);
        },
      );

      testWidgets(
        'default behavior: taps outside the visible button do NOT fire '
        'onBackPressed',
        (tester) async {
          var pressed = false;
          await tester.pumpWidget(
            buildTestWidget(
              title: 'Test',
              showBackButton: true,
              onBackPressed: () => pressed = true,
              style: DiVineAppBarStyle.overMediaStyle.copyWith(
                horizontalPadding: 12,
                leadingWidth: 72,
              ),
            ),
          );

          final iconButtonRect = tester.getRect(
            find.byType(DivineAppBarIconButton),
          );
          await tester.tapAt(
            Offset(iconButtonRect.right + 4, iconButtonRect.center.dy),
          );
          expect(pressed, isFalse);
        },
      );
    });

    group('actions', () {
      testWidgets('renders action buttons', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            actions: [
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.search),
                onPressed: () {},
              ),
            ],
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('renders multiple action buttons', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            actions: [
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.search),
                onPressed: () {},
              ),
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.settings),
                onPressed: () {},
              ),
            ],
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('action button calls onPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            actions: [
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.search),
                onPressed: () => pressed = true,
              ),
            ],
          ),
        );

        await tester.tap(find.byIcon(Icons.search));
        expect(pressed, isTrue);
      });
    });

    group('customActions', () {
      testWidgets('renders a custom widget in the trailing slot', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            customActions: const [
              SizedBox(key: Key('custom-trailing'), width: 24, height: 24),
            ],
          ),
        );

        expect(find.byKey(const Key('custom-trailing')), findsOneWidget);
      });

      testWidgets('renders typed actions and custom actions side by side', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            actions: [
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.search),
                onPressed: () {},
              ),
            ],
            customActions: const [
              SizedBox(key: Key('custom-trailing'), width: 24, height: 24),
            ],
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byKey(const Key('custom-trailing')), findsOneWidget);
      });

      testWidgets('renders multiple custom actions with spacing between', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            customActions: const [
              SizedBox(key: Key('custom-1'), width: 24, height: 24),
              SizedBox(key: Key('custom-2'), width: 24, height: 24),
            ],
          ),
        );

        expect(find.byKey(const Key('custom-1')), findsOneWidget);
        expect(find.byKey(const Key('custom-2')), findsOneWidget);
      });
    });

    group('status bar style', () {
      testWidgets('gradient mode keeps light icons over media', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.gradient,
            gradient: DiVineAppBarGradient.videoOverlay,
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.systemOverlayStyle, VineTheme.statusBarStyle);
      });

      testWidgets('solid and transparent defer to the themed appBarTheme', (
        tester,
      ) async {
        // Transparent only means "paints no background of its own" — the page
        // behind it follows the palette, so the status bar must too.
        for (final mode in [
          DiVineAppBarBackgroundMode.solid,
          DiVineAppBarBackgroundMode.transparent,
        ]) {
          await tester.pumpWidget(
            buildTestWidget(title: 'Test', backgroundMode: mode),
          );

          final appBar = tester.widget<AppBar>(find.byType(AppBar));
          expect(appBar.systemOverlayStyle, isNull, reason: '$mode');
        }
      });

      testWidgets('an explicit style still wins', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.transparent,
            systemOverlayStyle: VineTheme.lightStatusBarStyle,
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.systemOverlayStyle, VineTheme.lightStatusBarStyle);
      });
    });

    group('background modes', () {
      testWidgets('solid mode uses navGreen by default', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, VineTheme.navGreen);
      });

      testWidgets('solid mode uses custom backgroundColor', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Test', backgroundColor: Colors.purple),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, Colors.purple);
      });

      testWidgets('transparent mode uses transparent background', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.transparent,
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, Colors.transparent);
      });

      testWidgets('gradient mode wraps in Container with gradient', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.gradient,
            gradient: DiVineAppBarGradient.videoOverlay,
          ),
        );

        // Should have a Container with gradient decoration
        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasGradient = containers.any((c) {
          final decoration = c.decoration as BoxDecoration?;
          return decoration?.gradient != null;
        });

        expect(hasGradient, isTrue);
      });

      testWidgets('gradient mode sets AppBar background to transparent', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.gradient,
            gradient: DiVineAppBarGradient.videoOverlay,
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, Colors.transparent);
      });
    });

    group('AppBar properties', () {
      testWidgets('has zero elevation', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.elevation, 0);
      });

      testWidgets('has zero scrolledUnderElevation', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.scrolledUnderElevation, 0);
      });

      testWidgets('has correct toolbarHeight', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.toolbarHeight, 72);
      });

      testWidgets('has zero leadingWidth when no leading widget', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.leadingWidth, 0);
      });

      testWidgets('has correct leadingWidth when back button shown', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Test', showBackButton: true),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.leadingWidth, 80);
      });

      testWidgets('uses horizontalPadding as titleSpacing without leading', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.titleSpacing, 16);
      });

      testWidgets('has zero titleSpacing with leading', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Test', showBackButton: true),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.titleSpacing, 0);
      });

      testWidgets('does not center title', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.centerTitle, isFalse);
      });

      testWidgets('does not automatically imply leading', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.automaticallyImplyLeading, isFalse);
      });
    });

    group('style', () {
      testWidgets('uses default style when not provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Test', showBackButton: true),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.toolbarHeight, 72);
        expect(appBar.leadingWidth, 80);
      });

      testWidgets('uses provided style for height and leadingWidth', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            style: const DiVineAppBarStyle(height: 64, leadingWidth: 72),
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.toolbarHeight, 64);
        expect(appBar.leadingWidth, 72);
      });

      testWidgets('preferredSize uses style height', (tester) async {
        const customStyle = DiVineAppBarStyle(height: 64);
        const appBar = DiVineAppBar(title: 'Test', style: customStyle);

        expect(appBar.preferredSize.height, 64);
      });

      testWidgets('preferredSize uses default height when no style', (
        tester,
      ) async {
        const appBar = DiVineAppBar(title: 'Test');

        expect(appBar.preferredSize.height, 72);
      });
    });

    group('background mode auto-style', () {
      testWidgets('solid mode applies solidStyle icon color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Test', showBackButton: true),
        );

        final iconButton = tester.widget<DivineAppBarIconButton>(
          find.byType(DivineAppBarIconButton),
        );
        expect(iconButton.iconColor, VineTheme.primary);
        expect(iconButton.backgroundColor, VineTheme.surfaceContainer);
        expect(
          iconButton.borderSide,
          const BorderSide(color: VineTheme.outlineMuted, width: 2),
        );
      });

      testWidgets('transparent mode follows the nav foreground', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            backgroundMode: DiVineAppBarBackgroundMode.transparent,
          ),
        );

        final iconButton = tester.widget<DivineAppBarIconButton>(
          find.byType(DivineAppBarIconButton),
        );
        expect(iconButton.iconColor, VineTheme.darkColors.onNav);
        expect(iconButton.backgroundColor, const Color(0x26000000));
        expect(iconButton.borderSide, isNull);
      });

      testWidgets('gradient mode keeps the over-media icon color', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            backgroundMode: DiVineAppBarBackgroundMode.gradient,
            gradient: DiVineAppBarGradient.videoOverlay,
          ),
        );

        final iconButton = tester.widget<DivineAppBarIconButton>(
          find.byType(DivineAppBarIconButton),
        );
        expect(iconButton.iconColor, VineTheme.whiteText);
        expect(iconButton.backgroundColor, const Color(0x26000000));
        expect(iconButton.borderSide, isNull);
      });

      testWidgets('caller-supplied style overrides auto-style icon color', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            style: const DiVineAppBarStyle(iconColor: Colors.red),
          ),
        );

        final iconButton = tester.widget<DivineAppBarIconButton>(
          find.byType(DivineAppBarIconButton),
        );
        expect(iconButton.iconColor, Colors.red);
      });
    });

    group('assertions', () {
      test('throws when neither title nor titleWidget is provided', () {
        expect(DiVineAppBar.new, throwsA(isA<AssertionError>()));
      });

      test('throws when both showBackButton and showMenuButton are true', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            showBackButton: true,
            showMenuButton: true,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when showBackButton with custom leadingIcon', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            showBackButton: true,
            leadingIcon: const MaterialIconSource(Icons.close),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when showMenuButton with custom leadingIcon', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            showMenuButton: true,
            leadingIcon: const MaterialIconSource(Icons.close),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when tappable mode without onTitleTap', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.tappable,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when dropdown mode without onTitleTap', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.dropdown,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when gradient mode without gradient', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.gradient,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when leadingIcon without onLeadingPressed', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            leadingIcon: const MaterialIconSource(Icons.close),
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('accessibility', () {
      testWidgets('expandLeadingHitArea leaves no unlabeled tappable node', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Feed',
            showBackButton: true,
            onBackPressed: () {},
            expandLeadingHitArea: true,
          ),
        );

        // The stretching GestureDetector declares the same tap action as
        // the Semantics wrapping it, and two configs declaring one action
        // cannot merge — so without excludeFromSemantics the tree carries
        // an anonymous button nested inside the labelled one.
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        // ...and the labelled button is still there afterwards.
        expect(find.bySemanticsLabel('Back'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('expandLeadingHitArea still activates the callback', (
        tester,
      ) async {
        var pressed = 0;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Feed',
            showBackButton: true,
            onBackPressed: () => pressed++,
            expandLeadingHitArea: true,
          ),
        );

        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();

        expect(pressed, 1);
      });
    });
  });

  group('DiVineAppBar back button localization', () {
    // The default back label used to be a hardcoded 'Go back', which shipped
    // untranslated to 21 locales because only 6 of 92 call sites passed
    // backButtonSemanticLabel. It now defaults to
    // MaterialLocalizations.backButtonTooltip, which material_ui
    // translates. This test is the thing that would catch a regression back to
    // a constant: a hardcoded English default cannot produce 'Atrás'.
    Widget buildLocalized(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('es'), Locale('nl')],
      theme: VineTheme.theme,
      home: const Scaffold(
        appBar: DiVineAppBar(title: 'Test', showBackButton: true),
        body: SizedBox.shrink(),
      ),
    );

    testWidgets('uses the English MaterialLocalizations label', (tester) async {
      await tester.pumpWidget(buildLocalized(const Locale('en')));

      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });

    testWidgets('translates the back label for es', (tester) async {
      await tester.pumpWidget(buildLocalized(const Locale('es')));

      expect(find.bySemanticsLabel('Atrás'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsNothing);
    });

    testWidgets('an explicit label still wins over the localized default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en'), Locale('es')],
          theme: VineTheme.theme,
          home: const Scaffold(
            appBar: DiVineAppBar(
              title: 'Test',
              showBackButton: true,
              backButtonSemanticLabel: 'Volver al perfil',
            ),
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Volver al perfil'), findsOneWidget);
      expect(find.bySemanticsLabel('Atrás'), findsNothing);
    });
  });

  group('DiVineAppBar menu button localization', () {
    // Same defect as the back button: the defaults were the hardcoded English
    // 'Open menu' / 'Menu'. They now come from
    // MaterialLocalizations.openAppDrawerTooltip — the string Flutter's own
    // DrawerButton uses for this slot — so a constant regression cannot
    // produce 'Abrir el menú de navegación'.
    Widget buildLocalized(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('es')],
      theme: VineTheme.theme,
      home: Scaffold(
        appBar: DiVineAppBar(
          title: 'Test',
          showMenuButton: true,
          onMenuPressed: () {},
        ),
        body: const SizedBox.shrink(),
      ),
    );

    testWidgets('uses the English MaterialLocalizations label', (tester) async {
      await tester.pumpWidget(buildLocalized(const Locale('en')));

      expect(find.bySemanticsLabel('Open navigation menu'), findsOneWidget);
    });

    testWidgets('translates the menu label for es', (tester) async {
      await tester.pumpWidget(buildLocalized(const Locale('es')));

      expect(
        find.bySemanticsLabel('Abrir el menú de navegación'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Open navigation menu'), findsNothing);
    });

    testWidgets('an explicit label still wins over the localized default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en'), Locale('es')],
          theme: VineTheme.theme,
          home: Scaffold(
            appBar: DiVineAppBar(
              title: 'Test',
              showMenuButton: true,
              onMenuPressed: () {},
              menuButtonSemanticLabel: 'Abrir ajustes',
              menuButtonTooltip: 'Ajustes',
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Abrir ajustes'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Abrir el menú de navegación'),
        findsNothing,
      );
    });
  });
}
