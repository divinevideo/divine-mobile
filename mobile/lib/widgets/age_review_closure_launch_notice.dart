// ABOUTME: Opens Account Status once per session when the signed-in account
// ABOUTME: was closed by age review, so the closure is explained on launch.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/widgets/age_review_closure_launch_notice_cubit.dart';
import 'package:unified_logger/unified_logger.dart';

/// Takes an account closed by age review to Account Status when the app
/// opens, rather than waiting for a rejected post (support-trust-safety#260).
///
/// Every other enforcement state is left to the existing entry points: a
/// suspended or generically banned account can still browse, and an open age
/// case already routes to the review screens.
///
/// Mounted with the bottom-nav shell, so it runs for a signed-in session or one
/// still being restored. It is the only launch-time reader of the status, so it
/// costs a signed request to Funnelcake each time the shell mounts: at launch,
/// and again when navigation replaces the shell and brings it back, as
/// scheduling a post does on its way to the drafts. A closure costs one more,
/// because Account Status reads again when it opens. Settings, the account's
/// own profile and Account Status otherwise fetch it when opened. A failed
/// read gets one retry, on the next resume or when the signer becomes ready;
/// [AgeReviewClosureLaunchNoticeCubit] holds that policy.
class AgeReviewClosureLaunchNotice extends StatelessWidget {
  const AgeReviewClosureLaunchNotice({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AgeReviewClosureLaunchNoticeCubit(),
    child: _LaunchStatusReader(child: child),
  );
}

/// Feeds the launch status reads to the cubit, lets go of the status once the
/// cubit stops reading, and shows the closure when the cubit finds one.
class _LaunchStatusReader extends ConsumerStatefulWidget {
  const _LaunchStatusReader({required this.child});

  final Widget child;

  @override
  ConsumerState<_LaunchStatusReader> createState() =>
      _LaunchStatusReaderState();
}

class _LaunchStatusReaderState extends ConsumerState<_LaunchStatusReader> {
  ProviderSubscription<AsyncValue<AccountEnforcementStatus>>? _status;

  @override
  void initState() {
    super.initState();
    // For a local key, starting the read signs its request synchronously.
    // Waiting for the first frame keeps that out of the frame's build.
    addPostFrameCallbackIfMounted(_read);
  }

  void _read() {
    final notice = context.read<AgeReviewClosureLaunchNoticeCubit>();
    _status = ref.listenManual<AsyncValue<AccountEnforcementStatus>>(
      accountEnforcementStatusProvider,
      (_, next) {
        // The answer is a settled value for a signed-in account. signedOut is
        // what the provider reports while a session is still being restored,
        // and a value carried over while the provider reloads belongs to the
        // state before; stopping on either would miss the closure. A signer
        // that is not ready yet sent no request, so it is not a failed read.
        switch (next) {
          case AsyncData(:final value, isLoading: false)
              when value.kind != AccountEnforcementKind.signedOut:
            notice.answered(value);
          case AsyncError(:final error, isLoading: false)
              when error is! AccountStatusSignerNotReady:
            notice.readFailed();
          default:
        }
        // Letting go of the provider means a resume refetch costs nothing
        // unless something else is showing the status.
        if (!notice.state.isReading) _status?.close();
      },
      fireImmediately: true,
    );
    // A status already cached answers synchronously inside listenManual,
    // before _status is assigned, so close it here in that case.
    if (!notice.state.isReading) _status?.close();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depending on whether the tabs are in front brings this back when the
    // screen covering them closes, so a closure found under it shows then.
    // This runs during a build, which may neither navigate nor modify a
    // provider, so the showing waits for the frame.
    if (ModalRoute.isCurrentOf(context) ?? true) {
      addPostFrameCallbackIfMounted(_showFoundClosure);
    }
  }

  void _showFoundClosure() {
    final notice = context.read<AgeReviewClosureLaunchNoticeCubit>();
    if (notice.state.status !=
        AgeReviewClosureLaunchNoticeStatus.closureFound) {
      return;
    }
    final shown = ref.read(ageReviewClosureLaunchShownProvider.notifier);
    final pubkey = ref.read(activeEnforcementPubkeyProvider);
    // Not under a screen or dialog pushed over the whole shell: over the
    // recorder, an editor, a conversation or the app-update dialog a push
    // would skip their own exit steps, such as the recorder's lock and pause,
    // so the closure waits until the shell is in front. A sheet opened inside
    // a tab sits on that tab's navigator and does not cover the shell, which
    // is harmless: a sheet has no exit steps to skip. Account Status marks a
    // closure it explains as shown, so one the account opened itself in the
    // meantime is not opened again.
    if (!(ModalRoute.isCurrentOf(context) ?? true)) return;
    notice.shown();
    if (pubkey == null) return;
    if (!shown.markShown(pubkey)) return;
    runDetached(
      context.pushNamed(AccountStatusScreen.routeName),
      'open account status for age-review closure',
      logName: 'AgeReviewClosureLaunchNotice',
      category: LogCategory.ui,
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<
        AgeReviewClosureLaunchNoticeCubit,
        AgeReviewClosureLaunchNoticeState
      >(
        listenWhen: (_, current) =>
            current.status == AgeReviewClosureLaunchNoticeStatus.closureFound,
        listener: (_, _) => _showFoundClosure(),
        child: widget.child,
      );
}
