import Flutter
import UIKit
import UserNotifications
import AVFoundation
import divine_camera
import LibProofMode
import ZendeskCoreSDK
import SupportSDK
import SupportProvidersSDK
import flutter_local_notifications

extension FlutterError: @retroactive Error {}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    // Divine's own video effects, for the editor preview and the export (#9708).
    EchoVideoEffect.register()
    TimeVideoEffects.register()
    FisheyeVideoEffect.register()
    DropsVideoEffect.register()
    LightLeakVideoEffect.register()
    LightRaysVideoEffect.register()
    AnamorphicVideoEffect.register()
    PrismVideoEffect.register()
    WindowLightVideoEffect.register()
    SpotlightVideoEffect.register()
    DiscoVideoEffect.register()
    LaserVideoEffect.register()
    LightningVideoEffect.register()
    ParticlesVideoEffect.register()
    TiltShiftVideoEffect.register()
    SwirlVideoEffect.register()
    RippleVideoEffect.register()
    FlutedGlassVideoEffect.register()
    TunnelVideoEffect.register()
    ZoomBlurVideoEffect.register()
    SpinBlurVideoEffect.register()
    ComicVideoEffect.register()
    EightBitVideoEffect.register()
    AnaglyphVideoEffect.register()
    RisoVideoEffect.register()
    PaintVideoEffect.register()
    PencilSketchVideoEffect.register()
    NeonEdgesVideoEffect.register()
    AsciiVideoEffect.register()
    StainedGlassVideoEffect.register()
    ThermalVideoEffect.register()
    NightVisionVideoEffect.register()
    XRayVideoEffect.register()
    PopArtVideoEffect.register()
    PaperCutVideoEffect.register()
    CrossStitchVideoEffect.register()
    BricksVideoEffect.register()
    IntroOutroVideoEffect.register()
    LookVideoEffect.register()
    AdjustVideoEffect.register()
    if #available(iOS 16.2, *) {
      // A Live Activity while the camera is open puts the Apple Watch remote
      // in the Watch's Smart Stack.
      let recorderLiveActivity = RecorderLiveActivityController()
      DivineCameraPlugin.onWatchRemoteChanged = { recorderState in
        recorderLiveActivity.show(recorderState: recorderState)
      }
    }
    #if DEBUG
    exportScreenshotLaunchConfig()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  #if DEBUG
  // Bridges the App Store screenshot pipeline's launch environment into
  // shared_preferences, which Dart reads reliably. Dart's Platform.environment
  // is empty on iOS and a custom method channel races engine init under the
  // UIScene implicit-engine model, so the launch env (XCUITest
  // launchEnvironment / simctl SIMCTL_CHILD_) is surfaced via UserDefaults
  // instead — the "flutter." prefix matches shared_preferences' key space.
  // DEBUG-only; absent from Release binaries.
  private func exportScreenshotLaunchConfig() {
    let env = ProcessInfo.processInfo.environment
    guard env["SCREENSHOT_INITIAL_ROUTE"] != nil || env["SCREENSHOT_SEED_CLIPS"] != nil else {
      return
    }
    let defaults = UserDefaults.standard
    defaults.set(
      env["SCREENSHOT_INITIAL_ROUTE"] ?? "",
      forKey: "flutter.screenshot_initial_route"
    )
    defaults.set(
      env["SCREENSHOT_SEED_CLIPS"] ?? "",
      forKey: "flutter.screenshot_seed_clips"
    )
  }
  #endif

  // UIScene lifecycle: Called when Flutter engine is ready
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Register plugins for any background notification action isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Register plugins with the engine
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Set up Nostr bridge frame attestation channel.
    // Must run after GeneratedPluginRegistrant so WebViewFlutterPlugin is
    // already registered — FWFWebViewFlutterWKWebViewExternalAPI requires it.
    NostrBridgeAttestationPlugin.setup(
      messenger: engineBridge.applicationRegistrar.messenger(),
      pluginRegistry: engineBridge.pluginRegistry
    )

    // Set up ProofMode platform channel
    setupProofModeChannel(with: engineBridge)

    // Set up Zendesk platform channel
    setupZendeskChannel(with: engineBridge)

    // Set up install-source channel (App Store / TestFlight / sideload).
    // Drives the in-app review prompt's store-install gate and the
    // AppUpdateRepository's download-URL resolution (#6296).
    setupInstallSourceChannel(with: engineBridge)

    // Set up app-icon badge channel.
    setupAppBadgeChannel(with: engineBridge)

    // Physical RAM, which sizes Flutter's decoded-image cache (#10301).
    setupDeviceMemoryChannel(with: engineBridge)

    // Disk capacity and free space, which size the media caches.
    setupDeviceStorageChannel(with: engineBridge)

    // Whether the Large Screen Layout feature is on, for the orientation mask.
    setupLargeScreenLayoutChannel(with: engineBridge)

    NSLog("✅ AppDelegate: Implicit Flutter engine initialized with UIScene lifecycle")
  }

  // Portrait for the entire app (including camera preview), except on a large
  // screen — an iPad, or the iPhone Duo's inner display — while the Large
  // Screen Layout feature is on, as it is by default. There every orientation is
  // allowed here and Dart narrows it through SystemChrome
  // (AdaptiveLayoutScope), asking for portrait while the camera is on top.
  // Asked again on every rotation and whenever the feature turns on or off,
  // so neither needs a restart. The Duo honors only this mask: it refuses
  // programmatic orientation changes, so there the camera keeps the window's
  // orientation (PortraitOrientationLock).
  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    guard largeScreenLayoutEnabled,
          let screen = window?.windowScene?.screen,
          min(screen.bounds.width, screen.bounds.height)
            >= Self.largeScreenMinShortestSide
    else {
      return .portrait
    }
    return .all
  }

  /// FeatureFlag.largeScreenLayout as the app resolves it: the user's choice,
  /// or else the build default. Dart reports it (AdaptiveLayoutScope); a
  /// persisted override alone would miss a build that turns it on by default.
  ///
  /// Starts at the build default, on (#11472), so an iPad held in landscape
  /// launches in landscape instead of turning once Dart reports. Only someone
  /// who turned the layouts off sees the app turn to portrait at launch.
  private var largeScreenLayoutEnabled = true

  /// AdaptiveBreakpoints.large: the shortest side, in points, from which a
  /// screen counts as large.
  private static let largeScreenMinShortestSide: CGFloat = 600

  private func setupLargeScreenLayoutChannel(
    with engineBridge: FlutterImplicitEngineBridge
  ) {
    let channel = FlutterMethodChannel(
      name: "divine/large_screen_layout",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setEnabled", let enabled = call.arguments as? Bool
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.largeScreenLayoutEnabled = enabled
      // Ask every window for the mask again, so the change applies now and
      // not only at the next rotation.
      for case let windowScene as UIWindowScene
        in UIApplication.shared.connectedScenes {
        for window in windowScene.windows {
          window.rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
      }
      result(nil)
    }
  }

  private func setupProofModeChannel(with engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: "org.openvine/proofmode",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "generateProof":
        guard let args = call.arguments as? [String: Any],
              let mediaPath = args["mediaPath"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Media path is required",
            details: nil
          ))
          return
        }

        NSLog("🔐 ProofMode: Generating proof for: \(mediaPath)")

        do {
          // Create MediaItem from file URL
          let fileURL = URL(fileURLWithPath: mediaPath)
          guard FileManager.default.fileExists(atPath: mediaPath) else {
            NSLog("🔐 ProofMode: FILE NOT FOUND: \(mediaPath)")
            result(FlutterError(
              code: "FILE_NOT_FOUND",
              message: "Media file does not exist: \(mediaPath)",
              details: nil
            ))
            return
          }

          let mediaItem = MediaItem(mediaUrl: fileURL)

          // Configure proof generation options.
          // All three signals are deliberately off: Divine proves the media
          // hash only, and collects no device ID, location, or carrier data.
          // Keep them false unless the privacy manifest and the App Store
          // privacy label are updated to match (#8803).
          let options = ProofGenerationOptions(
            showDeviceIds: false,
            showLocation: false,
            showMobileNetwork: false,
            notarizationProviders: []
          )

		Proof.shared.process(mediaItem: mediaItem, options: options, whenDone: { mediaItem in
                    if let proofHash = mediaItem.mediaItemHash {
          		NSLog("🔐 ProofMode: Proof generated successfully: \(proofHash)")
          		result(proofHash)
                    } else {
            		NSLog("❌ ProofMode: Proof generation did not produce hash")
            		result(FlutterError(
              		code: "PROOF_HASH_MISSING",
              		message: "LibProofMode did not generate video hash",
              		details: nil
            		))
            		return
                    }
                })



        } catch {
          NSLog("❌ ProofMode: Proof generation failed: \(error.localizedDescription)")
          result(FlutterError(
            code: "PROOF_GENERATION_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }

      case "getProofDir":
        guard let args = call.arguments as? [String: Any],
              let proofHash = args["proofHash"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Proof hash is required",
            details: nil
          ))
          return
        }

        NSLog("🔐 ProofMode: Getting proof directory for hash: \(proofHash)")

        // ProofMode stores proof in documents directory under hash subfolder
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let proofDirPath = (documentsPath as NSString).appendingPathComponent(proofHash)

        if FileManager.default.fileExists(atPath: proofDirPath) {
          NSLog("🔐 ProofMode: Proof directory found: \(proofDirPath)")
          result(proofDirPath)
        } else {
          NSLog("⚠️ ProofMode: Proof directory not found for hash: \(proofHash)")
          result(nil)
        }

      case "isAvailable":
        // iOS ProofMode library is now available
        NSLog("🔐 ProofMode: isAvailable check - true (LibProofMode installed)")
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ ProofMode: Platform channel registered with LibProofMode")
  }

  /// Install-source platform channel.
  ///
  /// iOS distinguishes install source by the app store receipt URL: TestFlight
  /// builds ship a `sandboxReceipt`, App Store builds ship a `receipt`. The
  /// Dart side maps `isSandbox` → testFlight/appStore via the shared
  /// `resolveIosInstallSource` resolver in app_update_repository.
  private func setupInstallSourceChannel(with engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: "divine/install_source",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "isSandboxReceipt":
        // The receipt URL is nil in simulator/debug runs without a store
        // receipt. Return nil so Dart fails closed to sideload instead of
        // pretending an unknown receipt environment is the App Store.
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
          NSLog("📦 InstallSource: no receipt URL — returning unknown")
          result(nil)
          return
        }
        let isSandbox = receiptURL.lastPathComponent == "sandboxReceipt"
        NSLog("📦 InstallSource: isSandbox=\(isSandbox) (\(receiptURL.lastPathComponent))")
        result(isSandbox)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ InstallSource: Platform channel registered")
  }

  /// App-icon badge platform channel.
  ///
  /// The Dart side invokes this best-effort on launch, resume, and when the
  /// unfiltered notifications surface advances the seen watermark. Divine does
  /// not currently own a persistent app-icon badge count, so the only native
  /// operation exposed here is clearing it.
  private func setupAppBadgeChannel(with engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: "divine/app_badge",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "clear":
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(
                code: "BADGE_CLEAR_FAILED",
                message: error.localizedDescription,
                details: nil
              ))
              return
            }
            result(nil)
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ AppBadge: Platform channel registered")
  }

  /// Device-memory platform channel.
  ///
  /// The Dart side reads the physical RAM once at startup to size Flutter's
  /// decoded-image cache.
  private func setupDeviceMemoryChannel(with engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: "divine/device_memory",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getPhysicalMemoryBytes":
        result(Int(clamping: ProcessInfo.processInfo.physicalMemory))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Device-storage platform channel.
  ///
  /// The Dart side reads the disk's capacity and free space to shrink the
  /// media caches as the disk fills. Free space is the "important usage"
  /// figure, which counts space iOS would purge on demand.
  private func setupDeviceStorageChannel(with engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: "divine/device_storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getStorageSpace":
        result(AppDelegate.deviceStorageSpace())

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Capacity and free space of the volume holding the app's home directory,
  /// or nil when the OS does not report them.
  static func deviceStorageSpace() -> [String: Int]? {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    guard
      let values = try? home.resourceValues(forKeys: [
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey,
      ]),
      let total = values.volumeTotalCapacity,
      let free = values.volumeAvailableCapacityForImportantUsage
    else {
      return nil
    }
    return ["totalBytes": total, "freeBytes": Int(clamping: free)]
  }

  private func setupZendeskChannel(with engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: "com.openvine/zendesk_support",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { (call, result) in
      // Get the root view controller for presenting UI
      guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let controller = windowScene.windows.first?.rootViewController else {
        result(FlutterError(code: "NO_CONTROLLER", message: "FlutterViewController not available", details: nil))
        return
      }

      switch call.method {
      case "initialize":
        guard let args = call.arguments as? [String: Any],
              let appId = args["appId"] as? String,
              let clientId = args["clientId"] as? String,
              let zendeskUrl = args["zendeskUrl"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "appId, clientId, and zendeskUrl are required",
            details: nil
          ))
          return
        }

        NSLog("🎫 Zendesk: Initializing with URL: \(zendeskUrl)")

        // Initialize Zendesk Core SDK
        Zendesk.initialize(appId: appId, clientId: clientId, zendeskUrl: zendeskUrl)

        // Initialize Support SDK
        Support.initialize(withZendesk: Zendesk.instance)

        // No identity set at init — JWT identity will be set when the user
        // accesses support. Setting anonymous here would lock the SDK into
        // anonymous auth mode and prevent switching to JWT later.

        NSLog("✅ Zendesk: Initialized (identity deferred to JWT)")
        result(true)

      case "showNewTicket":
        let args = call.arguments as? [String: Any]
        let subject = args?["subject"] as? String ?? ""
        let tags = args?["tags"] as? [String] ?? []
        // Note: description parameter not supported by Zendesk iOS SDK RequestUiConfiguration

        NSLog("🎫 Zendesk: Showing new ticket screen")

        // Configure request UI
        let config = RequestUiConfiguration()
        config.subject = subject
        config.tags = tags

        // Build request screen
        let requestScreen = RequestUi.buildRequestUi(with: [config])

        // Present modally
        controller.present(requestScreen, animated: true) {
          NSLog("✅ Zendesk: Ticket screen presented")
        }

        result(true)

      case "showTicketList":
        NSLog("🎫 Zendesk: Showing ticket list screen")

        // Build request list screen
        let requestListScreen = RequestUi.buildRequestList()

        // CRITICAL: Zendesk RequestUi requires UINavigationController for ticket navigation
        // Without this, tapping tickets won't open the conversation view
        let navigationController = UINavigationController(rootViewController: requestListScreen)

        // Present modally with navigation controller
        controller.present(navigationController, animated: true) {
          NSLog("✅ Zendesk: Ticket list presented in navigation controller")
        }

        result(true)

      case "setUserIdentity":
        guard let args = call.arguments as? [String: Any],
              let name = args["name"] as? String,
              let email = args["email"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "name and email are required",
            details: nil
          ))
          return
        }

        NSLog("🎫 Zendesk: Setting user identity")

        // Create anonymous identity with name and email identifiers
        let identity = Identity.createAnonymous(name: name, email: email)
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: User identity set successfully")
        result(true)

      case "clearUserIdentity":
        NSLog("🎫 Zendesk: Clearing user identity")

        // Reset to plain anonymous identity
        let identity = Identity.createAnonymous()
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: User identity cleared")
        result(true)

      case "setJwtIdentity":
        guard let args = call.arguments as? [String: Any],
              let userToken = args["userToken"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "userToken is required",
            details: nil
          ))
          return
        }

        NSLog("🎫 Zendesk: Setting JWT identity with user token")

        // Pass user token (npub) to SDK - Zendesk will call our JWT endpoint to get the actual JWT
        let identity = Identity.createJwt(token: userToken)
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: JWT identity set - Zendesk will callback to get JWT")
        result(true)

      case "setAnonymousIdentity":
        NSLog("🎫 Zendesk: Setting anonymous identity")

        // Set plain anonymous identity (for non-logged-in users)
        let identity = Identity.createAnonymous()
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: Anonymous identity set")
        result(true)

      case "createTicket":
        NSLog("🎫 Zendesk: Creating ticket programmatically (no UI)")

        // Extract parameters
        guard let args = call.arguments as? [String: Any],
              let subject = args["subject"] as? String,
              let description = args["description"] as? String else {
          NSLog("❌ Zendesk: Missing required parameters for createTicket")
          result(FlutterError(code: "INVALID_ARGS",
                            message: "Missing subject or description",
                            details: nil))
          return
        }

        guard let zendesk = Zendesk.instance else {
          result(FlutterError(code: "SDK_NOT_INITIALIZED",
                            message: "Zendesk SDK not initialized",
                            details: nil))
          return
        }
        // Without an identity the SDK fails the ticket before sending it, as
        // Android's does. Dart can set one and retry.
        guard zendesk.identity != nil else {
          result(FlutterError(code: "NO_IDENTITY",
                            message: "Set an identity before creating a ticket",
                            details: nil))
          return
        }

        let tags = args["tags"] as? [String] ?? []
        let ticketFormId = args["ticketFormId"] as? NSNumber
        let customFieldsData = args["customFields"] as? [[String: Any]] ?? []
        let attachmentPaths = args["attachmentPaths"] as? [String] ?? []

        // Build create request object using ZDK API
        let createRequest = ZDKCreateRequest()
        createRequest.subject = subject
        createRequest.requestDescription = description
        createRequest.tags = tags

        // Set ticket form ID if provided
        if let formId = ticketFormId {
          createRequest.ticketFormId = formId
          NSLog("🎫 Zendesk: Using ticket form ID: \(formId)")
        }

        // Set custom fields if provided
        if !customFieldsData.isEmpty {
          var customFields: [CustomField] = []
          for fieldData in customFieldsData {
            if let fieldId = fieldData["id"] as? NSNumber,
               let fieldValue = fieldData["value"] {
              let customField = CustomField(dictionary: ["id": fieldId, "value": fieldValue])
              customFields.append(customField)
              NSLog("🎫 Zendesk: Custom field \(fieldId) = \(fieldValue)")
            }
          }
          createRequest.customFields = customFields
        }

        NSLog("🎫 Zendesk: Submitting ticket - subject: '\(subject)', tags: \(tags), attachments: \(attachmentPaths.count)")

        let submitRequest = {
          ZDKRequestProvider().createRequest(createRequest) { (request, error) in
            DispatchQueue.main.async {
              if let error = error {
                let nsError = error as NSError
                NSLog("❌ Zendesk: Failed to create ticket - \(nsError.domain) \(nsError.code): \(nsError.localizedDescription)")
                result(FlutterError(
                  code: "CREATE_FAILED",
                  message: nsError.localizedDescription,
                  details: zendeskCreateTicketErrorDetails(
                    error,
                    identity: Zendesk.instance?.identity.map(zendeskIdentityName)
                  )
                ))
              } else if let request = request as? ZDKRequest {
                NSLog("✅ Zendesk: Ticket created successfully - ID: \(request.requestId)")
                result(true)
              } else {
                NSLog("✅ Zendesk: Ticket created (no error, response type: \(type(of: request)))")
                result(true)
              }
            }
          }
        }

        if attachmentPaths.isEmpty {
          submitRequest()
        } else {
          self.uploadAttachments(attachmentPaths) { uploadResult in
            switch uploadResult {
            case .success(let uploadResponses):
              DispatchQueue.main.async {
                createRequest.attachments = uploadResponses
                NSLog("🎫 Zendesk: All \(uploadResponses.count) attachments uploaded, creating ticket")
                submitRequest()
              }
            case .failure(let error):
              DispatchQueue.main.async {
                result(error)
              }
            }
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ Zendesk: Platform channel registered")
  }

  private func uploadAttachments(
    _ paths: [String],
    completion: @escaping (Result<[ZDKUploadResponse], FlutterError>) -> Void
  ) {
    var responses: [ZDKUploadResponse] = []
    let uploadProvider = ZDKUploadProvider()

    func uploadNext(index: Int) {
      guard index < paths.count else {
        completion(.success(responses))
        return
      }

      let path = paths[index]
      guard let data = FileManager.default.contents(atPath: path) else {
        completion(.failure(FlutterError(
          code: "UPLOAD_FAILED",
          message: "Could not read the selected image",
          details: nil
        )))
        return
      }

      let filename = (path as NSString).lastPathComponent
      let contentType = attachmentContentType(for: filename)

      uploadProvider.uploadAttachment(data, withFilename: filename, andContentType: contentType) {
        uploadResponse, error in
        if let error = error {
          NSLog("❌ Zendesk: Upload failed for \(filename) - \(error.localizedDescription)")
          completion(.failure(FlutterError(
            code: "UPLOAD_FAILED",
            message: "Failed to upload selected image",
            details: nil
          )))
          return
        }

        guard let response = uploadResponse else {
          completion(.failure(FlutterError(
            code: "UPLOAD_FAILED",
            message: "Attachment upload did not return a token",
            details: nil
          )))
          return
        }

        // Do not log uploadToken: short-lived Zendesk secure-download credential.
        NSLog("✅ Zendesk: Uploaded \(filename) successfully")
        responses.append(response)
        uploadNext(index: index + 1)
      }
    }

    uploadNext(index: 0)
  }

  private func attachmentContentType(for filename: String) -> String {
    switch (filename as NSString).pathExtension.lowercased() {
    case "png":
      return "image/png"
    case "jpg", "jpeg":
      return "image/jpeg"
    case "heic":
      return "image/heic"
    case "heif":
      return "image/heif"
    case "webp":
      return "image/webp"
    case "gif":
      return "image/gif"
    default:
      return "image/jpeg"
    }
  }
}

