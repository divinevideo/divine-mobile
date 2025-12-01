// ABOUTME: Service for uploading videos to user-configured Blossom media servers
// ABOUTME: Supports Blossom BUD-01 authentication and returns media URLs from any Blossom server

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/utils/hash_util.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result type for Blossom upload operations
class BlossomUploadResult {
  final bool success;
  final String? videoId; // SHA-256 hash
  final String? url; // Primary HLS URL from server
  final String? fallbackUrl; // R2 MP4 URL (always available immediately)
  final String? streamingMp4Url; // BunnyStream MP4 URL (may be processing)
  final String? streamingHlsUrl; // BunnyStream HLS URL (same as url)
  final String? thumbnailUrl; // Auto-generated thumbnail
  final String? streamingStatus; // "processing" or "ready"
  final String? gifUrl; // Deprecated - keeping for backwards compatibility
  final String? blurhash; // Deprecated - keeping for backwards compatibility
  final String? errorMessage;

  // Convenience getter for backwards compatibility
  String? get cdnUrl => fallbackUrl ?? url;

  const BlossomUploadResult({
    required this.success,
    this.videoId,
    this.url,
    this.fallbackUrl,
    this.streamingMp4Url,
    this.streamingHlsUrl,
    this.thumbnailUrl,
    this.streamingStatus,
    this.gifUrl,
    this.blurhash,
    this.errorMessage,
  });
}

class BlossomUploadService {
  static const String _blossomServerKey = 'blossom_server_url';
  static const String _useBlossomKey = 'use_blossom_upload';
  static const String defaultBlossomServer = 'https://blossom.divine.video';

  final AuthService authService;
  final INostrService nostrService;
  final Dio dio;

  BlossomUploadService({
    required this.authService,
    required this.nostrService,
    Dio? dio,
  }) : dio = dio ?? Dio();

