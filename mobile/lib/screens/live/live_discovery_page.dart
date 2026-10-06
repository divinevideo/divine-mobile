import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/live_discovery/live_discovery_bloc.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/screens/live/live_discovery_view.dart';

class LiveDiscoveryPage extends ConsumerWidget {
  const LiveDiscoveryPage({
    super.key,
    this.embedded = false,
  });

  static const String routeName = 'liveDiscovery';
  static const String path = '/live';

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(liveRepositoryProvider);

    return BlocProvider(
      create: (_) =>
          LiveDiscoveryBloc(liveRepository: repository)
            ..add(const LiveDiscoveryRequested()),
      child: LiveDiscoveryView(embedded: embedded),
    );
  }
}
