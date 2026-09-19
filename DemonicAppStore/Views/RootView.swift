//
//  RootView.swift
//  DemonicAppStore
//
//  Kombiniert WKWebView + native Loading-/Offline-Overlays. Bewusst OHNE
//  eigene Navigationsleiste/TabBar – die Website nutzt praktisch den
//  gesamten Bildschirm.
//

import SwiftUI

struct RootView: View {
    @StateObject private var webViewStore = WebViewStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var didAutoRetryForNetwork = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            DemonicWebView(store: webViewStore)
                .ignoresSafeArea()
                .opacity(showLoading ? 0 : 1)

            if showLoading {
                LoadingView()
                    .transition(.opacity)
            }

            if case let .failed(reason) = webViewStore.loadState {
                OfflineView(reason: reason) {
                    webViewStore.retry()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: webViewStore.loadState)
        .statusBarHidden(false)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                webViewStore.notifyDidBecomeActive()
            }
        }
        .onReceive(webViewStore.networkMonitor.$isOnline) { isOnline in
            webViewStore.notifyNetworkChanged(isOnline: isOnline)
            if isOnline, case .failed = webViewStore.loadState, !didAutoRetryForNetwork {
                didAutoRetryForNetwork = true
                webViewStore.retry()
            }
            if !isOnline {
                didAutoRetryForNetwork = false
            }
        }
    }

    private var showLoading: Bool {
        webViewStore.isInitialLoad && webViewStore.loadState == .loading
    }
}

#Preview {
    RootView()
}
