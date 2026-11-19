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

  void availabilityChanged(bool available) {
    if (isClosed || state.armed || state.boundaryPassed || !available) return;
    emit((armed: true, boundaryPassed: false));
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
