// ABOUTME: Authentication service managing user login, key generation, and auth state
// ABOUTME: Handles Nostr identity creation, import, and session management with secure storage

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer, SecureKeyStorage;
import 'package:openvine/services/user_profile_service.dart' as ups;
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/nostr_timestamp.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication state for the user
enum AuthState {
  /// User is not authenticated (no keys stored)
  unauthenticated,

  /// User has keys but hasn't accepted Terms of Service yet
  awaitingTosAcceptance,

  /// User is authenticated (has valid keys and accepted TOS)
  authenticated,

  /// Authentication state is being checked
  checking,

  /// Authentication is in progress (generating/importing keys)
  authenticating,
}

/// Result of authentication operations
class AuthResult {
  const AuthResult({
    required this.success,
    this.errorMessage,
    this.keyContainer,
  });

  factory AuthResult.success(SecureKeyContainer keyContainer) =>
      AuthResult(success: true, keyContainer: keyContainer);

  factory AuthResult.failure(String errorMessage) =>
      AuthResult(success: false, errorMessage: errorMessage);
  final bool success;
  final String? errorMessage;
  final SecureKeyContainer? keyContainer;
}

/// User profile information
class UserProfile {
  const UserProfile({
    required this.npub,
    required this.publicKeyHex,
    required this.displayName,
    this.keyCreatedAt,
    this.lastAccessAt,
    this.about,
    this.picture,
    this.nip05,
  });

  /// Create minimal profile from secure key container
  factory UserProfile.fromSecureContainer(SecureKeyContainer keyContainer) =>
      UserProfile(
        npub: keyContainer.npub,
        publicKeyHex: keyContainer.publicKeyHex,
        displayName: NostrKeyUtils.maskKey(keyContainer.npub),
      );
  final String npub;
  final String publicKeyHex;
  final DateTime? keyCreatedAt;
  final DateTime? lastAccessAt;
  final String displayName;
  final String? about;
  final String? picture;
  final String? nip05;
}

