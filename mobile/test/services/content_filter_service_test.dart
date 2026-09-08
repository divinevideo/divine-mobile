import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  group(ContentFilterService, () {
    late ContentFilterService service;
    late AgeVerificationService ageService;
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      ageService = AgeVerificationService(
        preferences: preferences,
        currentPubkeyHex: () => _testPubkey,
      );
      service = ContentFilterService(ageVerificationService: ageService);
    });

    group('initialization', () {
      test('initializes with default preferences', () async {
        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(
          service.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.getPreference(ContentLabel.violence),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.getPreference(ContentLabel.alcohol),
          equals(ContentFilterPreference.hide),
        );
      });

      test('only initializes once', () async {
        await service.initialize();
        await service.setPreference(
          ContentLabel.flashingLights,
          ContentFilterPreference.show,
        );
        await service.initialize(); // Should not reset

        expect(
          service.getPreference(ContentLabel.flashingLights),
          equals(ContentFilterPreference.show),
        );
      });
    });

    group('default preferences', () {
      test('adult categories default to hide', () async {
        await service.initialize();

        for (final label in ContentFilterService.adultCategories) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} should default to hide',
          );
        }
      });

      test('always-filtered categories default to hide', () async {
        await service.initialize();

        for (final label in ContentFilterService.alwaysFilteredCategories) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} should always filter out',
          );
        }
      });

      test('visible categories default to warn', () async {
        await service.initialize();
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);

        for (final label in [
          ContentLabel.alcohol,
          ContentLabel.tobacco,
          ContentLabel.gambling,
          ContentLabel.profanity,
          ContentLabel.flashingLights,
          ContentLabel.spoiler,
          ContentLabel.misleading,
        ]) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.warn),
            reason: '${label.displayName} should default to warn',
          );
        }
      });

      test('adult categories default to hide even when age verified', () async {
        await service.initialize();
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);

        for (final label in ContentFilterService.adultCategories) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason:
                '${label.displayName} should stay hidden until the user '
                'opts in via Content Filters',
          );
        }
      });
    });

    group('setPreference', () {
      test('updates preference for a category', () async {
        await service.initialize();

        await service.setPreference(
          ContentLabel.flashingLights,
          ContentFilterPreference.hide,
        );

        expect(
          service.getPreference(ContentLabel.flashingLights),
          equals(ContentFilterPreference.hide),
        );
      });

      test('cannot change always-filtered categories away from hide', () async {
        await service.initialize();

        await service.setPreference(
          ContentLabel.porn,
          ContentFilterPreference.show,
        );

        expect(
          service.getPreference(ContentLabel.porn),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.allPreferences[ContentLabel.porn],
          equals(ContentFilterPreference.hide),
        );
      });

      test('persists preference across instances', () async {
        await service.initialize();
        await service.setPreference(
          ContentLabel.flashingLights,
          ContentFilterPreference.warn,
        );

        // Create new instance
        final newService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await newService.initialize();

        expect(
          newService.getPreference(ContentLabel.flashingLights),
          equals(ContentFilterPreference.warn),
        );
      });
    });

    group('age gate enforcement', () {
      test('adult categories locked to hide when not age verified', () async {
        await ageService.initialize();
        await service.initialize();

        // Not verified - should be locked
        expect(ageService.isAdultContentVerified, isFalse);
        expect(
          service.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.getPreference(ContentLabel.sexual),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.getPreference(ContentLabel.porn),
          equals(ContentFilterPreference.hide),
        );
      });

      test(
        'cannot set adult category to show without age verification',
        () async {
          await ageService.initialize();
          await service.initialize();

          await service.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.show,
          );

          // Should still be hide since not age verified
          expect(
            service.getPreference(ContentLabel.nudity),
            equals(ContentFilterPreference.hide),
          );
        },
      );

      test('can set adult category to show when age verified', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        await service.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );

        expect(
          service.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.show),
        );
      });

      test(
        'locks alcohol tobacco profanity and gambling when not age verified',
        () async {
          await ageService.initialize();
          await service.initialize();

          for (final label in [
            ContentLabel.alcohol,
            ContentLabel.tobacco,
            ContentLabel.profanity,
            ContentLabel.gambling,
          ]) {
            expect(
              service.getPreference(label),
              equals(ContentFilterPreference.hide),
              reason: '${label.displayName} should be hidden until verified',
            );

            await service.setPreference(label, ContentFilterPreference.show);

            expect(
              service.getPreference(label),
              equals(ContentFilterPreference.hide),
              reason: '${label.displayName} should reject unverified changes',
            );
          }
        },
      );

      test('visible non-adult categories not affected by age gate', () async {
        await ageService.initialize();
        await service.initialize();

        await service.setPreference(
          ContentLabel.flashingLights,
          ContentFilterPreference.show,
        );

        expect(
          service.getPreference(ContentLabel.flashingLights),
          equals(ContentFilterPreference.show),
        );
      });
    });

    group('getPreferenceForLabels', () {
      test('returns show when no labels match', () async {
        await service.initialize();

        final result = service.getPreferenceForLabels(['unknown-label']);
        expect(result, equals(ContentFilterPreference.show));
      });

      test('returns show for empty list', () async {
        await service.initialize();

        final result = service.getPreferenceForLabels([]);
        expect(result, equals(ContentFilterPreference.show));
      });

      test('returns most restrictive preference', () async {
        await service.initialize();

        // flashing-lights=warn, misleading=warn -> should return warn
        final result = service.getPreferenceForLabels([
          'flashing-lights',
          'misleading',
        ]);
        expect(result, equals(ContentFilterPreference.warn));
      });

      test('returns hide when any label is hide', () async {
        await service.initialize();

        // alcohol=hide while unverified, nudity=hide -> should return hide
        final result = service.getPreferenceForLabels(['alcohol', 'nudity']);
        expect(result, equals(ContentFilterPreference.hide));
      });

      test(
        'always-filtered labels return hide regardless of stored value',
        () async {
          await service.initialize();

          await service.setPreference(
            ContentLabel.aiGenerated,
            ContentFilterPreference.warn,
          );

          final result = service.getPreferenceForLabels(['ai-generated']);
          expect(result, equals(ContentFilterPreference.hide));
        },
      );
    });

    group('lockAdultCategories', () {
      test('resets all age-restricted categories to hide', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        // Set adult categories to show (allowed when verified)
        await service.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );
        await service.setPreference(
          ContentLabel.sexual,
          ContentFilterPreference.warn,
        );
        await service.setPreference(
          ContentLabel.alcohol,
          ContentFilterPreference.show,
        );
        await service.setPreference(
          ContentLabel.gambling,
          ContentFilterPreference.warn,
        );

        // Lock them back
        await service.lockAdultCategories();

        for (final label in ContentFilterService.ageRestrictedCategories) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} should be locked to hide',
          );
        }
      });
    });

    group('unlockAdultCategories', () {
      test('non-adult age-restricted categories default to warn after '
          'verification while adult categories stay hidden', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        for (final label in [
          ContentLabel.alcohol,
          ContentLabel.tobacco,
          ContentLabel.profanity,
          ContentLabel.gambling,
        ]) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.warn),
            reason: '${label.displayName} should default to warn',
          );
        }
        for (final label in ContentFilterService.adultCategories) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} should stay hidden',
          );
        }
      });

      test('promotes locked non-adult categories back to warn but leaves '
          'adult categories hidden', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        await service.lockAdultCategories();
        await service.unlockAdultCategories();

        for (final label in [
          ContentLabel.alcohol,
          ContentLabel.tobacco,
          ContentLabel.profanity,
          ContentLabel.gambling,
        ]) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.warn),
            reason: '${label.displayName} should be promoted from hide to warn',
          );
        }
        for (final label in ContentFilterService.adultCategories) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} requires explicit opt-in',
          );
        }
      });

      test('does not overwrite an existing warn preference', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        // User had previously set nudity to warn
        await service.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.warn,
        );

        await service.unlockAdultCategories();

        expect(
          service.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.warn),
        );
      });

      test('does not overwrite an existing show preference', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        // User had previously set sexual to show
        await service.setPreference(
          ContentLabel.sexual,
          ContentFilterPreference.show,
        );

        await service.unlockAdultCategories();

        expect(
          service.getPreference(ContentLabel.sexual),
          equals(ContentFilterPreference.show),
        );
      });

      test('only promotes hide categories, leaves others intact', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        // Explicitly set nudity to show, leave the others at hide
        await service.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );

        await service.unlockAdultCategories();

        // nudity was already show — must not be changed
        expect(
          service.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.show),
        );
        // sexual is an adult category: unlock never promotes it, so it
        // stays hidden until the user opts in. Pornography remains locked
        // to hide because it is always filtered out.
        expect(
          service.getPreference(ContentLabel.sexual),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.getPreference(ContentLabel.porn),
          equals(ContentFilterPreference.hide),
        );
      });

      test('persists unlocked preferences across instances', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        await service.unlockAdultCategories();

        final newAgeService = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => _testPubkey,
        );
        await newAgeService.initialize();
        final newService = ContentFilterService(
          ageVerificationService: newAgeService,
        );
        await newService.initialize();

        // age-verified so the gate is lifted; persisted warn should be visible
        await newAgeService.setAdultContentVerified(true);
        for (final label in [
          ContentLabel.alcohol,
          ContentLabel.tobacco,
          ContentLabel.profanity,
          ContentLabel.gambling,
        ]) {
          expect(
            newService.getPreference(label),
            equals(ContentFilterPreference.warn),
            reason: '${label.displayName} should survive restart',
          );
        }
        for (final label in ContentFilterService.adultCategories) {
          expect(
            newService.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} should stay hidden after restart',
          );
        }
      });

      test('adultPlaybackPreference stays hide after unlock until the user '
          'opts in', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        await service.unlockAdultCategories();

        expect(
          service.adultPlaybackPreference,
          equals(ContentFilterPreference.hide),
        );
      });

      test('adultPlaybackPreference is warn after an explicit per-category '
          'opt-in', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        await service.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.warn,
        );
        await service.setPreference(
          ContentLabel.sexual,
          ContentFilterPreference.warn,
        );

        expect(
          service.adultPlaybackPreference,
          equals(ContentFilterPreference.warn),
        );
      });

      test('adultPlaybackPreference stays hide until every configurable adult '
          'category is opted in', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        await service.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.warn,
        );

        expect(
          service.adultPlaybackPreference,
          equals(ContentFilterPreference.hide),
        );
      });
    });

    group('adultPlaybackPreference', () {
      test('returns hide when adult categories are locked', () async {
        await ageService.initialize();
        await service.initialize();

        expect(
          service.adultPlaybackPreference,
          equals(ContentFilterPreference.hide),
        );
      });

      test(
        'returns show when configurable adult categories are set to show',
        () async {
          await ageService.initialize();
          await ageService.setAdultContentVerified(true);
          await service.initialize();

          for (final label in [ContentLabel.nudity, ContentLabel.sexual]) {
            await service.setPreference(label, ContentFilterPreference.show);
          }

          expect(
            service.adultPlaybackPreference,
            equals(ContentFilterPreference.show),
          );
        },
      );

      test(
        'returns warn when opted-in adult categories have mixed non-hide '
        'preferences',
        () async {
          await ageService.initialize();
          await ageService.setAdultContentVerified(true);
          await service.initialize();

          await service.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.show,
          );
          await service.setPreference(
            ContentLabel.sexual,
            ContentFilterPreference.warn,
          );
          await service.setPreference(
            ContentLabel.porn,
            ContentFilterPreference.hide,
          );

          expect(
            service.adultPlaybackPreference,
            equals(ContentFilterPreference.warn),
          );
        },
      );

      test(
        'returns hide when any configurable adult category remains hidden',
        () async {
          await ageService.initialize();
          await ageService.setAdultContentVerified(true);
          await service.initialize();

          await service.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.show,
          );

          expect(
            service.adultPlaybackPreference,
            equals(ContentFilterPreference.hide),
          );
        },
      );
    });

    group('allPreferences', () {
      test('returns unmodifiable map of all preferences', () async {
        await service.initialize();

        final prefs = service.allPreferences;

        // Should have entries for all labels except other
        expect(prefs.length, greaterThanOrEqualTo(17));
        expect(
          () => (prefs as Map)[ContentLabel.nudity] =
              ContentFilterPreference.show,
          throwsUnsupportedError,
        );
      });

      test('reports always-filtered categories as hide', () async {
        await service.initialize();

        for (final label in ContentFilterService.alwaysFilteredCategories) {
          expect(
            service.allPreferences[label],
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} should be stored as hide',
          );
        }
      });
    });

    group('adult media cache invalidation', () {
      test(
        'clears caches when passive adult thumbnail access is revoked',
        () async {
          var clearCount = 0;
          ageService = AgeVerificationService(
            preferences: preferences,
            currentPubkeyHex: () => _testPubkey,
          );
          service = ContentFilterService(
            ageVerificationService: ageService,
            onAdultMediaAccessRevoked: () async {
              clearCount++;
            },
          );
          await ageService.initialize();
          await ageService.setAdultContentVerified(true);
          await service.initialize();
          await service.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.show,
          );
          await service.setPreference(
            ContentLabel.sexual,
            ContentFilterPreference.show,
          );
          expect(service.adultPlaybackPreference, ContentFilterPreference.show);

          await service.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.warn,
          );

          expect(clearCount, equals(1));
        },
      );

      test(
        'does not clear caches for unrelated content-filter changes',
        () async {
          var clearCount = 0;
          service = ContentFilterService(
            ageVerificationService: ageService,
            onAdultMediaAccessRevoked: () async {
              clearCount++;
            },
          );
          await ageService.initialize();
          await ageService.setAdultContentVerified(true);
          await service.initialize();

          await service.setPreference(
            ContentLabel.flashingLights,
            ContentFilterPreference.show,
          );

          expect(clearCount, isZero);
        },
      );
    });

    group('migration from old preferences', () {
      test(
        'overwrites stale stored preferences for always-filtered categories',
        () async {
          SharedPreferences.setMockInitialValues({
            'content_filter_prefs':
                '{"drugs":"show","violence":"warn","ai-generated":"show",'
                '"porn":"show"}',
          });

          final migrationService = ContentFilterService(
            ageVerificationService: ageService,
          );
          await migrationService.initialize();

          for (final label in [
            ContentLabel.drugs,
            ContentLabel.violence,
            ContentLabel.aiGenerated,
            ContentLabel.porn,
          ]) {
            expect(
              migrationService.getPreference(label),
              equals(ContentFilterPreference.hide),
            );
            expect(
              migrationService.allPreferences[label],
              equals(ContentFilterPreference.hide),
            );
          }

          final prefs = await SharedPreferences.getInstance();
          final persisted = jsonDecode(
            prefs.getString('content_filter_prefs')!,
          ) as Map<String, dynamic>;
          expect(persisted['drugs'], equals('hide'));
          expect(persisted['violence'], equals('hide'));
          expect(persisted['ai-generated'], equals('hide'));
          expect(persisted['porn'], equals('hide'));
        },
      );

      test('migrates alwaysShow to show for adult categories', () async {
        SharedPreferences.setMockInitialValues({
          // Legacy playback preference "alwaysShow" = index 0
          'adult_content_preference': 0,
        });

        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        final migrationService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await migrationService.initialize();

        // After migration, adult categories should be show
        // (but only visible when age-verified)
        expect(
          migrationService.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.show),
        );
      });

      test('persists migrated adult categories across restart', () async {
        SharedPreferences.setMockInitialValues({
          // Legacy playback preference "alwaysShow" = index 0
          'adult_content_preference': 0,
        });

        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        final migrationService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await migrationService.initialize();

        final restartedAgeService = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => _testPubkey,
        );
        await restartedAgeService.initialize();
        final restartedService = ContentFilterService(
          ageVerificationService: restartedAgeService,
        );
        await restartedService.initialize();

        for (final label in [ContentLabel.nudity, ContentLabel.sexual]) {
          expect(
            restartedService.getPreference(label),
            equals(ContentFilterPreference.show),
            reason: '${label.displayName} should survive restart',
          );
        }
        expect(
          restartedService.getPreference(ContentLabel.porn),
          equals(ContentFilterPreference.hide),
        );
      });

      test(
        'preserves existing adult category preferences during migration',
        () async {
          SharedPreferences.setMockInitialValues({
            // Legacy playback preference "alwaysShow" = index 0
            'adult_content_preference': 0,
            'content_filter_prefs':
                '{"nudity":"hide","sexual":"warn","violence":"hide"}',
          });

          await ageService.initialize();
          await ageService.setAdultContentVerified(true);

          final migrationService = ContentFilterService(
            ageVerificationService: ageService,
          );
          await migrationService.initialize();

          expect(
            migrationService.getPreference(ContentLabel.nudity),
            equals(ContentFilterPreference.hide),
          );
          expect(
            migrationService.getPreference(ContentLabel.sexual),
            equals(ContentFilterPreference.warn),
          );
          expect(
            migrationService.getPreference(ContentLabel.porn),
            equals(ContentFilterPreference.hide),
          );
          expect(
            migrationService.getPreference(ContentLabel.violence),
            equals(ContentFilterPreference.hide),
          );
        },
      );

      test('migrates askEachTime to warn for adult categories', () async {
        SharedPreferences.setMockInitialValues({
          // Legacy playback preference "askEachTime" = index 1
          'adult_content_preference': 1,
        });

        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        final migrationService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await migrationService.initialize();

        expect(
          migrationService.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.warn),
        );
      });

      test('migrates neverShow to hide for adult categories', () async {
        SharedPreferences.setMockInitialValues({
          // Legacy playback preference "neverShow" = index 2
          'adult_content_preference': 2,
        });

        final migrationService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await migrationService.initialize();

        expect(
          migrationService.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.hide),
        );
      });

      test('only migrates once', () async {
        SharedPreferences.setMockInitialValues({
          'adult_content_preference': 0, // alwaysShow
        });

        await ageService.initialize();
        await ageService.setAdultContentVerified(true);

        // First initialization migrates
        final firstService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await firstService.initialize();

        // Change preference after migration
        await firstService.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.hide,
        );

        // Second initialization should NOT re-migrate
        final secondService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await secondService.initialize();

        expect(
          secondService.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.hide),
        );
      });
    });
  });
}
