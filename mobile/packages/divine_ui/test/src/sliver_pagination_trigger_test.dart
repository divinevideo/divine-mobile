import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group(SliverPaginationTrigger, () {
    Widget buildSubject({
      required bool hasMore,
      required bool isLoadingMore,
      required VoidCallback onLoadMore,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPaginationTrigger(
                hasMore: hasMore,
                isLoadingMore: isLoadingMore,
                onLoadMore: onLoadMore,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets(
      'shows nothing when hasMore is false',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            hasMore: false,
            isLoadingMore: false,
            onLoadMore: () {},
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'shows loading indicator when isLoadingMore is true',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            hasMore: true,
            isLoadingMore: true,
            onLoadMore: () {},
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'calls onLoadMore when sentinel is mounted',
      (tester) async {
        var loadMoreCalled = false;

        await tester.pumpWidget(
          buildSubject(
            hasMore: true,
            isLoadingMore: false,
            onLoadMore: () => loadMoreCalled = true,
          ),
        );

        expect(loadMoreCalled, isTrue);
      },
    );

    testWidgets(
      'does not call onLoadMore when isLoadingMore is true',
      (tester) async {
        var loadMoreCalled = false;

        await tester.pumpWidget(
          buildSubject(
            hasMore: true,
            isLoadingMore: true,
            onLoadMore: () => loadMoreCalled = true,
          ),
        );

        expect(loadMoreCalled, isFalse);
      },
    );

    testWidgets(
      'does not call onLoadMore when hasMore is false',
      (tester) async {
        var loadMoreCalled = false;

        await tester.pumpWidget(
          buildSubject(
            hasMore: false,
            isLoadingMore: false,
            onLoadMore: () => loadMoreCalled = true,
          ),
        );

        expect(loadMoreCalled, isFalse);
      },
    );

    testWidgets(
      'fires again when sentinel remounts after loading cycle',
      (tester) async {
        var callCount = 0;

        // Step 1: sentinel mounts, fires onLoadMore.
        await tester.pumpWidget(
          buildSubject(
            hasMore: true,
            isLoadingMore: false,
            onLoadMore: () => callCount++,
          ),
        );
        expect(callCount, equals(1));

        // Step 2: isLoadingMore → true — sentinel replaced by spinner.
        await tester.pumpWidget(
          buildSubject(
            hasMore: true,
            isLoadingMore: true,
            onLoadMore: () => callCount++,
          ),
        );
        expect(callCount, equals(1));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Step 3: loading done, hasMore still true — new sentinel mounts,
        // fires onLoadMore again.
        await tester.pumpWidget(
          buildSubject(
            hasMore: true,
            isLoadingMore: false,
            onLoadMore: () => callCount++,
          ),
        );
        expect(callCount, equals(2));
      },
    );

    testWidgets(
      'does not re-fire onLoadMore on widget rebuild',
      (tester) async {
        var callCount = 0;

        await tester.pumpWidget(
          buildSubject(
            hasMore: true,
            isLoadingMore: false,
            onLoadMore: () => callCount++,
          ),
        );

        expect(callCount, equals(1));

        // Pump again — sentinel is already mounted, initState should not
        // re-fire.
        await tester.pump();
        await tester.pump();

        expect(callCount, equals(1));
      },
    );
  });
}
