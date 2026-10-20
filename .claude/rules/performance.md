# Performance

Divine is a video-centric app. Users scroll through feeds, play videos, and interact with media-heavy screens. Performance directly affects retention — dropped frames, slow loads, and memory pressure cause users to leave.

---

## Widget Rebuild Optimization

### Use `const` Constructors
Mark widgets and values `const` wherever possible. Flutter skips diffing for `const` subtrees:

```dart
// Good — no rebuild on parent change
return const Column(
  children: [
    Text('Static title'),
    SizedBox(height: 8),
  ],
);

// Bad — new instances every build
return Column(
  children: [
    Text('Static title'),
    SizedBox(height: 8),
  ],
);
```

### Use `BlocSelector` / `context.select` for Granular Rebuilds
When a widget only needs one property from state, select it. Watching full state causes unnecessary rebuilds:

```dart
// Good — rebuilds only when sendStatus changes
final sendStatus = context.select(
  (MyBloc bloc) => bloc.state.sendStatus,
);

// Bad — rebuilds on ANY state change
final state = context.watch<MyBloc>().state;
```

See `state_management.md` for detailed patterns.

### Split Large Widgets into Small Private Widgets
Extract subtrees into small, focused widget classes. Flutter rebuilds at the widget boundary — a `BlocBuilder` or `context.select` inside a small widget only rebuilds that widget, not the entire parent tree:

```dart
// Good — only _SendButton rebuilds when sendStatus changes
class ChatView extends StatelessWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MessageList(),
        _SendButton(),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (ChatBloc b) => b.state.sendStatus,
    );
    return ElevatedButton(
      onPressed: status == SendStatus.ready ? () {} : null,
      child: const Text('Send'),
    );
  }
}
```

See `code_style.md` for the general "prefer widgets over methods" rule.

### Use `RepaintBoundary` for Expensive Subtrees
Wrap widgets that repaint frequently (sliders, progress bars, animations) to isolate their repaint from the parent tree:

```dart
// Good — slider repaints don't trigger parent repaint
RepaintBoundary(
  child: VideoProgressBar(
    progress: progress,
    onSeek: _onSeek,
  ),
)
```

**When to use:**
- Animated or frequently updating widgets inside mostly-static parents
- Custom painters with per-frame updates
- Video editor overlays (split bars, filters, draw layers)

**When NOT to use:**
- Everywhere — each `RepaintBoundary` adds a compositing layer. Overuse wastes GPU memory. Profile first.

---

## Image and Thumbnail Loading

### Use `VineCachedImage` for Network Images
Always use the project's `VineCachedImage` wrapper — it provides caching and platform-specific config:

```dart
// Good — uses project caching infrastructure
VineCachedImage(
  imageUrl: thumbnailUrl,
)

// Bad — no caching, no placeholder
Image.network(thumbnailUrl)
```

### Constrain Image Memory Size
Set `memCacheWidth` or `memCacheHeight` to prevent decoding full-resolution images when displaying thumbnails:

```dart
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: 400, // decode at thumbnail size, not 4K
)
```

---

## Video Feed Performance

### Lazy Construction with `ListView.builder`
Never use plain `ListView` for feeds. Always use `ListView.builder` or `ListView.separated` for lazy item construction:

```dart
// Good — items built on demand
ListView.builder(
  itemCount: videos.length,
  itemBuilder: (context, index) => VideoFeedItem(
    video: videos[index],
  ),
)

// Bad — all items built upfront
ListView(
  children: videos.map(VideoFeedItem.new).toList(),
)
```

### Gate Work with `VisibilityDetector`
Use `VisibilityDetector` to start expensive operations (analytics, timers, preloading) only when the item is visible:

```dart
VisibilityDetector(
  key: Key('video_$id'),
  onVisibilityChanged: (info) {
    if (info.visibleFraction > 0.5) {
      _startAnalyticsTimer();
    } else {
      _stopAnalyticsTimer();
    }
  },
  child: VideoPlayer(url: url),
)
```

---

## Pagination

### Use Cursor-Based Pagination
Prefer cursor-based over offset-based pagination. Offset pagination breaks when items are inserted or deleted during scrolling:

```dart
// Good — cursor based
Future<VideoPage> getVideos({String? cursor}) async {
  final response = await _client.fetch(
    '/videos',
    queryParameters: {'after': cursor},
  );
  return VideoPage(
    items: response.items,
    nextCursor: response.nextCursor,
    hasMore: response.hasMore,
  );
}

// Bad — offset based (can miss or duplicate items)
Future<List<Video>> getVideos({int offset = 0}) async {
  return _client.fetch('/videos?offset=$offset');
}
```

