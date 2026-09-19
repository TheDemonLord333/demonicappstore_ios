//
//  AppConfiguration.swift
//  DemonicAppStore
//
//  Zentrale Konfiguration der nativen Hülle. Dies ist die EINZIGE Stelle im
//  Projekt, an der die Store-Domain hinterlegt ist. Soll die App künftig auf
//  eine andere Domain zeigen, genügt es, `storeURL` hier zu ändern.
//
//  Die Domain stammt aus `demonicappstore_web/.env.example` (BASE_URL) bzw.
//  der dort dokumentierten Let's-Encrypt-Anleitung.
//

import Foundation

enum AppConfiguration {

    /// Die öffentliche HTTPS-Adresse des Demonic App Store.
    static let storeURL: URL = URL(string: "https://das.thedemonlord333.me")!

    /// Hostname, gegen den Navigation & Bridge-Nachrichten validiert werden.
    static var trustedHost: String { storeURL.host ?? "" }

    /// Version der nativen Hülle (CFBundleShortVersionString), z. B. "1.0.0".
    static var nativeAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// Build-Nummer der nativen Hülle (CFBundleVersion), z. B. "1".
    static var nativeBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// Wird an den Standard-WebKit-User-Agent angehängt, ohne ihn zu ersetzen.
    /// `nativeBridge.js` erkennt die native Hülle primär über `window.DemonicNative`;
    /// dieser UA-Zusatz ist ein rein sekundäres, zusätzliches Signal
    /// (siehe `isNativeApp()` in nativeBridge.js, das per Regex danach sucht).
    static var userAgentSuffix: String {
        "DemonicAppStoreApp/\(nativeAppVersion)"
    }

    #if DEBUG
    static let isDebugBuild = true
    #else
    static let isDebugBuild = false
    #endif
}
