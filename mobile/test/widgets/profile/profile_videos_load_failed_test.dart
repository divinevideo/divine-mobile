import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/profile_videos_load_failed.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileFeedCubit extends MockBloc<ProfileFeedEvent, ProfileFeedState>
    implements ProfileFeedCubit {}

void main() {
  group(ProfileVideosLoadFailed, () {
    late _MockProfileFeedCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    void stubState({bool isRefreshing = false}) => whenListen(
      cubit,
      const Stream<ProfileFeedState>.empty(),
      initialState: ProfileFeedState(
        status: ProfileFeedStatus.failure,
        isRefreshing: isRefreshing,
      ),
    );

    setUp(() {
      cubit = _MockProfileFeedCubit();
    });

    Future<void> pumpSubject(
      WidgetTester tester, {
      bool isOwnProfile = true,
      double tabHeight = 300,
    }) async {
      // iPhone 17 width, where the title and subtitle wrap like on a device.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: tabHeight,
                child: BlocProvider<ProfileFeedCubit>.value(
                  value: cubit,
                  child: ProfileVideosLoadFailed(isOwnProfile: isOwnProfile),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('names your videos on your own profile', (tester) async {
        stubState();
        await pumpSubject(tester);

        expect(find.text(l10n.profileVideosLoadFailedTitle), findsOneWidget);
        expect(find.text(l10n.profileVideosLoadFailedOtherTitle), findsNothing);
        expect(
          find.text(l10n.profileVideosLoadFailedSubtitle),
          findsOneWidget,
        );
        expect(find.text(l10n.profileVideosLoadFailedRetry), findsOneWidget);
      });

      testWidgets("drops 'your' on someone else's profile", (tester) async {
        stubState();
        await pumpSubject(tester, isOwnProfile: false);

        expect(
          find.text(l10n.profileVideosLoadFailedOtherTitle),
          findsOneWidget,
        );
        expect(find.text(l10n.profileVideosLoadFailedTitle), findsNothing);
      });

      testWidgets('centers the message in a tab with room for it', (
        tester,
      ) async {
        stubState();
        await pumpSubject(tester);

        final top = tester
            .getTopLeft(find.text(l10n.profileVideosLoadFailedTitle))
            .dy;
        final bottom = tester.getBottomLeft(find.byType(DivineButton)).dy;
        expect((top + bottom) / 2, moreOrLessEquals(150, epsilon: 1));
      });

      // Measured at iPhone 17 size: the Videos tab is the space left under the
      // header, 165 points without a bio and 89 under a NIP-05 and a
      // two-line bio. Copy lengths below are English.
      testWidgets('keeps Try again on screen under a header without a bio', (
        tester,
      ) async {
        stubState();
        await pumpSubject(tester, tabHeight: 165);

        expect(
          tester.getBottomLeft(find.byType(DivineButton)).dy,
          lessThanOrEqualTo(165),
        );
      });

      testWidgets('keeps the message readable in the shortest tab', (
        tester,
      ) async {
        stubState();
        await pumpSubject(tester, tabHeight: 89);

        expect(
          tester
              .getBottomLeft(find.text(l10n.profileVideosLoadFailedSubtitle))
              .dy,
          lessThanOrEqualTo(89),
        );
      });
    });

    group('interactions', () {
      testWidgets('Try again asks the feed to load again', (tester) async {
        stubState();
        await pumpSubject(tester);

        await tester.tap(find.text(l10n.profileVideosLoadFailedRetry));

        verify(() => cubit.add(const ProfileFeedRetryRequested())).called(1);
      });

      testWidgets('Try again is disabled while a retry is running', (
        tester,
      ) async {
        stubState(isRefreshing: true);
        await pumpSubject(tester);

        await tester.tap(find.byType(DivineButton));

        verifyNever(() => cubit.add(const ProfileFeedRetryRequested()));
      });
    });
  });
}
