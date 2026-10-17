// ABOUTME: Typed handoff from a fulfilled sound request into video creation.
// ABOUTME: Applies audio before recorder widgets read their initial sound.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';

class RecorderSoundSelection {
  const RecorderSoundSelection({
    required this.sound,
    required this.ownerPubkey,
  });
  final AudioEvent sound;
  final String ownerPubkey;
}

class RecorderSoundSelectionGate extends StatefulWidget {
  const RecorderSoundSelectionGate({
    required this.selection,
    required this.apply,
    required this.child,
    super.key,
  });
  final RecorderSoundSelection selection;
  final FutureOr<void> Function(RecorderSoundSelection) apply;
  final Widget child;
  @override
  State<RecorderSoundSelectionGate> createState() =>
      _RecorderSoundSelectionGateState();
}

class _RecorderSoundSelectionGateState
    extends State<RecorderSoundSelectionGate> {
  late Future<void> _handoff;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant RecorderSoundSelectionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) _prepare();
  }

  void _prepare() {
    final selection = widget.selection;
    _handoff = Future.microtask(() async {
      if (mounted && identical(selection, widget.selection)) {
        await widget.apply(selection);
      }
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _handoff,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text(context.l10n.soundReuseUnavailable));
      }
      return snapshot.connectionState == ConnectionState.done
          ? widget.child
          : const SizedBox.expand();
    },
  );
}
