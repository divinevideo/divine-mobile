// MPL-2.0
/// Repository layer: relay gateway + account-scoped store ports.
/// Concord data lives under its own `concord:` key prefix, never in DM
/// tables, so existing DM behavior cannot be corrupted.
library;

export 'src/concord_repository.dart';
export 'src/sealed_chat_transport.dart';
export 'src/sealed_transport.dart';
export 'src/websocket_relay.dart';
