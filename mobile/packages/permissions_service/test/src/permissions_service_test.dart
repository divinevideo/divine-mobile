// Not required for test files where we want to test non-const constructors
// ignore_for_file: prefer_const_constructors

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:permissions_service/permissions_service.dart';

/// Mock implementation of [PermissionsService] for testing.
///
/// This demonstrates how consumers can mock the service in their tests.
class MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionStatus', () {
    test('has expected values', () {
      expect(PermissionStatus.values, hasLength(3));
      expect(PermissionStatus.granted, isNotNull);
      expect(PermissionStatus.canRequest, isNotNull);
      expect(PermissionStatus.requiresSettings, isNotNull);
    });
  });

  group('PermissionHandlerPermissionsService', () {
    late PermissionHandlerPermissionsService service;

    setUp(() {
      service = PermissionHandlerPermissionsService();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            null,
          );
    });

    test('can be instantiated', () {
      expect(PermissionHandlerPermissionsService(), isNotNull);
    });

    test('is a PermissionsService', () {
      expect(PermissionHandlerPermissionsService(), isA<PermissionsService>());
    });

    group('mapPermissionStatus', () {
      test('maps granted to PermissionStatus.granted', () {
        final result = service.mapPermissionStatus(ph.PermissionStatus.granted);
        expect(result, PermissionStatus.granted);
      });

      test('maps permanentlyDenied to PermissionStatus.requiresSettings', () {
        final result = service.mapPermissionStatus(
          ph.PermissionStatus.permanentlyDenied,
        );
        expect(result, PermissionStatus.requiresSettings);
      });

      test('maps restricted to PermissionStatus.requiresSettings', () {
        final result = service.mapPermissionStatus(
          ph.PermissionStatus.restricted,
        );
        expect(result, PermissionStatus.requiresSettings);
      });

      test('maps denied to PermissionStatus.canRequest', () {
        final result = service.mapPermissionStatus(ph.PermissionStatus.denied);
        expect(result, PermissionStatus.canRequest);
      });

      test('maps limited to PermissionStatus.granted', () {
        // limited is for iOS 14+ "Limited Photos Access" sufficient for saving
        final result = service.mapPermissionStatus(ph.PermissionStatus.limited);
        expect(result, PermissionStatus.granted);
      });

      test('maps provisional to PermissionStatus.canRequest', () {
        // provisional is for iOS provisional notifications
        final result = service.mapPermissionStatus(
          ph.PermissionStatus.provisional,
        );
        expect(result, PermissionStatus.canRequest);
      });
    });

    group('mapMacOSAuthorizationStatus', () {
      test('maps authorized to PermissionStatus.granted', () {
        expect(
          service.mapMacOSAuthorizationStatus('authorized'),
          PermissionStatus.granted,
        );
      });

      test('maps denied to PermissionStatus.requiresSettings', () {
        expect(
          service.mapMacOSAuthorizationStatus('denied'),
          PermissionStatus.requiresSettings,
        );
      });

      test('maps restricted to PermissionStatus.requiresSettings', () {
        expect(
          service.mapMacOSAuthorizationStatus('restricted'),
          PermissionStatus.requiresSettings,
        );
      });

      test('maps notDetermined to PermissionStatus.canRequest', () {
        expect(
          service.mapMacOSAuthorizationStatus('notDetermined'),
          PermissionStatus.canRequest,
        );
      });

      test('maps null/unknown to PermissionStatus.canRequest', () {
        expect(
          service.mapMacOSAuthorizationStatus(null),
          PermissionStatus.canRequest,
        );
        expect(
          service.mapMacOSAuthorizationStatus('unknown'),
          PermissionStatus.canRequest,
        );
      });
    });

    group('macOS native permissions', () {
      void mockNativeCamera(Future<Object?>? Function(MethodCall) handler) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('openvine/native_camera'),
              handler,
            );
      }

      test('checkCameraStatus routes through the native channel', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        mockNativeCamera((call) async {
          expect(call.method, 'cameraPermissionStatus');
          return 'denied';
        });

        expect(
          await service.checkCameraStatus(),
          PermissionStatus.requiresSettings,
        );
      });

      test(
        'requestCameraPermission routes through the native channel',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          mockNativeCamera((call) async {
            expect(call.method, 'requestCameraPermission');
            return 'authorized';
          });

          expect(
            await service.requestCameraPermission(),
            PermissionStatus.granted,
          );
        },
      );

      test('checkMicrophoneStatus routes through the native channel', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        mockNativeCamera((call) async {
          expect(call.method, 'microphonePermissionStatus');
          return 'restricted';
        });

        expect(
          await service.checkMicrophoneStatus(),
          PermissionStatus.requiresSettings,
        );
      });

      test(
        'requestMicrophonePermission routes through the native channel',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          mockNativeCamera((call) async {
            expect(call.method, 'requestMicrophonePermission');
            return 'authorized';
          });

          expect(
            await service.requestMicrophonePermission(),
            PermissionStatus.granted,
          );
        },
      );

      test('openAppSettings routes through the native channel', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        mockNativeCamera((call) async {
          expect(call.method, 'openSystemSettings');
          return true;
        });

        expect(await service.openAppSettings(), isTrue);
      });

      test('openAppSettings handles null native channel results', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        mockNativeCamera((call) async {
          expect(call.method, 'openSystemSettings');
          return null;
        });

        expect(await service.openAppSettings(), isFalse);
      });
    });
  });

  group('MockPermissionsService usage example', () {
    late MockPermissionsService mockService;

    setUp(() {
      mockService = MockPermissionsService();
    });

    test('can mock camera permission methods', () async {
      when(
        () => mockService.checkCameraStatus(),
      ).thenAnswer((_) async => PermissionStatus.canRequest);
      when(
        () => mockService.requestCameraPermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);

      expect(
        await mockService.checkCameraStatus(),
        PermissionStatus.canRequest,
      );
      expect(
        await mockService.requestCameraPermission(),
        PermissionStatus.granted,
      );

      verify(() => mockService.checkCameraStatus()).called(1);
      verify(() => mockService.requestCameraPermission()).called(1);
    });

    test('can mock microphone permission methods', () async {
      when(
        () => mockService.checkMicrophoneStatus(),
      ).thenAnswer((_) async => PermissionStatus.requiresSettings);
      when(
        () => mockService.requestMicrophonePermission(),
      ).thenAnswer((_) async => PermissionStatus.requiresSettings);

      expect(
        await mockService.checkMicrophoneStatus(),
        PermissionStatus.requiresSettings,
      );
      expect(
        await mockService.requestMicrophonePermission(),
        PermissionStatus.requiresSettings,
      );

      verify(() => mockService.checkMicrophoneStatus()).called(1);
      verify(() => mockService.requestMicrophonePermission()).called(1);
    });

    test('can mock openAppSettings', () async {
      when(() => mockService.openAppSettings()).thenAnswer((_) async => true);

      final result = await mockService.openAppSettings();

      expect(result, isTrue);
      verify(() => mockService.openAppSettings()).called(1);
    });

    test('can mock gallery permission methods', () async {
      when(
        () => mockService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.canRequest);
      when(
        () => mockService.requestGalleryPermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);

      expect(
        await mockService.checkGalleryStatus(),
        PermissionStatus.canRequest,
      );
      expect(
        await mockService.requestGalleryPermission(),
        PermissionStatus.granted,
      );

      verify(() => mockService.checkGalleryStatus()).called(1);
      verify(() => mockService.requestGalleryPermission()).called(1);
    });
  });
}
