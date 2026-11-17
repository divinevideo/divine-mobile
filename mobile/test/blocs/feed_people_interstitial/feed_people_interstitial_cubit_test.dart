import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/feed_people_interstitial_cubit.dart';

void main() {
  group('FeedPeopleInterstitialCubit', () {
    test(
      'arms only with available recommendations before the boundary',
      () async {
        final cubit = FeedPeopleInterstitialCubit(initialVideoIndex: 0);
        expect(cubit.state, isFalse);
        cubit.availabilityChanged(false);
        expect(cubit.state, isFalse);
        cubit.videoChanged(9);
        cubit.availabilityChanged(true);
        expect(cubit.state, isTrue);
        cubit.videoChanged(10);
        cubit.availabilityChanged(false);
        expect(
          cubit.state,
          isTrue,
        ); // Keep the slot stable until session reset.
        await cubit.close();
      },
    );

    test(
      'late results and restored positions never insert behind the viewer',
      () async {
        final cubit = FeedPeopleInterstitialCubit(initialVideoIndex: 10);
        cubit.availabilityChanged(true);
        expect(cubit.state, isFalse);
        cubit.reset(initialVideoIndex: 0);
        cubit.videoChanged(10);
        cubit.videoChanged(2);
        cubit.availabilityChanged(true);
        expect(cubit.state, isFalse);
        cubit.reset(initialVideoIndex: 0);
        cubit.availabilityChanged(true);
        expect(cubit.state, isTrue);
        await cubit.close();
      },
    );
  });
}
