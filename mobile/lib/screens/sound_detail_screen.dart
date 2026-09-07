// ABOUTME: Detail screen for viewing a sound and videos using that sound.
// ABOUTME: Displays sound info, preview/use buttons, and grid of related videos.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/saved_sound_context_builder.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/library/saved_sound_details_editor.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_credit.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:provider/provider.dart' as inherited_provider;
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

const _soundDetailCreatorAttributionIdentifier =
    'sound_detail_creator_attribution';
const _soundDetailPublisherAttributionIdentifier =
    'sound_detail_publisher_attribution';

/// How long the screen's confirmation / failure snackbars stay up.
const _snackBarDuration = Duration(seconds: 2);

/// Pinned label introducing the video grid.
///
/// Rendered through [PinnedHeaderSliver] rather than a
/// [SliverPersistentHeaderDelegate] on purpose: a delegate has to declare its
/// extent before the child is laid out, so every type or padding change has
/// to be mirrored in that arithmetic, and a header that ends up shorter than
/// its declared extent makes `layoutExtent` exceed `paintExtent` — the sliver
/// then fails layout, leaves its geometry null, and paint reports it as
/// "Null check operator used on a null value" against the enclosing
/// [CustomScrollView]. [PinnedHeaderSliver] measures the child instead, so
/// there is nothing to keep in sync.
///
/// Paints the scroll view's own background so the grid scrolls *behind* the
/// label rather than through it — a pinned sliver keeps painting where the
/// slivers after it are still scrolling, and a transparent one shows their
/// thumbnails straight through the text.
class _VideosSectionHeader extends StatelessWidget {
  const _VideosSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          title,
          style: VineTheme.titleSmallFont(
            color: context.vineColors.primaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Screen displaying details of a specific sound and videos using it.
///
/// Features:
/// - Sound header with title, duration, and video count
/// - Preview button to play/stop audio preview
/// - Use Sound button to select for recording
/// - Grid of videos using this sound
class SoundDetailScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'sound';

  /// Base path for sound routes.
  static const String basePath = RoutePaths.soundDetailBase;

  /// Path pattern for this route.
  static const path = '/sound/:id';

  /// Build path for a specific sound ID.
  static String pathForId(String id) => RoutePaths.soundDetailForId(id);

  /// Creates a SoundDetailScreen.
  ///
  /// [sound] is the audio event to display.
  /// [sourceVideo] is optional — provided for original sounds to show
  /// the video this sound came from.
  const SoundDetailScreen({required this.sound, this.sourceVideo, super.key});

  /// The audio event to display details for.
  final AudioEvent sound;

  /// The source video for original sounds (when [AudioEvent.isOriginalSound]).
  final VideoEvent? sourceVideo;

  @override
  ConsumerState<SoundDetailScreen> createState() => _SoundDetailScreenState();
}

class _SoundDetailScreenState extends ConsumerState<SoundDetailScreen> {
  bool _isPlayingPreview = false;
  bool _isLoadingPreview = false;

  /// Whether the video feed overlay is showing
  bool _showingVideoFeed = false;

  /// Starting index for video feed
  int _videoFeedStartIndex = 0;

  /// List of videos for the feed (populated when grid loads)
  List<VideoEvent> _videosForFeed = [];

  /// Cached reference to audio service for safe disposal
  AudioPlaybackService? _audioService;

  @override
  void dispose() {
    // Stop any playing preview when leaving the screen
    if (_isPlayingPreview && _audioService != null) {
      _audioService!.stop();
    }
    super.dispose();
  }

