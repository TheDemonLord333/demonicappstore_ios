//
//  NativeBridge.swift
//  DemonicAppStore
//
//  Swift-seitige Implementierung des in `client/native/nativeBridge.js`
//  bereits definierten Vertrags. Injiziert `window.DemonicNative` vor
//  Dokumentstart und beantwortet Nachrichten, die die Website über
//  `webkit.messageHandlers.demonicNative.postMessage(...)` sendet.
//
//  SICHERHEIT: Nachrichten werden ausschließlich akzeptiert, wenn sie aus
//  dem Hauptframe unserer vertrauenswürdigen Store-Domain stammen (geprüft
//  über `WKScriptMessage.frameInfo`, nicht nur `webView.url`). Nur die vier
//  in `NativeCommand` gelisteten Kommandos werden verarbeitet, alle
//  Payloads werden vollständig validiert. Es gibt keine generische
//  "führe beliebige Swift-Funktion anhand eines Strings aus"-Fähigkeit.
//

import Foundation
import WebKit
import UIKit
import OSLog

@MainActor
final class NativeBridge: NSObject, WKScriptMessageHandler {

    static let messageHandlerName = "demonicNative"

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DemonicAppStore", category: "Bridge")

    let registry: InstalledAppRegistry
    let trustedHost: String

    /// Wird von WebViewStore gesetzt, sobald die WKWebView existiert –
    /// erlaubt es der Bridge, Antworten per `evaluateJavaScript` zu senden.
    weak var webView: WKWebView?

    init(registry: InstalledAppRegistry, trustedHost: String) {
        self.registry = registry
        self.trustedHost = trustedHost
    }

    // MARK: - Injection script

    /// JavaScript, das `window.DemonicNative` VOR Dokumentstart bereitstellt
    /// – exakt in der Form, die `nativeBridge.js` erwartet (siehe dessen
    /// Kommentar-Header). Synchron verfügbare Felder (platform, deviceType,
    /// storeVersion, installedApps) werden direkt eingebettet; die
    /// Aktionsmethoden delegieren an den WKScriptMessageHandler.
    ///
    /// Wichtiges Detail: `nativeBridge.js`s `callNative()` ruft jede
    /// Aktionsmethode zunächst OHNE `requestId` auf, um zu prüfen, ob ein
    /// synchroner Rückgabewert existiert; liefert das `undefined`, wird die
    /// Methode ein zweites Mal mit der `requestId` als dem jeweils LETZTEN
    /// Argument aufgerufen – unabhängig davon, wie viele Argumente die Web-
    /// Seite ursprünglich übergeben hat (z. B. `installApp(id, url)` heute
    /// vs. ein mögliches künftiges `installApp(id, url, version, build)`).
    /// Die Shim-Funktionen lesen deshalb bewusst `arguments` (statt fester
    /// Parameterpositionen) und erkennen die `requestId` an ihrem stabilen
    /// `req_<timestamp>_<counter>`-Format aus nativeBridge.js. Nur wenn das
    /// letzte Argument so aussieht, wird tatsächlich gepostet – sonst würde
    /// der "Probe"-Aufruf ohne requestId die Aktion bereits auslösen.
    func injectionScript(deviceInfo: NativeDeviceInfo, installedApps: [String: [String: Any]]) -> String {
        let installedAppsJSON = Self.jsonString(from: installedApps) ?? "{}"

        return """
        (function () {
          function extractRequestId(args) {
            var last = args.length > 0 ? args[args.length - 1] : undefined;
            return (typeof last === 'string' && /^req_\\d+_\\d+$/.test(last)) ? last : undefined;
          }

          function post(command, payload, requestId) {
            window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({
              command: command,
              requestId: requestId,
              payload: payload
            });
            return undefined;
          }

          window.DemonicNative = {
            platform: \(Self.jsString(deviceInfo.platform)),
            deviceType: \(Self.jsString(deviceInfo.deviceType)),
            storeVersion: \(Self.jsString(deviceInfo.nativeAppVersion)),
            nativeAppVersion: \(Self.jsString(deviceInfo.nativeAppVersion)),
            nativeBuild: \(Self.jsString(deviceInfo.nativeBuild)),
            installedApps: \(installedAppsJSON),

            installApp: function () {
              var args = Array.prototype.slice.call(arguments);
              var requestId = extractRequestId(args);
              if (requestId === undefined) { return undefined; }
              return post('installApp', { appId: args[0], installUrl: args[1], version: args[2], build: args[3] }, requestId);
            },
            openApp: function () {
              var args = Array.prototype.slice.call(arguments);
              var requestId = extractRequestId(args);
              if (requestId === undefined) { return undefined; }
              return post('openApp', { appId: args[0] }, requestId);
            },
            checkForUpdates: function () {
              var args = Array.prototype.slice.call(arguments);
              var requestId = extractRequestId(args);
              if (requestId === undefined) { return undefined; }
              return post('checkForUpdates', {}, requestId);
            },
            getInstalledApps: function () {
              var args = Array.prototype.slice.call(arguments);
              var requestId = extractRequestId(args);
              if (requestId === undefined) { return undefined; }
              return post('getInstalledApps', {}, requestId);
            },

            // Zusätzliche, synchrone Komfortfunktionen (kein Bestandteil des
            // bisherigen nativeBridge.js-Vertrags, aber kompatibel dazu –
            // rein additiv, nichts Bestehendes wird verändert).
            getPlatform: function () { return window.DemonicNative.platform; },
            getDeviceInfo: function () {
              return {
                platform: window.DemonicNative.platform,
                deviceType: window.DemonicNative.deviceType,
                nativeAppVersion: window.DemonicNative.nativeAppVersion,
                nativeBuild: window.DemonicNative.nativeBuild
              };
            },
            getInstalledVersions: function () { return window.DemonicNative.installedApps; }
          };
        })();
        """
    }

