import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// The copyright notice of every video editor text font, keyed by family name
/// and grouped under the SPDX identifier of the license the family ships
/// under.
///
/// Families bundled in the app binary are credited by `font_licenses.dart`
/// instead, so each font appears on the license page once.
const _editorFontNoticesAsset = 'assets/licenses/editor_fonts.json';

/// The license text for each group in [_editorFontNoticesAsset].
///
/// These are the only licenses the editor accepts: each permits commercial use
/// and leaves text rendered into a video unrestricted.
const _editorFontLicenseTexts = <String, String>{
  'OFL-1.1': 'assets/licenses/OFL-1.1.txt',
  'Apache-2.0': 'assets/licenses/Apache-2.0.txt',
  'UFL-1.0': 'assets/licenses/UFL-1.0.txt',
};

/// Yields one [LicenseEntry] per editor text font, pairing the family's
/// copyright notice with the full text of its license.
///
/// The editor fonts are fetched at runtime by google_fonts rather than
/// bundled, and its README leaves registering their licenses to the app.
///
/// [bundle] is injectable so the entries can be exercised in tests without
/// touching the global [LicenseRegistry].
///
/// Throws a [StateError] when the notices name a license outside
/// [_editorFontLicenseTexts].
Stream<LicenseEntry> editorFontLicenseEntries(AssetBundle bundle) async* {
  final notices = jsonDecode(
    await bundle.loadString(_editorFontNoticesAsset),
  ) as Map<String, dynamic>;
  for (final MapEntry(key: license, value: families) in notices.entries) {
    final licenseTextAsset = _editorFontLicenseTexts[license];
    if (licenseTextAsset == null) {
      throw StateError('Editor fonts may not ship under $license');
    }
    final licenseText = await bundle.loadString(licenseTextAsset);
    for (final MapEntry(key: family, value: notice)
        in (families as Map<String, dynamic>).entries) {
      yield LicenseEntryWithLineBreaks([family], '$notice\n\n$licenseText');
    }
  }
}

/// Registers the editor text fonts' licenses with the global
/// [LicenseRegistry].
///
/// Call once during startup, before the license page can be opened. The
/// collector is lazy: the license assets load only when the license page
/// enumerates the registry.
void registerEditorFontLicenses() {
  LicenseRegistry.addLicense(() => editorFontLicenseEntries(rootBundle));
}
