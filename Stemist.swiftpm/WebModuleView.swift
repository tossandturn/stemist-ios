import Foundation
import SwiftUI
import UIKit
import WebKit
import SafariServices
import UniformTypeIdentifiers

private enum WebModuleTiming {
    static let loadTimeoutNanoseconds: UInt64 = 20_000_000_000
}

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

    func stopLoading() {
        webView?.stopLoading()
    }

    func pauseForHiding() {
        guard let webView else { return }

        webView.evaluateJavaScript(
            """
            (() => {
                document.querySelectorAll("audio, video").forEach((media) => {
                    try { media.pause(); } catch (_) {}
                    if (media.srcObject) {
                        media.srcObject.getTracks().forEach((track) => {
                            try { track.stop(); } catch (_) {}
                        });
                    }
                });
            })();
            """,
            completionHandler: nil
        )
    }

    func stopForDismissal() {
        webView?.stopLoading()
        pauseForHiding()
    }
}

enum ProductWebPolicy {
    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        let host = (url.host ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return host == "ieltsist.com" || host.hasSuffix(".ieltsist.com")
    }

    static func isAccountEntry(_ url: URL) -> Bool {
        guard isAllowed(url) else { return false }
        return WebRoute(url: url, allowsAccountEntry: true) == .ieltsAccount
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
    static let websiteDataStore = WKWebsiteDataStore.default()
}

private enum AccountEntryVisibilityScript {
    static let hide = """
    (() => {
        const host = window.location.hostname.toLowerCase();
        if (host !== 'ieltsist.com' && !host.endsWith('.ieltsist.com')) return;
        const styleId = 'stemist-account-entry-visibility';
        const selectors = [
            '#sidebarAccountEntry',
            '.sidebar-account-entry',
            '.account-trigger',
            '[aria-label="Sign in to STEM"]',
            '[data-view="mine"]',
            '[data-home-action="mine"]',
            '[data-stemist-hidden-account-entry="true"]'
        ];
        const interactiveSelector = 'button, a, [role="button"]';
        const markTextAccountControls = (root) => {
            if (!root) return;

            const candidates = [];
            if (root instanceof Element && root.matches(interactiveSelector)) {
                candidates.push(root);
            }
            if (typeof root.querySelectorAll === 'function') {
                root.querySelectorAll(interactiveSelector).forEach((element) => {
                    candidates.push(element);
                });
            }

            candidates.forEach((element) => {
                const text = (element.textContent || '').replace(/\\s+/g, ' ').trim();
                if (text === 'Log in or create account'
                    && !element.hasAttribute('data-stemist-hidden-account-entry')) {
                    element.setAttribute('data-stemist-hidden-account-entry', 'true');
                }
            });
        };
        const installStyle = () => {
            if (!document.getElementById(styleId)) {
                const root = document.head || document.documentElement;
                if (!root) return;
                const style = document.createElement('style');
                style.id = styleId;
                style.textContent = selectors.join(',')
                    + '{display:none !important;visibility:hidden !important;pointer-events:none !important;}';
                root.appendChild(style);
            }
        };
        const pendingRoots = new Set();
        let animationFrameScheduled = false;
        const flushPendingRoots = () => {
            animationFrameScheduled = false;
            pendingRoots.forEach((root) => markTextAccountControls(root));
            pendingRoots.clear();
        };
        const enqueueRoot = (root) => {
            if (!root) return;
            pendingRoots.add(root);
            if (animationFrameScheduled) return;
            animationFrameScheduled = true;
            requestAnimationFrame(flushPendingRoots);
        };
        let started = false;
        const start = () => {
            if (started) return;
            const root = document.documentElement;
            if (!root) return;
            started = true;
            installStyle();
            markTextAccountControls(root);

            const observer = new MutationObserver((records) => {
                records.forEach((record) => {
                    if (record.type === 'characterData') {
                        enqueueRoot(record.target.parentElement);
                        return;
                    }
                    if (record.type === 'attributes') {
                        enqueueRoot(record.target);
                        return;
                    }
                    record.addedNodes.forEach((node) => {
                        if (node.nodeType === Node.ELEMENT_NODE) {
                            enqueueRoot(node);
                        } else {
                            enqueueRoot(record.target);
                        }
                    });
                });
            });
            observer.observe(root, {
                childList: true,
                characterData: true,
                attributes: true,
                attributeFilter: ['aria-label', 'class', 'data-view', 'data-home-action', 'hidden'],
                subtree: true
            });
        };
        document.addEventListener('DOMContentLoaded', start, { once: true });
        start();
    })();
    """
}

private enum CoachAutoOpenScript {
    static let open = """
    (() => {
        const triggerSelectors = [
            '[aria-label="Open AI Coach"]',
            '#globalHelpButton',
            '.ai-coach-trigger'
        ];
        let opened = false;
        let observer;
        let expiryTimer;

        const isVisible = (element) => {
            if (!element || element.disabled) return false;
            const style = window.getComputedStyle(element);
            return style.display !== 'none'
                && style.visibility !== 'hidden'
                && element.getClientRects().length > 0;
        };
        const tryOpen = () => {
            if (opened) return;
            const trigger = triggerSelectors
                .map((selector) => document.querySelector(selector))
                .find(isVisible);
            if (!trigger) return;
            opened = true;
            observer?.disconnect();
            if (expiryTimer) window.clearTimeout(expiryTimer);
            trigger.click();
        };

        const root = document.documentElement;
        if (!root) return;
        observer = new MutationObserver(tryOpen);
        observer.observe(root, { childList: true, subtree: true });
        tryOpen();
        expiryTimer = window.setTimeout(() => observer.disconnect(), 10_000);
    })();
    """
}

struct WebModuleView: View {
    @Environment(\.stemistAllowsAccountEntry) private var allowsAccountEntry
    let route: WebRoute
    let launchURL: URL
    let requestLaunch: (WebRouteLaunch) -> Void
    let dismissWorkspace: () -> Void
    @StateObject private var webViewStore = WebViewStore()
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var reloadToken = UUID()
    @State private var loadWatchdogToken = UUID()
    @State private var currentURL: URL?
    @State private var showsSafari = false

