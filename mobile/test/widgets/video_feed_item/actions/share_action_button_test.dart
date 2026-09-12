// ABOUTME: Tests for ShareActionButton widget
// ABOUTME: Verifies share icon renders, share sheet opens with correct sections,
// ABOUTME: and standard action items display in the unified share sheet.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  group(ShareActionButton, () {
    const ownPubkey =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

    late VideoEvent testVideo;
    late _MockFollowRepository mockFollowRepository;
    late _MockProfileRepository mockProfileRepository;
    late _MockVideoSharingService mockVideoSharingService;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      mockVideoSharingService = _MockVideoSharingService();
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      mockProfileRepository = _MockProfileRepository();
      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.getCachedProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <UserProfile>[]);
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <String, UserProfile>{});

      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey: ownPubkey,
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
    });

    testWidgets('renders share icon button', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      expect(find.byType(ShareActionButton), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('renders $DivineIcon with shareFatDuo icon', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();

      expect(
        divineIcons.any((icon) => icon.icon == DivineIconName.shareFatDuo),
        isTrue,
        reason: 'Should render shareFatDuo DivineIcon',
      );
    });

    testWidgets('has correct accessibility semantics', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      // Find Semantics widget with share button label
      final semanticsFinder = find.bySemanticsLabel('Share video');
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('calls onInteracted before opening the share sheet', (
      tester,
    ) async {
      var interacted = false;
      final mockAuth = createMockAuthService();

      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: ShareActionButton(
              video: testVideo,
              onInteracted: () => interacted = true,
            ),
          ),
          additionalOverrides: [
            videoSharingServiceProvider.overrideWith(
              (ref) => mockVideoSharingService,
            ),
          ],
          mockAuthService: mockAuth,
          mockProfileRepository: mockProfileRepository,
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(interacted, isTrue);
    });

    group('share menu', () {
      testWidgets('shows Share with section', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Share with'), findsOneWidget);
      });

      testWidgets('shows Find people button', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Find\npeople'), findsOneWidget);
      });

      testWidgets('shows More actions section', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('More actions'), findsOneWidget);
      });

      testWidgets(
        'keeps owner actions aligned with provider scope when auth changes',
        (tester) async {
          final mockAuth = createMockAuthService();
          late StateSetter rebuildHost;
          await tester.pumpWidget(
            testMaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  rebuildHost = setState;
                  return Scaffold(
                    body: ShareActionButton(video: testVideo),
                  );
                },
              ),
              additionalOverrides: [
                videoSharingServiceProvider.overrideWith(
                  (ref) => mockVideoSharingService,
                ),
              ],
              mockAuthService: mockAuth,
              mockProfileRepository: mockProfileRepository,
            ),
          );
          await tester.tap(find.byType(GestureDetector));
          await tester.pumpAndSettle();
          expect(find.text('Delete video'), findsNothing);

          when(() => mockAuth.currentPublicKeyHex).thenReturn(ownPubkey);
          rebuildHost(() {});
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text('Delete video'), findsNothing);
        },
      );

      testWidgets('shows standard action items', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Save Video'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Share via'), findsOneWidget);
      });

      testWidgets('copy action responds when tapping the icon-label gap', (
        tester,
      ) async {
        final mockAuth = createMockAuthService();
        when(
          () => mockVideoSharingService.generateShareUrl(any()),
        ).thenReturn('https://divine.video/v/test');

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        final copyIcon = find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon && widget.icon == DivineIconName.linkSimple,
        );
        final copyLabel = find.text('Copy');
        expect(copyIcon, findsOneWidget);
        expect(copyLabel, findsOneWidget);

        final iconRect = tester.getRect(copyIcon);
        final labelRect = tester.getRect(copyLabel);

        await tester.tapAt(
          Offset(iconRect.center.dx, (iconRect.bottom + labelRect.top) / 2),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).shareCopiedPostLink,
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows own-video download actions for owned content', (
        tester,
      ) async {
        final mockAuth = createMockAuthService(
          authState: AuthState.authenticated,
          currentPublicKeyHex: ownPubkey,
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
            mockFollowRepository: mockFollowRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Save to Gallery'), findsOneWidget);
        expect(find.text('Save with Watermark'), findsOneWidget);
      });

      group('recipient selection', () {
        const alice = ShareableUser(
          pubkey:
              'fedcba9876543210fedcba9876543210'
              'fedcba9876543210fedcba9876543210',
          displayName: 'Alice',
        );
        const bob = ShareableUser(
          pubkey:
              '11111111111111111111111111111111'
              '11111111111111111111111111111111',
          displayName: 'Bob',
        );

        late AppLocalizations l10n;

        setUp(() {
          l10n = lookupAppLocalizations(const Locale('en'));
          when(
            () => mockVideoSharingService.recentlySharedWith,
          ).thenReturn([alice, bob]);
        });

        // #8421: the "Share with" row is a DM send target — tapping a contact
        // hands it to ShareSheetBloc, which routes to DmRepository.sendMessage
        // — so it must name and picture its peer the way the inbox does.
        group('DM peer identity', () {
          const vanished = ShareableUser(
            pubkey:
                'b75b9a3131f4263add94ba20beb352a1'
                '1032684f2dac07a7e1af827c6f3c1505',
            displayName: 'Aeontropy',
            picture: 'https://example.invalid/aeontropy.png',
          );
          const moderation = ShareableUser(
            pubkey: kModerationPubkeyHex,
            displayName: 'moderation-bot-v2',
          );

          Future<void> pumpWithContact(
            WidgetTester tester,
            ShareableUser contact, {
            bool isVanished = false,
          }) async {
            when(
              () => mockVideoSharingService.recentlySharedWith,
            ).thenReturn([contact]);

            await tester.pumpWidget(
              testMaterialApp(
                home: Scaffold(body: ShareActionButton(video: testVideo)),
                additionalOverrides: [
                  videoSharingServiceProvider.overrideWith(
                    (ref) => mockVideoSharingService,
                  ),
                  profileVanishedProvider(
                    contact.pubkey,
                  ).overrideWith((ref) => isVanished),
                ],
                mockAuthService: createMockAuthService(),
                mockProfileRepository: mockProfileRepository,
                mockFollowRepository: mockFollowRepository,
              ),
            );
            await tester.tap(find.byType(ShareActionButton));
            await tester.pumpAndSettle();
          }

          testWidgets('names a vanished peer "Deleted account"', (
            tester,
          ) async {
            await pumpWithContact(tester, vanished, isVanished: true);

            expect(
              find.text(l10n.profileDeletedAccountName),
              findsOneWidget,
            );
            expect(find.text('Aeontropy'), findsNothing);
          });

          testWidgets('gives the moderation account its bundled wordmark and '
              'shared name', (tester) async {
            await pumpWithContact(tester, moderation);

            expect(find.byType(ModerationAvatar), findsOneWidget);
            expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
            expect(find.text('moderation-bot-v2'), findsNothing);
          });

          testWidgets('announces the resolved name when a peer is selected', (
            tester,
          ) async {
            await pumpWithContact(tester, vanished, isVanished: true);

            await tester.tap(find.text(l10n.profileDeletedAccountName));
            await tester.pumpAndSettle();

            // The selection chip in the composer header names the recipient
            // the row named, not the kind-0 identity behind it.
            expect(find.text('Aeontropy'), findsNothing);
          });
        });

        Future<void> pumpOpenSheet(WidgetTester tester) async {
          final mockAuth = createMockAuthService();

          await tester.pumpWidget(
            testMaterialApp(
              home: Scaffold(body: ShareActionButton(video: testVideo)),
              additionalOverrides: [
                videoSharingServiceProvider.overrideWith(
                  (ref) => mockVideoSharingService,
                ),
              ],
              mockAuthService: mockAuth,
              mockProfileRepository: mockProfileRepository,
              mockFollowRepository: mockFollowRepository,
            ),
          );

          await tester.tap(find.byType(ShareActionButton));
          await tester.pumpAndSettle();
        }

        testWidgets(
          'tapping a contact selects it and swaps more actions for the '
          'message composer without sending',
          (tester) async {
            await pumpOpenSheet(tester);
            expect(find.text('More actions'), findsOneWidget);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            expect(find.byType(TextField), findsOneWidget);
            expect(find.text('More actions'), findsNothing);
            verifyNever(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            );
          },
        );

        testWidgets('pending cache-miss rows are not selectable', (
          tester,
        ) async {
          const unknownPubkey =
              '22222222222222222222222222222222'
              '22222222222222222222222222222222';
          final hydration = Completer<Map<String, UserProfile>>();
          when(() => mockVideoSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([unknownPubkey]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: [unknownPubkey],
            ),
          ).thenAnswer((_) => hydration.future);

          await pumpOpenSheet(tester);

          expect(find.text('Username'), findsOneWidget);

          await tester.tap(find.text('Username'), warnIfMissed: false);
          await tester.pump();

          final blocContext = tester.element(find.text('Share with'));
          expect(
            blocContext.read<ShareSheetBloc>().state.selectedRecipients,
            isEmpty,
          );
          expect(find.byType(TextField), findsNothing);
        });

        testWidgets(
          'tapping the last selected contact again deselects, restores '
          'more actions, and drops the draft',
          (tester) async {
            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'draft text');

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            expect(find.byType(TextField), findsNothing);
            expect(find.text('More actions'), findsOneWidget);

            // Re-selecting shows an empty composer — the draft was dropped.
            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            final field = tester.widget<TextField>(find.byType(TextField));
            expect(field.controller!.text, isEmpty);
          },
        );

        testWidgets(
          'tapping more contacts adds them to the selection and keeps '
          'the draft',
          (tester) async {
            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'draft text');

            await tester.tap(find.text('Bob'));
            await tester.pumpAndSettle();

            final blocContext = tester.element(find.text('Share with'));
            expect(
              blocContext.read<ShareSheetBloc>().state.selectedRecipients.map(
                (u) => u.pubkey,
              ),
              equals([alice.pubkey, bob.pubkey]),
            );
            final field = tester.widget<TextField>(find.byType(TextField));
            expect(field.controller!.text, equals('draft text'));
          },
        );

        testWidgets(
          'deselecting one of several recipients keeps the composer open',
          (tester) async {
            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Bob'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'draft text');

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            final blocContext = tester.element(find.text('Share with'));
            expect(
              blocContext.read<ShareSheetBloc>().state.selectedRecipients.map(
                (u) => u.pubkey,
              ),
              equals([bob.pubkey]),
            );
            final field = tester.widget<TextField>(find.byType(TextField));
            expect(field.controller!.text, equals('draft text'));
          },
        );

        testWidgets(
          'sending to multiple recipients shows the plural snackbar with '
          'no View chat action',
          (tester) async {
            when(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            ).thenAnswer(
              (_) async => {
                alice.pubkey: ShareResult.createSuccess('msg-1'),
                bob.pubkey: ShareResult.createSuccess('msg-2'),
              },
            );

            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Bob'));
            await tester.pumpAndSettle();

            await tester.tap(
              find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.arrowUp,
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Share with'), findsNothing);
            expect(
              find.text(l10n.sharePostSharedWithCount(2)),
              findsOneWidget,
            );
            expect(find.text(l10n.dmReelReplyViewChat), findsNothing);
          },
        );

        testWidgets(
          'send success dismisses the sheet and shows a snackbar with a '
          'View chat action',
          (tester) async {
            when(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            ).thenAnswer(
              (_) async => {
                alice.pubkey: ShareResult.createSuccess(
                  'msg-event-id',
                  conversationId: 'conversation-1',
                ),
              },
            );

            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            await tester.tap(
              find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.arrowUp,
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Share with'), findsNothing);
            expect(
              find.text(l10n.sharePostSharedWith('Alice')),
              findsOneWidget,
            );
            expect(find.text(l10n.dmReelReplyViewChat), findsOneWidget);
          },
        );

        testWidgets(
          'send success without a conversation id shows no View chat action',
          (tester) async {
            when(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            ).thenAnswer(
              (_) async => {
                alice.pubkey: ShareResult.createSuccess('msg-event-id'),
              },
            );

            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            await tester.tap(
              find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.arrowUp,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.text(l10n.sharePostSharedWith('Alice')),
              findsOneWidget,
            );
            expect(find.text(l10n.dmReelReplyViewChat), findsNothing);
          },
        );
      });

      testWidgets(
        'lifts message field above the keyboard when a recipient is selected',
        (tester) async {
          // Tall surface + dpr 1 so the short sheet stays bottom-anchored and
          // logical pixels equal physical pixels for the inset math.
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = const Size(1200, 6000);
          addTearDown(tester.view.reset);

          final mockAuth = createMockAuthService();

          await tester.pumpWidget(
            testMaterialApp(
              home: Scaffold(body: ShareActionButton(video: testVideo)),
              additionalOverrides: [
                videoSharingServiceProvider.overrideWith(
                  (ref) => mockVideoSharingService,
                ),
              ],
              mockAuthService: mockAuth,
              mockProfileRepository: mockProfileRepository,
            ),
          );

          await tester.tap(find.byType(GestureDetector));
          await tester.pumpAndSettle();

          // Select a recipient so the message TextField is shown.
          final blocContext = tester.element(find.text('Share with'));
          blocContext.read<ShareSheetBloc>().add(
            const ShareSheetRecipientToggled(
              ShareableUser(
                pubkey:
                    'fedcba9876543210fedcba9876543210'
                    'fedcba9876543210fedcba9876543210',
                displayName: 'Alice',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);

          // Simulate the keyboard opening.
          const keyboardHeight = 320.0;
          tester.view.viewInsets = const FakeViewPadding(
            bottom: keyboardHeight,
          );
          await tester.pumpAndSettle();

          final logicalHeight =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          final keyboardTop = logicalHeight - keyboardHeight;

          // The field must sit above the keyboard, not behind it.
          expect(
            tester.getBottomLeft(find.byType(TextField)).dy,
            lessThanOrEqualTo(keyboardTop),
          );
        },
      );
    });
  });
}
