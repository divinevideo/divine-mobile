// ABOUTME: Follow action for hashtag pages, with confirmed and pending state.
// ABOUTME: Uses the account-scoped follows repository through its Cubit.
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/hashtag_follows/cubit/hashtag_follows_cubit.dart';
import 'package:openvine/features/hashtag_follows/view/hashtag_follows_scope.dart';
import 'package:openvine/l10n/l10n.dart';

class HashtagFollowButton extends StatelessWidget {
  const HashtagFollowButton({required this.hashtag, super.key});
  final String hashtag;

  @override
  Widget build(BuildContext context) => HashtagFollowsScope(
    anonymousLabel: context.l10n.listFollowButton,
    child: _HashtagFollowView(hashtag: hashtag),
  );
}

class _HashtagFollowView extends StatelessWidget {
  const _HashtagFollowView({required this.hashtag});
  final String hashtag;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<HashtagFollowsCubit, HashtagFollowsState>(
        builder: (context, state) {
          final tag = hashtag
              .trim()
              .replaceFirst(RegExp('^#'), '')
              .toLowerCase();
          final followed = state.subscriptions.any(
            (value) => value.canonicalTag == tag,
          );
          final cubit = context.read<HashtagFollowsCubit>();
          final pending = state.pendingTags.contains(tag);
          return DivineButton(
            label: state.hasReadError
                ? context.l10n.commonRetry
                : followed
                ? context.l10n.listFollowingButton
                : context.l10n.listFollowButton,
            size: DivineButtonSize.small,
            type: DivineButtonType.secondary,
            isLoading: state.isLoading || pending,
            onPressed: state.isLoading || pending
                ? null
                : () {
                    if (state.hasReadError) {
                      cubit.initialize();
                    } else if (followed) {
                      cubit.unfollow(hashtag);
                    } else {
                      cubit.follow(hashtag);
                    }
                  },
          );
        },
      );
}
