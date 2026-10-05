import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/app_config.dart';

void main() {
  group('public people-list discovery configuration', () {
    test('deployment policy is immutable and preserves exact d-tags', () {
      final tags = AppConfig.parsePublicPeopleListExcludedDTags(
        '["synthetic-machine-set", "second-synthetic-set"]',
      );
      expect(tags, {'synthetic-machine-set', 'second-synthetic-set'});
      expect(() => tags!.add('another-set'), throwsUnsupportedError);
    });

    test('missing or malformed deployment input has no valid policy', () {
      for (final input in ['', 'null', '{}', '[4]', '[" "]', 'invalid']) {
        expect(AppConfig.parsePublicPeopleListExcludedDTags(input), isNull);
      }
    });

    test('an explicitly empty deployment policy is valid and immutable', () {
      final tags = AppConfig.parsePublicPeopleListExcludedDTags('[]');
      expect(tags, isEmpty);
      expect(() => tags!.add('synthetic-machine-set'), throwsUnsupportedError);
    });
  });
}
