// ABOUTME: Tests bindNativeProofModeHooks routes the signing hooks through the
// ABOUTME: live account container, so they survive an account switch.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/native_proofmode_hooks.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/c2pa_creator_binding_factory.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';

class _FakeClipLibraryService extends Fake implements ClipLibraryService {
  _FakeClipLibraryService(this.hashes);

  final Map<String, Set<String>> hashes;
  final List<String> lateProofs = [];

  @override
  Future<Map<String, Set<String>>> recordingHashesByFileName() async => hashes;

  @override
  Future<int> recordLateProof({
    required String fileName,
    required NativeProofData proof,
  }) async {
    lateProofs.add(fileName);
    return 1;
  }
}

class _FakeCreatorBindingFactory extends Fake
    implements C2paCreatorBindingFactory {
  final List<String> calls = [];

  @override
  Future<NostrCreatorBindingAssertion?> create(String filePath) async {
    calls.add(filePath);
    return null;
  }
}

void main() {
  late _FakeClipLibraryService libraryA;
  late _FakeClipLibraryService libraryB;
  late _FakeCreatorBindingFactory bindingA;
  late _FakeCreatorBindingFactory bindingB;
  late ProviderContainer containerA;
  late ProviderContainer containerB;
  late ProviderContainer live;

  ProviderContainer containerWith(
    _FakeClipLibraryService library,
    _FakeCreatorBindingFactory binding,
  ) => ProviderContainer(
    overrides: [
      clipLibraryServiceProvider.overrideWithValue(library),
      c2paCreatorBindingFactoryProvider.overrideWithValue(binding),
    ],
  );

  setUp(() {
    libraryA = _FakeClipLibraryService({
      'a.mp4': {'aaa'},
    });
    libraryB = _FakeClipLibraryService({
      'b.mp4': {'bbb'},
    });
    bindingA = _FakeCreatorBindingFactory();
    bindingB = _FakeCreatorBindingFactory();
    containerA = containerWith(libraryA, bindingA);
    containerB = containerWith(libraryB, bindingB);
    live = containerA;
    bindNativeProofModeHooks(() => live);
  });

  tearDown(() {
    NativeProofModeService.creatorBindingFactory = null;
    NativeProofModeService.recordingHashLookup = null;
    NativeProofModeService.lateProofRecorder = null;
    containerB.dispose();
  });

  /// Stands in for a committed account switch: the new container goes live
  /// and the one the hooks were first used with is disposed.
  void switchToB() {
    live = containerB;
    containerA.dispose();
  }

  group('bindNativeProofModeHooks', () {
    test(
      "recordingHashLookup reads the live container's clip library",
      () async {
        expect(await NativeProofModeService.recordingHashLookup!(), {
          'a.mp4': {'aaa'},
        });
        containerA.dispose();
      },
    );

    test(
      'hooks follow the live container after the old one is disposed',
      () async {
        switchToB();

        expect(await NativeProofModeService.recordingHashLookup!(), {
          'b.mp4': {'bbb'},
        });
      },
    );

    test(
      "lateProofRecorder records on the live container's clip library",
      () async {
        switchToB();

        await NativeProofModeService.lateProofRecorder!(
          '/documents/clips/x.mp4',
          const NativeProofData(videoHash: 'proof-hash'),
        );

        expect(libraryB.lateProofs, equals(['x.mp4']));
        expect(libraryA.lateProofs, isEmpty);
      },
    );

    test('creatorBindingFactory delegates to the live container', () async {
      switchToB();

      await NativeProofModeService.creatorBindingFactory!('/documents/f.mp4');

      expect(bindingB.calls, equals(['/documents/f.mp4']));
      expect(bindingA.calls, isEmpty);
    });
  });
}
