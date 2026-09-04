import Foundation
import SwiftUI
import UIKit
import AVFoundation
import PencilKit
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
        webView?.configuration.preferences.isTextInteractionEnabled = true
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

private enum PenInputBehaviorScript {
    static let handlerName = "stemistPenInput"

    static let install = """
    (() => {
        const host = window.location.hostname.toLowerCase();
        if (host !== 'ieltsist.com' && !host.endsWith('.ieltsist.com')) return;
        const handler = window.webkit?.messageHandlers?.stemistPenInput;
        // Never match every canvas here. PDF.js renders the question paper
        // into a normal canvas; setting touch-action:none on that base layer
        // prevents a finger from panning the surrounding PDF scroller.
        const drawingSelector = [
            '[data-ink-surface="handwriting"][data-ink-interactive="true"]',
            '[data-ink-surface="pdf"][data-ink-interactive="true"]',
            'canvas[data-drawing-surface][data-ink-interactive="true"]',
            'canvas[data-handwriting-canvas][data-ink-interactive="true"]',
            'canvas[data-answer-canvas][data-ink-interactive="true"]',
            'canvas[data-input-mode="handwrite"][data-ink-interactive="true"]',
            'canvas.handwriting-pad__canvas[data-ink-interactive="true"]',
            'canvas.pdf-ink-layer[data-ink-interactive="true"]'
        ].join(',');
        const scrollSelector = '.pdf-canvas-scroll, [data-pdf-scroll]';
        const activePenPointers = new Set();
        const styleId = 'stemist-pen-input-behavior';
        const drawingTarget = (target) => {
            if (!(target instanceof Element)) return null;
            return target.closest(drawingSelector);
        };
        const installStyle = () => {
            if (document.getElementById(styleId)) return;
            const root = document.head || document.documentElement;
            if (!root) return;
            const style = document.createElement('style');
            style.id = styleId;
            style.textContent = `${drawingSelector} {\\n`
                + '  -webkit-user-select: none !important;\\n'
                + '  user-select: none !important;\\n'
                + '  -webkit-touch-callout: none !important;\\n'
                + '  touch-action: none !important;\\n'
                + '}\\n'
                // Explicitly restore native finger/trackpad panning for the
                // PDF container while keeping its ink layer pointer-safe.
                + `${scrollSelector} {\\n`
                + '  touch-action: pan-x pan-y pinch-zoom !important;\\n'
                + '  -webkit-overflow-scrolling: touch !important;\\n'
                + '}';
            root.appendChild(style);
        };
        const blockSelection = (event) => {
            if (drawingTarget(event.target) || activePenPointers.size) event.preventDefault();
        };
        const notifyPenActivity = (active) => {
            try { handler?.postMessage({ active }); } catch (_) {}
        };
        const capturePen = (event) => {
            if (event.pointerType !== 'pen') return;
            activePenPointers.add(event.pointerId);
            const target = drawingTarget(event.target);
            if (!target || typeof target.setPointerCapture !== 'function') return;
            notifyPenActivity(true);
            try { target.setPointerCapture(event.pointerId); } catch (_) {}
        };
        const releasePen = (event) => {
            if (event.pointerType !== 'pen') return;
            activePenPointers.delete(event.pointerId);
            if (!activePenPointers.size) notifyPenActivity(false);
        };
        const clearPenSelection = () => {
            if (!activePenPointers.size) return;
            try { window.getSelection?.()?.removeAllRanges(); } catch (_) {}
        };
        // WKWebView may still create the blue iPad text-selection handles on
        // surrounding labels while a student is writing. Clear selections from
        // read-only page content, but keep native text selection intact in
        // answer inputs and other editable controls for accessibility.
        const isEditableTarget = (node) => {
            const element = node instanceof Element ? node : node?.parentElement;
            return Boolean(element?.closest(
                'input, textarea, [contenteditable=""], [contenteditable="true"], [contenteditable="plaintext-only"], [role="textbox"]'
            ));
        };
        const clearReadOnlySelection = () => {
            const selection = window.getSelection?.();
            if (!selection || selection.isCollapsed) return;
            if (isEditableTarget(selection.anchorNode) || isEditableTarget(selection.focusNode)) return;
            try { selection.removeAllRanges(); } catch (_) {}
        };

        const observeDocument = () => {
            const root = document.documentElement;
            if (!root) return;
            installStyle();
            new MutationObserver(installStyle).observe(root, {
                childList: true,
                subtree: true
            });
        };

        installStyle();
        document.addEventListener('selectstart', blockSelection, true);
        document.addEventListener('contextmenu', blockSelection, true);
        document.addEventListener('dragstart', blockSelection, true);
        document.addEventListener('pointerdown', capturePen, true);
        document.addEventListener('pointerup', releasePen, true);
        document.addEventListener('pointercancel', releasePen, true);
        document.addEventListener('selectionchange', clearPenSelection, true);
        document.addEventListener('selectionchange', clearReadOnlySelection, true);
        if (document.documentElement) {
            observeDocument();
        } else {
            document.addEventListener('DOMContentLoaded', observeDocument, { once: true });
        }
    })();
    """
}

