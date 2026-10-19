// ABOUTME: Empties Flutter's decoded-image cache and schedules a frame, so
// ABOUTME: the GPU memory behind the cached images is actually given back.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Empties Flutter's decoded-image cache and schedules a frame.
///
/// [ImageCache.clear] only drops the cache's references. Impeller gives the
/// textures behind them back when it next draws a frame, and a static screen
/// draws none: with a full cache, graphics memory stayed at 690 MB for 30 s
/// after a clear on a Galaxy S26 and fell to 386 MB once frames ran, and an
/// iPhone 12 Pro fell from 824 to 552 MB (#10301).
///
/// [includeLiveImages] also stops tracking images that are still on screen.
/// They stay visible, and are freed when the widgets showing them let go.
///
/// The frame follows the app's lifecycle, so a clear while the app is in the
/// background draws nothing until it returns. On Android the memory-pressure
/// clear on backgrounding arrives while the app is still inactive, so its
/// frame is drawn: graphics memory in the background fell from 632 MB to
/// 254–270 MB on the S26.
void clearDecodedImageCache({bool includeLiveImages = false}) {
  final cache = PaintingBinding.instance.imageCache..clear();
  if (includeLiveImages) cache.clearLiveImages();
  SchedulerBinding.instance.scheduleFrame();
}