    init(route: WebRoute) {
        self.route = route
        launchURL = route.url
        requestLaunch = { _ in }
        dismissWorkspace = {}
    }

    init(launch: WebRouteLaunch) {
        self.init(launch: launch, requestLaunch: { _ in }, dismissWorkspace: {})
    }

    init(
        launch: WebRouteLaunch,
        requestLaunch: @escaping (WebRouteLaunch) -> Void,
        dismissWorkspace: @escaping () -> Void
    ) {
        route = launch.route
        launchURL = launch.url
        self.requestLaunch = requestLaunch
        self.dismissWorkspace = dismissWorkspace
    }

    private func retryLoading() {
        loadError = nil
        isLoading = true
        reloadToken = UUID()
        loadWatchdogToken = UUID()
    }

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: route.symbol)
                .foregroundStyle(route.tint)
                .accessibilityHidden(true)
            Text(route.title)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 8)

            if allowsAccountEntry, route != .ieltsAccount {
                Button {
                    requestLaunch(WebRouteLaunch(route: .ieltsAccount))
                } label: {
                    Image(systemName: "person.crop.circle")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Open account")
                .accessibilityIdentifier("web-open-account")
                .help("Open account")
            }

            Button {
                webViewStore.pauseForHiding()
                dismissWorkspace()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close \(route.title)")
            .accessibilityIdentifier("web-close")
            .help("Close")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader

            NavigationStack {
                ZStack {
                EmbeddedWebView(
                    url: launchURL,
                    reloadToken: reloadToken,
                    store: webViewStore,
                    isLoading: $isLoading,
                    loadError: $loadError,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    currentURL: $currentURL,
                    allowsAccountEntry: allowsAccountEntry,
                    opensCoachOnLoad: route.opensCoachOnLoad,
                    accessibilityIdentifier: "web-module-\(route.id)",
                    loadWatchdogToken: $loadWatchdogToken
                )

                    if let errorMessage = loadError {
                    ContentUnavailableView {
                        Label("Unable to load \(route.title)", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again", systemImage: "arrow.clockwise") {
                            retryLoading()
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
                        retryLoading()
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
                .sheet(isPresented: $showsSafari) {
                SafariView(url: currentURL ?? launchURL)
                    .ignoresSafeArea()
                }
                .task(id: loadWatchdogToken) {
                do {
                    try await Task.sleep(nanoseconds: WebModuleTiming.loadTimeoutNanoseconds)
                    guard !Task.isCancelled, isLoading else { return }
                    webViewStore.stopLoading()
                    loadError = "The page is taking longer than expected. Check your connection and try again."
                    isLoading = false
                } catch {
                    // Cancellation is expected when the page finishes or the view is dismissed.
                }
                }
                .onDisappear {
                    webViewStore.stopForDismissal()
                }
            }
            .accessibilityIdentifier("web-module-\(route.id)")
        }
        .background(StemistTheme.background)
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
    let allowsAccountEntry: Bool
    let opensCoachOnLoad: Bool
    let accessibilityIdentifier: String
    @Binding var loadWatchdogToken: UUID

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WebViewEnvironment.processPool
        configuration.websiteDataStore = WebViewEnvironment.websiteDataStore
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        if !allowsAccountEntry {
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: AccountEntryVisibilityScript.hide,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )
        }
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
        webView.scrollView.panGestureRecognizer.cancelsTouchesInView = false
        configureInputGestures(for: webView)
        store.webView = webView
        webView.accessibilityIdentifier = accessibilityIdentifier
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
        webView.accessibilityIdentifier = accessibilityIdentifier
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

        private func restartLoadWatchdog() {
            parent.loadWatchdogToken = UUID()
        }

        private func openCoachIfRequested(in webView: WKWebView) {
            guard parent.opensCoachOnLoad else { return }
            webView.evaluateJavaScript(
                CoachAutoOpenScript.open,
                completionHandler: nil
            )
        }

        func load(_ url: URL, in webView: WKWebView) {
            requestedURL = url
            lastReloadToken = parent.reloadToken
            hasRetriedAfterTermination = false
            parent.isLoading = true
            parent.loadError = nil
            parent.currentURL = url
            restartLoadWatchdog()
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
            hasRetriedAfterTermination = false
            parent.isLoading = true
            parent.loadError = nil
            restartLoadWatchdog()
            webView.reload()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
            restartLoadWatchdog()
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
            openCoachIfRequested(in: webView)
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
            restartLoadWatchdog()
            webView.reload()
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let targetURL = navigationAction.request.url else { return nil }

            if !parent.allowsAccountEntry && ProductWebPolicy.isAccountEntry(targetURL) {
                return nil
            }

            if ProductWebPolicy.isAllowed(targetURL)
                || ExternalWebPolicy.canKeepAuthenticationRedirect(targetURL, from: webView.url) {
                webView.load(navigationAction.request)
            } else if ExternalWebPolicy.canOpen(targetURL) {
                UIApplication.shared.open(targetURL, options: [:])
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            presentJavaScriptDialog(from: webView) { presenter in
                let alert = UIAlertController(
                    title: "Message from \(frame.securityOrigin.host)",
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler()
                })
                presenter.present(alert, animated: true)
            } onUnavailable: {
                completionHandler()
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            presentJavaScriptDialog(from: webView) { presenter in
                let alert = UIAlertController(
                    title: "Confirm from \(frame.securityOrigin.host)",
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    completionHandler(false)
                })
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler(true)
                })
                presenter.present(alert, animated: true)
            } onUnavailable: {
                completionHandler(false)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            presentJavaScriptDialog(from: webView) { presenter in
                let alert = UIAlertController(
                    title: "Input requested by \(frame.securityOrigin.host)",
                    message: prompt,
                    preferredStyle: .alert
                )
                alert.addTextField { textField in
                    textField.text = defaultText
                }
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    completionHandler(nil)
                })
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler(alert.textFields?.first?.text)
                })
                presenter.present(alert, animated: true)
            } onUnavailable: {
                completionHandler(nil)
            }
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

        private func presentJavaScriptDialog(
            from webView: WKWebView,
            present: @escaping (UIViewController) -> Void,
            onUnavailable: @escaping () -> Void
        ) {
            guard let presenter = presentingViewController(for: webView),
                  presenter.viewIfLoaded?.window != nil,
                  !(presenter is UIAlertController),
                  !(presenter is UIDocumentPickerViewController) else {
                onUnavailable()
                return
            }

            present(presenter)
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

            if !parent.allowsAccountEntry && ProductWebPolicy.isAccountEntry(targetURL) {
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
