import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/profile_setup/widgets/widgets.dart';
import 'package:openvine/widgets/profile/nostr_info_sheet_content.dart';

class ProfileSetupScreenView extends ConsumerStatefulWidget {
  const ProfileSetupScreenView({required this.isNewUser, super.key});
  final bool isNewUser;

  @override
  ConsumerState<ProfileSetupScreenView> createState() =>
      _ProfileSetupScreenViewState();
}

class _ProfileSetupScreenViewState
    extends ConsumerState<ProfileSetupScreenView> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _nip05Controller = TextEditingController();
  // Owned here (not in DisplayNameField) so the Save action can focus the
  // name field when it is left empty.
  final _nameFocusNode = FocusNode();
  // Owned here so the username field's next key can target it directly.
  final _bioFocusNode = FocusNode();
  bool _isLeavingProfileSetup = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onProfileTextChanged);
    _bioController.addListener(_onProfileTextChanged);
    _websiteController.addListener(_onProfileTextChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onProfileTextChanged);
    _bioController.removeListener(_onProfileTextChanged);
    _websiteController.removeListener(_onProfileTextChanged);
    _nameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _nip05Controller.dispose();
    _nameFocusNode.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  void _onProfileTextChanged() {
    if (!mounted) return;
    context.read<ProfileEditorBloc>()
      ..add(DisplayNameChanged(_nameController.text))
      ..add(AboutChanged(_bioController.text))
      ..add(WebsiteChanged(_websiteController.text));
  }

  @override
  Widget build(BuildContext context) {
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;

    return ProfileSetupListeners(
      isNewUser: widget.isNewUser,
      nameController: _nameController,
      bioController: _bioController,
      websiteController: _websiteController,
      nip05Controller: _nip05Controller,
      child: BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
        builder: (context, profileEditorState) {
          return PopScope(
            canPop:
                _isLeavingProfileSetup || !profileEditorState.hasUnsavedChanges,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && profileEditorState.hasUnsavedChanges) {
                _confirmLeaveWithUnsavedChanges(
                  context,
                  state: profileEditorState,
                  pubkey: pubkey,
                );
              }
            },
            child: Scaffold(
              backgroundColor: context.vineColors.surfaceContainerHigh,
              appBar: DiVineAppBar(
                title: context.l10n.profileSetupEditProfileTitle,
                showBackButton: true,
                backButtonSemanticLabel: context.l10n.profileSetupBackLabel,
                onBackPressed: () => _handleLeavePressed(
                  context,
                  state: profileEditorState,
                  pubkey: pubkey,
                ),
                style: DiVineAppBarStyle(
                  iconButtonBackgroundColor:
                      context.vineColors.surfaceContainer,
                  iconButtonBorderSide: BorderSide(
                    color: context.vineColors.outlineMuted,
                    width: 2,
                  ),
                  horizontalPadding: 12,
                ),
                actions: [
                  DiVineAppBarAction(
                    icon: SvgIconSource(DivineIconName.info.assetPath),
                    onPressed: () => _showNostrInfoSheet(context),
                    tooltip: context.l10n.profileSetupAboutNostr,
                    semanticLabel: context.l10n.profileSetupAboutNostr,
                  ),
                ],
              ),
              body: GestureDetector(
                onTap: () {
                  // Dismiss keyboard when tapping outside text fields
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: SafeArea(
                  bottom: false, // Don't add bottom padding - let content extend to bottom
                  // Rounds the body's top corners the way the app bar's
                  // `radius 96` pieces do. Outside the scroll view on purpose:
                  // the corners belong to the viewport edge, so they stay put
                  // while the content moves under them. The fill behind the
                  // clip carries the app bar's own colour, so the notches read
                  // as a continuation of the bar rather than a hole.
                  // Material, not ColoredBox: descendant ListTiles paint their
                  // ink onto the nearest Material ancestor, and a bare
                  // ColoredBox in between would swallow it.
                  child: Material(
                    color: context.vineColors.nav,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(bodyTopRadius),
                      ),
                      child: SingleChildScrollView(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                textSelectionTheme: TextSelectionThemeData(
                                  cursorColor: VineTheme.primary,
                                  selectionColor: VineTheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Banner and avatar are both edited from here, so
                                  // neither has a section further down the form.
                                  ProfileHeaderPreview(
                                    nameController: _nameController,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: 16,
                                      children: [
                                        DisplayNameField(
                                          controller: _nameController,
                                          focusNode: _nameFocusNode,
                                        ),
                                        UsernameField(
                                          controller: _nip05Controller,
                                          nextFocusNode: _bioFocusNode,
                                        ),
                                        const Nip05Row(),
                                        BioField(
                                          controller: _bioController,
                                          focusNode: _bioFocusNode,
                                        ),
                                        const PublicKeyRow(),

                                        // Below here: still shipped, but absent from
                                        // the current design for this screen. Kept
                                        // in the same style rather than dropped.
                                        WebsiteField(
                                          controller: _websiteController,
                                        ),
                                        const VerifiedAccountsSection(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    spacing: 16,
                    children: [
                      Expanded(
                        child: DivineButton(
                          label: context.l10n.commonCancel,
                          type: DivineButtonType.secondary,
                          expanded: true,
                          onPressed:
                              profileEditorState.status ==
                                  ProfileEditorStatus.loading
                              ? null
                              : () => _handleLeavePressed(
                                  context,
                                  state: profileEditorState,
                                  pubkey: pubkey,
                                ),
                        ),
                      ),
                      if (pubkey != null)
                        Expanded(
                          child: SaveButton(
                            canSave: profileEditorState.isSaveReady,
                            onSave: () => _saveProfile(context, pubkey: pubkey),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleLeavePressed(
    BuildContext context, {
    required ProfileEditorState state,
    required String? pubkey,
  }) {
    if (state.hasUnsavedChanges) {
      _confirmLeaveWithUnsavedChanges(context, state: state, pubkey: pubkey);
      return;
    }
    _leaveProfileSetup(context);
  }

  void _confirmLeaveWithUnsavedChanges(
    BuildContext context, {
    required ProfileEditorState state,
    required String? pubkey,
  }) {
    final canSave = pubkey != null && state.isSaveReady;
    VineBottomSheetPrompt.show<void>(
      context: context,
      sticker: .alert,
      title: context.l10n.profileSetupUnsavedChangesTitle,
      subtitle: context.l10n.profileSetupUnsavedChangesSubtitle,
      primaryButtonText: canSave
          ? context.l10n.profileSetupUnsavedChangesSaveButton
          : null,
      secondaryButtonText: context.l10n.profileSetupUnsavedChangesDiscardButton,
      tertiaryButtonText: context.l10n.profileSetupUnsavedChangesKeepButton,
      onPrimaryPressed: !canSave
          ? null
          : () {
              context.pop();
              _saveProfile(context, pubkey: pubkey);
            },
      onSecondaryPressed: () {
        context.pop();
        context.read<ProfileEditorBloc>().add(const ProfileEditDiscarded());
        _leaveProfileSetup(context);
      },
      onTertiaryPressed: context.pop,
    );
  }

  void _saveProfile(BuildContext context, {required String pubkey}) {
    if (_nameController.text.trim().isEmpty) {
      _nameFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.profileSetupDisplayNameRequired,
          error: true,
        ),
      );
      return;
    }
    context.read<ProfileEditorBloc>().add(
      ProfileSaved(
        pubkey: pubkey,
        displayName: _nameController.text,
        about: _bioController.text,
        website: _websiteController.text,
        username: _nip05Controller.text,
        // Picture and banner are owned by bloc state. The bloc reads
        // pendingPictureUrl / pendingBannerUrl / pendingBannerColor /
        // persistedBanner directly via `effectiveBanner`, so we don't pass
        // them through the event.
      ),
    );
  }

  void _leaveProfileSetup(BuildContext context) {
    if (!_isLeavingProfileSetup && mounted) {
      if (widget.isNewUser) {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .recordOnboardingStep(
                flow: ProductAnalyticsV2OnboardingFlow.accountSetup,
                step: ProductAnalyticsV2OnboardingStep.identity,
                result: ProductAnalyticsV2OnboardingResult.skipped,
                reason: ProductAnalyticsV2OnboardingReason.dismissed,
              ),
        );
      }
      setState(() => _isLeavingProfileSetup = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
        return;
      }
      final authService = ref.read(authServiceProvider);
      final currentPubkey = authService.currentPublicKeyHex;
      if (currentPubkey != null) {
        final npub = authService.currentNpub;
        context.go('/profile/$npub');
      } else {
        context.go('/home/0');
      }
    });
  }

  void _showNostrInfoSheet(BuildContext context) {
    // Unfocus any field before opening sheet
    FocusManager.instance.primaryFocus?.unfocus();
    VineBottomSheet.show<void>(
      context: context,
      children: const [NostrInfoSheetContent()],
    ).then((_) {
      // Unfocus after sheet is dismissed to prevent auto-focus on form fields
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
}
