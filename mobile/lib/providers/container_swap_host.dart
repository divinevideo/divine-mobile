// ABOUTME: Hosts the active ProviderContainer and swaps it in place on an
// ABOUTME: account switch — no widget-tree remount, no welcome-screen bounce.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Attests a rendered container generation, rather than a scheduled setState.
class AccountContainerCommitReceipt {
  AccountContainerCommitReceipt._(
    this._controller,
    this.container,
    this._host,
    this._generation,
  );

  final AccountSwitchController _controller;
  final ProviderContainer container;
  final Object _host;
  final int _generation;

  /// Re-evaluated after every asynchronous settlement step.
  bool get isCurrent =>
      identical(_controller._host, _host) &&
      identical(_controller.currentContainer, container) &&
      _controller._committedGeneration == _generation;
}

/// Handle the UI uses to request an in-place container swap.
///
/// The switch trigger lives *above* the [ProviderContainer] (it must outlive
/// the container being replaced), so it can't be a provider inside the tree.
/// UI code holds this controller — surfaced via an inherited widget above the
/// scope, or the same instance injected into each container — and calls
/// [swapTo] with a freshly-built, already-signed-in container for the target
/// account.
class AccountSwitchController {
  Future<AccountContainerCommitReceipt> Function(
    ProviderContainer next,
    Future<void> Function()? beforePreviousContainerDispose,
  )?
  _onSwap;
  ProviderContainer? _currentContainer;
  Object? _host;
  int? _committedGeneration;
  bool _switchInProgress = false;

  /// Whether a [ContainerSwapHost] is mounted and ready to swap.
  bool get isReady => _onSwap != null;

  /// The currently mounted account container, when a host is active.
  ProviderContainer? get currentContainer => _currentContainer;

  AccountContainerCommitReceipt? get currentCommit {
    final host = _host;
    final container = _currentContainer;
    final generation = _committedGeneration;
    if (host == null || container == null || generation == null) return null;
    return AccountContainerCommitReceipt._(this, container, host, generation);
  }

  /// Runs [body] while rejecting overlapping switch attempts.
  Future<T> runExclusive<T>(Future<T> Function() body) async {
    if (_switchInProgress) {
      throw StateError('Account switch already in progress');
    }
    _switchInProgress = true;
    try {
      return await body();
    } finally {
      _switchInProgress = false;
    }
  }

  /// Requests the host swap the live container to [next].
  ///
  /// [next] must already be built (via `buildAccountContainer`) and signed in
  /// as the target account — the host only mounts it and disposes the old one.
  /// [beforePreviousContainerDispose] runs after the target mounts and must
  /// handle its own errors; the previous container is disposed in either case.
  Future<void> swapTo(
    ProviderContainer next, {
    Future<void> Function()? beforePreviousContainerDispose,
  }) {
    final onSwap = _onSwap;
    if (onSwap == null) {
      throw StateError('ContainerSwapHost is not mounted');
    }
    // Keep scheduling compatibility for callers that pump the frame themselves.
    // Authentication settlement uses swapToAndCommit and awaits the receipt.
    onSwap(next, beforePreviousContainerDispose).ignore();
    return Future<void>.value();
  }

  Future<AccountContainerCommitReceipt> swapToAndCommit(
    ProviderContainer next, {
    Future<void> Function()? beforePreviousContainerDispose,
  }) {
    final onSwap = _onSwap;
    if (onSwap == null) throw StateError('ContainerSwapHost is not mounted');
    return onSwap(next, beforePreviousContainerDispose);
  }
}

/// Owns the active [ProviderContainer] and rebuilds the app under a new one
/// when the account switches, disposing the previous container after the frame.
///
/// Replaces the single `UncontrolledProviderScope` at the app root. The device
/// singletons ([DeviceScope]) are shared across containers, so only the leaving
/// account's account-scoped runtime is torn down.
class ContainerSwapHost extends StatefulWidget {
  const ContainerSwapHost({
    required this.initialContainer,
    required this.controller,
    required this.child,
    super.key,
  });

  /// The container the app boots with (the initial account, or signed-out).
  final ProviderContainer initialContainer;

  /// Controller the UI calls to trigger a swap.
  final AccountSwitchController controller;

  final Widget child;

  @override
  State<ContainerSwapHost> createState() => _ContainerSwapHostState();
}

class _ContainerSwapHostState extends State<ContainerSwapHost> {
  late ProviderContainer _container;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _container = widget.initialContainer;
    widget.controller._currentContainer = _container;
    widget.controller._onSwap = _swap;
    widget.controller._host = this;
    widget.controller._committedGeneration = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller._host == this && _generation == 0) {
        widget.controller._committedGeneration = 0;
      }
    });
  }

  Future<AccountContainerCommitReceipt> _swap(
    ProviderContainer next,
    Future<void> Function()? beforePreviousContainerDispose,
  ) {
    if (!mounted) {
      // The host is gone; the caller owns the orphaned container.
      throw StateError('ContainerSwapHost is not mounted');
    }
    if (identical(next, _container)) {
      final receipt = widget.controller.currentCommit;
      if (receipt == null) throw StateError('Container has not committed');
      return Future.value(receipt);
    }

    final previous = _container;
    final committed = Completer<AccountContainerCommitReceipt>();
    setState(() {
      _container = next;
      _generation += 1;
      widget.controller._currentContainer = next;
      widget.controller._committedGeneration = null;
    });
    final generation = _generation;

    // Dispose the leaving container only after this frame commits, so widgets
    // still reading it during the unmount don't hit a disposed container. A
    // post-commit cleanup may retain account-scoped signers owned by that
    // container, so keep it alive until the cleanup settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.controller._host == this &&
          _generation == generation &&
          identical(_container, next)) {
        widget.controller._committedGeneration = generation;
        committed.complete(
          AccountContainerCommitReceipt._(
            widget.controller,
            next,
            this,
            generation,
          ),
        );
      } else {
        committed.completeError(StateError('Account container commit retired'));
      }
      unawaited(
        (() async {
          try {
            await beforePreviousContainerDispose?.call();
          } finally {
            previous.dispose();
          }
        })(),
      );
    });
    return committed.future;
  }

  @override
  void dispose() {
    // Tear-offs of the same instance method compare equal (but not identical),
    // so use == to avoid detaching a controller a newer host has claimed.
    if (widget.controller._onSwap == _swap) {
      widget.controller._onSwap = null;
      widget.controller._currentContainer = null;
      widget.controller._host = null;
      widget.controller._committedGeneration = null;
    }
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: _container,
      child: KeyedSubtree(key: ValueKey(_generation), child: widget.child),
    );
  }
}
