import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/models/invite_availability.dart';

/// Builds from shared signup-invite availability.
///
/// Defaults to enabled when the cubit is not in the tree so existing
/// screens stay usable in tests that do not mount availability.
class SignupInvitesAvailabilityBuilder extends StatelessWidget {
  const SignupInvitesAvailabilityBuilder({required this.builder, super.key});

  final Widget Function(
    BuildContext context,
    InviteAvailabilityState availability,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InviteAvailabilityCubit?>();
    if (cubit == null) {
      return builder(context, const InviteAvailabilityState());
    }
    return BlocBuilder<InviteAvailabilityCubit, InviteAvailabilityState>(
      builder: builder,
    );
  }
}
