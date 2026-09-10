// ABOUTME: Profile setup screen for new users to configure their display name, bio, and avatar
// ABOUTME: Publishes initial profile metadata to Nostr after setup is complete

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/profile_setup/view/profile_setup_view.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';

class ProfileSetupScreen extends ConsumerWidget {
  /// Route name for editing existing profile.
  static const editRouteName = 'edit-profile';

  /// Path for editing existing profile.
  static const String editPath = RoutePaths.profileSetupEdit;

  /// Route name for setting up new profile.
  static const setupRouteName = 'setup-profile';

  /// Path for setting up new profile.
  static const setupPath = '/setup-profile';

  const ProfileSetupScreen({required this.isNewUser, super.key});

  final bool isNewUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);
    final blossomUploadService = ref.watch(blossomUploadServiceProvider);
    final stagedProfileMediaStore = ref.watch(stagedProfileMediaStoreProvider);
    final authService = ref.watch(authServiceProvider);
    final identityClaimsRepository = ref.watch(
      identityClaimsRepositoryProvider,
    );

    final pubkey = authService.currentPublicKeyHex;

    // Show loading until NostrClient has keys
    if (profileRepository == null || pubkey == null) {
      return const BrandedLoadingScaffold();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileEditorBloc>(
          // Riverpod-into-BlocProvider bridge: rebuild the bloc when any
          // captured dependency's identity changes (auth flip, account
          // switch). Record-typed key compares per-field with `==`; the
          // captured classes do not override `==`, so equality falls
          // through to identity — exactly the semantics this needs.
          // See `state_management.md`.
          key: ValueKey((
            profileRepository,
            blossomUploadService,
            stagedProfileMediaStore,
            pubkey,
          )),
          create: (context) => ProfileEditorBloc(
            profileRepository: profileRepository,
            blossomUploadService: blossomUploadService,
            hasExistingProfile: authService.hasExistingProfile,
            currentUserPubkey: pubkey,
            stagedProfileMediaStore: stagedProfileMediaStore,
          ),
        ),
        BlocProvider<MyProfileBloc>(
          create: (context) {
            final bloc = MyProfileBloc(
              profileRepository: profileRepository,
              pubkey: pubkey,
              identityClaimsRepository: identityClaimsRepository,
            );
            if (!isNewUser) bloc.add(const MyProfileLoadRequested());
            return bloc;
          },
        ),
      ],
      child: ProfileSetupScreenView(isNewUser: isNewUser),
    );
  }
}
