// ABOUTME: Full-screen flow for picking badge recipients and publishing the
// ABOUTME: NIP-58 award event for them.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/badges/badge_detail_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Awards the badge at the routed coordinate to a chosen set of people.
class BadgeAwardScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'badgeAward';

  /// Route path used by GoRouter.
  static const path = '/badges/b/:naddr/award';

  /// Path that opens the award flow for [coordinate].
  static String pathFor(BadgeCoordinate coordinate) =>
      '/badges/b/${coordinate.toNaddr()}/award';

  /// Creates the award screen.
  const BadgeAwardScreen({required this.coordinate, super.key});

  /// Address of the badge being awarded.
  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(badgeRepositoryProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    return BlocProvider(
      key: ValueKey((repository, coordinate)),
      create: (_) => BadgeDetailCubit(
        repository: repository,
        contentBlocklistRepository: contentBlocklistRepository,
        coordinate: coordinate,
      ),
      child: const BadgeAwardView(),
    );
  }
}

/// Body of [BadgeAwardScreen].
class BadgeAwardView extends StatefulWidget {
  /// Creates the award view.
  @visibleForTesting
  const BadgeAwardView({super.key});

  @override
  State<BadgeAwardView> createState() => _BadgeAwardViewState();
}

class _BadgeAwardViewState extends State<BadgeAwardView> {
  final _manualController = TextEditingController();

  /// Recipients chosen through the people picker, in pick order.
  final List<String> _pickedPubkeys = [];

  /// Recipients resolved from the pasted-keys field.
  List<String> _pastedPubkeys = const [];

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  /// All recipients, deduplicated across both input paths.
  List<String> get _recipients =>
      <String>{..._pickedPubkeys, ..._pastedPubkeys}.toList(growable: false);

  Future<void> _pickPeople() async {
    final picked = await showUserPickerSheet(
      context,
      autoFocus: true,
      filterMode: UserPickerFilterMode.allUsers,
      title: context.l10n.badgeAwardPickAction,
      excludePubkeys: _pickedPubkeys.toSet(),
      onUserToggled: (profile) {
        setState(() {
          if (!_pickedPubkeys.remove(profile.pubkey)) {
            _pickedPubkeys.add(profile.pubkey);
          }
        });
      },
    );
    if (picked == null) return;
    setState(() {
      for (final profile in picked) {
        if (!_pickedPubkeys.contains(profile.pubkey)) {
          _pickedPubkeys.add(profile.pubkey);
        }
      }
    });
  }

  void _manualChanged(String value) {
    final parsed = parseBadgeRecipients(value);
    if (parsed.length == _pastedPubkeys.length &&
        parsed.every(_pastedPubkeys.contains)) {
      return;
    }
    setState(() => _pastedPubkeys = parsed);
  }

  void _removeRecipient(String pubkey) {
    setState(() {
      _pickedPubkeys.remove(pubkey);
      _pastedPubkeys = _pastedPubkeys
          .where((candidate) => candidate != pubkey)
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recipients = _recipients;
    return BlocConsumer<BadgeDetailCubit, BadgeDetailState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus,
      listener: (context, state) {
        if (state.actionStatus == BadgeDetailActionStatus.completed) {
          context.safePop(result: true, fallback: BadgesScreen.path);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: DiVineAppBar(
            title: l10n.badgeAwardTitle,
            showBackButton: true,
            onBackPressed: () => context.safePop(fallback: BadgesScreen.path),
          ),
          backgroundColor: context.vineColors.background,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      DivineButton(
                        label: l10n.badgeAwardPickAction,
                        type: DivineButtonType.secondary,
                        leadingIcon: DivineIconName.users,
                        onPressed: state.isBusy ? null : _pickPeople,
                      ),
                      DivineTextField(
                        labelText: l10n.badgeAwardManualLabel,
                        hintText: l10n.badgeAwardManualHint,
                        controller: _manualController,
                        filled: true,
                        fillColor: context.vineColors.surfaceContainer,
                        primaryWhenFilled: true,
                        enabled: !state.isBusy,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.none,
                        onChanged: _manualChanged,
                      ),
                      if (recipients.isEmpty)
                        Text(
                          l10n.badgeAwardEmptyHint,
                          style: VineTheme.bodySmallFont(
                            color: context.vineColors.onSurfaceVariant,
                          ),
                        )
                      else
                        for (final pubkey in recipients)
                          _SelectedRecipientRow(
                            pubkey: pubkey,
                            onRemove: state.isBusy
                                ? null
                                : () => _removeRecipient(pubkey),
                          ),
                      if (state.actionStatus == BadgeDetailActionStatus.failure)
                        Text(
                          l10n.badgeDetailActionError,
                          style: VineTheme.bodySmallFont(
                            color: VineTheme.error,
                          ),
                        ),
                      DivineButton(
                        label: l10n.badgeAwardSubmitAction(recipients.length),
                        isLoading:
                            state.actionStatus ==
                            BadgeDetailActionStatus.awarding,
                        onPressed: recipients.isEmpty || state.isBusy
                            ? null
                            : () => context.read<BadgeDetailCubit>().award(
                                recipients,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectedRecipientRow extends StatelessWidget {
  const _SelectedRecipientRow({required this.pubkey, required this.onRemove});

  final String pubkey;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: UserProfileTile(
            pubkey: pubkey,
            showFollowButton: false,
            // The enclosing list already pads to the screen inset.
            padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
          ),
        ),
        DivineIconButton(
          icon: .x,
          semanticLabel: context.l10n.badgesActionRemove,
          size: .small,
          type: .secondary,
          onPressed: onRemove,
        ),
      ],
    );
  }
}
