import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/native_camera_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('openvine/native_camera');
  const service = MethodChannelNativeCameraPermissionService();
  final methodCalls = <MethodCall>[];

  setUp(methodCalls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps a granted native request correctly', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'requestPermission') {
            return true;
          }
          return null;
        });

    final result = await service.requestPermission();

    expect(result, NativeCameraPermissionStatus.granted);
    expect(methodCalls.single.method, 'requestPermission');
  });

  test('maps native authorization status values', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'getAuthorizationStatus') {
            return 'notDetermined';
          }
          return null;
        });

    final result = await service.authorizationStatus();

    expect(result, NativeCameraAuthorizationStatus.notDetermined);
    expect(methodCalls.single.method, 'getAuthorizationStatus');
  });

  test('maps native microphone authorization status values', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'getMicrophoneAuthorizationStatus') {
            return 'restricted';
          }
          return null;
        });

    final result = await service.microphoneAuthorizationStatus();

    expect(result, NativeCameraAuthorizationStatus.restricted);
    expect(methodCalls.single.method, 'getMicrophoneAuthorizationStatus');
  });

  test('maps a granted native microphone request correctly', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'requestMicrophonePermission') {
            return true;
          }
          return null;
        });

    final result = await service.requestMicrophonePermission();

    expect(result, NativeCameraPermissionStatus.granted);
    expect(methodCalls.single.method, 'requestMicrophonePermission');
  });

  test('maps native permission denied into requires settings', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'Camera access denied',
          );
        });

    final result = await service.requestPermission();

    expect(result, NativeCameraPermissionStatus.requiresSettings);
    expect(methodCalls.single.method, 'requestPermission');
  });

  test(
    'maps a false native camera request that stays not determined into prompt blocked',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            methodCalls.add(methodCall);
            if (methodCall.method == 'requestPermission') {
              return false;
            }
            if (methodCall.method == 'getAuthorizationStatus') {
              return 'notDetermined';
            }
            return null;
          });

      final result = await service.requestPermission();

      expect(result, NativeCameraPermissionStatus.promptBlocked);
      expect(
        methodCalls.map((call) => call.method),
        <String>['requestPermission', 'getAuthorizationStatus'],
      );
    },
  );

  test(
    'maps a false native microphone request that stays not determined into prompt blocked',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            methodCalls.add(methodCall);
            if (methodCall.method == 'requestMicrophonePermission') {
              return false;
            }
            if (methodCall.method == 'getMicrophoneAuthorizationStatus') {
              return 'notDetermined';
            }
            return null;
          });

      final result = await service.requestMicrophonePermission();

      expect(result, NativeCameraPermissionStatus.promptBlocked);
      expect(
        methodCalls.map((call) => call.method),
        <String>[
          'requestMicrophonePermission',
          'getMicrophoneAuthorizationStatus',
        ],
      );
    },
  );

  test('opens native camera system settings', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'openSystemSettings') {
            return true;
          }
          return null;
        });

    final opened = await service.openSystemSettings();

    expect(opened, isTrue);
    expect(methodCalls.single.method, 'openSystemSettings');
  });
}
