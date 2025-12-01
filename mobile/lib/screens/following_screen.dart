// ABOUTME: Screen displaying list of users followed by the profile being viewed
// ABOUTME: Shows user profiles with follow/unfollow buttons and navigation to their profiles

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/mixins/nostr_list_fetch_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/utils/unified_logger.dart';

class FollowingScreen extends ConsumerStatefulWidget {
  const FollowingScreen({
    super.key,
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String displayName;

  @override
  ConsumerState<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends ConsumerState<FollowingScreen>
    with NostrListFetchMixin {
  // Mixin state variables
  List<String> _following = [];
  bool _isLoading = true;
  String? _error;

  @override
  List<String> get userList => _following;

  @override
  set userList(List<String> value) => _following = value;

  @override
  bool get isLoading => _isLoading;

  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  String? get error => _error;

  @override
  set error(String? value) => _error = value;

  @override
  void initState() {
    super.initState();
    loadList();
  }

  @override
  Future<void> fetchList() async {
    final socialService = ref.read(socialServiceProvider);

    // If viewing current user's following, use cached data
    final authService = ref.read(authServiceProvider);
    if (widget.pubkey == authService.currentPublicKeyHex) {
      final following = socialService.followingPubkeys;
      if (mounted) {
        setState(() {
          _following = following;
          completeLoading();
        });
      }
      return;
    }

    // Otherwise start streaming following list from Nostr
    await _fetchFollowingFromNostr(widget.pubkey);
  }

  Future<void> _fetchFollowingFromNostr(String pubkey) async {
    final nostrService = ref.read(nostrServiceProvider);

    // Subscribe to the user's kind 3 contact list events
    final subscription = nostrService.subscribeToEvents(
      filters: [
        nostr_sdk.Filter(
          authors: [pubkey],
          kinds: [3], // Contact lists
          limit: 1, // Get most recent only
        ),
      ],
    );

    // Apply timeout to detect relay connection issues
    final timeoutSubscription = subscription.timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        // No data received within 5 seconds - likely connection issue
        if (mounted && _following.isEmpty) {
          setError(
            'Failed to connect to relay server. Please check your connection and try again.',
          );
        } else {
          completeLoading();
        }
        sink.close();
      },
    );

    // Process events immediately as they arrive for real-time updates
    timeoutSubscription.listen(
      (event) {
        // Extract followed pubkeys from 'p' tags
        final newFollowing = <String>[];
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
            final followedPubkey = tag[1];
            if (!newFollowing.contains(followedPubkey)) {
              newFollowing.add(followedPubkey);
            }
          }
        }

        // Update UI immediately with the complete following list from this event
        if (mounted) {
          setState(() {
            _following = newFollowing;
            completeLoading(); // Stop loading as soon as we have the contact list
          });
        }
      },
      onError: (error) {
        Log.error(
          'Error in following subscription: $error',
          name: 'FollowingScreen',
          category: LogCategory.relay,
        );
        setError(
          'Failed to connect to relay server. Please check your connection and try again.',
        );
      },
      onDone: () {
        // Stream completed naturally
        if (mounted) {
          completeLoading();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: buildAppBar(context, '${widget.displayName}\'s Following'),
      body: buildListBody(
        context,
        _following,
        _navigateToProfile,
        emptyMessage: 'Not following anyone yet',
        emptyIcon: Icons.person_add_outlined,
      ),
    );
  }

  void _navigateToProfile(String pubkey) {
    context.goProfile(pubkey, 0);
  }
}
