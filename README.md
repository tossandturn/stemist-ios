# Stemist iOS

The native iOS/iPadOS entry point for the unified IELTSist and STEM learning product.

## Project structure

- `Stemist.swiftpm`: Swift Playground application package. Open it in Swift Playground on iPad or Xcode on macOS.
- `codemagic.yaml`: unsigned iOS Simulator validation workflow for Codemagic.

The app currently provides a native tab shell and deliberately loads the existing public product surfaces through a controlled `WKWebView`. Authentication, AI marking, Apple Pencil capture, and subscriptions remain server-backed integrations and must not place credentials in this repository.

## First cloud build

1. Connect this repository in Codemagic.
2. Select the `ios-simulator` workflow from `codemagic.yaml`.
3. Run the unsigned Simulator build.
4. Add Apple Developer signing and TestFlight publishing only after the native bundle identifier and App Store Connect record are ready.
stemist-ios
