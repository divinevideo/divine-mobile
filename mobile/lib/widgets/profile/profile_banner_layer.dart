// ABOUTME: Banner layer rendered edge-to-edge behind the profile content
// ABOUTME: Scroll-driven: moves up as user scrolls, extends behind status bar

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';

/// Renders the profile banner as a separate Stack layer in [ProfileGridView].
///
/// Unlike the rest of the profile content (which lives inside a [SafeArea]
/// and therefore starts below the status bar), this layer is positioned at
/// the screen edge so the banner image/gradient can show through the safe
/// area. The layer listens to the parent scroll controller and translates
/// its top offset upward as the user scrolls, so the banner scrolls away
/// naturally with the rest of the content.
class ProfileBannerLayer extends ConsumerStatefulWidget {
  const ProfileBannerLayer({
    required this.userIdHex,
    required this.isOwnProfile,
    this.profile,
    this.height = 334.0,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;
  final UserProfile? profile;
  final double height;

  @override
  ConsumerState<ProfileBannerLayer> createState() => _ProfileBannerLayerState();
}

class _ProfileBannerLayerState extends ConsumerState<ProfileBannerLayer> {
  /// Banner top offset driven by scroll. Always <= 0 when scrolled.
  final _topOffset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _topOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVanished =
        !widget.isOwnProfile &&
        ref.watch(profileVanishedProvider(widget.userIdHex));

    // Resolve effective profile (same logic as ProfileHeaderWidget).
    final UserProfile? effectiveProfile;
    if (isVanished) {
      effectiveProfile = null;
    } else if (widget.isOwnProfile) {
      effectiveProfile = _readOwnProfileBanner(context);
    } else if (widget.profile != null) {
      effectiveProfile = widget.profile;
    } else {
      effectiveProfile = ref
          .watch(fetchUserProfileProvider(widget.userIdHex))
          .value;
    }

    final hasBannerImage = effectiveProfile?.hasBannerImage ?? false;
    final bannerUrl = hasBannerImage ? effectiveProfile!.banner : null;
    final profileColor = effectiveProfile?.profileBackgroundColor;

    return ValueListenableBuilder<double>(
      valueListenable: _topOffset,
      builder: (_, topOffset, child) => child!,
      child: ExcludeSemantics(
        child: ProfileBanner(
          bannerUrl: bannerUrl,
          profileColor: profileColor,
          height: widget.height,
        ),
      ),
    );
  }

  /// Resolves the own-profile banner from [MyProfileBloc].
  ///
  /// Returns `null` when the bloc is not provided yet — cold start before
  /// profileRepository is ready, where the screen renders the real layout as a
  /// skeleton — so the banner falls back to its plain placeholder until the
  /// bloc is wired in. Mirrors the tolerant read in `ProfileHeaderWidget`.
  UserProfile? _readOwnProfileBanner(BuildContext context) {
    try {
      final state = context.watch<MyProfileBloc>().state;
      return switch (state) {
        MyProfileUpdated(:final profile) => profile,
        MyProfileLoaded(:final profile) => profile,
        MyProfileLoading(:final profile) => profile,
        _ => null,
      };
    } on ProviderNotFoundException {
      return null;
    }
  }
}
