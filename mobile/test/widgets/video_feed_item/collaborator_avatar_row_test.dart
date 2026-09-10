// ABOUTME: Widget tests for status-aware CollaboratorAvatarRow rendering.
// ABOUTME: Tests CollaboratorAvatarRowBody directly via CollaboratorVisibility.

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/video_feed_item/collaborator_avatar_row.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

Finder _divineIcon(DivineIconName icon) => find.byWidgetPredicate(
  (widget) => widget is DivineIcon && widget.icon == icon,
);

const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collab1 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collab2 =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _collab3 =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _thirdPartyPubkey =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

UserProfile _makeProfile(String pubkey, String name) => UserProfile(
  pubkey: pubkey,
  displayName: name,
  name: name.toLowerCase(),
  rawData: const {},
  createdAt: DateTime(2025),
  eventId: 'evt_$pubkey',
);

VideoEvent _video({List<String> collaborators = const []}) => VideoEvent(
  id: 'test_video_id_00000000000000000000000000000000000000000000000000',
  pubkey: _creatorPubkey,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  videoUrl: 'https://example.com/video.mp4',
  collaboratorPubkeys: collaborators,
);

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

AppLocalizations get _l10n => lookupAppLocalizations(const Locale('en'));

void main() {
  group(CollaboratorAvatarRow, () {
    testWidgets('renders SizedBox.shrink when video has no collaborators', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(CollaboratorAvatarRow(video: _video())));
      expect(_divineIcon(DivineIconName.users), findsNothing);
    });
  });

  group(CollaboratorAvatarRowBody, () {
    testWidgets(
      'fallback mode: renders all tagged pubkeys with no decoration',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CollaboratorAvatarRowBody(
              visibility: CollaboratorVisibility.fallback(
                taggedPubkeys: [_collab1, _collab2],
              ),
            ),
          ),
        );

        expect(_divineIcon(DivineIconName.users), findsOneWidget);
        expect(find.byType(Opacity), findsNothing);
      },
    );

    testWidgets(
      'inviter view: pending collaborator avatar dimmed with semantic label',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CollaboratorAvatarRowBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collab1, _collab2],
                statusByPubkey: {
                  _collab1: CollaboratorStatus.pending,
                  _collab2: CollaboratorStatus.confirmed,
                },
                currentUserPubkey: _creatorPubkey,
                creatorPubkey: _creatorPubkey,
              ),
            ),
          ),
        );

        // Exactly one avatar is wrapped in Opacity (the pending one).
        final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
        expect(opacityWidgets, hasLength(1));
        expect(opacityWidgets.first.opacity, closeTo(0.55, 0.001));

        // Pending semantic label present on the dimmed avatar (find via
        // widget predicate so the test doesn't need ensureSemantics).
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label ==
                    _l10n.videoCollaboratorPendingSemanticLabel,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('inviter view: pending count appears in label suffix', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CollaboratorAvatarRowBody(
            visibility: CollaboratorVisibility(
              taggedPubkeys: [_collab1, _collab2],
              statusByPubkey: {
                _collab1: CollaboratorStatus.pending,
                _collab2: CollaboratorStatus.pending,
              },
              currentUserPubkey: _creatorPubkey,
              creatorPubkey: _creatorPubkey,
            ),
          ),
          overrides: [
            fetchUserProfileProvider(
              _collab1,
            ).overrideWith((ref) async => _makeProfile(_collab1, 'Alice')),
            fetchUserProfileProvider(
              _collab2,
            ).overrideWith((ref) async => _makeProfile(_collab2, 'Bob')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final base = _l10n.videoCollaboratorWithMore('Alice', 1);
      final expectedLabel = _l10n.videoCollaboratorWithPendingSuffix(base, 2);
      expect(find.text(expectedLabel), findsOneWidget);
    });

    testWidgets('recipient view (ignored): own avatar filtered out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CollaboratorAvatarRowBody(
            visibility: CollaboratorVisibility(
              taggedPubkeys: [_collab1, _collab2],
              statusByPubkey: {
                _collab1: CollaboratorStatus.ignored,
                _collab2: CollaboratorStatus.confirmed,
              },
              currentUserPubkey: _collab1,
              creatorPubkey: _creatorPubkey,
              isResolved: true,
            ),
          ),
          overrides: [
            fetchUserProfileProvider(
              _collab1,
            ).overrideWith((ref) async => _makeProfile(_collab1, 'Alice')),
            fetchUserProfileProvider(
              _collab2,
            ).overrideWith((ref) async => _makeProfile(_collab2, 'Bob')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Row still renders for _collab2.
      expect(_divineIcon(DivineIconName.users), findsOneWidget);
      // Label is the single-collaborator variant naming Bob — not Alice.
      expect(find.text(_l10n.videoCollaboratorWithOne('Bob')), findsOneWidget);
      expect(find.text(_l10n.videoCollaboratorWithOne('Alice')), findsNothing);
      // No pending decoration on recipient view.
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('recipient view (ignored, sole collaborator): row shrinks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CollaboratorAvatarRowBody(
            visibility: CollaboratorVisibility(
              taggedPubkeys: [_collab1],
              statusByPubkey: {_collab1: CollaboratorStatus.ignored},
              currentUserPubkey: _collab1,
              creatorPubkey: _creatorPubkey,
              isResolved: true,
            ),
          ),
        ),
      );

      expect(_divineIcon(DivineIconName.users), findsNothing);
    });

    testWidgets(
      'recipient view (confirmed): own avatar visible without decoration',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CollaboratorAvatarRowBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collab1],
                statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
                currentUserPubkey: _collab1,
                creatorPubkey: _creatorPubkey,
                isResolved: true,
              ),
            ),
          ),
        );

        expect(_divineIcon(DivineIconName.users), findsOneWidget);
        expect(find.byType(Opacity), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label ==
                    _l10n.videoCollaboratorPendingSemanticLabel,
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'third-party view: unconfirmed collaborators are not rendered at all',
      (tester) async {
        // Pre-#6907 this row rendered every creator-tagged pubkey to third
        // parties, so tagging someone publicly credited them whether or not
        // they ever accepted.
        await tester.pumpWidget(
          _wrap(
            const CollaboratorAvatarRowBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collab1, _collab2],
                statusByPubkey: {
                  _collab1: CollaboratorStatus.pending,
                  _collab2: CollaboratorStatus.pending,
                },
                currentUserPubkey: _thirdPartyPubkey,
                creatorPubkey: _creatorPubkey,
                isResolved: true,
              ),
            ),
          ),
        );

        expect(_divineIcon(DivineIconName.users), findsNothing);
      },
    );

    testWidgets(
      'third-party view: renders nothing until the query resolves',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CollaboratorAvatarRowBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collab1],
                statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
                currentUserPubkey: _thirdPartyPubkey,
                creatorPubkey: _creatorPubkey,
              ),
            ),
          ),
        );

        expect(_divineIcon(DivineIconName.users), findsNothing);
      },
    );

    testWidgets(
      'third-party view: confirmed collaborators render without decoration',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CollaboratorAvatarRowBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collab1, _collab2],
                statusByPubkey: {
                  _collab1: CollaboratorStatus.pending,
                  _collab2: CollaboratorStatus.confirmed,
                },
                currentUserPubkey: _thirdPartyPubkey,
                creatorPubkey: _creatorPubkey,
                isResolved: true,
              ),
            ),
            overrides: [
              fetchUserProfileProvider(
                _collab1,
              ).overrideWith((ref) async => _makeProfile(_collab1, 'Alice')),
              fetchUserProfileProvider(
                _collab2,
              ).overrideWith((ref) async => _makeProfile(_collab2, 'Bob')),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.users), findsOneWidget);
        expect(
          find.text(_l10n.videoCollaboratorWithOne('Bob')),
          findsOneWidget,
        );
        expect(
          find.text(_l10n.videoCollaboratorWithOne('Alice')),
          findsNothing,
        );
        // Third-party viewers never see the pending decoration.
        expect(find.byType(Opacity), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label ==
                    _l10n.videoCollaboratorPendingSemanticLabel,
          ),
          findsNothing,
        );
      },
    );

    testWidgets('multi-collaborator row opens picker with every collaborator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CollaboratorAvatarRowBody(
            visibility: CollaboratorVisibility.fallback(
              taggedPubkeys: [_collab1, _collab2, _collab3],
            ),
          ),
          overrides: [
            fetchUserProfileProvider(
              _collab1,
            ).overrideWith((ref) async => _makeProfile(_collab1, 'Alice')),
            fetchUserProfileProvider(
              _collab2,
            ).overrideWith((ref) async => _makeProfile(_collab2, 'Bob')),
            fetchUserProfileProvider(
              _collab3,
            ).overrideWith((ref) async => _makeProfile(_collab3, 'Casey')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(_l10n.videoCollaboratorWithMore('Alice', 2)),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '${_l10n.metadataCollaboratorsLabel}: 3',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == _l10n.videoCollaboratorCountLabel(3),
        ),
        findsNothing,
      );

      await tester.tap(find.text(_l10n.videoCollaboratorWithMore('Alice', 2)));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.metadataCollaboratorsLabel), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Casey'), findsOneWidget);
    });

    testWidgets('expanded picker omits collaborator ignored by current user', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CollaboratorAvatarRowBody(
            visibility: CollaboratorVisibility(
              taggedPubkeys: [_collab1, _collab2, _collab3],
              statusByPubkey: {
                _collab1: CollaboratorStatus.ignored,
                _collab2: CollaboratorStatus.confirmed,
                _collab3: CollaboratorStatus.confirmed,
              },
              currentUserPubkey: _collab1,
              creatorPubkey: _creatorPubkey,
              isResolved: true,
            ),
          ),
          overrides: [
            fetchUserProfileProvider(
              _collab1,
            ).overrideWith((ref) async => _makeProfile(_collab1, 'Alice')),
            fetchUserProfileProvider(
              _collab2,
            ).overrideWith((ref) async => _makeProfile(_collab2, 'Bob')),
            fetchUserProfileProvider(
              _collab3,
            ).overrideWith((ref) async => _makeProfile(_collab3, 'Casey')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(_l10n.videoCollaboratorWithMore('Bob', 1)));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.metadataCollaboratorsLabel), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Casey'), findsOneWidget);
    });
  });
}
