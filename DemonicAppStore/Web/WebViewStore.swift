//
//  WebViewStore.swift
//  DemonicAppStore
//
//  Hält die EINE WKWebView-Instanz für die Lebenszeit der App. SwiftUI-Views
//  (RootView/DemonicWebView) können neu gebaut werden, ohne dass dabei je
//  eine neue WKWebView entsteht – wichtig u. a. für Pull-to-Refresh und für
//  erhaltene Navigation-History/Session-State.
//

import Foundation
import WebKit
import Combine
import OSLog

@MainActor
final class WebViewStore: NSObject, ObservableObject {

    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(FailureReason)
    }

    enum FailureReason: Equatable {
        case offline
        case serverUnreachable
        case tlsError
        case other

        var title: String {
            "Server nicht erreichbar"
        }

        var message: String {
            switch self {
            case .offline:
                return "Keine Internetverbindung. Überprüfe deine Internetverbindung."
            case .serverUnreachable:
                return "Der Demonic App Store konnte keine Verbindung zum Server herstellen."
            case .tlsError:
                return "Die sichere Verbindung zum Demonic App Store konnte nicht hergestellt werden."
            case .other:
                return "Der Demonic App Store konnte nicht geladen werden."
            }
        }
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DemonicAppStore", category: "WebView")

    @Published private(set) var loadState: LoadState = .loading
    @Published var isRefreshing: Bool = false

    /// true, solange noch kein erfolgreicher initialer Ladevorgang
    /// stattgefunden hat – steuert, ob der native LoadingView-Vollbild-
    /// Overlay gezeigt wird (nicht bei jedem Pull-to-Refresh-Reload).
    private(set) var isInitialLoad = true

    let webView: WKWebView
    let bridge: NativeBridge
    let registry: InstalledAppRegistry
    let networkMonitor: NetworkMonitor
    private let navigationPolicy: NavigationPolicy

    private lazy var coordinator = WebViewCoordinator(store: self, policy: navigationPolicy)
    private var hasTaggedUserAgent = false

    override init() {
        let registry = InstalledAppRegistry()
        let bridge = NativeBridge(registry: registry, trustedHost: AppConfiguration.trustedHost)
        self.registry = registry
        self.bridge = bridge
        self.networkMonitor = NetworkMonitor()
        self.navigationPolicy = NavigationPolicy(
            trustedHost: AppConfiguration.trustedHost,
            knownSchemes: Set(KnownAppSchemes.allSchemes)
        )
        self.webView = WebViewStore.makeWebView(bridge: bridge, registry: registry)
        super.init()

        bridge.webView = webView
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
    }

    // MARK: - WKWebView factory

    private static func makeWebView(bridge: NativeBridge, registry: InstalledAppRegistry) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default() // persistente Cookies/LocalStorage/Sessions
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let controller = WKUserContentController()
        controller.add(bridge, name: NativeBridge.messageHandlerName)

        let deviceInfo = NativeDeviceInfo.current
        let script = bridge.injectionScript(deviceInfo: deviceInfo, installedApps: registry.bridgeSnapshot())
        controller.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        return webView
    }

    // MARK: - Loading

    func loadIfNeeded() {
        guard webView.url == nil else { return }
        load()
    }

    func load() {
        loadState = .loading
        webView.load(URLRequest(url: AppConfiguration.storeURL))
    }

    func retry() {
        load()
    }

    func reloadFromPullToRefresh() {
        // Dieselbe WKWebView reloaden – niemals eine neue erzeugen.
        webView.reload()
    }

    // MARK: - Lifecycle / state transitions (called by WebViewCoordinator)

    func handleNavigationFinished() {
        loadState = .loaded
        isInitialLoad = false
        isRefreshing = false
        tagUserAgentIfNeeded()
        registry.refreshAllConfirmations()
        bridge.refreshInstalledApps(on: webView)
    }

    func handleNavigationFailed(reason: FailureReason) {
        loadState = .failed(reason)
        isRefreshing = false
    }

    private func tagUserAgentIfNeeded() {
        guard !hasTaggedUserAgent, webView.customUserAgent == nil else { return }
        hasTaggedUserAgent = true
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] result, _ in
            guard let self, let base = result as? String else { return }
            self.webView.customUserAgent = "\(base) \(AppConfiguration.userAgentSuffix)"
        }
    }

    // MARK: - Native -> Web events

    func notifyDidBecomeActive() {
        registry.refreshAllConfirmations()
        bridge.refreshInstalledApps(on: webView)
        bridge.dispatchLifecycleEvent("appDidBecomeActive", on: webView)
    }

    func notifyNetworkChanged(isOnline: Bool) {
        bridge.dispatchLifecycleEvent("networkChanged", extra: ["online": isOnline], on: webView)
    }
}
