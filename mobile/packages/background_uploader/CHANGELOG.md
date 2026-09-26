# Changelog

## 0.0.1

- Initial scaffold: OS-backed background uploads.
- Dart API (`BackgroundUploader`, `BackgroundUploadRequest`,
  `BackgroundUploadEvent`) with method-channel + event plumbing.
- Darwin (iOS + macOS) background `URLSession` implementation.
- Android foreground-service implementation.
- Keep iOS background-session wakes alive until Dart publish follow-up work
  explicitly finishes, with a native watchdog to balance the completion handler.
- Create the Darwin background `URLSession` off the main thread when an engine
  attaches, so plugin registration no longer blocks app launch on it.
