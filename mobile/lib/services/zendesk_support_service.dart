// ABOUTME: Flutter platform channel wrapper for Zendesk Support SDK
// ABOUTME: Provides ticket creation and support features via native iOS/Android SDKs

import 'package:flutter/services.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for interacting with Zendesk Support SDK
class ZendeskSupportService {
  static const MethodChannel _channel = MethodChannel(
    'com.openvine/zendesk_support',
  );

  static bool _initialized = false;

  /// Check if Zendesk is available (credentials configured and initialized)
  static bool get isAvailable => _initialized;

  /// Initialize Zendesk SDK
  ///
  /// Call once at app startup. Returns true if initialization successful.
  /// Returns false if credentials missing or initialization fails.
  /// App continues to work with email fallback when returns false.
  static Future<bool> initialize({
    required String appId,
    required String clientId,
    required String zendeskUrl,
  }) async {
    // Skip if credentials missing
    if (appId.isEmpty || clientId.isEmpty || zendeskUrl.isEmpty) {
      Log.info(
        'Zendesk credentials not configured - bug reports will use email fallback',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final result = await _channel.invokeMethod('initialize', {
        'appId': appId,
        'clientId': clientId,
        'zendeskUrl': zendeskUrl,
      });

      _initialized = (result == true);

      if (_initialized) {
        Log.info(
          '✅ Zendesk initialized successfully',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Zendesk initialization failed - bug reports will use email fallback',
          category: LogCategory.system,
        );
      }

      return _initialized;
    } on PlatformException catch (e) {
      Log.error(
        'Zendesk initialization failed: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      _initialized = false;
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error initializing Zendesk: $e',
        category: LogCategory.system,
      );
      _initialized = false;
      return false;
    }
  }

  /// Show native Zendesk ticket creation screen
  ///
  /// Presents the native Zendesk UI for creating a support ticket.
  /// Returns true if screen shown, false if Zendesk not initialized.
  static Future<bool> showNewTicketScreen({
    String? subject,
    String? description,
    List<String>? tags,
  }) async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket screen',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      await _channel.invokeMethod('showNewTicket', {
        'subject': subject,
        'description': description,
        'tags': tags,
      });

      Log.info('Zendesk ticket screen shown', category: LogCategory.system);
      return true;
    } on PlatformException catch (e) {
      Log.error(
        'Failed to show Zendesk ticket screen: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error showing Zendesk screen: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Show user's ticket list (support history)
  ///
  /// Presents the native Zendesk UI showing all tickets from this user.
  /// Returns true if screen shown, false if Zendesk not initialized.
  static Future<bool> showTicketListScreen() async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket list',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      await _channel.invokeMethod('showTicketList');
      Log.info('Zendesk ticket list shown', category: LogCategory.system);
      return true;
    } on PlatformException catch (e) {
      Log.error(
        'Failed to show Zendesk ticket list: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error showing ticket list: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Create a Zendesk ticket programmatically (no UI)
  ///
  /// Creates a support ticket silently in the background without showing any UI.
  /// Useful for automatic content reporting or system-generated tickets.
  /// Returns true if ticket created successfully, false otherwise.
  ///
  /// Platform limitations:
  /// - iOS: Full support via RequestProvider API
  /// - Android: Full support via RequestProvider API
  /// - macOS/Windows: Not supported (returns false)
  static Future<bool> createTicket({
    required String subject,
    required String description,
    List<String>? tags,
  }) async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot create ticket',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final result = await _channel.invokeMethod('createTicket', {
        'subject': subject,
        'description': description,
        'tags': tags ?? [],
      });

      if (result == true) {
        Log.info(
          'Zendesk ticket created successfully: $subject',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.warning(
          'Failed to create Zendesk ticket: $subject',
          category: LogCategory.system,
        );
        return false;
      }
    } on PlatformException catch (e) {
      Log.error(
        'Platform error creating Zendesk ticket: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error creating Zendesk ticket: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Show ticket list (user's support request history)
  ///
  /// Opens the Zendesk ticket list UI showing the user's past support tickets
  /// and allowing them to view responses and continue conversations.
  /// Returns true if ticket list shown successfully, false otherwise.
  static Future<bool> showTicketList() async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket list',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final result = await _channel.invokeMethod('showTicketList');

      if (result == true) {
        Log.info(
          'Zendesk ticket list shown successfully',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.warning(
          'Failed to show Zendesk ticket list',
          category: LogCategory.system,
        );
        return false;
      }
    } on PlatformException catch (e) {
      Log.error(
        'Platform error showing Zendesk ticket list: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error showing Zendesk ticket list: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }
}
