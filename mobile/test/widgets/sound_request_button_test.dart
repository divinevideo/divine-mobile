import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/metadata/sound_request_button.dart';

class _Repository extends Mock implements SoundRequestsRepository {}

const owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const address =
    '34236:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:clip';
void main() {
  for (final available in [true, false]) {
    testWidgets(
      'request action follows current source eligibility: $available',
      (tester) async {
        final repo = _Repository();
        when(() => repo.ownerPubkey).thenReturn(owner);
        when(repo.watchState).thenAnswer((_) => const Stream.empty());
        when(repo.start).thenAnswer((_) async {});
        when(() => repo.canRequest(address)).thenAnswer((_) async => available);
        final cubit = SoundRequestsCubit();
        await cubit.connect(repo);
        addTearDown(cubit.close);
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: SoundRequestButton(videoAddress: address),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Request this sound'),
          available ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}
