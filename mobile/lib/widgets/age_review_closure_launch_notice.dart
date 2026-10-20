// ABOUTME: Opens Account Status once per session when the signed-in account
// ABOUTME: was closed by age review, so the closure is explained on launch.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:unified_logger/unified_logger.dart';

/// Takes an account closed by age review to Account Status when the app
/// opens, rather than waiting for a rejected post (support-trust-safety#260).
///
/// Every other enforcement state is left to the existing entry points: a
/// suspended or generically banned account can still browse, and an open age
/// case already routes to the review screens.
///
/// Mounted with the bottom-nav shell, so it only runs for a signed-in session.
/// Watching the status here fetches it on launch, the same signed request the
/// minor-review gate already makes at startup.
class AgeReviewClosureLaunchNotice extends ConsumerStatefulWidget {
  const AgeReviewClosureLaunchNotice({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AgeReviewClosureLaunchNotice> createState() =>
      _AgeReviewClosureLaunchNoticeState();
}

class _AgeReviewClosureLaunchNoticeState
    extends ConsumerState<AgeReviewClosureLaunchNotice> {
  ProviderSubscription<AsyncValue<AccountEnforcementStatus>>? _status;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _status = ref.listenManual<AsyncValue<AccountEnforcementStatus>>(
      accountEnforcementStatusProvider,
      (_, next) {
        // Only the launch answer matters. Letting go of the provider after it
        // means a resume refetch costs nothing unless something else is
        // showing the status. A failed fetch keeps listening, so the refetch
        // on the next resume gets another try.
        if (_answered || !next.hasValue) return;
        _answered = true;
        _status?.close();
        if (next.value!.isAgeReviewClosure) _showOnce();
      },
      fireImmediately: true,
    );
    // A status already cached answers synchronously inside listenManual,
    // before _status is assigned, so close it here in that case.
    if (_answered) _status?.close();
  }

  @override
  void dispose() {
    _status?.close();
    super.dispose();
  }

  void _showOnce() {
    final pubkey = ref.read(activeEnforcementPubkeyProvider);
    if (pubkey == null) return;
    final shown = ref.read(ageReviewClosureLaunchShownProvider.notifier);
    if (!shown.markShown(pubkey)) return;
    // A listener can fire during a build, which must not navigate.
    addPostFrameCallbackIfMounted(() {
      final router = GoRouter.of(context);
      if (router.routerDelegate.currentConfiguration.uri.path ==
          AccountStatusScreen.path) {
        return;
      }
      runDetached(
        context.pushNamed(AccountStatusScreen.routeName),
        'open account status for age-review closure',
        logName: 'AgeReviewClosureLaunchNotice',
        category: LogCategory.ui,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
