// ABOUTME: Nostr Settings sub-screen for editing the user's NIP-05 identity.
// ABOUTME: Keeps custom NIP-05 management out of Edit Profile while reusing the
// ABOUTME: existing profile save and username-claim flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

const _divineVideoDomainSuffix = '.divine.video';

class Nip05SettingsScreen extends ConsumerWidget {
  static const routeName = 'nip05-settings';
  static const String subpath = RoutePaths.nip05SettingsSubpath;
  static const String path = RoutePaths.nip05Settings;

  const Nip05SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);
    final blossomUploadService = ref.watch(blossomUploadServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;

    if (profileRepository == null || pubkey == null) {
      return const _Nip05SettingsLoadingScreen();
    }

    return MultiBlocProvider(
      key: ValueKey((profileRepository, blossomUploadService, pubkey)),
      providers: [
        BlocProvider<ProfileEditorBloc>(
          create: (_) => ProfileEditorBloc(
            profileRepository: profileRepository,
            blossomUploadService: blossomUploadService,
            hasExistingProfile: authService.hasExistingProfile,
            currentUserPubkey: pubkey,
          ),
        ),
        BlocProvider<MyProfileBloc>(
          create: (_) => MyProfileBloc(
            profileRepository: profileRepository,
            pubkey: pubkey,
          )..add(const MyProfileLoadRequested()),
        ),
      ],
      child: const Nip05SettingsView(),
    );
  }
}

class _Nip05SettingsLoadingScreen extends StatelessWidget {
  const _Nip05SettingsLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.nostrSettingsNip05Address,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: const Center(child: BrandedLoadingIndicator(size: 60)),
    );
  }
}

@visibleForTesting
class Nip05SettingsView extends StatefulWidget {
  const Nip05SettingsView({super.key});

  @override
  State<Nip05SettingsView> createState() => _Nip05SettingsViewState();
}

