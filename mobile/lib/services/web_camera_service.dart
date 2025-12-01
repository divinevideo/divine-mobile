// ABOUTME: Web-specific camera service using getUserMedia and MediaRecorder APIs
// ABOUTME: Provides native web camera integration for Vine recording in browsers

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Web camera service that uses getUserMedia and MediaRecorder
class WebCameraService {
  html.MediaStream? _mediaStream;
  html.MediaRecorder? _mediaRecorder;
  html.VideoElement? _videoElement;
  final List<html.Blob> _recordedChunks = [];
  bool _isRecording = false;
  bool _isInitialized = false;
  StreamController<String>? _recordingCompleteController;

  /// Initialize the web camera
  Future<void> initialize() async {
    if (!kIsWeb) {
      throw Exception('WebCameraService can only be used on web platforms');
    }

    try {
      // Check if mediaDevices API is available
      if (html.window.navigator.mediaDevices == null) {
        throw Exception(
          'MediaDevices API not available. Please ensure you are using HTTPS.',
        );
      }

      // Request camera permissions and get media stream
      // Try with audio first, fall back to video-only if audio fails
      try {
        _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
          'video': {
            'width': {'ideal': 640},
            'height': {'ideal': 640},
            'facingMode': 'user', // Front camera by default for web
          },
          'audio': true,
        });
      } catch (audioError) {
        Log.warning(
          'Failed to get audio, trying video-only: $audioError',
          name: 'WebCameraService',
          category: LogCategory.system,
        );

        // Try without audio
        _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
          'video': {
            'width': {'ideal': 640},
            'height': {'ideal': 640},
            'facingMode': 'user',
          },
          'audio': false,
        });
      }

      // Create video element for preview
      _videoElement = html.VideoElement()
        ..srcObject = _mediaStream
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      _isInitialized = true;
      Log.info(
        '📱 Web camera initialized successfully',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Web camera initialization failed: $e',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
      throw Exception('Failed to initialize web camera: $e');
    }
  }

  /// Start recording a segment
  Future<void> startRecording() async {
    Log.info(
      '📱 WebCameraService.startRecording() - initialized: $_isInitialized, hasStream: ${_mediaStream != null}, isRecording: $_isRecording',
      name: 'WebCameraService',
      category: LogCategory.system,
    );

    if (!_isInitialized || _mediaStream == null || _isRecording) {
      final error =
          'Camera not initialized or already recording - initialized: $_isInitialized, hasStream: ${_mediaStream != null}, isRecording: $_isRecording';
      Log.error(
        'WebCameraService.startRecording() failed: $error',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
      throw Exception(error);
    }

    try {
      _recordedChunks.clear();
      _recordingCompleteController = StreamController<String>();

      // Create MediaRecorder
      _mediaRecorder = html.MediaRecorder(_mediaStream!, {
        'mimeType': _getSupportedMimeType(),
      });

      // Set up event listeners
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && blobEvent.data!.size > 0) {
          _recordedChunks.add(blobEvent.data!);
        }
      });

      _mediaRecorder!.addEventListener('stop', (event) {
        _finishRecording();
      });

      _mediaRecorder!.addEventListener('error', (event) {
        Log.error(
          'MediaRecorder error: $event',
          name: 'WebCameraService',
          category: LogCategory.system,
        );
        _isRecording = false;
      });

      // Start recording
      _mediaRecorder!.start();
      _isRecording = true;

      Log.info(
        'Started web camera recording',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
    } catch (e) {
      _isRecording = false;
      Log.error(
        'Failed to start web recording: $e',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
      throw Exception('Failed to start recording: $e');
    }
  }

  /// Stop recording and return the blob URL
  Future<String> stopRecording() async {
    Log.debug(
      '📱 WebCameraService.stopRecording() - isRecording: $_isRecording, hasRecorder: ${_mediaRecorder != null}',
      name: 'WebCameraService',
      category: LogCategory.system,
    );

    if (!_isRecording || _mediaRecorder == null) {
      final error =
          'Not currently recording - isRecording: $_isRecording, hasRecorder: ${_mediaRecorder != null}';
      Log.error(
        'WebCameraService.stopRecording() failed: $error',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
      throw Exception(error);
    }

    try {
      _mediaRecorder!.stop();
      _isRecording = false;

      // Wait for the recording to be processed
      final blobUrl = await _recordingCompleteController!.stream.first;
      return blobUrl;
    } catch (e) {
      Log.error(
        'Failed to stop web recording: $e',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Finish recording and create blob URL
  void _finishRecording() {
    if (_recordedChunks.isEmpty) {
      _recordingCompleteController?.addError('No recorded data');
      return;
    }

    try {
      // Create blob from recorded chunks
      final blob = html.Blob(_recordedChunks, _getSupportedMimeType());
      final blobUrl = html.Url.createObjectUrl(blob);

      _recordingCompleteController?.add(blobUrl);
      Log.info(
        'Web recording completed, blob URL: $blobUrl',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
    } catch (e) {
      _recordingCompleteController?.addError(e);
      Log.error(
        'Failed to create blob: $e',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
    }
  }

  /// Get the video element for preview
  html.VideoElement? get videoElement => _videoElement;

  /// Check if camera is initialized
  bool get isInitialized => _isInitialized;

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Switch between front and back camera (if available)
  Future<void> switchCamera() async {
    if (!_isInitialized) return;

    try {
      // Stop current stream
      _mediaStream?.getTracks().forEach((track) => track.stop());

      // Get current facing mode
      final currentConstraints = _mediaStream
          ?.getVideoTracks()
          .first
          .getSettings();
      final currentFacingMode = currentConstraints?['facingMode'] ?? 'user';
      final newFacingMode = currentFacingMode == 'user'
          ? 'environment'
          : 'user';

      // Request new stream with different camera
      _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 640},
          'facingMode': newFacingMode,
        },
        'audio': true,
      });

      // Update video element
      _videoElement?.srcObject = _mediaStream;

      Log.debug(
        'Switched to $newFacingMode camera',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to switch camera: $e',
        name: 'WebCameraService',
        category: LogCategory.system,
      );
      // If switching fails, try to restore original stream
      try {
        _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
          'video': {
            'width': {'ideal': 640},
            'height': {'ideal': 640},
            'facingMode': 'user',
          },
          'audio': true,
        });
        _videoElement?.srcObject = _mediaStream;
      } catch (restoreError) {
        Log.error(
          'Failed to restore camera: $restoreError',
          name: 'WebCameraService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Get supported MIME type for recording
  String _getSupportedMimeType() {
    // Try different MIME types in order of preference
    final mimeTypes = [
      'video/webm;codecs=vp9',
      'video/webm;codecs=vp8',
      'video/webm',
      'video/mp4',
    ];

    for (final mimeType in mimeTypes) {
      if (html.MediaRecorder.isTypeSupported(mimeType)) {
        return mimeType;
      }
    }

    // Fallback to webm if nothing else is supported
    return 'video/webm';
  }

  /// Download recorded video as file
  void downloadRecording(String blobUrl, String filename) {
    final anchor = html.AnchorElement(href: blobUrl)
      ..download = filename
      ..style.display = 'none';

    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();

    Log.debug(
      'Download triggered for $filename',
      name: 'WebCameraService',
      category: LogCategory.system,
    );
  }

  /// Revoke blob URL to free memory
  static void revokeBlobUrl(String blobUrl) {
    if (blobUrl.startsWith('blob:')) {
      try {
        html.Url.revokeObjectUrl(blobUrl);
        Log.debug(
          '🧹 Revoked blob URL: $blobUrl',
          name: 'WebCameraService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Error revoking blob URL: $e',
          name: 'WebCameraService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null; // Clear the stream reference
    _mediaRecorder = null;
    _videoElement = null;
    _recordingCompleteController?.close();
    _isInitialized = false;
    _isRecording = false; // Reset recording state
    Log.debug(
      '📱️ Web camera service disposed',
      name: 'WebCameraService',
      category: LogCategory.system,
    );
  }
}

/// Flutter widget that wraps the HTML video element for web camera preview
class WebCameraPreview extends StatefulWidget {
  const WebCameraPreview({required this.cameraService, super.key});
  final WebCameraService cameraService;

  @override
  State<WebCameraPreview> createState() => _WebCameraPreviewState();
}

class _WebCameraPreviewState extends State<WebCameraPreview> {
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _registerVideoElement();
  }

  void _registerVideoElement() {
    if (!kIsWeb || widget.cameraService.videoElement == null) return;

    // Generate unique view type
    _viewType = 'web-camera-${DateTime.now().millisecondsSinceEpoch}';

    // Register the video element as a platform view
    // ignore: avoid_web_libraries_in_flutter
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType!,
      (int viewId) => widget.cameraService.videoElement!,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _viewType == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Camera not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return HtmlElementView(viewType: _viewType!);
  }
}

/// Convert blob URL to Uint8List for further processing
Future<Uint8List> blobUrlToBytes(String blobUrl) async {
  final response = await html.window.fetch(blobUrl);
  final blob = await response.blob();
  final reader = html.FileReader();

  final completer = Completer<Uint8List>();
  reader.onLoadEnd.listen((_) {
    final result = reader.result as List<int>;
    completer.complete(Uint8List.fromList(result));
  });

  reader.onError.listen((error) {
    completer.completeError('Failed to read blob: $error');
  });

  reader.readAsArrayBuffer(blob);
  return completer.future;
}
