import Foundation
import SwiftUI
import UIKit
import WebKit
import SafariServices
import UniformTypeIdentifiers

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

enum ExternalWebPolicy {
    private static let allowedSchemes: Set<String> = ["http", "https", "mailto", "tel", "itms-apps"]
    private static let authenticationRedirectHosts: Set<String> = [
        "accounts.google.com",
        "appleid.apple.com",
        "login.microsoftonline.com",
    ]

    static func canOpen(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return allowedSchemes.contains(scheme)
    }

    static func canKeepAuthenticationRedirect(
        _ url: URL,
        from sourceURL: URL?
    ) -> Bool {
        guard let sourceURL,
              (ProductWebPolicy.isAllowed(sourceURL) || isAllowedAuthenticationHost(sourceURL)),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else {
            return false
        }

        return isAllowedAuthenticationHost(host)
    }

    private static func isAllowedAuthenticationHost(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else {
            return false
        }
        return isAllowedAuthenticationHost(host)
    }

    private static func isAllowedAuthenticationHost(_ host: String) -> Bool {
        authenticationRedirectHosts.contains(host)
            || host == "auth.ieltsist.com"
            || host.hasSuffix(".auth.ieltsist.com")
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

                if let errorMessage = loadError {
                    ContentUnavailableView {
                        Label("Unable to load \(route.title)", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again", systemImage: "arrow.clockwise") {
                            loadError = nil
                            isLoading = true
                            reloadToken = UUID()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("web-retry")
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 18) {
                    Button {
                        webViewStore.goBack()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("web-back")

                    Button {
                        webViewStore.goForward()
                    } label: {
                        Image(systemName: "chevron.forward")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canGoForward)
                    .accessibilityLabel("Forward")
                    .accessibilityIdentifier("web-forward")

                    Spacer()

                    Button {
                        reloadToken = UUID()
                        loadError = nil
                        isLoading = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Reload")
                    .accessibilityIdentifier("web-reload")

                    Button {
                        showsSafari = true
                    } label: {
                        Image(systemName: "safari")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Open current page in Safari")
                    .accessibilityIdentifier("web-safari")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .navigationTitle(route.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close \(route.title)")
                    .accessibilityIdentifier("web-close")
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
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsLinkPreview = false
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.delaysContentTouches = false
        webView.scrollView.keyboardDismissMode = .interactive
        configureInputGestures(for: webView)
        store.webView = webView
        context.coordinator.load(url, in: webView)
        return webView
    }

    private func configureInputGestures(for webView: WKWebView) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }

        // Keep finger and pointer scrolling, while leaving stylus touches for web canvases.
        webView.scrollView.panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.indirectPointer.rawValue),
        ]
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

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIDocumentPickerDelegate {
        var parent: EmbeddedWebView
        var store: WebViewStore
        var requestedURL: URL?
        var lastReloadToken: UUID?
        var fileUploadCompletion: (([URL]?) -> Void)?
        var hasRetriedAfterTermination = false

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
            hasRetriedAfterTermination = false
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

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard !hasRetriedAfterTermination else {
                parent.isLoading = false
                parent.loadError = "The page stopped unexpectedly. Tap Reload to continue."
                updateNavigationState(webView)
                return
            }

            hasRetriedAfterTermination = true
            parent.isLoading = true
            parent.loadError = nil
            webView.reload()
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let targetURL = navigationAction.request.url else { return nil }

            if ProductWebPolicy.isAllowed(targetURL) {
                webView.load(navigationAction.request)
            } else if ExternalWebPolicy.canOpen(targetURL) {
                UIApplication.shared.open(targetURL, options: [:])
            }
            return nil
        }

#if compiler(>=6.0)
        @available(iOS 18.4, *)
        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            fileUploadCompletion?(nil)
            fileUploadCompletion = completionHandler

            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [
                    UTType.item,
                    UTType.pdf,
                    UTType.plainText,
                    UTType.data,
                    UTType.image,
                    UTType.audio,
                    UTType.movie,
                ],
                asCopy: true
            )
            picker.allowsMultipleSelection = parameters.allowsMultipleSelection
            picker.delegate = self

            guard let presenter = presentingViewController(for: webView) else {
                finishFileUpload(with: nil)
                return
            }

            if let popover = picker.popoverPresentationController {
                popover.sourceView = webView
                popover.sourceRect = CGRect(
                    x: webView.bounds.midX,
                    y: webView.bounds.midY,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
            }
            presenter.present(picker, animated: true)
        }
#endif

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            finishFileUpload(with: urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finishFileUpload(with: nil)
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            guard let originURL = URL(string: "\(origin.protocol)://\(origin.host)"),
                  ProductWebPolicy.isAllowed(originURL) else {
                decisionHandler(.deny)
                return
            }

            decisionHandler(.prompt)
        }

        private func finishFileUpload(with urls: [URL]?) {
            let completion = fileUploadCompletion
            fileUploadCompletion = nil
            completion?(urls)
        }

        private func presentingViewController(for view: UIView) -> UIViewController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let viewController = current as? UIViewController {
                    var presenter = viewController
                    while let presented = presenter.presentedViewController {
                        presenter = presented
                    }
                    return presenter
                }
                responder = current.next
            }

            guard let rootViewController = view.window?.rootViewController else { return nil }
            var presenter = rootViewController
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            return presenter
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

            if ExternalWebPolicy.canKeepAuthenticationRedirect(targetURL, from: webView.url) {
                decisionHandler(.allow)
                return
            }

            guard ExternalWebPolicy.canOpen(targetURL) else {
                decisionHandler(.cancel)
                return
            }

            UIApplication.shared.open(targetURL, options: [:])
            decisionHandler(.cancel)
        }

        deinit {
            fileUploadCompletion?(nil)
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
