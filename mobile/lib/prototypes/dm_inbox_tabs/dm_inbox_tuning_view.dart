// ABOUTME: PROTOTYPE (#8076) — tuning panel for the inbox classifier.
// ABOUTME: Every value here is a Trust & Safety product decision, surfaced as
// ABOUTME: a control so the tradeoffs can be argued about concretely rather
// ABOUTME: than in the abstract.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_settings.dart';

/// Full-screen tuning panel.
///
/// Save pops the edited [DmPrototypeSettings]; back pops nothing, which
/// discards every edit.
class DmInboxTuningView extends StatefulWidget {
  const DmInboxTuningView({required this.settings, super.key});

  final DmPrototypeSettings settings;

  @override
  State<DmInboxTuningView> createState() => _DmInboxTuningViewState();
}

/// Community recipes, by name. The shield label is worked out from these, so
/// it stays right when the panel is reopened on saved weights.
const _recipes = {
  'Quiet Porch': DmSpamHeuristics(
    spamThreshold: 42,
    weightHighFanOut: 70,
    weightContainsLink: 45,
    weightReportedByOthers: 75,
    weightHasDivineVideos: -25,
    weightPriorPublicInteraction: -40,
  ),
  'Creator Open Door': DmSpamHeuristics(
    spamThreshold: 65,
    weightHighFanOut: 65,
    weightReportedByOthers: 80,
    weightPerMutualConnection: -18,
    weightHasDivineVideos: -30,
  ),
};

class _DmInboxTuningViewState extends State<DmInboxTuningView> {
  late DmPrototypeSettings _settings = widget.settings;

  String get _shieldLabel {
    final heuristics = _settings.heuristics;
    if (heuristics == const DmSpamHeuristics()) return 'Default';
    for (final MapEntry(:key, :value) in _recipes.entries) {
      if (value == heuristics) return key;
    }
    return 'Custom';
  }

  void _update(DmSpamHeuristics next) =>
      setState(() => _settings = _settings.copyWith(heuristics: next));

  void _reset() => _update(const DmSpamHeuristics());

