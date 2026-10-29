import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart' hide ChallengeView;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_deadline.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../packages/challenges_repository/test/harness.dart';

void main() {
  group('challenge deadlines', () {
    test(
      'explicit display instant preserves date boundary, locale and zone',
      () async {
        await initializeDateFormatting('fr');
        final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
        final instant = DateTime.parse('2030-01-01T00:30:00+13:00');
        expect(
          challengeDeadlineText(l10n, instant),
          'Deadline: 31 déc. 2029 11:30 (UTC)',
        );
      },
    );
    test(
      'organizer time converts the instant through the signed zone and DST',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
        await initializeDateFormatting('fr');
        final instant = DateTime.utc(2030, 1, 1, 5, 30);
        expect(
          challengeOrganizerTimeText(l10n, instant, 'Pacific/Auckland'),
          'Organizer time: 1 janv. 2030 18:30 (NZDT, Pacific/Auckland)',
        );
        expect(
          challengeOrganizerTimeText(l10n, instant, 'Unknown/Synthetic'),
          isNull,
        );
        tzdata.initializeTimeZones();
        expect(
          challengeDeadlineText(
            l10n,
            tz.TZDateTime.from(instant, tz.getLocation('Pacific/Auckland')),
          ),
          'Deadline: 1 janv. 2030 18:30 (NZDT)',
        );
      },
    );
    testWidgets(
      'detail and review show the local instant and use the app locale',
      (
        tester,
      ) async {
        final h = Harness();
        final end =
            DateTime.parse('2030-01-01T18:30:00+13:00')
                .millisecondsSinceEpoch ~/
            1000;
        h.definition = NostrEvent.fromJson(
          h.organizer.definition(start: end - 3600, end: end),
        );
        h.now = end - 1800;
        h.source.records = [jsonEncode(h.definition.toJson())];
        final coordinate = '31923:${h.organizer.pubkey}:synthetic:challenge';
        final cubit = ChallengeParticipationCubit(
          coordinate: coordinate,
          submissions: h.repository,
          refresh: () => h.reads.refresh(coordinate),
          loadCandidates: () async => [],
          exactVideo: (_) async => h.video,
          clientTags: () async => [],
          prepareRecording: (_) async => 'recording',
          handoffs: () async => [],
          reviewPublished: (_) => h.prepare(),
        );
        addTearDown(cubit.close);
        await cubit.load();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: ChallengeView(onRecord: (_, _) async {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final local = DateTime.fromMillisecondsSinceEpoch(
          end * 1000,
          isUtc: true,
        ).toLocal();
        final expected =
            'Deadline: ${DateFormat.yMMMd('fr').add_Hm().format(local)} (${local.timeZoneName})';
        expect(find.text(expected), findsOneWidget);
        await cubit.selectVideo(h.video.id);
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(h.signatures, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
