# Stemist iOS

The native iOS/iPadOS entry point for the unified IELTSist and STEM learning product.

## Project structure

- `Stemist.swiftpm`: Swift Playground application package. Open it in Swift Playground on iPad or Xcode on macOS.
- `codemagic.yaml`: unsigned iOS Simulator validation workflow for Codemagic.
- `scripts/test-navigation-contract.mjs`: platform-independent regression checks for module deep links, shared SSO WebKit state, and external-link handling.

The app currently provides a native tab shell and deliberately loads the existing public product surfaces through a controlled `WKWebView`. Authentication, AI marking, Apple Pencil capture, and subscriptions remain server-backed integrations and must not place credentials in this repository.

## Account visibility and full-function testing

The native account/profile entry is hidden in normal builds so students start in the learning surfaces. The account route and server authentication are still present; hiding the tab does not bypass, replace, or weaken authentication.

For an explicit QA run, launch the app with either the `-stemist-full-feature-test` launch argument or `STEMIST_FULL_FEATURE_TEST=1`. This only reveals the Profile tab and account route for testing. It does not create a session, seed credentials, or grant access to another account. Keep the switch out of student-facing release launch configurations.

The full-function route matrix is:

- IELTS: Listening, Reading, Writing upload, Speaking microphone flow, Vocabulary, and Account.
- STEM: Today, IG, AS, A2, Topics, Past papers, Notebook, and STEM Coach.
- Shared AI: the AI Coach page, persistent WebKit cookies, same-session navigation, and safe external-link handling.

For each route, verify loading, back/forward, reload, iPad portrait and landscape layout, keyboard focus, Apple Pencil/canvas input where the web surface supports it, upload cancellation and success, media permission prompts, autosave/restore, submit/result states, and a recoverable network or web-content-process failure. Use a test account and test data only.

## First cloud build

1. Connect this repository in Codemagic.
2. Select the `ios-simulator` workflow from `codemagic.yaml`.
3. Run the unsigned Simulator build.
4. Add Apple Developer signing and TestFlight publishing only after the native bundle identifier and App Store Connect record are ready.

The Windows checkout cannot compile Swift locally. A successful Codemagic `xcodebuild` step and its generated app metadata check are required before treating the iOS package as buildable.

## Local contract check

```text
node scripts/test-navigation-contract.mjs
```

The app keeps IELTSist product subdomains inside the shared WebView so an authenticated student can move between IELTS, STEM and AI without losing the product session. Non-product links are handed to Safari.
stemist-ios
