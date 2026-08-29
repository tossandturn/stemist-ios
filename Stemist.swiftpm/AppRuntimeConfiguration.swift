import Foundation

struct AppRuntimeConfiguration: Equatable {
    static let fullFeatureTestArgument = "-stemist-full-feature-test"
    static let fullFeatureTestEnvironmentKey = "STEMIST_FULL_FEATURE_TEST"

    let isFullFeatureTest: Bool

    var showsAccountEntry: Bool {
        isFullFeatureTest
    }

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let environmentValue = environment[Self.fullFeatureTestEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let enabledValues = Set(["1", "true", "yes"])

        isFullFeatureTest = arguments.contains(Self.fullFeatureTestArgument)
            || environmentValue.map(enabledValues.contains) == true
    }

    static let current = AppRuntimeConfiguration()
}
