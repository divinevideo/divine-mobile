// ABOUTME: Tests for media authentication interceptor handling 401 errors
// ABOUTME: Validates privacy-first auth flow for age-restricted Blossom content

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';

class MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockBuildContext extends Mock implements BuildContext {}

class FakeBuildContext extends Fake implements BuildContext {}

void main() {
  late MockAgeVerificationService mockAgeVerificationService;
  late MockBlossomAuthService mockBlossomAuthService;
  late MediaAuthInterceptor interceptor;
  late MockBuildContext mockContext;

  setUpAll(() {
    registerFallbackValue(FakeBuildContext());
  });

  setUp(() {
    mockAgeVerificationService = MockAgeVerificationService();
    mockBlossomAuthService = MockBlossomAuthService();
    mockContext = MockBuildContext();
    interceptor = MediaAuthInterceptor(
      ageVerificationService: mockAgeVerificationService,
      blossomAuthService: mockBlossomAuthService,
    );

    // Default mock behavior for preference checks
    when(() => mockAgeVerificationService.shouldHideAdultContent)
        .thenReturn(false);
    when(() => mockAgeVerificationService.shouldAutoShowAdultContent)
        .thenReturn(false);
  });

  group('MediaAuthInterceptor - 401 handling', () {
    test('returns null when user is not verified and denies confirmation',
        () async {
      // Arrange
      when(() => mockContext.mounted).thenReturn(true);
      when(() => mockAgeVerificationService.isAdultContentVerified)
          .thenReturn(false);
      when(() => mockAgeVerificationService.verifyAdultContentAccess(any()))
          .thenAnswer((_) async => false);

      // Act
      final result = await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'abc123',
        category: 'nudity',
      );

      // Assert
      expect(result, isNull);
      verify(() => mockAgeVerificationService.verifyAdultContentAccess(any()))
          .called(1);
      verifyNever(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ));
    });

    test('creates auth header when user has alwaysShow preference and is verified', () async {
      // Arrange - shouldAutoShowAdultContent means verified + alwaysShow preference
      when(() => mockAgeVerificationService.shouldAutoShowAdultContent)
          .thenReturn(true);
      when(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          )).thenAnswer((_) async => 'Nostr abc123token');

      // Act
      final result = await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'abc123',
        category: 'nudity',
      );

      // Assert
      expect(result, equals('Nostr abc123token'));
      verifyNever(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()));
      verify(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: 'abc123',
            serverUrl: null,
          )).called(1);
    });

    test('creates auth header when user confirms adult content access via dialog',
        () async {
      // Arrange - default askEachTime preference (shouldAutoShowAdultContent=false)
      when(() => mockContext.mounted).thenReturn(true);
      when(() => mockAgeVerificationService.verifyAdultContentAccess(any()))
          .thenAnswer((_) async => true);
      when(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          )).thenAnswer((_) async => 'Nostr abc123token');

      // Act
      final result = await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'abc123',
        category: 'nudity',
      );

      // Assert
      expect(result, equals('Nostr abc123token'));
      verify(() => mockAgeVerificationService.verifyAdultContentAccess(any()))
          .called(1);
      verify(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: 'abc123',
            serverUrl: null,
          )).called(1);
    });

    test('includes serverUrl in auth header when provided', () async {
      // Arrange - auto-show mode
      when(() => mockAgeVerificationService.shouldAutoShowAdultContent)
          .thenReturn(true);
      when(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          )).thenAnswer((_) async => 'Nostr tokenWithServer');

      // Act
      final result = await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'xyz789',
        serverUrl: 'https://blossom.example.com',
        category: 'nudity',
      );

      // Assert
      expect(result, equals('Nostr tokenWithServer'));
      verify(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: 'xyz789',
            serverUrl: 'https://blossom.example.com',
          )).called(1);
    });

    test('logs category for future extensibility', () async {
      // Arrange - auto-show mode
      when(() => mockAgeVerificationService.shouldAutoShowAdultContent)
          .thenReturn(true);
      when(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          )).thenAnswer((_) async => 'Nostr token');

      // Act - Test with different category (future-proofing for violence, etc.)
      await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'abc123',
        category: 'violence',
      );

      // Assert - Should still work (currently only handles nudity/adult content)
      verify(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: 'abc123',
            serverUrl: null,
          )).called(1);
    });

    test('returns null when BlossomAuthService fails to create header',
        () async {
      // Arrange - auto-show mode but auth service returns null
      when(() => mockAgeVerificationService.shouldAutoShowAdultContent)
          .thenReturn(true);
      when(() => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          )).thenAnswer((_) async => null);

      // Act
      final result = await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'abc123',
        category: 'nudity',
      );

      // Assert
      expect(result, isNull);
    });
  });

  group('MediaAuthInterceptor - helper methods', () {
    test('canCreateAuthHeaders delegates to BlossomAuthService', () {
      // Arrange
      when(() => mockBlossomAuthService.canCreateHeaders).thenReturn(true);

      // Act
      final result = interceptor.canCreateAuthHeaders;

      // Assert
      expect(result, isTrue);
      verify(() => mockBlossomAuthService.canCreateHeaders).called(1);
    });

    test('currentUserPubkey delegates to BlossomAuthService', () {
      // Arrange
      when(() => mockBlossomAuthService.currentUserPubkey)
          .thenReturn('npub123');

      // Act
      final result = interceptor.currentUserPubkey;

      // Assert
      expect(result, equals('npub123'));
      verify(() => mockBlossomAuthService.currentUserPubkey).called(1);
    });
  });
}
