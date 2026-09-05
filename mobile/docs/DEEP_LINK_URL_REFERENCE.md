# Deep Link URL Reference

Complete reference of all supported deep link URLs for divine.video. Use this to ensure web app routing matches mobile app deep link handling.

## URL Format

All deep links use the format:
```
https://divine.video/{type}/{identifier}[/{index}]
```

Where:
- `{type}` = video, profile, hashtag, search, or list
- `{identifier}` = ID, npub, tag, search term, or list ID
- `{index}` = Optional 0-based video index for feed view

## Supported URLs

### 1. Video Links

Opens a specific video in full-screen player.

**Pattern**: `https://divine.video/video/{videoId}`

**Parameters**:
- `videoId` (required): 64-character hexadecimal Nostr event ID

**Examples**:
```
https://divine.video/video/059fb12899fbab94d2087351d6f03ec15fb0d4266bcb049a0529f86464b84631
```

**Mobile Behavior**:
- Fetches video by event ID from Nostr
- Opens VideoDetailScreen
- Displays in full-screen video player
- Shows video metadata, author, reactions

**Web App Should**:
- Route to `/video/:id`
- Fetch event from Nostr relay
- Display video player with same metadata

---

### 2. Profile Links (Grid View)

Opens user profile in grid view showing all videos.

**Pattern**: `https://divine.video/profile/{npub}`

**Parameters**:
- `npub` (required): Nostr public key in npub1... format OR hex pubkey

**Examples**:
```
https://divine.video/profile/npub1abc123...xyz
https://divine.video/profile/a1b2c3d4e5f6... (hex pubkey also works)
```

**Mobile Behavior**:
- Navigates to `/profile/{npub}/0`
- Opens ProfileScreen
- Shows grid of user's videos
- Displays profile info (avatar, name, bio)

**Web App Should**:
- Route to `/profile/:npub` or `/profile/:npub/0`
- Fetch user profile (kind 0)
- Display video grid
- Support clicking videos to enter feed view

---

### 3. Profile Links (Feed View)

Opens user profile in feed view starting at a specific video.

**Pattern**: `https://divine.video/profile/{npub}/{index}`

**Parameters**:
- `npub` (required): Nostr public key in npub1... format
- `index` (required): 0-based video index to start playing

**Examples**:
```
https://divine.video/profile/npub1abc.../0   → First video
https://divine.video/profile/npub1abc.../5   → Sixth video
https://divine.video/profile/npub1abc.../12  → Thirteenth video
```

**Mobile Behavior**:
- Navigates to `/profile/{npub}/{index}`
- Opens ProfileScreen in feed mode
- Starts playing video at specified index
- Enables swipe up/down to navigate videos

**Web App Should**:
- Route to `/profile/:npub/:index`
- Load user's videos
- Start video player at specified index
- Support arrow keys or swipe for navigation

---

### 4. Hashtag Links (Grid View)

Opens hashtag page in grid view showing all videos with that tag.

**Pattern**: `https://divine.video/hashtag/{tag}`

**Parameters**:
- `tag` (required): Hashtag without the # symbol

**Examples**:
```
https://divine.video/hashtag/nostr
https://divine.video/hashtag/bitcoin
https://divine.video/hashtag/memes
```

**Mobile Behavior**:
- Navigates to `/hashtag/{tag}`
- Opens HashtagScreen in grid mode
- Shows grid of all videos tagged with #{tag}
- Displays hashtag title and video count

**Web App Should**:
- Route to `/hashtag/:tag`
- Query Nostr for videos with #tag
- Display video grid
- Show hashtag metadata

---

### 5. Hashtag Links (Feed View)

Opens hashtag page in feed view starting at a specific video.

**Pattern**: `https://divine.video/hashtag/{tag}/{index}`

**Parameters**:
- `tag` (required): Hashtag without the # symbol
- `index` (required): 0-based video index to start playing

**Examples**:
```
https://divine.video/hashtag/nostr/0    → First #nostr video
https://divine.video/hashtag/bitcoin/3  → Fourth #bitcoin video
https://divine.video/hashtag/memes/10   → Eleventh #memes video
```

**Mobile Behavior**:
- Navigates to `/hashtag/{tag}/{index}`
- Opens HashtagScreen in feed mode
- Starts playing video at specified index
- Filters videos by hashtag

**Web App Should**:
- Route to `/hashtag/:tag/:index`
- Load videos with #tag
- Start player at specified index
- Enable video navigation

---

### 6. Search Links (Grid View)

Opens search results in grid view for a search term.

**Pattern**: `https://divine.video/search/{term}`

**Parameters**:
- `term` (required): URL-encoded search term

**Examples**:
```
https://divine.video/search/bitcoin
https://divine.video/search/nostr%20tutorial   → "nostr tutorial"
https://divine.video/search/web3
```

**Mobile Behavior**:
- Navigates to `/search/{term}`
- Opens SearchScreen in grid mode
- Shows grid of search results
- Searches video titles, descriptions, tags

