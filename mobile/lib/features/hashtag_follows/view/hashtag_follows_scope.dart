// ABOUTME: Creates a fresh hashtag follows Cubit for the current account.
// ABOUTME: Keeps account wiring outside reusable follow and management views.
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/hashtag_follows/cubit/hashtag_follows_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/hashtag_subscription_repository_provider.dart';
import 'package:openvine/router/route_paths.dart';

class HashtagFollowsScope extends ConsumerWidget {
  const HashtagFollowsScope({
    required this.child,
    this.anonymousLabel,
    super.key,
  });
  final Widget child;
  final String? anonymousLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(hashtagSubscriptionRepositoryProvider);
    if (repository == null) {
      return DivineButton(
        label: anonymousLabel ?? context.l10n.profileSignInButton,
        size: DivineButtonSize.small,
        onPressed: () => context.push(RoutePaths.welcomeLoginOptions),
      );
    }
    return BlocProvider(
      key: ObjectKey(repository),
      create: (_) => HashtagFollowsCubit(repository: repository)..initialize(),
      child: BlocListener<HashtagFollowsCubit, HashtagFollowsState>(
        listenWhen: (previous, next) =>
            !previous.hasWriteError && next.hasWriteError,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              context.l10n.profileNotifyUpdateFailed,
              error: true,
            ),
          );
          context.read<HashtagFollowsCubit>().dismissWriteError();
        },
        child: child,
      ),
    );
  }
}
