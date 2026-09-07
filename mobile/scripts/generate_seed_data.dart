// ABOUTME: Script to generate bundled seed data from relay.divine.video.
// ABOUTME: Fetches Editor's Picks, popular videos, profiles, and metrics.
//
// USAGE: dart run scripts/generate_seed_data.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const String editorPicksEventId =
    '5e2797304dda04159f8f9f6c36cc5d7f473abe3931f21d7b68fed1ab6a04db3a';
const String relayUrl = 'wss://relay.divine.video';
const int targetVideoCount = 250;
const int maxQueryVideos = 1000;

Future<void> main() async {
  print('[SEED GEN] Connecting to $relayUrl...');

  try {
    final relay = await NostrRelay.connect(relayUrl);
    print('[SEED GEN] ✅ Connected');

    // Step 1: Fetch Editor's Picks curation list (kind 30005)
    print("[SEED GEN] Fetching Editor's Picks curation list...");
    print('[SEED GEN] Looking for event ID: $editorPicksEventId');

    // Try multiple queries to find the curation list
    var editorPicksEvents = await relay.query({
      'kinds': [30005],
      'ids': [editorPicksEventId],
    });

    // If not found by ID, try querying all kind 30005 events
    if (editorPicksEvents.isEmpty) {
      print(
        '[SEED GEN] Event not found by ID, querying all kind 30005 events...',
      );
      editorPicksEvents = await relay.query({
        'kinds': [30005],
        'limit': 100,
      });
      print(
        '[SEED GEN] Found ${editorPicksEvents.length} kind 30005 events total',
      );

      // Filter for the specific event ID
      editorPicksEvents = editorPicksEvents
          .where((e) => e['id'] == editorPicksEventId)
          .toList();
      if (editorPicksEvents.isNotEmpty) {
        print("[SEED GEN] ✅ Found Editor's Picks in full query results");
      } else {
        // Try to find any "Editor's Picks" by title
        for (final event in editorPicksEvents) {
          final tags = event['tags'] as List;
          for (final tag in tags) {
            if (tag is List &&
                tag.length >= 2 &&
                tag[0].toString() == 'title' &&
                tag[1].toString().toLowerCase().contains('editor')) {
              print("[SEED GEN] ✅ Found Editor's Picks by title match");
              editorPicksEvents = [event];
              break;
            }
          }
          if (editorPicksEvents.length == 1) break;
        }
      }
    }

    Map<String, dynamic>? editorPicksEvent;
    final List<String> editorPicksVideoIds = [];

    if (editorPicksEvents.isNotEmpty) {
      editorPicksEvent = editorPicksEvents.first;
      print(
        "[SEED GEN] ✅ Found Editor's Picks curation list (kind ${editorPicksEvent['kind']})",
      );

      // Parse video IDs from 'a' and 'e' tags
      final tags = editorPicksEvent['tags'] as List;
      for (final tag in tags) {
        if (tag is! List || tag.isEmpty) continue;
        final tagName = tag[0].toString();
        final tagValue = tag.length > 1 ? tag[1].toString() : '';

        if (tagName == 'a') {
          // Addressable reference: "kind:pubkey:d-tag"
          editorPicksVideoIds.add(tagValue);
        } else if (tagName == 'e') {
          // Direct event ID reference
          editorPicksVideoIds.add(tagValue);
        }
      }

      print(
        "[SEED GEN] 📋 Found ${editorPicksVideoIds.length} video references in Editor's Picks",
      );
    } else {
      print("[SEED GEN] ⚠️ WARNING: Editor's Picks list not found!");
      print('[SEED GEN] Will proceed with only top videos by loop count...');
    }

    // Step 2: Fetch Editor's Picks videos (if we have any)
    final List<Map<String, dynamic>> editorPicksVideos = [];
    if (editorPicksVideoIds.isNotEmpty) {
      print("[SEED GEN] Fetching Editor's Picks videos...");

      // Separate direct IDs from addressable references
      final directIds = <String>[];
      final addressableRefs = <String>[];

      for (final id in editorPicksVideoIds) {
        if (id.contains(':')) {
          addressableRefs.add(id);
        } else {
          directIds.add(id);
        }
      }

      // Fetch direct IDs
      if (directIds.isNotEmpty) {
        final directEvents = await relay.query({
          'kinds': [34236, 22],
          'ids': directIds,
        });
        editorPicksVideos.addAll(directEvents);
        print(
          "[SEED GEN] ✅ Fetched ${directEvents.length} direct Editor's Picks videos",
        );
      }

      // For addressable references, we query all videos and filter manually
      // This is a limitation of the simple query approach
      if (addressableRefs.isNotEmpty) {
        print(
          '[SEED GEN] ⚠️ Note: ${addressableRefs.length} addressable references require manual filtering',
        );
      }

      print(
        "[SEED GEN] ✅ Total Editor's Picks videos fetched: ${editorPicksVideos.length}",
      );
    }

    // Step 3: Query for additional popular videos to fill up to target total
    print(
      '[SEED GEN] Need ${targetVideoCount - editorPicksVideos.length} more videos to reach target of $targetVideoCount',
    );
    print('[SEED GEN] Querying for top videos by loop count...');

    final allVideos = await relay.query({
      'kinds': [34236],
      'limit': maxQueryVideos,
    });
    print('[SEED GEN] Found ${allVideos.length} total videos');

    // Filter videos with loop count and sort by loop count descending
    final videosWithLoops = allVideos.where((e) {
      final tags = e['tags'] as List;
      for (final tag in tags) {
        if (tag is List &&
            tag.isNotEmpty &&
            tag.length >= 2 &&
            tag[0].toString() == 'loops') {
          final loopCount = int.tryParse(tag[1].toString());
          return loopCount != null && loopCount > 0;
        }
      }
      return false;
    }).toList();

    print(
      '[SEED GEN] Found ${videosWithLoops.length} videos with loop count > 0',
    );

    videosWithLoops.sort((a, b) {
      int getLoopCount(Map<String, dynamic> event) {
        final tags = event['tags'] as List;
        for (final tag in tags) {
          if (tag is List &&
              tag.isNotEmpty &&
              tag.length >= 2 &&
              tag[0].toString() == 'loops') {
            return int.tryParse(tag[1].toString()) ?? 0;
          }
        }
        return 0;
      }

      return getLoopCount(b).compareTo(getLoopCount(a));
    });

    // Combine Editor's Picks with top popular videos
    final selectedVideos =
        <String, Map<String, dynamic>>{}; // Deduplicate by ID

    // Add Editor's Picks first (priority)
    for (final video in editorPicksVideos) {
      selectedVideos[video['id'] as String] = video;
    }

    // Fill remaining slots with popular videos
    for (final video in videosWithLoops) {
      if (selectedVideos.length >= targetVideoCount) break;
      selectedVideos[video['id'] as String] = video;
    }

    final finalVideos = selectedVideos.values.toList();
    print('[SEED GEN] ✅ Selected ${finalVideos.length} total videos');
    print("[SEED GEN]    - Editor's Picks: ${editorPicksVideos.length} videos");
    print(
      '[SEED GEN]    - Popular videos: ${finalVideos.length - editorPicksVideos.length} videos',
    );

    // Step 4: Extract unique author pubkeys
    final authorPubkeys = finalVideos
        .map((e) => e['pubkey'] as String)
        .toSet()
        .toList();
    print('[SEED GEN] Found ${authorPubkeys.length} unique authors');

    // Step 5: Query for author profiles (kind 0)
    // Batch the queries because querying 196 authors at once might timeout
    print(
      '[SEED GEN] Querying for author profiles (${authorPubkeys.length} authors)...',
    );
    final profileEvents = <Map<String, dynamic>>[];
    const batchSize = 50;

    for (var i = 0; i < authorPubkeys.length; i += batchSize) {
      final batch = authorPubkeys.skip(i).take(batchSize).toList();
      print(
        '[SEED GEN]   Fetching profiles ${i + 1}-${i + batch.length} of ${authorPubkeys.length}...',
      );
      final batchProfiles = await relay.query({
        'kinds': [0],
        'authors': batch,
      }, timeoutSeconds: 20);
      profileEvents.addAll(batchProfiles);
      print(
        '[SEED GEN]   Found ${batchProfiles.length} profiles in this batch',
      );
    }

    print('[SEED GEN] Found ${profileEvents.length} total profiles');

    // Step 6: Generate JSON bundle
    print('[SEED GEN] Generating JSON bundle...');
    final bundle = _generateBundle(
      finalVideos,
      profileEvents,
      editorPicksEvent,
      editorPicksVideos.length,
    );

    // Step 7: Write to file
    final outputFile = File('assets/seed_data/seed_events.json');
    await outputFile.create(recursive: true);
    await outputFile.writeAsString(jsonEncode(bundle));

    final fileSize = await outputFile.length();
    final fileSizeMB = fileSize / (1024 * 1024);

    print('[SEED GEN] ✅ Generated seed data: ${outputFile.path}');
    print('[SEED GEN]    Videos: ${finalVideos.length}');
    print('[SEED GEN]    Profiles: ${profileEvents.length}');
    print('[SEED GEN]    Curation list: ${editorPicksEvent != null ? 1 : 0}');
    print(
      '[SEED GEN]    Total events: ${finalVideos.length + profileEvents.length + (editorPicksEvent != null ? 1 : 0)}',
    );
    print(
      '[SEED GEN]    File size: ${fileSizeMB.toStringAsFixed(2)} MB ($fileSize bytes)',
    );

    await relay.close();
  } catch (e, stack) {
    print('[SEED GEN] ❌ Error: $e');
    print('[SEED GEN] Stack: $stack');
    exit(1);
  }
}