**Web App Should**:
- Route to `/search/:term`
- Decode URL-encoded term
- Search Nostr events
- Display results grid

---

### 7. Search Links (Feed View)

Opens search results in feed view starting at a specific video.

**Pattern**: `https://divine.video/search/{term}/{index}`

**Parameters**:
- `term` (required): URL-encoded search term
- `index` (required): 0-based video index in results

**Examples**:
```
https://divine.video/search/bitcoin/0   → First result for "bitcoin"
https://divine.video/search/nostr/5     → Sixth result for "nostr"
```

**Mobile Behavior**:
- Navigates to `/search/{term}/{index}`
- Opens SearchScreen in feed mode
- Starts playing result at specified index

**Web App Should**:
- Route to `/search/:term/:index`
- Load search results
- Start player at index
- Navigate through results

---

### 8. List Links

Opens a curated video list.

**Patterns**:
- `https://divine.video/list/{listId}`
- `https://divine.video/list/{pubkey}/{listId}`

**Parameters**:
- `listId` (required): Curated list d-tag or local list ID
- `pubkey` (optional): List author public key for authored web-canonical URLs

**Examples**:
```
https://divine.video/list/my-vines
https://divine.video/list/a1b2c3d4e5f6.../my-vines
```

**Mobile Behavior**:
- Navigates to `/list/{listId}` for local list links
- Navigates to `/list/{pubkey}/{listId}` for authored list links

---

## URL Patterns Summary

| URL Pattern | View | Mobile Route | Purpose |
|-------------|------|--------------|---------|
| `/video/{id}` | Player | `/video/{id}` | Play specific video |
| `/profile/{npub}` | Grid | `/profile/{npub}/0` | User's videos (grid) |
| `/profile/{npub}/{i}` | Feed | `/profile/{npub}/{i}` | User's videos (feed) |
| `/hashtag/{tag}` | Grid | `/hashtag/{tag}` | Tagged videos (grid) |
| `/hashtag/{tag}/{i}` | Feed | `/hashtag/{tag}/{i}` | Tagged videos (feed) |
| `/search/{term}` | Grid | `/search/{term}` | Search results (grid) |
| `/search/{term}/{i}` | Feed | `/search/{term}/{i}` | Search results (feed) |
| `/list/{listId}` | Grid | `/list/{listId}` | Curated video list |
| `/list/{pubkey}/{listId}` | Grid | `/list/{pubkey}/{listId}` | Authored curated video list |

## Special Characters in URLs

### Hashtags
- Always **without** the `#` symbol
- Example: `#nostr` → `/hashtag/nostr`
- Lowercase recommended but not required

### Search Terms
- **URL-encode** spaces and special characters
- Space → `%20`
- Example: "nostr tutorial" → `/search/nostr%20tutorial`

### Profile IDs
- Accept both **npub** and **hex** formats
- npub: `npub1abc...xyz` (Bech32 encoded)
- hex: `a1b2c3d4e5f6...` (64-char hex string)

### Video IDs
- Must be 64-character hexadecimal
- Nostr event ID format
- Example: `059fb12899fbab94d2087351d6f03ec15fb0d4266bcb049a0529f86464b84631`

## Navigation Behavior

### Grid to Feed Transition
When user clicks a video in grid view:
- Grid: `/hashtag/nostr`
- Clicks 5th video (index 4)
- Navigates to: `/hashtag/nostr/4`

### Feed Navigation
User swipes/scrolls through feed:
- Starts at: `/hashtag/nostr/4`
- Swipes to next video
- URL updates to: `/hashtag/nostr/5`

### URL Sharing
Any feed URL can be shared:
- Current URL: `/search/bitcoin/12`
- User shares link
- Recipient opens at same video (index 12)

## Route State And `extra`

Every route must be reachable from its URL alone. `GoRouterState.extra` is
process-local: it survives an in-app `push`, and nothing else. A universal
link, a `divine://` link, a browser refresh on the web build, a restored
session and an account switch that re-seeds the router all arrive with
`extra == null`. Flutter can also hand a *restored* `extra` back as a plain
`Map<String, dynamic>` rather than the typed object that was passed, which is
why route builders read it through `extraAs<T>` / `extraValue<T>`
(`lib/router/routes/route_extras.dart`) instead of casting.

