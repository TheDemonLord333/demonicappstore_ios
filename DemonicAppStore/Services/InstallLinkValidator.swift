//
//  InstallLinkValidator.swift
//  DemonicAppStore
//
//  Zentrale Validierung für Installationslinks. Wird sowohl von der
//  NavigationPolicy (Links/Redirects innerhalb der WKWebView) als auch von
//  NativeBridge (installApp-Nachrichten aus JavaScript) verwendet, damit
//  beide Wege exakt dieselben Regeln durchsetzen.
//
//  Format, das der Server erzeugt (server/services/manifestService.js):
//    itms-services://?action=download-manifest&url=<manifestUrl>
//  wobei <manifestUrl> = https://<Store-Domain>/api/apps/:slug/manifest
//
//  Das ist Apples offizieller, unterstützter Mechanismus für Ad-hoc-/
//  In-House-OTA-Installation signierter IPAs – es wird hier nichts umgangen,
//  nur validiert, dass der Link tatsächlich auf unsere vertrauenswürdige
//  Store-Domain zeigt, bevor er an iOS weitergereicht wird.
//

import Foundation

enum InstallLinkValidator {

    /// true, wenn `url` ein gültiger, auf `trustedHost` zeigender
    /// Installationslink ist (itms-services-OTA-Manifest oder ein direkter
    /// HTTPS-Link auf die Store-Domain).
    static func isValidInstallLink(_ url: URL, trustedHost: String) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }

        switch scheme {
        case "itms-services":
            return manifestURL(fromItmsServicesLink: url, trustedHost: trustedHost) != nil
        case "https":
            return url.host?.caseInsensitiveCompare(trustedHost) == .orderedSame
        default:
            return false
        }
    }

    /// Extrahiert und validiert die `url`-Query-Komponente eines
    /// `itms-services://`-Links: muss eine HTTPS-URL auf `trustedHost` sein.
    private static func manifestURL(fromItmsServicesLink url: URL, trustedHost: String) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawManifestURL = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let manifestURL = URL(string: rawManifestURL),
              manifestURL.scheme?.lowercased() == "https",
              manifestURL.host?.caseInsensitiveCompare(trustedHost) == .orderedSame else {
            return nil
        }
        return manifestURL
    }
}
