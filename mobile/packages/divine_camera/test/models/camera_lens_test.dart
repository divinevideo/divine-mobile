import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DivineCameraLens, () {
    group('toNativeString', () {
      test('converts front to correct string', () {
        expect(DivineCameraLens.front.toNativeString(), equals('front'));
      });

      test('converts back to correct string', () {
        expect(DivineCameraLens.back.toNativeString(), equals('back'));
      });

      test('converts ultraWide to correct string', () {
        expect(
          DivineCameraLens.ultraWide.toNativeString(),
          equals('ultraWide'),
        );
      });

      test('converts telephoto to correct string', () {
        expect(
          DivineCameraLens.telephoto.toNativeString(),
          equals('telephoto'),
        );
      });

      test('converts macro to correct string', () {
        expect(DivineCameraLens.macro.toNativeString(), equals('macro'));
      });

      test('converts frontUltraWide to correct string', () {
        expect(
          DivineCameraLens.frontUltraWide.toNativeString(),
          equals('frontUltraWide'),
        );
      });
    });

    group('fromNativeString', () {
      test('parses front correctly', () {
        expect(
          DivineCameraLens.fromNativeString('front'),
          equals(DivineCameraLens.front),
        );
      });

      test('parses back correctly', () {
        expect(
          DivineCameraLens.fromNativeString('back'),
          equals(DivineCameraLens.back),
        );
      });

      test('parses ultraWide correctly', () {
        expect(
          DivineCameraLens.fromNativeString('ultraWide'),
          equals(DivineCameraLens.ultraWide),
        );
      });

      test('parses telephoto correctly', () {
        expect(
          DivineCameraLens.fromNativeString('telephoto'),
          equals(DivineCameraLens.telephoto),
        );
      });

      test('parses macro correctly', () {
        expect(
          DivineCameraLens.fromNativeString('macro'),
          equals(DivineCameraLens.macro),
        );
      });

      test('parses frontUltraWide correctly', () {
        expect(
          DivineCameraLens.fromNativeString('frontUltraWide'),
          equals(DivineCameraLens.frontUltraWide),
        );
      });

      test('returns back for unknown values', () {
        expect(
          DivineCameraLens.fromNativeString('unknown'),
          equals(DivineCameraLens.back),
        );
      });
    });

    group('fromNativeStringList', () {
      test('parses list of lens types correctly', () {
        final result = DivineCameraLens.fromNativeStringList([
          'front',
          'back',
          'ultraWide',
          'telephoto',
          'macro',
        ]);

        expect(result, hasLength(5));
        expect(result[0], equals(DivineCameraLens.front));
        expect(result[1], equals(DivineCameraLens.back));
        expect(result[2], equals(DivineCameraLens.ultraWide));
        expect(result[3], equals(DivineCameraLens.telephoto));
        expect(result[4], equals(DivineCameraLens.macro));
      });

      test('filters out non-string values', () {
        final result = DivineCameraLens.fromNativeStringList([
          'front',
          123,
          'back',
          null,
          'ultraWide',
        ]);

        expect(result, hasLength(3));
        expect(result[0], equals(DivineCameraLens.front));
        expect(result[1], equals(DivineCameraLens.back));
        expect(result[2], equals(DivineCameraLens.ultraWide));
      });

      test('handles empty list', () {
        final result = DivineCameraLens.fromNativeStringList([]);

        expect(result, isEmpty);
      });
    });

    group('opposite', () {
      test('front returns back', () {
        expect(DivineCameraLens.front.opposite, equals(DivineCameraLens.back));
      });

      test('back returns front', () {
        expect(DivineCameraLens.back.opposite, equals(DivineCameraLens.front));
      });

      test('ultraWide returns front', () {
        expect(
          DivineCameraLens.ultraWide.opposite,
          equals(DivineCameraLens.front),
        );
      });

      test('telephoto returns front', () {
        expect(
          DivineCameraLens.telephoto.opposite,
          equals(DivineCameraLens.front),
        );
      });

      test('macro returns front', () {
        expect(DivineCameraLens.macro.opposite, equals(DivineCameraLens.front));
      });

      test('frontUltraWide returns back', () {
        expect(
          DivineCameraLens.frontUltraWide.opposite,
          equals(DivineCameraLens.back),
        );
      });
    });

    group('isFrontFacing', () {
      test('returns true for front camera', () {
        expect(DivineCameraLens.front.isFrontFacing, isTrue);
      });

      test('returns true for frontUltraWide', () {
        expect(DivineCameraLens.frontUltraWide.isFrontFacing, isTrue);
      });

      test('returns false for back camera', () {
        expect(DivineCameraLens.back.isFrontFacing, isFalse);
      });

      test('returns false for ultraWide', () {
        expect(DivineCameraLens.ultraWide.isFrontFacing, isFalse);
      });

      test('returns false for telephoto', () {
        expect(DivineCameraLens.telephoto.isFrontFacing, isFalse);
      });

      test('returns false for macro', () {
        expect(DivineCameraLens.macro.isFrontFacing, isFalse);
      });
    });

    group('isBackFacing', () {
      test('returns false for front camera', () {
        expect(DivineCameraLens.front.isBackFacing, isFalse);
      });

      test('returns false for frontUltraWide', () {
        expect(DivineCameraLens.frontUltraWide.isBackFacing, isFalse);
      });

      test('returns true for back camera', () {
        expect(DivineCameraLens.back.isBackFacing, isTrue);
      });

      test('returns true for ultraWide', () {
        expect(DivineCameraLens.ultraWide.isBackFacing, isTrue);
      });

      test('returns true for telephoto', () {
        expect(DivineCameraLens.telephoto.isBackFacing, isTrue);
      });

      test('returns true for macro', () {
        expect(DivineCameraLens.macro.isBackFacing, isTrue);
      });
    });

    group('facesUser', () {
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      test('is true only for the front lenses on iOS', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        expect(DivineCameraLens.allCamerasFaceUser, isFalse);
        expect(
          DivineCameraLens.values.where((lens) => lens.facesUser),
          equals([DivineCameraLens.front, DivineCameraLens.frontUltraWide]),
        );
      });

      test('is true for every lens on macOS', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        expect(DivineCameraLens.allCamerasFaceUser, isTrue);
        expect(
          DivineCameraLens.values.every((lens) => lens.facesUser),
          isTrue,
        );
      });
    });

    group('displayName', () {
      test('returns correct name for front', () {
        expect(DivineCameraLens.front.displayName, equals('Front'));
      });

      test('returns correct name for frontUltraWide', () {
        expect(
          DivineCameraLens.frontUltraWide.displayName,
          equals('Front Wide'),
        );
      });

      test('returns correct name for back', () {
        expect(DivineCameraLens.back.displayName, equals('Wide'));
      });

      test('returns correct name for ultraWide', () {
        expect(DivineCameraLens.ultraWide.displayName, equals('Ultra Wide'));
      });

      test('returns correct name for telephoto', () {
        expect(DivineCameraLens.telephoto.displayName, equals('Telephoto'));
      });

      test('returns correct name for macro', () {
        expect(DivineCameraLens.macro.displayName, equals('Macro'));
      });
    });

    group('shortLabel', () {
      test('returns 1x for front', () {
        expect(DivineCameraLens.front.shortLabel, equals('1x'));
      });

      test('returns 0.5x for frontUltraWide', () {
        expect(DivineCameraLens.frontUltraWide.shortLabel, equals('0.5x'));
      });

      test('returns 1x for back', () {
        expect(DivineCameraLens.back.shortLabel, equals('1x'));
      });

      test('returns 0.5x for ultraWide', () {
        expect(DivineCameraLens.ultraWide.shortLabel, equals('0.5x'));
      });

      test('returns 2x for telephoto', () {
        expect(DivineCameraLens.telephoto.shortLabel, equals('2x'));
      });

      test('returns Macro for macro', () {
        expect(DivineCameraLens.macro.shortLabel, equals('Macro'));
      });
    });

    group('isFrontFacing', () {
      test('returns true for front', () {
        expect(DivineCameraLens.front.isFrontFacing, isTrue);
      });

      test('returns true for frontUltraWide', () {
        expect(DivineCameraLens.frontUltraWide.isFrontFacing, isTrue);
      });

      test('returns false for back', () {
        expect(DivineCameraLens.back.isFrontFacing, isFalse);
      });

      test('returns false for ultraWide', () {
        expect(DivineCameraLens.ultraWide.isFrontFacing, isFalse);
      });

      test('returns false for telephoto', () {
        expect(DivineCameraLens.telephoto.isFrontFacing, isFalse);
      });

      test('returns false for macro', () {
        expect(DivineCameraLens.macro.isFrontFacing, isFalse);
      });
    });

    group('isFrontCameraLens', () {
      test('returns true for front', () {
        expect(DivineCameraLens.isFrontCameraLens('front'), isTrue);
      });

      test('returns true for frontUltraWide', () {
        expect(DivineCameraLens.isFrontCameraLens('frontUltraWide'), isTrue);
      });

      test('returns false for back', () {
        expect(DivineCameraLens.isFrontCameraLens('back'), isFalse);
      });

      test('returns false for ultraWide', () {
        expect(DivineCameraLens.isFrontCameraLens('ultraWide'), isFalse);
      });

      test('returns false for telephoto', () {
        expect(DivineCameraLens.isFrontCameraLens('telephoto'), isFalse);
      });

      test('returns false for macro', () {
        expect(DivineCameraLens.isFrontCameraLens('macro'), isFalse);
      });

      test('returns false for null', () {
        expect(DivineCameraLens.isFrontCameraLens(null), isFalse);
      });

      test('returns false for unknown value', () {
        expect(DivineCameraLens.isFrontCameraLens('unknown'), isFalse);
      });
    });
  });
}
