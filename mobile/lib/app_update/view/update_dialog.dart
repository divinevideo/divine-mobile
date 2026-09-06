import 'package:app_update_repository/app_update_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a dialog when the update urgency is moderate or urgent.
///
/// Place this as a [BlocListener] in the widget tree.
///
/// This listener is mounted above [MaterialApp], so its own [BuildContext] has
/// no [Navigator] ancestor and cannot present a dialog. The dialog is resolved
/// through [NavigatorKeys.root] instead, the same way `main.dart` resolves the
/// publish snackbar.
class UpdateDialogListener extends StatefulWidget {
  /// Creates an [UpdateDialogListener].
  const UpdateDialogListener({required this.child, super.key});

  /// The child widget.
  final Widget child;

  @override
  State<UpdateDialogListener> createState() => _UpdateDialogListenerState();
}

class _UpdateDialogListenerState extends State<UpdateDialogListener> {
  /// How long a prompt waits for the root [Navigator] before it is dropped.
  ///
  /// The wait exists because `GeoBlockingGate` renders a spinner *in place of*
  /// `MaterialApp` while its check is in flight, and `GeoBlockingService` caps
  /// that check at 10s. The budget only bites when frames keep arriving while
  /// no navigator ever appears: a geo-blocked user shown a static screen in
  /// place of `MaterialApp` produces no frames, so the retry idles on its own
  /// rather than re-arming. The 30s bound (3x the 10s check) caps that busy
  /// case, so it can only ever drop a prompt that had no app to appear in.
  static const _navigatorWaitBudget = Duration(seconds: 30);

  ({AppUpdateBloc bloc, AppUpdateState state})? _pending;
  Duration? _waitingSince;
  bool _retryArmed = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppUpdateBloc, AppUpdateState>(
      listenWhen: (prev, curr) =>
          curr.status == AppUpdateStatus.resolved &&
          (curr.urgency == UpdateUrgency.moderate ||
              curr.urgency == UpdateUrgency.urgent) &&
          prev.urgency != curr.urgency,
      listener: (context, state) =>
          _present(context.read<AppUpdateBloc>(), state),
      child: widget.child,
    );
  }

  void _present(AppUpdateBloc bloc, AppUpdateState state) {
    if (!mounted) return;

    final navigatorContext = NavigatorKeys.root.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) {
      _deferUntilNavigator(bloc, state);
      return;
    }

    _pending = null;
    _waitingSince = null;

    showDialog<void>(
      context: navigatorContext,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _UpdateDialog(
          urgency: state.urgency,
          latestVersion: state.latestVersion ?? '',
          downloadUrl: state.downloadUrl ?? '',
          highlights: state.releaseHighlights,
        ),
      ),
    );
  }

  /// Re-attempts the prompt on later frames until a [Navigator] exists or
  /// [_navigatorWaitBudget] elapses.
  ///
  /// The update check can resolve before the router's Navigator is in the
  /// tree: `GeoBlockingGate` renders a spinner in place of `MaterialApp` while
  /// its own check is in flight. `listenWhen` gates on a single urgency
  /// transition, so a prompt dropped there is dropped for the whole session —
  /// hence deferring rather than skipping.
  ///
  /// Only one retry is ever in flight, and a second transition arriving
  /// mid-wait supersedes the pending one rather than stacking a second dialog
  /// on top of the first.
  void _deferUntilNavigator(AppUpdateBloc bloc, AppUpdateState state) {
    _pending = (bloc: bloc, state: state);
    if (_retryArmed) return;
    _retryArmed = true;
    WidgetsBinding.instance.addPostFrameCallback(_retryPending);
  }

  void _retryPending(Duration timeStamp) {
    _retryArmed = false;
    final pending = _pending;
    if (pending == null) return;

    // addPostFrameCallback never requests a frame of its own, so the budget is
    // measured against the frames the app actually produced.
    _waitingSince ??= timeStamp;
    if (timeStamp - _waitingSince! > _navigatorWaitBudget) {
      _pending = null;
      _waitingSince = null;
      return;
    }

    _present(pending.bloc, pending.state);
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({
    required this.urgency,
    required this.latestVersion,
    required this.downloadUrl,
    required this.highlights,
  });

  final UpdateUrgency urgency;
  final String latestVersion;
  final String downloadUrl;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    final isUrgent = urgency == UpdateUrgency.urgent;

    return AlertDialog(
      backgroundColor: context.vineColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isUrgent
            ? context.l10n.updateUrgentTitle
            : context.l10n.updateModerateTitle,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: context.vineColors.primaryText,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlights.isNotEmpty) ...[
            Text(
              context.l10n.updateNewIn(latestVersion),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.vineColors.mutedText.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            for (final highlight in highlights.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(color: VineTheme.vineGreen),
                    ),
                    Expanded(
                      child: Text(
                        highlight,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.read<AppUpdateBloc>().add(const AppUpdateDismissed());
            Navigator.of(context).pop();
          },
          child: Text(
            context.l10n.updateNotNow,
            style: TextStyle(
              color: context.vineColors.mutedText.withValues(alpha: 0.6),
            ),
          ),
        ),
        FilledButton(
          onPressed: () async {
            final uri = Uri.tryParse(downloadUrl);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          style: FilledButton.styleFrom(backgroundColor: VineTheme.vineGreen),
          child: Text(context.l10n.updateAction),
        ),
      ],
    );
  }
}
