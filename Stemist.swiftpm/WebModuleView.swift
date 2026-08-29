import SwiftUI
import UIKit
import WebKit
import SafariServices

struct WebModuleView: View {
    @Environment(\.dismiss) private var dismiss
    let destination: WebDestination
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var reloadToken = UUID()
    @State private var showsSafari = false

    var body: some View {
        NavigationStack {
            ZStack {
                EmbeddedWebView(
                    url: destination.url,
                    reloadToken: reloadToken,
                    isLoading: $isLoading,
                    loadError: $loadError,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward
                )

                if let loadError {
                    ContentUnavailableView {
                        Label("Unable to load \(destination.title)", systemImage: "wifi.exclamationmark")
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
                        NotificationCenter.default.post(name: .stemistWebGoBack, object: nil)
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Back")

                    Button {
                        NotificationCenter.default.post(name: .stemistWebGoForward, object: nil)
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
                    .accessibilityLabel("Open in Safari")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close \(destination.title)")
                }
            }
            .sheet(isPresented: $showsSafari) {
                SafariView(url: destination.url)
                    .ignoresSafeArea()
            }
        }
    }
}

struct EmbeddedWebView: UIViewRepresentable {
    let url: URL
    let reloadToken: UUID
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.navigationDelegate = context.coordinator
        webView.allowsLinkPreview = false
        context.coordinator.load(url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateNavigationState(webView)
        guard context.coordinator.lastLoadedURL != url else { return }
        context.coordinator.load(url, in: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EmbeddedWebView
        var lastLoadedURL: URL?
        var lastReloadToken: UUID?
        weak var webView: WKWebView?

        init(parent: EmbeddedWebView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(goBack), name: .stemistWebGoBack, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(goForward), name: .stemistWebGoForward, object: nil)
        }

        func load(_ url: URL, in webView: WKWebView) {
            self.webView = webView
            lastLoadedURL = url
            lastReloadToken = parent.reloadToken
            parent.isLoading = true
            parent.loadError = nil
            webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
        }

        func updateNavigationState(_ webView: WKWebView) {
            self.webView = webView
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
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
            // Keep product pages in the app. External destinations open in Safari
            // so authentication and payment providers retain their supported flow.
            if (targetURL.scheme == "https" || targetURL.scheme == "http") && targetURL.host == parent.url.host {
                decisionHandler(.allow)
            } else {
                UIApplication.shared.open(targetURL)
                decisionHandler(.cancel)
            }
        }

        @objc private func goBack() {
            guard let webView, webView.canGoBack else { return }
            webView.goBack()
        }

        @objc private func goForward() {
            guard let webView, webView.canGoForward else { return }
            webView.goForward()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
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

extension Notification.Name {
    static let stemistWebGoBack = Notification.Name("stemistWebGoBack")
    static let stemistWebGoForward = Notification.Name("stemistWebGoForward")
}
