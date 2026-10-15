// ABOUTME: Full-screen management for the current account's followed hashtags.
// ABOUTME: Opens existing hashtag pages and supports explicit unfollow actions.
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/hashtag_follows/cubit/hashtag_follows_cubit.dart';
import 'package:openvine/features/hashtag_follows/view/hashtag_follows_scope.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';

class FollowedHashtagsPage extends StatelessWidget {
  const FollowedHashtagsPage({super.key});
  static const path = '/followed-hashtags';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vineColors.background,
    appBar: DiVineAppBar(
      title: context.l10n.followedHashtagsTitle,
      showBackButton: true,
      onBackPressed: context.safePop,
    ),
    body: const HashtagFollowsScope(child: _FollowedHashtagsView()),
  );
}

class _FollowedHashtagsView extends StatelessWidget {
  const _FollowedHashtagsView();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<HashtagFollowsCubit, HashtagFollowsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: DivineCircularProgressIndicator());
          }
          if (state.hasReadError) {
            return Center(
              child: DivineButton(
                label: context.l10n.commonRetry,
                onPressed: context.read<HashtagFollowsCubit>().initialize,
              ),
            );
          }
          if (state.subscriptions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.followedHashtagsEmpty,
                  textAlign: TextAlign.center,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: state.subscriptions.length,
            itemBuilder: (context, index) {
              final tag = state.subscriptions[index];
              final pending = state.pendingTags.contains(tag.canonicalTag);
              return ListTile(
                title: Text(
                  '#${tag.displayTag}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                onTap: () => context.push(
                  HashtagScreenRouter.pathForTag(tag.displayTag),
                ),
                trailing: DivineButton(
                  label: context.l10n.unfollowConfirmButton,
                  size: DivineButtonSize.small,
                  type: DivineButtonType.secondary,
                  isLoading: pending,
                  onPressed: pending
                      ? null
                      : () => context.read<HashtagFollowsCubit>().unfollow(
                          tag.canonicalTag,
                        ),
                ),
              );
            },
          );
        },
      );
}
