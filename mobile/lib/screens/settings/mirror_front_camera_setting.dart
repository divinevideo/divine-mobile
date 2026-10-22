// ABOUTME: Settings toggle that saves front camera recordings mirrored
// ABOUTME: Keeps selfie clips looking the way the preview showed them

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/front_camera_mirror/front_camera_mirror_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/preferences_providers.dart';

/// Opt-in mirrored recording for the front camera.
///
/// Offered on Android and iOS only: a Mac reports its second user-facing
/// camera as the back lens, which the camera does not mirror.
class MirrorFrontCameraSetting extends ConsumerWidget {
  const MirrorFrontCameraSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(frontCameraMirrorPreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => FrontCameraMirrorCubit(service: service)..load(),
      child: const _MirrorFrontCameraTile(),
    );
  }
}

class _MirrorFrontCameraTile extends StatelessWidget {
  const _MirrorFrontCameraTile();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (FrontCameraMirrorCubit cubit) => cubit.state.isEnabled,
    );
    return DivineSwitchTile(
      leadingIcon: DivineIconName.flipHorizontal,
      title: context.l10n.settingsMirrorFrontCamera,
      subtitle: context.l10n.settingsMirrorFrontCameraSubtitle,
      value: isEnabled,
      onChanged: (value) =>
          context.read<FrontCameraMirrorCubit>().setEnabled(value),
    );
  }
}
