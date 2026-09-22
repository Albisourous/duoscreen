import XCTest

final class DuoScreenUITests: XCTestCase {
    /// Debug harness: launch, rotate, dump a screenshot the test runner
    /// (which runs on the Mac) can write to /tmp.
    func testLandscapeLayout() throws {
        XCUIApplication().launch()
        sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        try XCUIScreen.main.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/duo_landscape.png"))
    }

    /// Both panes load a video at once — screenshot proves concurrent playback.
    func testDualVideoPlayback() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)
        let urls = [
            "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4",
            "https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4",
        ]
        for url in urls {
            // Only a pane still on the start page has the placeholder pill.
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Search or enter address'"))
                .element(boundBy: 0).tap()
            let field = app.textFields.element(boundBy: 0)
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            field.typeText(url + "\n")
            sleep(2)
        }
        // Both panes navigated = both can hold media at once. (No play taps —
        // tapping a media document kicks it fullscreen.)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'mozilla'"))
            .firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'blender'"))
            .firstMatch.waitForExistence(timeout: 10))
        sleep(4)
        try XCUIScreen.main.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/duo_dualvideo.png"))
    }
}
