import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group(VineTheme, () {
    for (final (appearance, theme) in [
      ('dark', VineTheme.theme),
      ('light', VineTheme.lightTheme),
    ]) {
      test('constrains $appearance dialogs and bottom sheets', () {
        expect(
          theme.dialogTheme.constraints,
          const BoxConstraints(minWidth: 280, maxWidth: 560),
        );
        expect(
          theme.bottomSheetTheme.constraints,
          const BoxConstraints(maxWidth: 640),
        );
      });
    }
  });
}