Map<String, dynamic> _generateBundle(
  List<Map<String, dynamic>> videos,
  List<Map<String, dynamic>> profiles,
  Map<String, dynamic>? curationList,
  int editorPicksCount,
) {
  final nowIso = DateTime.now().toIso8601String();
  final events = <Map<String, dynamic>>[
    if (curationList != null) _eventJson(curationList),
    ...videos.map(_eventJson),
    ...profiles.map(_eventJson),
  ];
  final profileRows = <Map<String, dynamic>>[];
  for (final profile in profiles) {
    final row = _profileJson(profile, generatedAtIso: nowIso);
    if (row != null) profileRows.add(row);
  }
  final metrics = videos
      .map((v) => _metricsJson(v, updatedAtIso: nowIso))
      .toList();
  return {
    'meta': {
      'generated_at': nowIso,
      'videos': videos.length,
      'editor_picks': editorPicksCount,
      'popular': videos.length - editorPicksCount,
      'profiles': profiles.length,
      'curation_lists': curationList != null ? 1 : 0,
    },
    'events': events,
    'profiles': profileRows,
    'metrics': metrics,
  };
}

Map<String, dynamic> _eventJson(Map<String, dynamic> event) {
  return {
    'id': event['id'],
    'pubkey': event['pubkey'],
    'created_at': event['created_at'],
    'kind': event['kind'],
    'tags': event['tags'],
    'content': event['content'],
    'sig': event['sig'],
  };
}

