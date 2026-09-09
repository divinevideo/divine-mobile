import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/invite_models.dart';

void main() {
  group(InviteCode, () {
    test('fromJson parses unclaimed code', () {
      final json = <String, dynamic>{
        'code': 'AB23-EF7K',
        'claimed': false,
        'claimedAt': null,
        'claimedBy': null,
      };
      final code = InviteCode.fromJson(json);
      expect(code.code, equals('AB23-EF7K'));
      expect(code.claimed, isFalse);
      expect(code.claimedAt, isNull);
      expect(code.claimedBy, isNull);
    });

    test('fromJson parses claimed code', () {
      final json = <String, dynamic>{
        'code': 'AB23-EF7K',
        'claimed': true,
        'claimedAt': '2025-01-15T10:30:00Z',
        'claimedBy':
            'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1',
      };
      final code = InviteCode.fromJson(json);
      expect(code.claimed, isTrue);
      expect(code.claimedAt, isNotNull);
      expect(
        code.claimedBy,
        equals(
          'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1',
        ),
      );
    });

    test('fromJson handles missing fields gracefully', () {
      final code = InviteCode.fromJson(const <String, dynamic>{});
      expect(code.code, isEmpty);
      expect(code.claimed, isFalse);
      expect(code.claimedAt, isNull);
      expect(code.claimedBy, isNull);
    });

    test('supports equality via Equatable', () {
      const a = InviteCode(code: 'AB23-EF7K', claimed: false);
      const b = InviteCode(code: 'AB23-EF7K', claimed: false);
      const c = InviteCode(code: 'XXXX-YYYY', claimed: false);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group(InviteStatus, () {
    test('fromJson parses eligible user with codes', () {
      final json = <String, dynamic>{
        'canInvite': true,
        'remaining': 3,
        'total': 5,
        'codes': <Map<String, dynamic>>[
          {
            'code': 'AB23-EF7K',
            'claimed': false,
            'claimedAt': null,
            'claimedBy': null,
          },
          {
            'code': 'HN4P-QR56',
            'claimed': true,
            'claimedAt': '2025-01-15T10:30:00Z',
            'claimedBy': 'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1',
          },
        ],
      };
      final status = InviteStatus.fromJson(json);
      expect(status.canInvite, isTrue);
      expect(status.remaining, equals(3));
      expect(status.total, equals(5));
      expect(status.codes, hasLength(2));
    });

    test('fromJson parses ineligible user', () {
      final json = <String, dynamic>{
        'canInvite': false,
        'remaining': 0,
        'total': 0,
        'codes': <Map<String, dynamic>>[],
      };
      final status = InviteStatus.fromJson(json);
      expect(status.canInvite, isFalse);
      expect(status.codes, isEmpty);
    });

    test('fromJson handles missing codes key', () {
      final status = InviteStatus.fromJson(const <String, dynamic>{
        'canInvite': false,
      });
      expect(status.remaining, equals(0));
      expect(status.total, equals(0));
      expect(status.codes, isEmpty);
    });

    test('unclaimedCodes returns only unclaimed', () {
      const status = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 2,
        codes: [
          InviteCode(code: 'AAAA-BBBB', claimed: false),
          InviteCode(code: 'CCCC-DDDD', claimed: true, claimedBy: 'abc'),
        ],
      );
      expect(status.unclaimedCodes, hasLength(1));
      expect(status.unclaimedCodes.first.code, equals('AAAA-BBBB'));
    });

    test('claimedCodes returns only claimed', () {
      const status = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 2,
        codes: [
          InviteCode(code: 'AAAA-BBBB', claimed: false),
          InviteCode(code: 'CCCC-DDDD', claimed: true, claimedBy: 'abc'),
        ],
      );
      expect(status.claimedCodes, hasLength(1));
      expect(status.claimedCodes.first.code, equals('CCCC-DDDD'));
    });

    test('hasUnclaimedCodes is true when unclaimed exist', () {
      const status = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 1,
        codes: [InviteCode(code: 'AAAA-BBBB', claimed: false)],
      );
      expect(status.hasUnclaimedCodes, isTrue);
    });

    test('hasUnclaimedCodes is false when all claimed', () {
      const status = InviteStatus(
        canInvite: true,
        remaining: 0,
        total: 1,
        codes: [InviteCode(code: 'AAAA-BBBB', claimed: true)],
      );
      expect(status.hasUnclaimedCodes, isFalse);
    });

    test('supports equality via Equatable', () {
      const a = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 1,
        codes: [InviteCode(code: 'AAAA-BBBB', claimed: false)],
      );
      const b = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 1,
        codes: [InviteCode(code: 'AAAA-BBBB', claimed: false)],
      );
      expect(a, equals(b));
    });
  });

  group(GenerateInviteResult, () {
    test('fromJson parses result', () {
      final result = GenerateInviteResult.fromJson(const <String, dynamic>{
        'code': 'WX56-3MKT',
        'remaining': 4,
      });
      expect(result.code, equals('WX56-3MKT'));
      expect(result.remaining, equals(4));
    });

    test('fromJson handles missing fields', () {
      final result = GenerateInviteResult.fromJson(const <String, dynamic>{});
      expect(result.code, isEmpty);
      expect(result.remaining, equals(0));
    });

    test('supports equality via Equatable', () {
      const a = GenerateInviteResult(code: 'WX56-3MKT', remaining: 4);
      const b = GenerateInviteResult(code: 'WX56-3MKT', remaining: 4);
      expect(a, equals(b));
    });
  });
}
