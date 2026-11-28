import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/feed_people_interstitial_cubit.dart';

void main() {
  group('FeedPeopleInterstitialCubit', () {
    test(
      'arms with available recommendations and disarms before the boundary if lost',
      () async {
        final cubit = FeedPeopleInterstitialCubit(initialVideoIndex: 0);
        expect(cubit.state.armed, isFalse);
        cubit.availabilityChanged(false);
        expect(cubit.state.armed, isFalse);
        cubit.videoChanged(9);
        cubit.availabilityChanged(true);
        expect(cubit.state.armed, isTrue);
        // Losing suggestions before reaching the card disarms it.
        cubit.availabilityChanged(false);
        expect(cubit.state.armed, isFalse);
        // Recovering before the boundary can re-arm it.
        cubit.availabilityChanged(true);
        expect(cubit.state.armed, isTrue);
        // While the card is visible on screen, normal exhaustion keeps it stable.
        cubit.availabilityChanged(false, cardVisible: true);
        expect(cubit.state.armed, isTrue);
        cubit.videoChanged(10);
        expect(cubit.state.boundaryPassed, isTrue);
        cubit.availabilityChanged(false);
        expect(
          cubit.state.armed,
          isTrue,
        ); // Keep the slot stable until session reset.
        // A server policy refusal immediately clears the card regardless of position.
        cubit.clearForPolicy();
        expect(cubit.state.armed, isFalse);
        expect(cubit.state.boundaryPassed, isTrue);
        await cubit.close();
      },
    );

    test(
      'late results and restored positions never insert behind the viewer',
      () async {
        final cubit = FeedPeopleInterstitialCubit(initialVideoIndex: 10);
        cubit.availabilityChanged(true);
        expect(cubit.state.armed, isFalse);
        cubit.reset(initialVideoIndex: 0);
        expect(cubit.state.boundaryPassed, isFalse);
        cubit.videoChanged(10);
        cubit.videoChanged(2);
        cubit.availabilityChanged(true);
        expect(cubit.state.armed, isFalse);
        cubit.reset(initialVideoIndex: 0);
        cubit.availabilityChanged(true);
        expect(cubit.state.armed, isTrue);
        await cubit.close();
      },
    );
  });
}
