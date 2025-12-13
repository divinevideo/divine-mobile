// ABOUTME: Full-screen modal for selecting background sound for videos
// ABOUTME: Includes search bar, scrollable sound list, import from device, and None option

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/widgets/sound_picker/sound_list_item.dart';
import 'package:openvine/utils/unified_logger.dart';

class SoundPickerModal extends ConsumerStatefulWidget {
  const SoundPickerModal({
    required this.sounds,
    required this.selectedSoundId,
    required this.onSoundSelected,
    super.key,
  });

  final List<VineSound> sounds;
  final String? selectedSoundId;
  final ValueChanged<String?> onSoundSelected;

  @override
  ConsumerState<SoundPickerModal> createState() => _SoundPickerModalState();
}

class _SoundPickerModalState extends ConsumerState<SoundPickerModal> {
  String _searchQuery = '';
  String? _playingSoundId;
  bool _isImporting = false;
  List<VineSound> _allSounds = [];
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _allSounds = List.from(widget.sounds);
    _audioPlayer = AudioPlayer();

    // Listen for playback completion to reset UI
    _audioPlayer?.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _playingSoundId = null);
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  List<VineSound> get _filteredSounds {
    if (_searchQuery.trim().isEmpty) {
      return _allSounds;
    }

    return _allSounds
        .where((sound) => sound.matchesSearch(_searchQuery))
        .toList();
  }

  void _handleSoundTap(String? soundId) {
    // Stop any playing audio when selecting
    _stopPlayback();
    widget.onSoundSelected(soundId);
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer?.stop();
    if (mounted) {
      setState(() => _playingSoundId = null);
    }
  }

  Future<void> _handlePlayPause(String soundId) async {
    if (_playingSoundId == soundId) {
      // Currently playing this sound - stop it
      await _stopPlayback();
    } else {
      // Play a different sound
      await _stopPlayback();

      final sound = _allSounds.firstWhere((s) => s.id == soundId);

      try {
        Log.info(
          '🔊 Loading sound: ${sound.title} from ${sound.assetPath}',
          name: 'SoundPickerModal',
        );

        String filePath;

        // Check if it's a file path (custom sound) or asset path (bundled)
        if (sound.assetPath.startsWith('/')) {
          // Custom sound - use file path directly
          filePath = sound.assetPath;
          Log.info('🔊 Using custom file: $filePath', name: 'SoundPickerModal');
        } else {
          // Bundled asset - copy to temp file for reliable playback on desktop
          final tempDir = await getTemporaryDirectory();
          final extension = sound.assetPath.split('.').last;
          filePath = '${tempDir.path}/preview_${sound.id}.$extension';

          // Only copy if not already cached
          final tempFile = File(filePath);
          if (!await tempFile.exists()) {
            Log.info(
              '🔊 Loading asset: ${sound.assetPath}',
              name: 'SoundPickerModal',
            );
            try {
              final assetData = await rootBundle.load(sound.assetPath);
              Log.info(
                '🔊 Asset loaded: ${assetData.lengthInBytes} bytes',
                name: 'SoundPickerModal',
              );
              await tempFile.writeAsBytes(assetData.buffer.asUint8List());
              Log.info(
                '🔊 Cached asset to: $filePath',
                name: 'SoundPickerModal',
              );
            } catch (assetError) {
              Log.error(
                '🔊 Failed to load asset ${sound.assetPath}: $assetError',
                name: 'SoundPickerModal',
              );
              rethrow;
            }
          } else {
            Log.info('🔊 Using cached file: $filePath', name: 'SoundPickerModal');
          }
        }

        // Verify file exists
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File does not exist: $filePath');
        }
        Log.info(
          '🔊 File exists, size: ${await file.length()} bytes',
          name: 'SoundPickerModal',
        );

        await _audioPlayer?.setFilePath(filePath);
        Log.info('🔊 Audio source set', name: 'SoundPickerModal');

        setState(() => _playingSoundId = soundId);
        await _audioPlayer?.play();

        Log.info(
          '🔊 Playing sound: ${sound.title}',
          name: 'SoundPickerModal',
        );
      } catch (e, stackTrace) {
        Log.error(
          '🔊 Failed to play sound ${sound.assetPath}: $e\n$stackTrace',
          name: 'SoundPickerModal',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not play: ${sound.title}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleImportAudio() async {
    setState(() => _isImporting = true);

    try {
      // Define audio file types for file_selector
      const audioTypeGroup = XTypeGroup(
        label: 'Audio',
        extensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'],
        mimeTypes: ['audio/*'],
      );

      // Pick audio file using file_selector (works on macOS, iOS, Android)
      final file = await openFile(acceptedTypeGroups: [audioTypeGroup]);

      if (file == null) {
        setState(() => _isImporting = false);
        return;
      }

      final sourcePath = file.path;
      final fileName = file.name;

      // Get audio duration using just_audio
      final player = AudioPlayer();
      Duration? duration;
      try {
        duration = await player.setFilePath(sourcePath);
      } finally {
        await player.dispose();
      }

      if (duration == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read audio duration'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isImporting = false);
        return;
      }

      // Copy file to app storage
      final appDir = await getApplicationDocumentsDirectory();
      final customSoundsDir = Directory('${appDir.path}/custom_sounds');
      if (!await customSoundsDir.exists()) {
        await customSoundsDir.create(recursive: true);
      }

      final soundId = 'custom_${const Uuid().v4()}';
      final extension = fileName.split('.').last;
      final destPath = '${customSoundsDir.path}/$soundId.$extension';
      await File(sourcePath).copy(destPath);

      // Extract title from filename (remove extension)
      final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

      // Create VineSound and add to library
      final customSound = VineSound(
        id: soundId,
        title: title,
        assetPath: destPath,
        duration: duration,
        artist: 'My Audio',
        tags: ['custom', 'imported'],
      );

      final soundService = await ref.read(soundLibraryServiceProvider.future);
      await soundService.addCustomSound(customSound);

      // Update local list
      setState(() {
        _allSounds = [..._allSounds, customSound];
        _isImporting = false;
      });

      Log.info(
        '🔊 Imported custom sound: $title (${duration.inSeconds}s)',
        name: 'SoundPickerModal',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$title" to your sounds'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Log.error(
        '🔊 Failed to import audio: $e',
        name: 'SoundPickerModal',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Select Sound',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _isImporting
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Import audio from device',
                  onPressed: _handleImportAudio,
                ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search sounds...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
              },
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Container(
                  color: widget.selectedSoundId == null
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.transparent,
                  child: ListTile(
                    onTap: () => _handleSoundTap(null),
                    leading: Icon(
                      Icons.music_off,
                      color: widget.selectedSoundId == null ? Colors.green : Colors.white,
                      size: 32,
                    ),
                    title: Text(
                      'None',
                      style: TextStyle(
                        color: widget.selectedSoundId == null ? Colors.green : Colors.white,
                        fontWeight: widget.selectedSoundId == null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      'No background sound',
                      style: TextStyle(color: Colors.grey),
                    ),
                    trailing: widget.selectedSoundId == null
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 28,
                          )
                        : null,
                  ),
                ),
                const Divider(color: Colors.grey),
                ..._filteredSounds.map((sound) {
                  return SoundListItem(
                    sound: sound,
                    isSelected: widget.selectedSoundId == sound.id,
                    isPlaying: _playingSoundId == sound.id,
                    onTap: () => _handleSoundTap(sound.id),
                    onPlayPause: () async => _handlePlayPause(sound.id),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
