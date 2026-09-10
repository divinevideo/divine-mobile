// ABOUTME: Screen for importing existing Nostr private keys (nsec or hex format)
// ABOUTME: Also supports NIP-46 bunker URLs for remote signing
// ABOUTME: Validates keys and imports them securely for existing Nostr users

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:unified_logger/unified_logger.dart';

class KeyImportScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'import-key';

  /// Path for this route.
  static const String path = RoutePaths.keyImport;

  const KeyImportScreen({super.key});

  @override
  ConsumerState<KeyImportScreen> createState() => _KeyImportScreenState();
}

class _KeyImportScreenState extends ConsumerState<KeyImportScreen> {
  final _keyController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isImporting = false;
  bool _isEncryptedKey = false;
  String? _keyError;
  String? _passwordError;

  /// Cached reference to auth service, since ref is invalid after unmount.
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _passwordController.dispose();

    // Clear any authentication errors when leaving this screen.
    // Uses cached reference because Riverpod ref is invalid after unmount.
    _authService.clearError();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 110,
                  children: [
                    // Scrollable form content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Back button
                        AuthBackButton(enabled: !_isImporting),

                        const SizedBox(height: 32),

                        // Title
                        Text(
                          context.l10n.keyImportTitle,
                          style: VineTheme.headlineLargeFont(
                            color: context.vineColors.primaryText,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtitle
                        Text(
                          context.l10n.keyImportSubtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.vineColors.secondaryText,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Key input field
                        DivineAuthTextField(
                          controller: _keyController,
                          label: context.l10n.keyImportKeyFieldLabel,
                          enabled: !_isImporting,
                          autocorrect: false,
                          errorText: _keyError,
                          onChanged: (value) {
                            final encrypted = Nip49.isEncryptedKey(
                              value.trim(),
                            );
                            setState(() {
                              _keyError = null;
                              _isEncryptedKey = encrypted;
                              if (!encrypted) _passwordError = null;
                            });
                          },
                        ),

                        if (_isEncryptedKey) ...[
                          const SizedBox(height: 16),
                          DivineAuthTextField(
                            controller: _passwordController,
                            label: context.l10n.authPasswordLabel,
                            enabled: !_isImporting,
                            autocorrect: false,
                            obscureText: true,
                            errorText: _passwordError,
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                            showPasswordSemanticLabel:
                                context.l10n.authShowPassword,
                            hidePasswordSemanticLabel:
                                context.l10n.authHidePassword,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Import button
                        DivineButton(
                          expanded: true,
                          label: context.l10n.authImportNostrKey,
                          isLoading: _isImporting,
                          onPressed: _importKey,
                        ),
                      ],
                    ),

                    // Pinned security warning with key overlay
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const _SecurityWarning(),
                        Positioned(
                          right: -60,
                          top: -130,
                          child: Transform.rotate(
                            angle: 12 * 3.1415926535 / 180,
                            child: const DivineSticker(
                              sticker: DivineStickerName.skeletonKey,
                              size: 174,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validateKey(String value) {
    if (value.trim().isEmpty) {
      return context.l10n.keyImportKeyRequired;
    }

    final trimmed = value.trim();

    // Check if it's a bunker URL
    if (NostrRemoteSignerInfo.isBunkerUrl(trimmed)) {
      try {
        NostrRemoteSignerInfo.parseBunkerUrl(trimmed);
      } on InvalidBunkerRelayException {
        // Specifically flag the security-relevant rejection (#3362) so the
        // user understands why a ws:// non-loopback relay was refused.
        return context.l10n.keyImportInsecureBunkerRelay;
      } catch (_) {
        return context.l10n.keyImportInvalidBunkerUrl;
      }
      return null;
    }

    // ncryptsec1: encrypted private key (NIP-49) — password validated separately
    if (Nip49.isEncryptedKey(trimmed)) {
      return null;
    }

    // Check if it looks like a valid key format
    if (!trimmed.startsWith('nsec') && trimmed.length != 64) {
      return context.l10n.keyImportInvalidFormat;
    }

    if (trimmed.startsWith('nsec') && trimmed.length != 63) {
      return context.l10n.keyImportInvalidNsecFormat;
    }

    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) {
      return context.l10n.keyImportPasswordRequired;
    }
    return null;
  }

  Future<void> _importKey() async {
    final keyError = _validateKey(_keyController.text);
    if (keyError != null) {
      setState(() => _keyError = keyError);
      return;
    }

    final keyText = _keyController.text.trim();

    if (Nip49.isEncryptedKey(keyText)) {
      final passwordError = _validatePassword(_passwordController.text);
      if (passwordError != null) {
        setState(() => _passwordError = passwordError);
        return;
      }
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final AuthResult result;

      if (NostrRemoteSignerInfo.isBunkerUrl(keyText)) {
        // Handle bunker URL (NIP-46 remote signing)
        result = await authService.connectWithBunker(keyText);
      } else if (Nip49.isEncryptedKey(keyText)) {
        // Handle NIP-49 password-encrypted key
        result = await authService.importFromNcryptsec(
          keyText,
          _passwordController.text,
        );
      } else if (keyText.startsWith('nsec')) {
        result = await authService.importFromNsec(keyText);
      } else {
        result = await authService.importFromHex(keyText);
      }

      if (result.success && mounted) {
        // Clear the text fields for security
        _keyController.clear();
        _passwordController.clear();

        // Start fetching the user's profile from relays in background
        // This ensures profile data is available when user navigates
        // to profile
        final pubkeyHex = authService.currentPublicKeyHex;
        if (pubkeyHex != null) {
          unawaited(
            ref
                    .read(profileRepositoryProvider)
                    ?.fetchFreshProfile(pubkey: pubkeyHex) ??
                Future<void>.value(),
          );
          Log.info(
            'Started background fetch for imported user profile',
            name: 'KeyImportScreen',
            category: LogCategory.auth,
          );
        }
      } else if (mounted &&
          result.failureReason == AuthFailureReason.incorrectPassword) {
        setState(() {
          _passwordError = context.l10n.keyManagementKeycastWrongPassword;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.keyImportFailedToImport),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Key import failed: $e',
        name: 'KeyImportScreen',
        category: LogCategory.ui,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.keyImportFailedToImport),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}

/// Security warning box about private key safety.
class _SecurityWarning extends StatelessWidget {
  const _SecurityWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.accentOrangeBackground),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 8,
            children: [
              const DivineIcon(
                icon: .warning,
                size: 20,
                color: VineTheme.accentOrange,
              ),
              Expanded(
                child: Text(
                  context.l10n.keyImportSecurityWarningTitle,
                  style: const TextStyle(
                    color: VineTheme.accentOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.keyImportSecurityWarningBody,
            style: const TextStyle(
              color: VineTheme.accentOrange,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
