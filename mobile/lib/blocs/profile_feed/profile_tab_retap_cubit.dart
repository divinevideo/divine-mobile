// ABOUTME: Signals a re-tap of the Profile tab while it is already showing, so
// ABOUTME: the profile can retry a failed load (#9773).

import 'package:flutter_bloc/flutter_bloc.dart';

/// Counts re-taps of the Profile tab while the user is already on it.
///
/// `VineBottomNav` calls [request]; the own profile listens and retries a load
/// that failed. Provided above `AppShell` (see `shell.dart`) beside
/// `HomeFeedRetapCubit`, so the nav and the profile branch share one instance.
class ProfileTabRetapCubit extends Cubit<int> {
  ProfileTabRetapCubit() : super(0);

  /// Records one re-tap.
  void request() => emit(state + 1);
}
