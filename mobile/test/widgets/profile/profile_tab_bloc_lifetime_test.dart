import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_tab_bloc_lifetime.dart';

class _TestCubit extends Cubit<int> {
  _TestCubit() : super(0);
}

void main() {
  group(ProfileTabBlocLifetime, () {
    test(
      'keeps a replaced bloc open until its fullscreen feed returns',
      () async {
        final bloc = _TestCubit();
        Future<void>? observedClose;
        final lifetime = ProfileTabBlocLifetime(
          bloc: bloc,
          observeClose: (close) => observedClose = close,
        );
        final releaseFeed = lifetime.acquire();

        lifetime.releaseOwner();

        expect(bloc.isClosed, isFalse);
        bloc.emit(1);
        expect(bloc.state, 1);
        expect(observedClose, isNull);

        releaseFeed();
        await observedClose;

        expect(bloc.isClosed, isTrue);
      },
    );

    test(
      'closes after the grid releases ownership when no feed is active',
      () async {
        final bloc = _TestCubit();
        Future<void>? observedClose;
        final lifetime = ProfileTabBlocLifetime(
          bloc: bloc,
          observeClose: (close) => observedClose = close,
        );

        lifetime.releaseOwner();
        await observedClose;

        expect(bloc.isClosed, isTrue);
      },
    );

    test('release callbacks and owner release are idempotent', () async {
      final bloc = _TestCubit();
      Future<void>? observedClose;
      final lifetime = ProfileTabBlocLifetime(
        bloc: bloc,
        observeClose: (close) => observedClose = close,
      );
      final releaseFeed = lifetime.acquire();

      releaseFeed();
      releaseFeed();
      lifetime.releaseOwner();
      lifetime.releaseOwner();
      await observedClose;

      expect(bloc.isClosed, isTrue);
    });
  });
}
