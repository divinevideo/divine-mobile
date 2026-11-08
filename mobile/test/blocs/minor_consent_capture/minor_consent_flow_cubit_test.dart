import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_flow_cubit.dart';

void main() {
  group('MinorConsentFlowCubit', () {
    MinorConsentFlowCubit create({
      Future<void> Function(String)? deleteClip,
      void Function()? refresh,
      void Function()? request,
    }) => MinorConsentFlowCubit(
      initializeCamera: () async {},
      releaseCamera: () async {},
      deleteClip: deleteClip ?? (_) async {},
      refreshPermissions: refresh ?? () {},
      requestPermissions: request ?? () {},
    );

    test(
      'retains accepted video until an upload finishes after close',
      () async {
        final deleted = <String>[];
        final cubit = create(deleteClip: (path) async => deleted.add(path));
        await cubit.accept('/private/clip.mp4');
        cubit.uploadStarted();
        await cubit.close();
        expect(deleted, isEmpty);
        cubit.uploadFinished();
        await Future<void>.value();
        expect(deleted, ['/private/clip.mp4']);
      },
    );

    test('leaving before submit discards the recorded clip', () async {
      final deleted = <String>[];
      final cubit = create(deleteClip: (path) async => deleted.add(path));
      cubit.recorded('/private/clip.mp4');
      await cubit.close();
      expect(deleted, ['/private/clip.mp4']);
    });

    test(
      'dismissed permission request refreshes then requests again',
      () async {
        var refreshes = 0;
        var requests = 0;
        final cubit = create(
          refresh: () => refreshes++,
          request: () => requests++,
        );
        cubit.permissionChanged(ConsentPermission.canRequest);
        expect(requests, 1);
        cubit.permissionChanged(ConsentPermission.loading);
        cubit.retryPermissions(canRequest: false);
        expect(refreshes, 1);
        cubit.permissionChanged(ConsentPermission.canRequest);
        expect(requests, 2);
        await cubit.close();
      },
    );
  });
}
