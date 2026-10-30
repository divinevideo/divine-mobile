import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/widgets/profile/profile_videos_load_failed.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileFeedCubit extends MockBloc<ProfileFeedEvent, ProfileFeedState>
    implements ProfileFeedCubit {}

void main() {
  group(ProfileVideosLoadFailed, () {
    group('renders', () {
      // Measured on an iPhone 17: under an own profile's full header the tab
      // is 208 points tall and only its top 146 show above the bottom nav.
      const tabHeight = 208.0;
      const tabHeightAboveNav = 146.0;

      testWidgets('keeps Retry above the bottom nav', (tester) async {
        final cubit = _MockProfileFeedCubit();
        whenListen(
          cubit,
          const Stream<ProfileFeedState>.empty(),
          initialState: const ProfileFeedState(
            status: ProfileFeedStatus.failure,
          ),
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: tabHeight,
                  child: BlocProvider<ProfileFeedCubit>.value(
                    value: cubit,
                    child: const ProfileVideosLoadFailed(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.getBottomLeft(find.byType(DivineButton)).dy,
          lessThanOrEqualTo(tabHeightAboveNav),
        );
      });
    });
  });
}
