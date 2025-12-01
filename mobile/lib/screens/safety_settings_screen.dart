// ABOUTME: Safety Settings screen for content moderation and user safety controls
// ABOUTME: Provides age verification, adult content preferences, and moderation providers

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetySettingsScreen extends ConsumerStatefulWidget {
  const SafetySettingsScreen({super.key});

  @override
  ConsumerState<SafetySettingsScreen> createState() =>
      _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends ConsumerState<SafetySettingsScreen> {
  bool _isLoading = true;
  bool _isAgeVerified = false;
  AdultContentPreference _preference = AdultContentPreference.askEachTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = ref.read(ageVerificationServiceProvider);
    await service.initialize();
    if (mounted) {
      setState(() {
        _isAgeVerified = service.isAdultContentVerified;
        _preference = service.adultContentPreference;
        _isLoading = false;
      });
    }
  }

  Future<void> _setAgeVerified(bool value) async {
    final service = ref.read(ageVerificationServiceProvider);
    await service.setAdultContentVerified(value);

    // If user says they're under 18, force preference to "Never show"
    if (!value && _preference != AdultContentPreference.neverShow) {
      await service.setAdultContentPreference(AdultContentPreference.neverShow);
      final videoEventService = ref.read(videoEventServiceProvider);
      videoEventService.filterAdultContentFromExistingVideos();
      if (mounted) {
        setState(() {
          _isAgeVerified = value;
          _preference = AdultContentPreference.neverShow;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isAgeVerified = value;
      });
    }
  }

  Future<void> _setPreference(AdultContentPreference value) async {
    final service = ref.read(ageVerificationServiceProvider);
    await service.setAdultContentPreference(value);

    // If user chose to never show adult content, filter existing videos from feeds
    if (value == AdultContentPreference.neverShow) {
      final videoEventService = ref.read(videoEventServiceProvider);
      videoEventService.filterAdultContentFromExistingVideos();
    }

    if (mounted) {
      setState(() {
        _preference = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Privacy'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen))
          : ListView(
              children: [
                _buildAgeVerificationSection(),
                _buildAdultContentSection(),
                _buildModerationProvidersSection(),
                _buildSectionHeader('BLOCKED USERS'),
                _buildSectionHeader('MUTED CONTENT'),
                _buildSectionHeader('REPORT HISTORY'),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: VineTheme.vineGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _buildAgeVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('AGE VERIFICATION'),
        CheckboxListTile(
          value: _isAgeVerified,
          onChanged: (value) {
            if (value != null) {
              _setAgeVerified(value);
            }
          },
          title: const Text(
            'I confirm I am 18 years or older',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Required to view adult content',
            style: TextStyle(color: Colors.grey),
          ),
          activeColor: VineTheme.vineGreen,
          checkColor: Colors.black,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildAdultContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ADULT CONTENT'),
        if (!_isAgeVerified)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Verify your age above to change adult content settings',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        _buildRadioOption(
          title: 'Always show',
          subtitle: 'Auto-authenticate for age-gated content',
          value: AdultContentPreference.alwaysShow,
          enabled: _isAgeVerified,
        ),
        _buildRadioOption(
          title: 'Ask each time',
          subtitle: 'Show confirmation dialog for each video',
          value: AdultContentPreference.askEachTime,
          enabled: _isAgeVerified,
        ),
        _buildRadioOption(
          title: 'Never show',
          subtitle: 'Filter adult content from your feed',
          value: AdultContentPreference.neverShow,
          enabled: _isAgeVerified,
        ),
      ],
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required AdultContentPreference value,
    required bool enabled,
  }) {
    return RadioListTile<AdultContentPreference>(
      value: value,
      groupValue: _preference,
      onChanged: enabled
          ? (newValue) {
              if (newValue != null) {
                _setPreference(newValue);
              }
            }
          : null,
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? Colors.grey : Colors.grey[700],
        ),
      ),
      activeColor: VineTheme.vineGreen,
    );
  }

  Widget _buildModerationProvidersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('MODERATION PROVIDERS'),
        _buildDivineProvider(),
        _buildPeopleIFollowProvider(),
        _buildCustomLabelersSection(),
      ],
    );
  }

  Widget _buildDivineProvider() {
    return ListTile(
      leading: const Icon(Icons.verified_user, color: VineTheme.vineGreen),
      title: const Text(
        'Divine',
        style: TextStyle(color: Colors.white),
      ),
      subtitle: const Text(
        'Default moderation service',
        style: TextStyle(color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: VineTheme.vineGreen),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('https://divine.video/moderation');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Learn more',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleIFollowProvider() {
    return SwitchListTile(
      value: false, // TODO: Wire to actual state
      onChanged: (value) {
        // TODO: Implement subscription to followed users' mute lists
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coming soon: Follow-based moderation'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      title: const Text(
        'People I follow',
        style: TextStyle(color: Colors.white),
      ),
      subtitle: const Text(
        'Subscribe to mute lists from people you follow',
        style: TextStyle(color: Colors.grey),
      ),
      activeColor: VineTheme.vineGreen,
      secondary: const Icon(Icons.people, color: Colors.grey),
    );
  }

  Widget _buildCustomLabelersSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.add_circle_outline, color: Colors.grey),
          title: const Text(
            'Add custom labeler',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Enter npub or nip05 address',
            style: TextStyle(color: Colors.grey),
          ),
          onTap: () {
            // TODO: Show add labeler dialog (Task 3b)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Coming soon: Custom labeler support'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        // TODO: List of added custom labelers
      ],
    );
  }
}