**The contract (#3335).** A route resolves its screen from path parameters,
query parameters and repositories. `extra` is only a **warm-start cache** that
skips a fetch the route could do anyway. A route builder must never dead-end —
no blank screen, no unusable screen — because `extra` was absent.

Three shapes satisfy the contract, all of them already in the codebase:

| Shape | Example |
|---|---|
| Resolve by id, `extra` skips the fetch | `/apps/:appId/sandbox` → `SandboxRouteCubit`; `/inbox/conversation/:id` → `ConversationParticipantsCubit` |
| Scalar in a query parameter | `/video-recorder?entry_point=`, `/video-metadata?mode=`, `/video-editor?from=library` |
| `extra` is a display hint the screen already defaults | `/profile/:npub` display-name and avatar hints |

### What each `extra`-bearing route loses without it

All of these render and function; the hint only saves a fetch or improves the
first frame.

| Route | Hint | Without it |
|---|---|---|
| `/apps/:appId/sandbox`, `/apps/:appId/web-sandbox` | `NostrAppDirectoryEntry` | Resolved from the approved-integrations directory by id or slug; a spinner first |
| `/apps/:slug` | `NostrAppDirectoryEntry` | Resolved by slug |
| `/inbox/conversation/:id` | counterparty pubkeys | Read from the conversation row. A DM-restricted account (#176) is bounced to the inbox instead, by design |
| `/inbox/message-requests/:id` | counterparty pubkeys | Same, via `RequestPreviewCubit` |
| `/list/:listId` | list name, video ids, author | Videos resolve from the list id; the title falls back until the local list loads. `/list/:pubkey/:listId` resolves from relays by author + d-tag |
| `/categories/:categoryName` | `VideoCategory` | Rebuilt from the path segment with a zero video count |
| `/video/:id` | prefetched video, comment autoscroll | Loaded by id |
| `/sound/:id` | `AudioEvent` (+ source video) | `SoundDetailLoader` fetches by id |
| `/original-sound/:pubkey` | source video | Creator resolves from the pubkey; the source-video card is omitted |
| `/video-edit/:videoId`, `/subtitle-edit/:videoId` | prefetched video | Loaded by id |
| `/creator-analytics/:videoId` | `VideoPerformance` | Recomputed for that video |
| `/profile/:npub` | display name, avatar url | Read from the profile; the hint only covers accounts with no kind-0 |
| `/followers/:pubkey`, `/following/:pubkey` | display name | Title falls back until the profile loads |
| `/pooled-video-feed` | in-memory feed args | Redirects to `/video/:id` from the `?video=` parameter, else to the home feed |

### Screens reachable only by URL must also be exitable

`go_router` nests by route *tree*, not by path string, so a flat top-level
route with a multi-segment path (`/apps/:appId/sandbox`) matches as a **single**
stack entry on a cold entry. `context.pop` throws `GoError: There is nothing to
pop` there — a dead back button, and previously a FATAL (#6112). Back
affordances on these screens use `context.safePop(fallback: …)`; the
`check_unsafe_back_pop_ceiling.sh` ratchet freezes the remaining raw pops.

## Testing URLs

### Real Working Examples

**Video**:
```
https://divine.video/video/059fb12899fbab94d2087351d6f03ec15fb0d4266bcb049a0529f86464b84631
```

**Profile** (replace with real npub):
```
https://divine.video/profile/npub1...
https://divine.video/profile/npub1.../0
```

**Hashtag**:
```
https://divine.video/hashtag/nostr
https://divine.video/hashtag/nostr/0
```

**Search**:
```
https://divine.video/search/bitcoin
https://divine.video/search/bitcoin/0
```

**List**:
```
https://divine.video/list/my-vines
```

## Server Configuration Required

For deep links to work, these files must be accessible:

### iOS Universal Links
**File**: `/.well-known/apple-app-site-association`
**Content-Type**: `application/json`
**Paths**: The apex/www AASA claim set is owned by `divine-web`; the
`login.divine.video` AASA claim set is owned by `keycast`. Mobile mirrors both
payloads in `test/fixtures/deep_links/` for offline routing coverage tests.

### Android App Links
**File**: `/.well-known/assetlinks.json`
**Content-Type**: `application/json`
**Package**: `co.openvine.app`

## Web App Implementation Checklist

- [ ] Route handlers for all URL patterns claimed by the current AASA payload
- [ ] Video player component
- [ ] Grid view component
- [ ] Feed view component with navigation
- [ ] Profile page with both views
- [ ] Hashtag page with both views
- [ ] Search page with both views
- [ ] URL encoding/decoding for search terms
- [ ] npub/hex conversion for profiles
- [ ] Index parameter handling
- [ ] Video navigation (next/previous)
- [ ] URL updates on navigation
- [ ] Share button generates correct URLs
- [ ] SEO meta tags for each URL type
- [ ] Open Graph tags for social sharing

## Notes for Web Developers

1. **URL Format Must Match Exactly**: Mobile app expects exact format. Don't add extra parameters or change structure.

2. **Index is 0-Based**: First video = index 0, not index 1.

3. **Grid vs Feed**:
   - Grid = thumbnail grid, 2-segment URL
   - Feed = full-screen player, 3-segment URL

4. **URL Encoding**: Always URL-encode search terms but NOT hashtags or npubs.

5. **Case Sensitivity**: Hashtags and search terms are case-insensitive. Profile IDs and video IDs are case-sensitive (hex).

6. **Invalid Index**: If index > video count, show last video or return to grid.

7. **Missing Video**: If video ID doesn't exist, show error page with link to home.

8. **SEO**: Each URL should have unique title, description, and OG image for sharing.
