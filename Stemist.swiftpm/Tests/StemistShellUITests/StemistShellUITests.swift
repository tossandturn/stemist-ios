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

        XCTAssertFalse(tabButton("Profile").exists)
        attachScreenshot(named: "student-account-entry-hidden")

        app.terminate()
        app.open(accountURL)
        XCTAssertTrue(app.otherElements["stemist-root"].waitForExistence(timeout: 3))
        XCTAssertFalse(tabButton("Profile").exists)
        XCTAssertFalse(webModule("web-module-ielts-account").waitForExistence(timeout: 1))
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
        XCTAssertTrue(waitUntilHittable(notebookEntry))
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
        XCTAssertTrue(waitUntilHittable(notebookEntry))
        notebookEntry.tap()
        openAndCloseRoute(
            buttonIdentifier: "open-stem-notebook",
            moduleIdentifier: "web-module-stem-notebook"
        )
    }

    func testFullFeatureQABuildOpensAccountDeepLinkFromColdLaunch() {
        app = XCUIApplication()
        app.launchEnvironment["STEMIST_FULL_FEATURE_TEST"] = "YES"
        app.open(accountURL)

        XCTAssertTrue(app.otherElements["stemist-root"].waitForExistence(timeout: 3))
        XCTAssertTrue(tabButton("Profile").exists)
        let accountModule = webModule("web-module-ielts-account")
        guard accountModule.waitForExistence(timeout: 5) else {
            XCTFail(
                "Expected a cold-launch account deep link to open the QA account module."
                    + "\n\nAccessibility hierarchy after cold launch:\n\(app.debugDescription)"
            )
            return
        }
        attachScreenshot(named: "qa-account-deep-link-opened-from-cold-launch")
        closeWebModule(accountModule, named: "web-module-ielts-account")
    }

    func testFullFeatureQABuildQueuesAccountRouteDuringModuleReplacement() {
        launchApp(fullFeatureTest: true)
        selectTab("IELTS")

        let listeningRoute = app.buttons["route-ielts-listening"]
        XCTAssertTrue(waitUntilHittable(listeningRoute))
        guard listeningRoute.exists, listeningRoute.isHittable else { return }
        listeningRoute.tap()

        let listeningModule = webModule("web-module-ielts-listening")
        XCTAssertTrue(listeningModule.waitForExistence(timeout: 3))

        let accountRoute = app.buttons["web-open-account"]
        XCTAssertTrue(waitUntilHittable(accountRoute))
        guard accountRoute.exists, accountRoute.isHittable else { return }
        accountRoute.tap()

        XCTAssertTrue(
            listeningModule.waitForNonExistence(timeout: 5),
            "Expected the prior IELTS module to finish replacement dismissal"
        )
        let accountModule = webModule("web-module-ielts-account")
        guard accountModule.waitForExistence(timeout: 5) else {
            XCTFail(
                "Expected the queued in-process account route to open after dismissal."
                    + "\n\nAccessibility hierarchy after route replacement:\n\(app.debugDescription)"
            )
            return
        }
        attachScreenshot(named: "qa-account-route-replayed-after-module-replacement")
        closeWebModule(accountModule, named: "web-module-ielts-account")
    }

    private func launchApp(fullFeatureTest: Bool) {
        app = XCUIApplication()
        app.launchEnvironment["STEMIST_FULL_FEATURE_TEST"] = fullFeatureTest ? "YES" : "NO"
        app.launch()
        XCTAssertTrue(app.otherElements["stemist-root"].waitForExistence(timeout: 3))
        attachScreenshot(named: fullFeatureTest ? "qa-launch" : "student-launch")
    }

    private func selectTab(_ visibleLabel: String) {
        let tab = tabButton(visibleLabel)
        guard waitUntilHittable(tab) else {
            XCTFail("Expected tab \(visibleLabel) to be available and hittable.\n\n\(app.debugDescription)")
            return
        }
        tab.tap()
    }

    private func tabButton(_ visibleLabel: String) -> XCUIElement {
        let identifier: String
        switch visibleLabel {
        case "Today":
            identifier = "tab-today"
        case "IELTS":
            identifier = "tab-ielts"
        case "STEM":
            identifier = "tab-stem"
        case "Notebook":
            identifier = "tab-notebook"
        case "Profile":
            identifier = "tab-profile"
        default:
            identifier = visibleLabel
        }

        if ["Today", "IELTS", "STEM", "Notebook", "Profile"].contains(visibleLabel) {
            // SwiftUI's iPad tab bar exports both the native tab button and
            // its accessibility proxy. The first match can be a non-hittable
            // proxy, so choose the live native element instead.
            let candidates = app.buttons.matching(
                NSPredicate(format: "identifier == %@ AND label == %@", identifier, visibleLabel)
            )
            return candidates.allElementsBoundByIndex.first(where: {
                $0.exists && $0.isHittable
            }) ?? candidates.firstMatch
        }

        return app.buttons
            .matching(NSPredicate(format: "label == %@ AND hittable == true", visibleLabel))
            .firstMatch
    }

    private func assertDashboardLearningSpace(_ identifier: String, exposesRoute routeIdentifier: String) {
        let learningSpace = app.buttons[identifier]
        XCTAssertTrue(waitUntilHittable(learningSpace), "Expected \(identifier) to be available and hittable")
        guard learningSpace.exists, learningSpace.isHittable else { return }
        learningSpace.tap()
        XCTAssertTrue(
            waitUntilHittable(app.buttons[routeIdentifier]),
            "Expected \(identifier) to open its learning space"
        )
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
        XCTAssertTrue(waitUntilHittable(routeButton), "Expected \(buttonIdentifier) to be available and hittable")
        guard routeButton.exists, routeButton.isHittable else { return }
        routeButton.tap()

        let module = webModule(moduleIdentifier)
        guard module.waitForExistence(timeout: 3) else {
            XCTFail(
                "Expected \(buttonIdentifier) to open \(moduleIdentifier)."
                    + "\n\nAccessibility hierarchy after opening the route:\n\(app.debugDescription)"
            )
            return
        }
        attachScreenshot(named: "\(moduleIdentifier)-opened")
        closeWebModule(module, named: moduleIdentifier)
    }

    private func webModule(_ identifier: String) -> XCUIElement {
        app.webViews[identifier]
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func closeWebModule(_ module: XCUIElement, named moduleIdentifier: String) {
        guard module.exists else { return }

        let closeButton = app.buttons["web-close"]
        XCTAssertTrue(waitUntilHittable(closeButton), "Expected \(moduleIdentifier) to expose a close control")
        guard closeButton.exists, closeButton.isHittable else { return }
        closeButton.tap()
        XCTAssertTrue(module.waitForNonExistence(timeout: 3), "Expected \(moduleIdentifier) to close")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
