import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:openvine/bootstrap/bundled_licenses.dart';

/// The emoji images info stickers draw, under `assets/info_stickers/`, are
/// Fluent Emoji's 3D style. They are app assets, which Flutter's generated
/// NOTICES do not cover, so their MIT license is registered here.
const _fluentEmojiLicenses = <BundledLicense>[
  (
    packages: <String>['Fluent Emoji'],
    assetPath: 'assets/licenses/FluentEmoji-MIT.txt',
  ),
];

/// Yields the license of the bundled Fluent Emoji images.
Stream<LicenseEntry> fluentEmojiLicenseEntries(AssetBundle bundle) =>
    bundledLicenseEntries(bundle, _fluentEmojiLicenses);

/// Registers the Fluent Emoji license with the global [LicenseRegistry].
///
/// Registration is lazy: the asset loads only when the license page enumerates
/// the registry.
void registerFluentEmojiLicenses() {
  LicenseRegistry.addLicense(() => fluentEmojiLicenseEntries(rootBundle));
}