  void _applyRecipe(String name) {
    _update(_recipes[name]!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name applied. Review the sliders before saving.'),
      ),
    );
  }

  void _shareRecipe() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Share preview: settings only — never messages, contacts, or account data.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final h = _settings.heuristics;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 4,
        title: Text(
          'My request filter',
          style: VineTheme.titleLargeFont(color: colors.primaryText),
        ),
        actions: [
          DivineIconButton(
            icon: DivineIconName.share,
            tooltip: 'Share filter recipe',
            semanticLabel: 'Share filter recipe',
            onPressed: _shareRecipe,
          ),
          DivineIconButton(
            icon: DivineIconName.arrowCounterClockwise,
            tooltip: 'Reset to defaults',
            semanticLabel: 'Reset to defaults',
            onPressed: _reset,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
        children: [
          _FilterHero(label: _shieldLabel, onShare: _shareRecipe),
          const SizedBox(height: 20),
          _Section(
            title: 'Remix a community filter',
            icon: DivineIconName.users,
            blurb:
                'Start with settings someone else shared, then make them '
                'yours. Recipes never include messages, contacts, or '
                'account data.',
            children: [
              _RecipeTile(
                title: 'Quiet Porch',
                author: 'Liz',
                description:
                    'Strict on bursts and links; generous to creators.',
                onApply: () => _applyRecipe('Quiet Porch'),
              ),
              _RecipeTile(
                title: 'Creator Open Door',
                author: 'Community Safety',
                description:
                    'Welcomes established creators and trusted mutuals.',
                onApply: () => _applyRecipe('Creator Open Door'),
              ),
            ],
          ),
          _Section(
            title: 'Research session',
            icon: DivineIconName.eye,
            blurb:
                'For facilitators. Changing the presentation resets what '
                'was opened, replied to, marked not spam, removed or '
                'blocked, so each condition starts the same.',
            children: [
              for (final presentation in RequestPresentation.values)
                DivineSelectableRow(
                  title: presentation.label,
                  subtitle: presentation.description,
                  isSelected: _settings.presentation == presentation,
                  onTap: () => setState(
                    () => _settings = _settings.copyWith(
                      presentation: presentation,
                    ),
                  ),
                ),
              DivineSwitchTile(
                title: 'Show scores',
                subtitle:
                    'Numbers and the threshold on each row, and the link and '
                    'media reasons on unopened requests. Keep this off '
                    'while a participant is using the app.',
                value: _settings.showScores,
                onChanged: (value) => setState(
                  () => _settings = _settings.copyWith(showScores: value),
                ),
              ),
            ],
          ),
          _Section(
            title: 'Layout',
            icon: DivineIconName.sealCheckFill,
            children: [
              _PlacementPicker(
                placement: _settings.placement,
                onChanged: (value) => setState(
                  () => _settings = _settings.copyWith(placement: value),
                ),
              ),
            ],
          ),
          _Section(
            title: 'Threshold',
            icon: DivineIconName.prohibit,
            blurb:
                'A request collapses into Likely spam once its risk score '
                'reaches this. Lower catches more spam, and more innocent '
                'people with it.',
            children: [
              _Slider(
                label: 'Likely-spam threshold',
                value: h.spamThreshold,
                min: 10,
                max: 150,
                onChanged: (v) => _update(h.copyWith(spamThreshold: v)),
              ),
            ],
          ),
          _Section(
            title: 'Risk signals',
            icon: DivineIconName.warning,
            accent: context.vineColors.onErrorContainer,
            blurb:
                'Added to the score when the signal fires. The strongest '
                'two are behavioural — what the sender did to other people '
                '— rather than anything about who they are.',
            children: [
              _Slider(
                label: 'Reported by other people',
                value: h.weightReportedByOthers,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    _update(h.copyWith(weightReportedByOthers: v)),
              ),
              _Slider(
                label: 'Messaged many new people recently',
                value: h.weightHighFanOut,
                min: 0,
                max: 100,
                onChanged: (v) => _update(h.copyWith(weightHighFanOut: v)),
              ),
              _Slider(
                label: 'First seen recently',
                value: h.weightNewAccount,
                min: 0,
                max: 100,
                onChanged: (v) => _update(h.copyWith(weightNewAccount: v)),
              ),
              _Slider(
                label: 'Has not posted on Divine',
                value: h.weightNoDivineVideos,
                min: 0,
                max: 100,
                onChanged: (v) => _update(h.copyWith(weightNoDivineVideos: v)),
              ),
              _Slider(
                label: 'No profile name or photo',
                value: h.weightNoProfileMetadata,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    _update(h.copyWith(weightNoProfileMetadata: v)),
              ),
              _Slider(
                label: 'No connections in common',
                value: h.weightNoMutualConnections,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    _update(h.copyWith(weightNoMutualConnections: v)),
              ),
              _Slider(
                label: 'First message contains a link',
                value: h.weightContainsLink,
                min: 0,
                max: 100,
                onChanged: (v) => _update(h.copyWith(weightContainsLink: v)),
              ),
              _Slider(
                label: 'First message contains media',
                value: h.weightContainsMedia,
                min: 0,
                max: 100,
                onChanged: (v) => _update(h.copyWith(weightContainsMedia: v)),
              ),
              _Slider(
                label: 'Added you to a group',
                value: h.weightUnknownGroupInvite,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    _update(h.copyWith(weightUnknownGroupInvite: v)),
              ),
            ],
          ),
          _Section(
            title: 'Mitigating signals',
            icon: DivineIconName.shieldCheck,
            accent: context.vineColors.accentBrand,
            blurb:
                'Subtracted from the score. These are what keep a real '
                'person with an unusual profile out of the spam bucket.',
            children: [
              _Slider(
                label: 'You have interacted before',
                value: -h.weightPriorPublicInteraction,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    _update(h.copyWith(weightPriorPublicInteraction: -v)),
              ),
              _Slider(
                label: 'Follows you',
                value: -h.weightFollowsMe,
                min: 0,
                max: 100,
                onChanged: (v) => _update(h.copyWith(weightFollowsMe: -v)),
              ),
              _Slider(
                label: 'Per connection in common',
                value: -h.weightPerMutualConnection,
                min: 0,
                max: 50,
                onChanged: (v) =>
                    _update(h.copyWith(weightPerMutualConnection: -v)),
              ),
              _Slider(
                label: 'Posts on Divine',
                value: -h.weightHasDivineVideos,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    _update(h.copyWith(weightHasDivineVideos: -v)),
              ),
              _Slider(
                label: 'Seen on Divine for a long time',
                value: -h.weightEstablishedAccount,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    _update(h.copyWith(weightEstablishedAccount: -v)),
              ),
            ],
          ),
          _Section(
            title: 'Signal definitions',
            icon: DivineIconName.info,
            blurb:
                'There is no authoritative npub creation date, so the two '
                'age thresholds count days since Divine first observed a '
                'signed event.',
            children: [
              _Slider(
                label: 'First seen recently is under',
                unit: 'days',
                value: h.newAccountDays,
                min: 1,
                // Kept under the other age threshold so no age counts as
                // both new and established.
                max: math.min(90, h.establishedAccountDays - 1),
                onChanged: (v) => _update(h.copyWith(newAccountDays: v)),
              ),
              _Slider(
                label: 'Seen for a long time is over',
                unit: 'days',
                value: h.establishedAccountDays,
                min: math.max(30, h.newAccountDays + 1),
                max: 730,
                onChanged: (v) =>
                    _update(h.copyWith(establishedAccountDays: v)),
              ),
              _Slider(
                label: 'High fan-out is',
                unit: 'new chats',
                value: h.fanOutThreshold,
                min: 1,
                max: 100,
                onChanged: (v) => _update(h.copyWith(fanOutThreshold: v)),
              ),
              _Slider(
                label: 'Reported is',
                unit: 'reporters',
                value: h.reporterThreshold,
                min: 1,
                max: 25,
                onChanged: (v) => _update(h.copyWith(reporterThreshold: v)),
              ),
              _Slider(
                label: 'Connections stop counting after',
                value: h.mutualConnectionCap,
                min: 1,
                max: 20,
                onChanged: (v) => _update(h.copyWith(mutualConnectionCap: v)),
              ),
            ],
          ),
          DivineButton(
            label: 'Save filter',
            expanded: true,
            onPressed: () => Navigator.of(context).pop(_settings),
          ),
          const SizedBox(height: 10),
          DivineButton(
            label: 'Share as a filter recipe',
            leadingIcon: DivineIconName.shareNetwork,
            expanded: true,
            type: DivineButtonType.secondary,
            onPressed: _shareRecipe,
          ),
        ],
      ),
    );
  }
}

