# Deep Link Testing Guide

This guide helps you test deep linking functionality on iOS and Android devices.

## Prerequisites

- Physical iOS device (iOS universal links don't work on simulator)
- OR Android device/emulator (Android app links work on both)
- App installed on device
- Server verification files deployed at `https://divine.video/.well-known/`

## Quick Test URLs

Use these test URLs for verification:

### Video Links
```
https://divine.video/video/abc123
https://divine.video/video/{actual-video-event-id}
```

### Profile Links
```
https://divine.video/profile/npub1abc...xyz
https://divine.video/profile/{actual-npub}
```

### Hashtag Links
```
https://divine.video/hashtag/nostr
https://divine.video/hashtag/bitcoin
https://divine.video/hashtag/{any-hashtag}
```

### Search Links
```
https://divine.video/search/bitcoin
https://divine.video/search/{search-term}
```

## Testing Methods

### Method 1: Send Link via Message (iOS/Android)

1. **Send yourself a message** with the deep link:
   - iMessage (iOS)
   - SMS
   - Email
   - Slack/Discord

2. **Tap the link**

3. **Expected behavior**:
   - App opens automatically
   - Navigates directly to the video/profile
   - No disambiguation dialog (should NOT ask "open in browser or app")

### Method 2: Open in Safari/Chrome (iOS/Android)

1. **Open Safari (iOS) or Chrome (Android)**

2. **Type/paste the URL**: `https://divine.video/video/test123`

3. **Tap the link or press Enter**

4. **Expected behavior**:
   - iOS: Shows banner at top "Open in divine" → tap to open
   - Android: App opens automatically (if verified correctly)

### Method 3: Using ADB (Android Only)

```bash
# Test video link
adb shell am start -a android.intent.action.VIEW -d "https://divine.video/video/test123"

# Test profile link
adb shell am start -a android.intent.action.VIEW -d "https://divine.video/profile/npub1test"

# Verify app link status
adb shell pm get-app-links co.openvine.app

# Re-verify if needed
adb shell pm verify-app-links --re-verify co.openvine.app
```

## What to Look For

### ✅ Success Indicators

1. **App opens automatically** (no "open with" dialog)
2. **Correct navigation**:
   - Video links → `VideoDetailScreen` showing the specific video
   - Profile links → `ProfileScreen` showing the user's profile
3. **Console logs** (look for these emoji):
   - `🔗 Setting up deep link listener...`
   - `🔗 Deep link service initialized`
   - `📱 App opened with deep link: https://divine.video/...`
   - `🔗 Processing deep link: DeepLink(type: video, videoId: ...)`
   - `📱 Navigating to video: /video/{id}`
   - `✅ Navigation completed to: /video/{id}`
   - `📱 Loading video by ID: {id}`

### ❌ Failure Indicators

1. **Browser stays open** instead of app opening
   - Means server verification file not accessible/correct
   - Check: `curl -I https://divine.video/.well-known/apple-app-site-association`
   - Check: `curl -I https://divine.video/.well-known/assetlinks.json`

2. **"Open with" dialog appears**
   - iOS: Means associated domains not configured correctly
   - Android: Means autoVerify failed - check `adb shell pm get-app-links`

3. **App opens to home feed** instead of video/profile
   - Deep link received but navigation failed
   - Check console logs for `🔗` and `📱` messages
   - Look for errors in `DeepLinkHandler` logs

4. **Error screen** shown in app
   - Video not found
   - Invalid video ID
   - Network/relay connection issue

## Debugging with Console Logs

### iOS (Xcode Console)

1. Connect device via USB
2. Open Xcode → Window → Devices and Simulators
3. Select your device → View Device Logs
4. Tap the deep link
5. Search for "DeepLink" or look for 🔗 emoji

### Android (ADB Logcat)

```bash
# Filter for deep link logs
adb logcat | grep -i "deeplink\|applinks"

# Full app logs
adb logcat | grep "co.openvine.app"

# Check verification status
adb logcat | grep -i "assetlinks"
```

## Common Issues & Fixes

### Issue: iOS links open in Safari instead of app

**Cause**: User previously chose "Open in Safari" for a divine.video link

**Fix**:
1. Long-press the link
2. Select "Open in divine" from the context menu
3. iOS will remember this choice

### Issue: Android shows "Open with" dialog

**Cause**: App links not verified

**Fix**:
```bash
# Check status
adb shell pm get-app-links co.openvine.app

# Should show:
# co.openvine.app:
#   divine.video: verified

# If not verified, re-verify
adb shell pm verify-app-links --re-verify co.openvine.app
```

### Issue: App opens but doesn't navigate

**Cause**: Timing race condition (should be fixed now)

**Check logs for**:
- Is `🔗 Deep link listener setup complete` logged?
- Is `📱 App opened with deep link` logged?
- Is `🔗 Processing deep link` logged?
- Any errors in navigation?

### Issue: Video not found error

**Cause**: Video ID doesn't exist in Nostr relays

**Fix**: Use a real video ID from an actual video:
1. Open app
2. View any video
3. Check logs for the event ID (64-char hex string)
4. Use that ID in test URL

## Testing Checklist

Before marking deep linking as complete:

- [ ] iOS universal links work (physical device)
  - [ ] Video link opens app and shows video
  - [ ] Profile link opens app and shows profile
  - [ ] Links from Messages work
  - [ ] Links from Safari work

- [ ] Android app links work
  - [ ] Video link opens app and shows video
  - [ ] Profile link opens app and shows profile
  - [ ] Links from Chrome work
  - [ ] ADB test commands work
  - [ ] `pm get-app-links` shows "verified"

- [ ] Server verification
  - [ ] Apple file returns HTTP 200
  - [ ] Android file returns HTTP 200
  - [ ] Apple validator passes

- [ ] Console logging
  - [ ] See `🔗` initialization logs
  - [ ] See `📱` navigation logs
  - [ ] No errors in deep link handling

## Notes

- **macOS/Desktop**: Deep links will NOT work in Chrome/Safari on desktop - this is expected behavior. Universal links are mobile-only.

- **Timing**: After deploying server files, iOS may cache for 24 hours. Reinstalling the app forces a refresh.

- **Production**: Before production release, update `assetlinks.json` with release keystore SHA-256 fingerprint.

## Getting a Real Video ID for Testing

```bash
# On device with app running
adb logcat | grep "VideoEvent"

# Look for output like:
# VideoEvent(id: a1b2c3d4e5f6..., title: "Test Video")

# Use that ID in test URL:
# https://divine.video/video/a1b2c3d4e5f6...
```

## Support

If deep linking isn't working after following this guide:

1. Check all console logs for errors
2. Verify server files are accessible
3. Confirm app is using the correct bundle ID / package name
4. Try reinstalling the app (clears cached verification results)