### Trigger Load Before End
Start fetching the next page before the user reaches the last item. A common threshold is 3–5 items from the end:

```dart
if (index >= videos.length - 3 && state.hasMore) {
  context.read<FeedBloc>().add(const FeedLoadMore());
}
```

---

## Memory Management

### Dispose Resources in `dispose()`
Cancel stream subscriptions, dispose controllers, and release video resources:

```dart
@override
void dispose() {
  _scrollController.dispose();
  _subscription.cancel();
  _videoController.dispose();
  super.dispose();
}
```

### Video Player Cache Limits
The project uses a 500 MB LRU disk cache for video content. Don't override this without profiling on low-end devices. Large caches cause storage pressure on older phones.

### Image Cache Tuning
Startup sizes Flutter's decoded-image cache by device RAM in `mobile/lib/startup/image_cache_budget.dart`: RAM / 48, clamped to 96–256 MB, and 128 MB when RAM is unknown (web, desktop, or a failed channel call). The divisor and the bounds are `AppConstants.imageCache*`; change the budget through them. Another `imageCache.maximumSizeBytes` assignment anywhere else silently overrides it on every device. Flutter's own default (1000 entries, 100 MiB) applies only until startup sets it.

Clearing the cache frees nothing until a frame is drawn, because `ImageCache` releases each image it drops in a post-frame callback. Clear through `clearDecodedImageCache()` (`mobile/lib/utils/decoded_image_cache.dart`), which schedules that frame, rather than calling `imageCache.clear()` directly.

Only tune the budget with profiling data — don't guess.

---

## Expensive Computation

### Use `compute()` for Blocking Work
Keep the UI thread free. Move CPU-intensive tasks to a background isolate:

```dart
// Good — runs on background isolate
final result = await compute(parseEvents, rawData);

// Bad — blocks the UI thread
final result = parseEvents(rawData);
```

**Use `compute()` when:**
- Parsing large JSON payloads
- Batch cryptographic operations (signing, decrypting)
- Image/video metadata extraction
- Sorting or filtering large datasets (1000+ items)

**Don't use for:**
- Simple transformations (a few maps/filters)
- Operations under ~1ms — isolate overhead negates the benefit

### Isolates for Long-Running Work
For persistent background tasks (relay connections, event processing), use dedicated isolates instead of `compute()`:

```dart
// Project pattern — relay runs in its own isolate
final relayIsolate = await Isolate.spawn(
  relayEntryPoint,
  relayConfig,
);
```

---

## Build Method Discipline

### Never Do Expensive Work in `build()`
The `build()` method runs **frequently** — every frame during animations. Keep it pure:

```dart
// Bad — network call in build
@override
Widget build(BuildContext context) {
  final data = await api.fetchData(); // NEVER
  return Text(data.title);
}

// Bad — expensive computation in build
@override
Widget build(BuildContext context) {
  final sorted = videos.toList()
    ..sort((a, b) => b.date.compareTo(a.date)); // Move to BLoC
  return ListView.builder(...);
}

// Good — read pre-computed state
@override
Widget build(BuildContext context) {
  final state = context.watch<FeedBloc>().state;
  return ListView.builder(
    itemCount: state.sortedVideos.length,
    itemBuilder: (_, i) => VideoItem(state.sortedVideos[i]),
  );
}
```

---

## Code Review Checklist (Agent-Enforceable)

When writing or reviewing code, flag these patterns as potential performance issues.

### Must Fix
- **Missing `dispose()`** on `ScrollController`, `AnimationController`, `StreamSubscription` — causes memory leaks
- **Network call or heavy async work in `build()`** — blocks the UI thread every frame
- **Sorting, filtering, or mapping inside `build()`** — move to BLoC/Cubit

### Should Fix
- **Plain `ListView()` with many children** → suggest `ListView.builder`
- **`Image.network()` without caching** → suggest `VineCachedImage`
- **Offset-based pagination** → suggest cursor-based
- **Fixed `SizedBox` around text** → suggest `ConstrainedBox(minHeight:)`

### Nitpick
- **`context.watch` on full state** when only one property is used → suggest `context.select`
- **Missing `const` on widget constructors** that could be const
- **New `RepaintBoundary` without justification** → ask whether profiling showed a repaint problem
- **`compute()` on trivial work** (simple map/filter) → remove isolate overhead

Don't add speculative optimizations. Flag the pattern and let the developer decide based on profiling data.
