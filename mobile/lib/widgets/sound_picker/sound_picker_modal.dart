// ABOUTME: Full-screen modal for selecting background sound for videos
// ABOUTME: Includes search bar, scrollable sound list, and None option

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/widgets/sound_picker/sound_list_item.dart';

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

  List<VineSound> get _filteredSounds {
    if (_searchQuery.trim().isEmpty) {
      return widget.sounds;
    }

    return widget.sounds
        .where((sound) => sound.matchesSearch(_searchQuery))
        .toList();
  }

  void _handleSoundTap(String? soundId) {
    widget.onSoundSelected(soundId);
  }

  void _handlePlayPause(String soundId) {
    setState(() {
      _playingSoundId = _playingSoundId == soundId ? null : soundId;
    });
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
                ListTile(
                  onTap: () => _handleSoundTap(null),
                  leading: const Icon(
                    Icons.music_off,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'None',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'No background sound',
                    style: TextStyle(color: Colors.grey),
                  ),
                  trailing: widget.selectedSoundId == null
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        )
                      : null,
                ),
                const Divider(color: Colors.grey),
                ..._filteredSounds.map((sound) {
                  return SoundListItem(
                    sound: sound,
                    isSelected: widget.selectedSoundId == sound.id,
                    isPlaying: _playingSoundId == sound.id,
                    onTap: () => _handleSoundTap(sound.id),
                    onPlayPause: () => _handlePlayPause(sound.id),
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
