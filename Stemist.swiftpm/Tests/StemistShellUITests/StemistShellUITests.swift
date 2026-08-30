import XCTest

final class StemistShellUITests: XCTestCase {
    private struct RouteExpectation {
        let buttonIdentifier: String
        let moduleIdentifier: String
    }

    private let accountURL = URL(string: "stemist://open/ielts-account")!
    private var app: XCUIApplication!

    func testStudentBuildHidesAccountEntryAndRejectsAccountDeepLinks() {
        launchApp(fullFeatureTest: false)

        XCTAssertFalse(app.tabBars.buttons["Profile"].exists)

        app.open(accountURL)
        XCTAssertFalse(app.otherElements["web-module-ielts-account"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.otherElements["stemist-root"].exists)
    }

    func testStudentBuildCanOpenAndCloseEveryIELTSRoute() {
        launchApp(fullFeatureTest: false)
        selectTab("tab-ielts")

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
        selectTab("tab-stem")

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
        selectTab("tab-today")

        assertDashboardLearningSpace(
            "learning-space-ielts-practice",
            exposesRoute: "route-ielts-listening"
        )

        selectTab("tab-today")
        assertDashboardLearningSpace(
            "learning-space-stem-study",
            exposesRoute: "route-stem-ig"
        )

        selectTab("tab-today")
        openAndCloseRoute(
            buttonIdentifier: "learning-space-ai-coach",
            moduleIdentifier: "web-module-ai-coach"
        )

        selectTab("tab-today")
        let notebookEntry = app.buttons["open-notebook"]
        XCTAssertTrue(notebookEntry.waitForExistence(timeout: 3))
        notebookEntry.tap()
        openAndCloseRoute(
            buttonIdentifier: "open-stem-notebook",
            moduleIdentifier: "web-module-stem-notebook"
        )
    }

    func testFullFeatureQABuildKeepsAccountEntryAndDeepLink() {
        launchApp(fullFeatureTest: true)

        selectTab("Profile")
        openAndCloseRoute(
            buttonIdentifier: "route-ielts-account",
            moduleIdentifier: "web-module-ielts-account"
        )

        app.open(accountURL)
        let accountModule = app.otherElements["web-module-ielts-account"]
        XCTAssertTrue(accountModule.waitForExistence(timeout: 3))
        closeWebModule(accountModule, named: "web-module-ielts-account")
    }

    private func launchApp(fullFeatureTest: Bool) {
        app = XCUIApplication()
        app.launchEnvironment["STEMIST_FULL_FEATURE_TEST"] = fullFeatureTest ? "YES" : "NO"
        app.launch()
        XCTAssertTrue(app.otherElements["stemist-root"].waitForExistence(timeout: 3))
    }

    private func selectTab(_ identifier: String) {
        let tab = app.tabBars.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 3), "Expected tab \(identifier) to be available")
        guard tab.exists else { return }
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
}
