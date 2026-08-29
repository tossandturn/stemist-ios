import Foundation
import SwiftUI
import UIKit
import WebKit
import SafariServices

final class WebViewStore: ObservableObject {
    weak var webView: WKWebView?

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }
}

enum ProductWebPolicy {
    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        let host = (url.host ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return host == "ieltsist.com" || host.hasSuffix(".ieltsist.com")
    }
}

enum WebViewEnvironment {
    static let processPool = WKProcessPool()
}

struct WebModuleView: View {
    @Environment(\.dismiss) private var dismiss
    let route: WebRoute
    @StateObject private var webViewStore = WebViewStore()
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var reloadToken = UUID()
    @State private var currentURL: URL?
    @State private var showsSafari = false

    var body: some View {
        NavigationStack {
            ZStack {
                EmbeddedWebView(
                    url: route.url,
                    reloadToken: reloadToken,
                    store: webViewStore,
                    isLoading: $isLoading,
                    loadError: $loadError,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    currentURL: $currentURL
                )

                if let loadError {
                    ContentUnavailableView {
                        Label("Unable to load \(route.title)", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button("Try again", systemImage: "arrow.clockwise") {
                            loadError = nil
                            isLoading = true
                            reloadToken = UUID()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(20)
                } else if isLoading {
                    ProgressView("Loading...")
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 18) {
                    Button {
                        webViewStore.goBack()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Back")

                    Button {
                        webViewStore.goForward()
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .disabled(!canGoForward)
                    .accessibilityLabel("Forward")

                    Spacer()

                    Button {
                        reloadToken = UUID()
                        loadError = nil
                        isLoading = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Reload")

                    Button {
                        showsSafari = true
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel("Open current page in Safari")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(route.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close \(route.title)")
                }
            }
            .sheet(isPresented: $showsSafari) {
                SafariView(url: currentURL ?? route.url)
                    .ignoresSafeArea()
            }
        }
    }
}

struct EmbeddedWebView: UIViewRepresentable {
    let url: URL
    let reloadToken: UUID
    let store: WebViewStore
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var currentURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WebViewEnvironment.processPool
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.navigationDelegate = context.coordinator
        webView.allowsLinkPreview = false
        webView.scrollView.keyboardDismissMode = .interactive
        store.webView = webView
        context.coordinator.load(url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.store = store
        context.coordinator.updateNavigationState(webView)
        guard context.coordinator.requestedURL != url else { return }
        context.coordinator.load(url, in: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, store: store)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EmbeddedWebView
        var store: WebViewStore
        var requestedURL: URL?
        var lastReloadToken: UUID?

        init(parent: EmbeddedWebView, store: WebViewStore) {
            self.parent = parent
            self.store = store
            super.init()
        }

        func load(_ url: URL, in webView: WKWebView) {
            requestedURL = url
            lastReloadToken = parent.reloadToken
            parent.isLoading = true
            parent.loadError = nil
            parent.currentURL = url
            store.webView = webView
            webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
        }

        func updateNavigationState(_ webView: WKWebView) {
            store.webView = webView
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            parent.currentURL = webView.url ?? parent.currentURL
            guard lastReloadToken != parent.reloadToken else { return }
            lastReloadToken = parent.reloadToken
            parent.isLoading = true
            parent.loadError = nil
            webView.reload()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.loadError = nil
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishWithError(webView, error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finishWithError(webView, error: error)
        }

        private func finishWithError(_ webView: WKWebView, error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            parent.isLoading = false
            parent.loadError = "Check your connection and try again."
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if ProductWebPolicy.isAllowed(targetURL) {
                if navigationAction.targetFrame == nil {
                    webView.load(navigationAction.request)
                    decisionHandler(.cancel)
                } else {
                    decisionHandler(.allow)
                }
                return
            }

            UIApplication.shared.open(targetURL, options: [:])
            decisionHandler(.cancel)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
