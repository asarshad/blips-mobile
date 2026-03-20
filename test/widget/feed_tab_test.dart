@Tags(['widget'])
library feed_tab_test;

import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/tabs/feed_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  List<FeedPageItem> buildArticleItems(int count) {
    return List<FeedPageItem>.generate(count, (index) {
      return OrganicFeedPageItem(
        ArticleFeedEntry(
          id: index + 1,
          title: 'Article ${index + 1}',
          summary: 'Summary ${index + 1}',
          source: 'Source',
          publishedAt: DateTime.utc(2026, 3, 1).add(Duration(days: index)),
          url: 'https://example.com/${index + 1}',
          imageUrl: 'https://example.com/${index + 1}.png',
          category: 'Technology',
          readTime: 3,
        ),
      );
    });
  }

  testWidgets('triggers load more after restoring onto last loaded item',
      (tester) async {
    var loadMoreCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              width: 400,
              child: FeedTab<FeedPageItem>(
                feed: AsyncValue.data(buildArticleItems(15)),
                emptyLabel: 'empty',
                overlayLabel: 'ART',
                onRefresh: () {},
                onLoadMore: () => loadMoreCalls += 1,
                restoreApproximateIndex: 14,
                builder: (_, __) => const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(loadMoreCalls, greaterThanOrEqualTo(1));
  });
}
