import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_upload_errors.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

/// Wraps the profile-setup form with all of its [BlocListener] side effects
/// (profile load -> controllers, save status snackbars/dialogs/navigation,
/// and avatar/banner upload status). Kept separate from
/// the view so the view body stays a thin composition.
class ProfileSetupListeners extends ConsumerStatefulWidget {
  const ProfileSetupListeners({
    required this.isNewUser,
    required this.nameController,
    required this.bioController,
    required this.websiteController,
    required this.nip05Controller,
    required this.child,
    super.key,
  });

  final bool isNewUser;
  final TextEditingController nameController;
  final TextEditingController bioController;
  final TextEditingController websiteController;
  final TextEditingController nip05Controller;

  final Widget child;

  @override
  ConsumerState<ProfileSetupListeners> createState() =>
      _ProfileSetupListenersState();
}

class _ProfileSetupListenersState extends ConsumerState<ProfileSetupListeners> {
  @override
  void initState() {
    super.initState();
    if (widget.isNewUser) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .recordOnboardingStep(
              flow: ProductAnalyticsV2OnboardingFlow.accountSetup,
              step: ProductAnalyticsV2OnboardingStep.identity,
              result: ProductAnalyticsV2OnboardingResult.viewed,
            ),
      );
    }
  }

  /// What the last seed wrote into each field.
  ///
  /// Lets a later profile snapshot tell "untouched since we filled it" from
  /// "the user typed this", so refreshing the form never eats an edit.
  String? _seededName;
  String? _seededBio;
  String? _seededWebsite;
  String? _seededUsername;
  String? _seededExternalNip05;
  String? _seededBanner;

  /// Whether a profile has reached the form yet.
  bool _hasSeeded = false;

  /// Whether a persisted divine handle or external NIP-05 has been seen.
  ///
  /// Tracked apart from [_hasSeeded], and keyed on the value rather than on the
  /// first snapshot: the cached profile that fills the form can predate a NIP-05
  /// the relay's fresher copy carries — set on another device, say — and gating
  /// these on the first snapshot left the editor never learning it. The mode is
  /// still allowed to change while the handle field is untouched, so a stale
  /// cached external address cannot keep Save in external mode after the relay
  /// reports a Divine handle.
  bool _hasSeededUsername = false;
  bool _hasSeededExternalNip05 = false;

  /// The profile carried by [state], whichever shape it arrived in.
  static UserProfile? _profileOf(MyProfileState state) => switch (state) {
    MyProfileLoading(:final profile) => profile,
    MyProfileLoaded(:final profile) => profile,
    MyProfileUpdated(:final profile) => profile,
    _ => null,
  };

  /// Fills the form from the first snapshot that carries a profile, then keeps
  /// untouched fields in step as fresher data lands.
  ///
  /// The cached profile arrives on [MyProfileLoading], well before the relay
  /// answers — waiting for [MyProfileLoaded] left the form blank for the whole
  /// round trip even though the profile screen had already drawn it.
  void _seedFrom(MyProfileState state) {
    final profile = _profileOf(state);
    if (profile == null) return;

    final (extractedUsername, externalNip05) = switch (state) {
      MyProfileLoading(:final extractedUsername, :final externalNip05) => (
        extractedUsername,
        externalNip05,
      ),
      MyProfileLoaded(:final extractedUsername, :final externalNip05) => (
        extractedUsername,
        externalNip05,
      ),
      MyProfileUpdated(:final extractedUsername, :final externalNip05) => (
        extractedUsername,
        externalNip05,
      ),
      _ => (null, null),
    };

    _seededName = _seedText(
      widget.nameController,
      profile.displayName ?? profile.name ?? '',
      _seededName,
    );
    _seededBio = _seedText(
      widget.bioController,
      profile.about ?? '',
      _seededBio,
    );
    _seededWebsite = _seedText(
      widget.websiteController,
      profile.website ?? '',
      _seededWebsite,
    );
    final usernameUntouched = _usernameFieldIsUntouched;
    final previousSeededUsername = _seededUsername;
    if (extractedUsername != null && usernameUntouched) {
      _seededUsername = _seedText(
        widget.nip05Controller,
        extractedUsername,
        _seededUsername,
      );
    }

    final editorBloc = context.read<ProfileEditorBloc>();
    // The baseline the unsaved-changes guard compares against is whatever was
    // last *seeded*, which is not the same as what the profile now says: a
    // field the user has typed into keeps its old baseline so the edit still
    // counts as unsaved. Refreshing it on every snapshot — not just the first —
    // is what stops a relay copy that disagrees with the cache from reading as
    // an edit on a form nobody touched. The current values come back off the
    // controllers, because a field the user touched is not the seed.
    editorBloc
      ..add(
        InitialProfileFieldsSet(
          displayName: _seededName ?? '',
          about: _seededBio ?? '',
          website: _seededWebsite ?? '',
        ),
      )
      ..add(DisplayNameChanged(widget.nameController.text))
      ..add(AboutChanged(widget.bioController.text))
      ..add(WebsiteChanged(widget.websiteController.text));
    if (!_hasSeeded) {
      _hasSeeded = true;
      // Seed bloc with the persisted picture so the avatar widget can
      // render `pendingPictureUrl ?? persistedPictureUrl` purely from
      // state, no widget-local fallback for the existing avatar.
      editorBloc
        ..add(InitialPersistedPictureSet(profile.picture))
        ..add(InitialPersistedBannerSet(profile.banner));
    } else {
      // A fresher picture or banner may replace the seeded one, but only while
      // the user has staged nothing of their own.
      final editorState = editorBloc.state;
      if (editorState.pendingPictureUrl == null &&
          !editorState.pictureCleared) {
        editorBloc.add(InitialPersistedPictureSet(profile.picture));
      }
      if (_bannerStillMatchesSeed(editorState)) {
        editorBloc.add(InitialPersistedBannerSet(profile.banner));
      }
    }
    _seededBanner = profile.banner;

    if (extractedUsername != null && usernameUntouched) {
      if (!_hasSeededUsername || previousSeededUsername != extractedUsername) {
        _hasSeededUsername = true;
        editorBloc
          ..add(InitialUsernameSet(extractedUsername))
          ..add(const Nip05ModeChanged(Nip05Mode.divine));
      }
      _seededExternalNip05 = null;
    }
    if (externalNip05 != null &&
        extractedUsername == null &&
        usernameUntouched) {
      if (!_hasSeededExternalNip05 || _seededExternalNip05 != externalNip05) {
        _hasSeededExternalNip05 = true;
        _seededExternalNip05 = externalNip05;
        // External NIP-05 now lives on Settings -> Nostr -> NIP-05.
        // Seed editor state here so Save from Edit Profile preserves it.
        editorBloc
          ..add(InitialExternalNip05Set(externalNip05))
          ..add(const Nip05ModeChanged(Nip05Mode.external_))
          ..add(ExternalNip05Changed(externalNip05));
      }
    }
  }

  bool get _usernameFieldIsUntouched {
    final seeded = _seededUsername;
    if (seeded == null) return widget.nip05Controller.text.isEmpty;
    return widget.nip05Controller.text == seeded;
  }

  bool _bannerStillMatchesSeed(ProfileEditorState state) {
    if (state.bannerCleared || state.pendingBannerUrl != null) return false;
    final stagedColor = state.pendingBannerColor;
    if (stagedColor == null) return true;
    return _bannerColorString(stagedColor) ==
        _normalizedBannerColor(_seededBanner);
  }

  static String? _normalizedBannerColor(String? banner) {
    if (banner == null || banner.isEmpty || banner.startsWith('http')) {
      return null;
    }
    var hex = banner;
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    } else if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    if (hex.length != 6 || int.tryParse(hex, radix: 16) == null) {
      return null;
    }
    return '0x${hex.toLowerCase()}';
  }

  static String _bannerColorString(Color color) =>
      '0x${color.toARGB32().toRadixString(16).substring(2)}';

  /// Writes [value] into [controller] unless the user has edited it since the
  /// last seed. Returns the value to remember for the next comparison.
  String _seedText(
    TextEditingController controller,
    String value,
    String? seeded,
  ) {
    if (seeded != null && controller.text != seeded) return seeded;
    if (controller.text != value) controller.text = value;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final isNewUser = widget.isNewUser;
    return MultiBlocListener(
      listeners: [
        BlocListener<MyProfileBloc, MyProfileState>(
          listenWhen: (prev, curr) => _profileOf(prev) != _profileOf(curr),
          listener: (context, myProfileState) => _seedFrom(myProfileState),
        ),
        BlocListener<ProfileEditorBloc, ProfileEditorState>(
          listenWhen: (prev, curr) => prev.status != curr.status,
          listener: (context, state) {
            if (state.status == ProfileEditorStatus.success) {
              if (isNewUser) {
                unawaited(
                  ref
                      .read(analyticsServiceProvider)
                      .recordOnboardingStep(
                        flow: ProductAnalyticsV2OnboardingFlow.accountSetup,
                        step: ProductAnalyticsV2OnboardingStep.identity,
                        result: ProductAnalyticsV2OnboardingResult.completed,
                      ),
                );
              }
              // Invalidate profile providers so profile screen refetches
              final currentPubkey = ref
                  .read(authServiceProvider)
                  .currentPublicKeyHex;
              if (currentPubkey != null) {
                ref.invalidate(fetchUserProfileProvider(currentPubkey));
                ref.invalidate(userProfileReactiveProvider(currentPubkey));
              }

              ScaffoldMessenger.of(context).showSnackBar(
                DivineSnackbarContainer.snackBar(
                  context.l10n.profileSetupProfilePublished,
                ),
              );
              if (isNewUser) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else {
                if (context.canPop()) {
                  context.pop(true);
                } else {
                  context.go('/');
                }
              }
            } else if (state.status ==
                ProfileEditorStatus.confirmationRequired) {
              // Show confirmation dialog for blank profile overwrite
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: context.vineColors.card,
                  title: Text(
                    context.l10n.profileSetupCreateNewProfile,
                    style: TextStyle(color: context.vineColors.primaryText),
                  ),
                  content: Text(
                    context.l10n.profileSetupNoExistingProfile,
                    style: TextStyle(color: context.vineColors.secondaryText),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => dialogContext.popModalIfMounted(),
                      child: Text(
                        context.l10n.profileCancelButton,
                        style: TextStyle(color: context.vineColors.mutedText),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // A tap that lands after the route is gone is not a
                        // confirmation the user ever saw, so it must not
                        // publish either.
                        if (!dialogContext.popModalIfMounted()) return;
                        context.read<ProfileEditorBloc>().add(
                          const ProfileSaveConfirmed(),
                        );
                      },
                      child: Text(
                        context.l10n.profileSetupPublishButton,
                        style: const TextStyle(color: VineTheme.vineGreen),
                      ),
                    ),
                  ],
                ),
              );
            } else if (state.status == ProfileEditorStatus.failure) {
              if (isNewUser) {
                final reason =
                    state.error == ProfileEditorError.claimNetworkError
                    ? ProductAnalyticsV2OnboardingReason.network
                    : ProductAnalyticsV2OnboardingReason.validation;
                unawaited(
                  ref
                      .read(analyticsServiceProvider)
                      .recordOnboardingStep(
                        flow: ProductAnalyticsV2OnboardingFlow.accountSetup,
                        step: ProductAnalyticsV2OnboardingStep.identity,
                        result: ProductAnalyticsV2OnboardingResult.failed,
                        reason: reason,
                      ),
                );
              }
              // Invalidate profile providers after rollback
              final currentPubkey = ref
                  .read(authServiceProvider)
                  .currentPublicKeyHex;
              if (currentPubkey != null) {
                ref.invalidate(fetchUserProfileProvider(currentPubkey));
                ref.invalidate(userProfileReactiveProvider(currentPubkey));
              }
              switch (state.error) {
                case ProfileEditorError.usernameTaken:
                  ScaffoldMessenger.of(context).showSnackBar(
                    DivineSnackbarContainer.snackBar(
                      context.l10n.profileSetupUsernameTaken,
                      error: true,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                case ProfileEditorError.usernameReserved:
                  final username = state.username;
                  showDialog<void>(
                    context: context,
                    builder: (context) => UsernameReservedDialog(username),
                  );
                // claimFailed (server rejected) and claimNetworkError
                // (couldn't reach the server) currently share this copy; the
                // types stay distinct for telemetry and to allow a
                // connectivity-specific message later.
                case ProfileEditorError.claimFailed:
                case ProfileEditorError.claimNetworkError:
                  ScaffoldMessenger.of(context).showSnackBar(
                    DivineSnackbarContainer.snackBar(
                      context.l10n.profileSetupClaimFailed,
                      error: true,
                    ),
                  );
                case ProfileEditorError.publishFailed:
                  ScaffoldMessenger.of(context).showSnackBar(
                    DivineSnackbarContainer.snackBar(
                      context.l10n.profileSetupPublishFailed,
                      error: true,
                    ),
                  );
                case null:
                  break;
              }
            }
          },
        ),
        BlocListener<ProfileEditorBloc, ProfileEditorState>(
          listenWhen: (prev, curr) =>
              prev.pendingAvatarStatus != curr.pendingAvatarStatus,
          listener: (context, state) {
            switch (state.pendingAvatarStatus) {
              case PendingAvatarStatus.staged:
                // Avatar preview has already swapped (BlocBuilder is rebuilding
                // from `effectivePictureUrl`). The snackbar makes the staged
                // contract explicit: bytes uploaded, not yet published.
                ScaffoldMessenger.of(context).showSnackBar(
                  DivineSnackbarContainer.snackBar(
                    context.l10n.profileSetupUploadStaged,
                  ),
                );
              case PendingAvatarStatus.failed:
                final classified =
                    state.avatarUploadError ?? AvatarUploadError.generic;
                ScaffoldMessenger.of(context).showSnackBar(
                  DivineSnackbarContainer.snackBar(
                    profileSetupUploadErrorMessage(context.l10n, classified),
                    error: true,
                  ),
                );
              case PendingAvatarStatus.idle:
              case PendingAvatarStatus.uploading:
                break;
            }
          },
        ),
        BlocListener<ProfileEditorBloc, ProfileEditorState>(
          listenWhen: (prev, curr) =>
              prev.pendingBannerStatus != curr.pendingBannerStatus,
          listener: (context, state) {
            switch (state.pendingBannerStatus) {
              case PendingBannerStatus.staged:
                ScaffoldMessenger.of(context).showSnackBar(
                  DivineSnackbarContainer.snackBar(
                    context.l10n.profileSetupUploadStaged,
                  ),
                );
              case PendingBannerStatus.failed:
                final classified =
                    state.bannerUploadError ?? BannerUploadError.generic;
                ScaffoldMessenger.of(context).showSnackBar(
                  DivineSnackbarContainer.snackBar(
                    profileSetupBannerUploadErrorMessage(
                      context.l10n,
                      classified,
                    ),
                    error: true,
                  ),
                );
              case PendingBannerStatus.idle:
              case PendingBannerStatus.uploading:
                break;
            }
          },
        ),
      ],
      child: widget.child,
    );
  }
}
