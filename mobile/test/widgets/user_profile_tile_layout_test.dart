// ABOUTME: Layout-focused TDD tests for UserProfileTile addressing widget display bugs
// ABOUTME: Tests responsive layout, element positioning, state visibility, and edge case rendering

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    _setupPlatformMocks();
  });

  group('UserProfileTile - Layout & Display Bug Tests', () {
    late TestUserProfileService testUserProfileService;
    late TestAuthService testAuthService;
    late UserProfile testProfile;
    late UserProfile longContentProfile;

    const testPubkey = 'npub1test123456789abcdef';
    const currentUserPubkey = 'npub1current987654321xyz';

    setUp(() {
      testUserProfileService = TestUserProfileService();
      testAuthService = TestAuthService();

      // Create test profiles with various content lengths
      testProfile = UserProfile(
        pubkey: testPubkey,
        rawData: const {
          "name": "Test User",
          "display_name": "Test Display Name",
          "about": "Short bio",
          "picture": "https://example.com/avatar.jpg",
        },
        eventId: 'test_event_id',
        name: 'Test User',
        displayName: 'Test Display Name',
        about: 'Short bio',
        picture: 'https://example.com/avatar.jpg',
        createdAt: DateTime.now(),
      );

      longContentProfile = UserProfile(
        pubkey: 'npub1long123456789',
        rawData: const {
          "name": "Very Long Username",
          "display_name": "Extremely Long Display Name",
          "about": "Very long bio",
        },
        eventId: 'long_event_id',
        name: 'Very Long Username That Should Not Break Layout',
        displayName:
            'Extremely Long Display Name That Tests Text Overflow Handling In The Widget',
        about:
            'This is an extremely long bio that should test text truncation and ellipsis handling. ' *
            5,
        picture: 'https://example.com/avatar.jpg',
        createdAt: DateTime.now(),
      );

      testAuthService.setCurrentUser(currentUserPubkey);
      testUserProfileService.addProfile(testProfile);
      testUserProfileService.addProfile(longContentProfile);
    });

    group('🎯 LAYOUT STRUCTURE TESTS', () {
      testWidgets('LAYOUT: maintains proper container structure and spacing', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey),
          ),
        );

        await tester.pumpAndSettle();

        // Find the main container
        final containerFinder = find.byType(Container).first;
        expect(containerFinder, findsOneWidget);

        final Container container = tester.widget<Container>(containerFinder);

        // Verify container has proper margin and padding
        expect(container.margin, equals(const EdgeInsets.only(bottom: 8)));
        expect(container.padding, equals(const EdgeInsets.all(12)));

        // Verify container decoration
        expect(container.decoration, isA<BoxDecoration>());
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(VineTheme.cardBackground));
        expect(decoration.borderRadius, equals(BorderRadius.circular(12)));
      });

      testWidgets('LAYOUT: row structure with proper flex distribution', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey),
          ),
        );

        await tester.pumpAndSettle();

        // Find main Row widget
        final rowFinder = find.byType(Row);
        expect(rowFinder, findsOneWidget);

        // Verify Row children structure
        final Row row = tester.widget<Row>(rowFinder);
        expect(
          row.children.length,
          equals(3),
        ); // Avatar, Expanded content, Follow button

        // Check that middle section is Expanded
        expect(row.children[1], isA<SizedBox>()); // SizedBox(width: 12)
        expect(row.children[2], isA<Expanded>());
      });

      testWidgets('LAYOUT: avatar positioning and sizing', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey),
          ),
        );

        await tester.pumpAndSettle();

        // Find UserAvatar
        final avatarFinder = find.byType(UserAvatar);
        expect(avatarFinder, findsOneWidget);

        final UserAvatar avatar = tester.widget<UserAvatar>(avatarFinder);
        expect(avatar.size, equals(48)); // Verify correct size
        expect(avatar.imageUrl, equals(testProfile.picture));
        expect(avatar.name, equals(testProfile.bestDisplayName));

        // Check avatar is properly wrapped in GestureDetector
        final avatarGestureDetector = find.ancestor(
          of: avatarFinder,
          matching: find.byType(GestureDetector),
        );
        expect(avatarGestureDetector, findsOneWidget);
      });

      testWidgets('LAYOUT: follow button placement and sizing when visible', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey, showFollowButton: true),
          ),
        );

        await tester.pumpAndSettle();

        // Find follow button
        final buttonFinder = find.byType(ElevatedButton);
        expect(buttonFinder, findsOneWidget);

        final ElevatedButton button = tester.widget<ElevatedButton>(
          buttonFinder,
        );
        expect(button.child, isA<Text>());

        // Check button is wrapped in SizedBox with correct height
        final buttonSizedBox = find.ancestor(
          of: buttonFinder,
          matching: find.byType(SizedBox),
        );
        expect(buttonSizedBox, findsOneWidget);

        final SizedBox sizedBox = tester.widget<SizedBox>(buttonSizedBox);
        expect(sizedBox.height, equals(32));
      });
    });

    group('🎯 CONTENT DISPLAY TESTS', () {
      testWidgets('CONTENT: displays profile name correctly', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey),
          ),
        );

        await tester.pumpAndSettle();

        // Should show display name
        expect(find.text('Test Display Name'), findsOneWidget);

        // Verify text styling
        final nameTextFinder = find.text('Test Display Name');
        final Text nameText = tester.widget<Text>(nameTextFinder);
        expect(nameText.style?.color, equals(Colors.white));
        expect(nameText.style?.fontSize, equals(16));
        expect(nameText.style?.fontWeight, equals(FontWeight.w600));
      });

      testWidgets('CONTENT: displays bio when available', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey),
          ),
        );

        await tester.pumpAndSettle();

        // Should show bio
        expect(find.text('Short bio'), findsOneWidget);

        // Verify bio text styling
        final bioTextFinder = find.text('Short bio');
        final Text bioText = tester.widget<Text>(bioTextFinder);
        expect(bioText.style?.color, equals(Colors.grey[400]));
        expect(bioText.style?.fontSize, equals(14));
        expect(bioText.maxLines, equals(2));
        expect(bioText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('CONTENT: hides bio when not available', (tester) async {
        final profileNoBio = UserProfile(
          pubkey: 'npub1nobio123',
          rawData: const {
            "name": "No Bio User",
            "display_name": "No Bio Display",
          },
          eventId: 'nobio_event_id',
          name: 'No Bio User',
          displayName: 'No Bio Display',
          createdAt: DateTime.now(),
        );
        testUserProfileService.addProfile(profileNoBio);

        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: 'npub1nobio123'),
          ),
        );

        await tester.pumpAndSettle();

        // Should show name but no bio
        expect(find.text('No Bio Display'), findsOneWidget);

        // Should NOT show any bio-related content
        expect(find.textContaining('bio'), findsNothing);
        expect(find.textContaining('about'), findsNothing);
      });

      testWidgets('CONTENT: shows abbreviated pubkey when no display name', (
        tester,
      ) async {
        final profileNoName = UserProfile(
          pubkey: testPubkey,
          rawData: const <String, dynamic>{},
          eventId: 'noname_event_id',
          createdAt: DateTime.now(),
        );
        testUserProfileService.clearProfiles();
        testUserProfileService.addProfile(profileNoName);

        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey),
          ),
        );

        await tester.pumpAndSettle();

        // Should show full pubkey
        expect(find.text(testPubkey), findsOneWidget);
      });
    });

    group('🎯 LONG CONTENT HANDLING TESTS', () {
      testWidgets(
        'LONG CONTENT: handles very long display name without overflow',
        (tester) async {
          await tester.pumpWidget(
            _buildTestWidget(
              testUserProfileService,
              testAuthService,
              const UserProfileTile(pubkey: 'npub1long123456789'),
            ),
          );

          await tester.pumpAndSettle();

          // Should render without RenderFlex overflow errors
          expect(find.byType(UserProfileTile), findsOneWidget);
          expect(
            find.textContaining('Extremely Long Display Name'),
            findsOneWidget,
          );

          // Verify text doesn't cause layout issues
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('LONG CONTENT: properly truncates long bio text', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: 'npub1long123456789'),
          ),
        );

        await tester.pumpAndSettle();

        // Find bio text
        final bioTextFinder = find.textContaining(
          'This is an extremely long bio',
        );
        expect(bioTextFinder, findsOneWidget);

        final Text bioText = tester.widget<Text>(bioTextFinder);
        expect(bioText.maxLines, equals(2));
        expect(bioText.overflow, equals(TextOverflow.ellipsis));

        // Should not cause overflow
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'LONG CONTENT: maintains layout integrity with all long content',
        (tester) async {
          await tester.pumpWidget(
            _buildTestWidget(
              testUserProfileService,
              testAuthService,
              const UserProfileTile(pubkey: 'npub1long123456789'),
            ),
          );

          await tester.pumpAndSettle();

          // All components should still be present
          expect(find.byType(UserAvatar), findsOneWidget);
          expect(
            find.textContaining('Extremely Long Display Name'),
            findsOneWidget,
          );
          expect(
            find.textContaining('This is an extremely long bio'),
            findsOneWidget,
          );
          expect(find.byType(ElevatedButton), findsOneWidget); // Follow button

          // No layout exceptions
          expect(tester.takeException(), isNull);

          // Verify the widget maintains its height constraints
          final tileFinder = find.byType(UserProfileTile);
          final RenderBox tileRenderBox = tester.renderObject(tileFinder);
          expect(tileRenderBox.size.height, greaterThan(0));
          expect(
            tileRenderBox.size.height,
            lessThan(200),
          ); // Reasonable max height
        },
      );
    });

    group('🎯 FOLLOW BUTTON VISIBILITY TESTS', () {
      testWidgets('BUTTON VISIBILITY: shows follow button for other users', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey, showFollowButton: true),
          ),
        );

        await tester.pumpAndSettle();

        // Should show follow button
        expect(find.text('Follow'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('BUTTON VISIBILITY: hides follow button for current user', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(
              pubkey: currentUserPubkey,
              showFollowButton: true,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should NOT show follow button
        expect(find.text('Follow'), findsNothing);
        expect(find.text('Following'), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
      });

      testWidgets('BUTTON VISIBILITY: respects showFollowButton parameter', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey, showFollowButton: false),
          ),
        );

        await tester.pumpAndSettle();

        // Should NOT show follow button even for other users
        expect(find.text('Follow'), findsNothing);
        expect(find.text('Following'), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
      });
    });

    group('🎯 RESPONSIVE LAYOUT TESTS', () {
      testWidgets('RESPONSIVE: adapts to narrow width constraints', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ProviderScope(
              overrides: [
                userProfileServiceProvider.overrideWithValue(
                  testUserProfileService,
                ),
                authServiceProvider.overrideWithValue(testAuthService),
              ],
              child: Scaffold(
                body: SizedBox(
                  width: 200, // Very narrow
                  child: const UserProfileTile(pubkey: testPubkey),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should still render all components without overflow
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.text('Test Display Name'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);

        // No overflow errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('RESPONSIVE: handles very wide layouts properly', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ProviderScope(
              overrides: [
                userProfileServiceProvider.overrideWithValue(
                  testUserProfileService,
                ),
                authServiceProvider.overrideWithValue(testAuthService),
              ],
              child: Scaffold(
                body: SizedBox(
                  width: 1000, // Very wide
                  child: const UserProfileTile(pubkey: testPubkey),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // All components should render properly
        expect(find.byType(UserProfileTile), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.text('Test Display Name'), findsOneWidget);

        // Layout should be stable
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'RESPONSIVE: maintains consistent appearance across different content',
        (tester) async {
          // Test with short content
          await tester.pumpWidget(
            _buildTestWidget(
              testUserProfileService,
              testAuthService,
              const UserProfileTile(pubkey: testPubkey),
            ),
          );

          await tester.pumpAndSettle();

          final shortContentHeight = tester
              .getSize(find.byType(UserProfileTile))
              .height;

          // Test with long content
          await tester.pumpWidget(
            _buildTestWidget(
              testUserProfileService,
              testAuthService,
              const UserProfileTile(pubkey: 'npub1long123456789'),
            ),
          );

          await tester.pumpAndSettle();

          final longContentHeight = tester
              .getSize(find.byType(UserProfileTile))
              .height;

          // Heights should be reasonably similar (bio is limited to 2 lines)
          final heightDifference = (longContentHeight - shortContentHeight)
              .abs();
          expect(
            heightDifference,
            lessThan(50),
          ); // Allow some variance for text wrapping
        },
      );
    });

    group('🎯 INTERACTION TESTS', () {
      testWidgets('INTERACTION: tap callbacks work correctly', (tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            UserProfileTile(pubkey: testPubkey, onTap: () => wasTapped = true),
          ),
        );

        await tester.pumpAndSettle();

        // Tap on avatar
        await tester.tap(find.byType(UserAvatar));
        await tester.pump();

        expect(wasTapped, isTrue);

        // Reset and test name tap
        wasTapped = false;
        await tester.tap(find.text('Test Display Name'));
        await tester.pump();

        expect(wasTapped, isTrue);
      });

      testWidgets('INTERACTION: follow button is tappable when visible', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: testPubkey, showFollowButton: true),
          ),
        );

        await tester.pumpAndSettle();

        final followButton = find.text('Follow');
        expect(followButton, findsOneWidget);

        // Should be tappable without throwing
        await tester.tap(followButton);
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });

    group('🎯 ERROR STATE HANDLING', () {
      testWidgets('ERROR: handles null profile gracefully', (tester) async {
        // Don't add profile to service, simulating null/missing profile
        testUserProfileService.clearProfiles();

        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: 'npub1missing123'),
          ),
        );

        await tester.pumpAndSettle();

        // Should still render with fallback content
        expect(find.byType(UserProfileTile), findsOneWidget);
        expect(find.text('npub1mis'), findsOneWidget); // Abbreviated pubkey

        // Should not crash
        expect(tester.takeException(), isNull);
      });

      testWidgets('ERROR: handles empty pubkey edge case', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            testUserProfileService,
            testAuthService,
            const UserProfileTile(pubkey: ''),
          ),
        );

        await tester.pumpAndSettle();

        // Should render without crashing
        expect(find.byType(UserProfileTile), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}

