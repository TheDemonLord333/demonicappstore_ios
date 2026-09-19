# Demonic App Store – iOS

Native iOS-Hülle für den bestehenden **Demonic App Store**
(`https://github.com/TheDemonLord333/demonicappstore_web`). Die App ist
bewusst dünn: die komplette Store-Oberfläche und Geschäftslogik bleiben auf
dem Webserver. Die native App lädt die bestehende Website in einer
`WKWebView` und stellt ihr über die bereits im Webprojekt definierte
Schnittstelle (`client/native/nativeBridge.js` / `window.DemonicNative`)
zusätzliche native Fähigkeiten zur Verfügung.

```
Demonic App Store Server
        │  HTTPS
        ▼
   Web-Anwendung
        │
   ┌────┴────┐
   │         │
Safari   iOS App
           │
       WKWebView
           │
  Swift Native Bridge (window.DemonicNative)
```

**Grundprinzip:** Ändert sich nur die Webanwendung (Design, Apps, Kategorien,
Texte, Buttons), ist **kein neuer Xcode-Build** nötig – die iOS-App zeigt die
Änderung beim nächsten Laden automatisch an. Nur echte native Änderungen
(neue Bridge-Fähigkeit, neues App-Scheme, neue Berechtigung) erfordern einen
neuen Build. Siehe [Web-Update vs. Native Update](#web-update-vs-native-update).

---

## Inhaltsverzeichnis

1. [Projektstruktur](#projektstruktur)
2. [Xcode öffnen & konfigurieren](#xcode-öffnen--konfigurieren)
3. [Store-Domain konfigurieren](#store-domain-konfigurieren)
4. [App Icon](#app-icon)
5. [Build auf dem eigenen iPhone](#build-auf-dem-eigenen-iphone)
6. [Native Bridge – Vertrag](#native-bridge--vertrag)
7. [Installations-/Update-Fluss](#installations--update-fluss)
8. [Eigene Apps mit Custom Scheme öffnen](#eigene-apps-mit-custom-scheme-öffnen)
9. [Sicherheitsmodell](#sicherheitsmodell)
10. [Web-Update vs. Native Update](#web-update-vs-native-update)
11. [Empfohlene (optionale) Änderung an nativeBridge.js](#empfohlene-optionale-änderung-an-nativebridgejs)
12. [Archive erstellen & Ad-hoc-Verteilung](#archive-erstellen--ad-hoc-verteilung)
13. [Grenzen / was diese App bewusst NICHT tut](#grenzen--was-diese-app-bewusst-nicht-tut)
14. [Manueller Testplan](#manueller-testplan)
15. [Troubleshooting](#troubleshooting)

---

## Projektstruktur

```
DemonicAppStore/
├── App/
│   ├── DemonicAppStoreApp.swift   @main SwiftUI-App
│   └── AppConfiguration.swift     EINZIGE Stelle mit der Store-URL
├── Web/
│   ├── DemonicWebView.swift       UIViewRepresentable-Wrapper um die WKWebView
│   ├── WebViewStore.swift         Hält die eine WKWebView-Instanz, Ladezustand
│   ├── WebViewCoordinator.swift   WKNavigationDelegate/WKUIDelegate
│   └── NavigationPolicy.swift     intern/extern/Install-Link/Scheme/blockieren
├── Bridge/
│   ├── NativeBridge.swift         window.DemonicNative-Injection + Message-Handler
│   └── NativeBridgeModels.swift   NativeMessage, Command-Whitelist, Device-Info, KnownAppSchemes
├── Services/
│   ├── InstalledAppRegistry.swift lokale Store-Historie (Codable + JSON-Datei)
│   ├── NetworkMonitor.swift       NWPathMonitor-Wrapper
│   ├── ExternalURLHandler.swift   UIApplication.open-Wrapper
│   └── InstallLinkValidator.swift validiert itms-services-/Install-Links
├── Views/
│   ├── RootView.swift             WebView + Loading-/Offline-Overlays
│   ├── LoadingView.swift          nativer Ladebildschirm (Demonic-Stil)
│   └── OfflineView.swift          native Offline-/Fehleransicht
├── Models/
│   └── AppInstallRecord.swift     Codable-Model der Registry-Einträge
├── Assets.xcassets/
│   ├── AppIcon.appiconset/        aus dem bereitgestellten Icon generiert
│   ├── LaunchIcon.imageset/       dasselbe Icon für Launch-Screen/LoadingView
│   ├── LaunchBackgroundColor.colorset/  #0B0A10 (wie manifest.webmanifest)
│   └── AccentColor.colorset/
└── Info.plist
```

## Xcode öffnen & konfigurieren

1. `DemonicAppStore.xcodeproj` in Xcode öffnen.
2. Projekt-Navigator → Target **DemonicAppStore** → *Signing & Capabilities*:
   - **Team**: dein Apple-Developer-Team auswählen (aktuell hinterlegt:
     `LWL7HM459L` – ggf. auf dein eigenes Team ändern).
   - **Bundle Identifier**: aktuell `me.thedemonlord333.DemonicAppStore` –
     bei Bedarf anpassen (muss zu deinem Provisioning Profile passen).
   - *Automatically manage signing* bleibt aktiviert; Xcode/Apple Developer
     kümmern sich um Zertifikate & Provisioning Profiles. Die App selbst
     erzeugt oder manipuliert diese nicht.
3. Scheme **DemonicAppStore** auswählen, Zielgerät (dein iPhone oder
   Simulator) wählen.

## Store-Domain konfigurieren

Einzige Stelle: [`DemonicAppStore/App/AppConfiguration.swift`](DemonicAppStore/App/AppConfiguration.swift)

```swift
static let storeURL: URL = URL(string: "https://das.thedemonlord333.me")!
```

Der Wert stammt aus `demonicappstore_web/.env.example` (`BASE_URL`). Soll die
App auf eine andere Domain zeigen, genügt es, diese eine Zeile zu ändern –
`trustedHost` (Navigationsregeln, Bridge-Origin-Prüfung) wird automatisch
daraus abgeleitet. **Kein zweiter Ort im Projekt referenziert die Domain
fest.**

## App Icon

Das bereitgestellte Icon (`ChatGPT Image 19. Sept. 2026, 08_11_05.png`,
1254×1254 px) wurde unverändert im Seitenverhältnis verwendet, verlustfrei in
alle von Apple benötigten Home-Screen-/Settings-/Spotlight-/App-Store-Größen
skaliert (`DemonicAppStore/Assets.xcassets/AppIcon.appiconset/`) und dort als
`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` referenziert. Für den
1024×1024-App-Store-Eintrag wurde die im Original vorhandene Transparenz auf
einen schwarzen Hintergrund (passend zum Demonic-Dark-Theme) geflacht, da
Apple dort keinen Alphakanal akzeptiert – alle anderen Eigenschaften (Motiv,
Proportionen, keine zusätzliche Rundung) blieben unverändert. iOS übernimmt
die Maskierung/Rundung selbst.

Dieselbe Grafik (diesmal mit erhaltener Transparenz) liegt zusätzlich als
`LaunchIcon`-Imageset vor und wird auf dem nativen Launch-/Loading-Screen
verwendet.

## Build auf dem eigenen iPhone

1. iPhone per Kabel/WLAN mit dem Mac verbinden, in Xcode als Ziel wählen.
2. ⌘R (Run). Bei erstem Start ggf. auf dem iPhone unter
   *Einstellungen → Allgemein → VPN & Geräteverwaltung* dem
   Entwicklerprofil vertrauen.
3. Die App zeigt zuerst den nativen Ladebildschirm, lädt danach
   `https://das.thedemonlord333.me` in der WKWebView.

## Native Bridge – Vertrag

`client/native/nativeBridge.js` (im Webprojekt) definiert bereits den
vollständigen Vertrag; diese App implementiert ihn **kompatibel, ohne ihn neu
zu erfinden**:

- Vor Dokumentstart injiziert `NativeBridge.injectionScript(...)` (siehe
  `Bridge/NativeBridge.swift`) ein `window.DemonicNative`-Objekt mit:
  - `platform: "ios"`, `deviceType: "iphone" | "ipad"`
  - `storeVersion` (von nativeBridge.js bereits erwartet) sowie zusätzlich
    `nativeAppVersion` / `nativeBuild` – aus `CFBundleShortVersionString`
    bzw. `CFBundleVersion`, nirgendwo doppelt hartkodiert.
  - `installedApps: { [appId]: { version, build } }` – synchron, aus der
    lokalen `InstalledAppRegistry`.
  - `installApp(appId, installUrl)`, `openApp(appId)`, `checkForUpdates()` –
    exakt die von nativeBridge.js erwarteten Methoden inkl. des dort
    dokumentierten Zwei-Aufruf-Musters (erst ohne, dann mit `requestId`).
  - Zusätzlich, rein additiv: `getPlatform()`, `getDeviceInfo()`,
    `getInstalledVersions()` – synchron, kein bestehendes Verhalten wird
    dadurch verändert.
- Nachrichten von JavaScript nach Swift laufen ausschließlich über
  `webkit.messageHandlers.demonicNative.postMessage(...)`. Nur vier
  Kommandos werden akzeptiert (`installApp`, `openApp`, `checkForUpdates`,
  `getInstalledApps` – siehe `NativeCommand` in `NativeBridgeModels.swift`).
  Jedes andere `command` wird ignoriert; es gibt keine generische
  "führe beliebige Funktion aus"-Fähigkeit.
- Antworten gehen über `window.dispatchEvent(new CustomEvent('demonicNativeResponse', { detail: { requestId, ok, data, error } }))`
  – genau das von nativeBridge.js erwartete Event.
- Zusätzlich (rein additiv, kein bestehender Vertrag wird verändert) sendet
  die Bridge bei App-Lifecycle-Ereignissen
  `window.dispatchEvent(new CustomEvent('demonicNativeEvent', { detail: { type, ... } }))`
  mit `type` ∈ `appDidBecomeActive`, `networkChanged`, `registryChanged`.
  nativeBridge.js hört diese Events heute nicht ab – die Website kann optional
  einen `window.addEventListener('demonicNativeEvent', ...)` ergänzen, um z. B.
  nach Rückkehr aus dem Hintergrund Daten neu zu laden. Ohne einen solchen
  Listener passiert schlicht nichts (kein Bruch bestehenden Verhaltens).

**Es wurde keine einzige Datei im Webprojekt verändert.** Eine kleine,
optionale Erweiterung ist unten dokumentiert, aber nicht erforderlich, damit
die Bridge funktioniert.

## Installations-/Update-Fluss

1. Nutzer tippt in der Website auf "Installieren"/"Update".
2. `nativeBridge.js` ruft `window.DemonicNative.installApp(app.id, app.installUrl)` auf.
3. Swift validiert den `installUrl` (muss ein `itms-services://`-Link sein,
   dessen eingebettete Manifest-URL auf die vertrauenswürdige Store-Domain
   zeigt – erzeugt von `server/services/manifestService.js`) und öffnet ihn
   über `UIApplication.open` – **Apples offizieller OTA-Installationsweg**
   für Ad-hoc-/In-House-signierte IPAs. Es wird nichts an Code-Signing,
   Provisioning Profiles oder Gerätefreigaben vorbeigeschleust.
4. `InstalledAppRegistry` merkt sich `installRequestedAt` (bzw.
   `lastUpdateRequestedAt`) – das ist eine **Store-Historie**, kein Beweis
   für eine erfolgreiche Installation.
5. Sobald die App das nächste Mal über ihr registriertes URL-Scheme
   erreichbar ist (`UIApplication.canOpenURL`, öffentliche API), markiert die
   Registry sie als bestätigt (`lastConfirmedAt`) und meldet sie fortan in
   `installedApps` – ausschließlich dann wechselt `resolveAppState()` in der
   Website von "Installieren" zu "Öffnen"/"Update".

Ohne registriertes URL-Scheme (siehe unten) kann iOS grundsätzlich nicht
zuverlässig bestätigen, dass eine App installiert ist – die Bridge zeigt dann
bewusst weiterhin "Installieren" an, statt einen falschen Zustand
vorzutäuschen.

## Eigene Apps mit Custom Scheme öffnen

`Bridge/NativeBridgeModels.swift` → `KnownAppSchemes` ist eine **feste,
kontrollierte Whitelist** (kein aus Webinhalten übernommenes Scheme):

```swift
Entry(appId: "demonic-slots", bundleId: "me.thedemonlord333.DemonicSlots", scheme: "demonicslots")
```

Eine neue App mit eigenem Scheme hinzuzufügen ist eine **native Änderung**:

1. Eintrag in `KnownAppSchemes.entries` ergänzen.
2. Das Scheme zusätzlich in `Info.plist` unter `LSApplicationQueriesSchemes`
   eintragen (sonst liefert `canOpenURL` immer `false`).
3. Neuen Build erstellen und verteilen.

## Sicherheitsmodell

- **Domain-Validierung**: Bridge-Nachrichten werden nur akzeptiert, wenn
  `WKScriptMessage.frameInfo` Hauptframe + HTTPS + Host == `AppConfiguration.trustedHost`
  ist (`NativeBridge.handle(message:)`). Eine fremde Seite bekommt selbst
  dann keinen Zugriff, wenn sie irgendwie in der WKWebView landen würde.
- **Navigation**: `NavigationPolicy.decide(for:)` erzwingt:
  - interne HTTPS-URL (Store-Domain) → in der WKWebView
  - `itms-services://` mit auf die Store-Domain zeigender Manifest-URL →
    `UIApplication.open` (System-Installationsfluss)
  - externe HTTPS-URL → `UIApplication.open` (Safari), verlässt die
    privilegierte WKWebView
  - `mailto:`/`tel:`/`sms:`/`facetime:` → System-Handler
  - registriertes Custom Scheme (Whitelist) → `UIApplication.open`
  - `javascript:`, `file:`, `data:`, `blob:`, alles Unbekannte → blockiert
- **Message-Whitelist**: nur `installApp`, `openApp`, `checkForUpdates`,
  `getInstalledApps` werden verarbeitet; Payloads werden vollständig
  typgeprüft (`NativeMessage`, `handleInstallApp`, `handleOpenApp`).
- **Install-Link-Validierung** (`InstallLinkValidator`): wird sowohl von der
  Navigationsregel als auch vom Bridge-Handler verwendet – ein
  `itms-services`-Link wird nur akzeptiert, wenn seine eingebettete
  `url`-Query-Komponente eine HTTPS-URL auf die Store-Domain ist.
- **Kein `NSAllowsArbitraryLoads`**, keine ATS-Sonderausnahmen – die App
  verlässt sich auf das gültige HTTPS-Zertifikat der Store-Domain.
- Erwogen, aber bewusst weggelassen: **App-Bound Domains**
  (`WKAppBoundDomains`/`limitsNavigationsToAppBoundDomains`). Die bereits
  vorhandene Origin-Prüfung pro Nachricht plus die Navigationsregel decken
  denselben Bedrohungsfall ab, ohne die WKWebView-Funktionalität
  (max. 10 Domains, eingeschränkte Frame-Navigation) zusätzlich
  einzuschränken.
- **Keine Passwörter/Session-Tokens werden geloggt.** `OSLog`-Kategorien:
  `WebView`, `Bridge`, `Network`, `Registry`.
- **Keine Analytics, kein Tracking, keine Advertising-ID.**

## Web-Update vs. Native Update

**Web-Update** (nur Server deployen, **kein neuer Xcode-Build**):

- CSS/Design geändert
- neue App im Store hinzugefügt
- Kategorie hinzugefügt/geändert
- Beschreibungstexte, Buttons, Reihenfolge geändert
- neue App-Version im Admin-Bereich veröffentlicht

**Native Update** (neuer Xcode-Build + neue Verteilung nötig):

- neue Bridge-Fähigkeit/-Kommando
- neues Custom-URL-Scheme in `KnownAppSchemes` + `Info.plist`
- Änderung an der WKWebView-Integration/Navigationsregel
- neue native Berechtigung (Info.plist)
- Store-Domain-Wechsel in `AppConfiguration.swift`

## Empfohlene (optionale) Änderung an nativeBridge.js

Die Bridge funktioniert **vollständig ohne jede Änderung am Webprojekt** –
diese Session hatte ohnehin nur Lesezugriff auf
`demonicappstore_web` und hat dort nichts verändert.

Für **präzisere Versionsangaben** in der lokalen Registry (die Website
vergleicht `installed.version` mit `app.version`; ohne Versionsangabe liefert
`installApp` schlicht keine Version mit, wodurch `resolveAppState()` – dank
JavaScript-Falsy-Semantik bei leerem String – konservativ "Öffnen" statt
"Update" anzeigt, niemals einen falschen Zustand) kann optional folgende
rückwärtskompatible Erweiterung an `client/native/nativeBridge.js`
vorgenommen werden:

```diff
   async function installApp(app) {
     if (hasNativeObject() && typeof global.DemonicNative.installApp === 'function') {
-      return callNative('installApp', app.id, app.installUrl);
+      // Rückwärtskompatible Erweiterung: version/build werden zusätzlich
+      // übergeben, damit die native Store-Historie präzise Versionsdaten
+      // führen kann. Ältere native Implementierungen, die nur (appId,
+      // installUrl) lesen, funktionieren unverändert weiter.
+      return callNative('installApp', app.id, app.installUrl, app.version, app.build);
     }
     if (app.installUrl) {
       global.location.href = app.installUrl;
       return { ok: true, delegated: 'browser' };
     }
     throw new Error('Für diese App ist keine Installations-URL hinterlegt.');
   }
```

Die native Seite liest `version`/`build` bereits heute defensiv (optional,
per Positionserkennung über die stabile `req_<timestamp>_<counter>`-Form der
`requestId` – funktioniert mit und ohne diesen Patch, siehe Kommentar in
`NativeBridge.injectionScript`). Diese Änderung ist rein additiv, ändert
keine bestehende Signatur und bricht keine Browser-Fallback-Funktionalität.

## Archive erstellen & Ad-hoc-Verteilung

1. Xcode → *Product → Scheme* → sicherstellen, dass **Any iOS Device**
   (nicht Simulator) als Ziel gewählt ist.
2. *Product → Archive*.
3. Im Organizer: Archiv auswählen → *Distribute App* → **Ad Hoc**.
4. Provisioning Profile: entweder automatisch von Xcode verwalten lassen
   (empfohlen) oder ein manuell im Apple Developer Portal erstelltes
   Ad-hoc-Profil auswählen, das die gewünschten **registrierten Geräte**
   enthält (Geräte vorher unter *Certificates, Identifiers & Profiles →
   Devices* hinzufügen).
5. Xcode exportiert eine `.ipa`. Diese kann z. B. über den eigenen Demonic
   App Store selbst (als neue "App" mit eigenem Eintrag,
   `distributionType = manifest`, hochgeladener IPA) oder einen anderen von
   Apple unterstützten OTA-Weg an registrierte Geräte verteilt werden.
6. Eine neue native Store-Version verteilen = neues Archiv mit erhöhter
   `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` (Xcode-Projekteinstellungen)
   + erneuter Export/Verteilung. Reine Webänderungen benötigen diesen
   Schritt **nicht**.

Die App selbst erzeugt, signiert oder manipuliert keine Zertifikate oder
Provisioning Profiles – das bleibt vollständig Aufgabe von Xcode/Apple
Developer.

## Grenzen / was diese App bewusst NICHT tut

- Kein Auslesen aller installierten Apps des Geräts (von iOS nicht
  vorgesehen). Die `InstalledAppRegistry` ist eine **Store-Historie**, kein
  Ersatz für Apples echten Installationsstatus.
- Keine Umgehung von Code Signing, Provisioning Profiles, Gerätefreigaben
  oder sonstigen iOS-Sicherheitsmechanismen.
- Keine privaten Apple-APIs, kein Jailbreak, keine Exploits.
- Keine zweite native Store-Oberfläche, keine doppelte Navigation/TabBar –
  die Website nutzt praktisch den gesamten Bildschirm.

## Manueller Testplan

Da dieses Projekt in einer Linux-Umgebung ohne Xcode/iOS-Simulator erstellt
wurde, konnte der Build hier **nicht** durch einen echten Xcode-Compile-Lauf
verifiziert werden. Bitte vor dem ersten produktiven Einsatz in Xcode
durchgehen:

- [ ] Projekt kompiliert ohne Fehler/Warnungen (insbesondere AppIcon-Warnungen)
- [ ] Loading Screen erscheint sofort, keine weiße Fläche
- [ ] Store lädt (Home, Suche, App-Detail, Updates, Admin-Login)
- [ ] SPA-Routing (Zurück/Vor per Swipe-Geste) funktioniert
- [ ] Admin-Login + Cookie-Session bleibt nach App-Neustart erhalten
- [ ] Pull-to-Refresh lädt dieselbe WKWebView neu (kein Flackern/Neuaufbau)
- [ ] Flugmodus an → native Offline-Ansicht, "Erneut versuchen" funktioniert
- [ ] Flugmodus aus während Offline-Ansicht sichtbar → automatischer Retry
- [ ] Externer Link (z. B. `https://apple.com`) öffnet Safari, nicht die App
- [ ] `itms-services://`-Installationslink öffnet den System-Installationsdialog
- [ ] Unbekanntes Scheme (z. B. `foo://bar`) wird blockiert (kein Absturz)
- [ ] App in den Hintergrund → Vordergrund: kein Full-Reload, `appDidBecomeActive` wird ausgelöst
- [ ] Rotation (iPhone Portrait/Landscape, iPad alle Richtungen)
- [ ] Safe Areas/Dynamic Island: keine weißen Ränder
- [ ] Tastatur bei Login/Suche: Eingabefeld bleibt sichtbar
- [ ] Registry übersteht App-Neustart (Datei in Application Support)

## Troubleshooting

**AppIcon-Warnung beim Build** — Assets.xcassets/AppIcon.appiconset prüfen;
alle 18 generierten Größen müssen vorhanden sein und exakt zu ihrer in
`Contents.json` deklarierten Pixelgröße passen (wurden aus dem Originalbild
per Lanczos-Resampling erzeugt).

**Installation über itms-services startet nicht** — siehe auch
Web-Repo-README: erfordert gültiges HTTPS-Zertifikat (kein Self-Signed) und
eine korrekt signierte IPA. Zusätzlich native Seite prüfen: Der Link wird nur
akzeptiert, wenn seine `url`-Query-Komponente auf `AppConfiguration.trustedHost`
zeigt (siehe `InstallLinkValidator`) – bei einem Domain-Wechsel
`AppConfiguration.storeURL` aktualisieren.

**`openApp()` liefert immer "nicht installiert"** — Scheme fehlt entweder in
`KnownAppSchemes.entries` oder in `Info.plist` → `LSApplicationQueriesSchemes`
(beides ist nötig, siehe oben).
