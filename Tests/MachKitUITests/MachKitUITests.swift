import XCTest

final class MachKitUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesMainWindow() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-showMenuBar", "NO",
            "-menuBarCloseBehaviorRepairV1", "YES",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.windows.firstMatch.isHittable)
    }
}
