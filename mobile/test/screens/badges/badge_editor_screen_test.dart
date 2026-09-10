// ABOUTME: Widget tests for BadgeEditorScreen — when the missing-artwork
// ABOUTME: message appears, and that Publish stays reachable to trigger it.

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/badges/badge_editor_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockBadgeEditorCubit extends MockCubit<BadgeEditorState>
    implements BadgeEditorCubit {}

void main() {
  group('BadgeEditorScreen', () {
    late _MockBadgeRepository repository;
    late _MockBlossomUploadService uploadService;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(
        const BadgeDefinitionDraft(identifier: 'x', name: 'x', imageUrl: 'x'),
      );
    });

    setUp(() {
      repository = _MockBadgeRepository();
      uploadService = _MockBlossomUploadService();
      when(
        repository.loadCreatedIdentifiers,
      ).thenAnswer((_) async => const <String>{});
    });

    /// Pumps the create-a-badge editor behind a real [GoRouter], which the
    /// screen needs because it pops itself once a badge is published.
    ///
    /// Passing [cubit] pumps the view against that cubit instead of the one
    /// the screen builds, which is how a state the UI cannot reach on its own
    /// (an upload still in flight) gets rendered.
    Widget buildSubject({BadgeEditorCubit? cubit}) {
      final router = GoRouter(
        initialLocation: BadgeEditorScreen.createPath,
        routes: [
          GoRoute(
            path: '/badges',
            builder: (_, _) => const Scaffold(body: Text('badge dashboard')),
          ),
          GoRoute(
            path: BadgeEditorScreen.createPath,
            builder: (_, _) => cubit == null
                ? const BadgeEditorScreen()
                : BlocProvider<BadgeEditorCubit>.value(
                    value: cubit,
                    child: const BadgeEditorView(),
                  ),
          ),
        ],
      );
      addTearDown(router.dispose);

      return testProviderScope(
        additionalOverrides: [
          badgeRepositoryProvider.overrideWithValue(repository),
          blossomUploadServiceProvider.overrideWithValue(uploadService),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    testWidgets('opens without scolding the user about artwork', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeEditorArtworkAdd), findsOneWidget);
      expect(find.text(l10n.badgeEditorArtworkRequired), findsNothing);
    });

    testWidgets('asks for artwork only once Publish is pressed', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(DivineTextField).first,
        'Scene Stealer',
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.badgeEditorArtworkRequired), findsNothing);

      final publish = find.text(l10n.badgeEditorSaveAction);
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      await tester.tap(publish);
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeEditorArtworkRequired), findsOneWidget);
      verifyNever(() => repository.saveDefinition(any()));
    });

    testWidgets('keeps the fields editable while artwork uploads', (
      tester,
    ) async {
      const uploading = BadgeEditorState(
        isEditing: false,
        status: BadgeEditorStatus.ready,
        artworkStatus: BadgeArtworkStatus.uploading,
        name: 'Scene Stealer',
        identifier: 'scene-stealer',
      );
      final cubit = _MockBadgeEditorCubit();
      whenListen(
        cubit,
        Stream<BadgeEditorState>.value(uploading),
        initialState: uploading,
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(buildSubject(cubit: cubit));
      // Not pumpAndSettle: the uploading spinner animates forever.
      await tester.pump();

      final fields = tester
          .widgetList<DivineTextField>(find.byType(DivineTextField))
          .toList();
      expect(fields.map((field) => field.enabled), everyElement(isTrue));

      // The artwork and Publish controls do stay locked: a second upload
      // would race the first, and publishing now would report the artwork
      // that is still in flight as missing.
      final publish = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, l10n.badgeEditorSaveAction),
      );
      expect(publish.onPressed, isNull);
      final artwork = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, l10n.badgeEditorArtworkAdd),
      );
      expect(artwork.onPressed, isNull);
    });

    testWidgets('identifier helper fits without being cut off', (tester) async {
      // At one line this rendered as "Part of the badge's address, so it stays
      // put once the badge e…", cutting the clause that carries the meaning.
      // A phone-width surface is the point: at the 800px test default the
      // helper fits on one line and the assertion proves nothing.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final helper = tester.renderObject<RenderParagraph>(
        find.text(l10n.badgeEditorIdentifierHelp),
      );
      expect(helper.didExceedMaxLines, isFalse);
    });

    testWidgets('warns instead of replacing a badge with the same name', (
      tester,
    ) async {
      when(
        repository.loadCreatedIdentifiers,
      ).thenAnswer((_) async => const {'test'});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(DivineTextField).first, 'Test');
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeEditorIdentifierTaken), findsOneWidget);
      final publish = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, l10n.badgeEditorSaveAction),
      );
      expect(publish.onPressed, isNull);
    });

    testWidgets(
      'asks for an identifier a non-Latin name could not derive',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // The slug is derived from `a-z0-9`, so a name written in another
        // script derives nothing and the user has to supply one by hand.
        await tester.enterText(find.byType(DivineTextField).first, 'スシ職人');
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgeEditorIdentifierRequired), findsNothing);

        final publish = find.text(l10n.badgeEditorSaveAction);
        await tester.ensureVisible(publish);
        await tester.pumpAndSettle();
        await tester.tap(publish);
        await tester.pumpAndSettle();

        expect(find.text(l10n.badgeEditorIdentifierRequired), findsOneWidget);
        verifyNever(() => repository.saveDefinition(any()));
      },
    );

    testWidgets('leaves Publish dead until the badge is named', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final publish = find.text(l10n.badgeEditorSaveAction);
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      await tester.tap(publish);
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeEditorArtworkRequired), findsNothing);
    });
  });
}
