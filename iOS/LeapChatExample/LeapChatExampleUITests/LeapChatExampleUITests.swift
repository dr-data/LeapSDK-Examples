import XCTest

final class LeapChatExampleUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Home Screen

    @MainActor
    func testAppLaunches() throws {
        // App Home shows APOLLO branding
        XCTAssertTrue(app.staticTexts["APOLLO"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAppHomeSectionsVisible() throws {
        XCTAssertTrue(app.staticTexts["APPS"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Chat"].exists)
    }

    @MainActor
    func testAppHomeShowsRecents() throws {
        XCTAssertTrue(app.staticTexts["RECENTS"].waitForExistence(timeout: 3))
    }

    // MARK: - Navigation to AI Providers

    @MainActor
    func testSettingsNavigation() throws {
        // Tap gear icon on App Home
        let gearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gearshape'")).firstMatch
        if gearButton.waitForExistence(timeout: 3) {
            gearButton.tap()
            XCTAssertTrue(app.staticTexts["AI Providers"].waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testAIProvidersShowsAllProviders() throws {
        let gearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gearshape'")).firstMatch
        if gearButton.waitForExistence(timeout: 3) {
            gearButton.tap()
            XCTAssertTrue(app.staticTexts["AI Providers"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["OpenRouter"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["Local Model"].exists)
            XCTAssertTrue(app.staticTexts["Custom Backends"].exists)
        }
    }

    // MARK: - Navigation to Local Models

    @MainActor
    func testLocalModelNavigation() throws {
        let gearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gearshape'")).firstMatch
        if gearButton.waitForExistence(timeout: 3) {
            gearButton.tap()
            XCTAssertTrue(app.staticTexts["AI Providers"].waitForExistence(timeout: 3))
            app.staticTexts["Local Model"].tap()
            XCTAssertTrue(app.staticTexts["Local Models"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["CHAT MODELS"].waitForExistence(timeout: 3))
        }
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
