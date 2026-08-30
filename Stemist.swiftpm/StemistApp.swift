import Foundation
import SwiftUI

@MainActor
final class AppRouteCoordinator: ObservableObject {
    @Published private(set) var pendingURL: URL?

    func receive(_ url: URL) {
        pendingURL = url
    }

    func takePendingURL() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
    }
}

@main
struct StemistApp: App {
    @StateObject private var routeCoordinator = AppRouteCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView(routeCoordinator: routeCoordinator)
                .onOpenURL { url in
                    routeCoordinator.receive(url)
                }
        }
    }
}
