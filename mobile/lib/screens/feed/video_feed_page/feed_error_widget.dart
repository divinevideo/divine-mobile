// ABOUTME: Feed error state widget — shown when the home feed fails to load,
// ABOUTME: saying whether the fault is ours, the network's, or unknown.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/outage_notice/outage_notice_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/outage_diagnosis_provider.dart';

/// Error state for the home video feed.
///
/// Diagnoses the failure on mount by cross-checking the Divine status page,
/// which is hosted away from the services it reports on and so stays
/// reachable when they are not. The check runs only while a user is looking
/// at this screen — never in the background, and only for the components the
/// feed itself depends on.
class FeedErrorWidget extends ConsumerWidget {
  const FeedErrorWidget({required this.onRetry, super.key});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnosisService = ref.watch(outageDiagnosisServiceProvider);

    return BlocProvider(
      key: ValueKey(diagnosisService),
      create: (_) =>
          OutageNoticeCubit(diagnosisService: diagnosisService)..diagnose(),
      child: FeedErrorView(onRetry: onRetry),
    );
  }
}

/// The rendered failure copy.
@visibleForTesting
class FeedErrorView extends StatelessWidget {
  const FeedErrorView({required this.onRetry, super.key});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OutageNoticeCubit>().state;

    return Center(
      // Scrollable so a long operator message — an operator writes this, and
      // could paste a paragraph — cannot push the Retry button off-screen or
      // overflow the column during the incident it is explaining.
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            DivineIcon(
              icon: switch (state.status) {
                OutageNoticeStatus.noConnection => DivineIconName.globe,
                _ => DivineIconName.warningCircle,
              },
              color: VineTheme.error,
              size: 64,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                _message(context, state),
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            DivineButton(
              label: context.l10n.feedRetry,
              onPressed: () => unawaited(onRetry()),
            ),
          ],
        ),
      ),
    );
  }

  String _message(BuildContext context, OutageNoticeState state) {
    // An operator writing "fix rolling out, ~20 min" beats any canned line, so
    // it wins whenever the status page carries one.
    final operatorMessage = state.operatorMessage;
    if (state.status == OutageNoticeStatus.divineOutage &&
        operatorMessage != null &&
        operatorMessage.isNotEmpty) {
      return operatorMessage;
    }

    return switch (state.status) {
      OutageNoticeStatus.divineOutage => context.l10n.feedOutageMessage,
      OutageNoticeStatus.noConnection => context.l10n.feedOfflineMessage,
      // While the diagnosis runs, and whenever nothing corroborates a cause,
      // claim nothing: a wrong "it's us" that flips a second later is worse
      // than staying generic.
      OutageNoticeStatus.checking ||
      OutageNoticeStatus.indeterminate => context.l10n.feedFailedToLoadVideos,
    };
  }
}
