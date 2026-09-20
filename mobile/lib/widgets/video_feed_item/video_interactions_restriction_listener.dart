// ABOUTME: Opens Account Status after a social publish confirms enforcement.
// ABOUTME: Keeps navigation out of repository and BLoC state.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Navigates to Account Status when the interactions BLoC confirms a ban.
class VideoInteractionsRestrictionListener extends StatelessWidget {
  /// Creates a listener around [child].
  const VideoInteractionsRestrictionListener({
    required this.child,
    super.key,
  });

  /// Content kept unchanged while restriction state is observed.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoInteractionsBloc, VideoInteractionsState>(
      listenWhen: (previous, current) =>
          previous.accountRestrictionRevision !=
          current.accountRestrictionRevision,
      listener: (context, state) {
        final router = GoRouter.of(context);
        if (router.routerDelegate.currentConfiguration.uri.path !=
            AccountStatusScreen.path) {
          runDetached(
            context.pushNamed(AccountStatusScreen.routeName, extra: true),
            'open account status',
            logName: 'VideoInteractionsRestrictionListener',
            category: LogCategory.ui,
          );
        }
      },
      child: child,
    );
  }
}