private enum NativePencilSurfaceScript {
    static let handlerName = "stemistPencilSurface"

    static let observe = """
    (() => {
        const handler = window.webkit?.messageHandlers?.stemistPencilSurface;
        if (!handler) return;
        // Fail closed when a page has only the legacy surface marker. Without
        // an explicit ID and interaction state the WebView remains the owner
        // of Pencil input, so the native overlay cannot swallow an unbridged
        // stroke.
        const selector = '[data-ink-surface="handwriting"], [data-ink-surface="pdf"]';
        let frame = 0;
        const report = () => {
            frame = 0;
            const surfaces = [...document.querySelectorAll(selector)]
                .filter((element) => element.dataset.inkInteractive === 'true'
                    && Boolean(element.dataset.inkSurfaceId))
                .map((element) => {
                    const rect = element.getBoundingClientRect();
                    return {
                        id: element.dataset.inkSurfaceId || '',
                        x: rect.left,
                        y: rect.top,
                        width: rect.width,
                        height: rect.height,
                        tool: element.dataset.inkTool === 'eraser' ? 'eraser' : 'pen'
                    };
                })
                .filter((surface) => surface.id && surface.width > 0 && surface.height > 0);
            try { handler.postMessage({ surfaces }); } catch (_) {}
        };
        const schedule = () => {
            if (frame) return;
            frame = requestAnimationFrame(report);
        };
        const start = () => {
            if (!document.documentElement) return;
            const observer = new MutationObserver(schedule);
            observer.observe(document.documentElement, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: [
                    'data-ink-surface',
                    'data-ink-surface-id',
                    'data-ink-interactive',
                    'data-ink-tool',
                    'style',
                    'class'
                ]
            });
            window.addEventListener('resize', schedule, { passive: true });
            window.addEventListener('scroll', schedule, { capture: true, passive: true });
            window.visualViewport?.addEventListener('resize', schedule, { passive: true });
            window.visualViewport?.addEventListener('scroll', schedule, { passive: true });
            schedule();
        };
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', start, { once: true });
        } else {
            start();
        }
    })();
    """
}

private enum CameraCaptureIntentScript {
    static let handlerName = "stemistCameraCapture"

