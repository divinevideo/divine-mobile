import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/profile/profile_cache_load_indicator.dart';

void main() {
  group(ProfileCacheLoadIndicator, () {
    testWidgets('renders a linear progress indicator at its fixed height', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProfileCacheLoadIndicator()),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final size = tester.getSize(find.byType(ProfileCacheLoadIndicator));
      expect(size.height, ProfileCacheLoadIndicator.height);
    });
  });
}
