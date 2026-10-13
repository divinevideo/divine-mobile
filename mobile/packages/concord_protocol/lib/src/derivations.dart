// MPL-2.0
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Deterministic stream/channel derivations (pinned for fixture interop).
String deriveStreamId(String communityId, String channelId) => sha256
    .convert(utf8.encode('concord/stream/v1:$communityId:$channelId'))
    .toString();
String deriveMessageId(
  String streamId,
  String author,
  int createdAt,
  String body,
) => sha256
    .convert(utf8.encode('concord/msg/v1:$streamId:$author:$createdAt:$body'))
    .toString();
