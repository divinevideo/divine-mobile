// ABOUTME: Persists the viewer's "only show capture-verified videos" choice.
// ABOUTME: Independent of the Divine-hosted filter; both can apply at once.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preference for only showing capture-verified videos.
///
/// This is the provenance axis, and it is deliberately separate from
/// [DivineHostFilterService]'s hosting axis. Where a video is served from
/// says who can moderate or take it down; whether it carries a capture
/// chain (C2PA / ProofMode) says whether it can be traced back to a camera.
/// A creator can publish verified media on their own host, and unverified
/// media can sit on ours, so neither answers the other's question.
///
/// Defaults to `false`. Enabling it by default would hide every upload
/// without a capture chain from users who never chose it — roughly an
/// eighth of modern uploads at the time of writing.
///
/// Archive content is exempt at the filter site, not here: original Vine
/// videos predate content credentials by a decade and can never satisfy a
/// provenance check.
class VideoProvenanceFilterService extends ChangeNotifier {
  VideoProvenanceFilterService(this._prefs)
    : _showVerifiedOnly = _prefs.getBool(showVerifiedOnlyStorageKey) ?? false;

  /// Public so `UserDataCleanupService` can clear it by reference.
  /// A copied literal cannot detect that this key was renamed (#8314).
  static const String showVerifiedOnlyStorageKey = 'show_verified_only';

  final SharedPreferences _prefs;
  bool _showVerifiedOnly;

  bool get showVerifiedOnly => _showVerifiedOnly;

  Future<void> setShowVerifiedOnly(bool value) async {
    if (_showVerifiedOnly == value) return;

    await _prefs.setBool(showVerifiedOnlyStorageKey, value);
    _showVerifiedOnly = value;
    notifyListeners();
  }
}
