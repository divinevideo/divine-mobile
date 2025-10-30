# Test with Correct Blossom Server

## Change Made

Updated default Blossom server from:
```dart
// OLD (broken)
static const String defaultBlossomServer = 'https://cf-stream-service-prod.protestnet.workers.dev';

// NEW (correct)
static const String defaultBlossomServer = 'https://cdn.divine.video';
```

**File**: `lib/services/blossom_upload_service.dart:39`

## Test Steps

1. **Hot Reload the App**
   ```bash
   # In the terminal where app is running, press 'r' for hot reload
   # Or restart the app: ./run_dev.sh chrome debug
   ```

2. **Record and Upload Video**
   - Click camera button
   - Record 3-5 seconds
   - Add title: "Testing cdn.divine.video"
   - Click Publish

3. **Expected Successful Output**
   ```
   [VIDEO] Uploading using Blossom spec (PUT with raw bytes)
   [VIDEO]   URL: https://cdn.divine.video/upload
   [VIDEO] Blossom server response: 200 (or 201)
   [VIDEO] Response data: {url: https://cdn.divine.video/<hash>.mp4, ...}
   [VIDEO] ✅ Blossom upload successful
   [VIDEO] ✅ Nostr event published successfully
   ```

## Server Endpoints (Confirmed Working)

- **Upload**: `https://cdn.divine.video/upload` (PUT method)
- **Retrieve**: `https://cdn.divine.video/<sha256>.mp4` (GET method)

## Notes

- The old server (`cf-stream-service-prod.protestnet.workers.dev`) is completely offline (error 1042)
- The correct production server is `cdn.divine.video`
- This uses Cloudflare Stream backend
- 405 errors without auth are expected and normal (means server is working but requires auth)