Widget _buildTestWidget(
  TestUserProfileService userProfileService,
  TestAuthService authService,
  Widget child,
) {
  return MaterialApp(
    home: testProviderScope(
      additionalOverrides: [
        userProfileServiceProvider.overrideWithValue(userProfileService),
        authServiceProvider.overrideWithValue(authService),
      ],
      child: Scaffold(body: child),
    ),
  );
}

// Simple test implementations
class TestUserProfileService implements UserProfileService {
  final Map<String, UserProfile> _profiles = {};

  void addProfile(UserProfile profile) {
    _profiles[profile.pubkey] = profile;
  }

  void clearProfiles() {
    _profiles.clear();
  }

  @override
  Future<UserProfile?> fetchProfile(
    String pubkey, {
    bool forceRefresh = false,
  }) async {
    return _profiles[pubkey];
  }

  @override
  UserProfile? getCachedProfile(String pubkey) {
    return _profiles[pubkey];
  }

  // Implement other required methods with basic implementations
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class TestAuthService implements AuthService {
  String? _currentUser;

  void setCurrentUser(String pubkey) {
    _currentUser = pubkey;
  }

  @override
  String? get currentPublicKeyHex => _currentUser;

  // Implement other required methods with basic implementations
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void _setupPlatformMocks() {
  // SharedPreferences mock
  const MethodChannel sharedPreferencesChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(sharedPreferencesChannel, (call) async {
        if (call.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      });

  // SecureStorage mock
  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async {
        if (call.method == 'read' || call.method == 'readAll') {
          return null;
        }
        if (call.method == 'write' ||
            call.method == 'delete' ||
            call.method == 'deleteAll') {
          return null;
        }
        return null;
      });

  // PathProvider mock
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return '/tmp/test_documents';
        }
        if (call.method == 'getApplicationSupportDirectory') {
          return '/tmp/test_support';
        }
        return '/tmp/test';
      });

  // Connectivity mock
  const MethodChannel connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(connectivityChannel, (call) async {
        if (call.method == 'check') {
          return 'wifi';
        }
        return null;
      });

  // DeviceInfo mock
  const MethodChannel deviceInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/device_info',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(deviceInfoChannel, (call) async {
        if (call.method == 'getLinuxDeviceInfo') {
          return <String, dynamic>{
            'name': 'Test Device',
            'version': '1.0.0',
            'id': 'test-device-id',
            'idLike': ['test'],
            'versionCodename': 'test',
            'versionId': '1.0',
            'prettyName': 'Test OS',
            'buildId': 'test-build',
            'variant': 'test',
            'variantId': 'test',
            'machineId': 'test-machine',
          };
        }
        return <String, dynamic>{};
      });
}
