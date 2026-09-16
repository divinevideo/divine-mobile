// ABOUTME: Connects Listenable services to Riverpod provider lifecycles
// ABOUTME: Guarantees every provider listener is removed when its ref disposes

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registers [listener] with [source] for the lifetime of [ref].
void listenForProviderLifetime(
  Ref ref,
  Listenable source,
  VoidCallback listener,
) {
  source.addListener(listener);
  ref.onDispose(() => source.removeListener(listener));
}
