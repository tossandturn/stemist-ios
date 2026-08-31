import Foundation
import SwiftUI
import UIKit

#if DEBUG
import os
#endif

@MainActor
final class AppRouteCoordinator: ObservableObject {
    static let shared = AppRouteCoordinator()

    @Published private(set) var pendingURL: URL?

    #if DEBUG
    @Published private(set) var debugSnapshot = "0 init"
    private var debugSequence = 0
    private let debugLog = Logger(subsystem: "com.ieltsist.stemist", category: "routing")
    #endif

    private var lastAcknowledgedURL: URL?
    private var lastAcknowledgedAt: Date?
    private static let duplicateSuppressionInterval: TimeInterval = 2

    #if DEBUG
    private func record(_ event: String, url: URL? = nil) {
        debugSequence += 1
        let location = url.map { "\($0.scheme ?? "")://\($0.host ?? "")\($0.path)" } ?? "-"
        debugSnapshot = "\(debugSequence) \(event) \(location) pending=\(pendingURL != nil)"
        debugLog.debug("\(self.debugSnapshot, privacy: .public)")
        print("[StemistRouting] \(debugSnapshot)")
    }
    #else
    private func record(_ event: String, url: URL? = nil) {}
    #endif

    func observeLifecycle(_ source: String, urlCount: Int) {
        record("lifecycle[\(source)] count=\(urlCount)")
    }

    func receive(_ url: URL, source: String = "unknown") {
        record("receive[\(source)]", url: url)
        guard pendingURL != url else { return }

        if let lastAcknowledgedURL,
           lastAcknowledgedURL == url,
           let lastAcknowledgedAt,
           Date().timeIntervalSince(lastAcknowledgedAt)
             < Self.duplicateSuppressionInterval {
            return
        }

        pendingURL = url
        record("pending[\(source)]", url: url)
    }

    func peekPendingURL() -> URL? {
        return pendingURL
    }

    func acknowledgePendingURL(_ url: URL) {
        guard pendingURL == url else { return }
        pendingURL = nil
        lastAcknowledgedURL = url
        lastAcknowledgedAt = Date()
        record("acknowledged", url: url)
    }
}

@MainActor
final class StemistAppDelegate: NSObject, UIApplicationDelegate {
    let routeCoordinator = AppRouteCoordinator.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let launchURL = launchOptions?[.url] as? URL
        routeCoordinator.observeLifecycle(
            "appDelegate.didFinishLaunching",
            urlCount: launchURL == nil ? 0 : 1
        )
        if let url = launchURL {
            routeCoordinator.receive(url, source: "appDelegate.didFinishLaunching")
        }
        return true
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        routeCoordinator.receive(url, source: "appDelegate.openURL")
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        routeCoordinator.observeLifecycle(
            "appDelegate.configurationForConnecting",
            urlCount: connectionOptions.urlContexts.count
        )
        connectionOptions.urlContexts.forEach { context in
            routeCoordinator.receive(
                context.url,
                source: "appDelegate.configurationForConnecting"
            )
        }

        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = StemistSceneDelegate.self
        return configuration
    }
}

@MainActor
final class StemistSceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var routeCoordinator: AppRouteCoordinator {
        AppRouteCoordinator.shared
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        receive(connectionOptions.urlContexts, source: "scene.willConnectTo")
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        receive(URLContexts, source: "scene.openURLContexts")
    }

    private func receive(_ contexts: Set<UIOpenURLContext>, source: String) {
        routeCoordinator.observeLifecycle(source, urlCount: contexts.count)
        contexts.forEach { context in
            routeCoordinator.receive(context.url, source: source)
        }
    }
}

@main
struct StemistApp: App {
    @UIApplicationDelegateAdaptor(StemistAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(routeCoordinator: appDelegate.routeCoordinator)
                .onOpenURL { url in
                    appDelegate.routeCoordinator.receive(url, source: "swiftui.onOpenURL")
                }
        }
    }
}