/// The errors the Zendesk iOS SDK (ZendeskCoreSDK 5.0, SupportProvidersSDK 9.0)
/// fails a ticket with. None of them is public API: they were read from the SDK
/// binaries, and the identity check's were also raised against a stub server.
enum ZendeskSdkErrorDomain {
  /// The ticket API answered with an HTTP error. The code is the HTTP status.
  static let http = "com.zendesk.sdk"
  /// Exchanging the identity for an access token failed (code 1000). The
  /// exchange's HTTP status is in the user info under `HTTP Status code`.
  static let tokenExchange = "com.zendesk.sdk.core"
  /// The SDK held no identity when it tried to authenticate.
  static let access = "com.zendesk.core.access"
  /// The identity check that runs before the token exchange failed:
  /// `identityMismatchCode`, 808 when the SDK has no settings that say which
  /// type the app expects (also when the settings request fails offline), or
  /// 809 when a request that needs no access token asked for one.
  static let identityCheck = "com.zendesk.core.identity"
  /// The identity's type differs from the one the SDK app is set up for.
  static let identityMismatchCode = 303
}

/// The name Dart uses for the type of `identity`, as in `expectedAuth`.
func zendeskIdentityName(_ identity: Identity) -> String {
  switch identity.type {
  case .jwt: return "jwt"
  case .anonymous: return "anonymous"
  @unknown default: return "unknown"
  }
}

