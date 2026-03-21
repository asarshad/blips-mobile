#!/usr/bin/env bash

set -euo pipefail

flutter test \
  test/widget/interest_selection_page_test.dart \
  test/widget/article_card_interactions_test.dart \
  test/widget/video_card_interactions_test.dart \
  test/widget/reel_item_interactions_test.dart \
  test/widget/video_card_actions_sheet_test.dart \
  test/widget/chat_page_test.dart \
  test/widget/chat_detail_page_test.dart \
  test/widget/settings_page_test.dart \
  test/widget/ad_card_interactions_test.dart \
  test/widget/app_navigation_test.dart \
  test/widget/feed_tab_test.dart \
  test/unit/articles_notifier_refresh_test.dart \
  test/unit/videos_notifier_cache_test.dart \
  test/unit/reels_notifier_stability_test.dart \
  test/unit/feed_ordering_stability_test.dart \
  test/unit/feed_repository_test.dart \
  test/unit/feed_session_store_test.dart \
  test/unit/external_video_url_test.dart \
  test/unit/backend_api_client_test.dart \
  test/unit/youtube_player_manager_playback_test.dart
