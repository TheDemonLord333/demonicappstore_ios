//
//  InstalledAppRegistry.swift
//  DemonicAppStore
//
//  Lokale, persistente Store-Historie: welche Apps hat der Nutzer über den
//  Demonic App Store zur Installation/zum Update angestoßen, und für welche
//  davon konnten wir zuletzt über `canOpenURL` (öffentliche Apple-API)
//  bestätigen, dass sie tatsächlich über ihr URL-Scheme erreichbar sind.
//
//  WICHTIG: Das ist explizit KEINE zuverlässige Abfrage von Apples echtem
//  Installationszustand beliebiger Apps – iOS bietet dafür bewusst keine
//  öffentliche API. Ohne ein registriertes URL-Scheme (KnownAppSchemes)
//  kann eine App grundsätzlich nicht als "installiert" bestätigt werden;
//  in diesem Fall bleibt der Zustand in der Web-UI konservativ bei
//  "install", statt einen falschen Zustand vorzutäuschen.
//
//  Persistenz: einfache Codable-JSON-Datei im Application-Support-Verzeichnis
//  der App – bewusst keine Datenbank, die Datenmenge ist minimal.
//

import Foundation
import UIKit
import OSLog

@MainActor
final class InstalledAppRegistry: ObservableObject {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DemonicAppStore", category: "Registry")

    @Published private(set) var records: [String: AppInstallRecord] = [:]

    private let fileURL: URL

    init() {
        let fileManager = FileManager.default
        let baseDir = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        let appDir = baseDir.appendingPathComponent("DemonicAppStore", isDirectory: true)
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.fileURL = appDir.appendingPathComponent("installed-apps-registry.json")
        self.records = Self.load(from: fileURL)
    }

    // MARK: - Mutating actions

    /// Eine Installation (oder ein Update) wurde über die Bridge angestoßen.
    /// `isUpdate` bestimmt nur, welcher Zeitstempel gesetzt wird – der
    /// eigentliche Installationsvorgang läuft in beiden Fällen über denselben
    /// von Apple unterstützten OTA-Mechanismus (itms-services).
    func recordInstallRequested(appId: String, version: String?, build: Int?, isUpdate: Bool) {
        var record = records[appId] ?? AppInstallRecord(appId: appId)
        if let entry = KnownAppSchemes.entry(forAppId: appId) {
            record.bundleId = entry.bundleId
        }
        if let version { record.knownVersion = version }
        if let build { record.knownBuild = build }

        let now = Date()
        if isUpdate {
            record.lastUpdateRequestedAt = now
        } else {
            record.installRequestedAt = now
        }
        // Eine neue Installations-/Update-Anfrage entwertet die vorherige
        // Bestätigung, bis wir sie erneut per canOpenURL nachweisen können.
        record.lastConfirmedAt = nil

        records[appId] = record
        persist()
        Self.logger.info("installRequested appId=\(appId, privacy: .public) isUpdate=\(isUpdate)")
    }

    /// Bestätigt (oder widerlegt) anhand von `UIApplication.canOpenURL`, ob
    /// eine bekannte App aktuell über ihr URL-Scheme erreichbar ist.
    @discardableResult
    func refreshConfirmation(for entry: KnownAppSchemes.Entry) -> Bool {
        guard let url = URL(string: "\(entry.scheme)://") else { return false }
        let isReachable = UIApplication.shared.canOpenURL(url)

        var record = records[entry.appId] ?? AppInstallRecord(appId: entry.appId)
        record.bundleId = entry.bundleId
        record.lastConfirmedAt = isReachable ? Date() : nil
        records[entry.appId] = record
        return isReachable
    }

    /// Aktualisiert die Bestätigung für alle bekannten Apps (z. B. bei
    /// `checkForUpdates()` oder wenn die App aus dem Hintergrund zurückkehrt).
    func refreshAllConfirmations() {
        for entry in KnownAppSchemes.entries {
            refreshConfirmation(for: entry)
        }
        persist()
    }

    // MARK: - Snapshot for the web bridge

    /// Liefert exakt die Form, die `nativeBridge.js` erwartet:
    /// `{ [appId]: { version, build } }` – ausschließlich für Apps, deren
    /// Erreichbarkeit zuletzt bestätigt wurde.
    func bridgeSnapshot() -> [String: [String: Any]] {
        var snapshot: [String: [String: Any]] = [:]
        for (appId, record) in records where record.isConfirmedPresent {
            var entry: [String: Any] = [:]
            entry["version"] = record.knownVersion ?? ""
            if let build = record.knownBuild {
                entry["build"] = build
            }
            snapshot[appId] = entry
        }
        return snapshot
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Self.logger.error("Registry konnte nicht gespeichert werden: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from url: URL) -> [String: AppInstallRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: AppInstallRecord].self, from: data)) ?? [:]
    }
}
