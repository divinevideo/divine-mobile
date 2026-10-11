import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/live/widgets/live_chat_message_tile.dart';

class LiveChatPanel extends StatefulWidget {
  const LiveChatPanel({
    super.key,
  });

  @override
  State<LiveChatPanel> createState() => _LiveChatPanelState();
}

class _LiveChatPanelState extends State<LiveChatPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
        builder: (context, roomState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.liveChat,
                style: VineTheme.titleLargeFont(
                  color: context.vineColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<LiveChatBloc, LiveChatState>(
                  builder: (context, state) {
                    if (state.status == LiveChatStatus.loading) {
                      return const Center(
                        child: DivineCircularProgressIndicator(
                          color: VineTheme.primary,
                        ),
                      );
                    }

                    if (state.error != null) {
                      return Center(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            state.error == LiveChatError.sendFailed
                                ? context.l10n.liveSendFailed
                                : context.l10n.liveChatLoadFailed,
                          ),
                        ),
                      );
                    }

                    final activeSessionAddress = state.sessionAddress;
                    final visibleMessages = state.messages
                        .where((message) {
                          return message.sessionAddress ==
                                  activeSessionAddress &&
                              !roomState.hiddenChatParticipantPubkeys.contains(
                                message.pubkey,
                              ) &&
                              !roomState.hiddenParticipantPubkeys.contains(
                                message.pubkey,
                              );
                        })
                        .toList(growable: false);

                    if (visibleMessages.isEmpty) {
                      return Center(
                        child: Text(
                          state.messages
                                  .where(
                                    (message) =>
                                        message.sessionAddress ==
                                        activeSessionAddress,
                                  )
                                  .isEmpty
                              ? context.l10n.liveNoMessagesYetBreakTheSilence
                              : context.l10n.liveHiddenChatNotice,
                          style: VineTheme.bodyMediumFont(
                            color: context.vineColors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: visibleMessages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final message = visibleMessages[index];
                        return LiveChatMessageTile(
                          message: message,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: context.l10n.liveSaySomething,
                        hintStyle: VineTheme.bodyMediumFont(
                          color: context.vineColors.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: context.vineColors.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BlocBuilder<LiveChatBloc, LiveChatState>(
                    builder: (context, state) {
                      return DivineButton(
                        label: context.l10n.liveSend,
                        onPressed: state.isSending
                            ? null
                            : () {
                                context.read<LiveChatBloc>().add(
                                  LiveChatMessageSendRequested(
                                    _controller.text,
                                  ),
                                );
                                _controller.clear();
                              },
                        isLoading: state.isSending,
                        size: DivineButtonSize.small,
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
