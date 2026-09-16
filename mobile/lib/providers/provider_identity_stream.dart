// ABOUTME: Exposes a provider's successive values as a seeded broadcast stream
// ABOUTME: so app-shell blocs can re-point captured dependencies (#6480).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/providers/provider_detached_future.dart';

/// Wraps [source] in a provider whose value is a stream of [source]'s
/// successive values, seeded with the value current at subscribe time.
///
/// This exists for a narrow case: a bloc created once in an app-shell
/// `BlocProvider` whose `create:` captures a Riverpod dependency that later
/// changes identity (auth flip, account switch, sign-out, `ref.invalidate`).
/// The two cheaper cures are both closed off in that position:
///
/// * A record-typed `ValueKey` on the `BlocProvider` — shipped and **reverted**
///   in #4918. Keying a provider that sits above `MaterialApp.router` remounts
///   the router and shell on every startup and every account switch.
/// * A sync `ConsumerWidget` calling `context.read<Bloc>()` from a Riverpod
///   listener (`AppShellBadgeScope`) — needs `lazy: false` to avoid the #6115
///   re-entrant lazy create, which defeats feature-flag gating that relies on
///   the bloc staying lazy.
///
/// So the bloc subscribes to the change instead — `state_management.md` rule
/// exception #2. Inject the stream at `create:` and re-point the field on each
/// emission.
///
/// Subscribers receive the **current** value first, then every later change.
/// That matters because blocs typically subscribe from an event handler rather
/// than their constructor, and a plain broadcast stream would drop the seed.
/// A subscriber that already holds the current instance should guard with
/// `identical` — the seed is delivered unconditionally.
///
/// Change detection is Riverpod's, i.e. `==`. The dependencies this is used
/// with do not override `==`, so equality falls through to identity, which is
/// exactly the signal we want. **If one ever gains value equality this goes
/// silent** — the same failure mode `state_management.md` documents for
/// record-typed `ValueKey`s.
///
/// Returns a plain (non-codegen) `Provider`, which is not auto-disposed — the
/// container-level listener below has to stay armed for the container's whole
/// life, not just while someone holds a subscription. Do not convert this to a
/// `@riverpod`-generated provider without re-checking that.
Provider<Stream<T>> identityStreamOf<T>(ProviderListenable<T> source) {
  return Provider<Stream<T>>((ref) {
    final controller = StreamController<T>.broadcast();

    // container.listen, not ref.listen. A listener registered inside a provider
    // body is only driven while that provider itself has listeners, and this
    // one is `ref.read` from a BlocProvider.create — never watched. Riverpod
    // then leaves [source] dirty-but-not-recomputed and the callback never
    // fires, so the bloc silently keeps its original instance. Verified: with
    // ref.listen the stream emits only the seed even after the source has
    // demonstrably rebuilt; with container.listen it emits both.
    final subscription = ref.container.listen<T>(source, (_, next) {
      if (!controller.isClosed) controller.add(next);
    });
    ref.onDispose(() {
      subscription.close();
      runProviderDetached(
        controller.close(),
        'close the provider identity stream',
        logName: 'ProviderIdentityStream',
      );
    });

    // Stream.multi, not an `async*` generator: a generator returns a
    // single-subscription stream, so a second consumer of the same provider
    // would throw "Stream has already been listened to". Each listener runs
    // the callback fresh and is seeded with the value current at *its*
    // subscribe time.
    return Stream<T>.multi((listener) {
      if (controller.isClosed) {
        runProviderDetached(
          listener.close(),
          'close an expired provider identity listener',
          logName: 'ProviderIdentityStream',
        );
        return;
      }
      listener.add(ref.read(source));
      final subscription = controller.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener.onCancel = subscription.cancel;
    });
  });
}