class _FilterHero extends StatelessWidget {
  const _FilterHero({required this.label, required this.onShare});

  final String label;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: colors.accentBrand.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          DivineIcon(
            icon: DivineIconName.shieldCheck,
            color: colors.accentBrand,
            size: 28,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  'Shield: $label',
                  style: VineTheme.titleLargeFont(color: colors.primaryText),
                ),
                Text(
                  'Decide what reaches Requests and what waits in Likely spam. '
                  'Official Divine identities and existing chats are never filtered.',
                  style: VineTheme.bodyMediumFont(
                    color: colors.onSurfaceVariant,
                  ).copyWith(height: 1.4),
                ),
                DivineButton(
                  label: 'Share this setup',
                  leadingIcon: DivineIconName.share,
                  type: DivineButtonType.link,
                  onPressed: onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.title,
    required this.author,
    required this.description,
    required this.onApply,
  });

  final String title;
  final String author;
  final String description;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  title,
                  style: VineTheme.titleSmallFont(color: colors.primaryText),
                ),
                Text(
                  'by $author · $description',
                  style: VineTheme.bodySmallFont(color: colors.onSurfaceMuted),
                ),
              ],
            ),
          ),
          DivineButton(
            label: 'Remix',
            type: DivineButtonType.secondary,
            size: DivineButtonSize.small,
            onPressed: onApply,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.blurb,
    this.accent,
  });

  final String title;
  final DivineIconName icon;
  final String? blurb;
  final Color? accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 9,
            children: [
              DivineIcon(
                icon: icon,
                color: accent ?? colors.onSurfaceMuted,
                size: 15,
              ),
              Text(
                title,
                style: VineTheme.titleSmallFont(color: colors.primaryText),
              ),
            ],
          ),
          if (blurb != null)
            Text(
              blurb!,
              style: VineTheme.bodySmallFont(
                color: colors.onSurfaceMuted,
              ).copyWith(height: 1.45),
            ),
          // Material, not a decorated Container: DivineSwitchTile renders a
          // ListTile, which paints its background and ink splash on the
          // nearest Material ancestor. A coloured DecoratedBox in between
          // hides both, and Flutter asserts on it — opening this panel threw
          // 'ListTile background color or ink splashes may be invisible'.
          Material(
            color: colors.surfaceContainer.withValues(alpha: 0.55),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacementPicker extends StatelessWidget {
  const _PlacementPicker({required this.placement, required this.onChanged});

  final OfficialPlacement placement;
  final ValueChanged<OfficialPlacement> onChanged;

  @override
  Widget build(BuildContext context) {
    final isOwnTab = placement == OfficialPlacement.ownTab;
    return DivineSwitchTile(
      title: 'Official gets its own tab',
      subtitle: isOwnTab
          ? 'Four tabs. Findable and hard to impersonate, but it is an extra '
                'place to look.'
          : 'Three tabs. Official pins to the top of Inbox, matching '
                '"official messages go directly to the inbox".',
      value: isOwnTab,
      onChanged: (value) => onChanged(
        value ? OfficialPlacement.ownTab : OfficialPlacement.pinnedInInbox,
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit,
  });

  final String label;
  final String? unit;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.bodyMediumFont(color: colors.primaryText),
                ),
              ),
              _ValueChip(value: value, unit: unit),
            ],
          ),
          DivineSlider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            trackHeight: 5,
            thumbHeight: 24,
            semanticLabel: label,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.value, this.unit});

  final int value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return MediaQuery.withNoTextScaling(
      child: Container(
        constraints: const BoxConstraints(minWidth: 34),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.containerLow,
          borderRadius: const BorderRadius.all(Radius.circular(7)),
        ),
        alignment: Alignment.center,
        child: Text(
          unit == null ? '$value' : '$value $unit',
          style: VineTheme.labelMediumFont(color: colors.primaryText),
        ),
      ),
    );
  }
}

extension on RequestPresentation {
  String get label => switch (this) {
    RequestPresentation.contextOnly => 'Sender context only',
    RequestPresentation.contextWithReasons => 'Context and reasons',
    RequestPresentation.contextWithCaution => 'Context and a caution label',
  };

  String get description => switch (this) {
    RequestPresentation.contextOnly =>
      'Videos, loops and a mutual connection. No reasons.',
    RequestPresentation.contextWithReasons =>
      'Adds a "Why is this here?" control people can open.',
    RequestPresentation.contextWithCaution =>
      'Adds one line of factual caution, such as "First seen recently".',
  };
}
