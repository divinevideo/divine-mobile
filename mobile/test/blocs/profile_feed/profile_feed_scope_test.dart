// ABOUTME: Verifies profile-feed state transitions surface localized snackbars.
// ABOUTME: Covers every pin-feedback mapping and the pagination error listener.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_scope.dart';
import 'package:openvine/l10n/l10n.dart';

class _MockProfileFeedCubit extends MockCubit<ProfileFeedState>
    implements ProfileFeedCubit {}

void main() {
  final pinFeedbackCases =
      <
        (
          ProfileFeedPinFeedback,
          String Function(AppLocalizations),
        )
      >[
        (
          ProfileFeedPinFeedback.pinned,
          (l10n) => l10n.profilePinSuccess,
        ),
        (
          ProfileFeedPinFeedback.unpinned,
          (l10n) => l10n.profileUnpinSuccess,
        ),
        (
          ProfileFeedPinFeedback.pinLimitReached,
          (l10n) => l10n.profilePinLimitReached(
            ProfileFeedState.maxPinnedVideos,
          ),
        ),
        (
          ProfileFeedPinFeedback.pinConnectionFailed,
          (l10n) => l10n.profilePinConnectionFailed,
        ),
        (
          ProfileFeedPinFeedback.pinFailed,
          (l10n) => l10n.profilePinFailed,
        ),
        (
          ProfileFeedPinFeedback.unpinFailed,
          (l10n) => l10n.profileUnpinFailed,
        ),
      ];

  group('renders', () {
    for (final testCase in pinFeedbackCases) {
      testWidgets('shows the ${testCase.$1.name} snackbar', (tester) async {
        final cubit = _MockProfileFeedCubit();
        final states = StreamController<ProfileFeedState>();
        addTearDown(states.close);
        whenListen(
          cubit,
          states.stream,
          initialState: const ProfileFeedState(),
        );
        addTearDown(cubit.close);

        await tester.pumpWidget(_TestApp(cubit: cubit));
        states.add(ProfileFeedState(pinFeedback: testCase.$1));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(testCase.$2(l10n)), findsOneWidget);
      });
    }

    testWidgets('shows the load-more error snackbar', (tester) async {
      final cubit = _MockProfileFeedCubit();
      final states = StreamController<ProfileFeedState>();
      addTearDown(states.close);
      whenListen(
        cubit,
        states.stream,
        initialState: const ProfileFeedState(),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_TestApp(cubit: cubit));
      states.add(const ProfileFeedState(hasLoadMoreError: true));
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileFeedLoadMoreError), findsOneWidget);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.cubit});

  final ProfileFeedCubit cubit;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<ProfileFeedCubit>.value(
          value: cubit,
          child: const ProfileFeedFeedbackListeners(
            child: SizedBox(),
          ),
        ),
      ),
    );
  }
}
