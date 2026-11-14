import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_link/profile_link_cubit.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/widgets/profile/profile_link_scope.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileReader extends Mock implements ProfileReader {}

/// Stands in for the header subtree the scope wraps.
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => Text(
    context.select<ProfileLinkCubit, String>((cubit) => cubit.state.link.url),
    textDirection: TextDirection.ltr,
  );
}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  ProfileReader readerOwning(String canonical) {
    final reader = _MockProfileReader();
    when(() => reader.lookupUsernameByPubkey(pubkeyHex: pubkey)).thenAnswer(
      (_) async => DivineUsernameFound(name: canonical, canonical: canonical),
    );
    return reader;
  }

  Widget scope(ProfileReader reader, {bool enabled = true}) => ProviderScope(
    overrides: [profileReadRepositoryProvider.overrideWithValue(reader)],
    child: ProfileLinkScope(
      pubkey: pubkey,
      profile: null,
      enabled: enabled,
      child: const _Probe(),
    ),
  );

  group(ProfileLinkScope, () {
    testWidgets(
      're-resolves with a new repository without remounting its child',
      (tester) async {
        await tester.pumpWidget(scope(readerOwning('alice')));
        await tester.pumpAndSettle();
        expect(find.text('https://alice.divine.video'), findsOneWidget);
        final probe = tester.state(find.byType(_Probe));

        await tester.pumpWidget(scope(readerOwning('carol')));
        await tester.pumpAndSettle();

        expect(find.text('https://carol.divine.video'), findsOneWidget);
        expect(tester.state(find.byType(_Probe)), same(probe));
      },
    );

    testWidgets(
      'drops the resolved username when disabled without remounting its child',
      (tester) async {
        final reader = readerOwning('alice');
        await tester.pumpWidget(scope(reader));
        await tester.pumpAndSettle();
        expect(find.text('https://alice.divine.video'), findsOneWidget);
        final probe = tester.state(find.byType(_Probe));

        await tester.pumpWidget(scope(reader, enabled: false));
        await tester.pumpAndSettle();

        expect(
          find.text(ProfileLink.fallback(pubkey, null).url),
          findsOneWidget,
        );
        expect(tester.state(find.byType(_Probe)), same(probe));
      },
    );
  });
}
