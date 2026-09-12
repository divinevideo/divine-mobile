import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/router/invite_availability_redirects.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';

import '../helpers/invite_availability_harness.dart';

void main() {
  group('signup invite route guards', () {
    testWidgets('redirects /welcome/invite to create-account when disabled', (
      tester,
    ) async {
      final cubit = seededInviteAvailabilityCubit(
        serverMode: OnboardingMode.open,
      );
      addTearDown(cubit.close);

      final router = GoRouter(
        initialLocation: WelcomeScreen.inviteGatePath,
        routes: [
          GoRoute(
            path: WelcomeScreen.path,
            builder: (_, _) => const SizedBox(),
            routes: [
              GoRoute(
                path: 'invite',
                redirect: (_, state) => inviteGateRedirectIfDisabled(
                  cubit,
                  state,
                ),
                builder: (_, _) => const Text('Invite Gate'),
              ),
              GoRoute(
                path: 'create-account',
                builder: (_, _) => const Text('Create Account'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Invite Gate'), findsNothing);
    });

    testWidgets('redirects /invites to settings when disabled', (tester) async {
      final cubit = seededInviteAvailabilityCubit(
        serverMode: OnboardingMode.open,
      );
      addTearDown(cubit.close);

      final router = GoRouter(
        initialLocation: InvitesScreen.path,
        routes: [
          GoRoute(
            path: SettingsScreen.path,
            builder: (_, _) => const Text('Settings'),
          ),
          GoRoute(
            path: InvitesScreen.path,
            redirect: (_, state) => invitesScreenRedirectIfDisabled(
              cubit,
              state,
            ),
            builder: (_, _) => const Text('Invites'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Invites'), findsNothing);
    });

    testWidgets('keeps /welcome/invite open when invites are enabled', (
      tester,
    ) async {
      final cubit = seededInviteAvailabilityCubit();
      addTearDown(cubit.close);

      final router = GoRouter(
        initialLocation: WelcomeScreen.inviteGatePath,
        routes: [
          GoRoute(
            path: WelcomeScreen.path,
            builder: (_, _) => const SizedBox(),
            routes: [
              GoRoute(
                path: 'invite',
                redirect: (_, state) => inviteGateRedirectIfDisabled(
                  cubit,
                  state,
                ),
                builder: (_, _) => const Text('Invite Gate'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Invite Gate'), findsOneWidget);
    });
  });
}
