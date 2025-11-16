# diVine
    
<img src="https://devine.video/og.png" alt="diVine logo and screenshot"/>

### diVine is a decentralized, short-form video sharing mobile application built on the Nostr protocol, inspired by the simplicity and creativity of Vine.

**Try it:** https://divine.video/discovery 

_Feed navigation • Hashtag filtering • Video interactions • Social sharing • Real-time content discovery_

<br>

## Features

### Core Features
- **Decentralized**: Built on Nostr protocol for censorship resistance
- **Vine-Style Recording**: Short-form video content (6.3 seconds like original Vine)
- **Cross-Platform**: Flutter app for iOS, Android, and Web
- **Real-Time Social**: Follow, like, comment, repost, and share videos
- **Open Source**: Fully open source and transparent
- **Dark Mode Only**: Sleek dark aesthetic optimized for video viewing

### Video Features
- **Multi-Platform Camera**: Supports iOS, Android, macOS, and Web recording
- **Segmented Recording**: Press-and-hold recording with pause/resume capability
- **Auto-Upload**: Direct video upload to Cloudflare R2 with CDN serving
- **Thumbnail Generation**: Automatic video thumbnail creation
- **Progressive Loading**: Smart video preloading and caching

### Social Features
- **Activity Feed**: Real-time notifications for likes, follows, and interactions
- **Video Sharing**: Comprehensive sharing menu with external app support
- **Content Curation**: Create and manage curated video lists (NIP-51)
- **Content Reporting**: Apple-compliant content moderation and reporting
- **Direct Messaging**: Share videos privately with other users
- **Bug Reporting**: Encrypted diagnostic reports sent via NIP-17 private messages

### Technical Features
- **Nostr Integration**: Full NIP compliance (NIP-01, NIP-02, NIP-18, NIP-25, NIP-71)
- **Offline Support**: Queue uploads and sync when connection restored
- **Error Recovery**: Robust error handling with automatic retry mechanisms
- **Performance Optimized**: Efficient video management with memory limits

## Project Structure

```
nostrvine/
├── mobile/          # Flutter mobile application
├── backend/         # Cloudflare Workers backend
├── docs/           # Documentation and planning
└── README.md       # This file
```

## Quick Start

### Mobile App
```bash
cd mobile
flutter pub get
flutter run
```

### Backend
```bash
cd backend
npm install
wrangler dev
```

## Development

### Prerequisites

**Mobile App:**
- Flutter SDK (latest stable)
- Dart SDK
- iOS development: Xcode
- Android development: Android Studio

**Backend:**
- Node.js (latest LTS)
- Cloudflare account
- Wrangler CLI

### Available Commands

**Mobile:**
- `flutter run` - Run the app
- `flutter build` - Build for production
- `flutter test` - Run tests
- `flutter analyze` - Analyze code

**Backend:**
- `wrangler dev` - Local development
- `wrangler publish` - Deploy to Cloudflare
- `npm test` - Run tests

## Architecture

**Mobile App:**
- **Framework**: Flutter with Dart
- **Protocol**: Nostr for decentralized social networking
- **Platforms**: iOS, Android, macOS, and Web
- **Video Processing**: Multi-platform camera with segmented recording
- **State Management**: Provider pattern with reactive data flow
- **Storage**: Hive for local data persistence

**Backend:**
- **Runtime**: Cloudflare Workers (serverless)
- **Storage**: Cloudflare R2 for video hosting
- **CDN**: Global video delivery via Cloudflare
- **Processing**: Direct video upload with thumbnail generation
- **API**: RESTful endpoints with NIP-98 authentication

**Nostr Integration:**
- **Event Types**: Kind 22 (videos), Kind 6 (reposts), Kind 0 (profiles)
- **NIPs Supported**: NIP-01, NIP-02, NIP-18, NIP-25, NIP-71, NIP-94, NIP-98
- **Relays**: Multi-relay support for redundancy and performance

## API Endpoints

OpenVine uses two separate Cloudflare Workers with distinct domains for different purposes:

### Main Backend API (`api.openvine.co`)

**File Upload & Media:**
- `POST /api/upload` - NIP-96 compliant video upload
- `POST /api/import-url` - Import video from external URL
- `GET /api/status/{jobId}` - Check upload job status
- `GET /api/check-hash/{sha256}` - Check if file exists by hash
- `POST /api/set-vine-mapping` - Map original Vine URLs to fileIds
- `GET /media/{fileId}` - Serve media files

**Video Management:**
- `POST /v1/media/request-upload` - Cloudflare Stream upload request
- `POST /v1/webhooks/stream-complete` - Stream processing webhook
- `GET /v1/media/status/{videoId}` - Video processing status
- `GET /v1/media/list` - List uploaded media
- `GET /v1/media/metadata/{publicId}` - Get video metadata

**Video Cache & Lookup:**
- `GET /api/video/{videoId}` - Get video metadata from cache
- `POST /api/videos/batch` - Batch video metadata lookup
- `GET /api/media/lookup` - Media lookup by vine_id or filename

