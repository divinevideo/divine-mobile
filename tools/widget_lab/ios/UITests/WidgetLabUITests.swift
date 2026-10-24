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
        if !home.icons["Divine Widget Lab"].firstMatch.exists { addSquareWidget(home) }
        let widget = home.icons["Divine Widget Lab"].firstMatch
        XCTAssertTrue(widget.waitForExistence(timeout: 15), "Add the small square widget before running this test. " + home.debugDescription)
        XCTAssertLessThan(widget.frame.width, 220, "The test requires the small square widget on home-screen page two.")
        XCTAssertGreaterThan(widget.frame.height, widget.frame.width * 0.9)
        attach(home.screenshot(), "Widget before Next")
        // WidgetKit's remote controls are not exposed consistently by SpringBoard AX.
        // The small icon's bounds include the app label below the square tile.
        // These points are inside bottom-right Next, bottom-left Like, and top-right Open.
        widget.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.75)).tap()
        attach(home.screenshot(), "Widget immediately after Next")
        widget.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.75)).tap()
        attach(home.screenshot(), "Widget after Like")
        widget.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.17)).tap()
        XCTAssertTrue(app.navigationBars["Divine Widget Lab"].waitForExistence(timeout: 10), app.debugDescription)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Next taps: 1"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Like / unlike taps: 1"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["Open taps: 1"].exists, app.debugDescription)
        attach(app.screenshot(), "Verified local widget actions")
    }

    private func addSquareWidget(_ home: XCUIApplication) {
        // A blank area on page two of this disposable test simulator.
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 1.5)
        let edit = home.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), home.debugDescription)
        edit.tap()
        let add = home.buttons["Add Widget"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), home.debugDescription)
        add.tap()
        let search = home.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), home.debugDescription)
        search.tap()
        search.typeText("Divine")
        let lab = home.cells["Divine Widget Lab"].firstMatch
        XCTAssertTrue(lab.waitForExistence(timeout: 5), home.debugDescription)
        lab.tap()
        let galleryAdd = home.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Add Widget")).firstMatch
        XCTAssertTrue(galleryAdd.waitForExistence(timeout: 5), home.debugDescription)
        attach(home.screenshot(), "iOS square gallery")
        home.swipeLeft()
        attach(home.screenshot(), "iOS large gallery")
        home.swipeRight()
        galleryAdd.tap()
        let done = home.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), home.debugDescription)
        done.tap()
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
