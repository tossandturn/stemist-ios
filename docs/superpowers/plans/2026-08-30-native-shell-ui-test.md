# Native Shell UI Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the native iPad shell behaves differently in student and internal QA builds without exposing account entry in the student artifact.

**Architecture:** Keep the app package usable in Swift Playgrounds by conditionally defining XCTest targets only outside Playgrounds. Run real `XCUIApplication` flows against an iPad Simulator on an Xcode 16.4-capable runner, while preserving the real-iPad matrix for WebKit, authentication, Pencil, media, upload, and AI coverage.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest/XCUIAutomation, Swift Package Manager AppleProductTypes, GitHub Actions, Codemagic.

**Spec:** `docs/ios-ipad-acceptance-matrix.md`

## Global Constraints

- Student builds use `STEMIST_FULL_FEATURE_TEST=NO` and must not present a Profile tab or an account deep-link destination.
- Internal QA builds use `STEMIST_FULL_FEATURE_TEST=YES` and must retain the Profile tab and account deep-link delivery.
- Swift Playgrounds on iPad must continue to load only the existing application target.
- No production credentials, tokens, or test-account data may enter the repository or CI output.
- WebKit product pages are server-backed; real iPad QA remains the release gate for authenticated, Pencil, media, upload, and AI flows.

---

### Task 1: Add Native Shell UI Coverage

**Files:**
- Create: `Stemist.swiftpm/Tests/StemistShellUITests/StemistShellUITests.swift`
- Modify: `Stemist.swiftpm/Package.swift`
- Modify: `.github/workflows/ios-simulator.yml`
- Modify: `scripts/test-navigation-contract.mjs`

**Interfaces:**
- Consumes: app bundle identifier `com.ieltsist.stemist`, native accessibility identifiers from `ContentView.swift` and `WebModuleView.swift`.
- Produces: `StemistShellUITests`, which launches the real app and exercises the student and QA shell modes.

- [ ] **Step 1: Write the failing UI test**

```swift
func testStudentBuildHidesAccountEntryAndKeepsLearningSpacesNavigable() {
    launchApp()
    XCTAssertFalse(app.tabBars.buttons["Profile"].exists)
    app.tabBars.buttons["Notebook"].tap()
    XCTAssertTrue(app.buttons["open-stem-notebook"].waitForExistence(timeout: 3))
}
```

- [ ] **Step 2: Make the test target and GitHub runner available only to Xcode/SwiftPM**

```swift
#if !SwiftPlaygrounds && !canImport(PlaygroundSupport)
targets.append(
    .testTarget(name: "StemistShellUITests", path: "Tests/StemistShellUITests")
)
#endif
```

Use `macos-15` and `DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer` so the Apple-supported `XCUIApplication.open(_:)` API is available. Add separate normal and QA `xcodebuild test` invocations, each targeting the same disposable iPad Simulator and retaining a dedicated test log.

- [ ] **Step 3: Run the student UI test in cloud CI and verify expected RED output**

Run the new `xcodebuild test -only-testing:StemistShellUITests/StemistShellUITests/testStudentBuildHidesAccountEntryAndKeepsLearningSpacesNavigable` command on an iPad Simulator.

Expected: the test fails because `open-stem-notebook` is not yet assigned to the native button.

### Task 2: Repair The Native Test Boundary

**Files:**
- Modify: `Stemist.swiftpm/ContentView.swift`
- Modify: `Stemist.swiftpm/WebModuleView.swift`

**Interfaces:**
- Consumes: the UI test's `open-stem-notebook` identifier and existing `stemistAllowsAccountEntry` environment value.
- Produces: an accessible Notebook entry and a product-domain-only account-hiding script.

- [ ] **Step 1: Add the missing Notebook accessibility identifier**

```swift
.accessibilityIdentifier("open-stem-notebook")
```

- [ ] **Step 2: Restrict the account-hiding user script to product hosts**

```javascript
const host = window.location.hostname.toLowerCase();
if (host !== 'ieltsist.com' && !host.endsWith('.ieltsist.com')) return;
```

- [ ] **Step 3: Re-run both UI modes**

Run the student test with `STEMIST_FULL_FEATURE_TEST=NO` and the QA account/deep-link test with `STEMIST_FULL_FEATURE_TEST=YES`.

Expected: both pass; a normal build remains on the root shell after the account deep link, while the QA build presents `web-module-ielts-account`.

### Task 3: Extend Cloud Evidence And Release Documentation

**Files:**
- Modify: `codemagic.yaml`
- Modify: `README.md`
- Modify: `docs/ios-ipad-acceptance-matrix.md`

**Interfaces:**
- Consumes: `StemistShellUITests` and the two `STEMIST_FULL_FEATURE_TEST` build values.
- Produces: two separate UI-test logs plus normal/QA simulator screenshots and a custom-scheme registration smoke-test artifact.

- [ ] **Step 1: Run separate UI test invocations in Codemagic**

```bash
xcodebuild ... STEMIST_FULL_FEATURE_TEST=NO \
  -only-testing:StemistShellUITests/StemistShellUITests/testStudentBuildHidesAccountEntryAndKeepsLearningSpacesNavigable test
xcodebuild ... STEMIST_FULL_FEATURE_TEST=YES \
  -only-testing:StemistShellUITests/StemistShellUITests/testInternalQABuildShowsAccountEntryAndOpensAccountDeepLink test
```

- [ ] **Step 2: Retain the test logs and contract assertions**

Add the logs to workflow artifacts and assert the Xcode/UI-test contract in `scripts/test-navigation-contract.mjs`.

### Task 4: Verify And Publish

**Files:**
- Verify: all files changed in Tasks 1-3

**Interfaces:**
- Consumes: successful cloud test logs, generated screenshots, and the real-device matrix.
- Produces: release documentation that distinguishes automated native-shell proof from pending real-iPad server-backed acceptance.

- [ ] **Step 1: Run local static checks**

Run `node scripts/test-navigation-contract.mjs`, YAML parsing, `git diff --check`, and a filename-only secret-pattern scan.

- [ ] **Step 2: Push and inspect the GitHub Actions run**

Verify that the normal and QA UI-test commands compile, execute, and pass before updating the draft PR evidence.

- [ ] **Step 3: Record only residual device gates**

Keep TestFlight distribution and the authenticated real-iPad matrix as explicit remaining gates; do not claim that simulator WebKit loading proves AI, sign-in, Apple Pencil, microphone, camera, or upload journeys.
