// ABOUTME: Keeps one presentation Cubit while account repositories change.
// ABOUTME: Starts history reconciliation without rebuilding the app navigator.
import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';
import 'package:openvine/providers/sound_requests_providers.dart';

class SoundRequestsScope extends ConsumerStatefulWidget {
  const SoundRequestsScope({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<SoundRequestsScope> createState() => _SoundRequestsScopeState();
}

class _SoundRequestsScopeState extends ConsumerState<SoundRequestsScope> {
  final _cubit = SoundRequestsCubit();
  @override
  void initState() {
    super.initState();
    ref.listenManual<SoundRequestsRepository?>(
      soundRequestsRepositoryProvider,
      (_, next) => unawaited(_cubit.connect(next)),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: widget.child);
}
