// ABOUTME: Reusable presentation for opening private support with email fallback
// ABOUTME: Supplies localized fallback copy and reports terminal email failure

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/support_contact/support_contact_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/share_position_origin.dart';

typedef SupportContactActionBuilder = Widget Function(
  BuildContext context,
  bool isOpening,
  VoidCallback openSupport,
);

class SupportContactAction extends StatelessWidget {
  const SupportContactAction({
    required this.builder,
    this.openSupportMessages,
    this.composeEmail,
    super.key,
  });

  final SupportContactActionBuilder builder;
  final OpenSupportMessages? openSupportMessages;
  final ComposeSupportEmail? composeEmail;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SupportContactCubit(
        openSupportMessages: openSupportMessages,
        composeEmail: composeEmail,
      ),
      child: _SupportContactActionView(builder: builder),
    );
  }
}

class _SupportContactActionView extends StatelessWidget {
  const _SupportContactActionView({required this.builder});

  final SupportContactActionBuilder builder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<SupportContactCubit, SupportContactState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == SupportContactStatus.emailFailed,
      listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.authCouldNotOpenEmail(AppConstants.supportEmail),
          error: true,
        ),
      ),
      builder: (context, state) => builder(
        context,
        state.status == SupportContactStatus.opening,
        () => context.read<SupportContactCubit>().open(
          SupportContactEmailRequest(
            toEmail: AppConstants.supportEmail,
            subject: l10n.supportContactSupport,
            body: l10n.supportContactSupportSubtitle,
            messagingUnavailableNote: l10n.supportChatNotAvailable,
            messagingFailedNote: l10n.supportCouldNotOpenMessages,
            sharePositionOrigin: shareAnchorForContext(context),
          ),
        ),
      ),
    );
  }
}