  Future<void> _togglePreview() async {
    if (_isLoadingPreview) return;

    // Cache audio service for safe disposal
    _audioService ??= ref.read(audioPlaybackServiceProvider);
    final audioService = _audioService!;

    if (_isPlayingPreview) {
      // Stop playing
      await audioService.stop();
      if (mounted) {
        setState(() {
          _isPlayingPreview = false;
        });
      }
      return;
    }

    // Check if sound has a URL to play
    if (widget.sound.url == null || widget.sound.url!.isEmpty) {
      Log.warning(
        'Cannot preview sound: no URL available (${widget.sound.id})',
        name: 'SoundDetailScreen',
        category: LogCategory.ui,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.soundUnableToPreview,
            error: true,
            duration: _snackBarDuration,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoadingPreview = true;
    });

    try {
      Log.info(
        'Starting preview for sound: ${widget.sound.title} (${widget.sound.id})',
        name: 'SoundDetailScreen',
        category: LogCategory.ui,
      );

      await audioService.loadAudio(widget.sound.url!);
      if (mounted) {
        setState(() {
          _isPlayingPreview = true;
          _isLoadingPreview = false;
        });
      }
      await audioService.play();

      if (mounted) {
        setState(() {
          _isPlayingPreview = true;
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      Log.error(
        'Failed to preview sound: $e',
        name: 'SoundDetailScreen',
        category: LogCategory.ui,
      );
      if (mounted) {
        setState(() {
          _isPlayingPreview = false;
          _isLoadingPreview = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.soundPreviewFailed,
            error: true,
            duration: _snackBarDuration,
          ),
        );
      }
    }
  }

  void _onUseSound() {
    Log.info(
      'Saving sound to library: ${widget.sound.title} (${widget.sound.id})',
      name: 'SoundDetailScreen',
      category: LogCategory.ui,
    );

    unawaited(_saveSoundToLibrary());
  }

  Future<void> _saveSoundToLibrary() async {
    if (_isPlayingPreview && _audioService != null) {
      await _audioService!.stop();
      if (!mounted) return;
      setState(() {
        _isPlayingPreview = false;
      });
    }

    SavedSoundSaveResult? result;
    try {
      result = await context.read<SavedSoundsBloc>().saveSound(
        widget.sound,
        sourceContext: widget.sourceVideo == null
            ? null
            : const SavedSoundContextBuilder().fromVideo(
                widget.sourceVideo!,
                creatorName: widget.sourceVideo!.authorName,
              ),
      );
    } catch (_) {
      result = null;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        switch (result) {
          SavedSoundSaveResult.saved => context.l10n.soundsSavedToLibrary,
          SavedSoundSaveResult.alreadySaved =>
            context.l10n.soundsAlreadySavedToLibrary,
          null => context.l10n.soundsSaveFailed,
        },
        error: result == null,
        duration: _snackBarDuration,
      ),
    );
  }

  /// Whether the viewer may reuse [SoundDetailScreen.sound].
  ///
  /// Explicit consent is accepted directly. Older Kind 1063 events are
  /// verified against their exact source video and otherwise fail closed.
  bool _canReuseSound() {
    final sound = widget.sound;
    final knownTerms = audioReuseTermsFromEvent(sound);
    if (knownTerms == true) return true;
    // Keep the synchronously knowable owner gate local so the button does not
    // disappear for a frame on the creator's own sound.
    ref.watch(currentAuthStateProvider);
    final viewer = ref.watch(authServiceProvider).currentPublicKeyHex;
    if (viewer != null && viewer.isNotEmpty && viewer == sound.pubkey) {
      return true;
    }
    if (knownTerms == false) return false;
    return ref.watch(audioReuseConsentProvider(sound)).value ?? false;
  }

  /// Public reuse terms for [SoundDetailScreen.sound], or `null` while legacy
  /// consent is still being verified.
  bool? _reuseTerms() {
    final sound = widget.sound;
    return audioReuseTermsFromEvent(sound) ??
        ref.watch(audioReuseTermsProvider(sound)).value;
  }

  void _navigateToVideo(String videoId, int index, List<VideoEvent> videos) {
    Log.info(
      'Showing video feed at index $index for video: $videoId',
      name: 'SoundDetailScreen',
      category: LogCategory.ui,
    );

    // Stop preview if playing before showing video feed
    if (_isPlayingPreview && _audioService != null) {
      _audioService!.stop();
      setState(() {
        _isPlayingPreview = false;
      });
    }

    // Show video feed overlay instead of navigating away
    setState(() {
      _videosForFeed = videos;
      _videoFeedStartIndex = index;
      _showingVideoFeed = true;
    });
  }

  void _closeVideoFeed() {
    Log.info(
      'Closing video feed overlay',
      name: 'SoundDetailScreen',
      category: LogCategory.ui,
    );
    setState(() {
      _showingVideoFeed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // A reused original sound carries the source video's id behind a `video_`
    // prefix; query usage/grid by the recovered event id that real reuses tag
    // in their `["e", <id>, relay, "audio"]` reference, not the synthetic id.
    final soundEventId = widget.sound.attributionEventId ?? widget.sound.id;
    final showsSourceVideo =
        widget.sound.isOriginalSound && widget.sourceVideo != null;
    final usageCountAsync = ref.watch(soundUsageCountProvider(soundEventId));
    final canReuseSound = _canReuseSound();
    final reuseAllowed = _reuseTerms();
    SavedSoundsBloc? savedSoundsBloc;
    try {
      savedSoundsBloc = inherited_provider.Provider.of<SavedSoundsBloc>(
        context,
        listen: false,
      );
    } on inherited_provider.ProviderNotFoundException {
      // Standalone embeds can display sound details without a saved library.
    }

    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: _showingVideoFeed
          ? null
          : DiVineAppBar(
              title: context.l10n.soundTitle,
              showBackButton: true,
              onBackPressed: context.safePop,
              backgroundColor: context.vineColors.card,
            ),
      body: Stack(
        children: [
          // Main content. One scroll view for the whole screen: the sound
          // header used to be a fixed-height `Column` child above the grid,
          // so on a short viewport — or once attribution, tags and the saved
          // sound editor stack up — the grid was squeezed into a slot barely
          // one row tall. Only the videos section header stays pinned.
          Semantics(
            identifier: 'sound_detail_screen_${widget.sound.id}',
            container: true,
            child: CustomScrollView(
              slivers: [
                // Sound header
                SliverToBoxAdapter(
                  child: _SoundHeader(
                    sound: widget.sound,
                    usageCount: usageCountAsync.value ?? 0,
                    isPlaying: _isPlayingPreview,
                    isLoadingPreview: _isLoadingPreview,
                    onPreviewTap: _togglePreview,
                    onUseSoundTap: canReuseSound ? _onUseSound : null,
                    reuseAllowed: reuseAllowed,
                  ),
                ),

                if (savedSoundsBloc != null)
                  SliverToBoxAdapter(
                    child: BlocBuilder<SavedSoundsBloc, SavedSoundsState>(
                      bloc: savedSoundsBloc,
                      builder: (context, state) {
                        final records = state.sounds.where(
                          (record) => record.id == widget.sound.id,
                        );
                        if (records.isEmpty) return const SizedBox.shrink();
                        return SavedSoundDetailsEditor(sound: records.first);
                      },
                    ),
                  ),

                PinnedHeaderSliver(
                  child: _VideosSectionHeader(
                    title: showsSourceVideo
                        ? context.l10n.soundSourceVideo
                        : context.l10n.soundVideosUsingThisSound,
                  ),
                ),

                // Videos grid — when a source video is on hand (own original
                // sound), show it directly; otherwise query by the recovered
                // audio event id.
                if (showsSourceVideo)
                  _SourceVideoGrid(
                    video: widget.sourceVideo!,
                    onVideoTap: _navigateToVideo,
                  )
                else
                  _VideosGrid(
                    audioEventId: soundEventId,
                    onVideoTap: _navigateToVideo,
                  ),

                const SliverBottomSafeArea(),
              ],
            ),
          ),

          // Video feed overlay
          if (_showingVideoFeed && _videosForFeed.isNotEmpty)
            _SoundVideoFeedOverlay(
              videos: _videosForFeed,
              startIndex: _videoFeedStartIndex,
              soundTitle: widget.sound.title ?? context.l10n.soundOriginalSound,
              onClose: _closeVideoFeed,
            ),
        ],
      ),
    );
  }
}

/// Header section displaying sound info and action buttons.
class _SoundHeader extends ConsumerStatefulWidget {
  const _SoundHeader({
    required this.sound,
    required this.usageCount,
    required this.isPlaying,
    required this.isLoadingPreview,
    required this.onPreviewTap,
    required this.onUseSoundTap,
    required this.reuseAllowed,
  });

  final AudioEvent sound;
  final int usageCount;
  final bool isPlaying;
  final bool isLoadingPreview;
  final VoidCallback onPreviewTap;
  final bool? reuseAllowed;

  /// Tap handler for the "Use Sound" button, or `null` when the sound may not
  /// be reused — in which case the button is hidden entirely.
  final VoidCallback? onUseSoundTap;

  @override
  ConsumerState<_SoundHeader> createState() => _SoundHeaderState();
}

class _SoundHeaderState extends ConsumerState<_SoundHeader> {
  String? _artistName;
  String? _license;
  String? _sourceUrl;

  @override
  void initState() {
    super.initState();
    _lookUpAttribution();
  }

  void _lookUpAttribution() {
    final sound = widget.sound;
    _artistName = sound.creatorName;
    _license = sound.licenseName;
    _sourceUrl = _launchableUrl(sound.source);
    if (sound.externalSource case final external?) {
      _artistName ??= external.creatorName;
      _license ??= external.license.name;
      _sourceUrl ??= _launchableUrl(external.sourceUrl);
    }
    if (!sound.isBundled) return;

    final soundId = sound.id.replaceFirst('${AudioEvent.bundledMarker}_', '');
    final service = ref.read(soundLibraryServiceSyncProvider);
    final vineSound = service.getSoundById(soundId);
    if (vineSound != null) {
      _artistName = vineSound.artist;
      _license = vineSound.license;
      _sourceUrl = _launchableUrl(vineSound.sourceUrl);
    }
  }

  /// [AudioEvent.source] carries free-text attribution ("Original Sound",
  /// "Artist via Freesound") as often as a real URL, so only an absolute URL
  /// becomes a tappable "View source" link — anything else would render a link
  /// that `canLaunchUrl` rejects on tap.
  static String? _launchableUrl(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.hasAuthority ? value : null;
  }

  String get _formattedDuration {
    final seconds = widget.sound.duration;
    if (seconds == null || seconds <= 0) return '';
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).toStringAsFixed(0);
    return '$minutes:${remainingSeconds.padLeft(2, '0')}';
  }

  String _videoCountText(AppLocalizations l10n) {
    if (widget.usageCount == 0) return l10n.soundNoVideoCount;
    if (widget.usageCount == 1) return l10n.soundOneVideo;
    return l10n.soundVideoCount(widget.usageCount);
  }

  @override
  Widget build(BuildContext context) {
    final sound = widget.sound;
    final profileCreditPubkey = _profileCreditPubkey(sound);
    final profileCreditProfile = profileCreditPubkey == null
        ? null
        : ref.watch(userProfileReactiveProvider(profileCreditPubkey)).value;
    final profileCreditName = profileCreditPubkey == null
        ? null
        : _artistName ??
              AudioAttributionCredit.displayNameForPubkey(
                pubkey: profileCreditPubkey,
                profile: profileCreditProfile,
              );
    // Matches the feed pill and the metadata sheet: a credited creator who is
    // not the signer means the signer only shared the sound. Bundled sounds
    // carry a marker pubkey rather than a real signer, so they are excluded
    // instead of being credited to a generated name.
    final showsSeparatePublisher =
        _artistName != null &&
        !sound.isBundled &&
        sound.creatorPubkey != sound.pubkey;
    final publisherProfile = showsSeparatePublisher
        ? ref.watch(userProfileReactiveProvider(sound.pubkey)).value
        : null;
    final publisherName = showsSeparatePublisher
        ? AudioAttributionCredit.publisherNameFor(
            audio: sound,
            publisherProfile: publisherProfile,
          )
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.vineColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sound title and icon
          Row(
            spacing: 12,
            children: [
              if (profileCreditPubkey == null)
                const _SoundCoverFallback()
              else
                _SoundCover(
                  pubkey: profileCreditPubkey,
                  name: profileCreditName!,
                  pictureUrl: profileCreditProfile?.picture,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      widget.sound.title ?? context.l10n.soundOriginalSound,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _metadataText(context.l10n),
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                    if (profileCreditPubkey != null &&
                        profileCreditName != null)
                      _ProfileAttributionInfo(
                        text: context.l10n.soundCreatorBy(profileCreditName),
                        pubkey: profileCreditPubkey,
                        semanticsIdentifier:
                            _soundDetailCreatorAttributionIdentifier,
                        license: _license,
                        sourceUrl: _sourceUrl,
                      )
                    else if (_artistName != null)
                      _AttributionInfo(
                        artistName: _artistName!,
                        license: _license,
                        sourceUrl: _sourceUrl,
                      ),
                    if (showsSeparatePublisher && publisherName != null)
                      _ProfileCreditLink(
                        text: context.l10n.soundSharedBy(publisherName),
                        pubkey: sound.pubkey,
                        semanticsIdentifier:
                            _soundDetailPublisherAttributionIdentifier,
                      ),
                    if (widget.reuseAllowed case final reuseAllowed?)
                      Text(
                        reuseAllowed
                            ? context.l10n.soundRemixingAllowed
                            : context.l10n.soundCreditOnly,
                        style: VineTheme.labelSmallFont(
                          color: reuseAllowed
                              ? VineTheme.vineGreen
                              : context.vineColors.onSurfaceVariant,
                        ),
                      ),
                    if (sound.publicTags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final tag in sound.publicTags)
                            Text(
                              '#$tag',
                              style: VineTheme.labelSmallFont(
                                color: context.vineColors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            spacing: 12,
            children: [
              // Preview button
              Expanded(
                child: DivineButton(
                  label: widget.isPlaying
                      ? context.l10n.soundStop
                      : context.l10n.soundPreview,
                  type: DivineButtonType.secondary,
                  leadingIcon: widget.isPlaying
                      ? DivineIconName.squareFill
                      : DivineIconName.play,
                  isLoading: widget.isLoadingPreview,
                  semanticIdentifier: 'sound_detail_preview_button',
                  onPressed: widget.onPreviewTap,
                ),
              ),

              // Use Sound button
              if (widget.onUseSoundTap != null)
                Expanded(
                  child: DivineButton(
                    label: context.l10n.soundUseSound,
                    leadingIcon: DivineIconName.plus,
                    semanticIdentifier: 'sound_detail_use_button',
                    onPressed: widget.onUseSoundTap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _metadataText(AppLocalizations l10n) {
    final duration = _formattedDuration;
    return [
      if (duration.isNotEmpty) duration,
      _videoCountText(l10n),
    ].join(' · ');
  }

  String? _profileCreditPubkey(AudioEvent sound) {
    if (sound.isBundled || sound.isLocalImport) return null;
    final creatorPubkey = sound.creatorPubkey;
    if (creatorPubkey != null && creatorPubkey.isNotEmpty) {
      return creatorPubkey;
    }
    if (_artistName == null) return sound.pubkey;
    return null;
  }
}

/// Cover art for the sound header.
///
/// A sound carries no artwork of its own, so the credited creator's avatar
/// stands in for it — the same account the "By …" line names, which lets the
/// header say whose sound this is at a glance and gives a second way into
/// that profile. Bundled and locally imported sounds have no account behind
/// them ([_SoundHeaderState._profileCreditPubkey] returns null there) and
/// keep the note glyph.
class _SoundCover extends StatelessWidget {
  const _SoundCover({
    required this.pubkey,
    required this.name,
    this.pictureUrl,
  });

  static const double _size = 48;

  /// Pubkey of the credited creator.
  final String pubkey;
  final String name;
  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      size: _size,
      imageUrl: pictureUrl,
      name: name,
      placeholderSeed: pubkey,
      onTap: () => context.pushOtherProfile(pubkey),
      semanticLabel: context.l10n.profileChipTapHint(name),
    );
  }
}

/// Note glyph shown when no account backs the sound.
///
/// Shares [UserAvatar]'s corner geometry so the header's leading tile keeps
/// the same silhouette whether it resolves to an avatar or to this.
class _SoundCoverFallback extends StatelessWidget {
  const _SoundCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _SoundCover._size,
      height: _SoundCover._size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(
          UserAvatar.cornerRadiusForSize(_SoundCover._size),
        ),
      ),
      child: const DivineIcon(
        icon: DivineIconName.musicNote,
        color: VineTheme.vineGreen,
        size: 28,
      ),
    );
  }
}

/// Displays a profile-backed creator credit with optional license/source text.
class _ProfileAttributionInfo extends StatelessWidget {
  const _ProfileAttributionInfo({
    required this.text,
    required this.pubkey,
    required this.semanticsIdentifier,
    this.license,
    this.sourceUrl,
  });

  final String text;
  final String pubkey;
  final String semanticsIdentifier;
  final String? license;
  final String? sourceUrl;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: VineTheme.bodySmallFont(color: context.vineColors.secondaryText),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _ProfileCreditLink(
              text: text,
              pubkey: pubkey,
              semanticsIdentifier: semanticsIdentifier,
            ),
          ),
          if (license != null) TextSpan(text: ' · $license'),
          if (sourceUrl != null) ...[
            const TextSpan(text: ' · '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _SourceLink(sourceUrl: sourceUrl!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileCreditLink extends StatelessWidget {
  const _ProfileCreditLink({
    required this.text,
    required this.pubkey,
    required this.semanticsIdentifier,
  });

  final String text;
  final String pubkey;
  final String semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticsIdentifier,
      button: true,
      label: context.l10n.profileChipTapHint(text),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.pushOtherProfile(pubkey),
        child: Text(
          text,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.secondaryText,
          ).copyWith(decoration: TextDecoration.underline),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Displays artist name, license, and optional "View on Freesound" link.
class _AttributionInfo extends StatelessWidget {
  const _AttributionInfo({
    required this.artistName,
    this.license,
    this.sourceUrl,
  });

  final String artistName;
  final String? license;
  final String? sourceUrl;

  @override
  Widget build(BuildContext context) {
    final attributionText = [
      context.l10n.soundCreatorBy(artistName),
      if (license != null) license,
    ].join(' · ');

    return Text.rich(
      TextSpan(
        style: VineTheme.bodySmallFont(color: context.vineColors.secondaryText),
        children: [
          TextSpan(text: attributionText),
          if (sourceUrl != null) ...[
            const TextSpan(text: ' · '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _SourceLink(sourceUrl: sourceUrl!),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.sourceUrl});

  final String sourceUrl;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.soundViewSource;
    return Semantics(
      button: true,
      child: DivineTextLink(
        text: label,
        style: VineTheme.bodySmallFont(color: VineTheme.vineGreen).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: VineTheme.vineGreen,
        ),
        onTap: () async {
          final uri = Uri.parse(sourceUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }
}

/// Sliver grid showing the single source video for an original sound.
class _SourceVideoGrid extends StatelessWidget {
  const _SourceVideoGrid({required this.video, required this.onVideoTap});

  final VideoEvent video;
  final void Function(String videoId, int index, List<VideoEvent> videos)
  onVideoTap;

  @override
  Widget build(BuildContext context) {
    final videosList = [video];
    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return _VideoGridTile(
            video: video,
            onTap: () => onVideoTap(video.id, 0, videosList),
          );
        }, childCount: 1),
      ),
    );
  }
}

/// Sliver grid of videos using the specified sound.
class _VideosGrid extends ConsumerWidget {
  const _VideosGrid({required this.audioEventId, required this.onVideoTap});

  final String audioEventId;
  final void Function(String videoId, int index, List<VideoEvent> videos)
  onVideoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(videosUsingSoundProvider(audioEventId));

    return videosAsync.when(
      data: (videoIds) {
        if (videoIds.isEmpty) {
          return _VideosEmptyState(
            title: context.l10n.soundNoVideosYet,
            message: context.l10n.soundBeFirstToUse,
          );
        }

        return _VideosGridContent(videoIds: videoIds, onVideoTap: onVideoTap);
      },
      loading: () => const _PlaceholderLayout(
        children: [BrandedLoadingIndicator(size: 60)],
      ),
      error: (error, stack) => _VideosErrorState(
        onRetry: () => ref.invalidate(videosUsingSoundProvider(audioEventId)),
      ),
    );
  }
}

/// Sliver centering placeholder content in whatever viewport is left below
/// the header, growing past it — and scrolling — when the content is taller.
class _PlaceholderLayout extends StatelessWidget {
  const _PlaceholderLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

/// Placeholder shown when no video is available for the sound.
class _VideosEmptyState extends StatelessWidget {
  const _VideosEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _PlaceholderLayout(
      children: [
        DivineIcon(
          icon: DivineIconName.filmSlate,
          size: 64,
          color: context.vineColors.mutedText,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Placeholder shown when the videos for a sound failed to load.
class _VideosErrorState extends StatelessWidget {
  const _VideosErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PlaceholderLayout(
      children: [
        const DivineIcon(
          icon: DivineIconName.warningCircle,
          size: 64,
          color: VineTheme.likeRed,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.soundFailedToLoadVideos,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        DivineButton(
          label: l10n.soundRetry,
          leadingIcon: DivineIconName.arrowClockwise,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

/// Content widget that fetches and displays video events in a grid.
class _VideosGridContent extends ConsumerStatefulWidget {
  const _VideosGridContent({required this.videoIds, required this.onVideoTap});

  final List<String> videoIds;
  final void Function(String videoId, int index, List<VideoEvent> videos)
  onVideoTap;

  @override
  ConsumerState<_VideosGridContent> createState() => _VideosGridContentState();
}

class _VideosGridContentState extends ConsumerState<_VideosGridContent> {
  Map<String, VideoEvent?> _videoEvents = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideoEvents();
  }

  @override
  void didUpdateWidget(_VideosGridContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoIds != oldWidget.videoIds) {
      _fetchVideoEvents();
    }
  }

  Future<void> _fetchVideoEvents() async {
    setState(() {
      _isLoading = true;
    });

    final videoEventService = ref.read(videoEventServiceProvider);
    final nostrService = ref.read(nostrServiceProvider);
    final events = <String, VideoEvent?>{};

    for (final videoId in widget.videoIds) {
      // First try to get from cache
      var video = videoEventService.getVideoById(videoId);

      // If not in cache, fetch from Nostr
      if (video == null) {
        try {
          final event = await nostrService.fetchEventById(videoId);
          if (event != null) {
            video = VideoEvent.fromNostrEvent(event);
          }
        } catch (e) {
          Log.error(
            'Failed to fetch video $videoId: $e',
            name: 'SoundDetailScreen',
            category: LogCategory.video,
          );
        }
      }

      if (video != null && videoEventService.shouldHideVideo(video)) {
        video = null;
      }

      events[videoId] = video;
    }

    if (mounted) {
      setState(() {
        _videoEvents = events;
        _isLoading = false;
      });
      ref
          .read(screenAnalyticsServiceProvider)
          .markDataLoaded(
            'sound_detail',
            dataMetrics: {'video_count': events.length},
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(divineHostFilterVersionProvider);
    ref.watch(contentFilterVersionProvider);
    // Re-filter the grid when a block/mute arrives so a newly blocked author's
    // videos disappear without leaving the screen (#4782 residual leak).
    ref.watch(blocklistVersionProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    if (_isLoading) {
      return const _PlaceholderLayout(
        children: [BrandedLoadingIndicator(size: 60)],
      );
    }

    final validVideos = widget.videoIds.where((id) {
      final video = _videoEvents[id];
      return video != null && !videoEventService.shouldHideVideo(video);
    }).toList();

    if (validVideos.isEmpty) {
      return _VideosEmptyState(
        title: context.l10n.soundVideosUnavailable,
        message: context.l10n.soundCouldNotLoadDetails,
      );
    }

    // Build list of valid video events in order
    final videosList = validVideos.map((id) => _videoEvents[id]!).toList();

    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final video = videosList[index];
          return _VideoGridTile(
            video: video,
            onTap: () => widget.onVideoTap(video.id, index, videosList),
          );
        }, childCount: videosList.length),
      ),
    );
  }
}

/// Individual video tile in the grid.
class _VideoGridTile extends StatelessWidget {
  const _VideoGridTile({required this.video, required this.onTap});

  final VideoEvent video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.card,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _VideoThumbnail(thumbnailUrl: video.thumbnailUrl),
              ),
            ),
            Center(
              child: DivineIcon(
                icon: DivineIconName.playCircleFill,
                color: context.vineColors.onSurfaceVariant,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Video thumbnail with loading and error states.
class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return VineCachedImage(
        imageUrl: thumbnailUrl!,
        placeholder: (context, url) => const _ThumbnailPlaceholder(),
        errorWidget: (context, url, error) => const _ThumbnailPlaceholder(),
      );
    }
    return const _ThumbnailPlaceholder();
  }
}

/// Gradient placeholder for thumbnails.
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          colors: [
            VineTheme.vineGreen.withValues(alpha: 0.3),
            VineTheme.info.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Center(
        child: DivineIcon(
          icon: DivineIconName.playCircle,
          color: context.vineColors.primaryText,
        ),
      ),
    );
  }
}

/// Full-screen video feed overlay for browsing videos using a sound.
///
/// Shows a swipeable pooled feed with a header showing sound info
/// and a close button to return to the grid view.
class _SoundVideoFeedOverlay extends ConsumerWidget {
  const _SoundVideoFeedOverlay({
    required this.videos,
    required this.startIndex,
    required this.soundTitle,
    required this.onClose,
  });

  final List<VideoEvent> videos;
  final int startIndex;
  final String soundTitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        PooledFullscreenVideoFeedScreen(
          source: VideoListViewSource(videos),
          feedRepository: StaticFeedRepository(),
          initialIndex: startIndex,
          contextTitle: soundTitle,
        ),

        // Header with close button and sound title
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    VineTheme.backgroundColor.withValues(alpha: 0.7),
                    VineTheme.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Close button
                  DivineIconButton(
                    icon: DivineIconName.x,
                    type: DivineIconButtonType.ghostOverMedia,
                    size: DivineIconButtonSize.small,
                    tooltip: context.l10n.soundCloseTooltip,
                    semanticLabel: context.l10n.soundCloseTooltip,
                    onPressed: onClose,
                  ),

                  // Sound title
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 6,
                      children: [
                        const DivineIcon(
                          icon: DivineIconName.musicNote,
                          color: VineTheme.vineGreen,
                          size: 18,
                        ),
                        Flexible(
                          child: Text(
                            soundTitle,
                            // Fixed light text: the backdrop here is a video
                            // frame, not a palette surface.
                            style: VineTheme.labelLargeFont(
                              color: VineTheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Balances the leading close button so the title stays
                  // optically centred.
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
