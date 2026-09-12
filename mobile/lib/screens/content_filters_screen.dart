// ABOUTME: Per-category content filter settings screen with Show/Warn/Hide controls
// ABOUTME: Bluesky-inspired grouped layout with segmented buttons per content category

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/content_filters/content_filters_cubit.dart';
import 'package:openvine/blocs/content_filters/content_filters_state.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Page: bridges the filter + age services into [ContentFiltersCubit].
class ContentFiltersScreen extends ConsumerWidget {
  const ContentFiltersScreen({super.key});

  static const routeName = 'content-filters';
  static const String path = RoutePaths.contentFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentFilterService = ref.watch(contentFilterServiceProvider);
    final ageVerificationService = ref.watch(ageVerificationServiceProvider);
    return BlocProvider(
      // Both are moderation services that can be rebuilt; re-key so the Cubit
      // reloads with fresh instances rather than operating on stale ones.
      key: ValueKey((contentFilterService, ageVerificationService)),
      create: (_) => ContentFiltersCubit(
        contentFilterService: contentFilterService,
        ageVerificationService: ageVerificationService,
      )..load(),
      child: const ContentFiltersView(),
    );
  }
}

/// View: renders the per-category filter controls from the Cubit state.
class ContentFiltersView extends StatelessWidget {
  @visibleForTesting
  const ContentFiltersView({super.key});

  static const List<ContentLabel> _adultLabels = [
    ContentLabel.nudity,
    ContentLabel.sexual,
  ];

  static const List<ContentLabel> _substanceLabels = [
    ContentLabel.alcohol,
    ContentLabel.tobacco,
  ];

  static const List<ContentLabel> _otherLabels = [
    ContentLabel.profanity,
    ContentLabel.flashingLights,
    ContentLabel.gambling,
    ContentLabel.spoiler,
    ContentLabel.misleading,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.contentPreferencesContentFilters,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<ContentFiltersCubit, ContentFiltersState>(
            builder: (context, state) {
              if (state.status != ContentFiltersStatus.ready) {
                return const Center(child: BrandedLoadingIndicator(size: 60));
              }
              final cubit = context.read<ContentFiltersCubit>();
              return ListView(
                padding: .only(
                  bottom: 32 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  if (!state.isAgeVerified) const _AgeGateBanner(),
                  _CategoryGroup(
                    title: context.l10n.contentFiltersAdultContent,
                    labels: _adultLabels,
                    state: state,
                    onChanged: cubit.setPreference,
                  ),
                  _CategoryGroup(
                    title: context.l10n.contentFiltersSubstances,
                    labels: _substanceLabels,
                    state: state,
                    onChanged: cubit.setPreference,
                  ),
                  _CategoryGroup(
                    title: context.l10n.contentFiltersOther,
                    labels: _otherLabels,
                    state: state,
                    onChanged: cubit.setPreference,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AgeGateBanner extends StatelessWidget {
  const _AgeGateBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.vineColors.disabled, width: 0.5),
      ),
      child: Row(
        children: [
          DivineIcon(
            icon: DivineIconName.lockSimple,
            color: context.vineColors.onSurfaceMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.contentFiltersAgeGateMessage,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.title,
    required this.labels,
    required this.state,
    required this.onChanged,
  });

  final String title;
  final List<ContentLabel> labels;
  final ContentFiltersState state;
  final Future<void> Function(
    ContentLabel label,
    ContentFilterPreference preference,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: fixedRowTextScaleLimit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DivineSectionHeader(title),
          ...labels.map(
            (label) => _ContentFilterRow(
              label: label,
              preference: state.preferenceFor(label),
              locked: state.isLabelLocked(label),
              onChanged: (preference) {
                onChanged(label, preference);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentFilterRow extends StatelessWidget {
  const _ContentFilterRow({
    required this.label,
    required this.preference,
    required this.locked,
    required this.onChanged,
  });

  final ContentLabel label;
  final ContentFilterPreference preference;
  final bool locked;
  final ValueChanged<ContentFilterPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('content-filter-${label.value}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              localizedContentLabelName(context.l10n, label),
              style: VineTheme.bodyLargeFont(
                color: locked
                    ? context.vineColors.disabled
                    : context.vineColors.primaryText,
              ),
            ),
          ),
          _FilterSegmentedControl(
            value: preference,
            locked: locked,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterSegmentedControl extends StatelessWidget {
  const _FilterSegmentedControl({
    required this.value,
    required this.locked,
    required this.onChanged,
  });

  final ContentFilterPreference value;
  final bool locked;
  final ValueChanged<ContentFilterPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.vineColors.disabled, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterSegment(
            label: context.l10n.contentFiltersShow,
            selected: value == ContentFilterPreference.show,
            locked: locked,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.show),
          ),
          _FilterSegment(
            label: context.l10n.contentFiltersWarn,
            selected: value == ContentFilterPreference.warn,
            locked: locked,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.warn),
          ),
          _FilterSegment(
            label: context.l10n.contentFiltersFilterOut,
            selected: value == ContentFilterPreference.hide,
            locked: locked,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.hide),
          ),
        ],
      ),
    );
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required String label,
    required bool selected,
    required bool locked,
    required VoidCallback? onTap,
  }) : _label = label,
       _selected = selected,
       _locked = locked,
       _onTap = onTap;

  final String _label;
  final bool _selected;
  final bool _locked;
  final VoidCallback? _onTap;

  @override
  Widget build(BuildContext context) {
    // MergeSemantics lifts the child Text's label onto this node instead of
    // repeating it in `label:`, so the announced string cannot drift from the
    // rendered one.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _onTap != null,
        selected: _selected,
        inMutuallyExclusiveGroup: true,
        child: GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              // The active segment stays green even when locked — dimming the
              // fill to `outlineDisabled` made it indistinguishable from the
              // card behind it, so a locked row showed no active mode at all.
              // Locked-ness is carried by the label colour instead.
              color: _selected ? VineTheme.vineGreen : VineTheme.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                _label,
                style: VineTheme.labelMediumFont(
                  color: _selected
                      ? context.vineColors.background
                      : _locked
                      ? context.vineColors.disabled
                      : context.vineColors.secondaryText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
