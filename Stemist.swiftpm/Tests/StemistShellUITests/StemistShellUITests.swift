import Foundation
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
        openCustomURLFromSafari(accountURL)
        XCTAssertTrue(app.otherElements["stemist-root"].waitForExistence(timeout: 10))
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
        launchApp(fullFeatureTest: true)
        app.terminate()
        openCustomURLFromSafari(accountURL)

        XCTAssertTrue(app.otherElements["stemist-root"].waitForExistence(timeout: 10))
        XCTAssertTrue(tabButton("Profile").exists)
        let accountModule = webModule("web-module-ielts-account")
        guard accountModule.waitForExistence(timeout: 5) else {
            let root = app.otherElements["stemist-root"]
            XCTFail(
                "Expected a cold-launch account deep link to open the QA account module."
                    + "\n\nRoot lifecycle diagnostics: \(String(describing: root.value))"
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

    func testFullFeatureQABuildReopensWarmAccountDeepLinkAfterModuleReplacement() {
        launchApp(fullFeatureTest: true)
        selectTab("IELTS")

        let listeningRoute = app.buttons["route-ielts-listening"]
        XCTAssertTrue(waitUntilHittable(listeningRoute))
        guard listeningRoute.exists, listeningRoute.isHittable else { return }
        listeningRoute.tap()

        let listeningModule = webModule("web-module-ielts-listening")
        XCTAssertTrue(listeningModule.waitForExistence(timeout: 3))

        openCustomURLFromSafari(accountURL)

        XCTAssertTrue(
            listeningModule.waitForNonExistence(timeout: 5),
            "Expected a warm account deep link to replace the active IELTS module."
        )
        let accountModule = webModule("web-module-ielts-account")
        guard accountModule.waitForExistence(timeout: 5) else {
            let root = app.otherElements["stemist-root"]
            XCTFail(
                "Expected a warm account deep link to open the QA account module."
                    + "\n\nRoot lifecycle diagnostics: \(String(describing: root.value))"
                    + "\n\nAccessibility hierarchy after warm replacement:\n\(app.debugDescription)"
            )
            return
        }
        attachScreenshot(named: "qa-account-deep-link-opened-from-warm-replacement")

        // The app deliberately suppresses duplicate system handoffs briefly.
        // This verifies the next separate user action after that window expires.
        waitForCustomURLReplayWindow()
        closeWebModule(accountModule, named: "web-module-ielts-account")

        openCustomURLFromSafari(accountURL)

        let reopenedAccountModule = webModule("web-module-ielts-account")
        guard reopenedAccountModule.waitForExistence(timeout: 5) else {
            let root = app.otherElements["stemist-root"]
            let lifecycleProbe = app.descendants(matching: .any)["stemist-routing-lifecycle"]
            XCTFail(
                "Expected the same valid warm account deep link to reopen after its workspace closed."
                    + "\n\nRoot lifecycle diagnostics: \(String(describing: root.value))"
                    + "\n\nRouting lifecycle probe: \(String(describing: lifecycleProbe.value))"
                    + "\n\nAccessibility hierarchy after replaying the warm deep link:\n\(app.debugDescription)"
            )
            return
        }
        attachScreenshot(named: "qa-account-deep-link-reopened-after-warm-replacement")
        closeWebModule(reopenedAccountModule, named: "web-module-ielts-account")
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
        XCTAssertTrue(
            waitUntilHittableByScrolling(routeButton),
            "Expected \(buttonIdentifier) to be available and hittable.\n\n\(app.debugDescription)"
        )
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

    private func waitUntilHittableByScrolling(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if waitUntilHittable(element, timeout: 0.5) {
                return true
            }
            guard element.exists else { continue }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    private func closeWebModule(_ module: XCUIElement, named moduleIdentifier: String) {
        guard module.exists else { return }

        let workspaceChrome = app.otherElements["web-workspace-chrome"]
        XCTAssertTrue(
            workspaceChrome.waitForExistence(timeout: 3),
            "Expected \(moduleIdentifier) to mount its native workspace chrome."
                + "\n\nAccessibility hierarchy while the module is open:\n\(app.debugDescription)"
        )

        let closeButton = app.buttons["web-close"]
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 3),
            "Expected \(moduleIdentifier) to expose a close control."
                + "\n\nAccessibility hierarchy while the module is open:\n\(app.debugDescription)"
        )
        guard closeButton.exists else { return }

        let closeFrame = closeButton.frame
        XCTAssertFalse(closeFrame.isEmpty, "Expected \(moduleIdentifier)'s close control to have a visible frame")
        guard !closeFrame.isEmpty else { return }

        closeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        guard workspaceChrome.waitForNonExistence(timeout: 3) else {
            let root = app.otherElements["stemist-root"]
            XCTFail(
                "Expected \(moduleIdentifier)'s native workspace chrome to close."
                    + "\n\nRoot workspace diagnostics: \(String(describing: root.value))"
                    + "\n\nAccessibility hierarchy after tapping close:\n\(app.debugDescription)"
            )
            return
        }

        let tabIdentifiers = ["tab-today", "tab-ielts", "tab-stem", "tab-notebook", "tab-profile"]
        let restoredTabCandidates = app.buttons.matching(
            NSPredicate(format: "identifier IN %@", tabIdentifiers)
        )
        let restoredTab = restoredTabCandidates.allElementsBoundByIndex.first(where: {
            $0.exists && $0.isHittable
        }) ?? restoredTabCandidates.firstMatch
        XCTAssertTrue(
            waitUntilHittable(restoredTab),
            "Expected the native product shell to become interactive after closing \(moduleIdentifier)."
                + "\n\nAccessibility hierarchy after closing the workspace:\n\(app.debugDescription)"
        )
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openCustomURLFromSafari(_ url: URL) {
        let lifecycleProbe = app.descendants(matching: .any)["stemist-routing-lifecycle"]
        if app.state == .runningForeground {
            _ = lifecycleProbe.waitForExistence(timeout: 3)
        }
        let previousLifecycleValue = lifecycleProbe.exists ? lifecycleProbe.value as? String : nil
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()

        let addressField = safariAddressField(in: safari)
        XCTAssertTrue(
            addressField.waitForExistence(timeout: 8),
            "Expected Safari to expose an address field before opening \(url.absoluteString).\n\n\(safari.debugDescription)"
        )
        guard addressField.exists else { return }

        addressField.tap()
        // Safari can retain the previous custom URL after a warm handoff.
        // Replace the focused address contents rather than appending a second
        // scheme, which would never reach the application delegate.
        safari.typeKey("a", modifierFlags: .command)
        // Safari exposes duplicate Address text fields after focus on iPadOS.
        // Send text to the focused application instead of re-resolving the
        // now-ambiguous address-field query.
        safari.typeText(url.absoluteString)

        let goButtons = [
            safari.keyboards.buttons["go"],
            safari.keyboards.buttons["Go"],
            safari.buttons["Go"],
        ]
        for goButton in goButtons {
            if goButton.waitForExistence(timeout: 1) {
                goButton.tap()
                XCTAssertTrue(
                    waitForStemistHandoff(from: safari, previousLifecycleValue: previousLifecycleValue),
                    customURLHandoffFailureDescription(safari: safari, url: url)
                )
                return
            }
        }

        safari.typeText("\n")
        XCTAssertTrue(
            waitForStemistHandoff(from: safari, previousLifecycleValue: previousLifecycleValue),
            customURLHandoffFailureDescription(safari: safari, url: url)
        )
    }

    private func waitForCustomURLReplayWindow() {
        let replayWindow = expectation(description: "custom URL duplicate suppression window expires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
            replayWindow.fulfill()
        }
        wait(for: [replayWindow], timeout: 3)
    }

    private func safariAddressField(in safari: XCUIApplication) -> XCUIElement {
        let focusedSearchField = safari.textFields.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "SearchFieldItemView")
        ).firstMatch
        if focusedSearchField.exists {
            return focusedSearchField
        }

        let labels = [
            "Search or enter website name",
            "Address",
            "URL",
            "Tab Bar",
        ]
        for label in labels {
            let field = safari.textFields[label].firstMatch
            if field.exists {
                return field
            }
        }
        return safari.textFields.firstMatch
    }

    private func waitForStemistHandoff(
        from safari: XCUIApplication,
        previousLifecycleValue: String?,
        timeout: TimeInterval = 12
    ) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let buttonLabels = ["Open", "Allow", "Continue"]
        let promptPredicate = NSPredicate(format: "label IN %@", buttonLabels)
        let springboardButton = springboard.buttons.matching(promptPredicate).firstMatch
        let safariButton = safari.buttons.matching(promptPredicate).firstMatch
        let root = app.otherElements["stemist-root"]
        let lifecycleProbe = app.descendants(matching: .any)["stemist-routing-lifecycle"]
        let deadline = Date().addingTimeInterval(timeout)
        var didTapOpenPrompt = false
        var didObserveSafariForeground = false
        var didObserveStemistBackground = app.state != .runningForeground

        while Date() < deadline {
            if safari.state == .runningForeground {
                didObserveSafariForeground = true
            }
            if app.state != .runningForeground {
                didObserveStemistBackground = true
            }

            let currentLifecycleValue = lifecycleProbe.exists ? lifecycleProbe.value as? String : nil
            let lifecycleChanged: Bool
            if let previousLifecycleValue {
                lifecycleChanged = currentLifecycleValue != previousLifecycleValue
            } else {
                lifecycleChanged = currentLifecycleValue != nil
            }

            if didObserveSafariForeground,
               didObserveStemistBackground,
               app.state == .runningForeground,
               root.exists,
               lifecycleChanged {
                return true
            }

            if !didTapOpenPrompt {
                for promptButton in [springboardButton, safariButton] {
                    if promptButton.exists && promptButton.isHittable {
                        promptButton.tap()
                        didTapOpenPrompt = true
                        break
                    }
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        let currentLifecycleValue = lifecycleProbe.exists ? lifecycleProbe.value as? String : nil
        let lifecycleChanged: Bool
        if let previousLifecycleValue {
            lifecycleChanged = currentLifecycleValue != previousLifecycleValue
        } else {
            lifecycleChanged = currentLifecycleValue != nil
        }
        return didObserveSafariForeground
            && didObserveStemistBackground
            && app.state == .runningForeground
            && root.exists
            && lifecycleChanged
    }

    private func customURLHandoffFailureDescription(
        safari: XCUIApplication,
        url: URL
    ) -> String {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let lifecycleProbe = app.descendants(matching: .any)["stemist-routing-lifecycle"]
        return "Expected Safari to hand \(url.absoluteString) to Stemist."
            + "\n\nStemist state: \(app.state.rawValue)"
            + "\n\nRouting lifecycle probe: \(String(describing: lifecycleProbe.value))"
            + "\n\nStemist hierarchy:\n\(safeHierarchyDescription(for: app))"
            + "\n\nSafari hierarchy:\n\(safeHierarchyDescription(for: safari))"
            + "\n\nSpringBoard hierarchy:\n\(safeHierarchyDescription(for: springboard))"
    }

    private func safeHierarchyDescription(for application: XCUIApplication) -> String {
        let state = application.state
        guard state == .runningForeground else {
            return "<hierarchy unavailable; application state=\(state.rawValue)>"
        }
        return application.debugDescription
    }
}
