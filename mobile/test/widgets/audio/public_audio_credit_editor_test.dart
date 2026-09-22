// ABOUTME: Widget tests for the shared public sound credit editor.
// ABOUTME: Edits reach onChanged as a full attribution; source shows only when
// ABOUTME: the sound is not the user's own work.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/widgets/audio/public_audio_credit_editor.dart';

const _ownWork = AudioShareAttribution(
  title: 'Kitchen beat',
  creatorName: 'Alice',
  creatorPubkey: 'a',
  publicTags: ['beat'],
  confirmedOwnWork: true,
);

/// Hosts the editor the way its owners do: holds the attribution and feeds
/// every edit back in.
class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.changes});

  final AudioShareAttribution initial;
  final List<AudioShareAttribution> changes;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late AudioShareAttribution _attribution = widget.initial;

  @override
  Widget build(BuildContext context) {
    return PublicAudioCreditEditor(
      attribution: _attribution,
      onChanged: (next) {
        widget.changes.add(next);
        setState(() => _attribution = next);
      },
    );
  }
}

void main() {
  late List<AudioShareAttribution> changes;
  late AppLocalizations l10n;

  setUp(() {
    changes = [];
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    AudioShareAttribution initial = _ownWork,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: _Host(initial: initial, changes: changes),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, Key key) => tester
      .widget<TextField>(
        find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
      )
      .controller!
      .text;

  group(PublicAudioCreditEditor, () {
    group('renders', () {
      testWidgets('seeds every field from the attribution', (tester) async {
        await pumpEditor(tester);

        expect(
          fieldText(tester, const Key('audio_credit_title')),
          'Kitchen beat',
        );
        expect(fieldText(tester, const Key('audio_credit_creator')), 'Alice');
        expect(fieldText(tester, const Key('audio_credit_tags')), '#beat');
        expect(find.byKey(const Key('audio_credit_source')), findsNothing);
        expect(
          find.text('Kitchen beat · ${l10n.soundCreatorBy('Alice')}'),
          findsOneWidget,
        );
      });

      testWidgets("shows the source field for somebody else's work", (
        tester,
      ) async {
        await pumpEditor(
          tester,
          initial: _ownWork.copyWith(
            confirmedOwnWork: false,
            sourceUrl: 'https://example.com/source',
          ),
        );

        expect(
          fieldText(tester, const Key('audio_credit_source')),
          'https://example.com/source',
        );
      });
    });

    group('interactions', () {
      testWidgets('hands each edit back as a full attribution', (
        tester,
      ) async {
        await pumpEditor(tester);

        await tester.enterText(
          find.byKey(const Key('audio_credit_title')),
          'Bathroom beat',
        );
        await tester.enterText(
          find.byKey(const Key('audio_credit_tags')),
          '#Beat, kitchen beat',
        );
        await tester.pumpAndSettle();

        expect(changes.last.title, 'Bathroom beat');
        expect(changes.last.creatorName, 'Alice');
        expect(changes.last.creatorPubkey, 'a');
        expect(changes.last.publicTags, ['beat', 'kitchen']);
        expect(
          find.text('Bathroom beat · ${l10n.soundCreatorBy('Alice')}'),
          findsOneWidget,
        );
      });

      testWidgets('reveals the source field when own work is unticked', (
        tester,
      ) async {
        await pumpEditor(tester);

        await tester.tap(find.text(l10n.soundOwnWork));
        await tester.pumpAndSettle();

        expect(changes.last.confirmedOwnWork, isFalse);
        expect(find.byKey(const Key('audio_credit_source')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('audio_credit_source')),
          'https://example.com/source',
        );
        expect(changes.last.sourceUrl, 'https://example.com/source');
        expect(changes.last.isValid, isTrue);
      });
    });
  });
}