  /// Get the configured Blossom server URL
  Future<String?> getBlossomServer() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_blossomServerKey);
    // If nothing is stored, return default. If empty string is stored, return it.
    return stored ?? defaultBlossomServer;
  }

  /// Set the Blossom server URL
  Future<void> setBlossomServer(String? serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      await prefs.setString(_blossomServerKey, serverUrl);
    } else {
      // Store empty string to indicate "no server configured"
      await prefs.setString(_blossomServerKey, '');
    }
  }

  /// Check if custom Blossom server is enabled
  /// When false (default), uploads go to diVine's Blossom server
  /// When true, uploads go to the user's custom configured server
  Future<bool> isBlossomEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useBlossomKey) ??
        false; // Default to false (use diVine's server)
  }

  /// Enable or disable Blossom upload
  Future<void> setBlossomEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBlossomKey, enabled);
  }

  /// Create a Blossom authentication event for upload
  Future<Event?> _createBlossomAuthEvent({
    required String url,
    required String method,
    required String fileHash,
    required int fileSize,
    String contentDescription = 'Upload video to Blossom server',
  }) async {
    try {
      // Blossom requires these tags (BUD-01):
      // - t: "upload" to indicate upload request
      // - expiration: Unix timestamp when auth expires
      // - x: SHA-256 hash of the file (optional but recommended)

      final now = DateTime.now();
      final expiration = now.add(
        const Duration(minutes: 5),
      ); // 5 minute expiration
      final expirationTimestamp = expiration.millisecondsSinceEpoch ~/ 1000;

      // Build tags for Blossom auth event (kind 24242)
      final tags = [
        ['t', 'upload'],
        ['expiration', expirationTimestamp.toString()],
        ['size', fileSize.toString()], // File size for server validation
        ['x', fileHash], // SHA-256 hash of the file
      ];

      // Use AuthService to create and sign the event (established pattern)
      final signedEvent = await authService.createAndSignEvent(
        kind: 24242, // Blossom auth event kind
        content: contentDescription,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create/sign Blossom auth event via AuthService',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Created Blossom auth event: ${signedEvent.id}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event kind: ${signedEvent.kind}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event pubkey: ${signedEvent.pubkey}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event created_at: ${signedEvent.createdAt}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event tags: ${signedEvent.tags}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return signedEvent;
    } catch (e) {
      Log.error(
        'Error creating Blossom auth event: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Upload a video file to the configured Blossom server
  ///
  /// This method currently returns a placeholder implementation.
  /// The actual Blossom upload will be implemented using the SDK's
  /// BolssomUploader when the Nostr service integration is ready.
  ///
  /// [proofManifestJson] - Optional ProofMode manifest JSON string for cryptographic proof
  Future<BlossomUploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    required String title,
    String? description,
    List<String>? hashtags,
    String? proofManifestJson,
    void Function(double)? onProgress,
  }) async {
    // Start performance trace for video upload
    await PerformanceMonitoringService.instance.startTrace('video_upload');

    try {
      // Determine which server to use
      // If custom server is enabled, use the configured server
      // Otherwise, use the default diVine Blossom server
      final isCustomServerEnabled = await isBlossomEnabled();
      String serverUrl;

      if (isCustomServerEnabled) {
        final customServerUrl = await getBlossomServer();
        if (customServerUrl == null || customServerUrl.isEmpty) {
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Custom Blossom server enabled but not configured',
          );
        }
        serverUrl = customServerUrl;
      } else {
        // Use default diVine Blossom server
        serverUrl = 'https://blossom.divine.video';
      }

      // Parse and validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL',
        );
      }

      // Check authentication after URL validation
      if (!authService.isAuthenticated) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }

      Log.info(
        'Uploading to Blossom server: $serverUrl',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      Log.info(
        'Checking if user is authenticated...',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Check if user is authenticated (has keys available)
      if (!authService.isAuthenticated) {
        Log.error(
          '❌ User not authenticated - cannot sign Blossom requests',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return BlossomUploadResult(
          success: false,
          errorMessage: 'User not authenticated - please sign in to upload',
        );
      }

      Log.info(
        '✅ User is authenticated, can create signed events',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Report initial progress
      onProgress?.call(0.1);

      // Use Blossom spec: POST with raw bytes
      Log.info(
        'Uploading using Blossom spec (POST with raw bytes)',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Read file bytes
      final fileBytes = await videoFile.readAsBytes();
      final fileSize = fileBytes.length;
      final fileHash = HashUtil.sha256Hash(fileBytes);

      // Add file size metric to performance trace
      PerformanceMonitoringService.instance.setMetric(
        'video_upload',
        'file_size_bytes',
        fileSize,
      );

      Log.info(
        'File hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      onProgress?.call(0.2);

      // Create Blossom auth event (kind 24242)
      final authEvent = await _createBlossomAuthEvent(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
      );

      if (authEvent == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
        );
      }

      // Prepare headers following Blossom spec (BUD-01 requires standard base64 encoding)
      final authEventJson = jsonEncode(authEvent.toJson());
      final authHeader = 'Nostr ${base64.encode(utf8.encode(authEventJson))}';

      // Debug: Log auth event for troubleshooting 401 errors
      Log.info(
        '🔐 Auth event JSON (first 200 chars): ${authEventJson.substring(0, authEventJson.length > 200 ? 200 : authEventJson.length)}...',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '🔐 Auth header length: ${authHeader.length} chars',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Add ProofMode headers if manifest is provided
      final headers = <String, dynamic>{
        'Authorization': authHeader,
        'Content-Type': 'video/mp4',
        'Content-Length': fileSize.toString(),
      };

      if (proofManifestJson != null && proofManifestJson.isNotEmpty) {
        _addProofModeHeaders(headers, proofManifestJson);
      }

      Log.info(
        'Sending PUT request with raw bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  URL: $serverUrl/upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  File size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // PUT request with raw bytes (Blossom BUD-01 spec)
      final response = await dio.put(
        '$serverUrl/upload',
        data: fileBytes,
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            // Progress from 20% to 90% during upload
            final progress = 0.2 + (sent / total) * 0.7;
            onProgress?.call(progress);
          }
        },
      );

      Log.info(
        'Blossom server response: ${response.statusCode}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        'Response data: ${response.data}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Handle successful responses
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        if (responseData is Map) {
          // Log FULL response to understand what server returns
          Log.info(
            '==========================================',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          Log.info(
            'BLOSSOM SERVER RESPONSE FIELDS:',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          for (final key in responseData.keys) {
            Log.info(
              '  $key: ${responseData[key]}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
          }
          Log.info(
            '==========================================',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );

          // Extract all URL fields from server response
          final url = responseData['url']?.toString();
          final fallbackUrl = responseData['fallbackUrl']?.toString();

          // Extract streaming info if present
          String? streamingMp4Url;
          String? streamingHlsUrl;
          String? thumbnailUrl;
          String? streamingStatus;

          final streamingData = responseData['streaming'];
          if (streamingData is Map) {
            streamingMp4Url = streamingData['mp4Url']?.toString();
            streamingHlsUrl = streamingData['hlsUrl']?.toString();
            thumbnailUrl = streamingData['thumbnailUrl']?.toString();
            streamingStatus = streamingData['status']?.toString();
          }

          if (url != null && url.isNotEmpty) {
            onProgress?.call(1.0);

            Log.info(
              '✅ Blossom upload successful',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Primary URL (HLS): $url',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Fallback URL (R2 MP4): $fallbackUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Streaming MP4: $streamingMp4Url',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Thumbnail: $thumbnailUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Status: $streamingStatus',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Video ID (hash): $fileHash',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            return BlossomUploadResult(
              success: true,
              url: url,
              fallbackUrl: fallbackUrl,
              streamingMp4Url: streamingMp4Url,
              streamingHlsUrl: streamingHlsUrl,
              thumbnailUrl: thumbnailUrl,
              streamingStatus: streamingStatus,
              videoId: fileHash,
            );
          }
        }

        // Response didn't have expected URL
        Log.error(
          '❌ Response missing URL field: $responseData',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Upload response missing URL field',
        );
      }

      // Handle 409 Conflict - file already exists
      if (response.statusCode == 409) {
        final existingUrl = 'https://cdn.divine.video/$fileHash.mp4';
        Log.info(
          '✅ File already exists on server: $existingUrl',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );

        onProgress?.call(1.0);

        return BlossomUploadResult(
          success: true,
          fallbackUrl: existingUrl, // Use fallbackUrl for R2 MP4
          videoId: fileHash,
        );
      }

      // Handle other error responses
      // Extract X-Reason header for detailed error info (BUD-01 spec)
      final xReason =
          response.headers.value('X-Reason') ??
          response.headers.value('x-reason');
      Log.error(
        '❌ Upload failed: ${response.statusCode} - ${response.data}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      if (xReason != null) {
        Log.error(
          '❌ X-Reason header: $xReason',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
      }
      return BlossomUploadResult(
        success: false,
        errorMessage:
            'Upload failed: ${response.statusCode} - ${xReason ?? response.data}',
      );
    } on DioException catch (e) {
      Log.error(
        'Blossom upload network error: ${e.message}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      if (e.type == DioExceptionType.connectionTimeout) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Connection timeout - check server URL',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Cannot connect to Blossom server',
        );
      } else {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Network error: ${e.message}',
        );
      }
    } catch (e) {
      Log.error(
        'Blossom upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return BlossomUploadResult(
        success: false,
        errorMessage: 'Blossom upload failed: $e',
      );
    } finally {
      // Stop performance trace
      await PerformanceMonitoringService.instance.stopTrace('video_upload');
    }
  }

  /// Upload an image file (e.g. thumbnail) to the configured Blossom server
  ///
  /// This uses the same Blossom BUD-01 protocol as video uploads but with image MIME type
  Future<BlossomUploadResult> uploadImage({
    required File imageFile,
    required String nostrPubkey,
    String mimeType = 'image/jpeg',
    void Function(double)? onProgress,
  }) async {
    try {
      // Determine which server to use
      final isCustomServerEnabled = await isBlossomEnabled();
      String serverUrl;

      if (isCustomServerEnabled) {
        final customServerUrl = await getBlossomServer();
        if (customServerUrl == null || customServerUrl.isEmpty) {
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Custom Blossom server enabled but not configured',
          );
        }
        serverUrl = customServerUrl;
      } else {
        serverUrl = 'https://blossom.divine.video';
      }

      // Parse and validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL',
        );
      }

      // Check authentication
      if (!authService.isAuthenticated) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }

      Log.info(
        'Uploading image to Blossom server: $serverUrl',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Report initial progress
      onProgress?.call(0.1);

      // Calculate file hash for Blossom
      final fileBytes = await imageFile.readAsBytes();
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;

      Log.info(
        'Image file hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Create Blossom auth event
      final authEvent = await _createBlossomAuthEvent(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
      );

      if (authEvent == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
        );
      }

      // Prepare authorization header (BUD-01/NIP-98 requires standard base64 encoding)
      final authEventJson = jsonEncode(authEvent.toJson());
      final authHeader = 'Nostr ${base64.encode(utf8.encode(authEventJson))}';

      Log.info(
        '📤 Blossom Image Upload: PUT with raw bytes to $serverUrl/upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Blossom BUD-01 spec: PUT with raw bytes
      final response = await dio.put(
        '$serverUrl/upload',
        data: fileBytes,
        options: Options(
          headers: {'Authorization': authHeader, 'Content-Type': mimeType},
          validateStatus: (status) => status != null && status < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = 0.1 + (sent / total) * 0.8;
            onProgress?.call(progress);
          }
        },
      );

      Log.info(
        'Response status: ${response.statusCode}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Handle HTTP 409 Conflict - file already exists
      if (response.statusCode == 409) {
        Log.info(
          '✅ Image already exists on server (hash: $fileHash)',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );

        // Add appropriate file extension based on MIME type
        final extension = _getFileExtensionFromMimeType(mimeType);
        final existingUrl = 'https://cdn.divine.video/$fileHash$extension';
        onProgress?.call(1.0);

        return BlossomUploadResult(
          success: true,
          videoId: fileHash,
          fallbackUrl: existingUrl,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        Log.info(
          '✅ Image upload successful',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        onProgress?.call(0.95);

        // Parse Blossom BUD-01 response: {sha256, url, size, type}
        final blobData = response.data;

        if (blobData is Map) {
          final sha256 = blobData['sha256'] as String?;
          final mediaUrl = blobData['url'] as String?;

          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            final imageId = sha256 ?? fileHash;

            // WORKAROUND for Blossom server bug: Server returns .mp4 extension for images
            // Fix the file extension based on the MIME type we sent
            String correctedUrl = mediaUrl;
            if (mediaUrl.endsWith('.mp4')) {
              // Map MIME type to correct file extension
              final extension = _getImageExtensionFromMimeType(mimeType);
              correctedUrl = mediaUrl.replaceAll(
                RegExp(r'\.mp4$'),
                '.$extension',
              );
              Log.debug(
                'Fixed server extension: .mp4 → .$extension for MIME type: $mimeType',
                name: 'BlossomUploadService',
                category: LogCategory.video,
              );
            }

            onProgress?.call(1.0);

            Log.info(
              '  URL: $correctedUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  SHA256: $sha256',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            return BlossomUploadResult(
              success: true,
              fallbackUrl: correctedUrl,
              videoId: imageId,
            );
          } else {
            return BlossomUploadResult(
              success: false,
              errorMessage: 'Invalid Blossom response: missing URL field',
            );
          }
        } else {
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Invalid Blossom response format',
          );
        }
      } else if (response.statusCode == 401) {
        Log.error(
          '❌ Authentication failed: ${response.data}',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Authentication failed',
        );
      } else {
        Log.error(
          '❌ Image upload failed: ${response.statusCode}',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Image upload failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      Log.error(
        'Image upload exception: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Image upload failed: $e',
      );
    }
  }

  /// Get file extension from MIME type
  String _getFileExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'video/mp4':
        return '.mp4';
      case 'video/webm':
        return '.webm';
      default:
        // Default to no extension for unknown types
        return '';
    }
  }

  /// Upload a bug report file (text/plain) to the configured Blossom server
  ///
  /// Returns the URL to the uploaded bug report file
  Future<String?> uploadBugReport({
    required File bugReportFile,
    void Function(double)? onProgress,
  }) async {
    try {
      // Determine which server to use
      final isCustomServerEnabled = await isBlossomEnabled();
      String serverUrl;

      if (isCustomServerEnabled) {
        final customServerUrl = await getBlossomServer();
        if (customServerUrl == null || customServerUrl.isEmpty) {
          Log.error(
            'Custom Blossom server enabled but not configured',
            name: 'BlossomUploadService',
            category: LogCategory.system,
          );
          return null;
        }
        serverUrl = customServerUrl;
      } else {
        serverUrl = 'https://blossom.divine.video';
      }

      // Parse and validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        Log.error(
          'Invalid Blossom server URL: $serverUrl',
          name: 'BlossomUploadService',
          category: LogCategory.system,
        );
        return null;
      }

      // Check authentication
      if (!authService.isAuthenticated) {
        Log.error(
          'Not authenticated - cannot upload bug report',
          name: 'BlossomUploadService',
          category: LogCategory.system,
        );
        return null;
      }

      Log.info(
        'Uploading bug report to Blossom server: $serverUrl',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      // Report initial progress
      onProgress?.call(0.1);

      // Calculate file hash and size
      final fileBytes = await bugReportFile.readAsBytes();
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;

      Log.info(
        'Bug report file hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      onProgress?.call(0.2);

      // Create Blossom auth event (kind 24242)
      final authEvent = await _createBlossomAuthEvent(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
        contentDescription: 'Upload bug report to Blossom server',
      );

      if (authEvent == null) {
        Log.error(
          'Failed to create Blossom authentication',
          name: 'BlossomUploadService',
          category: LogCategory.system,
        );
        return null;
      }

      // Prepare headers following Blossom spec (BUD-01 requires standard base64 encoding)
      final authEventJson = jsonEncode(authEvent.toJson());
      final authHeader = 'Nostr ${base64.encode(utf8.encode(authEventJson))}';

      final headers = <String, dynamic>{
        'Authorization': authHeader,
        'Content-Type': 'text/plain', // Bug reports are plain text
      };

      Log.info(
        'Sending PUT request for bug report',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );
      Log.info(
        '  URL: $serverUrl/upload',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );
      Log.info(
        '  File size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      // PUT request with raw bytes (BUD-01 spec requires PUT for uploads)
      final response = await dio.put(
        '$serverUrl/upload',
        data: fileBytes,
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            // Progress from 20% to 90% during upload
            final progress = 0.2 + (sent / total) * 0.7;
            onProgress?.call(progress);
          }
        },
      );

      Log.info(
        'Blossom server response: ${response.statusCode}',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );
      Log.info(
        'Response data: ${response.data}',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      // Handle successful responses
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        if (responseData is Map) {
          final urlRaw = responseData['url'];
          final cdnUrl = urlRaw?.toString();

          if (cdnUrl != null && cdnUrl.isNotEmpty) {
            onProgress?.call(1.0);

            Log.info(
              '✅ Bug report upload successful',
              name: 'BlossomUploadService',
              category: LogCategory.system,
            );
            Log.info(
              '  URL: $cdnUrl',
              name: 'BlossomUploadService',
              category: LogCategory.system,
            );

            return cdnUrl;
          }
        }

        // Response didn't have expected URL
        Log.error(
          '❌ Response missing URL field: $responseData',
          name: 'BlossomUploadService',
          category: LogCategory.system,
        );
        return null;
      }

      // Handle 409 Conflict - file already exists (construct URL from hash)
      if (response.statusCode == 409) {
        // Blossom servers return the file via hash, construct URL
        // Format varies by server, but typically: https://server/$hash or https://cdn.server/$hash.txt
        final existingUrl = '$serverUrl/$fileHash.txt';
        Log.info(
          '✅ Bug report already exists on server: $existingUrl',
          name: 'BlossomUploadService',
          category: LogCategory.system,
        );

        onProgress?.call(1.0);
        return existingUrl;
      }

      // Handle other error responses
      Log.error(
        '❌ Bug report upload failed: ${response.statusCode} - ${response.data}',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );
      return null;
    } on DioException catch (e) {
      Log.error(
        'Bug report upload network error: ${e.message}',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );
      return null;
    } catch (e) {
      Log.error(
        'Bug report upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Add ProofMode headers to upload request
  ///
  /// Generates X-ProofMode-Manifest, X-ProofMode-Signature, and X-ProofMode-Attestation
  /// headers from the provided ProofManifest JSON.
  void _addProofModeHeaders(
    Map<String, dynamic> headers,
    String proofManifestJson,
  ) {
    try {
      final manifestMap = jsonDecode(proofManifestJson) as Map<String, dynamic>;

      // Base64 encode the full manifest
      headers['X-ProofMode-Manifest'] = base64.encode(
        utf8.encode(proofManifestJson),
      );

      // Extract and encode signature if present
      if (manifestMap['pgpSignature'] != null) {
        final signature = manifestMap['pgpSignature'] as Map<String, dynamic>;
        final signatureJson = jsonEncode(signature);
        headers['X-ProofMode-Signature'] = base64.encode(
          utf8.encode(signatureJson),
        );
      }

      // Extract and encode attestation if present
      if (manifestMap['deviceAttestation'] != null) {
        final attestation =
            manifestMap['deviceAttestation'] as Map<String, dynamic>;
        final attestationJson = jsonEncode(attestation);
        headers['X-ProofMode-Attestation'] = base64.encode(
          utf8.encode(attestationJson),
        );
      }

      Log.info(
        'Added ProofMode headers to upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        'Failed to add ProofMode headers: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      // Don't fail the upload if ProofMode headers can't be added
    }
  }

  /// Map MIME types to file extensions for image uploads
  /// WORKAROUND: Blossom server returns .mp4 for all uploads, we need to fix it client-side
  String _getImageExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/svg+xml':
        return 'svg';
      case 'image/bmp':
        return 'bmp';
      default:
        // Default to jpg if unknown MIME type
        Log.debug(
          'Unknown image MIME type: $mimeType, defaulting to jpg',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return 'jpg';
    }
  }
}
