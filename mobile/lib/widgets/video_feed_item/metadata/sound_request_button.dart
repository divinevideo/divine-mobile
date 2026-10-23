// ABOUTME: Requests an original sound through the current account's DM flow.
// ABOUTME: Fresh eligibility and duplicate handling come from the feature Cubit.
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:unified_logger/unified_logger.dart';

class SoundRequestButton extends StatefulWidget {
  const SoundRequestButton({required this.videoAddress, super.key});
  final String videoAddress;
  @override
  State<SoundRequestButton> createState() => _SoundRequestButtonState();
}

class _SoundRequestButtonState extends State<SoundRequestButton> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant SoundRequestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoAddress != widget.videoAddress) _check();
  }

  void _check() => runDetached(
    context.read<SoundRequestsCubit>().checkEligibility(widget.videoAddress),
    'check sound request eligibility',
    logName: 'SoundRequestButton',
    category: LogCategory.ui,
  );
  Future<void> _request() async {
    final cubit = context.read<SoundRequestsCubit>();
    final owner = cubit.state.ownerPubkey;
    final creator = soundRequestCreator(widget.videoAddress);
    if (creator == null) return;
    final existing = cubit.state.snapshot.requests.values.any(
      (r) =>
          r.videoAddress == widget.videoAddress &&
          r.requester == owner &&
          r.isPending,
    );
    if (!existing) {
      await cubit.request(widget.videoAddress);
      if (!mounted || cubit.state.ownerPubkey != owner) return;
      if (!cubit.state.snapshot.requests.values.any(
        (r) =>
            r.videoAddress == widget.videoAddress &&
            r.requester == owner &&
            r.isPending,
      )) {
        return;
      }
    }
    if (!mounted) return;
    final host = Navigator.of(context, rootNavigator: true).context;
    if (ModalRoute.of(context) is PopupRoute) Navigator.of(context).pop();
    if (!host.mounted) return;
    await host.pushWithVideoPause(
      ConversationRouteData(
        id: DmRepository.computeConversationId([owner, creator]),
      ).location,
      extra: DmRouteExtra(participantPubkeys: [owner, creator]),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SoundRequestsCubit, SoundRequestsState>(
        builder: (context, state) {
          if (state.ownerPubkey.isEmpty ||
              soundRequestCreator(widget.videoAddress) == state.ownerPubkey) {
            return const SizedBox.shrink();
          }
          final eligibility = state.eligibility[widget.videoAddress];
          if (eligibility == null ||
              eligibility == SoundRequestEligibility.checking) {
            return const SizedBox.shrink();
          }
          if (eligibility == SoundRequestEligibility.unavailable) {
            return const SizedBox.shrink();
          }
          final hasRequest = state.snapshot.requests.values.any(
            (r) =>
                r.videoAddress == widget.videoAddress &&
                r.requester == state.ownerPubkey &&
                r.isPending,
          );
          final working =
              state.target == widget.videoAddress &&
              state.operation == SoundRequestOperation.working;
          final failed =
              eligibility == SoundRequestEligibility.failed ||
              (state.target == widget.videoAddress &&
                  state.operation == SoundRequestOperation.failed);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failed) Text(context.l10n.soundReuseUnavailable),
              DivineButton(
                label: hasRequest
                    ? context.l10n.soundRequestSent
                    : eligibility == SoundRequestEligibility.failed
                    ? context.l10n.commonRetry
                    : context.l10n.soundRequestAction,
                size: DivineButtonSize.small,
                type: DivineButtonType.secondary,
                isLoading: working,
                onPressed: working
                    ? null
                    : () => runDetached(
                        eligibility == SoundRequestEligibility.failed
                            ? context
                                  .read<SoundRequestsCubit>()
                                  .checkEligibility(
                                    widget.videoAddress,
                                    refresh: true,
                                  )
                            : _request(),
                        'request original sound',
                        logName: 'SoundRequestButton',
                        category: LogCategory.ui,
                      ),
              ),
            ],
          );
        },
      );
}
