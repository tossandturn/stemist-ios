import XCTest

final class StemistShellUITests: XCTestCase {
    private let accountURL = URL(string: "stemist://open/ielts-account")!
    private var app: XCUIApplication!

    func testStudentBuildHidesAccountEntryAndKeepsLearningSpacesNavigable() {
        launchApp(fullFeatureTest: false)

        XCTAssertFalse(app.tabBars.buttons["Profile"].exists)
        XCTAssertTrue(app.tabBars.buttons["tab-ielts"].waitForExistence(timeout: 3))
        app.tabBars.buttons["tab-ielts"].tap()
        XCTAssertTrue(app.buttons["route-ielts-listening"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.tabBars.buttons["tab-stem"].waitForExistence(timeout: 3))
        app.tabBars.buttons["tab-stem"].tap()
        XCTAssertTrue(app.buttons["route-stem-ig"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.tabBars.buttons["tab-notebook"].waitForExistence(timeout: 3))
        app.tabBars.buttons["tab-notebook"].tap()
        XCTAssertTrue(app.buttons["open-stem-notebook"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.tabBars.buttons["tab-today"].waitForExistence(timeout: 3))
        app.tabBars.buttons["tab-today"].tap()
        XCTAssertTrue(app.buttons["learning-space-ai-coach"].waitForExistence(timeout: 3))
        app.buttons["learning-space-ai-coach"].tap()
        XCTAssertTrue(app.otherElements["web-module-ai-coach"].waitForExistence(timeout: 3))
        app.buttons["web-close"].tap()
        XCTAssertFalse(app.otherElements["web-module-ai-coach"].waitForExistence(timeout: 1))

        app.open(accountURL)
        XCTAssertFalse(app.otherElements["web-module-ielts-account"].waitForExistence(timeout: 1))
    }

    func testFullFeatureQABuildKeepsAccountEntryAndDeepLink() {
        launchApp(fullFeatureTest: true)

        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: 3))
        app.open(accountURL)
        XCTAssertTrue(app.otherElements["web-module-ielts-account"].waitForExistence(timeout: 3))
    }

    private func launchApp(fullFeatureTest: Bool) {
        app = XCUIApplication()
        app.launchEnvironment["STEMIST_FULL_FEATURE_TEST"] = fullFeatureTest ? "YES" : "NO"
        app.launch()
        XCTAssertTrue(app.otherElements["stemist-root"].waitForExistence(timeout: 3))
    }
}
