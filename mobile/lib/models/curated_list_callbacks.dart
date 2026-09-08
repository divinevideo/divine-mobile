// ABOUTME: Subscription callback typedefs used by CuratedListService.
// ABOUTME: Re-exported by curated_list_service.dart for its existing callers.

/// Callback type for list subscription events
/// Called with listId and the video IDs in that list
typedef OnListSubscribedCallback = Future<void> Function(
  String listId,
  List<String> videoIds,
);

/// Callback type for list unsubscription events
/// Called with listId when a list is unsubscribed
typedef OnListUnsubscribedCallback = void Function(String listId);