Map<String, dynamic>? _profileJson(
  Map<String, dynamic> event, {
  required String generatedAtIso,
}) {
  try {
    final profile =
        jsonDecode(event['content'] as String) as Map<String, dynamic>;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (event['created_at'] as int) * 1000,
    );
    return {
      'pubkey': event['pubkey'],
      'display_name': profile['display_name'],
      'name': profile['name'],
      'picture': profile['picture'],
      'banner': profile['banner'],
      'about': profile['about'],
      'website': profile['website'],
      'nip05': profile['nip05'],
      'lud16': profile['lud16'],
      'lud06': profile['lud06'],
      'raw_data': event['content'],
      'created_at': createdAt.toIso8601String(),
      'event_id': event['id'],
      'last_fetched': generatedAtIso,
    };
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _metricsJson(
  Map<String, dynamic> event, {
  required String updatedAtIso,
}) {
  final tags = event['tags'] as List;
  return {
    'event_id': event['id'],
    'loop_count': _tagInt(tags, 'loops'),
    'likes': _tagInt(tags, 'likes'),
    'views': _tagInt(tags, 'views'),
    'comments': _tagInt(tags, 'comments'),
    'updated_at': updatedAtIso,
  };
}

int? _tagInt(List tags, String tagName) {
  for (final tag in tags) {
    if (tag is List && tag.length >= 2 && tag[0].toString() == tagName) {
      return int.tryParse(tag[1].toString());
    }
  }
  return null;
}

/// Simple Nostr relay client using WebSocket
class NostrRelay {
  final WebSocket _socket;
  final Map<String, List<Map<String, dynamic>>> _responses = {};
  int _subCounter = 0;

  NostrRelay._(this._socket) {
    _socket.listen(_handleMessage);
  }

  static Future<NostrRelay> connect(String url) async {
    final socket = await WebSocket.connect(url);
    return NostrRelay._(socket);
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as List;
      if (data.isEmpty) return;

      final type = data[0] as String;
      if (type == 'EVENT' && data.length >= 3) {
        final subId = data[1] as String;
        final event = data[2] as Map<String, dynamic>;
        _responses.putIfAbsent(subId, () => []).add(event);
      }
    } catch (e) {
      // Ignore malformed messages
    }
  }

  Future<List<Map<String, dynamic>>> query(
    Map<String, dynamic> filter, {
    int timeoutSeconds = 15,
  }) async {
    final subId = 'sub_${_subCounter++}';
    _responses[subId] = [];

    // Send REQ message
    final reqMessage = jsonEncode(['REQ', subId, filter]);
    _socket.add(reqMessage);

    // Wait for EOSE (or timeout)
    await Future.delayed(Duration(seconds: timeoutSeconds));

    // Send CLOSE message
    final closeMessage = jsonEncode(['CLOSE', subId]);
    _socket.add(closeMessage);

    final results = _responses[subId] ?? [];
    _responses.remove(subId);
    return results;
  }

  Future<void> close() async {
    await _socket.close();
  }
}
