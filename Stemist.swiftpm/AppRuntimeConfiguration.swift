import Foundation
import SwiftUI

private struct StemistAllowsAccountEntryKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var stemistAllowsAccountEntry: Bool {
        get { self[StemistAllowsAccountEntryKey.self] }
        set { self[StemistAllowsAccountEntryKey.self] = newValue }
    }
}

struct AppRuntimeConfiguration: Equatable {
    static let fullFeatureTestArgument = "-stemist-full-feature-test"
    static let fullFeatureTestEnvironmentKey = "STEMIST_FULL_FEATURE_TEST"
    static let fullFeatureTestInfoKey = "STEMIST_FULL_FEATURE_TEST"

    let isFullFeatureTest: Bool

    var showsAccountEntry: Bool {
        isFullFeatureTest
    }

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        #if DEBUG
        let environmentValue = environment[Self.fullFeatureTestEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        #else
        // Release/student artifacts may not be switched into QA mode by a
        // process environment value. The signed Info.plist flag is reserved
        // for an explicitly produced internal QA artifact.
        let environmentValue: String? = nil
        #endif
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: Self.fullFeatureTestInfoKey)
            .map { String(describing: $0) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let enabledValues = Set(["1", "true", "yes"])

        isFullFeatureTest = arguments.contains(Self.fullFeatureTestArgument)
            || environmentValue.map(enabledValues.contains) == true
            || bundleValue.map(enabledValues.contains) == true
    }

    static let current = AppRuntimeConfiguration()
}