/// Main authentication service for the divine app
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class AuthService {
  AuthService({SecureKeyStorage? keyStorage})
    : _keyStorage = keyStorage ?? SecureKeyStorage();
  final SecureKeyStorage _keyStorage;

  AuthState _authState = AuthState.checking;
  SecureKeyContainer? _currentKeyContainer;
  UserProfile? _currentProfile;
  String? _lastError;

  // Streaming controllers for reactive auth state
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final StreamController<UserProfile?> _profileController =
      StreamController<UserProfile?>.broadcast();

  /// Current authentication state
  AuthState get authState => _authState;

  /// Stream of authentication state changes
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Current user profile (null if not authenticated)
  UserProfile? get currentProfile => _currentProfile;

  /// Stream of profile changes
  Stream<UserProfile?> get profileStream => _profileController.stream;

  /// Current public key (npub format)
  String? get currentNpub => _currentKeyContainer?.npub;

  /// Current public key (hex format)
  String? get currentPublicKeyHex => _currentKeyContainer?.publicKeyHex;

  /// Check if user is authenticated
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Last authentication error
  String? get lastError => _lastError;

  /// Initialize the authentication service
  Future<void> initialize() async {
    Log.debug(
      'Initializing SecureAuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Set checking state immediately - we're starting the auth check now
    _setAuthState(AuthState.checking);

    try {
      // Initialize secure key storage
      await _keyStorage.initialize();

      // Check for existing keys
      await _checkExistingAuth();

      Log.info(
        'SecureAuthService initialized',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'SecureAuthService initialization failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to initialize auth: $e';

      // Set state synchronously to prevent loading screen deadlock
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Create a new Nostr identity
  Future<AuthResult> createNewIdentity({String? biometricPrompt}) async {
    Log.debug(
      '📱 Creating new secure Nostr identity',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Generate new secure key container
      final keyContainer = await _keyStorage.generateAndStoreKeys(
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(keyContainer);

      Log.info(
        'New secure identity created successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${NostrKeyUtils.maskKey(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to create secure identity: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to create identity: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Import identity from nsec (bech32 private key)
  Future<AuthResult> importFromNsec(
    String nsec, {
    String? biometricPrompt,
  }) async {
    Log.debug(
      'Importing identity from nsec to secure storage',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Validate nsec format
      if (!NostrKeyUtils.isValidNsec(nsec)) {
        throw Exception('Invalid nsec format');
      }

      // Import keys into secure storage
      final keyContainer = await _keyStorage.importFromNsec(
        nsec,
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(keyContainer);

      Log.info(
        'Identity imported to secure storage successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${NostrKeyUtils.maskKey(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to import identity: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to import identity: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Import identity from hex private key
  Future<AuthResult> importFromHex(
    String privateKeyHex, {
    String? biometricPrompt,
  }) async {
    Log.debug(
      'Importing identity from hex to secure storage',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Validate hex format
      if (!NostrKeyUtils.isValidKey(privateKeyHex)) {
        throw Exception('Invalid private key format');
      }

      // Import keys into secure storage
      final keyContainer = await _keyStorage.importFromHex(
        privateKeyHex,
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(keyContainer);

      Log.info(
        'Identity imported from hex to secure storage successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${NostrKeyUtils.maskKey(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to import from hex: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to import from hex: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Refresh the current user's profile from UserProfileService
  Future<void> refreshCurrentProfile(
    ups.UserProfileService userProfileService,
  ) async {
    if (_currentKeyContainer == null) return;

    Log.debug(
      '🔄 Refreshing current user profile from UserProfileService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Get the latest profile from UserProfileService
    final cachedProfile = userProfileService.getCachedProfile(
      _currentKeyContainer!.publicKeyHex,
    );

    if (cachedProfile != null) {
      Log.info(
        '📋 Found updated profile:',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.info(
        '  - name: ${cachedProfile.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.info(
        '  - displayName: ${cachedProfile.displayName}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.info(
        '  - about: ${cachedProfile.about}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Update the AuthService profile with data from UserProfileService
      _currentProfile = UserProfile(
        npub: _currentKeyContainer!.npub,
        publicKeyHex: _currentKeyContainer!.publicKeyHex,
        displayName:
            cachedProfile.displayName ??
            cachedProfile.name ??
            NostrKeyUtils.maskKey(_currentKeyContainer!.npub),
        about: cachedProfile.about,
        picture: cachedProfile.picture,
        nip05: cachedProfile.nip05,
      );

      // Notify listeners and stream
      _profileController.add(_currentProfile);

      Log.info(
        '✅ AuthService profile updated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } else {
      Log.warning(
        '⚠️ No cached profile found in UserProfileService',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Accept Terms of Service - transitions to authenticated state
  Future<void> acceptTermsOfService() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'terms_accepted_at',
        DateTime.now().toIso8601String(),
      );
      await prefs.setBool('age_verified_16_plus', true);

      // If unauthenticated (e.g., after logout), re-initialize to load existing keys
      if (_authState == AuthState.unauthenticated) {
        await initialize();
        return;
      }

      _setAuthState(AuthState.authenticated);

      Log.info(
        'Terms of Service accepted, user is now fully authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to save TOS acceptance: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to accept terms: $e';
    }
  }

  /// Sign out the current user
  Future<void> signOut({bool deleteKeys = false}) async {
    Log.debug(
      '📱 Signing out user',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      // Clear TOS acceptance on any logout - user must re-accept when logging back in
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('age_verified_16_plus');
      await prefs.remove('terms_accepted_at');

      if (deleteKeys) {
        Log.debug(
          '📱️ Deleting stored keys',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await _keyStorage.deleteKeys();
      } else {
        _keyStorage.clearCache();
      }

      // Clear session
      _currentKeyContainer?.dispose();
      _currentKeyContainer = null;
      _currentProfile = null;
      _lastError = null;

      _setAuthState(AuthState.unauthenticated);

      Log.info(
        'User signed out',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      if (deleteKeys) {
        Log.info(
          'Auto-creating new identity after key deletion',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await _checkExistingAuth();
      }
    } catch (e) {
      Log.error(
        'Error during sign out: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Sign out failed: $e';
    }
  }

  /// Get the private key for signing operations
  Future<String?> getPrivateKeyForSigning({String? biometricPrompt}) async {
    if (!isAuthenticated) return null;

    try {
      return await _keyStorage.withPrivateKey<String?>(
        (privateKeyHex) => privateKeyHex,
        biometricPrompt: biometricPrompt,
      );
    } catch (e) {
      Log.error(
        'Failed to get private key: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Export nsec for backup purposes
  Future<String?> exportNsec({String? biometricPrompt}) async {
    if (!isAuthenticated) return null;

    try {
      Log.warning(
        'Exporting nsec - ensure secure handling',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return await _keyStorage.exportNsec(biometricPrompt: biometricPrompt);
    } catch (e) {
      Log.error(
        'Failed to export nsec: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Create and sign a Nostr event
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    String? biometricPrompt,
  }) async {
    if (!isAuthenticated || _currentKeyContainer == null) {
      Log.error(
        'Cannot sign event - user not authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    try {
      return await _keyStorage.withPrivateKey<Event?>((privateKey) {
        // Create event with current user's public key
        // Use appropriate timestamp backdating based on event kind
        final driftTolerance = NostrTimestamp.getDriftToleranceForKind(kind);

        // CRITICAL: divine relays require specific tags for storage
        final eventTags = List<List<String>>.from(tags ?? []);

        // CRITICAL: Kind 0 events require expiration tag FIRST (matching Python script order)
        if (kind == 0) {
          final expirationTimestamp =
              (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
              (72 * 60 * 60); // 72 hours
          eventTags.add(['expiration', expirationTimestamp.toString()]);
        }

        final event = Event(
          _currentKeyContainer!.publicKeyHex,
          kind,
          eventTags,
          content,
          createdAt: NostrTimestamp.now(driftTolerance: driftTolerance),
        );

        // DEBUG: Log event details before signing
        Log.info(
          '🔍 Event BEFORE signing:',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - ID: ${event.id}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Pubkey: ${event.pubkey}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Kind: ${event.kind}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Created at: ${event.createdAt}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Tags: ${event.tags}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Content: ${event.content}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Signature (before): ${event.sig}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Is valid (before): ${event.isValid}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Is signed (before): ${event.isSigned}',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        // CRITICAL DEBUG: Log the exact JSON array used for ID calculation
        final idCalculationArray = [
          0,
          event.pubkey,
          event.createdAt,
          event.kind,
          event.tags,
          event.content,
        ];
        final idCalculationJson = jsonEncode(idCalculationArray);
        Log.info(
          '📊 CRITICAL: ID calculation JSON array:',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '   Raw Array: $idCalculationArray',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '   JSON: $idCalculationJson',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '   JSON Length: ${idCalculationJson.length} chars',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        // Sign the event
        event.sign(privateKey);

        // DEBUG: Log event details after signing
        Log.info(
          '🔍 Event AFTER signing:',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - ID (should be same): ${event.id}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Signature (after): ${event.sig}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Is valid (after): ${event.isValid}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.info(
          '  - Is signed (after): ${event.isSigned}',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        // CRITICAL: Verify signature is actually valid
        if (!event.isSigned) {
          Log.error(
            '❌ Event signature validation FAILED!',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          Log.error(
            '   This would cause relay to accept but not store the event',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          return null;
        }

        if (!event.isValid) {
          Log.error(
            '❌ Event structure validation FAILED!',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          Log.error(
            '   Event ID does not match computed hash',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          return null;
        }

        Log.info(
          '✅ Event signature and structure validation PASSED',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        return event;
      }, biometricPrompt: biometricPrompt);
    } catch (e) {
      Log.error(
        'Failed to create event: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Check for existing authentication
  Future<void> _checkExistingAuth() async {
    try {
      final hasKeys = await _keyStorage.hasKeys();

      if (hasKeys) {
        Log.info(
          'Found existing secure keys, loading saved identity...',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        final keyContainer = await _keyStorage.getKeyContainer();
        if (keyContainer != null) {
          Log.info(
            'Loaded existing secure identity: ${NostrKeyUtils.maskKey(keyContainer.npub)}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _setupUserSession(keyContainer);
          return;
        } else {
          Log.warning(
            'Has keys flag set but could not load secure key container',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      }

      Log.info(
        'No existing secure keys found, creating new identity automatically...',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Auto-create identity like TikTok - seamless onboarding
      // Note: createNewIdentity() sets state to authenticating immediately, so no need to set it here
      final result = await createNewIdentity();
      if (result.success && result.keyContainer != null) {
        Log.info(
          'Auto-created NEW secure Nostr identity: ${NostrKeyUtils.maskKey(result.keyContainer!.npub)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.debug(
          '📱 This identity is now securely saved and will be reused on next launch',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        Log.error(
          'Failed to auto-create identity: ${result.errorMessage}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Set state synchronously to prevent loading screen deadlock
        _setAuthState(AuthState.unauthenticated);
      }
    } catch (e) {
      Log.error(
        'Error checking existing auth: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Set state synchronously to prevent loading screen deadlock
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Set up user session after successful authentication
  Future<void> _setupUserSession(SecureKeyContainer keyContainer) async {
    _currentKeyContainer = keyContainer;

    // Create user profile from secure container
    _currentProfile = UserProfile(
      npub: keyContainer.npub,
      publicKeyHex: keyContainer.publicKeyHex,
      displayName: NostrKeyUtils.maskKey(keyContainer.npub),
    );

    // Store current user pubkey in SharedPreferences for router redirect checks
    // This allows the router to know which user's following list to check
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'current_user_pubkey_hex',
        keyContainer.publicKeyHex,
      );

      final hasAcceptedTos = prefs.getBool('age_verified_16_plus') ?? false;
      if (hasAcceptedTos) {
        _setAuthState(AuthState.authenticated);
      } else {
        _setAuthState(AuthState.awaitingTosAcceptance);
      }
    } catch (e) {
      Log.warning(
        'Failed to check TOS status: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Default to awaiting TOS if we can't check
      _setAuthState(AuthState.awaitingTosAcceptance);
    }

    _profileController.add(_currentProfile);

    Log.info(
      'Secure user session established',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    Log.verbose(
      'Profile: ${_currentProfile!.displayName}',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    Log.debug(
      '📱 Security: Hardware-backed storage active',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  /// Update authentication state and notify listeners
  void _setAuthState(AuthState newState) {
    if (_authState != newState) {
      _authState = newState;
      _authStateController.add(newState);

      Log.debug(
        'Auth state changed: ${newState.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Get user statistics
  Map<String, dynamic> get userStats => {
    'is_authenticated': isAuthenticated,
    'auth_state': authState.name,
    'npub': currentNpub != null ? NostrKeyUtils.maskKey(currentNpub!) : null,
    'key_created_at': _currentProfile?.keyCreatedAt?.toIso8601String(),
    'last_access_at': _currentProfile?.lastAccessAt?.toIso8601String(),
    'has_error': _lastError != null,
    'last_error': _lastError,
  };

  void dispose() {
    Log.debug(
      '📱️ Disposing SecureAuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Securely dispose of key container
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;

    _authStateController.close();
    _profileController.close();
    _keyStorage.dispose();
  }
}