/// The `details` of the `CREATE_FAILED` error that `createTicket` raises when
/// the Zendesk SDK fails to create a ticket, with the keys Android's
/// `zendeskCreateTicketErrorDetails` uses.
///
/// `status` is the HTTP status, or -1 when none arrived; `networkError` marks
/// an I/O failure; `authFailed` marks a failure to authenticate `identity`,
/// which Dart retries with another identity; `expectedAuth`, `jwt` or
/// `anonymous`, names the identity type the SDK app is set up for, so Dart
/// never retries with a type the app refuses. `identity` is the type the SDK
/// held, and `errorDomain` and `errorCode` identify the error, because iOS
/// gives no reason as specific as Android's.
func zendeskCreateTicketErrorDetails(_ error: Error, identity: String?) -> [String: Any] {
  let nsError = error as NSError
  let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
  let networkError =
    nsError.domain == NSURLErrorDomain || underlying?.domain == NSURLErrorDomain

  let status: Int
  switch nsError.domain {
  case ZendeskSdkErrorDomain.http:
    status = nsError.code
  case ZendeskSdkErrorDomain.tokenExchange:
    status = zendeskStatusCode(nsError.userInfo["HTTP Status code"]) ?? -1
  default:
    status = -1
  }

  let identityMismatch =
    nsError.domain == ZendeskSdkErrorDomain.identityCheck
    && nsError.code == ZendeskSdkErrorDomain.identityMismatchCode
  let authFailed = !networkError && (
    identityMismatch
      || nsError.domain == ZendeskSdkErrorDomain.tokenExchange
      || nsError.domain == ZendeskSdkErrorDomain.access
      || (nsError.domain == ZendeskSdkErrorDomain.http && status == 401)
  )

  var details: [String: Any] = [
    "status": status,
    "networkError": networkError,
    "authFailed": authFailed,
    "errorDomain": nsError.domain,
    "errorCode": nsError.code,
  ]
  if let identity { details["identity"] = identity }
  if authFailed {
    // The identity check runs before authentication, so an identity that got
    // as far as authenticating has the type the app expects. One refused by
    // the check has the other type.
    let expectedAuth: String?
    switch (identityMismatch, identity) {
    case (true, "jwt"): expectedAuth = "anonymous"
    case (true, "anonymous"): expectedAuth = "jwt"
    case (true, _): expectedAuth = nil
    case (false, let held): expectedAuth = held
    }
    if let expectedAuth { details["expectedAuth"] = expectedAuth }
  }
  return details
}

private func zendeskStatusCode(_ value: Any?) -> Int? {
  guard let value else { return nil }
  switch value {
  case let number as NSNumber: return number.intValue
  case let text as String: return Int(text)
  default: return nil
  }
}
