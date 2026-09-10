import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/codec_heavy_surface/codec_heavy_surface_cubit.dart';
import 'package:openvine/mixins/codec_heavy_surface_guard.dart';

class _GuardedScreen extends StatefulWidget {
  const _GuardedScreen();

  @override
  State<_GuardedScreen> createState() => _GuardedScreenState();
}

class _GuardedScreenState extends State<_GuardedScreen>
    with CodecHeavySurfaceGuard {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ImmediateGuardedScreen extends StatefulWidget {
  const _ImmediateGuardedScreen();

  @override
  State<_ImmediateGuardedScreen> createState() =>
      _ImmediateGuardedScreenState();
}

class _ImmediateGuardedScreenState extends State<_ImmediateGuardedScreen>
    with CodecHeavySurfaceGuard {
  @override
  bool get assertCodecSignalAfterEntranceTransition => false;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  group(CodecHeavySurfaceGuard, () {
    late CodecHeavySurfaceCubit cubit;
    late GlobalKey<NavigatorState> navKey;

    setUp(() {
      cubit = CodecHeavySurfaceCubit();
      navKey = GlobalKey<NavigatorState>();
    });

    tearDown(() => cubit.close());

    Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
      BlocProvider<CodecHeavySurfaceCubit>.value(
        value: cubit,
        child: MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    testWidgets('asserts the signal only after the entrance transition '
        'completes', (tester) async {
      await pumpHost(tester);

      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const _GuardedScreen()),
      );

      // Mid-transition: the screen is animating in, the signal must stay off so
      // the background feed keeps rendering behind it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(cubit.state.isActive, isFalse);

      // Transition finished — now the signal asserts.
      await tester.pumpAndSettle();
      expect(cubit.state.isActive, isTrue);
    });

    testWidgets('asserts the signal immediately when the transition wait is '
        'disabled', (tester) async {
      await pumpHost(tester);

      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const _ImmediateGuardedScreen(),
        ),
      );

      // First frame, still mid-transition: the override drains right away so a
      // screen that allocates a decoder on mount (the editor) does not race the
      // feed's decoder.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(cubit.state.isActive, isTrue);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(cubit.state.isActive, isFalse);
    });

    testWidgets('releases the signal on pop', (tester) async {
      await pumpHost(tester);

      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const _GuardedScreen()),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.isActive, isTrue);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(cubit.state.isActive, isFalse);
    });

    testWidgets('does not assert when popped before the transition completes', (
      tester,
    ) async {
      await pumpHost(tester);

      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const _GuardedScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(cubit.state.isActive, isFalse);

      // Pop before the entrance transition finishes: enter never fired, so the
      // count must stay balanced at zero (no stray exit driving it negative).
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(cubit.state.isActive, isFalse);
      expect(cubit.state.activeCount, equals(0));
    });
  });
}
