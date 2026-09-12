// ABOUTME: Widget tests for the gallery permission bottom sheet.
// ABOUTME: Verifies Open Settings, Allow Access, Not Now, and
// ABOUTME: Don't Ask Again actions for both canRequest and
// ABOUTME: requiresSettings permission states.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/gallery_permission_sheet.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  late _MockPermissionsService mockPermissionsService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockPermissionsService = _MockPermissionsService();
    when(
      () => mockPermissionsService.openAppSettings(),
    ).thenAnswer((_) async => true);
    when(
      () => mockPermissionsService.checkGalleryStatus(),
    ).thenAnswer((_) async => PermissionStatus.requiresSettings);
    when(
      () => mockPermissionsService.requestGalleryPermission(),
    ).thenAnswer((_) async => PermissionStatus.granted);
  });

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final choice = await showGalleryPermissionSheet(
                context,
                permissionsService: mockPermissionsService,
              );
              if (!context.mounted) return;
              // Surface the result as text so tests can verify it.
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('result:${choice.name}')));
            },
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  group('showGalleryPermissionSheet', () {
    group('renders', () {
      testWidgets('title with destination name', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Let us save your videos'), findsOneWidget);
      });

      testWidgets('description text', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Flip on Gallery access in Settings'),
          findsOneWidget,
        );
      });

      testWidgets('alert sticker', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(DivineSticker), findsOneWidget);
      });

      testWidgets('Open Settings primary button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Open Settings'), findsOneWidget);
      });

      testWidgets('Not Now secondary button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Not Now'), findsOneWidget);
      });

      testWidgets("Don't Ask Again text button", (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text("Don't Ask Again"), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping Open Settings calls openAppSettings and returns '
          '$GalleryPermissionChoice.openedSettings', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        // Sheet dismissed
        expect(find.text('Let us save your videos'), findsNothing);

        verify(() => mockPermissionsService.openAppSettings()).called(1);
        expect(find.text('result:openedSettings'), findsOneWidget);
      });

      testWidgets('tapping Not Now returns $GalleryPermissionChoice.skipped', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Not Now'));
        await tester.pumpAndSettle();

        // Sheet dismissed
        expect(find.text('Let us save your videos'), findsNothing);

        verifyNever(() => mockPermissionsService.openAppSettings());
        expect(find.text('result:skipped'), findsOneWidget);
      });

      testWidgets("tapping Don't Ask Again persists flag and returns "
          '$GalleryPermissionChoice.dismissedForever', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text("Don't Ask Again"));
        await tester.pumpAndSettle();

        // Sheet dismissed
        expect(find.text('Let us save your videos'), findsNothing);

        expect(find.text('result:dismissedForever'), findsOneWidget);

        // SharedPreferences flag was set
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('gallery_permission_dismissed_forever'), isTrue);
      });
    });

    group('when permission can be requested', () {
      setUp(() {
        when(
          () => mockPermissionsService.checkGalleryStatus(),
        ).thenAnswer((_) async => PermissionStatus.canRequest);
      });

      group('renders', () {
        testWidgets('Allow Access primary button', (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          expect(find.text('Allow Access'), findsOneWidget);
          expect(find.text('Open Settings'), findsNothing);
        });

        testWidgets('request description text', (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          expect(find.textContaining('we need Gallery access'), findsOneWidget);
        });
      });

      group('interactions', () {
        testWidgets('tapping Allow Access calls requestGalleryPermission '
            'and returns $GalleryPermissionChoice.granted when granted', (
          tester,
        ) async {
          await tester.pumpWidget(buildSubject());
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Allow Access'));
          await tester.pumpAndSettle();

          // Sheet dismissed
          expect(find.text('Let us save your videos'), findsNothing);

          verify(
            () => mockPermissionsService.requestGalleryPermission(),
          ).called(1);
          verifyNever(() => mockPermissionsService.openAppSettings());
          expect(find.text('result:granted'), findsOneWidget);
        });

        testWidgets('tapping Allow Access returns '
            '$GalleryPermissionChoice.skipped when denied', (tester) async {
          when(
            () => mockPermissionsService.requestGalleryPermission(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);

          await tester.pumpWidget(buildSubject());
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Allow Access'));
          await tester.pumpAndSettle();

          expect(find.text('Let us save your videos'), findsNothing);

          verify(
            () => mockPermissionsService.requestGalleryPermission(),
          ).called(1);
          expect(find.text('result:skipped'), findsOneWidget);
        });

        testWidgets(
          'tapping Not Now returns $GalleryPermissionChoice.skipped',
          (tester) async {
            await tester.pumpWidget(buildSubject());
            await tester.tap(find.text('Open Sheet'));
            await tester.pumpAndSettle();

            await tester.tap(find.text('Not Now'));
            await tester.pumpAndSettle();

            expect(find.text('Let us save your videos'), findsNothing);
            expect(find.text('result:skipped'), findsOneWidget);
          },
        );
      });
    });

    testWidgets(
      'returns $GalleryPermissionChoice.granted without showing sheet '
      'when permission is already granted',
      (tester) async {
        when(
          () => mockPermissionsService.checkGalleryStatus(),
        ).thenAnswer((_) async => PermissionStatus.granted);

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Sheet should not appear
        expect(find.text('Let us save your videos'), findsNothing);
        // Result should be granted
        expect(find.text('result:granted'), findsOneWidget);
      },
    );
  });

  group('isGalleryPermissionDismissedForever', () {
    test('returns false when flag is not set', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await isGalleryPermissionDismissedForever(), isFalse);
    });

    test('returns true when flag is set', () async {
      SharedPreferences.setMockInitialValues({
        'gallery_permission_dismissed_forever': true,
      });
      expect(await isGalleryPermissionDismissedForever(), isTrue);
    });

    test('returns false when flag is explicitly false', () async {
      SharedPreferences.setMockInitialValues({
        'gallery_permission_dismissed_forever': false,
      });
      expect(await isGalleryPermissionDismissedForever(), isFalse);
    });
  });
}
