// ABOUTME: XCTests for DivineCameraPlugin method channel dispatch
// ABOUTME: Verifies routing, error handling, and results without camera hardware

import XCTest
import FlutterMacOS
import divine_camera

// MARK: - Test Helpers

/// Captures the FlutterResult value for assertion.
class ResultCapture {
    var value: Any?
    var called = false

    var flutterResult: FlutterResult {
        return { [weak self] result in
            self?.value = result
            self?.called = true
        }
    }

    var flutterError: FlutterError? {
        return value as? FlutterError
    }

    var isNotImplemented: Bool {
        return value is FlutterMethodNotImplemented.Type
            || (value as AnyObject) === FlutterMethodNotImplemented
    }
}

// MARK: - Tests

final class DivineCameraPluginTests: XCTestCase {

    private var plugin: DivineCameraPlugin!

    override func setUp() {
        super.setUp()
        plugin = DivineCameraPlugin()
    }

    override func tearDown() {
        plugin = nil
        super.tearDown()
    }

    // MARK: - getPlatformVersion

    func testGetPlatformVersion() {
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: "getPlatformVersion",
            arguments: nil
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(capture.called)
        let version = capture.value as? String
        XCTAssertNotNil(version)
        XCTAssertTrue(
            version?.hasPrefix("macOS") == true,
            "Expected version to start with 'macOS', got: \(version ?? "nil")"
        )
    }

    // MARK: - disposeCamera

    func testDisposeCameraWithoutInitialization() {
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: "disposeCamera",
            arguments: nil
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(capture.called)
        XCTAssertNil(capture.value, "disposeCamera should return nil")
    }

    // MARK: - pausePreview

    func testPausePreviewWithoutInitialization() {
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: "pausePreview",
            arguments: nil
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(capture.called)
        XCTAssertNil(capture.value, "pausePreview should return nil")
    }

    // MARK: - Unsupported macOS features

    func testSetRemoteRecordControlEnabled() {
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: "setRemoteRecordControlEnabled",
            arguments: ["enabled": true]
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(capture.called)
        XCTAssertEqual(
            capture.value as? Bool,
            false,
            "Remote record control should not be supported on macOS"
        )
    }

    func testSetVolumeKeysEnabled() {
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: "setVolumeKeysEnabled",
            arguments: ["enabled": true]
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(capture.called)
        XCTAssertEqual(
            capture.value as? Bool,
            false,
            "Volume keys should not be supported on macOS"
        )
    }

    // MARK: - Unknown method

    func testUnknownMethodReturnsNotImplemented() {
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: "nonExistentMethod",
            arguments: nil
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(capture.called)
        XCTAssertTrue(
            capture.isNotImplemented,
            "Unknown method should return FlutterMethodNotImplemented"
        )
    }

    // MARK: - NOT_INITIALIZED errors

    func testSetFlashModeWithoutInit() {
        assertNotInitializedError(
            method: "setFlashMode",
            arguments: ["mode": "torch"]
        )
    }

    func testSetFocusPointWithoutInit() {
        assertNotInitializedError(
            method: "setFocusPoint",
            arguments: ["x": 0.5, "y": 0.5]
        )
    }

    func testSetExposurePointWithoutInit() {
        assertNotInitializedError(
            method: "setExposurePoint",
            arguments: ["x": 0.5, "y": 0.5]
        )
    }

    func testCancelFocusAndMeteringWithoutInit() {
        assertNotInitializedError(
            method: "cancelFocusAndMetering",
            arguments: nil
        )
    }

    func testSetZoomLevelWithoutInit() {
        assertNotInitializedError(
            method: "setZoomLevel",
            arguments: ["level": 2.0]
        )
    }

    func testSwitchCameraWithoutInit() {
        assertNotInitializedError(
            method: "switchCamera",
            arguments: ["lens": "back"]
        )
    }

    func testStartRecordingWithoutInit() {
        assertNotInitializedError(
            method: "startRecording",
            arguments: ["useCache": true]
        )
    }

    func testStopRecordingWithoutInit() {
        assertNotInitializedError(
            method: "stopRecording",
            arguments: nil
        )
    }

    func testGetCameraStateWithoutInit() {
        assertNotInitializedError(
            method: "getCameraState",
            arguments: nil
        )
    }

    func testResumePreviewWithoutInit() {
        assertNotInitializedError(
            method: "resumePreview",
            arguments: nil
        )
    }

    // MARK: - Argument parsing

    func testInitializeCameraDefaultArguments() {
        // Without a texture registry, initializeCamera should return
        // a NO_REGISTRY error — this verifies argument parsing runs
        // before the camera controller is created.
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: "initializeCamera",
            arguments: nil  // No arguments — should use defaults
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(capture.called)
        let error = capture.flutterError
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.code, "NO_REGISTRY")
    }

    func testInitializeCameraWithArguments() {
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: "initializeCamera",
            arguments: [
                "lens": "back",
                "videoQuality": "uhd",
                "enableAutoLensSwitch": true,
            ]
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(capture.called)
        let error = capture.flutterError
        XCTAssertNotNil(error)
        XCTAssertEqual(
            error?.code,
            "NO_REGISTRY",
            "Without registrar, should fail with NO_REGISTRY"
        )
    }

    // MARK: - Helpers

    private func assertNotInitializedError(
        method: String,
        arguments: Any?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let capture = ResultCapture()
        let call = FlutterMethodCall(
            methodName: method,
            arguments: arguments
        )

        plugin.handle(call, result: capture.flutterResult)

        XCTAssertTrue(
            capture.called,
            "\(method) should call result",
            file: file,
            line: line
        )
        let error = capture.flutterError
        XCTAssertNotNil(
            error,
            "\(method) should return FlutterError when not initialized",
            file: file,
            line: line
        )
        XCTAssertEqual(
            error?.code,
            "NOT_INITIALIZED",
            "\(method) error code should be NOT_INITIALIZED",
            file: file,
            line: line
        )
        XCTAssertEqual(
            error?.message,
            "Camera not initialized",
            "\(method) error message mismatch",
            file: file,
            line: line
        )
    }
}
