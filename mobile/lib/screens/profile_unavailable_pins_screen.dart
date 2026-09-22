// ABOUTME: Owner-only recovery page for unresolved pinned profile videos.
// ABOUTME: Lets creators remove stale coordinates without loading the videos.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_scope.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Route page: validates ownership and supplies the profile-feed state.
class ProfileUnavailablePinsPage extends ConsumerWidget {
  const ProfileUnavailablePinsPage({required this.npub, super.key});

  final String npub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = npubToHexOrNull(npub);
    final currentUser = ref.watch(authServiceProvider).currentPublicKeyHex;
    if (author == null ||
        currentUser == null ||
        author.toLowerCase() != currentUser.toLowerCase()) {
      return Scaffold(
        backgroundColor: context.vineColors.background,
        appBar: DiVineAppBar(
          title: context.l10n.profilePinRecoveryTitle,
          showBackButton: true,
          onBackPressed: context.safePop,
        ),
        body: Center(child: Text(context.l10n.profilePinRecoveryOwnerOnly)),
      );
    }

    return ProfileFeedScope(
      userIdHex: author,
      child: const ProfileUnavailablePinsView(),
    );
  }
}

/// View: renders the unavailable coordinates and dispatches owner mutations.
class ProfileUnavailablePinsView extends StatelessWidget {
  @visibleForTesting
  const ProfileUnavailablePinsView({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<ProfileFeedCubit, ProfileFeedState>(
    listenWhen: (previous, current) =>
        previous.unavailablePinFeedback != current.unavailablePinFeedback &&
        current.unavailablePinFeedback !=
            ProfileFeedUnavailablePinFeedback.none,
    listener: (context, state) {
      final l10n = context.l10n;
      final message = switch (state.unavailablePinFeedback) {
        ProfileFeedUnavailablePinFeedback.none => null,
        ProfileFeedUnavailablePinFeedback.removed =>
          l10n.profilePinUnavailableRemoved,
        ProfileFeedUnavailablePinFeedback.connectionFailed =>
          l10n.profilePinUnavailableConnectionFailed,
        ProfileFeedUnavailablePinFeedback.failed =>
          l10n.profilePinUnavailableRemoveFailed,
      };
      if (message != null) {
        announceDetached(
          context,
          message,
          description: 'announce unavailable profile pin removal outcome',
          logName: 'ProfileUnavailablePinsScreen',
        );
      }
    },
    child: Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.profilePinRecoveryTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<ProfileFeedCubit, ProfileFeedState>(
            builder: (context, state) {
              if (state.unavailablePinnedCoordinates.isEmpty) {
                if (state.status == ProfileFeedStatus.initial ||
                    state.status == ProfileFeedStatus.loading ||
                    state.isInitialLoad) {
                  return const Center(child: BrandedLoadingIndicator());
                }
                if (state.status == ProfileFeedStatus.failure) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.profilePinRecoveryLoadFailed,
                            textAlign: TextAlign.center,
                            style: VineTheme.bodyMediumFont(
                              color: context.vineColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DivineButton(
                            label: context.l10n.profileRetryButton,
                            type: DivineButtonType.secondary,
                            onPressed: () => context
                                .read<ProfileFeedCubit>()
                                .add(const ProfileFeedRefreshRequested()),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.l10n.profilePinRecoveryEmpty,
                      textAlign: TextAlign.center,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.onSurface,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.unavailablePinnedCoordinates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final coordinate = state.unavailablePinnedCoordinates[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.vineColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.profilePinUnavailableLabel,
                          style: VineTheme.titleSmallFont(
                            color: context.vineColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          label:
                              '${context.l10n.profilePinUnavailableCoordinate}: '
                              '$coordinate',
                          child: SelectableText(
                            coordinate,
                            style: VineTheme.bodySmallFont(
                              color: context.vineColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: DivineButton(
                            label: context.l10n.profilePinRemoveUnavailable,
                            type: DivineButtonType.secondary,
                            isLoading: state.isPinMutationInFlight,
                            onPressed: state.isPinMutationInFlight
                                ? null
                                : () => context.read<ProfileFeedCubit>().add(
                                    ProfileFeedPinnedCoordinateRemoveRequested(
                                      coordinate,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}
