import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';

void main() {
  group(ScrollPaginationMixin, () {
    testWidgets(
      'triggers load more near the bottom once per in-flight request',
      (tester) async {
        final completer = Completer<void>();
        var loadMoreCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _TestWidget(
              canLoadMore: () => true,
              onLoadMore: () {
                loadMoreCalls++;
                return completer.future;
              },
            ),
          ),
        );

        final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
        final scrollController = state.paginationScrollController;

        expect(scrollController.hasClients, isTrue);
        expect(scrollController.position.maxScrollExtent, greaterThan(0));

        scrollController.jumpTo(
          scrollController.position.maxScrollExtent - 100,
        );
        await tester.pump();

        expect(loadMoreCalls, 1);

        // Second scroll while first load is pending — should be ignored
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        expect(loadMoreCalls, 1);

        completer.complete();
        await tester.pump();

        // Scroll away from bottom, then back — should trigger again
        scrollController.jumpTo(0);
        await tester.pump();
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        expect(loadMoreCalls, 2);
      },
    );

    testWidgets('prefetches a viewport ahead of the bottom by default', (
      tester,
    ) async {
      var loadMoreCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _TestWidget(
            canLoadMore: () => true,
            onLoadMore: () async => loadMoreCalls++,
          ),
        ),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
      final scrollController = state.paginationScrollController;
      final viewport = scrollController.position.viewportDimension;

      // Just under one viewport from the bottom — still well outside any
      // fixed few-hundred-pixel threshold, but inside the 1.5-viewport
      // prefetch distance.
      scrollController.jumpTo(
        scrollController.position.maxScrollExtent - (viewport - 1),
      );
      await tester.pump();

      expect(loadMoreCalls, 1);
    });

    testWidgets(
      'a larger paginationLoadMoreThreshold triggers further from the bottom',
      (tester) async {
        var loadMoreCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _TestWidget(
              canLoadMore: () => true,
              onLoadMore: () async => loadMoreCalls++,
              loadMoreThreshold: 4000,
            ),
          ),
        );

        final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
        final scrollController = state.paginationScrollController;
        final viewport = scrollController.position.viewportDimension;

        // Three viewports from the bottom: past the 1.5-viewport default (no
        // trigger) but inside the overridden 4000px one (triggers).
        scrollController.jumpTo(
          scrollController.position.maxScrollExtent - viewport * 3,
        );
        await tester.pump();

        expect(loadMoreCalls, 1);
      },
    );

    testWidgets('does not trigger when canLoadMore returns false', (
      tester,
    ) async {
      var canLoadMore = false;
      var loadMoreCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _TestWidget(
            canLoadMore: () => canLoadMore,
            onLoadMore: () async {
              loadMoreCalls++;
            },
          ),
        ),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
      final scrollController = state.paginationScrollController;

      expect(scrollController.hasClients, isTrue);
      expect(scrollController.position.maxScrollExtent, greaterThan(0));

      scrollController.jumpTo(scrollController.position.maxScrollExtent - 100);
      await tester.pump();

      expect(loadMoreCalls, 0);

      canLoadMore = true;
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();

      expect(loadMoreCalls, 1);
    });

    testWidgets(
      'does not throw when the scroll controller has multiple positions',
      (tester) async {
        var loadMoreCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: _MultiPositionTestWidget(
              onLoadMore: () async {
                loadMoreCalls++;
              },
            ),
          ),
        );

        final state = tester.state<_MultiPositionTestWidgetState>(
          find.byType(_MultiPositionTestWidget),
        );
        final scrollController = state.paginationScrollController;

        expect(scrollController.positions.length, 2);

        scrollController.jumpTo(
          scrollController.positions.first.maxScrollExtent,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(loadMoreCalls, 1);
      },
    );
  });
}

/// Test widget that uses [ScrollPaginationMixin].
class _TestWidget extends StatefulWidget {
  const _TestWidget({
    required this.canLoadMore,
    required this.onLoadMore,
    this.loadMoreThreshold,
  });

  final bool Function() canLoadMore;
  final FutureOr<void> Function() onLoadMore;
  final double? loadMoreThreshold;

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> with ScrollPaginationMixin {
  final _scrollController = ScrollController();

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  double get paginationLoadMoreThreshold =>
      widget.loadMoreThreshold ?? super.paginationLoadMoreThreshold;

  @override
  bool canLoadMore() => widget.canLoadMore();

  @override
  FutureOr<void> onLoadMore() => widget.onLoadMore();

  @override
  void initState() {
    super.initState();
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: 100,
      itemBuilder: (context, index) =>
          SizedBox(height: 80, child: Text('Item $index')),
    );
  }
}

class _MultiPositionTestWidget extends StatefulWidget {
  const _MultiPositionTestWidget({required this.onLoadMore});

  final FutureOr<void> Function() onLoadMore;

  @override
  State<_MultiPositionTestWidget> createState() =>
      _MultiPositionTestWidgetState();
}

class _MultiPositionTestWidgetState extends State<_MultiPositionTestWidget>
    with ScrollPaginationMixin {
  final _scrollController = ScrollController();

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() => true;

  @override
  FutureOr<void> onLoadMore() => widget.onLoadMore();

  @override
  void initState() {
    super.initState();
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildList()),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: 100,
      itemBuilder: (context, index) =>
          SizedBox(height: 40, child: Text('Item $index')),
    );
  }
}
