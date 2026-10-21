// ABOUTME: Constructor factories for people-picker business state.
// ABOUTME: Captures current dependencies without exposing services to widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:openvine/blocs/local_user_picker/local_user_picker_cubit.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_cubit.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_ranking_providers.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod/misc.dart';

/// Local mode additionally needs the existing feed-block predicate.
final ProviderFamily<UserPickerCubitFactory, bool>
userPickerCubitFactoryProvider = Provider.autoDispose
    .family<UserPickerCubitFactory, bool>(
      (ref, local) {
        final profiles = ref.watch(profileRepositoryProvider);
        final blocklist = local && profiles != null
            ? ref.watch(contentBlocklistRepositoryProvider)
            : null;
        return UserPickerCubitFactory(
          followRepository: ref.watch(followRepositoryProvider),
          profileRepository: profiles,
          rankingSignalsLoader: profiles == null
              ? null
              : ref.watch(userRankingSignalsLoaderProvider),
          isBlocked: blocklist == null
              ? (_) => false
              : blocklist.shouldFilterFromFeeds,
        );
      },
      dependencies: [
        profileRepositoryProvider,
        followRepositoryProvider,
        userRankingSignalsLoaderProvider,
        contentBlocklistRepositoryProvider,
      ],
    );

/// Fresh construction inputs shared by the local and network picker modes.
class UserPickerCubitFactory {
  const UserPickerCubitFactory({
    required FollowRepository followRepository,
    required ProfileRepository? profileRepository,
    required UserRankingSignalsLoader? rankingSignalsLoader,
    required bool Function(String) isBlocked,
  }) : _followRepository = followRepository,
       _profileRepository = profileRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       _isBlocked = isBlocked;

  final FollowRepository _followRepository;
  final ProfileRepository? _profileRepository;
  final UserRankingSignalsLoader? _rankingSignalsLoader;
  final bool Function(String) _isBlocked;

  UserSearchBloc createSearch({
    String? excludedPubkey,
    UserSearchState? initialState,
  }) {
    final profiles = _profileRepository;
    return UserSearchBloc(
      profileRepository: profiles,
      rankingSignalsLoader: _rankingSignalsLoader,
      followRepository: _followRepository,
      excludedPubkey: excludedPubkey,
      initialState: initialState,
    );
  }

  LocalUserPickerCubit createLocal({
    String? excludedPubkey,
    LocalUserPickerState? initialState,
  }) {
    final profiles = _profileRepository;
    final loader = _rankingSignalsLoader;
    return LocalUserPickerCubit(
      followRepository: _followRepository,
      profileRepository: profiles,
      rankingSignalsLoader: loader,
      isBlocked: _isBlocked,
      excludedPubkey: excludedPubkey,
      initialState: initialState,
    );
  }
}

final Provider<AddPeopleToListCubitFactory>
addPeopleToListCubitFactoryProvider =
    Provider.autoDispose<AddPeopleToListCubitFactory>(
      (ref) => AddPeopleToListCubitFactory(
        followRepository: ref.watch(followRepositoryProvider),
        profileRepository: ref.watch(profileRepositoryProvider),
        rankingSignalsLoader: ref.watch(userRankingSignalsLoaderProvider),
      ),
      dependencies: [
        followRepositoryProvider,
        profileRepositoryProvider,
        userRankingSignalsLoaderProvider,
      ],
    );

/// Owns typed service wiring while the UI owns the owner/list/source lifetime.
class AddPeopleToListCubitFactory {
  const AddPeopleToListCubitFactory({
    required FollowRepository followRepository,
    required ProfileRepository? profileRepository,
    required UserRankingSignalsLoader rankingSignalsLoader,
  }) : _followRepository = followRepository,
       _profileRepository = profileRepository,
       _rankingSignalsLoader = rankingSignalsLoader;

  final FollowRepository _followRepository;
  final ProfileRepository? _profileRepository;
  final UserRankingSignalsLoader _rankingSignalsLoader;

  AddPeopleToListCubit create({
    required List<String> existingMemberPubkeys,
    AddPeopleToListState initialState = const AddPeopleToListState(),
  }) => AddPeopleToListCubit(
    followRepository: _followRepository,
    profileRepository: _profileRepository,
    rankingSignalsLoader: _rankingSignalsLoader,
    existingMemberPubkeys: existingMemberPubkeys,
    initialState: initialState,
  );
}
