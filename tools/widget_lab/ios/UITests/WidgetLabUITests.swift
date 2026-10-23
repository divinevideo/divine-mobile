import XCTest

final class WidgetLabUITests: XCTestCase {
    func testHomeScreenWidgetActions() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "video.divine.widgetlab")
        app.launch()
        XCTAssertTrue(app.navigationBars["Divine Widget Lab"].waitForExistence(timeout: 15))
        let reset = app.buttons["Reset experiment"]
        if !reset.isHittable { app.swipeUp() }
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        home.swipeLeft()
        let widget = home.icons["Divine Widget Lab"].firstMatch
        XCTAssertTrue(widget.waitForExistence(timeout: 15), "Add the medium widget before running this test. " + home.debugDescription)
        XCTAssertGreaterThan(widget.frame.width, 200, "The test requires the medium widget on home-screen page two.")
        attach(home.screenshot(), "Widget before Next")
        // WidgetKit's remote controls are not exposed consistently by SpringBoard AX.
        // These points are inside the medium card's bottom-right Next, Like, and top-right Open.
        widget.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.72)).tap()
        attach(home.screenshot(), "Widget immediately after Next")
        widget.coordinate(withNormalizedOffset: CGVector(dx: 0.77, dy: 0.72)).tap()
        attach(home.screenshot(), "Widget after Like")
        widget.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.17)).tap()
        XCTAssertTrue(app.navigationBars["Divine Widget Lab"].waitForExistence(timeout: 10), app.debugDescription)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Next taps: 1"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Like / unlike taps: 1"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["Open taps: 1"].exists, app.debugDescription)
        attach(app.screenshot(), "Verified local widget actions")
    }

    private func attach(_ screenshot: XCUIScreenshot, _ name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WidgetLabScreens")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        print("WidgetLabScreens: \(directory.path)")
    }
}
