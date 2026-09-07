// ABOUTME: Replaces the app UI with a restart prompt once the local database
// ABOUTME: reports on-disk corruption, so the next launch can salvage it.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/database_corruption_provider.dart';
import 'package:openvine/startup/close_app_support.dart';
import 'package:unified_logger/unified_logger.dart';

const _recoveryPersistenceTimeout = Duration(seconds: 15);

/// Swaps [child] for [DatabaseCorruptionScreen] once corruption surfaces.
///
/// Installed as `MaterialApp.builder`, so it covers every route with one gate
/// rather than each screen having to handle a dead database itself.
///
/// The takeover is total on purpose. `DatabaseCorruptionService.isCorrupted`
/// only ever flips once, and nothing repairs the open database in place: from
/// that point on every read against the damaged pages throws, so leaving the
/// user in the app only trades one broken screen for the next. Recovery needs a
/// restart (see the service for why it cannot happen in-session), so the honest
/// move is to say so immediately.
class DatabaseCorruptionGate extends ConsumerWidget {
  /// Creates a gate wrapping [child].
  const DatabaseCorruptionGate({required this.child, super.key});

  /// The normal app UI, shown while the database is healthy.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(databaseCorruptionServiceProvider);
    // Null in widget tests, which never wire the interceptor that reports.
    if (service == null) return child;

    return ValueListenableBuilder<bool>(
      valueListenable: service.isCorrupted,
      builder: (context, isCorrupted, healthyChild) => isCorrupted
          ? DatabaseCorruptionScreen(
              awaitRecoveryPersisted: () => service.recoveryPersisted,
            )
          : healthyChild!,
      child: child,
    );
  }
}

/// Tells the user their local database is damaged and a restart repairs it.
///
/// The sibling of `DatabaseBootstrapFailureApp`, for corruption that surfaces
/// *after* startup. Supported platforms can close the app directly; the body
/// copy tells users on other platforms how to restart it themselves.
class DatabaseCorruptionScreen extends StatelessWidget {
  /// Creates the screen. [onCloseApp] is injected for tests.
  const DatabaseCorruptionScreen({
    this.awaitRecoveryPersisted,
    this.canCloseApp,
    this.onCloseApp = SystemNavigator.pop,
    super.key,
  });

  /// Resolves once the next launch's salvage is scheduled durably.
  ///
  /// `null` leaves the button enabled immediately, for callers with no flag to
  /// wait on (tests covering the layout).
  final Future<void> Function()? awaitRecoveryPersisted;

  /// Overrides platform close support in tests.
  final bool? canCloseApp;

  /// Invoked by the close button.
  final VoidCallback onCloseApp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  const ExcludeSemantics(
                    child: DivineIcon(
                      icon: DivineIconName.warningCircle,
                      color: VineTheme.accentOrange,
                      size: 48,
                    ),
                  ),
                  Text(
                    l10n.databaseCorruptionTitle,
                    textAlign: TextAlign.center,
                    style: VineTheme.titleLargeFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  _CloseAppAffordance(
                    awaitRecoveryPersisted: awaitRecoveryPersisted,
                    canCloseApp: canCloseApp ?? platformCanCloseApp,
                    onCloseApp: onCloseApp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The recovery instructions and close affordance, held until the recovery
/// flag is durable.
///
/// Closing before the write lands would strand the user on the same corrupt
/// database: the restart only repairs anything if the next launch can read the
/// flag. The wait is invisible in practice — the write settles long before
/// anyone finishes reading the screen.
class _CloseAppAffordance extends StatefulWidget {
  const _CloseAppAffordance({
    required this.awaitRecoveryPersisted,
    required this.canCloseApp,
    required this.onCloseApp,
  });

  final Future<void> Function()? awaitRecoveryPersisted;
  final bool canCloseApp;
  final VoidCallback onCloseApp;

  @override
  State<_CloseAppAffordance> createState() => _CloseAppAffordanceState();
}

class _CloseAppAffordanceState extends State<_CloseAppAffordance> {
  Timer? _persistenceTimer;

  // Resolved once, not per build, so a rebuild cannot restart the wait.
  late final Future<void> _persisted = _waitForPersistence();

  Future<void> _waitForPersistence() {
    final source =
        widget.awaitRecoveryPersisted?.call() ?? Future<void>.value();
    final completion = Completer<void>();
    late final Timer timer;
    timer = Timer(_recoveryPersistenceTimeout, () {
      Log.warning(
        'Timed out waiting for the database recovery flag to persist',
        name: 'DatabaseCorruptionScreen',
        category: LogCategory.system,
      );
      if (!completion.isCompleted) completion.complete();
    });
    _persistenceTimer = timer;
    source.then(
      (_) {
        timer.cancel();
        if (!completion.isCompleted) completion.complete();
      },
      onError: (Object error, StackTrace stack) {
        timer.cancel();
        if (!completion.isCompleted) completion.completeError(error, stack);
      },
    );
    return completion.future;
  }

  @override
  void dispose() {
    _persistenceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _persisted,
      builder: (context, snapshot) {
        // Any terminal state releases the instructions, including a failed
        // write:
        // the service has already logged it, and a user who restarts anyway is
        // better off than one held in a session that cannot recover.
        final settled = snapshot.connectionState == ConnectionState.done;
        if (!settled) {
          return DivineCircularProgressIndicator(
            semanticsLabel: context.l10n.commonLoading,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                context.l10n.databaseCorruptionBody,
                textAlign: TextAlign.center,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
            ),
            if (widget.canCloseApp)
              DivineButton(
                label: context.l10n.databaseCorruptionCloseButton,
                onPressed: widget.onCloseApp,
                type: DivineButtonType.secondary,
              ),
          ],
        );
      },
    );
  }
}
