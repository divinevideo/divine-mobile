// ABOUTME: Arms one people card before a fixed video boundary per feed session.
// ABOUTME: Late suggestions cannot insert a page behind the viewer's position.
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedPeopleInterstitialCubit extends Cubit<bool> {
  FeedPeopleInterstitialCubit({required int initialVideoIndex})
    : _boundaryPassed = initialVideoIndex >= insertBeforeIndex,
      super(false);

  static const insertBeforeIndex = 10;
  bool _boundaryPassed;

  void availabilityChanged(bool available) {
    if (isClosed || state || _boundaryPassed || !available) return;
    emit(true);
  }

  void videoChanged(int index) {
    if (index >= insertBeforeIndex) _boundaryPassed = true;
  }

  void reset({required int initialVideoIndex}) {
    _boundaryPassed = initialVideoIndex >= insertBeforeIndex;
    emit(false);
  }
}
