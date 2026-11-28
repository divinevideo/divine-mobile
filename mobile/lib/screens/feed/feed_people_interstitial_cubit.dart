// ABOUTME: Arms one people card before a fixed video boundary per feed session.
// ABOUTME: Late suggestions cannot insert a page behind the viewer's position.
import 'package:flutter_bloc/flutter_bloc.dart';

typedef FeedPeopleInterstitialState = ({bool armed, bool boundaryPassed});

class FeedPeopleInterstitialCubit extends Cubit<FeedPeopleInterstitialState> {
  FeedPeopleInterstitialCubit({required int initialVideoIndex})
    : super((
        armed: false,
        boundaryPassed: initialVideoIndex >= insertBeforeIndex,
      ));

  static const insertBeforeIndex = 10;

  void availabilityChanged(bool available, {bool cardVisible = false}) {
    if (isClosed) return;
    if (!available) {
      // Disarm before the viewer reaches the card so empty/failed results never
      // leave an empty or error page in the feed. Keep an already-visible or
      // already-passed slot stable during normal exhaustion so the feed does
      // not jump under the viewer's finger.
      if (state.armed && !state.boundaryPassed && !cardVisible) {
        emit((armed: false, boundaryPassed: false));
      }
      return;
    }
    if (state.armed || state.boundaryPassed) return;
    emit((armed: true, boundaryPassed: false));
  }

  /// Immediately removes the Home card when the server refuses policy checks.
  void clearForPolicy() {
    if (isClosed || !state.armed) return;
    emit((armed: false, boundaryPassed: state.boundaryPassed));
  }

  void videoChanged(int index) {
    if (!isClosed && index >= insertBeforeIndex) {
      emit((armed: state.armed, boundaryPassed: true));
    }
  }

  void reset({required int initialVideoIndex}) {
    if (isClosed) return;
    emit((
      armed: false,
      boundaryPassed: initialVideoIndex >= insertBeforeIndex,
    ));
  }
}
