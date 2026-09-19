//
//  NetworkMonitor.swift
//  DemonicAppStore
//
//  Dünner Wrapper um NWPathMonitor (öffentliche Apple-API). Beachte: Eine
//  bestehende Internetverbindung bedeutet nicht, dass unser Store-Server
//  erreichbar ist – das wird zusätzlich über WKWebView-Ladefehler geprüft
//  (siehe WebViewCoordinator).
//

import Foundation
import Network
import OSLog

@MainActor
final class NetworkMonitor: ObservableObject {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DemonicAppStore", category: "Network")

    @Published private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "me.thedemonlord333.DemonicAppStore.network-monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if self.isOnline != online {
                    self.isOnline = online
                    Self.logger.info("Netzwerkstatus geändert: \(online ? "online" : "offline")")
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
