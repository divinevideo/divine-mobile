// ABOUTME: Widget tests for ConversationTile.
// ABOUTME: Verifies avatar, display name, last message, unread dot, and tap.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/dm_display_text.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  const currentPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  UserProfile createTestProfile({String? displayName, String? name}) {
    return UserProfile(
      pubkey: otherPubkey,
      displayName: displayName,
      name: name,
      rawData: const {},
      createdAt: now,
      eventId:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
  }

  DmConversation createTestConversation({
    String? lastMessageContent,
    int? lastMessageTimestamp,
    bool isRead = true,
  }) {
    return DmConversation(
      id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      participantPubkeys: const [currentPubkey, otherPubkey],
      isGroup: false,
      createdAt: nowUnix,
      lastMessageContent: lastMessageContent,
      lastMessageTimestamp: lastMessageTimestamp,
      isRead: isRead,
    );
  }

  /// The [SemanticsProperties] of the tile's own outermost Semantics wrapper.
  ///
  /// `onLongPressHint` lands in `SemanticsHintOverrides`, which `SemanticsData`
  /// does not expose, so the widget's declared properties are the accessible
  /// assertion point.
  SemanticsProperties tileSemantics(WidgetTester tester) {
    return tester
        .widget<Semantics>(
          find
              .descendant(
                of: find.byType(ConversationTile),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties;
  }

  group(ConversationTile, () {
    group('renders', () {
      testWidgets('renders $UserAvatar', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('renders display name from profile', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets(
        'uses a loading identity before revealing the generated fallback',
        (tester) async {
          final testConversation = createTestConversation();
          final generatedName = UserProfile.defaultDisplayNameFor(otherPubkey);

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
                profileIdentityResolvingProvider(
                  otherPubkey,
                ).overrideWithValue(true),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tileSemantics(tester).label, contains('Loading'));
          expect(
            tester
                .widgetList<Skeletonizer>(find.bySubtype<Skeletonizer>())
                .every((skeletonizer) => skeletonizer.enabled),
            isTrue,
          );

          await tester.pump(const Duration(seconds: 8));
          await tester.pumpAndSettle();

          expect(find.text(generatedName), findsOneWidget);
          expect(
            tester
                .widgetList<Skeletonizer>(find.bySubtype<Skeletonizer>())
                .every((skeletonizer) => !skeletonizer.enabled),
            isTrue,
          );
        },
      );

      testWidgets('paints a brand-green heart in a display name', (
        tester,
      ) async {
        final testProfile = createTestProfile(
          displayName: 'Alice $divineGreenHeart',
        );
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final heartFinder = find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon && widget.icon == DivineIconName.heartFill,
        );
        expect(heartFinder, findsOneWidget);
        expect(
          tester.widget<DivineIcon>(heartFinder).color,
          VineTheme.vineGreen,
        );
      });

      testWidgets('renders last message content', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hey, how are you?'), findsOneWidget);
      });

      testWidgets('bounds an oversized last-message preview', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final prefix = 'a' * dmPreviewDisplayCodeUnits;
        final testConversation = createTestConversation(
          lastMessageContent: '${prefix}hidden suffix',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(prefix), findsOneWidget);
        expect(find.textContaining('hidden suffix'), findsNothing);
      });

      testWidgets(
        'renders without crashing when the last message contains an '
        'unpaired UTF-16 surrogate',
        (tester) async {
          // The preview renders through plain Text rather than
          // LinkifiedText, so it does not inherit the span builder's
          // guard and has to sanitize the rumor body itself. Without it
          // the paragraph builder throws during layout.
          // See https://github.com/divinevideo/divine-mobile/issues/6516.
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent: 'before${String.fromCharCode(0xD83D)}after',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('before�after'), findsOneWidget);
        },
      );

      testWidgets(
        'last message preview uses VineTheme.onSurfaceVariant',
        (tester) async {
          // PR #3548 picked onSurfaceVariant for the preview; a later
          // drift slid it back to onSurfaceMuted (one shade darker) and
          // shipped without anyone catching it. Pin the color so the
          // same drift can't recur silently.
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent: 'Hey, how are you?',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final preview = tester.widget<Text>(find.text('Hey, how are you?'));
          expect(preview.style?.color, equals(VineTheme.onSurfaceVariant));
        },
      );

      // #3662 — the structured collab invite carries a deterministic
      // plaintext fallback ('...Open diVine to review and accept.') so
      // legacy clients can still see something. Inside diVine that copy
      // is misleading; the conversation list should show a localized
      // label instead.
      testWidgets(
        'replaces legacy collab invite plaintext with localized preview',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent:
                'You were invited to collaborate on Skate loop. '
                'Open diVine to review and accept.',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(
            find.text(l10n.inboxConversationCollabInvitePreview),
            findsOneWidget,
          );
          expect(
            find.textContaining('Open diVine to review and accept'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'recognizes a legacy collab invite beyond the preview limit',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent:
                '${'a' * dmPreviewDisplayCodeUnits} '
                'Open Divine to review and accept.',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(
            find.text(l10n.inboxConversationCollabInvitePreview),
            findsOneWidget,
          );
          expect(
            find.textContaining('Open Divine to review and accept'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'strips divine.video URL and prefixes a camera icon for shared-video DMs',
        (tester) async {
          // VideoSharingService composes a share DM as
          //   [personal message?]
          //   "title"
          //   <blank>
          //   https://divine.video/video/<id>
          // The conversation preview shouldn't surface the URL; it should
          // render an inline cameraRetro icon (the same glyph as the
          // bottom-nav camera button) followed by the title.
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent:
                '"#DIVINE #TEAMFB @shutupphia"\n\n'
                'https://divine.video/video/abc123',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.textContaining('"#DIVINE #TEAMFB @shutupphia"'),
            findsOneWidget,
          );
          expect(
            find.textContaining('https://divine.video'),
            findsNothing,
          );
          final cameraIcon = find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.cameraRetro &&
                widget.color == VineTheme.whiteText,
          );
          expect(cameraIcon, findsOneWidget);
        },
      );

      testWidgets(
        'plain-text preview does not include the camera icon',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation(
            lastMessageContent: 'Hey, how are you?',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is DivineIcon &&
                  widget.icon == DivineIconName.cameraRetro,
            ),
            findsNothing,
          );
        },
      );

      testWidgets('renders unread indicator when conversation is unread', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(isRead: false);

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The unread dot is an 8x8 Container with BoxShape.circle
        final dotFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8,
        );
        expect(dotFinder, findsOneWidget);
      });

      testWidgets(
        'does not render unread indicator when conversation is read',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation();

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // No 8x8 circle Container should exist
          final dotFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxWidth == 8 &&
                widget.constraints?.maxHeight == 8,
          );
          expect(dotFinder, findsNothing);
        },
      );

      testWidgets('renders emphasized preview when conversation is unread', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
          isRead: false,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final preview = tester.widget<Text>(find.text('Hey, how are you?'));
        expect(preview.style?.fontWeight, equals(FontWeight.w600));
        expect(preview.style?.color, equals(VineTheme.whiteText));
      });

      testWidgets('renders muted preview when conversation is read', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final preview = tester.widget<Text>(find.text('Hey, how are you?'));
        expect(preview.style?.fontWeight, equals(FontWeight.w400));
        expect(preview.style?.color, equals(VineTheme.onSurfaceVariant));
      });

      testWidgets('announces unread status in the semantic label', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
          isRead: false,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(find.byType(ConversationTile));
        expect(
          semantics.label,
          contains(l10n.inboxConversationTileLabelUnread('Alice')),
        );
      });

      testWidgets('omits the unread prefix from the label when read', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(
          lastMessageContent: 'Hey, how are you?',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(find.byType(ConversationTile));
        expect(
          semantics.label,
          contains(l10n.inboxConversationTileLabel('Alice')),
        );
        expect(
          semantics.label,
          isNot(contains(l10n.inboxConversationTileLabelUnread('Alice'))),
        );
      });
    });

    group('interactions', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('calls onLongPress when long-pressed', (tester) async {
        var longPressed = false;
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });
    });

    group('highlight', () {
      testWidgets(
        'applies $VineTheme.containerLow background when highlighted',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Alice');
          final testConversation = createTestConversation();

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => testProfile),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: testConversation,
                  currentUserPubkey: currentPubkey,
                  highlighted: true,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final decoratedBox = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(ConversationTile),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final decoration = decoratedBox.decoration as BoxDecoration;
          expect(decoration.color, equals(VineTheme.containerLow));
        },
      );

      testWidgets('has no background color when not highlighted', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final decoratedBox = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(ConversationTile),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, isNull);
      });
    });

    group('fixed-identity overrides (#6283)', () {
      testWidgets('displayNameOverride wins over the resolved profile', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => testProfile),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                displayNameOverride: 'Divine Moderation',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Divine Moderation'), findsOneWidget);
        expect(find.text('Alice'), findsNothing);
      });

      testWidgets('displayNameOverride also wins before the profile '
          'repository is ready', (tester) async {
        // profileRepositoryProvider is null until the relay client is ready,
        // so the tile's fallback is a generated "Adjective Animal N" name.
        // A pinned, known account must never render that.
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                displayNameOverride: 'Divine Moderation',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Divine Moderation'), findsOneWidget);
        expect(
          find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsNothing,
        );
      });

      testWidgets('subtitleOverride replaces the message preview', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(
                  lastMessageContent: 'Hello',
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                subtitleOverride: 'Bugs, moderation, account stuff.',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bugs, moderation, account stuff.'), findsOneWidget);
        expect(find.text('Hello'), findsNothing);
      });

      testWidgets('advertises no long-press hint when no handler is given', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The hint is a promise to assistive tech; without onLongPress there
        // is no action sheet to open, so promising one is a lie.
        expect(tileSemantics(tester).hintOverrides?.onLongPressHint, isNull);
      });

      testWidgets('keeps the long-press hint when a handler IS given', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tileSemantics(tester).hintOverrides?.onLongPressHint,
          isNotNull,
        );
      });
    });

    group('moderation avatar (#6283)', () {
      final moderationPubkey = kPinnedOfficialAccounts
          .firstWhere((account) => account.role == 'moderation')
          .pubkeyHex;

      Finder lockFinder() => find.byWidgetPredicate(
        (widget) =>
            widget is DivineIcon && widget.icon == DivineIconName.lockSimple,
        description: 'closed-thread lock',
      );

      Finder wordmarkFinder() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.logo,
        description: 'bundled Divine wordmark',
      );

      Future<void> pumpTileFor(
        WidgetTester tester,
        String counterparty, {
        String? picture,
      }) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              fetchUserProfileProvider(counterparty).overrideWith(
                (ref) async => UserProfile(
                  pubkey: counterparty,
                  displayName: 'Divine Moderation',
                  picture: picture,
                  rawData: const {},
                  createdAt: now,
                  eventId:
                      'cccccccccccccccccccccccccccccccccccccccccccccccccc'
                      'cccccccccccccc',
                ),
              ),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: DmConversation(
                  id:
                      'dddddddddddddddddddddddddddddddddddddddddddddddddd'
                      'dddddddddddddd',
                  participantPubkeys: [currentPubkey, counterparty],
                  isGroup: false,
                  createdAt: nowUnix,
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('an ordinary account keeps its kind-0 picture', (
        tester,
      ) async {
        await pumpTileFor(
          tester,
          otherPubkey,
          picture: 'https://divine.video/avatar.png',
        );

        expect(find.byType(VineCachedImage), findsOneWidget);
        expect(wordmarkFinder(), findsNothing);
      });

      testWidgets('the moderation account renders the bundled wordmark instead '
          'of its kind-0 picture', (tester) async {
        // divine-logo.svg colours itself through a <style> block that
        // flutter_svg's parser discards, so the account's own picture paints
        // opaque black on the dark inbox surface.
        await pumpTileFor(
          tester,
          moderationPubkey,
          picture: 'https://divine.video/divine-logo.svg',
        );

        expect(wordmarkFinder(), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
        // The wordmark is 3.8:1. Contain would letterbox the whole lockup
        // into an illegible sliver; cover crops it to the middle "Vi", which
        // is how divine-web frames the same artwork.
        expect(tester.widget<DivineIcon>(wordmarkFinder()).fit, BoxFit.cover);
      });

      testWidgets('a retired moderation pubkey is covered too', (tester) async {
        // A thread opened before the #2321 rotation stays keyed on the old
        // pubkey, and it is the same team on the other end of it.
        await pumpTileFor(tester, kLegacyModerationPubkeys.first);

        expect(wordmarkFinder(), findsOneWidget);
      });

      // The cases above stub a kind-0 that already carries the right name, so
      // they cannot catch the naming half. A retired key is the case that
      // still has no kind-0 to read anywhere — funnelcake answers for it with
      // `profile: null`, which maps to `UserProfileNotPublished` and
      // short-circuits the relay fallback outright, so the lookup can only
      // return null (#6416). The CURRENT key does resolve today: its kind-0
      // (`17e11af3…`, 2026-03-12) is on relay.divine.video and funnelcake
      // serves it — see mobile/docs/RETIRED_MODERATION_KEYS.md. The
      // substitution still has to hold for both, because a name the viewer
      // has never seen on an enforcement notice is the failure either way.
      group('with no profile to resolve', () {
        final l10n = lookupAppLocalizations(const Locale('en'));

        Future<void> pumpUnprofiledTileFor(
          WidgetTester tester,
          String counterparty,
        ) async {
          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                fetchUserProfileProvider(
                  counterparty,
                ).overrideWith((ref) async => null),
              ],
              home: Scaffold(
                body: ConversationTile(
                  conversation: DmConversation(
                    id:
                        'dddddddddddddddddddddddddddddddddddddddddddddddddd'
                        'dddddddddddddd',
                    participantPubkeys: [currentPubkey, counterparty],
                    isGroup: false,
                    createdAt: nowUnix,
                  ),
                  currentUserPubkey: currentPubkey,
                  onTap: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        testWidgets('a retired thread is still named as moderation', (
          tester,
        ) async {
          final retired = kLegacyModerationPubkeys.first;

          await pumpUnprofiledTileFor(tester, retired);

          expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
          expect(find.text(l10n.dmRetiredThreadClosedTitle), findsOneWidget);
          // Without the override this row rendered Divine's own wordmark
          // beside a generated "Adjective Animal N" stranger.
          expect(
            find.text(UserProfile.defaultDisplayNameFor(retired)),
            findsNothing,
          );
        });

        testWidgets('a retired thread is marked closed, not previewed', (
          tester,
        ) async {
          // Name and wordmark are deliberately identical to the live pinned
          // support row, so the closed sentence used to be the only thing
          // separating them — rendered in the preview's own slot, font and
          // colour, which reads as "the last thing they said" rather than as
          // a status (#7847). The lock is what makes it scan as one.
          await pumpUnprofiledTileFor(tester, kLegacyModerationPubkeys.first);

          expect(lockFinder(), findsOneWidget);
        });

        testWidgets('a live moderation thread carries no lock', (
          tester,
        ) async {
          await pumpUnprofiledTileFor(tester, moderationPubkey);

          expect(lockFinder(), findsNothing);
        });

        testWidgets('an ordinary thread carries no lock', (tester) async {
          await pumpUnprofiledTileFor(tester, otherPubkey);

          expect(lockFinder(), findsNothing);
        });

        testWidgets('the current key is named without a kind-0 too', (
          tester,
        ) async {
          await pumpUnprofiledTileFor(tester, moderationPubkey);

          expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        });

        testWidgets(
          'an ordinary account still falls back to a generated name',
          (
            tester,
          ) async {
            await pumpUnprofiledTileFor(tester, otherPubkey);

            expect(
              find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
              findsOneWidget,
            );
            expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
          },
        );
      });
    });

    group('deleted accounts', () {
      Future<void> pumpTile(
        WidgetTester tester, {
        required bool vanished,
        Locale? locale,
        bool identityResolving = false,
        bool settle = true,
      }) async {
        await tester.pumpWidget(
          testMaterialApp(
            locale: locale,
            additionalOverrides: [
              fetchUserProfileProvider(otherPubkey).overrideWith(
                (ref) async => createTestProfile(displayName: 'meylis.divine'),
              ),
              profileVanishedProvider(
                otherPubkey,
              ).overrideWith((ref) => vanished),
              profileIdentityResolvingProvider(
                otherPubkey,
              ).overrideWithValue(identityResolving),
            ],
            home: Scaffold(
              body: ConversationTile(
                conversation: createTestConversation(
                  lastMessageContent: 'hi',
                  lastMessageTimestamp: nowUnix,
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump();
          await tester.pump();
        }
      }

      testWidgets('replaces the display name for a deleted account', (
        tester,
      ) async {
        await pumpTile(tester, vanished: true);

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
        expect(find.text('meylis.divine'), findsNothing);
      });

      testWidgets('reads the deleted-account copy from l10n', (tester) async {
        // Pump in German and require the German string. Asserting the German
        // copy is *absent* from an English pump passes whether or not the
        // widget reads l10n, so it proved nothing.
        await pumpTile(tester, vanished: true, locale: const Locale('de'));

        final de = lookupAppLocalizations(const Locale('de'));
        expect(find.text(de.profileDeletedAccountName), findsOneWidget);
      });

      testWidgets('drops the avatar for a deleted account', (tester) async {
        await pumpTile(tester, vanished: true);

        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets('does not hide a deleted identity behind profile loading', (
        tester,
      ) async {
        await pumpTile(
          tester,
          vanished: true,
          identityResolving: true,
          settle: false,
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
        expect(
          tileSemantics(tester).label,
          contains(l10n.profileDeletedAccountName),
        );
        expect(
          tester
              .widgetList<Skeletonizer>(find.bySubtype<Skeletonizer>())
              .every((skeletonizer) => !skeletonizer.enabled),
          isTrue,
        );
      });

      testWidgets('leaves a live account untouched', (tester) async {
        await pumpTile(tester, vanished: false);

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text('meylis.divine'), findsOneWidget);
        expect(find.text(l10n.profileDeletedAccountName), findsNothing);
      });

      testWidgets('keeps the last message so the thread stays readable', (
        tester,
      ) async {
        // The messages are the viewer's own copy — a vanish cannot retract
        // them, and hiding them would destroy the viewer's history.
        await pumpTile(tester, vanished: true);

        expect(find.text('hi'), findsOneWidget);
      });
    });
  });
}
