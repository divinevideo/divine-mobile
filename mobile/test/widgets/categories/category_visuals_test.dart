// ABOUTME: Tests for CategoryVisuals asset-path resolution and aliases.
// ABOUTME: Locks the #4398 alias map so backend names resolve to bundled SVGs.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:openvine/widgets/categories/category_visuals.dart';

void main() {
  group(CategoryVisuals, () {
    group('forCategory asset path', () {
      test('aliases backend "beverages" onto the bundled beverage.svg', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'beverages', videoCount: 5),
          0,
        );

        expect(visuals.assetPath, equals('assets/categories/beverage.svg'));
      });

      test('derives the path from the slug for non-aliased categories', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'comedy', videoCount: 99),
          3,
        );

        expect(visuals.assetPath, equals('assets/categories/comedy.svg'));
      });

      test('is case-insensitive on the slug', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'BEVERAGES', videoCount: 5),
          0,
        );

        expect(visuals.assetPath, equals('assets/categories/beverage.svg'));
      });

      test('resolves to null when no SVG is bundled for the slug (#6116)', () {
        // "fighting" has no assets/categories/fighting.svg; the old code pointed
        // assetPath at the missing file and let the load throw.
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'fighting', videoCount: 42),
          1,
        );

        expect(visuals.assetPath, isNull);
        // A missing asset must not cost the category its fallback colors.
        expect(visuals.backgroundColor, isNotNull);
        expect(visuals.foregroundColor, isNotNull);
      });
    });

    group('forCategory sticker', () {
      CategorySticker? stickerFor(String slug, {int index = 0}) {
        return CategoryVisuals.forCategory(
          VideoCategory(name: slug, videoCount: 1),
          index,
        ).sticker;
      }

      test('gives every category with a designed sticker its sticker', () {
        const illustrated = {
          'animals': DivineStickerName.horse,
          'food': DivineStickerName.pizzaSlice,
          'sports': DivineStickerName.foamFinger,
          'fashion': DivineStickerName.sunglasses,
          'music': DivineStickerName.djController,
          'art': DivineStickerName.ceramicHands,
          'entertainment': DivineStickerName.psychedelicTv,
          'family': DivineStickerName.toaster,
          'comedy': DivineStickerName.chatteringTeeth,
          'dance': DivineStickerName.discoBall,
          'travel': DivineStickerName.luggage,
          'education': DivineStickerName.schoolBackpack,
          'gaming': DivineStickerName.gameController,
          'news': DivineStickerName.newsCamera,
          'nature': DivineStickerName.rainforest,
          'fitness': DivineStickerName.pinkDumbbells,
          'animation': DivineStickerName.videoClapBoard,
          'beauty': DivineStickerName.glitterLips,
          'pets': DivineStickerName.cat,
          'automotive': DivineStickerName.flatTire,
          'pranks': DivineStickerName.boom,
        };

        for (final MapEntry(key: slug, value: sticker) in illustrated.entries) {
          expect(stickerFor(slug)?.name, equals(sticker), reason: slug);
        }
      });

      test('is case-insensitive on the slug', () {
        expect(stickerFor('Animals')?.name, equals(DivineStickerName.horse));
      });

      test('does not depend on the fallback colour index', () {
        expect(
          stickerFor('comedy', index: 3)?.name,
          equals(DivineStickerName.chatteringTeeth),
        );
      });

      test('is null for a category the backend invents', () {
        expect(stickerFor('fighting'), isNull);
      });
    });

    group('featured categories', () {
      test('returns the curated visuals for a featured category', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'music', videoCount: 1797),
          7,
        );

        expect(visuals.assetPath, equals('assets/categories/music.svg'));
        // Featured categories use a hand-picked palette, not a fallback color.
        expect(visuals.backgroundColor, isNot(equals(visuals.foregroundColor)));
      });

      test('maps fashion to the curated style asset', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'fashion', videoCount: 10),
          0,
        );

        expect(visuals.assetPath, equals('assets/categories/style.svg'));
      });
    });

    group('bundledAssetBasenames', () {
      test('stays in sync with the assets/categories/ directory (#6116)', () {
        // The set is the runtime source of truth for "is this asset bundled?".
        // If it drifts from disk, forCategory either drops a real asset (ugly
        // emoji fallback) or points at a missing file (the crash returns), so
        // pin it to the actual *.svg files here.
        final onDisk = Directory('assets/categories')
            .listSync()
            .whereType<File>()
            .map((e) => e.uri.pathSegments.last)
            .where((name) => name.endsWith('.svg'))
            .map((name) => name.substring(0, name.length - '.svg'.length))
            .toSet();

        expect(
          onDisk,
          isNotEmpty,
          reason: 'asset directory should not be empty',
        );
        expect(CategoryVisuals.bundledAssetBasenames, equals(onDisk));
      });

      test('every featured category resolves a bundled asset', () {
        // Featured basenames resolve through the same bundled-set gate as
        // derived names, so a curated asset drifting off disk would silently
        // demote a flagship category to its emoji — pin all of them here.
        expect(CategoryVisuals.featuredCategoryNames, isNotEmpty);
        for (final name in CategoryVisuals.featuredCategoryNames) {
          final visuals = CategoryVisuals.forCategory(
            VideoCategory(name: name, videoCount: 1),
            0,
          );
          expect(
            visuals.assetPath,
            isNotNull,
            reason: '$name is featured but its asset is not bundled',
          );
        }
      });
    });
  });
}
