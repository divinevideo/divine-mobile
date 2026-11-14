// ABOUTME: Owns one profile's link resolution and discards superseded results.
// ABOUTME: Display, copy and share reuse the same in-flight resolution.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

class ProfileLinkState extends Equatable {
  const ProfileLinkState({
    required this.pubkey,
    required this.claim,
    required this.website,
    required this.link,
    this.resolution,
  });

  final String pubkey;
  final String? claim;
  final String? website;
  final ProfileLink link;
  final Future<ProfileLink>? resolution;

  @override
  List<Object?> get props => [pubkey, claim, website, link, resolution];
}

class ProfileLinkCubit extends Cubit<ProfileLinkState> {
  ProfileLinkCubit({
    required ProfileLinkResolver resolver,
    required String pubkey,
    required UserProfile? profile,
  }) : _resolver = resolver,
       super(
         ProfileLinkState(
           pubkey: pubkey,
           claim: profile?.nip05,
           website: profile?.website,
           link: ProfileLink.fallback(pubkey, profile),
         ),
       );

  final ProfileLinkResolver _resolver;

  Future<ProfileLink> load({
    required String pubkey,
    required UserProfile? profile,
  }) async {
    final current = state;
    if (current.pubkey == pubkey &&
        current.claim == profile?.nip05 &&
        current.website == profile?.website &&
        current.resolution != null) {
      return current.resolution!;
    }
    final resolution = _resolver.resolve(pubkey: pubkey, profile: profile);
    emit(
      ProfileLinkState(
        pubkey: pubkey,
        claim: profile?.nip05,
        website: profile?.website,
        link: ProfileLink.fallback(pubkey, profile),
        resolution: resolution,
      ),
    );
    final link = await resolution;
    if (!isClosed && identical(state.resolution, resolution)) {
      emit(
        ProfileLinkState(
          pubkey: pubkey,
          claim: profile?.nip05,
          website: profile?.website,
          link: link,
          resolution: resolution,
        ),
      );
    }
    return link;
  }
}
