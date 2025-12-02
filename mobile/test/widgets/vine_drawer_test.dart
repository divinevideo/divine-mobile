// ABOUTME: Unit tests for VineDrawer widget
// ABOUTME: Tests branding (wordmark logo) and navigation menu functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/vine_drawer.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'vine_drawer_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  group('VineDrawer Branding', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(
        mockAuthService.currentPublicKeyHex,
      ).thenReturn('test_pubkey_' + '0' * 54);
    });

    testWidgets('displays Divine logo image in header', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Open the drawer using scaffold key
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Verify logo image is present (app_icon.png)
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.contains('app_icon.png'),
        ),
        findsOneWidget,
        reason: 'Divine logo image should be displayed in drawer header',
      );
    });

    testWidgets('does not display "OpenVine" text in header', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Open the drawer using scaffold key
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Verify "OpenVine" text is NOT present in the header
      expect(
        find.text('OpenVine'),
        findsNothing,
        reason: 'Old "OpenVine" branding should not be displayed',
      );
    });

    testWidgets('does not use generic icon in header', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Open the drawer using scaffold key
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Verify Icons.video_library is NOT used in header
      expect(
        find.byIcon(Icons.video_library),
        findsNothing,
        reason:
            'Generic video_library icon should not be used, use wordmark instead',
      );
    });
  });
}
