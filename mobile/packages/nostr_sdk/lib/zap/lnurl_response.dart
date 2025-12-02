class LnurlResponse {
  String? callback;
  int? maxSendable;
  int? minSendable;
  String? metadata;
  int? commentAllowed;
  String? tag;
  bool? allowsNostr;
  String? nostrPubkey;

  LnurlResponse(
      {this.callback,
      this.maxSendable,
      this.minSendable,
      this.metadata,
      this.commentAllowed,
      this.tag,
      this.allowsNostr,
      this.nostrPubkey});

  LnurlResponse.fromJson(Map<String, dynamic> json) {
    callback = json['callback'];
    maxSendable = json['maxSendable'];
    minSendable = json['minSendable'];
    metadata = json['metadata'];
    commentAllowed = json['commentAllowed'];
    tag = json['tag'];
    allowsNostr = json['allowsNostr'];
    nostrPubkey = json['nostrPubkey'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callback'] = callback;
    data['maxSendable'] = maxSendable;
    data['minSendable'] = minSendable;
    data['metadata'] = metadata;
    data['commentAllowed'] = commentAllowed;
    data['tag'] = tag;
    data['allowsNostr'] = allowsNostr;
    data['nostrPubkey'] = nostrPubkey;
    return data;
  }
}
