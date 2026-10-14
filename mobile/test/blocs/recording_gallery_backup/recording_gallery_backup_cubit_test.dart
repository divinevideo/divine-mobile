// ABOUTME: Unit tests for RecordingGalleryBackupCubit — the backup toggle.
// ABOUTME: Covers asking for gallery access before the setting turns on.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/recording_gallery_backup/recording_gallery_backup_cubit.dart';
import 'package:openvine/blocs/recording_gallery_backup/recording_gallery_backup_state.dart';
import 'package:openvine/services/recording_gallery_backup_preference_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  group(RecordingGalleryBackupCubit, () {
    late RecordingGalleryBackupPreferenceService preferences;
    late _MockPermissionsService permissions;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = RecordingGalleryBackupPreferenceService(
        await SharedPreferences.getInstance(),
      );
      permissions = _MockPermissionsService();
      when(
        permissions.checkGalleryStatus,
      ).thenAnswer((_) async => PermissionStatus.granted);
    });

    RecordingGalleryBackupCubit buildCubit() => RecordingGalleryBackupCubit(
      preferences: preferences,
      permissionsService: permissions,
    );

    group('load', () {
      blocTest<RecordingGalleryBackupCubit, RecordingGalleryBackupState>(
        'reads the stored setting',
        setUp: () => preferences.setEnabled(true),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [const RecordingGalleryBackupState(isEnabled: true)],
      );
    });

    group('setEnabled', () {
      blocTest<RecordingGalleryBackupCubit, RecordingGalleryBackupState>(
        'turns on when gallery access is granted',
        build: buildCubit,
        act: (cubit) => cubit.setEnabled(true),
        expect: () => [const RecordingGalleryBackupState(isEnabled: true)],
        verify: (_) => expect(preferences.isEnabled, isTrue),
      );

      blocTest<RecordingGalleryBackupCubit, RecordingGalleryBackupState>(
        'asks for gallery access before turning on',
        setUp: () {
          when(
            permissions.checkGalleryStatus,
          ).thenAnswer((_) async => PermissionStatus.canRequest);
          when(
            permissions.requestGalleryPermission,
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: buildCubit,
        act: (cubit) => cubit.setEnabled(true),
        expect: () => [const RecordingGalleryBackupState(isEnabled: true)],
        verify: (_) {
          verify(permissions.requestGalleryPermission).called(1);
          expect(preferences.isEnabled, isTrue);
        },
      );

      blocTest<RecordingGalleryBackupCubit, RecordingGalleryBackupState>(
        'stays off and reports it when gallery access is denied',
        setUp: () {
          when(
            permissions.checkGalleryStatus,
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        },
        build: buildCubit,
        act: (cubit) => cubit.setEnabled(true),
        expect: () => [
          const RecordingGalleryBackupState(permissionDenied: true),
        ],
        verify: (_) {
          verifyNever(permissions.requestGalleryPermission);
          expect(preferences.isEnabled, isFalse);
        },
      );

      blocTest<RecordingGalleryBackupCubit, RecordingGalleryBackupState>(
        'turns off without asking for anything',
        setUp: () => preferences.setEnabled(true),
        build: buildCubit,
        seed: () => const RecordingGalleryBackupState(isEnabled: true),
        act: (cubit) => cubit.setEnabled(false),
        expect: () => [const RecordingGalleryBackupState()],
        verify: (_) {
          verifyNever(permissions.checkGalleryStatus);
          expect(preferences.isEnabled, isFalse);
        },
      );
    });
  });
}
