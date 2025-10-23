# Detailed Test Comparison: Feature Branch vs Main

## Summary
- **Feature Branch**: 562 failing tests
- **Main Branch**: 558 failing tests  
- **Net Change**: +4 failures

## Breakdown
- **New Failures** (feature branch only): 10 tests
- **Fixed Tests** (main failures now passing): 6 tests
- **Common Failures** (both branches): 552 tests

## New Failures Introduced by Feature Branch (10):
CuratedListService - Query Operations Query Operations - Edge Cases search handles special characters [E]
CuratedListService - Query Operations Query Operations - Edge Cases search handles unicode characters [E]
CuratedListService - Query Operations searchLists() finds lists by tags [E]
ExploreScreen - Video Display Tests should display videos in grid when data is available [E]
ExploreScreen - Video Display Tests should show empty state when no videos available [E]
ExploreScreen - Video Display Tests should show loading state while fetching videos [E]
ExploreScreen - Video Display Tests should switch tabs correctly [E]
loading /Users/rabble/code/andotherstuff/openvine/mobile/test/providers/video_events_provider_listener_test.dart [E]
loading /Users/rabble/code/andotherstuff/openvine/mobile/test/services/vine_recording_controller_preview_test.dart [E]
SearchScreenPure Hybrid Search Tests should combine local and remote search results [E]

## Tests Fixed by Feature Branch (6):
accessing previewWidget before initialization should throw meaningful error [E]
BugReportDialog should disable Send button when description is empty [E]
BugReportDialog should display title and description field [E]
Home Feed Display Bug should show empty state when user is not following anyone [E]
preview widget should be available immediately when state=idle after init [E]
VideoOverlayActions contextTitle does not show contextTitle chip when null [E]
