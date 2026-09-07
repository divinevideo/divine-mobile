// ABOUTME: Create-account route guard that enforces invite approval

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';

class InviteProtectedCreateAccountScreen extends ConsumerStatefulWidget {
  const InviteProtectedCreateAccountScreen({
    this.initialCode,
    this.initialError,
    this.initialSourceSlug,
    super.key,
  });

  final String? initialCode;
  final String? initialError;
  final String? initialSourceSlug;

  @override
  ConsumerState<InviteProtectedCreateAccountScreen> createState() =>
      _InviteProtectedCreateAccountScreenState();
}

class _InviteProtectedCreateAccountScreenState
    extends ConsumerState<InviteProtectedCreateAccountScreen> {
  void _redirectToInvite(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final code = widget.initialCode;
        context.go(
          code == null || code.isEmpty
              ? WelcomeScreen.inviteGatePath
              : WelcomeScreen.inviteGatePathWithCode(
                  code,
                  error: widget.initialError,
                  sourceSlug: widget.initialSourceSlug,
                ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(currentAuthStateProvider);
    return BlocBuilder<InviteAvailabilityCubit, InviteAvailabilityState>(
      builder: (context, availability) {
        return BlocBuilder<InviteGateBloc, InviteGateState>(
          builder: (context, state) {
            if (authState == AuthState.authenticated && state.hasAccessGrant) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<InviteGateBloc>().add(
                  const InviteGateAccessCleared(),
                );
              });
            }

            if (!availability.isEnabled || state.hasAccessGrant) {
              return const CreateAccountScreen();
            }

            if (!availability.hasResolved) {
              return const _InviteGuardLoadingPage();
            }

            _redirectToInvite(context);
            return const _InviteGuardLoadingPage();
          },
        );
      },
    );
  }
}

class _InviteGuardLoadingPage extends StatelessWidget {
  const _InviteGuardLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: Center(
        child: DivineCircularProgressIndicator(
          color: context.vineColors.accentPositive,
        ),
      ),
    );
  }
}
