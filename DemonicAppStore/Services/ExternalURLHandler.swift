//
//  ExternalURLHandler.swift
//  DemonicAppStore
//
//  Öffnet URLs außerhalb der privilegierten Store-WKWebView über die
//  öffentliche `UIApplication.open`-API (Safari-App bzw. das zuständige
//  System-/Drittanbieter-Handler für das jeweilige Scheme).
//

import UIKit
import OSLog

@MainActor
enum ExternalURLHandler {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DemonicAppStore", category: "WebView")

    /// Öffnet `url` über die passende System-Funktion. Gibt `true` zurück,
    /// wenn iOS die URL entgegengenommen hat.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        guard UIApplication.shared.canOpenURL(url) else {
            logger.warning("Kann URL nicht öffnen (kein Handler registriert): \(url.scheme ?? "?", privacy: .public)")
            return false
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                logger.warning("Öffnen der externen URL ist fehlgeschlagen.")
            }
        }
        return true
    }
}
