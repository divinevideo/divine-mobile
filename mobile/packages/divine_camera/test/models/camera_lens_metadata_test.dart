import 'dart:convert';

import 'package:divine_camera/src/models/camera_lens_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CameraLensMetadata, () {
    const metadata = CameraLensMetadata(
      lensType: 'back',
      cameraId: '0',
      focalLength: 4.25,
      focalLengthEquivalent35mm: 26,
      aperture: 1.8,
      sensorWidth: 5.6,
      sensorHeight: 4.2,
      pixelArrayWidth: 4032,
      pixelArrayHeight: 3024,
      minFocusDistance: 10,
      fieldOfView: 78,
      hasOpticalStabilization: true,
      isLogicalCamera: true,
      physicalCameraIds: ['0', '2'],
      exposureDuration: 0.033,
      exposureTimeMin: 0.00001,
      exposureTimeMax: 0.25,
      iso: 100,
      isoMin: 50,
      isoMax: 3200,
    );

    group('fromMap', () {
      test('keeps finite readings', () {
        final parsed = CameraLensMetadata.fromMap(const {
          'lensType': 'back',
          'exposureDuration': 0.033,
          'iso': 100,
        });

        expect(parsed.exposureDuration, equals(0.033));
        expect(parsed.iso, equals(100.0));
      });

      test('reads a reading that is not a finite number as unknown', () {
        final parsed = CameraLensMetadata.fromMap(const {
          'lensType': 'back',
          'focalLength': double.nan,
          'focalLengthEquivalent35mm': double.infinity,
          'aperture': double.nan,
          'sensorWidth': double.nan,
          'sensorHeight': double.negativeInfinity,
          'minFocusDistance': double.nan,
          'fieldOfView': double.nan,
          'exposureDuration': double.nan,
          'exposureTimeMin': double.nan,
          'exposureTimeMax': double.infinity,
          'iso': double.nan,
        });

        expect(parsed, equals(const CameraLensMetadata(lensType: 'back')));
      });

      test('a NaN exposure reading still encodes to JSON', () {
        // iOS reports CMTimeGetSeconds of an invalid exposure time as NaN;
        // clips persist this map, and json.encode throws on NaN.
        final parsed = CameraLensMetadata.fromMap(const {
          'lensType': 'back',
          'exposureDuration': double.nan,
        });

        expect(() => jsonEncode(parsed.toMap()), returnsNormally);
      });
    });

    group('equality', () {
      test(
        'two instances with same values including exposure '
        'fields are equal',
        () {
          const other = CameraLensMetadata(
            lensType: 'back',
            cameraId: '0',
            focalLength: 4.25,
            focalLengthEquivalent35mm: 26,
            aperture: 1.8,
            sensorWidth: 5.6,
            sensorHeight: 4.2,
            pixelArrayWidth: 4032,
            pixelArrayHeight: 3024,
            minFocusDistance: 10,
            fieldOfView: 78,
            hasOpticalStabilization: true,
            isLogicalCamera: true,
            physicalCameraIds: ['0', '2'],
            exposureDuration: 0.033,
            exposureTimeMin: 0.00001,
            exposureTimeMax: 0.25,
            iso: 100,
            isoMin: 50,
            isoMax: 3200,
          );

          expect(metadata, equals(other));
        },
      );

      test('different exposureDuration produces inequality', () {
        final other = metadata.copyWith(exposureDuration: 0.016);

        expect(metadata, isNot(equals(other)));
      });

      test('different exposureTimeMin produces inequality', () {
        final other = metadata.copyWith(exposureTimeMin: 0.001);

        expect(metadata, isNot(equals(other)));
      });

      test('different exposureTimeMax produces inequality', () {
        final other = metadata.copyWith(exposureTimeMax: 1);

        expect(metadata, isNot(equals(other)));
      });

      test('different iso produces inequality', () {
        final other = metadata.copyWith(iso: 200);

        expect(metadata, isNot(equals(other)));
      });

      test('different isoMin produces inequality', () {
        final other = metadata.copyWith(isoMin: 25);

        expect(metadata, isNot(equals(other)));
      });

      test('different isoMax produces inequality', () {
        final other = metadata.copyWith(isoMax: 6400);

        expect(metadata, isNot(equals(other)));
      });
    });

    group('copyWith', () {
      test('returns identical instance when no arguments provided', () {
        final copy = metadata.copyWith();

        expect(copy, equals(metadata));
      });

      test('replaces lensType', () {
        final copy = metadata.copyWith(lensType: 'front');

        expect(copy.lensType, equals('front'));
      });

      test('replaces cameraId', () {
        final copy = metadata.copyWith(cameraId: '1');

        expect(copy.cameraId, equals('1'));
      });

      test('replaces focalLength', () {
        final copy = metadata.copyWith(focalLength: 6);

        expect(copy.focalLength, equals(6.0));
      });

      test('replaces focalLengthEquivalent35mm', () {
        final copy = metadata.copyWith(focalLengthEquivalent35mm: 52);

        expect(copy.focalLengthEquivalent35mm, equals(52.0));
      });

      test('replaces aperture', () {
        final copy = metadata.copyWith(aperture: 2.8);

        expect(copy.aperture, equals(2.8));
      });

      test('replaces sensorWidth', () {
        final copy = metadata.copyWith(sensorWidth: 7);

        expect(copy.sensorWidth, equals(7.0));
      });

      test('replaces sensorHeight', () {
        final copy = metadata.copyWith(sensorHeight: 5);

        expect(copy.sensorHeight, equals(5.0));
      });

      test('replaces pixelArrayWidth', () {
        final copy = metadata.copyWith(pixelArrayWidth: 8064);

        expect(copy.pixelArrayWidth, equals(8064));
      });

      test('replaces pixelArrayHeight', () {
        final copy = metadata.copyWith(pixelArrayHeight: 6048);

        expect(copy.pixelArrayHeight, equals(6048));
      });

      test('replaces minFocusDistance', () {
        final copy = metadata.copyWith(minFocusDistance: 25);

        expect(copy.minFocusDistance, equals(25.0));
      });

      test('replaces fieldOfView', () {
        final copy = metadata.copyWith(fieldOfView: 120);

        expect(copy.fieldOfView, equals(120.0));
      });

      test('replaces hasOpticalStabilization', () {
        final copy = metadata.copyWith(hasOpticalStabilization: false);

        expect(copy.hasOpticalStabilization, isFalse);
      });

      test('replaces isLogicalCamera', () {
        final copy = metadata.copyWith(isLogicalCamera: false);

        expect(copy.isLogicalCamera, isFalse);
      });

      test('replaces physicalCameraIds', () {
        final copy = metadata.copyWith(physicalCameraIds: ['3']);

        expect(copy.physicalCameraIds, equals(['3']));
      });

      test('replaces exposureDuration', () {
        final copy = metadata.copyWith(exposureDuration: 0.016);

        expect(copy.exposureDuration, equals(0.016));
      });

      test('replaces exposureTimeMin', () {
        final copy = metadata.copyWith(exposureTimeMin: 0.001);

        expect(copy.exposureTimeMin, equals(0.001));
      });

      test('replaces exposureTimeMax', () {
        final copy = metadata.copyWith(exposureTimeMax: 1);

        expect(copy.exposureTimeMax, equals(1.0));
      });

      test('replaces iso', () {
        final copy = metadata.copyWith(iso: 200);

        expect(copy.iso, equals(200.0));
      });

      test('replaces isoMin', () {
        final copy = metadata.copyWith(isoMin: 25);

        expect(copy.isoMin, equals(25));
      });

      test('replaces isoMax', () {
        final copy = metadata.copyWith(isoMax: 6400);

        expect(copy.isoMax, equals(6400));
      });

      test('preserves unmodified fields', () {
        final copy = metadata.copyWith(lensType: 'front');

        expect(copy.cameraId, equals(metadata.cameraId));
        expect(copy.focalLength, equals(metadata.focalLength));
        expect(copy.aperture, equals(metadata.aperture));
        expect(copy.exposureDuration, equals(metadata.exposureDuration));
        expect(copy.iso, equals(metadata.iso));
        expect(copy.isoMin, equals(metadata.isoMin));
        expect(copy.isoMax, equals(metadata.isoMax));
      });
    });
  });
}
