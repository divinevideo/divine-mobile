// ABOUTME: Direct / Rooms navigation within the existing Messages tab.
// ABOUTME: Keeps list state mounted while hiding inactive input and semantics.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/messages/messages_navigation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// The two message surfaces share navigation, but retain independent state.
class MessagesHomeView extends StatelessWidget {
  const MessagesHomeView({
    required this.direct,
    required this.rooms,
    this.roomsUnreadCount = 0,
    this.roomsUnreadLimited = false,
    super.key,
  });

  final Widget direct;
  final Widget rooms;
  final int roomsUnreadCount;
  final bool roomsUnreadLimited;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<MessagesNavigationCubit, MessagesSection>(
    builder: (context, selected) {
      final showRooms = selected == MessagesSection.rooms;
      final unreadDisplay = '$roomsUnreadCount${roomsUnreadLimited ? '+' : ''}';
      final unreadBadge = roomsUnreadCount > 99 ? '99+' : unreadDisplay;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                children: [
                  Semantics(
                    selected: !showRooms,
                    child: DivineButton(
                      label: context.l10n.messagesDirect,
                      type: !showRooms
                          ? DivineButtonType.secondary
                          : DivineButtonType.ghostSecondary,
                      size: DivineButtonSize.small,
                      onPressed: () => _select(context, MessagesSection.direct),
                    ),
                  ),
                  Semantics(
                    selected: showRooms,
                    child: DivineButton(
                      label: roomsUnreadCount > 0
                          ? '${context.l10n.messagesRooms} ($unreadBadge)'
                          : context.l10n.messagesRooms,
                      semanticLabel: roomsUnreadCount > 0
                          ? context.l10n.messagesRoomsUnreadLabel(
                              roomsUnreadCount,
                              unreadDisplay,
                            )
                          : null,
                      type: showRooms
                          ? DivineButtonType.secondary
                          : DivineButtonType.ghostSecondary,
                      size: DivineButtonSize.small,
                      onPressed: () => _select(context, MessagesSection.rooms),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: showRooms ? 1 : 0,
              sizing: StackFit.expand,
              children: [
                _MessagesPane(active: !showRooms, child: direct),
                _MessagesPane(
                  active: showRooms,
                  child: rooms,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  void _select(BuildContext context, MessagesSection section) {
    FocusManager.instance.primaryFocus?.unfocus();
    runDetached(
      context.read<MessagesNavigationCubit>().select(section),
      'select Messages section',
      logName: 'MessagesHomeView',
      category: LogCategory.ui,
    );
  }
}

class _MessagesPane extends StatelessWidget {
  const _MessagesPane({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: active,
    child: ExcludeFocus(
      excluding: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: IgnorePointer(ignoring: !active, child: child),
      ),
    ),
  );
}
