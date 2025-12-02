import 'utils/string_util.dart';

/// Representation of a Nostr event subscription.
class Subscription {
  final String _id;
  List<Map<String, dynamic>> filters;
  Function onEvent;

  /// Subscription ID
  String get id => _id;

  Subscription(this.filters, this.onEvent, [String? id])
      : _id = id ?? StringUtil.rndNameStr(16);

  /// Returns the subscription as a Nostr subscription request in JSON format
  List<dynamic> toJson() {
    List<dynamic> json = ["REQ", _id];

    for (Map<String, dynamic> filter in filters) {
      json.add(filter);
    }

    return json;
  }
}
