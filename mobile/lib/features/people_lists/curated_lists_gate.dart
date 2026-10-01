// ABOUTME: Access points for FeatureFlag.curatedLists outside the flag's own
// ABOUTME: providers: a one-shot BuildContext read for imperative entry points,
// ABOUTME: and a seeded stream for the app-lifetime PeopleListsBloc.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/provider_identity_stream.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

/// Whether curated lists are enabled for the current user.
///
/// The global `PeopleListsBloc` is registered unconditionally in `main.dart`
/// — a conditional entry changed the provider chain's shape and re-inflated
/// the Navigator on every flag flip. `BlocProvider` laziness gates it
/// instead, which only holds while every entry point that would read the
/// bloc checks the flag first.
///
/// Widgets that can rebuild on a flip should `ref.watch` the flag directly;
/// this is for imperative call sites (`show...Sheet` helpers) that only need
/// a one-shot read.
bool curatedListsEnabled(BuildContext context) {
  return ProviderScope.containerOf(
    context,
    listen: false,
  ).read(isFeatureEnabledProvider(FeatureFlag.curatedLists));
}

/// Successive `FeatureFlag.curatedLists` values, seeded with the current one,
/// for the app-shell `PeopleListsBloc` (#6494).
///
/// Laziness gates *construction* of that bloc, and the entry points above keep
/// that gate honest. What laziness cannot do is tear a bloc down again: the
/// `BlocProvider` is unconditional on purpose (#6477), so one constructed while
/// the flag was on stays alive for the session and has to stand down on its own
/// when the flag goes off.
///
/// Unlike [identityStreamOf]'s usual subjects, the value here is a `bool`, so
/// Riverpod's `==` change detection is plain value equality — exactly the
/// signal wanted, rather than the identity proxy the helper's doc describes.
final Provider<Stream<bool>> curatedListsEnabledStreamProvider =
    identityStreamOf<bool>(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );

/// The repository Home reads the viewer's followed people lists from, or `null`
/// while `FeatureFlag.curatedLists` is off.
///
/// The flag is the master switch for people lists. With it off, the screens
/// that follow and unfollow a list are out of reach, so a followed list left in
/// Home's feed selector could be neither refreshed nor removed. Home then
/// behaves as it did before lists could be followed, and a saved selection
/// waits for the flag to come back.
final Provider<PeopleListsRepository?> homePeopleListsRepositoryProvider =
    Provider<PeopleListsRepository?>((ref) {
      if (!ref.watch(isFeatureEnabledProvider(FeatureFlag.curatedLists))) {
        return null;
      }
      return ref.watch(peopleListsRepositoryProvider);
    });
