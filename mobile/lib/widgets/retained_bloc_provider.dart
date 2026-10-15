// ABOUTME: Replaces constructor dependencies while retaining same-owner view state.
// ABOUTME: The owner key defines the boundary; blocs validate inherited snapshots.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Use an owner [key] and immutable [dependencies] to separate account lifetime
/// from dependency lifetime. [create] must validate the inherited snapshot.
class RetainedBlocProvider<B extends StateStreamableSource<S>, S>
    extends StatefulWidget {
  const RetainedBlocProvider({
    required this.dependencies,
    required this.create,
    required this.child,
    super.key,
  });
  final Object dependencies;
  final B Function(S? snapshot) create;
  final Widget child;

  @override
  State<RetainedBlocProvider<B, S>> createState() =>
      _RetainedBlocProviderState<B, S>();
}

class _RetainedBlocProviderState<B extends StateStreamableSource<S>, S>
    extends State<RetainedBlocProvider<B, S>> {
  late B _bloc;
  @override
  void initState() {
    super.initState();
    _bloc = widget.create(null);
  }

  @override
  void didUpdateWidget(covariant RetainedBlocProvider<B, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dependencies == widget.dependencies) return;
    final previous = _bloc;
    _bloc = widget.create(previous.state);
    _close(previous);
  }

  void _close(B bloc) => runDetached(
    Future<void>.sync(bloc.close),
    'close replaced view state',
    logName: 'RetainedBlocProvider',
    category: LogCategory.ui,
  );

  @override
  void dispose() {
    _close(_bloc);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider<B>.value(value: _bloc, child: widget.child);
}
