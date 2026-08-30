import XCTest

final class StemistShellUITests: XCTestCase {
    private struct RouteExpectation {
        let buttonIdentifier: String
        let moduleIdentifier: String
    }

    private let accountURL = URL(string: "stemist://open/ielts-account")!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testStudentBuildHidesAccountEntryAndRejectsAccountDeepLinks() {
        launchApp(fullFeatureTest: false)

        XCTAssertFalse(app.buttons["Profile"].exists)
        attachScreenshot(named: "student-account-entry-hidden")

        app.open(accountURL)
        XCTAssertFalse(app.otherElements["web-module-ielts-account"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.otherElements["stemist-root"].exists)
        attachScreenshot(named: "student-account-deep-link-blocked")
    }

    func testStudentBuildCanOpenAndCloseEveryIELTSRoute() {
        launchApp(fullFeatureTest: false)
        selectTab("IELTS")

        exerciseRoutes([
            RouteExpectation(buttonIdentifier: "route-ielts-listening", moduleIdentifier: "web-module-ielts-listening"),
            RouteExpectation(buttonIdentifier: "route-ielts-reading", moduleIdentifier: "web-module-ielts-reading"),
            RouteExpectation(buttonIdentifier: "route-ielts-writing", moduleIdentifier: "web-module-ielts-writing"),
            RouteExpectation(buttonIdentifier: "route-ielts-speaking", moduleIdentifier: "web-module-ielts-speaking"),
            RouteExpectation(buttonIdentifier: "route-ielts-vocabulary", moduleIdentifier: "web-module-ielts-vocabulary"),
        ])
    }

    func testStudentBuildCanOpenAndCloseEverySTEMRoute() {
        launchApp(fullFeatureTest: false)
        selectTab("STEM")

        exerciseRoutes([
            RouteExpectation(buttonIdentifier: "route-stem-ig", moduleIdentifier: "web-module-stem-ig"),
            RouteExpectation(buttonIdentifier: "route-stem-as", moduleIdentifier: "web-module-stem-as"),
            RouteExpectation(buttonIdentifier: "route-stem-a2", moduleIdentifier: "web-module-stem-a2"),
            RouteExpectation(buttonIdentifier: "route-stem-topics", moduleIdentifier: "web-module-stem-topics"),
            RouteExpectation(buttonIdentifier: "route-stem-past-papers", moduleIdentifier: "web-module-stem-past-papers"),
            RouteExpectation(buttonIdentifier: "route-stem-notebook", moduleIdentifier: "web-module-stem-notebook"),
            RouteExpectation(buttonIdentifier: "route-stem-coach", moduleIdentifier: "web-module-stem-coach"),
        ])
    }

    func testStudentBuildCanNavigateDashboardLearningSpacesAndNotebook() {
        launchApp(fullFeatureTest: false)
        selectTab("Today")

        assertDashboardLearningSpace(
            "learning-space-ielts-practice",
            exposesRoute: "route-ielts-listening"
        )

        selectTab("Today")
        assertDashboardLearningSpace(
            "learning-space-stem-study",
            exposesRoute: "route-stem-ig"
        )

        selectTab("Today")
        openAndCloseRoute(
            buttonIdentifier: "learning-space-ai-coach",
            moduleIdentifier: "web-module-ai-coach"
        )

        selectTab("Today")
        let notebookEntry = app.buttons["open-notebook"]
        XCTAssertTrue(notebookEntry.waitForExistence(timeout: 3))
        notebookEntry.tap()
        openAndCloseRoute(
            buttonIdentifier: "open-stem-notebook",
            moduleIdentifier: "web-module-stem-notebook"
        )
    }

    func testFullFeatureQABuildKeepsAccountEntryAndAllLearningRoutes() {
        launchApp(fullFeatureTest: true)

        selectTab("Profile")
        attachScreenshot(named: "qa-profile-entry-visible")
        openAndCloseRoute(
            buttonIdentifier: "route-ielts-account",
            moduleIdentifier: "web-module-ielts-account"
        )

        app.open(accountURL)
        let accountModule = app.otherElements["web-module-ielts-account"]
        XCTAssertTrue(accountModule.waitForExistence(timeout: 3))
        attachScreenshot(named: "qa-account-deep-link-opened")
        closeWebModule(accountModule, named: "web-module-ielts-account")

        selectTab("IELTS")
        exerciseRoutes([
            RouteExpectation(buttonIdentifier: "route-ielts-listening", moduleIdentifier: "web-module-ielts-listening"),
            RouteExpectation(buttonIdentifier: "route-ielts-reading", moduleIdentifier: "web-module-ielts-reading"),
            RouteExpectation(buttonIdentifier: "route-ielts-writing", moduleIdentifier: "web-module-ielts-writing"),
            RouteExpectation(buttonIdentifier: "route-ielts-speaking", moduleIdentifier: "web-module-ielts-speaking"),
            RouteExpectation(buttonIdentifier: "route-ielts-vocabulary", moduleIdentifier: "web-module-ielts-vocabulary"),
        ])

        selectTab("STEM")
        exerciseRoutes([
            RouteExpectation(buttonIdentifier: "route-stem-ig", moduleIdentifier: "web-module-stem-ig"),
            RouteExpectation(buttonIdentifier: "route-stem-as", moduleIdentifier: "web-module-stem-as"),
            RouteExpectation(buttonIdentifier: "route-stem-a2", moduleIdentifier: "web-module-stem-a2"),
            RouteExpectation(buttonIdentifier: "route-stem-topics", moduleIdentifier: "web-module-stem-topics"),
            RouteExpectation(buttonIdentifier: "route-stem-past-papers", moduleIdentifier: "web-module-stem-past-papers"),
            RouteExpectation(buttonIdentifier: "route-stem-notebook", moduleIdentifier: "web-module-stem-notebook"),
            RouteExpectation(buttonIdentifier: "route-stem-coach", moduleIdentifier: "web-module-stem-coach"),
        ])

        selectTab("Today")
        assertDashboardLearningSpace(
            "learning-space-ielts-practice",
            exposesRoute: "route-ielts-listening"
        )

        selectTab("Today")
        assertDashboardLearningSpace(
            "learning-space-stem-study",
            exposesRoute: "route-stem-ig"
        )

        selectTab("Today")
        openAndCloseRoute(
            buttonIdentifier: "learning-space-ai-coach",
            moduleIdentifier: "web-module-ai-coach"
        )

        selectTab("Today")
        let notebookEntry = app.buttons["open-notebook"]
        XCTAssertTrue(notebookEntry.waitForExistence(timeout: 3))
        notebookEntry.tap()
        openAndCloseRoute(
            buttonIdentifier: "open-stem-notebook",
            moduleIdentifier: "web-module-stem-notebook"
        )
    }

    private func launchApp(fullFeatureTest: Bool) {
        app = XCUIApplication()
        app.launchEnvironment["STEMIST_FULL_FEATURE_TEST"] = fullFeatureTest ? "YES" : "NO"
        app.launch()
        XCTAssertTrue(app.otherElements["stemist-root"].waitForExistence(timeout: 3))
        attachScreenshot(named: fullFeatureTest ? "qa-launch" : "student-launch")
    }

    private func selectTab(_ visibleLabel: String) {
        let tab = app.buttons[visibleLabel]
        guard tab.waitForExistence(timeout: 3) else {
            XCTFail("Expected tab \(visibleLabel) to be available.\n\n\(app.debugDescription)")
            return
        }
        tab.tap()
    }

    private func assertDashboardLearningSpace(_ identifier: String, exposesRoute routeIdentifier: String) {
        let learningSpace = app.buttons[identifier]
        XCTAssertTrue(learningSpace.waitForExistence(timeout: 3), "Expected \(identifier) to be available")
        guard learningSpace.exists else { return }
        learningSpace.tap()
        XCTAssertTrue(app.buttons[routeIdentifier].waitForExistence(timeout: 3), "Expected \(identifier) to open its learning space")
    }

    private func exerciseRoutes(_ routes: [RouteExpectation]) {
        for route in routes {
            XCTContext.runActivity(named: route.buttonIdentifier) { _ in
                openAndCloseRoute(
                    buttonIdentifier: route.buttonIdentifier,
                    moduleIdentifier: route.moduleIdentifier
                )
            }
        }
    }

    private func openAndCloseRoute(buttonIdentifier: String, moduleIdentifier: String) {
        let routeButton = app.buttons[buttonIdentifier]
        XCTAssertTrue(routeButton.waitForExistence(timeout: 3), "Expected \(buttonIdentifier) to be available")
        guard routeButton.exists else { return }
        routeButton.tap()

        let module = app.otherElements[moduleIdentifier]
        XCTAssertTrue(module.waitForExistence(timeout: 3), "Expected \(buttonIdentifier) to open \(moduleIdentifier)")
        attachScreenshot(named: "\(moduleIdentifier)-opened")
        closeWebModule(module, named: moduleIdentifier)
    }

    private func closeWebModule(_ module: XCUIElement, named moduleIdentifier: String) {
        guard module.exists else { return }

        let closeButton = app.buttons["web-close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Expected \(moduleIdentifier) to expose a close control")
        guard closeButton.exists else { return }
        closeButton.tap()
        XCTAssertFalse(module.waitForExistence(timeout: 2), "Expected \(moduleIdentifier) to close")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
