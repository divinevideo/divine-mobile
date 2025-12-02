// ABOUTME: Robust initialization helper with retry logic and failure recovery
// ABOUTME: Handles transient failures, corrupted storage, and provides exponential backoff

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Robust initialization helper for UploadManager
class UploadInitializationHelper {
  static const String _uploadsBoxName = 'pending_uploads';
  static const int _maxRetries =
      3; // Reduced from 5 since we fail fast on permanent errors
  static const Duration _baseDelay = Duration(milliseconds: 250);
  static const Duration _maxDelay = Duration(seconds: 5); // Reduced from 30s

  // Track initialization state
  static bool _isInitializing = false;
  static int _failureCount = 0;
  static DateTime? _lastFailureTime;
  static Box<PendingUpload>? _cachedBox;

  /// Get app-specific storage directory (sandboxed, always writable)
  /// On web, returns null since IndexedDB is used directly
  static Future<Directory?> _getAppStorageDir() async {
    if (kIsWeb) {
      // Web uses IndexedDB, no filesystem path needed
      return null;
    }

    final base = await getApplicationSupportDirectory();
    final appDir = Directory(p.join(base.path, 'openvine'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Check if error is a permanent permission error (don't retry these)
  static bool _isPermanentPermissionError(dynamic error) {
    if (kIsWeb) {
      // Web doesn't have FileSystemException
      return false;
    }

    // Use dynamic type checking since FileSystemException isn't available on web
    if (error.runtimeType.toString() != 'FileSystemException') return false;

    try {
      final code = (error as dynamic).osError?.errorCode;
      // macOS/iOS: EPERM=1, EACCES=13
      // These are permanent - no amount of retrying will help
      return code == 1 || code == 13;
    } catch (_) {
      return false;
    }
  }

  /// Robustly initialize the uploads box with retry logic
  static Future<Box<PendingUpload>> initializeUploadsBox({
    bool forceReinit = false,
  }) async {
    // Return cached box if available and not forcing reinit
    if (_cachedBox != null && _cachedBox!.isOpen && !forceReinit) {
      Log.debug(
        'Using cached uploads box',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
      return _cachedBox!;
    }

    // Prevent concurrent initialization attempts
    if (_isInitializing) {
      Log.info(
        'Waiting for ongoing initialization...',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
      return _waitForInitialization();
    }

    _isInitializing = true;

    try {
      // Check if we should apply circuit breaker
      if (_shouldApplyCircuitBreaker()) {
        throw Exception('Circuit breaker active - too many recent failures');
      }

      // Attempt initialization with retries
      final box = await _initializeWithRetries();

      // Success - reset failure tracking
      _failureCount = 0;
      _lastFailureTime = null;
      _cachedBox = box;

      Log.info(
        '✅ Uploads box initialized successfully',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );

      return box;
    } catch (e) {
      _failureCount++;
      _lastFailureTime = DateTime.now();

      Log.error(
        '❌ Failed to initialize uploads box after all retries: $e',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );

      // Try recovery strategies
      final recoveredBox = await _attemptRecovery();
      if (recoveredBox != null) {
        _cachedBox = recoveredBox;
        return recoveredBox;
      }

      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Initialize with exponential backoff retry
  static Future<Box<PendingUpload>> _initializeWithRetries() async {
    Exception? lastError;

    // Initialize Hive with proper app container directory FIRST
    // Skip on web since it uses IndexedDB
    if (!kIsWeb) {
      try {
        final storageDir = await _getAppStorageDir();
        if (storageDir != null) {
          Hive.init(storageDir.path);
          Log.info(
            'Hive initialized with app storage: ${storageDir.path}',
            name: 'UploadInitHelper',
            category: LogCategory.video,
          );
        }
      } catch (e) {
        Log.error(
          'Failed to get app storage directory: $e',
          name: 'UploadInitHelper',
          category: LogCategory.video,
        );
        throw Exception('Cannot access app storage directory: $e');
      }
    } else {
      Log.info(
        'Web platform detected - using IndexedDB for storage',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
    }

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        Log.info(
          'Initialization attempt ${attempt + 1}/${_maxRetries + 1}',
          name: 'UploadInitHelper',
          category: LogCategory.video,
        );

        // Register adapters if needed
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(UploadStatusAdapter());
        }
        if (!Hive.isAdapterRegistered(2)) {
          Hive.registerAdapter(PendingUploadAdapter());
        }

        // Try to open the box
        Box<PendingUpload>? box;

        // First try: normal open
        try {
          box = await Hive.openBox<PendingUpload>(
            _uploadsBoxName,
          ).timeout(const Duration(seconds: 10));
        } catch (e) {
          // Check for permanent permission errors FIRST
          if (_isPermanentPermissionError(e)) {
            Log.error(
              '❌ Permanent permission error - cannot retry: $e',
              name: 'UploadInitHelper',
              category: LogCategory.video,
            );
            throw Exception(
              'Permission denied: Cannot access storage. '
              'This is a permanent error that cannot be fixed by retrying.',
            );
          }

          Log.warning(
            'Normal open failed: $e, trying recovery...',
            name: 'UploadInitHelper',
            category: LogCategory.video,
          );

          // Second try: delete and recreate if corrupted
          if (e.toString().contains('corrupted') ||
              e.toString().contains('Invalid') ||
              e.toString().contains('format')) {
            await _deleteCorruptedBox();
            box = await Hive.openBox<PendingUpload>(_uploadsBoxName);
          } else {
            rethrow;
          }
        }

        if (!box.isOpen) {
          throw Exception('Box opened but is not open');
        }

        // Verify box is functional
        await _verifyBoxFunctionality(box);

        return box;
      } catch (e) {
        // Check for permanent errors - don't retry these
        if (_isPermanentPermissionError(e)) {
          Log.error(
            '❌ Permanent permission error detected - failing immediately',
            name: 'UploadInitHelper',
            category: LogCategory.video,
          );
          throw Exception('Permanent permission error: $e');
        }

        lastError = e as Exception;

        if (attempt < _maxRetries) {
          final delay = _calculateBackoffDelay(attempt);
          Log.warning(
            'Attempt ${attempt + 1} failed: $e. Retrying in ${delay.inMilliseconds}ms...',
            name: 'UploadInitHelper',
            category: LogCategory.video,
          );
          await Future.delayed(delay);
        }
      }
    }

    throw lastError ??
        Exception('Failed to initialize after ${_maxRetries + 1} attempts');
  }

  /// Calculate exponential backoff delay
  static Duration _calculateBackoffDelay(int attempt) {
    final exponentialDelay = _baseDelay * pow(2, attempt);
    final jitteredDelay =
        exponentialDelay * (0.5 + Random().nextDouble() * 0.5);

    return jitteredDelay < _maxDelay ? jitteredDelay : _maxDelay;
  }

  /// Check if circuit breaker should be applied
  static bool _shouldApplyCircuitBreaker() {
    if (_failureCount < 10) return false;
    if (_lastFailureTime == null) return false;

    // Apply circuit breaker for 5 minutes after 10 failures
    final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
    return timeSinceLastFailure.inMinutes < 5;
  }

  /// Wait for ongoing initialization
  static Future<Box<PendingUpload>> _waitForInitialization() async {
    // Use proper async waiting instead of polling with Future.delayed
    final success = await AsyncUtils.waitForCondition(
      condition: () =>
          !_isInitializing && _cachedBox != null && _cachedBox!.isOpen,
      timeout: const Duration(seconds: 30),
      checkInterval: const Duration(milliseconds: 100),
      debugName: 'upload_box_initialization',
    );

    if (!success || _cachedBox == null || !_cachedBox!.isOpen) {
      throw Exception('Initialization completed but box not available');
    }

    return _cachedBox!;
  }

  /// Attempt recovery strategies
  static Future<Box<PendingUpload>?> _attemptRecovery() async {
    Log.warning(
      'Attempting recovery strategies...',
      name: 'UploadInitHelper',
      category: LogCategory.video,
    );

    // Strategy 1: Try to use existing box if it's somehow still open
    try {
      if (Hive.isBoxOpen(_uploadsBoxName)) {
        final box = Hive.box<PendingUpload>(_uploadsBoxName);
        if (await _verifyBoxFunctionality(box)) {
          Log.info(
            'Recovery successful - using existing open box',
            name: 'UploadInitHelper',
            category: LogCategory.video,
          );
          return box;
        }
      }
    } catch (e) {
      Log.debug(
        'Existing box recovery failed: $e',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
    }

    // Strategy 2: Delete corrupted box and start fresh
    try {
      await _deleteCorruptedBox();
      final box = await Hive.openBox<PendingUpload>(_uploadsBoxName);

      if (await _verifyBoxFunctionality(box)) {
        Log.info(
          'Recovery successful - created fresh box',
          name: 'UploadInitHelper',
          category: LogCategory.video,
        );
        return box;
      }
    } catch (e) {
      Log.error(
        'Fresh box recovery failed: $e',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
    }

    // Strategy 3: Use in-memory box as last resort
    try {
      Log.warning(
        'Using in-memory box as last resort',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );

      // Note: This would need a custom in-memory box implementation
      // For now, we'll return null to indicate failure
      return null;
    } catch (e) {
      Log.error(
        'In-memory box creation failed: $e',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
    }

    return null;
  }

  /// Delete corrupted box files
  static Future<void> _deleteCorruptedBox() async {
    try {
      await Hive.deleteBoxFromDisk(_uploadsBoxName);
      Log.warning(
        'Deleted corrupted uploads box',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        'Failed to delete corrupted box: $e',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
    }
  }

  /// Verify box is functional
  static Future<bool> _verifyBoxFunctionality(Box<PendingUpload> box) async {
    try {
      // Try to read length
      final _ = box.length;

      // Try to read all keys
      box.keys.toList(); // Test key access

      // Try a write/read/delete operation with a test key
      const testKey = '__test_functionality__';
      final testUpload = PendingUpload.create(
        localVideoPath: '/test/path',
        nostrPubkey: 'test_pubkey',
      );

      await box.put(testKey, testUpload);
      final retrieved = box.get(testKey);
      await box.delete(testKey);

      return retrieved != null;
    } catch (e) {
      Log.error(
        'Box functionality verification failed: $e',
        name: 'UploadInitHelper',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Reset all state (useful for testing)
  static void reset() {
    _isInitializing = false;
    _failureCount = 0;
    _lastFailureTime = null;
    _cachedBox = null;
  }

  /// Get current state for debugging
  static Map<String, dynamic> getDebugState() {
    return {
      'isInitializing': _isInitializing,
      'failureCount': _failureCount,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'hasCachedBox': _cachedBox != null,
      'cachedBoxOpen': _cachedBox?.isOpen ?? false,
      'circuitBreakerActive': _shouldApplyCircuitBreaker(),
    };
  }
}
