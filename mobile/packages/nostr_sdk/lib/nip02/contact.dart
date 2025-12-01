import '../client_utils/keys.dart';

/// A single contact for use with [ContactList]
class Contact {
  /// Creates a new [Contact].
  ///
  /// [publicKey] is a public key to identify the contact.
  /// [url] is a relay URL where events from [publicKey] can be found.
  /// [petname] is a local name (nickname) for the profile.
  ///
  /// An [ArgumentError] is thrown if [publicKey] is invalid or if [url] is not
  /// a valid relay URL.
  Contact({required this.publicKey, this.url = '', this.petname = ''}) {
    if (!keyIsValid(publicKey)) {
      throw ArgumentError.value(publicKey, 'publicKey', 'Invalid key');
    }
  }

  /// The contact's public key.
  final String publicKey;

  /// A known good relay URL for the contact.
  final String url;

  /// The contact's petname (nickname).
  final String petname;
}