    static let observe = """
    (() => {
        const host = window.location.hostname.toLowerCase();
        if (host !== 'ieltsist.com' && !host.endsWith('.ieltsist.com')) return;
        const handler = window.webkit?.messageHandlers?.stemistCameraCapture;
        if (!handler) return;
        const cameraLabel = /(take photo|camera|拍照|使用摄像头|打开摄像头)/i;
        const textOf = (element) => (element?.textContent || '')
            .replace(/\\s+/g, ' ')
            .trim() + ' ' + (element?.getAttribute?.('aria-label') || '');
        const isCameraInput = (element) => element instanceof HTMLInputElement
            && element.type === 'file'
            && (element.hasAttribute('capture') || element.hasAttribute('data-camera-input'));
        const isCameraControl = (element) => {
            if (!(element instanceof Element)) return false;
            if (isCameraInput(element)) return true;
            if (element.hasAttribute('data-camera-intent')) return true;
            if (!element.matches('button, [role="button"], label')) return false;
            return cameraLabel.test(textOf(element));
        };
        const findCameraInput = (candidates) => {
            const direct = candidates.find(isCameraInput);
            if (direct) return direct;

            const control = candidates.find((element) => element.hasAttribute?.('data-camera-intent')
                || cameraLabel.test(textOf(element)));
            if (!control) return null;

            const scopes = [
                control,
                control.closest?.('.handwriting-pad, .ai-coach, form, section, article'),
                control.parentElement,
                document
            ].filter(Boolean);
            for (const scope of scopes) {
                const input = scope.querySelector?.('input[type="file"][capture], input[type="file"][data-camera-input]');
                if (input && isCameraInput(input)) return input;
            }
            return null;
        };
        const nextRequestID = () => {
            const random = globalThis.crypto?.randomUUID?.()
                || `${Date.now()}-${Math.random().toString(36).slice(2)}`;
            return `camera-${random}`.replace(/[^A-Za-z0-9._:-]/g, '').slice(0, 96);
        };
        const recordCameraIntent = (input) => {
            // This runs in the capture phase, before React opens the hidden
            // file input. The native panel delegate can read this marker if
            // the WKScriptMessage arrives one run-loop turn too late.
            window.__stemistCameraIntentAt = Date.now();
            const requestId = nextRequestID();
            if (input) input.setAttribute('data-stemist-camera-request', requestId);
            try {
                handler.postMessage({ kind: 'camera-direct', requestId });
                return true;
            } catch (_) {}
            if (input) input.removeAttribute('data-stemist-camera-request');
            return false;
        };
        document.addEventListener('click', (event) => {
            if (!(event.target instanceof Element)) return;
            const candidates = [
                event.target.closest('input[type="file"]'),
                event.target.closest('button, [role="button"]'),
                event.target.closest('label')
            ].filter(Boolean);
            if (!candidates.some(isCameraControl)) return;

            const input = findCameraInput(candidates);
            if (!input) {
                // Leave unknown controls to WebKit's normal upload path. The
                // marker still lets iOS 18.4+ select the camera if the page
                // opens a capture input on the next event turn.
                window.__stemistCameraIntentAt = Date.now();
                try { handler.postMessage({ kind: 'camera' }); } catch (_) {}
                return;
            }

            // A successful native handoff owns the event. Preventing the
            // hidden input click is what keeps iOS 17 from opening Files.
            if (recordCameraIntent(input)) {
                event.preventDefault();
                event.stopImmediatePropagation();
            }
        }, true);
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

    var body: some View {
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
                if route.showsBrowserNavigation {
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
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("web-browser-navigation")
                    }
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
        .background(StemistTheme.background)
    }
}

private struct NativePencilSurface {
    let id: String
    let frame: CGRect
    let tool: String
}

private final class PencilStrokeCanvasView: PKCanvasView {
    var onStrokeEnd: (() -> Void)?

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        // PencilKit updates its PKDrawing during the super call. Deliver on
        // the next main-run-loop turn so the final control point is included
        // before the bridge snapshots the stroke.
        DispatchQueue.main.async { [weak self] in
            self?.onStrokeEnd?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        DispatchQueue.main.async { [weak self] in
            self?.onStrokeEnd?()
        }
    }
}

private final class NativePencilSurfaceOverlay: UIView {
    struct Stroke {
        let surfaceID: String
        let surfaceFrame: CGRect
        let tool: String
        let points: [[String: Any]]
    }

    private let canvasView = PencilStrokeCanvasView(frame: .zero)
    private var surfaces: [NativePencilSurface] = []
    private var activeSurface: NativePencilSurface?

    var onStrokeEnd: (() -> Void)? {
        didSet {
            canvasView.onStrokeEnd = { [weak self] in
                self?.onStrokeEnd?()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.allowsFingerDrawing = false
        canvasView.isMultipleTouchEnabled = false
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 2)
        addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reset() {
        surfaces = []
        activeSurface = nil
        canvasView.drawing = PKDrawing()
    }

    func updateSurfaces(_ next: [NativePencilSurface]) {
        surfaces = next
        if let activeSurface,
           !next.contains(where: { $0.id == activeSurface.id }) {
            self.activeSurface = nil
        }
        if let tool = next.first?.tool, tool == "eraser" {
            canvasView.tool = PKEraserTool(.vector)
        } else {
            canvasView.tool = PKInkingTool(.pen, color: .label, width: 2)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let pencilIsAtPoint = event?.allTouches?.contains(where: { touch in
            guard touch.type == .pencil else { return false }
            let location = touch.location(in: self)
            return hypot(location.x - point.x, location.y - point.y) < 4
        }) == true
        guard pencilIsAtPoint,
              let surface = surfaces.first(where: { $0.frame.contains(point) }) else {
            return nil
        }
        activeSurface = surface
        canvasView.tool = surface.tool == "eraser"
            ? PKEraserTool(.vector)
            : PKInkingTool(.pen, color: .label, width: 2)
        return canvasView
    }

    func consumePendingStrokes() -> [Stroke] {
        guard let activeSurface,
              !canvasView.drawing.strokes.isEmpty else {
            canvasView.drawing = PKDrawing()
            return []
        }

        let pending = canvasView.drawing.strokes.compactMap { stroke -> Stroke? in
            let path = stroke.path
            guard path.count > 0 else { return nil }

            var points: [[String: Any]] = []
            points.reserveCapacity(path.count)
            for index in 0..<path.count {
                let point = path[index]
                let localLocation = point.location.applying(stroke.transform)
                // The web bridge consumes viewport coordinates from
                // getBoundingClientRect(). Convert out of PencilKit's canvas
                // coordinate space explicitly so future layout/transform
                // changes cannot silently shift the ink relative to the DOM.
                let location = canvasView.convert(localLocation, to: self)
                points.append([
                    "x": Double(location.x),
                    "y": Double(location.y),
                    "pressure": Double(point.force),
                ])
            }
            guard !points.isEmpty else { return nil }
            return Stroke(
                surfaceID: activeSurface.id,
                surfaceFrame: activeSurface.frame,
                tool: activeSurface.tool,
                points: points
            )
        }
        canvasView.drawing = PKDrawing()
        return pending
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
        configuration.userContentController.add(context.coordinator, name: PenInputBehaviorScript.handlerName)
        configuration.userContentController.add(context.coordinator, name: NativePencilSurfaceScript.handlerName)
        configuration.userContentController.add(context.coordinator, name: CameraCaptureIntentScript.handlerName)
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: PenInputBehaviorScript.install,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: NativePencilSurfaceScript.observe,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: CameraCaptureIntentScript.observe,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
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
        let pencilOverlay = NativePencilSurfaceOverlay(frame: .zero)
        pencilOverlay.translatesAutoresizingMaskIntoConstraints = false
        webView.addSubview(pencilOverlay)
        NSLayoutConstraint.activate([
            pencilOverlay.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            pencilOverlay.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            pencilOverlay.topAnchor.constraint(equalTo: webView.topAnchor),
            pencilOverlay.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
        ])
        context.coordinator.pencilOverlay = pencilOverlay
        pencilOverlay.onStrokeEnd = { [weak coordinator = context.coordinator] in
            coordinator?.forwardLatestPencilStroke()
        }
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
        // Keep text interaction stable. Toggling this preference from a
        // JavaScript pointer callback causes a measurable Pencil hitch in
        // WKWebView; drawing surfaces opt out of selection themselves.
        configuration.preferences.isTextInteractionEnabled = true
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

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIDocumentPickerDelegate,
        UIImagePickerControllerDelegate, UINavigationControllerDelegate, WKScriptMessageHandler {
        var parent: EmbeddedWebView
        var store: WebViewStore
        var requestedURL: URL?
        var lastReloadToken: UUID?
        var fileUploadCompletion: (([URL]?) -> Void)?
        var hasRetriedAfterTermination = false
        fileprivate weak var pencilOverlay: NativePencilSurfaceOverlay?
        private var cameraCaptureIntentDeadline: Date?
        private var directCameraRequestID: String?
        private weak var directCameraWebView: WKWebView?

        private static let maxCameraDimension: CGFloat = 2048
        private static let maxCameraAttachmentBytes = 4 * 1024 * 1024

        init(parent: EmbeddedWebView, store: WebViewStore) {
            self.parent = parent
            self.store = store
            super.init()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == PenInputBehaviorScript.handlerName {
                // Do not mutate WKPreferences while a Pencil stroke is in
                // flight. WebKit applies that preference asynchronously and
                // can interrupt the same pointer stream that is painting the
                // answer. Selection/callout suppression is handled by the
                // scoped CSS, pointer cancellation and context-menu delegate,
                // so the preference remains stable for the document lifetime.
                return
            }

            if message.name == NativePencilSurfaceScript.handlerName {
                updatePencilSurfaces(from: message.body)
                return
            }

            guard message.name == CameraCaptureIntentScript.handlerName,
                  let body = message.body as? [String: Any],
                  isTrustedProductMessage(message) else {
                return
            }

            if body["kind"] as? String == "camera-direct" {
                guard let requestID = body["requestId"] as? String,
                      isSafeCameraRequestID(requestID),
                      let webView = store.webView else {
                    return
                }
                directCameraRequestID = requestID
                directCameraWebView = webView
                cameraCaptureIntentDeadline = nil
                DispatchQueue.main.async { [weak self, weak webView] in
                    guard let self, let webView,
                          self.directCameraRequestID == requestID else { return }
                    self.presentCameraCapture(in: webView)
                }
                return
            }

            guard body["kind"] as? String == "camera" else { return }

            // The message arrives immediately before WebKit asks the delegate
            // to present the file panel for the same input. Keep the window
            // short so a later Upload photo action cannot inherit camera mode.
            cameraCaptureIntentDeadline = Date().addingTimeInterval(2)
        }

        private func isTrustedProductMessage(_ message: WKScriptMessage) -> Bool {
            guard message.frameInfo.isMainFrame else { return false }
            let origin = message.frameInfo.securityOrigin
            guard let originURL = URL(string: "\(origin.protocol)://\(origin.host)") else {
                return false
            }
            return ProductWebPolicy.isAllowed(originURL)
        }

        private func isSafeCameraRequestID(_ value: String) -> Bool {
            guard !value.isEmpty, value.count <= 96 else { return false }
            return value.range(of: "^[A-Za-z0-9._:-]+$", options: .regularExpression) != nil
        }

        private func updatePencilSurfaces(from body: Any) {
            guard let body = body as? [String: Any],
                  let rawSurfaces = body["surfaces"] as? [[String: Any]] else {
                pencilOverlay?.reset()
                return
            }

            let surfaces = rawSurfaces.compactMap { raw -> NativePencilSurface? in
                guard let id = raw["id"] as? String,
                      let x = raw["x"] as? NSNumber,
                      let y = raw["y"] as? NSNumber,
                      let width = raw["width"] as? NSNumber,
                      let height = raw["height"] as? NSNumber,
                      width.doubleValue > 0,
                      height.doubleValue > 0 else {
                    return nil
                }
                return NativePencilSurface(
                    id: id,
                    frame: CGRect(
                        x: x.doubleValue,
                        y: y.doubleValue,
                        width: width.doubleValue,
                        height: height.doubleValue
                    ),
                    tool: raw["tool"] as? String == "eraser" ? "eraser" : "pen"
                )
            }
            pencilOverlay?.updateSurfaces(surfaces)
        }

        func forwardLatestPencilStroke() {
            guard let webView = store.webView,
                  let strokes = pencilOverlay?.consumePendingStrokes(),
                  !strokes.isEmpty else {
                return
            }

            // A fast lift-and-repress can leave more than one PKStroke in the
            // canvas before the async touch callback runs. Send each stroke
            // separately so the web ink model never draws a false segment
            // between two independent strokes.
            for stroke in strokes {
                guard let payloadData = try? JSONSerialization.data(
                    withJSONObject: [
                        "surfaceId": stroke.surfaceID,
                        "coordinateSpace": "webViewViewport",
                        "surfaceFrame": [
                            "x": Double(stroke.surfaceFrame.origin.x),
                            "y": Double(stroke.surfaceFrame.origin.y),
                            "width": Double(stroke.surfaceFrame.size.width),
                            "height": Double(stroke.surfaceFrame.size.height),
                        ],
                        "tool": stroke.tool,
                        "points": stroke.points,
                    ],
                    options: []
                ),
                let payload = String(data: payloadData, encoding: .utf8) else {
                    continue
                }
                let script = "window.dispatchEvent(new CustomEvent('stemist-native-pencil-stroke',{detail:\(payload)}));"
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
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
            if let requestID = directCameraRequestID {
                clearDirectCameraInput(requestID, in: directCameraWebView)
                directCameraRequestID = nil
                directCameraWebView = nil
            }
            requestedURL = url
            pencilOverlay?.reset()
            webView.configuration.preferences.isTextInteractionEnabled = true
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

        @available(iOS 13.0, *)
        func webView(
            _ webView: WKWebView,
            contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
            completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
        ) {
            // Product actions have their own native/web controls. Returning
            // nil prevents a long Pencil press from opening WebKit's copy,
            // lookup or link-preview menu over the drawing surface.
            completionHandler(nil)
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
            let allowsMultipleSelection = parameters.allowsMultipleSelection

            resolveCameraCaptureIntent(in: webView) { [weak self, weak webView] useCamera in
                guard let self else { return }
                guard let webView else {
                    self.finishFileUpload(with: nil)
                    return
                }
                if useCamera {
                    self.presentCameraCapture(in: webView)
                } else {
                    self.presentDocumentPicker(
                        allowsMultipleSelection: allowsMultipleSelection,
                        in: webView
                    )
                }
            }
        }

        private func presentDocumentPicker(
            allowsMultipleSelection: Bool,
            in webView: WKWebView
        ) {
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
            picker.allowsMultipleSelection = allowsMultipleSelection
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

        private func consumeCameraCaptureIntent() -> Bool {
            defer { cameraCaptureIntentDeadline = nil }
            guard let deadline = cameraCaptureIntentDeadline else { return false }
            return deadline > Date()
        }

        private func resolveCameraCaptureIntent(
            in webView: WKWebView,
            completion: @escaping (Bool) -> Void
        ) {
            if consumeCameraCaptureIntent() {
                webView.evaluateJavaScript("window.__stemistCameraIntentAt = 0;", completionHandler: nil)
                completion(true)
                return
            }

            // The capture-phase JavaScript marker is synchronous, whereas
            // WKScriptMessage delivery is not guaranteed to beat the file
            // input's panel request. Consume a fresh marker exactly once.
            webView.evaluateJavaScript(
                """
                (() => {
                    const timestamp = Number(window.__stemistCameraIntentAt || 0);
                    const age = Date.now() - timestamp;
                    const fresh = Number.isFinite(timestamp) && age >= 0 && age < 2_000;
                    if (fresh) window.__stemistCameraIntentAt = 0;
                    return fresh;
                })();
                """
            ) { result, _ in
                completion(result as? Bool ?? false)
            }
        }

        private func presentCameraCapture(in webView: WKWebView) {
            guard let presenter = presentingViewController(for: webView) else {
                cancelCameraCapture()
                return
            }
            // A second tap while the system camera is already on screen is a
            // duplicate event, not a failed capture. Keep the first request
            // alive until the picker completes.
            if presenter is UIImagePickerController { return }
            guard !(presenter is UIAlertController),
                  !(presenter is UIDocumentPickerViewController) else {
                cancelCameraCapture()
                return
            }

            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                presentCameraUnavailable(on: presenter)
                return
            }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                presentCameraPicker(on: presenter)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self, weak presenter] granted in
                    DispatchQueue.main.async {
                        guard let self, let presenter else { return }
                        if granted {
                            self.presentCameraPicker(on: presenter)
                        } else {
                            self.presentCameraPermissionDenied(on: presenter)
                        }
                    }
                }
            case .denied, .restricted:
                presentCameraPermissionDenied(on: presenter)
            @unknown default:
                presentCameraPermissionDenied(on: presenter)
            }
        }

        private func presentCameraPicker(on presenter: UIViewController) {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.delegate = self
            presenter.present(picker, animated: true)
        }

        private func presentCameraUnavailable(on presenter: UIViewController) {
            let alert = UIAlertController(
                title: "Camera unavailable",
                message: "This device cannot open a camera right now. Choose Upload photo instead.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancelCameraCapture()
            })
            presenter.present(alert, animated: true)
        }

        private func presentCameraPermissionDenied(on presenter: UIViewController) {
            let alert = UIAlertController(
                title: "Camera access is off",
                message: "Allow camera access in Settings, then try Take photo again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.cancelCameraCapture()
            })
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { [weak self] _ in
                self?.cancelCameraCapture()
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL, options: [:])
            })
            presenter.present(alert, animated: true)
        }

        private func presentCameraAttachmentFailure() {
            guard let webView = store.webView,
                  let presenter = presentingViewController(for: webView),
                  !(presenter is UIAlertController),
                  !(presenter is UIDocumentPickerViewController),
                  !(presenter is UIImagePickerController) else {
                return
            }

            let alert = UIAlertController(
                title: "Photo could not be attached",
                message: "The photo was captured but could not be prepared for AI Coach. Try Take photo again or choose Upload photo.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
        }

        private func cancelCameraCapture() {
            guard let requestID = directCameraRequestID else {
                finishFileUpload(with: nil)
                return
            }
            let webView = directCameraWebView
            directCameraRequestID = nil
            directCameraWebView = nil
            clearDirectCameraInput(requestID, in: webView)
        }

        private func clearDirectCameraInput(_ requestID: String, in webView: WKWebView?) {
            guard let webView else { return }
            let script = """
            (() => {
                const input = document.querySelector('[data-stemist-camera-request="\(requestID)"]');
                if (input) input.removeAttribute('data-stemist-camera-request');
                return Boolean(input);
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func preparedCameraJPEG(from image: UIImage) -> Data? {
            let sourceSize = image.size
            guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
            let longestSide = max(sourceSize.width, sourceSize.height)
            let scale = min(1, Self.maxCameraDimension / longestSide)
            let targetSize = CGSize(
                width: max(1, floor(sourceSize.width * scale)),
                height: max(1, floor(sourceSize.height * scale))
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            for quality in [CGFloat(0.86), 0.74, 0.62, 0.5] {
                guard let data = rendered.jpegData(compressionQuality: quality) else { continue }
                if data.count <= Self.maxCameraAttachmentBytes { return data }
            }
            return nil
        }

        private func deliverDirectCameraImage(
            _ data: Data,
            requestID: String,
            to webView: WKWebView?
        ) {
            guard data.count <= Self.maxCameraAttachmentBytes,
                  let webView else {
                clearDirectCameraInput(requestID, in: webView)
                presentCameraAttachmentFailure()
                return
            }
            let encoded = data.base64EncodedString()
            let script = """
            (() => {
                const input = document.querySelector('[data-stemist-camera-request="\(requestID)"]');
                if (!(input instanceof HTMLInputElement)) return false;
                try {
                    const binary = atob('\(encoded)');
                    const bytes = new Uint8Array(binary.length);
                    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
                    const transfer = typeof DataTransfer === 'function'
                        ? new DataTransfer()
                        : new ClipboardEvent('').clipboardData;
                    if (!transfer) return false;
                    transfer.items.add(new File([bytes], 'stemist-camera.jpg', { type: 'image/jpeg' }));
                    try {
                        input.files = transfer.files;
                    } catch (_) {
                        Object.defineProperty(input, 'files', { configurable: true, value: transfer.files });
                    }
                    input.removeAttribute('data-stemist-camera-request');
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                    input.dispatchEvent(new Event('change', { bubbles: true }));
                    return true;
                } catch (_) {
                    input.removeAttribute('data-stemist-camera-request');
                    return false;
                }
            })();
            """
            webView.evaluateJavaScript(script) { [weak self, weak webView] result, _ in
                guard (result as? Bool) == true else {
                    DispatchQueue.main.async {
                        self?.clearDirectCameraInput(requestID, in: webView)
                        self?.presentCameraAttachmentFailure()
                    }
                    return
                }
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            let directRequestID = directCameraRequestID
            let preparedData = image.flatMap { self.preparedCameraJPEG(from: $0) }
            let fileURL = directRequestID == nil ? preparedData.flatMap { data -> URL? in
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("stemist-camera-\(UUID().uuidString).jpg")
                do {
                    try data.write(to: url, options: .atomic)
                    return url
                } catch {
                    return nil
                }
            } : nil
            let failedToPrepare = image == nil || preparedData == nil

            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                if let directRequestID {
                    let webView = self.directCameraWebView
                    self.directCameraRequestID = nil
                    self.directCameraWebView = nil
                    if let preparedData, !failedToPrepare {
                        self.deliverDirectCameraImage(preparedData, requestID: directRequestID, to: webView)
                    } else {
                        self.clearDirectCameraInput(directRequestID, in: webView)
                        self.presentCameraAttachmentFailure()
                    }
                } else {
                    self.finishFileUpload(with: fileURL.map { [$0] })
                    if failedToPrepare {
                        self.presentCameraAttachmentFailure()
                    }
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { [weak self] in
                self?.cancelCameraCapture()
            }
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
            if let requestID = directCameraRequestID {
                clearDirectCameraInput(requestID, in: directCameraWebView)
            }
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
