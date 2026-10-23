import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/text_wrap_hint/text_wrap_hint_cubit.dart';

void main() {
  group(TextWrapHintCubit, () {
    group('layerTransformed', () {
      test('shows the hint for a pinched text, then hides it', () {
        fakeAsync((async) {
          final cubit = TextWrapHintCubit()..layerTransformed('title');

          expect(cubit.state.layerId, 'title');

          async.elapse(TextWrapHintCubit.defaultTransientDuration);
          expect(cubit.state.layerId, isNull);
          unawaited(cubit.close());
        });
      });

      test('hides the hint when anything else is moved', () {
        final cubit = TextWrapHintCubit()
          ..layerTransformed('title')
          ..layerTransformed(null);

        expect(cubit.state.layerId, isNull);
        addTearDown(cubit.close);
      });

      test('keeps a text selected in the timeline', () {
        final cubit = TextWrapHintCubit()
          ..layerSelected('selected')
          ..layerTransformed('other');

        expect(cubit.state.layerId, 'selected');
        addTearDown(cubit.close);
      });
    });

    group('layerSelected', () {
      test('keeps the hint up while the text stays selected', () {
        fakeAsync((async) {
          final cubit = TextWrapHintCubit()..layerSelected('title');

          async.elapse(TextWrapHintCubit.defaultTransientDuration * 2);
          expect(cubit.state.layerId, 'title');
          expect(cubit.state.isPinned, isTrue);
          unawaited(cubit.close());
        });
      });

      test('hides the hint when the selection is cleared', () {
        final cubit = TextWrapHintCubit()
          ..layerSelected('title')
          ..layerSelected(null);

        expect(cubit.state.layerId, isNull);
        addTearDown(cubit.close);
      });
    });

    group('wrapToggled', () {
      test('keeps a pinched text up for another while', () {
        fakeAsync((async) {
          final cubit = TextWrapHintCubit()..layerTransformed('title');

          async.elapse(TextWrapHintCubit.defaultTransientDuration * 0.75);
          cubit.wrapToggled();
          async.elapse(TextWrapHintCubit.defaultTransientDuration * 0.75);

          expect(cubit.state.layerId, 'title');
          unawaited(cubit.close());
        });
      });
    });

    group('layersChanged', () {
      test('asks the hint to read its layer again', () {
        final cubit = TextWrapHintCubit()..layerTransformed('title');
        final before = cubit.state.revision;

        cubit.layersChanged();

        expect(cubit.state.revision, before + 1);
        expect(cubit.state.layerId, 'title');
        addTearDown(cubit.close);
      });

      test('does nothing without a hint', () {
        final cubit = TextWrapHintCubit()..layersChanged();

        expect(cubit.state, const TextWrapHintState());
        addTearDown(cubit.close);
      });
    });
  });
}
