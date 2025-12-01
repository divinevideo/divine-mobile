// ABOUTME: Stub implementation for web camera service when not running on web platform
// ABOUTME: Prevents import errors on non-web platforms while allowing conditional imports

import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Stub for WebCameraService on non-web platforms
class WebCameraService {
  Future<void> initialize() async {
    throw UnsupportedError(
      'WebCameraService is only supported on web platform',
    );
  }

  Future<void> startRecording() async {
    throw UnsupportedError(
      'WebCameraService is only supported on web platform',
    );
  }

  Future<String?> stopRecording() async {
    throw UnsupportedError(
      'WebCameraService is only supported on web platform',
    );
  }

  Future<void> switchCamera() async {
    throw UnsupportedError(
      'WebCameraService is only supported on web platform',
    );
  }

  void dispose() {}

  static void revokeBlobUrl(String blobUrl) {
    // No-op on non-web platforms
  }
}

/// Stub for WebCameraPreview on non-web platforms
class WebCameraPreview extends StatelessWidget {
  const WebCameraPreview({required this.cameraService, super.key});
  final dynamic cameraService;

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black,
    child: Center(
      child: Text(
        'Web camera not available on this platform',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}

/// Stub function for blobUrlToBytes on non-web platforms
Future<Uint8List> blobUrlToBytes(String blobUrl) async {
  throw UnsupportedError('blobUrlToBytes is only supported on web platform');
}
