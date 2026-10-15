// ABOUTME: Persists followed hashtags under the authenticated account's full key.
// ABOUTME: Reports failed writes instead of publishing unconfirmed follows.
import 'package:hashtag_subscription_repository/hashtag_subscription_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHashtagSubscriptionStore
    implements HashtagSubscriptionStore {
  SharedPreferencesHashtagSubscriptionStore({
    required SharedPreferences prefs,
    required String pubkey,
  }) : _prefs = prefs,
       _key = 'followed_hashtags_$pubkey';

  final SharedPreferences _prefs;
  final String _key;

  @override
  Future<String?> read() async {
    final value = _prefs.get(_key);
    if (value != null && value is! String) {
      throw const FormatException('Invalid saved hashtag list');
    }
    return value as String?;
  }

  @override
  Future<void> write(String value) async {
    if (!await _prefs.setString(_key, value)) {
      throw Exception('Could not save followed hashtags');
    }
  }
}
