// ABOUTME: Mock video controller for tests that avoids actual video initialization
// ABOUTME: Provides minimal implementation to make tests pass without real video players

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Test implementation of VideoPlayerController that doesn't require real video files
class TestVideoPlayerController extends VideoPlayerController {
  TestVideoPlayerController(String dataSource)
    : _dataSource = dataSource,
      super.networkUrl(Uri.parse(dataSource));

  final String _dataSource;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isDisposed = false;
  Duration _position = Duration.zero;

  @override
  Future<void> initialize() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    // Simulate initialization delay
    await Future.delayed(const Duration(milliseconds: 10));
    _isInitialized = true;
    // Notify listeners that initialization is complete
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 6),
      size: const Size(1080, 1920),
    );
  }

  @override
  Future<void> play() async {
    if (!_isInitialized) throw StateError('Not initialized');
    if (_isDisposed) throw StateError('Controller is disposed');
    _isPlaying = true;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    if (!_isInitialized) throw StateError('Not initialized');
    if (_isDisposed) throw StateError('Controller is disposed');
    _isPlaying = false;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (!_isInitialized) throw StateError('Not initialized');
    if (_isDisposed) throw StateError('Controller is disposed');
    _position = position;
    value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _isInitialized = false;
    _isPlaying = false;
    super.dispose();
  }

  @override
  VideoPlayerValue get value => _isDisposed
      ? VideoPlayerValue.uninitialized()
      : VideoPlayerValue(
          duration: const Duration(seconds: 6),
          size: const Size(1080, 1920),
          position: _position,
          isPlaying: _isPlaying,
          isInitialized: _isInitialized,
          isBuffering: false,
          errorDescription: null,
        );

  @override
  String get dataSource => _dataSource;
}
