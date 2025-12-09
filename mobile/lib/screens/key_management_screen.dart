// ABOUTME: Key management screen for importing, exporting, and backing up Nostr keys
// ABOUTME: Simple, clear interface focused on user needs with helpful explanations

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/theme/vine_theme.dart';

class KeyManagementScreen extends ConsumerStatefulWidget {
  const KeyManagementScreen({super.key});

  @override
  ConsumerState<KeyManagementScreen> createState() =>
      _KeyManagementScreenState();
}

class _KeyManagementScreenState extends ConsumerState<KeyManagementScreen> {
  bool _isProcessing = false;
  final _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyManager = ref.watch(nostrKeyManagerProvider);
    final nostrService = ref.watch(nostrServiceProvider);
    final profileService = ref.watch(userProfileServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nostr Keys'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
      ),
      backgroundColor: Colors.black,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // What are Nostr keys explanation
              _buildExplanationCard(),
              const SizedBox(height: 24),

              // Import existing key section
              _buildImportSection(
                context,
                keyManager,
                nostrService,
                profileService,
              ),
              const SizedBox(height: 24),

              // Export/Backup section
              _buildExportSection(context, keyManager),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.15),
        border: Border.all(color: VineTheme.vineGreen.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: VineTheme.vineGreen, size: 24),
              const SizedBox(width: 12),
              const Text(
                'What are Nostr keys?',
                style: TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your Nostr identity is a cryptographic key pair:\n\n'
            '• Your public key (npub) is like your username - share it freely\n'
            '• Your private key (nsec) is like your password - keep it secret!\n\n'
            'Your nsec lets you access your account on any Nostr app.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildImportSection(
    BuildContext context,
    NostrKeyManager keyManager,
    nostrService,
    profileService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import Existing Key',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Already have a Nostr account? Paste your private key (nsec) to access it here.',
          style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _importController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'nsec1...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VineTheme.vineGreen),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.paste, color: Colors.grey.shade400),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _importController.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
                maxLines: 3,
                enabled: !_isProcessing,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _importKey(
                          context,
                          keyManager,
                          nostrService,
                          profileService,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Import Key',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.shade700.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade300,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This will replace your current key!',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportSection(BuildContext context, NostrKeyManager keyManager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Backup Your Key',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Save your private key (nsec) to use your account in other Nostr apps.',
          style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _exportKey(context, keyManager),
                  icon: const Icon(Icons.copy, size: 20),
                  label: const Text(
                    'Copy My Private Key (nsec)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.shade700.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.red.shade300, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Never share your nsec with anyone!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _importKey(
    BuildContext context,
    NostrKeyManager keyManager,
    nostrService,
    profileService,
  ) async {
    final nsec = _importController.text.trim();

    if (nsec.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste your private key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!nsec.startsWith('nsec1')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid key format. Must start with "nsec1"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Import This Key?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will replace your current identity with the imported one.\n\n'
          'Your current key will be lost unless you backed it up first.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      await keyManager.importFromNsec(nsec);

      // Optionally fetch profile after import if services are available
      if (context.mounted &&
          nostrService.isInitialized &&
          keyManager.publicKey != null) {
        try {
          await profileService.fetchProfile(
            keyManager.publicKey!,
            forceRefresh: false,
          );
        } catch (e) {
          // Non-fatal - profile fetch failure shouldn't block import
        }
      }

      if (context.mounted) {
        _importController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Key imported successfully!'),
            backgroundColor: VineTheme.vineGreen,
            duration: Duration(seconds: 3),
          ),
        );

        // Pop back to settings after successful import
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import key: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportKey(
    BuildContext context,
    NostrKeyManager keyManager,
  ) async {
    try {
      final nsec = keyManager.exportAsNsec();

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: nsec));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Private key copied to clipboard!\n\nStore it somewhere safe.',
            ),
            backgroundColor: VineTheme.vineGreen,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
