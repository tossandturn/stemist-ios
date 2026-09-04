# Stemist iOS

The native iOS/iPadOS entry point for the unified IELTSist and STEM learning product.

## Project structure

- `Stemist.swiftpm`: Swift Playground application package. Open it in Swift Playground on iPad or Xcode on macOS.
- `codemagic.yaml`: unsigned iOS Simulator validation workflow for Codemagic.
- `scripts/test-navigation-contract.mjs`: platform-independent regression checks for module deep links, shared SSO WebKit state, and external-link handling.

Swift Playgrounds metadata caches are intentionally not versioned. If an older iPad copy still shows a previous app name or capability list, close the playground, remove its local cached manifest, and reopen the package so it is regenerated from `Stemist.swiftpm/Package.swift`.

The app currently provides a native tab shell and deliberately loads the existing public product surfaces through a controlled `WKWebView`. Authentication, AI marking, and subscriptions remain server-backed integrations and must not place credentials in this repository. On iPad, interactive handwriting surfaces opt into a native PencilKit capture layer for low-latency Pencil rendering; the resulting stroke is handed back to the web ink model so autosave, undo/redo, evidence storage and AI marking remain unchanged. Pages without an explicit interactive ink surface continue to use the WebView input path. Product `Take photo` controls use a native camera bridge: on iOS versions where WebKit cannot customise its upload panel, the bridge prevents the Files picker, captures a bounded JPEG, and dispatches it back to the originating web input so the existing upload/AI pipeline is reused.

## Account visibility and full-function testing

The native account/profile entry is hidden in normal builds so students start in the learning surfaces. The account route and server authentication are still present; hiding the tab does not bypass, replace, or weaken authentication.

Normal-mode WebViews also hide the known account controls rendered by IELTSist and STEM (including the guest/sign-in buttons and dashboard account action). This is presentation-only convenience, not an authorization boundary; the backend still owns every session and permission decision. The full-function test switch leaves those controls visible so login, registration, SSO and account recovery can be exercised end to end.

For an explicit QA run, launch the app with either the `-stemist-full-feature-test` launch argument or `STEMIST_FULL_FEATURE_TEST=1`. This only reveals the Profile tab and account route for testing. It does not create a session, seed credentials, or grant access to another account. Keep the switch out of student-facing release launch configurations.

Product deep links resolve to a typed route and retain only safe study context, including `contractVersion`, curriculum route/stage/topic, vocabulary term IDs, attempt ID and an approved IELTSist return link. OAuth callbacks, tokens, session identifiers, passwords, arbitrary query values and off-product return targets are never forwarded into the WebView.

The full-function route matrix is:

- IELTS: Listening, Reading, Writing upload, Speaking microphone flow, Vocabulary, and Account.
- STEM: Today, IG, AS, A2, Topics, Past papers, Notebook, and STEM Coach.
- Shared AI: the IELTSist AI Coach chat surface (`https://ieltsist.com/#ai-coach`), persistent WebKit cookies, same-session navigation, and safe external-link handling. The `ai.ieltsist.com` API console is a server-side operations surface and is not presented as the student chat.

For each route, verify loading, back/forward, reload, iPad portrait and landscape layout, keyboard focus, Apple Pencil/canvas input where the web surface supports it, upload cancellation and success, media permission prompts, autosave/restore, submit/result states, and a recoverable network or web-content-process failure. Use a test account and test data only.

When a product page opens a JavaScript alert, confirm or prompt, the shell presents a native iPad dialog and always returns a completion result. This prevents embedded account, upload and practice flows from being stalled by a browser-only dialog.

## First cloud build

1. Connect this repository in Codemagic.
2. Select the `ios-simulator` workflow from `codemagic.yaml`.
3. Run the unsigned Simulator build.
4. Add Apple Developer signing and TestFlight publishing only after the native bundle identifier and App Store Connect record are ready.

The Windows checkout cannot compile Swift locally. A successful Codemagic `xcodebuild` step and its generated app metadata check are required before treating the iOS package as buildable.

Both cloud workflows create two disposable iPad Simulator builds: a normal student build and an internal QA build with the bundle setting `STEMIST_FULL_FEATURE_TEST=YES`. They install and launch both, retain screenshots, then request the otherwise hidden account custom scheme from the QA app. iOS presents its own "Open in Stemist?" confirmation, which is retained as scheme-registration evidence rather than misreported as a completed account journey. The tester completes that confirmation and the authenticated, Apple Pencil, camera, microphone, upload and AI journeys on a real iPad using the [acceptance matrix](docs/ios-ipad-acceptance-matrix.md).

The package deployment target is iPadOS/iOS 17.0 or newer. The native shell keeps the account tab hidden in student mode, while the existing web authentication remains available inside product flows.

## Local contract check

```text
node scripts/test-navigation-contract.mjs
```

The app keeps IELTSist product subdomains inside the shared WebView so an authenticated student can move between IELTS, STEM and AI without losing the product session. Non-product links are handed to Safari.
stemist-ios
