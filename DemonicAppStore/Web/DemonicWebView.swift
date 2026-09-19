//
//  DemonicWebView.swift
//  DemonicAppStore
//
//  Schlanker SwiftUI-Wrapper um die von WebViewStore gehaltene WKWebView.
//  Erzeugt selbst NIE eine WKWebView – nutzt ausschließlich die bereits
//  bestehende Instanz, damit Pull-to-Refresh & Navigation-History erhalten
//  bleiben.
//

import SwiftUI
import WebKit

struct DemonicWebView: UIViewRepresentable {
    @ObservedObject var store: WebViewStore

    func makeUIView(context: Context) -> WKWebView {
        let webView = store.webView
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor(red: 0.82, green: 0.15, blue: 0.2, alpha: 1)
        refreshControl.addTarget(context.coordinator, action: #selector(RefreshHandler.handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        context.coordinator.refreshControl = refreshControl

        store.loadIfNeeded()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if !store.isRefreshing {
            context.coordinator.refreshControl?.endRefreshing()
        }
    }

    func makeCoordinator() -> RefreshHandler {
        RefreshHandler(store: store)
    }

    @MainActor
    final class RefreshHandler: NSObject {
        weak var refreshControl: UIRefreshControl?
        private let store: WebViewStore

        init(store: WebViewStore) {
            self.store = store
        }

        @objc func handleRefresh() {
            store.isRefreshing = true
            store.reloadFromPullToRefresh()
        }
    }
}
