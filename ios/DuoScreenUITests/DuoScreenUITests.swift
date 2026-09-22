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
}
