// ABOUTME: Widget tests for CommentsEmptyState component
// ABOUTME: Tests empty state display and Classic Vine notice functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/comments.dart';

void main() {
  group('CommentsEmptyState', () {
    group('standard empty state', () {
      testWidgets('displays "No comments yet" message', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CommentsEmptyState(isClassicVine: false)),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.commentsEmptyTitle), findsOneWidget);
        expect(find.text(l10n.commentsEmptySubtitle), findsOneWidget);
      });

      testWidgets(
        'does NOT show Classic Vine notice when isClassicVine is false',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: CommentsEmptyState(isClassicVine: false)),
            ),
          );

          expect(find.text('Classic Vine'), findsNothing);
          expect(find.byIcon(Icons.history), findsNothing);
        },
      );

      testWidgets('is centered on screen', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CommentsEmptyState(isClassicVine: false)),
          ),
        );

        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets(
        'does not overflow when the open keyboard squeezes the sheet',
        (tester) async {
          // The comments sheet's list area shrinks to almost nothing when the
          // keyboard is up on a small sheet fraction; the empty state must
          // shrink with it instead of overflowing (RenderFlex overflow fails
          // the test automatically via FlutterError).
          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  height: 40,
                  child: CommentsEmptyState(isClassicVine: false),
                ),
              ),
            ),
          );

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.commentsEmptyTitle), findsOneWidget);
        },
      );
    });

    group('Classic Vine state', () {
      testWidgets('shows Classic Vine notice when isClassicVine is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CommentsEmptyState(isClassicVine: true)),
          ),
        );

        expect(find.text('Classic Vine'), findsOneWidget);
        expect(find.byIcon(Icons.history), findsOneWidget);
      });

      testWidgets('shows archive import message for Classic Vine', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CommentsEmptyState(isClassicVine: true)),
          ),
        );

        expect(
          find.text(
            "We're still working on importing old comments "
            "from the archive. They're not ready yet.",
          ),
          findsOneWidget,
        );
      });

      testWidgets('still shows "No comments yet" with Classic Vine notice', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CommentsEmptyState(isClassicVine: true)),
          ),
        );

        // Should show both the Classic Vine notice AND the empty state message
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text('Classic Vine'), findsOneWidget);
        expect(find.text(l10n.commentsEmptyTitle), findsOneWidget);
        expect(find.text(l10n.commentsEmptySubtitle), findsOneWidget);
      });

      testWidgets('has styled container for Classic Vine notice', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CommentsEmptyState(isClassicVine: true)),
          ),
        );

        // Find the decorated container (the one with orange styling)
        final containers = tester.widgetList<Container>(find.byType(Container));
        final decoratedContainer = containers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).borderRadius != null,
          orElse: () => throw StateError('No decorated container found'),
        );

        final decoration = decoratedContainer.decoration! as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(12)));
        expect(decoration.border, isNotNull);
      });
    });
  });
}
