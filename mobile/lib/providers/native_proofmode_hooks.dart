// ABOUTME: Points NativeProofModeService's static signing hooks at whichever
// ABOUTME: account container is live, so they keep working after a switch.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:path/path.dart' as p;

/// Assigns [NativeProofModeService]'s creator-binding, recording-hash and
/// late-proof hooks.
///
/// Each hook resolves [liveContainer] when it runs rather than capturing a
/// container now: the hooks are static and outlive the container the app
/// started with, which an in-place account switch disposes. The clip library
/// and creator binding they read therefore always belong to the signed-in
/// account.
void bindNativeProofModeHooks(ProviderContainer Function() liveContainer) {
  NativeProofModeService.creatorBindingFactory = (filePath) =>
      liveContainer().read(c2paCreatorBindingFactoryProvider).create(filePath);
  NativeProofModeService.recordingHashLookup = () => liveContainer()
      .read(clipLibraryServiceProvider)
      .recordingHashesByFileName();
  NativeProofModeService.lateProofRecorder = (path, proof) => liveContainer()
      .read(clipLibraryServiceProvider)
      .recordLateProof(fileName: p.basename(path), proof: proof);
}
