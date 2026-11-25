// ABOUTME: Reverse lazy timeline with an optional exact-message scroll origin.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:openvine/notifications/routing/dm_message_visibility.dart';

/// Splits the existing lazy delegate at the requested row. Flutter lays out the
/// row at scroll offset zero and grows the two halves in opposite directions.
/// A taller preceding row or a newer insertion cannot invalidate that origin.
class ConversationFocusList extends StatefulWidget {
  const ConversationFocusList({
    required this.messageId,
    required this.itemCount,
    required this.findChildIndexCallback,
    required this.onUnavailable,
    required this.highlightColor,
    required this.itemBuilder,
    this.owner,
    this.conversation,
    super.key,
  });

  final String? messageId;
  final String? owner;
  final String? conversation;
  final int itemCount;
  final int? Function(Key) findChildIndexCallback;
  final VoidCallback onUnavailable;
  final Color highlightColor;
  final IndexedWidgetBuilder itemBuilder;

  @visibleForTesting
  static const ValueKey<String> highlightKey = ValueKey(
    'conversation-focus-highlight',
  );

  @override
  State<ConversationFocusList> createState() => _ConversationFocusListState();
}

class _ConversationFocusListState extends State<ConversationFocusList> {
  static const ValueKey<String> _center = ValueKey(
    'focused-conversation-sliver',
  );
  Timer? _timer;
  bool _settled = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    DmMessageVisibility.attach(_isVisible);
  }

  bool _isVisible(String owner, String conversation, String id) {
    if (!mounted ||
        widget.owner != owner ||
        widget.conversation != conversation ||
        ModalRoute.of(context)?.isCurrent != true ||
        !TickerMode.valuesOf(context).enabled) {
      return false;
    }
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return false;
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    var found = false;
    void visit(Element element) {
      if (found) return;
      if (element.widget.key == ValueKey(id)) {
        final box = element.renderObject;
        if (box is RenderBox &&
            box.attached &&
            box.hasSize &&
            !box.size.isEmpty) {
          found = bounds.overlaps(box.localToGlobal(Offset.zero) & box.size);
        }
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  void didUpdateWidget(ConversationFocusList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messageId != oldWidget.messageId) {
      _timer?.cancel();
      _timer = null;
      _settled = false;
      _unavailable = false;
    }
  }

  @override
  void dispose() {
    DmMessageVisibility.detach(_isVisible);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.messageId;
    final target = id == null
        ? null
        : widget.findChildIndexCallback(ValueKey(id));
    if (target == null || _unavailable) {
      if (id != null && !_unavailable) {
        _unavailable = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.messageId == id) widget.onUnavailable();
        });
      }
      return ListView.builder(
        reverse: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: widget.itemCount,
        findChildIndexCallback: widget.findChildIndexCallback,
        itemBuilder: widget.itemBuilder,
      );
    }

    _timer ??= Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _settled = true);
    });
    SliverList half({required bool newer}) => SliverList(
      key: newer ? null : _center,
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final index = newer ? target - 1 - i : target + i;
          final row = widget.itemBuilder(context, index);
          return Padding(
            key: row.key,
            padding: EdgeInsets.only(
              top: index == widget.itemCount - 1 ? 8 : 0,
              bottom: index == 0 ? 8 : 0,
            ),
            child: index == target
                ? Stack(
                    fit: StackFit.passthrough,
                    children: [
                      if (!_settled)
                        Positioned.fill(
                          child: ColoredBox(
                            key: ConversationFocusList.highlightKey,
                            color: widget.highlightColor,
                          ),
                        ),
                      row,
                    ],
                  )
                : row,
          );
        },
        childCount: newer ? target : widget.itemCount - target,
        findChildIndexCallback: (key) {
          final index = widget.findChildIndexCallback(key);
          if (index == null || (index < target) != newer) return null;
          return newer ? target - 1 - index : index - target;
        },
      ),
    );
    return CustomScrollView(
      key: ValueKey(id),
      center: _center,
      reverse: true,
      anchor: target == 0 ? 0 : 0.5,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [half(newer: true), half(newer: false)],
    );
  }
}
