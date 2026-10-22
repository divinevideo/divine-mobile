import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/widgets/supporter_membership.dart';

/// Whether a supporter's halo and wings show on their profile to others.
///
/// Only supporters see it. Absent when supporters are not configured or no
/// one is signed in.
class SupporterRecognitionSection extends StatelessWidget {
  const SupporterRecognitionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SupporterMembershipScope(child: _SupporterRecognition());
  }
}

class _SupporterRecognition extends StatelessWidget {
  const _SupporterRecognition();

  @override
  Widget build(BuildContext context) {
    final SupporterCubit cubit;
    try {
      cubit = context.read<SupporterCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return BlocConsumer<SupporterCubit, SupporterState>(
      bloc: cubit,
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure != current.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            state.failure!.message(l10n),
            error: true,
          ),
        );
        cubit.dismissError();
      },
      builder: (context, state) {
        if (!state.isSupporter) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              l10n.supporterTitle,
              style: VineTheme.labelMediumFont(
                color: context.vineColors.mutedText,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileSwitchRow(
                  label: l10n.supporterPublicRecognition,
                  value: state.haloVisible,
                  onChanged: state.snapshot == null || state.savingRecognition
                      ? null
                      : cubit.setPublicRecognition,
                ),
                ProfileFieldSupportingText(
                  l10n.supporterPublicRecognitionBody,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
