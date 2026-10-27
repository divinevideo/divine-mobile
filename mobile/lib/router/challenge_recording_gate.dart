import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';

/// Opens the existing recorder only after its durable owner-scoped context has
/// been restored. No challenge discovery or new recording screen is exposed.
class ChallengeRecordingGate extends StatefulWidget {
  const ChallengeRecordingGate({
    required this.prepare,
    required this.child,
    super.key,
  });
  final Future<void> Function() prepare;
  final Widget child;
  @override
  State<ChallengeRecordingGate> createState() => _ChallengeRecordingGateState();
}

class _ChallengeRecordingGateState extends State<ChallengeRecordingGate> {
  late final Future<void> _ready;
  @override
  void initState() {
    super.initState();
    _ready = Future.microtask(widget.prepare);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return RouteErrorScreen(message: context.l10n.commonSomethingWentWrong);
      }
      return snapshot.connectionState == ConnectionState.done
          ? widget.child
          : const SizedBox.expand();
    },
  );
}
