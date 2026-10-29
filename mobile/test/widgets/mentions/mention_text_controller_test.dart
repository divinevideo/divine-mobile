import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/mentions/mention_text_controller.dart';

const _river =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  group(MentionTextController, () {
    late MentionTextController controller;

    setUp(() {
      controller = MentionTextController();
      controller.value = const TextEditingValue(
        text: 'Hi @riv',
        selection: TextSelection.collapsed(offset: 7),
      );
      controller.selectMention(pubkey: _river, display: 'River');
    });
    tearDown(() => controller.dispose());

    test('preserves the selected account when text before it moves', () {
      controller.text = 'Hello! ${controller.text}';
      final binding = controller.bindings.single;
      expect(binding.pubkey, _river);
      expect(binding.start, 10);
      expect(binding.end, 16);
      expect(controller.text.substring(10, 16), '@River');
    });

    test('drops a binding when the selected token is edited', () {
      controller.text = 'Hi @Riven ';
      expect(controller.bindings, isEmpty);
    });

    test('does not bind a newly typed same-name token after clearing', () {
      controller.clear();
      controller.text = '@River';
      expect(controller.bindings, isEmpty);
    });

    test('does not keep an account when a token becomes a longer handle', () {
      controller.text = 'Hi @Riverbank ';
      expect(controller.bindings, isEmpty);
    });

    test(
      'deleting the first repeated name keeps the second chosen account',
      () {
        controller.clear();
        controller.value = const TextEditingValue(
          text: '@ri',
          selection: TextSelection.collapsed(offset: 3),
        );
        controller.selectMention(pubkey: _river, display: 'River');
        controller.value = const TextEditingValue(
          text: '@River @ri',
          selection: TextSelection.collapsed(offset: 10),
        );
        controller.selectMention(pubkey: '4' * 64, display: 'River');
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 7,
        );
        controller.value = const TextEditingValue(
          text: '@River ',
          selection: TextSelection.collapsed(offset: 0),
        );
        expect(controller.bindings.single.pubkey, '4' * 64);
        expect(controller.bindings.single.start, 0);
        expect(controller.bindings.single.end, 6);
      },
    );
  });
}
