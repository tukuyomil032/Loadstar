import XCTest

final class LoadStarAppUITests: XCTestCase {
    func testFixturePreviewSeparatesProcessAndReadiness() {
        let app = XCUIApplication()
        app.launchEnvironment["LOADSTAR_UI_TEST_MODE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["server.process.status.detail"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["server.process.status.detail"].label, "Process: Running")
        XCTAssertEqual(app.staticTexts["server.readiness.status"].label, "Readiness: Connecting")
        XCTAssertTrue(app.buttons["server.capability.stop"].isEnabled)
        XCTAssertTrue(app.buttons["server.capability.restart"].isEnabled)
        XCTAssertFalse(app.buttons["server.launch.button"].isEnabled)

        app.switches["server.eula.checkbox"].tap()
        XCTAssertTrue(app.buttons["server.launch.button"].isEnabled)
    }
}
