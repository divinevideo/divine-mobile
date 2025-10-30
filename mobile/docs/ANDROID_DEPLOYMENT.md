# Android Deployment Guide

## Quick Start

### 1. One-Time Setup (First Deploy Only)

**Create Google Play Service Account**:

1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to **Setup** → **API access**
3. Click **Create new service account** or use existing
4. Click the Google Cloud Console link that appears
5. Create service account with name "OpenVine Deploy"
6. Click **Create and Continue**
7. Grant role: **Service Account User**
8. Click **Done**
9. Click on the service account email
10. Go to **Keys** tab → **Add Key** → **Create new key**
11. Choose **JSON** format
12. Download the JSON key file
13. Save it as: `android/play-store-service-account.json`

**Grant Permissions in Play Console**:

1. Back in Play Console → API access
2. Find your service account in the list
3. Click **Grant access**
4. Under **App permissions**, select your app
5. Grant **Release manager** role
6. Click **Invite user**

### 2. Deploy Commands

**Deploy to Internal Testing** (no review, instant, 100 testers):
```bash
./deploy_android.sh internal
```

**Deploy to Closed Testing** (alpha/beta, requires review):
```bash
./deploy_android.sh closed
```

**Deploy to Production** (full review):
```bash
./deploy_android.sh production
```

### 3. Options

**Skip build** (use existing AAB):
```bash
./deploy_android.sh internal --skip-build
```

**Build only** (don't upload):
```bash
./deploy_android.sh internal --skip-upload
```

**With version and notes**:
```bash
./deploy_android.sh internal \
  --version "v0.1.0" \
  --notes "Bug fixes and performance improvements"
```

## What the Script Does

1. ✅ Checks for fastlane setup (creates if needed)
2. ✅ Verifies Google Play API credentials
3. ✅ Runs `flutter clean` and `flutter pub get`
4. ✅ Builds release app bundle (AAB)
5. ✅ Uploads to specified Play Store track
6. ✅ Shows next steps

## Manual Upload (if script fails)

If the automated script doesn't work, you can still upload manually:

1. Build AAB:
   ```bash
   flutter build appbundle --release
   ```

2. Upload via Play Console:
   - Go to Testing → Internal testing
   - Click "Create new release"
   - Upload `build/app/outputs/bundle/release/app-release.aab`
   - Add release notes
   - Review and start rollout

## Troubleshooting

**Error: Service account JSON not found**
- Make sure you saved the JSON key as `android/play-store-service-account.json`

**Error: Permission denied**
- Verify the service account has "Release manager" role in Play Console

**Error: Build failed**
- Run `flutter doctor` to check for issues
- Make sure keystore and key.properties are configured

**Error: Upload failed**
- Check that your app is already created in Play Console
- Verify the package name matches

## Track Differences

| Track | Review Time | Testers | Rollout Speed |
|-------|-------------|---------|---------------|
| **Internal** | None | 100 max | Instant |
| **Closed** | 1-2 days | Unlimited | Within hours after approval |
| **Production** | 3-7 days | Public | Gradual rollout |

## Files

- `deploy_android.sh` - Main deployment script
- `android/fastlane/Fastfile` - Fastlane configuration (auto-generated)
- `android/play-store-service-account.json` - API credentials (gitignored)
- `build/app/outputs/bundle/release/app-release.aab` - Built app bundle

## Security Notes

- The service account JSON file contains sensitive credentials
- It's already in `.gitignore` - **never commit it**
- Store it securely (e.g., 1Password, encrypted storage)
- Rotate keys periodically for security
