//
//  NavigationPolicy.swift
//  DemonicAppStore
//
//  Zentrale Navigationsregel für die Store-WKWebView. Wird ausschließlich
//  von WebViewCoordinator (WKNavigationDelegate) konsultiert.
//
//  Grundprinzip (siehe README):
//    interne HTTPS-URL          -> in der WKWebView laden
//    unterstützter Installationslink (itms-services) -> System-Installationsfluss
//    externe HTTPS-URL          -> außerhalb der WKWebView öffnen
//    erlaubtes Custom Scheme    -> kontrolliert an iOS weitergeben
//    unbekanntes/unsicheres Scheme -> blockieren
//

import Foundation

enum NavigationDecision: Equatable {
    case allowInWebView
    case openInstallLink(URL)
    case openExternally(URL)
    case openCustomScheme(URL)
    case block
}

struct NavigationPolicy {
    let trustedHost: String
    let knownSchemes: Set<String>

    /// Schemes, die iOS selbst sinnvoll behandelt und die keine Gefahr für
    /// die privilegierte Store-WKWebView darstellen.
    private static let systemHandledSchemes: Set<String> = ["mailto", "tel", "facetime", "facetime-audio", "sms"]

    /// Niemals erlaubte Schemes – unabhängig vom Kontext blockiert.
    private static let alwaysBlockedSchemes: Set<String> = ["javascript", "file", "data", "blob", "about"]

    func decide(for url: URL) -> NavigationDecision {
        guard let scheme = url.scheme?.lowercased() else { return .block }

        if Self.alwaysBlockedSchemes.contains(scheme) {
            return .block
        }

        switch scheme {
        case "https":
            if url.host?.caseInsensitiveCompare(trustedHost) == .orderedSame {
                return .allowInWebView
            }
            return .openExternally(url)

        case "http":
            // Nur zulassen, falls dieselbe Domain versehentlich ohne TLS
            // verlinkt wurde (wird dann ohnehin von ATS abgelehnt); alles
            // andere geht nach außen.
            if url.host?.caseInsensitiveCompare(trustedHost) == .orderedSame {
                return .allowInWebView
            }
            return .openExternally(url)

        case "itms-services":
            guard InstallLinkValidator.isValidInstallLink(url, trustedHost: trustedHost) else {
                return .block
            }
            return .openInstallLink(url)

        default:
            if Self.systemHandledSchemes.contains(scheme) {
                return .openExternally(url)
            }
            if knownSchemes.contains(scheme) {
                return .openCustomScheme(url)
            }
            return .block
        }
    }
}
