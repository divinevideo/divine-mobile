import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_user_chip.dart';

/// Mock for UserProfile
class _MockUserProfile extends Mock implements UserProfile {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoMetadataUserChip, () {
    const testPubkey =
        'abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234';
    const testNpub =
        'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuv';

    group('renders', () {
      testWidgets('$UserAvatar with profile picture', (tester) async {
        final mockProfile = _MockUserProfile();
        when(() => mockProfile.picture).thenReturn('https://example.com/pic');
        when(() => mockProfile.bestDisplayName).thenReturn('Test User');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(
                testPubkey,
              ).overrideWith((ref) => mockProfile),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoMetadataUserChip.fromPubkey(pubkey: testPubkey),
              ),
            ),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('display name from profile', (tester) async {
        final mockProfile = _MockUserProfile();
        when(() => mockProfile.picture).thenReturn(null);
        when(() => mockProfile.bestDisplayName).thenReturn('Alice');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(
                testPubkey,
              ).overrideWith((ref) => mockProfile),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoMetadataUserChip.fromPubkey(pubkey: testPubkey),
              ),
            ),
          ),
        );

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets('fallback pubkey when profile loading', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(
                testPubkey,
              ).overrideWith((ref) => throw Exception('Loading')),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoMetadataUserChip.fromPubkey(pubkey: testPubkey),
              ),
            ),
          ),
        );

        // Full pubkey is shown (with text overflow handling)
        expect(find.text(testPubkey), findsOneWidget);
      });

      testWidgets('remove button when onRemove provided', (tester) async {
        final mockProfile = _MockUserProfile();
        when(() => mockProfile.picture).thenReturn(null);
        when(() => mockProfile.bestDisplayName).thenReturn('Bob');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(
                testPubkey,
              ).overrideWith((ref) => mockProfile),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoMetadataUserChip.fromPubkey(
                  pubkey: testPubkey,
                  onRemove: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SvgPicture), findsOneWidget);
      });

      testWidgets('no remove button when onRemove is null', (tester) async {
        final mockProfile = _MockUserProfile();
        when(() => mockProfile.picture).thenReturn(null);
        when(() => mockProfile.bestDisplayName).thenReturn('Charlie');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(
                testPubkey,
              ).overrideWith((ref) => mockProfile),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoMetadataUserChip.fromPubkey(pubkey: testPubkey),
              ),
            ),
          ),
        );

        expect(find.byType(SvgPicture), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('calls onRemove when remove button tapped', (tester) async {
        var removeCalled = false;
        final mockProfile = _MockUserProfile();
        when(() => mockProfile.picture).thenReturn(null);
        when(() => mockProfile.bestDisplayName).thenReturn('Dave');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(
                testPubkey,
              ).overrideWith((ref) => mockProfile),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoMetadataUserChip.fromPubkey(
                  pubkey: testPubkey,
                  onRemove: () => removeCalled = true,
                ),
              ),
            ),
          ),
        );

        // Tap the close icon (SvgPicture)
        await tester.tap(find.byType(SvgPicture));
        await tester.pumpAndSettle();

        expect(removeCalled, isTrue);
      });
    });

    group('fromNpub constructor', () {
      testWidgets('converts npub to hex for profile lookup', (tester) async {
        // Note: NostrKeyUtils.decode converts npub to hex pubkey
        // We test that the widget accepts npub format
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoMetadataUserChip.fromNpub(npub: testNpub),
              ),
            ),
          ),
        );

        expect(find.byType(VideoMetadataUserChip), findsOneWidget);
      });
    });
  });
}
