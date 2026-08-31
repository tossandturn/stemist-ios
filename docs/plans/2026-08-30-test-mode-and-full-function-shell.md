# Stemist Test Mode and Full-Function Shell Implementation Plan

> **For implementer:** Use TDD throughout. Write failing test first. Watch it fail. Then implement.

**Goal:** Keep the account route and server authentication intact while hiding its visible entry by default, exposing it only for explicit full-function test runs, and hardening the iOS web shell for realistic IELTSist/STEM journeys.

**Architecture:** Add a small runtime configuration that reads a dedicated launch argument or environment value without changing authentication. Route all app deep links through the existing typed `WebRoute` model, and keep product pages in one shared persistent `WKWebView` data store. Codemagic remains the authoritative Swift compiler because the Windows host has no Xcode toolchain.

**Tech Stack:** SwiftUI, WebKit, Swift Package Manager iOS application product, Node contract tests, Codemagic.

---

### Task 1: Test-only account visibility contract

**Files:**
- Create: `Stemist.swiftpm/AppRuntimeConfiguration.swift`
- Modify: `Stemist.swiftpm/ContentView.swift`
- Modify: `scripts/test-navigation-contract.mjs`

1. Add failing assertions for default-hidden account UI, explicit full-feature test activation, and retention of the `ieltsAccount` route.
2. Run `node scripts/test-navigation-contract.mjs` and confirm the new assertions fail.
3. Implement the runtime configuration and conditional account entry.
4. Re-run the contract and confirm it passes.

### Task 2: Deep-link and route testability

**Files:**
- Modify: `Stemist.swiftpm/ContentView.swift`
- Modify: `Stemist.swiftpm/StemistApp.swift`
- Modify: `scripts/test-navigation-contract.mjs`

1. Add failing assertions for a typed app deep-link parser and stable accessibility identifiers.
2. Implement `stemist://open/<route-id>` handling at the root app level.
3. Verify account and every learning route can be opened without bypassing web authentication.

### Task 3: WebView full-function behavior

**Files:**
- Modify: `Stemist.swiftpm/WebModuleView.swift`
- Modify: `scripts/test-navigation-contract.mjs`

1. Add failing assertions for persistent website data, product-only media permissions, web content process recovery, and file-picker support.
2. Implement the smallest WebKit changes required for writing uploads, speaking microphone prompts, AI pages, and resilient reload behavior.
3. Re-run the contract suite.

### Task 4: Cloud compilation and release evidence

**Files:**
- Modify: `codemagic.yaml`
- Modify: `README.md`

1. Run all local contract checks, YAML parsing, `git diff --check`, and secret-pattern review.
2. Push the existing feature branch and inspect the new Codemagic check suite.
3. Treat only a completed `xcodebuild` run as compile evidence; queued suites are not success.
