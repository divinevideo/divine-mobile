import 'package:models/models.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:test/test.dart';

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _member =
    '2222222222222222222222222222222222222222222222222222222222222222';

void main() {
  group(PeopleListSearchResult, () {
    final list = UserList(
      id: 'crew',
      name: 'Crew',
      pubkeys: const [_member],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    test('counts the members its list holds by default', () {
      expect(
        PeopleListSearchResult(ownerPubkey: _owner, list: list).memberCount,
        1,
      );
    });

    test('keeps a count beyond the members its list previews', () {
      expect(
        PeopleListSearchResult(
          ownerPubkey: _owner,
          list: list,
          memberCount: 32,
        ).memberCount,
        32,
      );
    });

    test('tells results with different member counts apart', () {
      expect(
        PeopleListSearchResult(ownerPubkey: _owner, list: list),
        isNot(
          PeopleListSearchResult(
            ownerPubkey: _owner,
            list: list,
            memberCount: 32,
          ),
        ),
      );
      expect(
        PeopleListSearchResult(ownerPubkey: _owner, list: list),
        PeopleListSearchResult(ownerPubkey: _owner, list: list, memberCount: 1),
      );
    });
  });
}
