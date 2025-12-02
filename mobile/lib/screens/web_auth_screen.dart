// ABOUTME: Web authentication screen supporting NIP-07 and nsec bunker login
// ABOUTME: Provides user-friendly interface for Nostr authentication on web platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

class WebAuthScreen extends ConsumerStatefulWidget {
  const WebAuthScreen({super.key});

  @override
  ConsumerState<WebAuthScreen> createState() => _WebAuthScreenState();
}

class _WebAuthScreenState extends ConsumerState<WebAuthScreen>
    with TickerProviderStateMixin {
  final TextEditingController _bunkerUriController = TextEditingController();
  bool _isAuthenticating = false;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = FadeTransition(
      opacity: _fadeController,
      child: Container(),
    ).opacity;

    _fadeController.forward();

    // Check for existing session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
    });
  }

  @override
  void dispose() {
    _bunkerUriController.dispose();
    _fadeController.dispose();

    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    final webAuth = ref.read(webAuthServiceProvider);
    await webAuth.checkExistingSession();

    if (webAuth.isAuthenticated && mounted) {
      _onAuthenticationSuccess();
    }
  }

  Future<void> _onAuthenticationSuccess() async {
    // Navigate to main app or trigger auth state update
    if (mounted) {
      final webAuth = ref.read(webAuthServiceProvider);

      try {
        // Set the public key in the main auth service to trigger authenticated state
        if (webAuth.publicKey != null) {
          // Web authentication not supported in secure mode
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Web authentication not supported in secure mode. Please use mobile app for secure key management.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        Log.error(
          'Failed to integrate web auth with main auth service: $e',
          name: 'WebAuthScreen',
          category: LogCategory.ui,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Authentication integration failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _authenticateWithNip07() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final webAuth = ref.read(webAuthServiceProvider);
      final result = await webAuth.authenticateWithNip07();

      if (mounted) {
        if (result.success) {
          _onAuthenticationSuccess();
        } else {
          setState(() {
            _errorMessage = result.errorMessage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unexpected error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _authenticateWithBunker() async {
    final bunkerUri = _bunkerUriController.text.trim();
    if (bunkerUri.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a bunker URI';
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final webAuth = ref.read(webAuthServiceProvider);
      final result = await webAuth.authenticateWithBunker(bunkerUri);

      if (mounted) {
        if (result.success) {
          _onAuthenticationSuccess();
        } else {
          setState(() {
            _errorMessage = result.errorMessage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unexpected error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && mounted) {
        _bunkerUriController.text = clipboardData!.text!;
      }
    } catch (e) {
      Log.error(
        'Failed to paste from clipboard: $e',
        name: 'WebAuthScreen',
        category: LogCategory.ui,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Consumer(
      builder: (context, ref, child) {
        final webAuth = ref.watch(webAuthServiceProvider);
        return SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo and title
                              const Icon(
                                Icons.security,
                                size: 80,
                                color: Colors.purple,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Connect to divine',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'serif', // Fallback font
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Choose your preferred Nostr authentication method',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 48),

                              // NIP-07 Authentication
                              if (webAuth.isNip07Available) ...[
                                _buildAuthMethodCard(
                                  title: 'Browser Extension',
                                  subtitle: webAuth.getMethodDisplayName(
                                    WebAuthMethod.nip07,
                                  ),
                                  icon: Icons.extension,
                                  color: Colors.blue,
                                  onTap: _isAuthenticating
                                      ? null
                                      : _authenticateWithNip07,
                                  isRecommended: true,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Bunker Authentication
                              _buildBunkerAuthCard(webAuth),

                              // Error message
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Help text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'New to Nostr?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Install a browser extension like Alby or nos2x for the easiest experience, or use nsec bunker for secure remote signing.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _buildAuthMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isRecommended = false,
  }) => Card(
    color: Colors.white.withValues(alpha: 0.05),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isRecommended
              ? Border.all(color: Colors.purple, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (_isAuthenticating && onTap != null)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildBunkerAuthCard(WebAuthService webAuth) => Card(
    color: Colors.white.withValues(alpha: 0.05),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'nsec bunker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Connect to a remote signer',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bunkerUriController,
            enabled: !_isAuthenticating,
            enableInteractiveSelection: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'bunker://pubkey?relay=wss://localhost:8080',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _isAuthenticating ? null : _pasteFromClipboard,
                    icon: const Icon(Icons.paste, color: Colors.white54),
                    tooltip: 'Paste from clipboard',
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAuthenticating ? null : _authenticateWithBunker,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isAuthenticating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Connect to Bunker',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