class _Nip05SettingsViewState extends State<Nip05SettingsView> {
  final _usernameController = TextEditingController();
  final _externalController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _externalFocusNode = FocusNode();
  bool _didSeedInitialValues = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onFieldChanged);
    _externalController.addListener(_onFieldChanged);
    _usernameFocusNode.addListener(_onFieldChanged);
    _externalFocusNode.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _usernameController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _externalController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _usernameFocusNode
      ..removeListener(_onFieldChanged)
      ..dispose();
    _externalFocusNode
      ..removeListener(_onFieldChanged)
      ..dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.nostrSettingsNip05Address,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: MultiBlocListener(
        listeners: [
          BlocListener<MyProfileBloc, MyProfileState>(
            listenWhen: (previous, current) =>
                !_didSeedInitialValues && _profileFromState(current) != null,
            listener: _seedInitialValues,
          ),
          BlocListener<ProfileEditorBloc, ProfileEditorState>(
            listenWhen: (previous, current) =>
                previous.status != current.status,
            listener: _onSaveStatusChanged,
          ),
        ],
        child: BlocBuilder<MyProfileBloc, MyProfileState>(
          builder: (context, myProfileState) {
            final currentProfile = _profileFromState(myProfileState);
            return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
              builder: (context, editorState) {
                if (myProfileState case MyProfileError(:final errorType)) {
                  return switch (errorType) {
                    MyProfileErrorType.notFound =>
                      const _Nip05SettingsMissingProfile(),
                    MyProfileErrorType.networkError =>
                      const _Nip05SettingsLoadError(),
                  };
                }

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: currentProfile == null
                        ? const Center(child: BrandedLoadingIndicator(size: 60))
                        : ListView(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            children: [
                              _buildIntro(context),
                              const SizedBox(height: 8),
                              _buildDivineUsernameField(context, editorState),
                              const SizedBox(height: 16),
                              _buildToggleRow(context, editorState),
                              if (editorState.nip05Mode == Nip05Mode.external_)
                                _buildExternalNip05Field(context, editorState),
                              const SizedBox(height: 24),
                              _buildSaveButton(
                                context,
                                currentProfile,
                                editorState,
                              ),
                            ],
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        context.l10n.nostrSettingsNip05AddressSubtitle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
    );
  }

  Widget _buildDivineUsernameField(
    BuildContext context,
    ProfileEditorState state,
  ) {
    final isExternal = state.nip05Mode == Nip05Mode.external_;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DivineAuthTextField(
            label: context.l10n.profileSetupUsernameLabel,
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            enabled: !isExternal,
            prefixText: '@',
            suffixText: _divineVideoDomainSuffix,
            textInputAction: TextInputAction.next,
            inputFormatters: const [LowercaseTextInputFormatter()],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            onChanged: (value) {
              context.read<ProfileEditorBloc>().add(UsernameChanged(value));
            },
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.profileSetupUsernameHelper,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          if (!isExternal)
            UsernameStatusIndicator(
              status: state.usernameStatus,
              error: state.usernameError,
            ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(BuildContext context, ProfileEditorState state) {
    final isExternal = state.nip05Mode == Nip05Mode.external_;
    return MergeSemantics(
      child: Semantics(
        checked: isExternal,
        child: GestureDetector(
          onTap: () => _onTogglePressed(context, state),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: DivineCheckbox(
              state: isExternal
                  ? DivineCheckboxState.selected
                  : DivineCheckboxState.unselected,
              label: Text(
                context.l10n.profileSetupUseOwnNip05,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExternalNip05Field(
    BuildContext context,
    ProfileEditorState state,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          DivineAuthTextField(
            label: context.l10n.profileSetupNip05AddressLabel,
            controller: _externalController,
            focusNode: _externalFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            hintText: context.l10n.nostrSettingsNip05AddressHint,
            errorText: switch (state.externalNip05Error) {
              ExternalNip05ValidationError.invalidFormat =>
                context.l10n.profileSetupExternalNip05InvalidFormat,
              ExternalNip05ValidationError.divineDomain =>
                context.l10n.profileSetupExternalNip05DivineDomain,
              null => null,
            },
            onChanged: (value) {
              context.read<ProfileEditorBloc>().add(
                ExternalNip05Changed(value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    UserProfile currentProfile,
    ProfileEditorState editorState,
  ) {
    final isLoading = editorState.status == ProfileEditorStatus.loading;
    final canSave =
        !isLoading && editorState.isSaveReady && _isDirty(editorState);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DivineButton(
        label: context.l10n.nostrSettingsNip05SaveAction,
        onPressed: canSave
            ? () => _onSavePressed(context, currentProfile)
            : null,
        expanded: true,
        isLoading: isLoading,
      ),
    );
  }

  void _seedInitialValues(BuildContext context, MyProfileState state) {
    final profile = _profileFromState(state);
    if (profile == null || _didSeedInitialValues) return;

    final extractedUsername = _extractedUsernameFromState(state);
    final externalNip05 = _externalNip05FromState(state);

    if (extractedUsername != null) {
      _usernameController.text = extractedUsername;
    }
    if (externalNip05 != null) {
      _externalController.text = externalNip05;
    }

    final editorBloc = context.read<ProfileEditorBloc>();
    if (extractedUsername != null) {
      editorBloc.add(InitialUsernameSet(extractedUsername));
    }
    if (externalNip05 != null) {
      editorBloc
        ..add(InitialExternalNip05Set(externalNip05))
        ..add(const Nip05ModeChanged(Nip05Mode.external_))
        ..add(ExternalNip05Changed(externalNip05));
    }

    _didSeedInitialValues = true;
  }

  void _onSaveStatusChanged(BuildContext context, ProfileEditorState state) {
    if (state.status == ProfileEditorStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(context.l10n.nostrSettingsNip05Saved),
      );
      context.pop();
      return;
    }

    if (state.status == ProfileEditorStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.nostrSettingsNip05SaveFailed,
          error: true,
        ),
      );
    }
  }

  Future<void> _onTogglePressed(
    BuildContext context,
    ProfileEditorState state,
  ) async {
    final bloc = context.read<ProfileEditorBloc>();
    if (state.nip05Mode == Nip05Mode.external_) {
      bloc
        ..add(const Nip05ModeChanged(Nip05Mode.divine))
        ..add(const ExternalNip05Changed(''));
      return;
    }

    final confirmed = await _showConfirmDialog(context);
    if (!confirmed || !context.mounted) return;
    bloc
      ..add(const Nip05ModeChanged(Nip05Mode.external_))
      ..add(ExternalNip05Changed(_externalController.text));
  }

  Future<bool> _showConfirmDialog(BuildContext context) async {
    final l10n = context.l10n;
    final result = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: l10n.profileSetupNip05ConfirmTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.profileSetupNip05ConfirmBody,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
        // The buttons resolve the Navigator from the sheet's own subtree
        // rather than from this screen's context: the settings screen can be
        // rebuilt out from under an open sheet, and a caller context that has
        // gone defunct leaves both buttons inert.
        Builder(
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              spacing: 16,
              children: [
                Expanded(
                  child: DivineButton(
                    label: l10n.profileSetupNip05ConfirmCancel,
                    type: DivineButtonType.secondary,
                    expanded: true,
                    onPressed: () => sheetContext.popModalIfMounted(false),
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: l10n.profileSetupNip05ConfirmContinue,
                    expanded: true,
                    onPressed: () => sheetContext.popModalIfMounted(true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return result ?? false;
  }

  void _onSavePressed(BuildContext context, UserProfile currentProfile) {
    context.read<ProfileEditorBloc>().add(
      ProfileNip05Saved(currentProfile: currentProfile),
    );
  }

  bool _isDirty(ProfileEditorState editorState) {
    final normalizedUsername = _usernameController.text.trim().toLowerCase();
    final initialUsername = editorState.initialUsername?.toLowerCase() ?? '';
    final normalizedExternal = _externalController.text.trim().toLowerCase();
    final initialExternal =
        editorState.initialExternalNip05?.trim().toLowerCase() ?? '';

    return switch (editorState.nip05Mode) {
      Nip05Mode.divine =>
        normalizedUsername != initialUsername ||
            editorState.initialExternalNip05 != null,
      Nip05Mode.external_ =>
        normalizedExternal != initialExternal ||
            editorState.initialUsername != null,
    };
  }
}

class _Nip05SettingsMissingProfile extends StatelessWidget {
  const _Nip05SettingsMissingProfile();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            DivineIcon(
              icon: DivineIconName.userCircle,
              color: context.vineColors.secondaryText,
              size: 48,
            ),
            Text(
              context.l10n.nostrSettingsNip05ProfileRequired,
              textAlign: TextAlign.center,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            DivineButton(
              size: DivineButtonSize.small,
              label: context.l10n.nostrSettingsNip05CreateProfileAction,
              onPressed: () async {
                await context.push(ProfileSetupScreen.setupPath);
                if (!context.mounted) return;
                context.read<MyProfileBloc>().add(
                  const MyProfileLoadRequested(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Nip05SettingsLoadError extends StatelessWidget {
  const _Nip05SettingsLoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            DivineIcon(
              icon: DivineIconName.warningCircle,
              color: context.vineColors.secondaryText,
              size: 48,
            ),
            Text(
              context.l10n.profilePleaseTryAgain,
              textAlign: TextAlign.center,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            DivineButton(
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              label: context.l10n.profileRetryButton,
              onPressed: () {
                context.read<MyProfileBloc>().add(
                  const MyProfileLoadRequested(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

UserProfile? _profileFromState(MyProfileState state) {
  return switch (state) {
    MyProfileLoading(:final profile) => profile,
    MyProfileLoaded(:final profile) => profile,
    MyProfileUpdated(:final profile) => profile,
    _ => null,
  };
}

String? _extractedUsernameFromState(MyProfileState state) {
  return switch (state) {
    MyProfileLoading(:final extractedUsername) => extractedUsername,
    MyProfileLoaded(:final extractedUsername) => extractedUsername,
    MyProfileUpdated(:final extractedUsername) => extractedUsername,
    _ => null,
  };
}

String? _externalNip05FromState(MyProfileState state) {
  return switch (state) {
    MyProfileLoading(:final externalNip05) => externalNip05,
    MyProfileLoaded(:final externalNip05) => externalNip05,
    MyProfileUpdated(:final externalNip05) => externalNip05,
    _ => null,
  };
}
