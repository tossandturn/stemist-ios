import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppRouteCoordinator: ObservableObject {
    @Published private(set) var pendingURL: URL?

    func receive(_ url: URL) {
        guard pendingURL != url else { return }
        pendingURL = url
    }

    func peekPendingURL() -> URL? {
        return pendingURL
    }

    func acknowledgePendingURL(_ url: URL) {
        guard pendingURL == url else { return }
        pendingURL = nil
    }
}

@MainActor
final class StemistAppDelegate: NSObject, UIApplicationDelegate {
    let routeCoordinator = AppRouteCoordinator()

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        routeCoordinator.receive(url)
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        connectionOptions.urlContexts.forEach { context in
            routeCoordinator.receive(context.url)
        }

        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        return configuration
    }
}

@main
struct StemistApp: App {
    @UIApplicationDelegateAdaptor(StemistAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(routeCoordinator: appDelegate.routeCoordinator)
                .onOpenURL { url in
                    appDelegate.routeCoordinator.receive(url)
                }
        }
    }
}
