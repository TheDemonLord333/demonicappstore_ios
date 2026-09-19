//
//  WebViewCoordinator.swift
//  DemonicAppStore
//
//  WKNavigationDelegate/WKUIDelegate der Store-WKWebView. Setzt die
//  NavigationPolicy durch und meldet Ladezustände an WebViewStore.
//

import WebKit
import UIKit
import OSLog

@MainActor
final class WebViewCoordinator: NSObject {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DemonicAppStore", category: "WebView")

    private weak var store: WebViewStore?
    private let policy: NavigationPolicy

    init(store: WebViewStore, policy: NavigationPolicy) {
        self.store = store
        self.policy = policy
    }

    /// true, wenn dieser Fehler eine von UNS über decidePolicyFor bewusst
    /// abgebrochene Navigation ist (externer Link, Installationslink,
    /// Custom Scheme) – kein echter Ladefehler, darf keine Offline-Ansicht
    /// auslösen.
    private func isIntentionalCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func classify(_ error: Error) -> WebViewStore.FailureReason {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return .other }
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .offline
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorDNSLookupFailed:
            return .serverUnreachable
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateNotYetValid,
             NSURLErrorClientCertificateRejected:
            return .tlsError
        default:
            return .other
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewCoordinator: WKNavigationDelegate {

    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        Task { @MainActor in
            let decision = self.policy.decide(for: url)
            switch decision {
            case .allowInWebView:
                decisionHandler(.allow)
            case .openInstallLink(let installURL):
                decisionHandler(.cancel)
                ExternalURLHandler.open(installURL)
            case .openExternally(let externalURL):
                decisionHandler(.cancel)
                ExternalURLHandler.open(externalURL)
            case .openCustomScheme(let schemeURL):
                decisionHandler(.cancel)
                ExternalURLHandler.open(schemeURL)
            case .block:
                Self.logger.warning("Navigation blockiert (nicht erlaubtes Scheme): \(url.scheme ?? "?", privacy: .public)")
                decisionHandler(.cancel)
            }
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if navigationResponse.canShowMIMEType {
            decisionHandler(.allow)
            return
        }
        // Nicht darstellbare Antwort (z. B. ein direkter Dateidownload, der
        // kein IPA-Installationslink ist): außerhalb der Store-WKWebView
        // behandeln lassen, statt eine leere/weiße Seite zu zeigen.
        guard let url = navigationResponse.response.url else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.cancel)
        Task { @MainActor in
            ExternalURLHandler.open(url)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.store?.handleNavigationFinished()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard !self.isIntentionalCancellation(error) else { return }
            self.store?.handleNavigationFailed(reason: self.classify(error))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard !self.isIntentionalCancellation(error) else { return }
            self.store?.handleNavigationFailed(reason: self.classify(error))
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewCoordinator: WKUIDelegate {

    /// `target="_blank"`-Links: in derselben Regel wie normale Navigation
    /// behandeln, statt ein neues WKWebView-Fenster zu öffnen (der Store
    /// bekommt kein zweites privilegiertes Fenster).
    nonisolated func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            Task { @MainActor in
                let decision = self.policy.decide(for: url)
                switch decision {
                case .allowInWebView:
                    webView.load(navigationAction.request)
                case .openInstallLink(let u), .openExternally(let u), .openCustomScheme(let u):
                    ExternalURLHandler.open(u)
                case .block:
                    break
                }
            }
        }
        return nil
    }

    nonisolated func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            UIApplication.topPresentedViewController()?.present(alert, animated: true)
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Abbrechen", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
            UIApplication.topPresentedViewController()?.present(alert, animated: true)
        }
    }
}

private extension UIApplication {
    static func topPresentedViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var top = scene.keyWindow?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first(where: \.isKeyWindow)
    }
}
