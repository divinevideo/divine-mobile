// ABOUTME: Navigator keys for the root navigator and the four shell branches
// ABOUTME: Each bottom-nav tab is a StatefulShellBranch with its own navigator

import 'package:flutter/widgets.dart';

/// Navigator keys for the app's root navigator and the four bottom-nav
/// branches of the [StatefulShellRoute].
///
/// Each branch key identifies the [Navigator] built for that tab. Because
/// `StatefulShellRoute` keeps every branch's navigator alive, these keys let
/// each tab preserve its own navigation stack and state while inactive.
class NavigatorKeys {
  /// Root navigator key for the entire app.
  static final root = GlobalKey<NavigatorState>(debugLabel: 'root');

  /// Home tab branch navigator key.
  static final home = GlobalKey<NavigatorState>(debugLabel: 'home');

  /// Explore tab branch navigator key (grid + feed routes).
  static final explore = GlobalKey<NavigatorState>(debugLabel: 'explore');

  /// Inbox tab branch navigator key (inbox + notifications routes).
  static final inbox = GlobalKey<NavigatorState>(debugLabel: 'inbox');

  /// Profile tab branch navigator key (profile routes).
  static final profile = GlobalKey<NavigatorState>(debugLabel: 'profile');
}
