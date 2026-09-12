// ABOUTME: "Help classify this" bottom sheet — viewers suggest content
// ABOUTME: warnings for a video (#4771). Driven by CommunitySuggestCubit.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/community_suggest/community_suggest_cubit.dart';
import 'package:openvine/blocs/community_suggest/community_suggest_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// The "Help classify this" content-warning suggestion sheet.
class CommunitySuggestSheet {
  const CommunitySuggestSheet._();

  /// Opens the suggestion sheet for [video].
  static Future<void> show(
    BuildContext context, {
    required VideoEvent video,
    required CommunityContentLabelRepository repository,
    required String myPubkey,
  }) {
    return context.showVideoPausingVineBottomSheet<void>(
      maxChildSize: 1,
      initialChildSize: 0.9,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      showHeader: false,
      showDragHandle: false,
      // Preserves the pre-pause-integration presentation: the sheet stays in
      // the shell navigator rather than covering the tab bar.
      useRootNavigator: false,
      buildScrollBody: (scrollController) => BlocProvider(
        create: (_) => CommunitySuggestCubit(
          repository: repository,
          video: video,
          myPubkey: myPubkey,
        )..loadExisting(),
        child: CommunitySuggestView(scrollController: scrollController),
      ),
    );
  }
}

/// Inner view for [CommunitySuggestSheet]; consumes [CommunitySuggestCubit].
@visibleForTesting
class CommunitySuggestView extends StatelessWidget {
  /// Creates the view.
  const CommunitySuggestView({required this.scrollController, super.key});

  /// Scroll controller supplied by the enclosing draggable sheet.
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommunitySuggestCubit, CommunitySuggestState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CommunitySuggestStatus.success) {
          SemanticsService.sendAnnouncement(
            View.of(context),
            context.l10n.communitySuggestSuccess,
            Directionality.of(context),
          );
          Navigator.of(context).maybePop();
        } else if (state.status == CommunitySuggestStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.communitySuggestFailure)),
          );
        }
      },
      child: Column(
        children: [
          VineBottomSheetHeader(
            showDivider: false,
            leadingAction: DivineIconButton(
              icon: .x,
              type: .secondary,
              size: .small,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const _HeaderTitle(),
          ),
          Divider(
            height: 0,
            thickness: 0,
            color: context.vineColors.surfaceContainer,
          ),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: ContentLabel.values.length,
              separatorBuilder: (_, _) => Divider(
                height: 0,
                thickness: 0,
                color: context.vineColors.surfaceContainer,
              ),
              itemBuilder: (_, index) =>
                  _LabelTile(label: ContentLabel.values[index]),
            ),
          ),
          const _SubmitBar(),
        ],
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6,
      children: [
        Text(context.l10n.communitySuggestTitle),
        Text(
          context.l10n.communitySuggestSubtitle,
          textAlign: TextAlign.center,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _LabelTile extends StatelessWidget {
  const _LabelTile({required this.label});

  final ContentLabel label;

  @override
  Widget build(BuildContext context) {
    final selected = context.select(
      (CommunitySuggestCubit cubit) => cubit.state.selected.contains(label),
    );
    final alreadySuggested = context.select(
      (CommunitySuggestCubit cubit) =>
          cubit.state.alreadySuggested.contains(label.value),
    );

    return Semantics(
      button: true,
      selected: selected || alreadySuggested,
      label: localizedContentLabelName(context.l10n, label),
      child: Material(
        color: selected || alreadySuggested
            ? context.vineColors.surfaceContainer
            : VineTheme.transparent,
        child: InkWell(
          onTap: alreadySuggested
              ? null
              : () => context.read<CommunitySuggestCubit>().toggle(label),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Text(
                    localizedContentLabelName(context.l10n, label),
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ),
                if (alreadySuggested)
                  Text(
                    context.l10n.communitySuggestAlready,
                    style: VineTheme.labelSmallFont(
                      color: context.vineColors.secondaryText,
                    ),
                  )
                else
                  DivineIcon(
                    icon: selected ? .check : .plus,
                    color: selected
                        ? VineTheme.primary
                        : context.vineColors.secondaryText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar();

  @override
  Widget build(BuildContext context) {
    final canSubmit = context.select(
      (CommunitySuggestCubit cubit) => cubit.state.canSubmit,
    );
    final submitting = context.select(
      (CommunitySuggestCubit cubit) =>
          cubit.state.status == CommunitySuggestStatus.submitting,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: DivineButton(
        label: context.l10n.communitySuggestSubmit,
        isLoading: submitting,
        onPressed: canSubmit
            ? () => context.read<CommunitySuggestCubit>().submit()
            : null,
      ),
    );
  }
}
