// ABOUTME: Tests for the locked clip credit rows shown in the post form.
// ABOUTME: Covers names, the npub fallback, the viewer's own clips and no remove control.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_clip_credits.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../helpers/test_provider_overrides.dart';

const _viewer =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _author =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _otherAuthor =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

class _ClipManagerNotifier extends ClipManagerNotifier {
  _ClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

DivineVideoClip _clip(String id, List<String> authors) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  sourceCredits: [
    for (final author in authors)
      model.ClipSourceCredit.fromAddressableId(
        addressableId: '34236:$author:$id-$author',
      ),
  ],
);

Widget _build(
  List<DivineVideoClip> clips, {
  Map<String, model.UserProfile> profiles = const {},
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(
        createMockAuthService(currentPublicKeyHex: _viewer),
      ),
      clipManagerProvider.overrideWith(() => _ClipManagerNotifier(clips)),
      fetchUserProfileProvider.overrideWith(
        (ref, pubkey) async => profiles[pubkey],
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: VideoMetadataClipCredits()),
    ),
  );
}

void main() {
  group(VideoMetadataClipCredits, () {
    testWidgets('renders nothing when no clip carries a credit', (
      tester,
    ) async {
      await tester.pumpWidget(_build([_clip('own', const [])]));
      await tester.pump();

      expect(find.textContaining('Uses a clip from'), findsNothing);
    });

    testWidgets('shows the creator name for a reused clip', (tester) async {
      await tester.pumpWidget(
        _build(
          [
            _clip('one', const [_author]),
          ],
          profiles: {
            _author: model.UserProfile(
              pubkey: _author,
              rawData: const {},
              createdAt: DateTime(2026),
              eventId: 'e' * 64,
              displayName: 'Vine Fan',
            ),
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(_l10n.videoMetadataClipCreditRow('Vine Fan')),
        findsOneWidget,
      );
    });

    testWidgets('falls back to the full npub when no name is known', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build([
          _clip('one', const [_author]),
        ]),
      );
      await tester.pump();
      await tester.pump();

      final npub = NostrKeyUtils.encodePubKey(_author);
      expect(
        find.text(_l10n.videoMetadataClipCreditRow(npub)),
        findsOneWidget,
      );
      final text = tester.widget<Text>(
        find.text(_l10n.videoMetadataClipCreditRow(npub)),
      );
      expect(text.maxLines, equals(1));
      expect(text.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('lists each creator once and skips the viewer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build([
          _clip('one', const [_author, _viewer]),
          _clip('two', const [_author, _otherAuthor]),
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Uses a clip from'), findsNWidgets(2));
      expect(
        find.textContaining(NostrKeyUtils.encodePubKey(_viewer)),
        findsNothing,
      );
    });

    testWidgets('has no tappable control and exposes the text to semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _build([
          _clip('one', const [_author]),
        ]),
      );
      await tester.pump();
      await tester.pump();

      final label = _l10n.videoMetadataClipCreditRow(
        NostrKeyUtils.encodePubKey(_author),
      );
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      handle.dispose();
    });
  });
}
