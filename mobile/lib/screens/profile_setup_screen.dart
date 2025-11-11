// ABOUTME: Profile setup screen for new users to configure their display name, bio, and avatar
// ABOUTME: Publishes initial profile metadata to Nostr after setup is complete

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/models/user_profile.dart' as profile_model;
import 'package:openvine/utils/unified_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/theme/vine_theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({
    required this.isNewUser,
    super.key,
  });
  final bool isNewUser;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _pictureController = TextEditingController();
  final _nip05Controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isPublishing = false;
  bool _isUploadingImage = false;
  bool _isCheckingUsername = false;
  bool? _usernameAvailable;
  String? _usernameError;
  File? _selectedImage;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _pictureController.dispose();
    _nip05Controller.dispose();

    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    if (!widget.isNewUser) {
      // For imported users, try to load their existing profile
      try {
        final userProfileService = ref.read(userProfileServiceProvider);
        final authService = ref.read(authServiceProvider);

        if (authService.currentPublicKeyHex != null) {
          final profile = await userProfileService
              .fetchProfile(authService.currentPublicKeyHex!);
          if (profile != null && mounted) {
            setState(() {
              // Use bestDisplayName which handles name/displayName fallback properly
              _nameController.text = profile.name ?? profile.displayName ?? '';
              _bioController.text = profile.about ?? '';
              _pictureController.text = profile.picture ?? '';

              // Extract username from NIP-05 if present
              if (profile.nip05 != null &&
                  profile.nip05!.endsWith('@openvine.co')) {
                final username = profile.nip05!.split('@')[0];
                _nip05Controller.text = username;
                _usernameAvailable = true; // Already registered
              }
            });

            Log.info('✅ Pre-filled profile setup form with existing data:',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - name: ${profile.name}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - displayName: ${profile.displayName}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - about: ${profile.about}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - picture: ${profile.picture}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - banner: ${profile.banner}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - website: ${profile.website}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - nip05: ${profile.nip05}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - lud16: ${profile.lud16}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
          }
        }
      } catch (e) {
        Log.error('Failed to load existing profile: $e',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // /edit-profile and /setup-profile are standalone routes outside the ShellRoute
    // They should ALWAYS show their own AppBar
    print('🔍 PROFILE_SETUP DEBUG: build called');
    print('🔍 PROFILE_SETUP DEBUG: isNewUser = ${widget.isNewUser}');

    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.whiteText,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
        ),
        body: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside text fields
            FocusScope.of(context).unfocus();
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        widget.isNewUser
                            ? 'Welcome to divine!'
                            : 'Update Your Profile',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isNewUser
                            ? "Let's set up your profile to get started"
                            : 'Your profile information will be published to Nostr',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[300],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Display Name
                      TextFormField(
                        controller: _nameController,
                        autofocus: true, // Automatically focus on first field
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          labelStyle: const TextStyle(color: Colors.grey),
                          hintText: 'How should people know you?',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey[700]!, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: VineTheme.vineGreen, width: 2),
                          ),
                          prefixIcon:
                              const Icon(Icons.person, color: Colors.grey),
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a display name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Bio
                      TextFormField(
                        controller: _bioController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Bio (Optional)',
                          labelStyle: const TextStyle(color: Colors.grey),
                          hintText: 'Tell people about yourself...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey[700]!, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: VineTheme.vineGreen, width: 2),
                          ),
                          prefixIcon: const Icon(Icons.info_outline,
                              color: Colors.grey),
                        ),
                        maxLines: 3,
                        minLines: 1,
                        maxLength: 160,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 16),

                      // NIP-05 Username (optional) - HIDDEN until @divine.video is ready
                      // TODO: Re-enable when @divine.video NIP-05 service is available
                      // TextFormField(
                      //   controller: _nip05Controller,
                      //   style: const TextStyle(color: Colors.white),
                      //   decoration: InputDecoration(
                      //     labelText: 'Username (Optional)',
                      //     labelStyle: const TextStyle(color: Colors.grey),
                      //     hintText: 'username',
                      //     hintStyle: TextStyle(color: Colors.grey[600]),
                      //     filled: true,
                      //     fillColor: Colors.grey[900],
                      //     border: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //       borderSide: BorderSide.none,
                      //     ),
                      //     enabledBorder: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //       borderSide:
                      //           BorderSide(color: Colors.grey[700]!, width: 1),
                      //     ),
                      //     focusedBorder: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //       borderSide: const BorderSide(
                      //           color: VineTheme.vineGreen, width: 2),
                      //     ),
                      //     prefixIcon: const Icon(Icons.verified_user,
                      //         color: Colors.grey),
                      //     suffixText: '@divine.video',
                      //     suffixStyle: TextStyle(color: Colors.grey[500]),
                      //     errorMaxLines: 2,
                      //   ),
                      //   textInputAction: TextInputAction.next,
                      //   onFieldSubmitted: (_) =>
                      //       FocusScope.of(context).nextFocus(),
                      //   onChanged: _onUsernameChanged,
                      //   validator: (value) {
                      //     if (value == null || value.isEmpty) {
                      //       return null; // Optional field
                      //     }
                      //
                      //     final regex =
                      //         RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
                      //     if (!regex.hasMatch(value)) {
                      //       return 'Username can only contain letters, numbers, dash, underscore, and dot';
                      //     }
                      //     if (value.length < 3) {
                      //       return 'Username must be at least 3 characters';
                      //     }
                      //     if (value.length > 20) {
                      //       return 'Username must be 20 characters or less';
                      //     }
                      //     if (_usernameError != null) {
                      //       return _usernameError;
                      //     }
                      //     return null;
                      //   },
                      // ),
                      // if (_isCheckingUsername)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 8),
                      //     child: Row(
                      //       children: [
                      //         const SizedBox(
                      //           width: 16,
                      //           height: 16,
                      //           child:
                      //               CircularProgressIndicator(strokeWidth: 2),
                      //         ),
                      //         const SizedBox(width: 8),
                      //         Text(
                      //           'Checking availability...',
                      //           style: TextStyle(
                      //               color: Colors.grey[400], fontSize: 12),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // if (_usernameAvailable == true &&
                      //     !_isCheckingUsername &&
                      //     _nip05Controller.text.isNotEmpty)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 8),
                      //     child: Row(
                      //       children: [
                      //         const Icon(Icons.check_circle,
                      //             color: VineTheme.vineGreen, size: 16),
                      //         const SizedBox(width: 8),
                      //         Text(
                      //           'Username available!',
                      //           style: TextStyle(
                      //               color: VineTheme.vineGreen, fontSize: 12),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // const SizedBox(height: 16),

                      // Profile Picture Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Picture (Optional)',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Stack(
                              children: [
                                // Profile picture preview
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[800],
                                    border: Border.all(
                                      color: _selectedImage != null ||
                                              _uploadedImageUrl != null ||
                                              _pictureController.text.isNotEmpty
                                          ? VineTheme.vineGreen
                                          : Colors.grey[700]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _buildProfilePicturePreview(),
                                  ),
                                ),
                                // Upload progress indicator
                                if (_isUploadingImage)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            Colors.black.withValues(alpha: 0.7),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: VineTheme.vineGreen,
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Image source buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Show camera button on mobile only (macOS camera support is unreliable)
                              if (!_isDesktopPlatform()) ...[
                                OutlinedButton.icon(
                                  onPressed: _isUploadingImage
                                      ? null
                                      : () => _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt, size: 20),
                                  label: const Text('Camera'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.grey[700]!),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              OutlinedButton.icon(
                                onPressed: _isUploadingImage
                                    ? null
                                    : () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library, size: 20),
                                label: Text(_isDesktopPlatform()
                                    ? 'Browse Files'
                                    : 'Gallery'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.grey[700]!),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // URL input option
                          ExpansionTile(
                            title: Text(
                              defaultTargetPlatform == TargetPlatform.macOS
                                  ? 'Paste image URL (recommended)'
                                  : 'Or paste image URL',
                              style: TextStyle(
                                color: defaultTargetPlatform ==
                                        TargetPlatform.macOS
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontSize: defaultTargetPlatform ==
                                        TargetPlatform.macOS
                                    ? 16
                                    : 14,
                                fontWeight: defaultTargetPlatform ==
                                        TargetPlatform.macOS
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                            tilePadding: EdgeInsets.zero,
                            initiallyExpanded:
                                defaultTargetPlatform == TargetPlatform.macOS,
                            children: [
                              TextFormField(
                                controller: _pictureController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText:
                                      'https://example.com/your-avatar.jpg',
                                  hintStyle: TextStyle(color: Colors.grey[600]),
                                  filled: true,
                                  fillColor: Colors.grey[900],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey[700]!, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: VineTheme.vineGreen, width: 2),
                                  ),
                                  prefixIcon: const Icon(Icons.link,
                                      color: Colors.grey),
                                ),
                                textInputAction: TextInputAction.done,
                                onChanged: (_) =>
                                    setState(() {}), // Update preview
                                onFieldSubmitted: (_) => _publishProfile(),
                                keyboardType: TextInputType.url,
                                validator: (value) {
                                  if (value != null &&
                                      value.trim().isNotEmpty) {
                                    // Basic URL validation
                                    final uri = Uri.tryParse(value.trim());
                                    if (uri == null || !uri.hasAbsolutePath) {
                                      return 'Please enter a valid URL';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              if (defaultTargetPlatform ==
                                  TargetPlatform.macOS) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Tip: Upload your image to imgur.com, cloudinary.com, or any image hosting service to get a URL.',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isPublishing
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isPublishing ? null : _publishProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: VineTheme.vineGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isPublishing
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Saving...'),
                                      ],
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
                ),
                ),
            ),
          ),
        ),
      );
  }

  Future<void> _publishProfile() async {
    Log.info('🚀 Starting profile publish...',
        name: 'ProfileSetupScreen', category: LogCategory.ui);

    if (!_formKey.currentState!.validate()) {
      Log.warning('Form validation failed',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final nostrService = ref.read(nostrServiceProvider);
      final userProfileService = ref.read(userProfileServiceProvider);

      Log.info(
        'Auth status: isAuthenticated=${authService.isAuthenticated}, publicKey=${authService.currentPublicKeyHex != null}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      Log.info(
        'NostrService status: isInitialized=${nostrService.isInitialized}, connectedRelays=${nostrService.connectedRelays.length}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      // Log existing profile before update
      final currentPubkey = authService.currentPublicKeyHex!;
      final existingProfile =
          userProfileService.getCachedProfile(currentPubkey);
      if (existingProfile != null) {
        Log.info('📋 Existing profile before update:',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - name: ${existingProfile.name}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - displayName: ${existingProfile.displayName}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - about: ${existingProfile.about}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - picture: ${existingProfile.picture}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - eventId: ${existingProfile.eventId}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
      } else {
        Log.info(
            '📋 No existing profile found for ${currentPubkey}...',
            name: 'ProfileSetupScreen',
            category: LogCategory.ui);
      }

      // Create profile metadata - start with existing profile data to preserve all fields
      final profileData = <String, dynamic>{};

      // Preserve all existing fields from current profile
      if (existingProfile != null) {
        // Start with the raw data to preserve unknown fields
        profileData.addAll(existingProfile.rawData);

        // Also explicitly preserve known fields
        if (existingProfile.name != null) {
          profileData['name'] = existingProfile.name;
        }
        if (existingProfile.displayName != null) {
          profileData['display_name'] = existingProfile.displayName;
        }
        if (existingProfile.about != null) {
          profileData['about'] = existingProfile.about;
        }
        if (existingProfile.picture != null) {
          profileData['picture'] = existingProfile.picture;
        }
        if (existingProfile.banner != null) {
          profileData['banner'] = existingProfile.banner;
        }
        if (existingProfile.website != null) {
          profileData['website'] = existingProfile.website;
        }
        if (existingProfile.nip05 != null) {
          profileData['nip05'] = existingProfile.nip05;
        }
        if (existingProfile.lud16 != null) {
          profileData['lud16'] = existingProfile.lud16;
        }
        if (existingProfile.lud06 != null) {
          profileData['lud06'] = existingProfile.lud06;
        }

        Log.info('📋 Preserved existing profile fields:',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - Preserved fields: ${profileData.keys.toList()}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
      }

      // Override with form data (only the fields we can edit)
      profileData['name'] = _nameController.text.trim();

      if (_bioController.text.trim().isNotEmpty) {
        profileData['about'] = _bioController.text.trim();
      } else {
        // Remove about field if empty (user cleared it)
        profileData.remove('about');
      }

      if (_pictureController.text.trim().isNotEmpty) {
        profileData['picture'] = _pictureController.text.trim();
      } else {
        // Remove picture field if empty (user cleared it)
        profileData.remove('picture');
      }

      Log.info('📝 Profile data to publish:',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - name: ${profileData['name']}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - about: ${profileData['about'] ?? 'not set'}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - picture: ${profileData['picture'] ?? 'not set'}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      // Handle NIP-05 registration if username provided - DISABLED until @divine.video is ready
      // TODO: Re-enable when @divine.video NIP-05 service is available
      // String? nip05Identifier;
      // if (_nip05Controller.text.trim().isNotEmpty &&
      //     _usernameAvailable == true) {
      //   try {
      //     final nip05Service = Nip05Service();
      //     final username = _nip05Controller.text.trim();
      //     final nostrService = ref.read(nostrServiceProvider);
      //     final relays = nostrService.connectedRelays.toList();
      //
      //     final registered = await nip05Service.registerUsername(
      //       username,
      //       authService.currentPublicKeyHex!,
      //       relays,
      //     );
      //
      //     if (registered) {
      //       nip05Identifier = '$username@divine.video';
      //       profileData['nip05'] = nip05Identifier;
      //     }
      //   } catch (e) {
      //     Log.error('Failed to register NIP-05: $e',
      //         name: 'ProfileSetupScreen', category: LogCategory.ui);
      //     // Continue with profile creation even if NIP-05 fails
      //   }
      // }

      // Create NIP-01 kind 0 profile event
      Log.info('🔨 Creating kind 0 event...',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      final event = await authService.createAndSignEvent(
        kind: 0,
        content: jsonEncode(profileData),
      );

      if (event == null) {
        Log.error(
            '❌ Failed to create profile event - createAndSignEvent returned null',
            name: 'ProfileSetupScreen',
            category: LogCategory.ui);
        throw Exception('Failed to create profile event');
      }

      // Log the created event
      Log.info('✅ Created kind 0 event:',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Event ID: ${event.id}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Pubkey: ${event.pubkey}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Kind: ${event.kind}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Content: ${event.content}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Created at: ${event.createdAt}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Signature: ${event.sig}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Tags: ${event.tags}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      // Check if event is valid
      final isValid = event.isSigned;
      Log.info('🔍 Event signature valid: $isValid',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      // Publish to Nostr relays
      Log.info('📡 Publishing profile event to Nostr relays...',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      final result = await nostrService.broadcastEvent(event);
      final success = result.isSuccessful;

      Log.info(
        'Broadcast result: success=$success, successCount=${result.successCount}/${result.totalRelays}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      if (result.errors.isNotEmpty) {
        Log.error('Broadcast errors: ${result.errors}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
      }


      if (success) {
        // Immediately update local cache with published profile data
        if (mounted) {
          Log.info(
            '🔄 Updating local cache with published profile...',
            name: 'ProfileSetupScreen',
            category: LogCategory.ui,
          );

          final userProfileService = ref.read(userProfileServiceProvider);

          // Create profile from published data
          final newProfile = profile_model.UserProfile(
            pubkey: currentPubkey,
            eventId: event.id,
            createdAt:
                DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
            name: profileData['name'] as String?,
            displayName: profileData['display_name'] as String?,
            about: profileData['about'] as String?,
            picture: profileData['picture'] as String?,
            nip05: profileData['nip05'] as String?,
            rawData: profileData,
          );

          // Update cache directly (no async fetch needed)
          await userProfileService.updateCachedProfile(newProfile);
          Log.info('✅ Updated local cache with published profile data',
              name: 'ProfileSetupScreen', category: LogCategory.ui);

          // Update AuthService profile cache
          await authService.refreshCurrentProfile(userProfileService);
          Log.info('✅ Updated AuthService profile cache',
              name: 'ProfileSetupScreen', category: LogCategory.ui);

          // Invalidate Riverpod provider to trigger UI refresh
          ref.invalidate(fetchUserProfileProvider(currentPubkey));
          Log.info('✅ Invalidated fetchUserProfileProvider for UI refresh',
              name: 'ProfileSetupScreen', category: LogCategory.ui);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: VineTheme.vineGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Profile published successfully!',
                    style: TextStyle(color: VineTheme.vineGreen),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
            ),
          );
        }

        // Navigate back or to main app
        if (widget.isNewUser) {
          // For new users, wait a moment to show success message, then navigate to main app
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            // Navigate to main app by popping back to the auth flow
            // The auth service should already be in authenticated state
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else {
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to publish profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  // Skip button removed from UI - no longer needed
  // void _skipProfileSetup() {
  //   if (widget.isNewUser) {
  //     // For new users, navigate back to the auth flow
  //     // The auth service should already be in authenticated state
  //     Navigator.of(context).popUntil((route) => route.isFirst);
  //   } else {
  //     // For existing users, just go back to previous screen
  //     Navigator.of(context).pop();
  //   }
  // }

  Widget _buildProfilePicturePreview() {
    // Priority: selected image > uploaded URL > manual URL > placeholder
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    } else if (_uploadedImageUrl != null) {
      return Image.network(
        _uploadedImageUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, color: Colors.grey, size: 50),
      );
    } else if (_pictureController.text.isNotEmpty) {
      return Image.network(
        _pictureController.text,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, color: Colors.grey, size: 50),
      );
    } else {
      return const Icon(Icons.person, color: Colors.grey, size: 50);
    }
  }

  /// Platform-aware image selection
  Future<void> _pickImage(ImageSource source) async {
    try {
      Log.info(
        '🖼️ Attempting to pick image from ${source.name} on ${defaultTargetPlatform.name}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      File? selectedFile;

      // Use different methods based on platform and source
      if (source == ImageSource.gallery && _isDesktopPlatform()) {
        // Use file_selector for desktop gallery/file browsing
        selectedFile = await _pickImageFromDesktop();
      } else {
        // Use image_picker for mobile or camera
        selectedFile = await _pickImageFromMobile(source);
      }

      if (selectedFile != null) {
        Log.info('✅ Image picked successfully: ${selectedFile.path}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        setState(() {
          _selectedImage = selectedFile;
          _uploadedImageUrl = null; // Clear previous upload
          _pictureController.clear(); // Clear manual URL
        });

        // Upload the image
        await _uploadImage();
      } else {
        Log.info('❌ No image selected',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
      }
    } catch (e) {
      Log.error('Error picking image: $e',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.gallery
                  ? 'Image selection failed. Please paste an image URL below instead.'
                  : 'Camera access failed: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  /// Check if running on desktop platform
  bool _isDesktopPlatform() =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Use file_selector for desktop platforms
  Future<File?> _pickImageFromDesktop() async {
    try {
      Log.info('🖥️ Starting desktop file picker...',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
      );

      Log.info('🖥️ Opening file dialog with type group: ${typeGroup.label}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      final file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );

      if (file != null) {
        Log.info('✅ Desktop file selected: ${file.path}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('📁 File name: ${file.name}',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('📁 File size: ${await file.length()} bytes',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
        return File(file.path);
      } else {
        Log.info('❌ Desktop file picker: User cancelled or no file selected',
            name: 'ProfileSetupScreen', category: LogCategory.ui);
      }
      return null;
    } catch (e) {
      Log.error('Desktop file picker error: $e',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.error('Error type: ${e.runtimeType}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.error('Stack trace: ${StackTrace.current}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      rethrow;
    }
  }

  /// Use image_picker for mobile platforms and camera
  Future<File?> _pickImageFromMobile(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      Log.error('Mobile image picker error: $e',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      rethrow;
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final uploadService = ref.read(blossomUploadServiceProvider);

      if (authService.currentPublicKeyHex == null) {
        throw Exception('No public key available');
      }

      final result = await uploadService.uploadImage(
        imageFile: _selectedImage!,
        nostrPubkey: authService.currentPublicKeyHex!,
        mimeType: 'image/jpeg',
        onProgress: (progress) {
          // Only log at major milestones to reduce noise
          if (progress == 1.0 || progress == 0.0) {
            Log.debug('Upload ${progress == 1.0 ? "completed" : "started"}',
                name: 'ProfileSetupScreen', category: LogCategory.ui);
          }
        },
      );

      if (result.success && result.cdnUrl != null) {
        setState(() {
          _uploadedImageUrl = result.cdnUrl;
          _pictureController.text = result.cdnUrl!;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result.errorMessage ?? 'Upload failed');
      }
    } catch (e) {
      Log.error('Error uploading image: $e',
          name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.error('Upload error type: ${e.runtimeType}',
          name: 'ProfileSetupScreen', category: LogCategory.ui);

      // Check if it's a network connectivity issue
      final errorMessage = e.toString().toLowerCase();
      String userMessage = 'Failed to upload image: $e';

      if (errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout')) {
        userMessage =
            'Network error: Please check your internet connection and try again.';
      } else if (errorMessage.contains('auth') ||
          errorMessage.contains('401') ||
          errorMessage.contains('403')) {
        userMessage =
            'Authentication error: Please try logging out and back in.';
      } else if (errorMessage.contains('file too large') ||
          errorMessage.contains('size')) {
        userMessage =
            'File too large: Please choose a smaller image (max 10MB).';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // NIP-05 username checking - DISABLED until @divine.video is ready
  // TODO: Re-enable when @divine.video NIP-05 service is available
  // Timer? _usernameCheckTimer;
  //
  // void _onUsernameChanged(String value) {
  //   // Cancel any existing timer
  //   _usernameCheckTimer?.cancel();
  //
  //   // Reset state
  //   setState(() {
  //     _usernameAvailable = null;
  //     _usernameError = null;
  //   });
  //
  //   // Don't check if empty or too short
  //   if (value.isEmpty || value.length < 3) {
  //     return;
  //   }
  //
  //   // Validate format locally first
  //   final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
  //   if (!regex.hasMatch(value)) {
  //     return;
  //   }
  //
  //   // Debounce the check
  //   _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () {
  //     _checkUsernameAvailability(value);
  //   });
  // }
  //
  // Future<void> _checkUsernameAvailability(String username) async {
  //   setState(() {
  //     _isCheckingUsername = true;
  //   });
  //
  //   try {
  //     final nip05Service = Nip05Service();
  //     final isAvailable =
  //         await nip05Service.checkUsernameAvailability(username);
  //
  //     if (mounted) {
  //       setState(() {
  //         _usernameAvailable = isAvailable;
  //         _usernameError = isAvailable ? null : 'Username already taken';
  //         _isCheckingUsername = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         _usernameError = 'Failed to check username';
  //         _isCheckingUsername = false;
  //       });
  //     }
  //   }
  // }
}
