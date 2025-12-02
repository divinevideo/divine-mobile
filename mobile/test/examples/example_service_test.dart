import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/example_service.dart';

void main() {
  group('ExampleService', () {
    late ExampleService service;

    setUp(() {
      service = ExampleService();
    });

    tearDown(() {
      service.dispose();
    });

    test('should initialize correctly', () {
      expect(service.isInitialized, isTrue);
    });

    test('should handle errors gracefully', () {
      expect(() => service.doSomethingThatFails(), 
          throwsA(isA<CustomException>()));
    });
  });
}