    /// Aktualisiert `window.DemonicNative.installedApps` in einer bereits
    /// geladenen Seite (z. B. nachdem die Registry sich geändert hat) und
    /// löst ein `demonicNativeEvent` aus, an dem die Website – falls
    /// gewünscht – reaktiv Daten neu laden kann. Kein bestehender Vertrag
    /// aus nativeBridge.js wird dadurch verändert; die Views lesen
    /// `installedApps` heute bereits bei jedem Rendern neu aus.
    func refreshInstalledApps(on webView: WKWebView) {
        let snapshot = Self.jsonString(from: registry.bridgeSnapshot()) ?? "{}"
        let js = """
        if (window.DemonicNative) {
          window.DemonicNative.installedApps = \(snapshot);
          window.dispatchEvent(new CustomEvent('demonicNativeEvent', { detail: { type: 'registryChanged' } }));
        }
        """
        webView.evaluateJavaScript(js)
    }

    func dispatchLifecycleEvent(_ type: String, extra: [String: Any] = [:], on webView: WKWebView) {
        var detail = extra
        detail["type"] = type
        let json = Self.jsonString(from: detail) ?? "{\"type\":\"\(type)\"}"
        let js = "window.dispatchEvent(new CustomEvent('demonicNativeEvent', { detail: \(json) }));"
        webView.evaluateJavaScript(js)
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor in
            self.handle(message: message)
        }
    }

    private func handle(message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName else { return }

        // Domain-Sicherheit: Nachrichten nur aus dem Hauptframe unserer
        // vertrauenswürdigen HTTPS-Domain akzeptieren.
        let origin = message.frameInfo.securityOrigin
        guard message.frameInfo.isMainFrame,
              origin.protocol.lowercased() == "https",
              origin.host.caseInsensitiveCompare(trustedHost) == .orderedSame else {
            Self.logger.warning("Bridge-Nachricht von nicht vertrauenswürdigem Origin verworfen: \(origin.host, privacy: .public)")
            return
        }

        guard let native = NativeMessage(body: message.body) else {
            Self.logger.warning("Ungültige oder unbekannte Bridge-Nachricht verworfen.")
            return
        }
        guard let requestId = native.requestId, !requestId.isEmpty else {
            // Siehe injectionScript(): ohne requestId ist dies der reine
            // "Probe"-Aufruf von callNative() – bewusst kein Vorgang.
            return
        }

        switch native.command {
        case .installApp:
            handleInstallApp(payload: native.payload, requestId: requestId)
        case .openApp:
            handleOpenApp(payload: native.payload, requestId: requestId)
        case .checkForUpdates:
            handleCheckForUpdates(requestId: requestId)
        case .getInstalledApps:
            respond(requestId: requestId, ok: true, data: registry.bridgeSnapshot())
        }
    }

    // MARK: - Command handlers

    private func handleInstallApp(payload: [String: Any], requestId: String) {
        guard let appId = payload["appId"] as? String, !appId.isEmpty,
              let rawInstallUrl = payload["installUrl"] as? String,
              let installUrl = URL(string: rawInstallUrl) else {
            respond(requestId: requestId, ok: false, error: "Ungültige installApp-Anfrage.")
            return
        }
        guard InstallLinkValidator.isValidInstallLink(installUrl, trustedHost: trustedHost) else {
            Self.logger.warning("Blockierter Installationslink (nicht vertrauenswürdig): \(installUrl.absoluteString, privacy: .public)")
            respond(requestId: requestId, ok: false, error: "Installationslink ist nicht vertrauenswürdig.")
            return
        }

        let version = payload["version"] as? String
        let build = (payload["build"] as? NSNumber)?.intValue

        let existing = registry.records[appId]
        let isUpdate = existing?.isConfirmedPresent == true
        registry.recordInstallRequested(appId: appId, version: version, build: build, isUpdate: isUpdate)

        let opened = ExternalURLHandler.open(installUrl)
        if opened {
            respond(requestId: requestId, ok: true, data: ["delegated": "native", "started": true])
        } else {
            respond(requestId: requestId, ok: false, error: "Installation konnte nicht gestartet werden.")
        }
    }

    private func handleOpenApp(payload: [String: Any], requestId: String) {
        guard let appId = payload["appId"] as? String, !appId.isEmpty else {
            respond(requestId: requestId, ok: false, error: "Ungültige openApp-Anfrage.")
            return
        }
        guard let entry = KnownAppSchemes.entry(forAppId: appId) else {
            respond(requestId: requestId, ok: false, error: "Für diese App ist kein natives URL-Scheme registriert.")
            return
        }

        let isReachable = registry.refreshConfirmation(for: entry)
        guard isReachable, let url = URL(string: "\(entry.scheme)://") else {
            respond(requestId: requestId, ok: false, error: "Die App scheint nicht installiert zu sein.")
            return
        }

        if ExternalURLHandler.open(url) {
            respond(requestId: requestId, ok: true, data: ["opened": true])
        } else {
            respond(requestId: requestId, ok: false, error: "App konnte nicht geöffnet werden.")
        }
    }

    private func handleCheckForUpdates(requestId: String) {
        registry.refreshAllConfirmations()
        respond(requestId: requestId, ok: true, data: registry.bridgeSnapshot())
    }

    // MARK: - Responses

    private func respond(requestId: String, ok: Bool, data: [String: Any]? = nil, error: String? = nil) {
        guard let webView else { return }
        var detail: [String: Any] = ["requestId": requestId, "ok": ok]
        if let data { detail["data"] = data }
        if let error { detail["error"] = error }

        guard let json = Self.jsonString(from: detail) else { return }
        let js = "window.dispatchEvent(new CustomEvent('demonicNativeResponse', { detail: \(json) }));"
        webView.evaluateJavaScript(js) { _, error in
            if let error {
                Self.logger.error("Antwort an Website fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - JSON helpers

    private static func jsonString(from object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func jsString(_ value: String) -> String {
        jsonString(from: [value])
            .map { String($0.dropFirst().dropLast()) } ?? "\"\""
    }
}
