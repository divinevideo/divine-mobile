# Zendesk Support Integration

Status: Current
Validated against: `mobile/lib/services/zendesk_support_service.dart` and `mobile/lib/screens/settings/support_center_screen.dart` on 2026-03-19.

Divine integrates Zendesk Support to provide native support-message flows when credentials are configured. The app keeps working without Zendesk by falling back to in-app bug reporting and exportable logs.

## User Entry Point

Users reach support from:

- `Settings -> Support Center`

Current Support Center actions:

- contact support / report a bug
- save logs
- view support messages
- open FAQ
- open ProofMode information
- open Privacy Policy
- open Safety Standards

## Integration Shape

```
Support Center
  -> BugReportService for local bug report flows and log export
  -> ZendeskSupportService for native ticket UI and ticket history
  -> external policy/support URLs on divine.video
```

## Platform Channel Architecture

The Zendesk native SDKs are accessed through a Flutter `MethodChannel`. The service layer abstracts platform details so the rest of the app never touches native code directly.

```
Settings (UI)
  -> ZendeskSupportService (Dart)
       -> MethodChannel('com.divine.zendesk')
            -> iOS: ZendeskPlugin (Swift, uses ZendeskSDK pod)
            -> Android: ZendeskPlugin (Kotlin, uses Zendesk Support SDK)
```

All calls through the channel are fire-and-forget or return simple status maps. The native side handles SDK lifecycle, view presentation, and push-token registration.

## Platform Auth Paths

| Platform | Auth method | Configured in Codemagic |
|----------|-------------|------------------------|
| iOS / Android | Zendesk native SDK via OAuth (`APP_ID` + `CLIENT_ID`) | Yes |
| macOS (internal only) | REST API via basic auth (`API_TOKEN` + `API_EMAIL`) | No |

JWT pre-auth tokens (minted via relay-manager) enrich user identity on the native SDK but are not the primary auth mechanism -- OAuth handles that.

## Current Service Behavior

`ZendeskSupportService`:

- initializes from dart defines at app startup
- stores user identity details locally
- can set anonymous identity for unauthenticated users
- upgrades to JWT identity by fetching a pre-auth token through the relay-manager API
- opens the native ticket composer and ticket list when the SDK is available

If Zendesk is unavailable:

- the Support Center still supports bug reporting and log export
- ticket history is unavailable

### Identity Upgrade Flow

When the user signs in, the service first registers an **anonymous identity** with the Zendesk SDK, which needs no network call. Divine's SDK app authenticates with JWT (#1294), so the SDK refuses that identity when it creates a ticket.

Once the user authenticates (login or registration), the service upgrades to a **JWT pre-auth identity**:

1. The service calls the relay-manager API to fetch a Zendesk JWT token scoped to the authenticated user.
2. On success, it replaces the anonymous identity with the JWT identity via the platform channel. Existing tickets become associated with the authenticated user.
3. **Fallback**: If the JWT token fetch fails (network error, server error, expired session), the service logs the failure and the anonymous identity stays set. `createTicket` refreshes the JWT before each attempt, and once the bridge reports that the app expects JWT it does not retry with the anonymous identity. The upgrade is reattempted on the next app foreground or manual support-center open.

## Configuration

### Dart Define Configuration

The Zendesk SDK uses dart defines injected at build time:

| Define | Purpose |
|--------|---------|
| `ZENDESK_APP_ID` | Identifies the Zendesk mobile SDK application |
| `ZENDESK_CLIENT_ID` | OAuth client ID for SDK authentication |
| `ZENDESK_URL` | Base URL of the Zendesk instance (e.g. `https://divine.zendesk.com`) |
| `ZENDESK_API_TOKEN` | REST API basic auth for desktop platforms (macOS internal builds only). Not configured in Codemagic. |

**Local development**: Values are loaded automatically from the `.env` file in `mobile/`. The `.env` file is gitignored and must be created manually from `.env.example` or obtained from the team.

**CI / production builds (iOS/Android)**: The three SDK defines are passed via `--dart-define` in `codemagic.yaml`. `ZENDESK_API_TOKEN` is not included -- it's only needed for the REST API fallback on desktop (macOS), which is internal-only.

If `ZENDESK_APP_ID` or `ZENDESK_CLIENT_ID` is missing or empty, `ZendeskSupportService` skips initialization and the app falls back to local bug reporting and log export.

## Current Files

- `mobile/lib/services/zendesk_support_service.dart`
- `mobile/lib/screens/settings/support_center_screen.dart`
- `mobile/lib/config/zendesk_config.dart`
- native platform handlers in the iOS and Android app targets

## Troubleshooting

### iOS build fails with Zendesk pod errors

The Zendesk iOS SDK is installed via CocoaPods. If `pod install` fails or Xcode reports missing modules:

```bash
cd mobile/ios
rm -rf Pods Podfile.lock .symlinks
cd ..
flutter clean && flutter pub get
cd ios && pod install
```

If the error persists, also clear Xcode derived data:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Zendesk not initializing

Check the debug console for log lines from `ZendeskSupportService`. Common causes:

- One or more dart defines are missing or empty. Verify `.env` contains the required keys (`ZENDESK_APP_ID`, `ZENDESK_CLIENT_ID`, `ZENDESK_URL`).
- The native plugin failed to register. Confirm `ZendeskPlugin` is listed in the iOS `AppDelegate` / Android `MainActivity` plugin registry.
- Network is unreachable at init time. The service logs the failure and retries on next access.

### Support button shows email dialog instead of Zendesk UI

This means the SDK credentials are not configured or initialization was skipped. The app intentionally falls back to a `mailto:` link when Zendesk is unavailable. To fix:

1. Confirm the required dart defines are set (see Configuration above).
2. Restart the app (hot-reload does not re-run SDK initialization).
3. Check logs for initialization errors.

## Notes For Launch

- Make sure Support Center copy and screenshots match the current UI, not the older drawer-based flows.
- Re-validate support contacts and external policy links before store submission.
