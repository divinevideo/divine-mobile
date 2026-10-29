// ABOUTME: Full-screen mobile room conversation with Divine's shared composer.
// ABOUTME: Keeps channel context, sender identity, and delivery state readable.

import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/caption_mentions/caption_mentions_cubit.dart';
import 'package:openvine/blocs/chat/chat_composer_cubit.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_message_tile.dart';
import 'package:openvine/features/chat/public_room_notice.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mentions/mention_text_editing.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_input_bar.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/mentions/mention_overlay.dart';
import 'package:unified_logger/unified_logger.dart';

/// Native conversation for the Concord POC selected from Messages.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  static const String path = RoutePaths.chat;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _readScheduled = false;
  List<ChatMessage> _readSnapshot = const [];
  late final ChatComposerCubit _composer;
  late final CaptionMentionsCubit _mentions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_scheduleCurrentRead);
    final chat = context.read<ChatCubit>();
    _composer = ChatComposerCubit(
      send: (body) => chat.send(
        communityId: chat.state.selectedCommunityId,
        channelId: chat.state.selectedChannelId,
        author: '',
        body: body,
        nowMilliseconds: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _mentions = CaptionMentionsCubit(
      profileRepositoryOf: () => ref.read(profileRepositoryProvider),
      candidatePubkeys: () => {
        ...context.read<ChatCubit>().state.messages.map((m) => m.author),
        ...ref.read(followRepositoryProvider).followingPubkeys,
      },
    );
    _controller.addListener(_searchMentions);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleCurrentRead();
  }

  void _scheduleCurrentRead() {
    if (mounted) _scheduleRead(context.read<ChatCubit>().visibleMessages());
  }

  void _scheduleRead(List<ChatMessage> messages) {
    final cubit = context.read<ChatCubit>();
    _readSnapshot = List.unmodifiable(messages);
    if (_readScheduled || messages.isEmpty || cubit.onRead == null) return;
    _readScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readScheduled = false;
      if (!mounted ||
          !TickerMode.valuesOf(context).enabled ||
          ModalRoute.of(context)?.isCurrent == false ||
          cubit.state.threadRootId != null) {
        return;
      }
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      if (_scrollController.hasClients &&
          _scrollController.position.pixels > 1) {
        return;
      }
      // The reversed list starts at the newest message. Do not acknowledge
      // incoming messages while reading older history or another route.
      unawaited(cubit.markRead(_readSnapshot));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleCurrentRead();
  }

  void _searchMentions() {
    _composer.updateDraft(
      _controller.text,
      _controller.selection.baseOffset,
      selectionExtent: _controller.selection.extentOffset,
    );
    runDetached(
      _mentions.search(
        activeMentionQuery(_controller.text, _controller.selection.baseOffset),
      ),
      'search room mentions',
      logName: 'ChatScreen',
      category: LogCategory.ui,
    );
  }

  void _selectMention(String pubkey, String display) {
    final insertion = _composer.selectMention(
      cursor: _controller.selection.baseOffset,
      pubkey: pubkey,
      display: display,
    );
    if (insertion == null) return;
    _controller.value = TextEditingValue(
      text: insertion.text,
      selection: TextSelection.collapsed(offset: insertion.selection),
    );
    _mentions.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _controller.removeListener(_searchMentions);
    unawaited(_mentions.close());
    unawaited(_composer.close());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final clear = await _composer.submit();
    if (mounted && clear) _controller.clear();
  }

  void _submit(String text) {
    final state = context.read<ChatCubit>().state;
    if (state.sending || state.loading || state.loadFailed) return;
    runDetached(
      _send(),
      'send room message',
      logName: 'ChatScreen',
      category: LogCategory.ui,
    );
  }

  KeyEventResult _handleComposerKey(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if ((event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
        keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        !_controller.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    // Only a fresh press sends; holding Enter must not republish a draft.
    if (event is KeyDownEvent) _submit(_controller.text);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ChatCubit, ChatState>(
    builder: (context, state) {
      final cubit = context.read<ChatCubit>();
      final messages = cubit.visibleMessages();
      _scheduleRead(messages);
      final community = state.communities
          .where((entry) => entry.id == state.selectedCommunityId)
          .firstOrNull;
      return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          toolbarHeight:
              MediaQuery.textScalerOf(context).scale(24) +
              MediaQuery.textScalerOf(context).scale(16) +
              16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${state.selectedChannelId}',
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              if (community != null)
                Text(
                  community.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
            ],
          ),
          leading: state.threadRootId == null
              ? null
              : DivineIconButton(
                  icon: DivineIconName.arrowLeft,
                  semanticLabel: context.l10n.commonBack,
                  onPressed: cubit.closeThread,
                ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                const PublicRoomNotice(),
                if (state.loading) const DivineLinearProgressIndicator(),
                if (state.loadFailed) ...[
                  Text(context.l10n.dmConversationLoadError),
                  DivineButton(
                    onPressed: state.loading ? null : cubit.start,
                    label: context.l10n.commonRetry,
                    type: DivineButtonType.link,
                  ),
                ],
                BlocBuilder<ChatComposerCubit, ChatComposerState>(
                  bloc: _composer,
                  builder: (context, composer) =>
                      state.sendFailed || composer.sendFailed
                      ? Text(context.l10n.dmSendFailedMessage)
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (messages.isEmpty)
                        _EmptyRoom(channel: state.selectedChannelId)
                      else
                        ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                messages[messages.length - index - 1];
                            return ChatMessageTile(
                              key: ValueKey(message.id),
                              message: message,
                              reactions:
                                  state.reactions[message.id] ?? const {},
                              pending: state.pendingIds.contains(
                                message.id,
                              ),
                              sending: state.sending,
                              onRetry: () => runDetached(
                                cubit.retry(message.id),
                                'retry room message',
                                logName: 'ChatScreen',
                                category: LogCategory.ui,
                              ),
                            );
                          },
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child:
                            BlocBuilder<
                              CaptionMentionsCubit,
                              CaptionMentionsState
                            >(
                              bloc: _mentions,
                              builder: (context, mentions) => MentionOverlay(
                                suggestions: mentions.suggestions,
                                onSelect: _selectMention,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                Focus(
                  canRequestFocus: false,
                  onKeyEvent: _handleComposerKey,
                  child: MessageInputBar(
                    controller: _controller,
                    clearOnSend: false,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !state.loading && !state.loadFailed,
                    onSend: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({required this.channel});
  final String channel;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DivineIcon(
            icon: DivineIconName.chatCircle,
            size: 40,
            color: context.vineColors.onSurfaceMuted,
          ),
          const SizedBox(height: 16),
          Text(
            '#$channel',
            style: VineTheme.titleLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.inboxEmptyTitle,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    ),
  );
}
