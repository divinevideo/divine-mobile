// ABOUTME: Reusable mixin for Nostr list fetching screens (followers/following)
// ABOUTME: Provides common state management and UI building patterns for user list screens

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Mixin providing common state management and UI patterns for Nostr list screens.
///
/// Used by FollowersScreen and FollowingScreen to eliminate code duplication.
/// Provides:
/// - State variables for loading/error/list states
/// - Helper methods for state updates
/// - UI building patterns for loading/error/empty/list states
/// - Loading timeout logic
///
/// Usage:
/// ```dart
/// class _MyListScreenState extends ConsumerState<MyListScreen>
///     with NostrListFetchMixin {
///
///   @override
///   void initState() {
///     super.initState();
///     loadList(); // Calls your implemented fetchList method
///   }
///
///   @override
///   Future<void> fetchList() async {
///     // Your Nostr subscription logic with proper timeout handling
///     final subscription = nostrService.subscribe(...);
///
///     subscription.timeout(Duration(seconds: 5), onTimeout: (sink) {
///       setError('Failed to connect to relay server');
///       sink.close();
///     }).listen(...);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: buildAppBar(context, 'My List'),
///       body: buildListBody(
///         context,
///         userList,
///         onNavigateToProfile,
///         'No users found',
///       ),
///     );
///   }
/// }
/// ```
mixin NostrListFetchMixin<T extends StatefulWidget> on State<T> {
  /// List of user pubkeys
  List<String> get userList;
  set userList(List<String> value);

  /// Loading state
  bool get isLoading;
  set isLoading(bool value);

  /// Error message
  String? get error;
  set error(String? value);

  /// Fetch the list from Nostr (must be implemented by the using class)
  Future<void> fetchList();

  /// Start loading state
  void startLoading() {
    if (mounted) {
      setState(() {
        isLoading = true;
        error = null;
      });
    }
  }

  /// Set error state
  void setError(String errorMessage) {
    if (mounted) {
      setState(() {
        error = errorMessage;
        isLoading = false;
      });
    }
  }

  /// Complete loading state
  void completeLoading() {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Load the list with error handling
  Future<void> loadList() async {
    try {
      startLoading();
      await fetchList();
    } catch (e) {
      setError('Failed to load list');
    }
  }

  /// Build AppBar for the list screen
  AppBar buildAppBar(BuildContext context, String title) {
    return AppBar(
      backgroundColor: VineTheme.vineGreen,
      foregroundColor: Colors.white,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// Build body with loading/error/empty/list states
  Widget buildListBody(
    BuildContext context,
    List<String> pubkeys,
    void Function(String pubkey) onNavigateToProfile, {
    String emptyMessage = 'No users found',
    IconData emptyIcon = Icons.people_outline,
  }) {
    // Loading state
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    // Error state
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              error!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadList,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (pubkeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // List state
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pubkeys.length,
      itemBuilder: (context, index) {
        final pubkey = pubkeys[index];
        return UserProfileTile(
          pubkey: pubkey,
          onTap: () => onNavigateToProfile(pubkey),
        );
      },
    );
  }
}
