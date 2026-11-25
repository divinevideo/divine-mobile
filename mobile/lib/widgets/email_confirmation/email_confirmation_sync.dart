// ABOUTME: Points the app-wide EmailConfirmationCubit at the signed-in Keycast
// ABOUTME: account and re-checks the confirmation whenever the app resumes.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/providers/email_confirmation_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Keeps [EmailConfirmationCubit] on the signed-in account.
///
/// Only accounts signed in with email and password through Keycast have an
/// email to confirm; every other account is pointed at nobody, so it never
/// sees the nudge. The confirmation link opens in the mail app or a browser,
/// so returning to the app is when the answer is most likely to have changed.
class EmailConfirmationSync extends ConsumerStatefulWidget {
  const EmailConfirmationSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<EmailConfirmationSync> createState() =>
      _EmailConfirmationSyncState();
}

class _EmailConfirmationSyncState extends ConsumerState<EmailConfirmationSync> {
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<KeycastPolicyRefusal> _refusals;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refusals = KeycastPolicyRefusals.stream.listen(_onRefusal);
    _syncAccount(ref.read(emailConfirmationAccountProvider));
  }

  @override
  void dispose() {
    runDetached(
      _refusals.cancel(),
      'stop listening for Keycast refusals',
      logName: 'EmailConfirmationSync',
      category: LogCategory.auth,
    );
    _lifecycle.dispose();
    super.dispose();
  }

  /// Keycast refuses signing for accounts that have not confirmed, deep in
  /// publishing and messaging where no screen is listening. Route each refusal
  /// to the cubit so the app can explain it.
  void _onRefusal(KeycastPolicyRefusal refusal) {
    if (!mounted) return;
    final cubit = context.read<EmailConfirmationCubit>();
    switch (refusal.kind) {
      case KeycastPolicyRefusalKind.emailNotConfirmed:
        runDetached(
          cubit.markUnconfirmedByKeycast(refusal.owner),
          'lock after Keycast refused a DM',
          logName: 'EmailConfirmationSync',
          category: LogCategory.auth,
        );
      case KeycastPolicyRefusalKind.unconfirmedRateLimited:
        cubit.reportCapReached(refusal.owner);
    }
  }

  void _syncAccount(String? account) {
    runDetached(
      context.read<EmailConfirmationCubit>().loadFor(account),
      'load email confirmation',
      logName: 'EmailConfirmationSync',
      category: LogCategory.auth,
    );
  }

  void _refresh() {
    if (!mounted) return;
    runDetached(
      context.read<EmailConfirmationCubit>().refresh(),
      'refresh email confirmation',
      logName: 'EmailConfirmationSync',
      category: LogCategory.auth,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(emailConfirmationAccountProvider, (_, account) {
      _syncAccount(account);
    });
    return widget.child;
  }
}
