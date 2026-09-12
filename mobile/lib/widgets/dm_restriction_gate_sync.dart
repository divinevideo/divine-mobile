// ABOUTME: Always-mounted app-shell listener (#176) that pumps DM-restriction
// ABOUTME: flips into the inbox gate so the list and unread badge re-filter.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';

/// Pushes a re-filter tick into [protectedMinorInboxGateProvider] whenever the
/// DM-restriction status flips (mid-session approval/revocation, dev toggle).
///
/// Lives at the app shell (always mounted) because a provider-internal
/// `ref.listen` is paused while its provider is inactive (Riverpod 3 activity
/// semantics): with no DM surface mounted nothing would pump the flip, and the
/// app-shell unread badge would stay stale until the next DM event. A widget
/// listener is always active.
class DmRestrictionGateSync extends ConsumerWidget {
  /// Creates the sync wrapper around [child].
  const DmRestrictionGateSync({required this.child, super.key});

  /// The subtree to wrap; rendered unchanged.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(isDmRestrictedProvider, (previous, next) {
      if (previous != next) {
        ref.read(protectedMinorInboxGateProvider).notifyRestrictionChanged();
      }
    });
    return child;
  }
}
