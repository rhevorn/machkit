import XCTest

final class MachKitUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesMainWindow() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-showMenuBar", "NO",
            "-menuBarCloseBehaviorRepairV2", "YES",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.windows.firstMatch.isHittable)
    }

    @MainActor
    func testClosingLastWindowMovesAppToMenuBarBackground() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-showMenuBar", "YES",
            "-menuBarCloseBehaviorRepairV2", "YES",
        ]
        app.launch()
        defer { app.terminate() }

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.buttons[XCUIIdentifierCloseWindow].click()

        XCTAssertTrue(window.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
    }
}
