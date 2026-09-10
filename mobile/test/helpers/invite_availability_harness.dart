import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';

class MockInviteApiClient extends Mock implements InviteApiClient {}

InviteAvailabilityCubit seededInviteAvailabilityCubit({
  OnboardingMode? serverMode = OnboardingMode.inviteCodeRequired,
  InviteAvailabilityOverride override = InviteAvailabilityOverride.useServer,
  InviteApiClient? client,
  bool hasResolved = true,
  InviteClientConfig? config,
}) {
  final resolvedConfig =
      config ??
      (serverMode == null
          ? null
          : InviteClientConfig(
              mode: serverMode,
              supportEmail: 'support@divine.video',
            ));
  return InviteAvailabilityCubit(
    repository: InviteAvailabilityRepository(
      client: client ?? MockInviteApiClient(),
      seed: InviteAvailabilityState(
        hasResolved: hasResolved,
        serverMode: serverMode,
        config: resolvedConfig,
        developerOverride: override,
      ),
    ),
  );
}

Widget wrapWithInviteAvailability(
  Widget child, {
  InviteAvailabilityCubit? cubit,
  OnboardingMode? serverMode = OnboardingMode.inviteCodeRequired,
  InviteAvailabilityOverride override = InviteAvailabilityOverride.useServer,
}) {
  return BlocProvider<InviteAvailabilityCubit>.value(
    value:
        cubit ??
        seededInviteAvailabilityCubit(
          serverMode: serverMode,
          override: override,
        ),
    child: child,
  );
}
