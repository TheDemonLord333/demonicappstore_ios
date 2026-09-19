//
//  NativeBridgeModels.swift
//  DemonicAppStore
//
//  Typen und die feste Kommando-Whitelist für die Kommunikation zwischen der
//  Website (client/native/nativeBridge.js) und der nativen Hülle.
//

import Foundation
import UIKit

/// Die einzigen Nachrichten, die von JavaScript nach Swift akzeptiert werden.
/// Jedes andere `command` wird ohne Ausführung verworfen (siehe NativeBridge).
enum NativeCommand: String, CaseIterable {
    case installApp
    case openApp
    case checkForUpdates
    case getInstalledApps
}

/// Vom Frontend über `webkit.messageHandlers.demonicNative.postMessage(...)`
/// gesendete Nachricht. Wird defensiv aus dem rohen `[String: Any]`-Body
/// des `WKScriptMessage` dekodiert – nichts wird ungeprüft übernommen.
struct NativeMessage {
    let command: NativeCommand
    let requestId: String?
    let payload: [String: Any]

    init?(body: Any) {
        guard let dict = body as? [String: Any],
              let rawCommand = dict["command"] as? String,
              let command = NativeCommand(rawValue: rawCommand) else {
            return nil
        }
        self.command = command
        self.requestId = dict["requestId"] as? String
        self.payload = (dict["payload"] as? [String: Any]) ?? [:]
    }
}

/// Statische Geräte-/App-Informationen, die synchron in `window.DemonicNative`
/// injiziert werden (kein Roundtrip nötig).
struct NativeDeviceInfo {
    let platform: String
    let deviceType: String
    let nativeAppVersion: String
    let nativeBuild: String

    @MainActor
    static var current: NativeDeviceInfo {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return NativeDeviceInfo(
            platform: "ios",
            deviceType: isPad ? "ipad" : "iphone",
            nativeAppVersion: AppConfiguration.nativeAppVersion,
            nativeBuild: AppConfiguration.nativeBuild
        )
    }
}

/// Kontrollierte Whitelist eigener Apps mit eigenem URL-Scheme, die der
/// Store per `openApp()` öffnen darf. NICHT aus Webinhalten übernehmen –
/// neue Einträge sind eine bewusste native Codeänderung (siehe README,
/// Abschnitt "Native Update").
///
/// Jeder Eintrag muss zusätzlich im Info.plist unter
/// `LSApplicationQueriesSchemes` stehen, sonst liefert `canOpenURL` immer
/// `false`.
enum KnownAppSchemes {
    struct Entry {
        let appId: String
        let bundleId: String
        let scheme: String
    }

    static let entries: [Entry] = [
        Entry(appId: "demonic-slots", bundleId: "me.thedemonlord333.DemonicSlots", scheme: "demonicslots"),
    ]

    static func entry(forAppId appId: String) -> Entry? {
        entries.first { $0.appId == appId }
    }

    static var allSchemes: [String] { entries.map(\.scheme) }
}
