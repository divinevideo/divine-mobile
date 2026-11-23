// ABOUTME: Platform-agnostic database connection interface
// ABOUTME: Uses conditional exports to select native or web implementation

export 'connection_stub.dart'
    if (dart.library.io) 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
export 'hot_journal_recovery_models.dart';
