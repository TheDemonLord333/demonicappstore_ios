//
//  AppInstallRecord.swift
//  DemonicAppStore
//
//  Ein Eintrag in der lokalen Store-Historie (siehe InstalledAppRegistry).
//  WICHTIG: Dies ist eine Historie dessen, was der Demonic App Store beim
//  Nutzer ANGESTOSSEN hat – keine zuverlässige Quelle für Apples tatsächlichen
//  Installationszustand. iOS erlaubt Apps grundsätzlich nicht, den
//  Installationsstatus beliebiger fremder Apps auszulesen.
//

import Foundation

struct AppInstallRecord: Codable, Identifiable, Equatable {
    /// Die App-ID/Slug, wie sie der Server verwendet (`app.id` im Frontend).
    var appId: String

    /// Bundle-Identifier der Ziel-App, falls bekannt.
    var bundleId: String?

    /// Zuletzt vom Server gemeldete Versionsnummer, die installiert werden sollte.
    var knownVersion: String?

    /// Zuletzt vom Server gemeldete Build-Nummer.
    var knownBuild: Int?

    /// Zeitpunkt der letzten Installationsanfrage (Erstinstallation).
    var installRequestedAt: Date?

    /// Zeitpunkt der letzten Update-Anfrage.
    var lastUpdateRequestedAt: Date?

    /// Zeitpunkt, zu dem zuletzt via `canOpenURL` bestätigt werden konnte,
    /// dass die App mit ihrem registrierten URL-Scheme tatsächlich geöffnet
    /// werden kann (bestmögliches, öffentlich verfügbares Signal für
    /// "ist installiert" – siehe KnownAppSchemes).
    var lastConfirmedAt: Date?

    var id: String { appId }

    /// true, wenn wir zuletzt zuverlässig bestätigen konnten, dass die App
    /// über ihr URL-Scheme erreichbar ist.
    var isConfirmedPresent: Bool { lastConfirmedAt != nil }
}
