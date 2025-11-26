// ABOUTME: Settings screen for configuring Blossom media server uploads
// ABOUTME: Allows users to enable Blossom uploads and configure their preferred server

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

class BlossomSettingsScreen extends ConsumerStatefulWidget {
  const BlossomSettingsScreen({super.key});

  @override
  ConsumerState<BlossomSettingsScreen> createState() => _BlossomSettingsScreenState();
}

class _BlossomSettingsScreenState extends ConsumerState<BlossomSettingsScreen> {
  final _serverController = TextEditingController();
  bool _isBlossomEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final blossomService = ref.read(blossomUploadServiceProvider);
      
      final isEnabled = await blossomService.isBlossomEnabled();
      final serverUrl = await blossomService.getBlossomServer();
      
      if (mounted) {
        setState(() {
          _isBlossomEnabled = isEnabled;
          _serverController.text = serverUrl ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.error('Failed to load Blossom settings: $e',
          name: 'BlossomSettingsScreen', category: LogCategory.ui);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    // Validate URL if Blossom is enabled
    if (_isBlossomEnabled && _serverController.text.isNotEmpty) {
      final uri = Uri.tryParse(_serverController.text);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid server URL (e.g., https://blossom.divine.video)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final blossomService = ref.read(blossomUploadServiceProvider);
      
      // Save settings
      await blossomService.setBlossomEnabled(_isBlossomEnabled);
      
      if (_isBlossomEnabled && _serverController.text.isNotEmpty) {
        await blossomService.setBlossomServer(_serverController.text);
      } else {
        await blossomService.setBlossomServer(null);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blossom settings saved'),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Log.error('Failed to save Blossom settings: $e',
          name: 'BlossomSettingsScreen', category: LogCategory.ui);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Blossom Upload Settings'),
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.whiteText,
        ),
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(
            color: VineTheme.vineGreen,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blossom Upload Settings'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: VineTheme.vineGreen),
                  ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          // Info card
          Card(
            color: Colors.black.withValues(alpha:0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: VineTheme.vineGreen.withValues(alpha:0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, 
                          color: VineTheme.vineGreen.withValues(alpha:0.8)),
                      const SizedBox(width: 8),
                      const Text(
                        'About Blossom',
                        style: TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Blossom is a decentralized media storage protocol that allows you to upload videos to any compatible server. '
                    'When enabled, your videos will be uploaded to your chosen Blossom server instead of Divine\'s default storage.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Enable/Disable toggle
          SwitchListTile(
            title: const Text(
              'Use Blossom Upload',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: Text(
              _isBlossomEnabled
                  ? 'Videos will be uploaded to your Blossom server'
                  : 'Videos will be uploaded to Divine\'s servers',
              style: TextStyle(color: Colors.white.withValues(alpha:0.6)),
            ),
            value: _isBlossomEnabled,
            onChanged: (value) {
              setState(() {
                _isBlossomEnabled = value;
                // Set default server to diVine Blossom when enabling for the first time
                if (value && _serverController.text.isEmpty) {
                  _serverController.text = 'https://blossom.divine.video';
                }
              });
            },
            activeThumbColor: VineTheme.vineGreen,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha:0.3),
          ),
          const SizedBox(height: 20),

          // Server URL input
          AnimatedOpacity(
            opacity: _isBlossomEnabled ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blossom Server URL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverController,
                  enabled: _isBlossomEnabled,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'https://blossom.divine.video',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.4)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha:0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: VineTheme.vineGreen.withValues(alpha:0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: VineTheme.vineGreen.withValues(alpha:0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: VineTheme.vineGreen,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha:0.3),
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.cloud_upload,
                      color: VineTheme.vineGreen,
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the URL of your Blossom server',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Popular Blossom servers section
          if (_isBlossomEnabled) ...[
            const Text(
              'Popular Blossom Servers',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildServerOption('https://blossom.divine.video', 'diVine Blossom (Default)'),
            _buildServerOption('https://blossom.band', 'Blossom Band'),
            _buildServerOption('https://cdn.satellite.earth', 'Satellite Earth'),
            _buildServerOption('https://blossom.primal.net', 'Primal'),
            _buildServerOption('https://nostr.download', 'Nostr Download'),
            _buildServerOption('https://cdn.nostrcheck.me', 'NostrCheck'),
          ],
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerOption(String url, String name) {
    return Card(
      color: Colors.white.withValues(alpha:0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          name,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          url,
          style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward,
          color: VineTheme.vineGreen,
        ),
        onTap: () {
          setState(() {
            _serverController.text = url;
          });
        },
      ),
    );
  }
}