**Thumbnails:**
- `GET /thumbnail/{videoId}` - Get or generate video thumbnail
- `POST /thumbnail/{videoId}/upload` - Upload custom thumbnail
- `GET /thumbnail/{videoId}/list` - List available thumbnails

**NIP-05 Identity:**
- `GET /.well-known/nostr.json` - NIP-05 verification endpoint
- `POST /api/nip05/register` - Register NIP-05 username

**Feature Flags:**
- `GET /api/feature-flags` - List all feature flags
- `GET /api/feature-flags/{flagName}/check` - Check specific flag

**Content Moderation:**
- `POST /api/moderation/report` - Report content
- `GET /api/moderation/status/{videoId}` - Check moderation status
- `GET /api/moderation/queue` - Admin: View moderation queue
- `POST /api/moderation/action` - Admin: Take moderation action

**Legacy & Compatibility:**
- `GET /r/videos_h264high/{vineId}` - Vine URL compatibility
- `GET /r/videos/{vineId}` - Vine URL compatibility  
- `GET /v/{vineId}` - Vine URL compatibility
- `GET /t/{vineId}` - Vine URL compatibility

### Analytics API (`api.openvine.co/analytics`)

**View Tracking:**
- `POST /analytics/view` - Track video view events

**Trending Content:**
- `GET /analytics/trending/vines` - Get trending videos
- `GET /analytics/trending/viners` - Get trending creators
- `GET /analytics/trending/velocity` - Get rapidly ascending content

**Video Analytics:**
- `GET /analytics/video/{eventId}/stats` - Get video statistics

**Hashtag Analytics:**
- `GET /analytics/hashtag/{hashtag}/trending` - Get trending for hashtag
- `GET /analytics/hashtags/trending` - Get trending hashtags

**Health Check:**
- `GET /analytics/health` - Analytics service health status

### Domain Usage Summary

| Domain | Purpose | Examples |
|--------|---------|----------|
| `api.openvine.co` | File uploads, media serving, video management, user identity, analytics | Upload videos, serve thumbnails, NIP-05 verification, track video views, get trending content |

## Bug Reporting

OpenVine includes an encrypted bug reporting system that allows users to send diagnostic information directly to developers via NIP-17 private messages.

### How It Works

1. **User Initiates Report**: Navigate to Settings → Support → Report a Bug
2. **Describe the Issue**: Enter a description of the problem you're experiencing
3. **Automatic Diagnostics**: The app automatically collects:
   - Recent application logs (last 1000 entries)
   - Device information (OS version, device model, app version)
   - Error frequency counts (helps identify recurring issues)
   - Current screen name
   - User public key (for follow-up if needed)
4. **Privacy Protection**: All collected data is automatically sanitized to remove:
   - Private keys (nsec1... formats and hex private keys)
   - Passwords and authentication tokens
   - Authorization headers
   - Any other sensitive credentials
5. **Encrypted Transmission**: Report is sent via NIP-17 (gift-wrapped encrypted messages) to the developer's npub
6. **Confirmation**: User receives immediate feedback on successful submission

### Architecture

**Components:**
- **LogCaptureService**: Circular buffer that maintains the last 1000 log entries in memory
- **BugReportService**: Collects diagnostics, sanitizes sensitive data, and coordinates report sending
- **NIP17MessageService**: Implements three-layer NIP-17 encryption (kind 14 rumor → kind 13 seal → kind 1059 gift wrap)
- **BugReportDialog**: User interface for bug report submission

**Security:**
- Uses NIP-17 gift wrapping for maximum privacy
- Random ephemeral keys ensure sender anonymity
- Timestamp obfuscation (±2 days randomization)
- End-to-end encryption to recipient's public key
- Automatic sensitive data removal via regex patterns

**Testing:**
- Comprehensive widget tests (BugReportDialog: 8/8 passing)
- Unit tests for diagnostic collection (8/10 passing)
- Unit tests for NIP-17 encryption (8/8 passing)
- Unit tests for log capture (10/10 passing)

### Developer Information

Bug reports are sent to: `npub1wmr34t36fy03m8hvgl96zl3znndyzyaqhwmwdtshwmtkg03fetaqhjg240`

Reports include structured diagnostic data that helps with debugging and improving the app while respecting user privacy.

## Contributing

We welcome contributions! Please see our **[Contributing Guide](CONTRIBUTING.md)** for detailed instructions on:

- Setting up the development environment
- Building Divine (OpenVine) from source
- Setting up the Flutter Embedded Nostr Relay dependency
- Running tests and code quality checks
- Submitting pull requests

**Quick Start for Contributors:**
1. Read [CONTRIBUTING.md](CONTRIBUTING.md)
2. Set up the Flutter Embedded Nostr Relay symlink
3. Run `flutter pub get` in the `mobile/` directory
4. Start building with `flutter run -d macos`

## License

ISC License
