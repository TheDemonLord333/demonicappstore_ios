//
//  DemonicAppStoreApp.swift
//  DemonicAppStore
//
//  Die native Hülle ist bewusst klein: der gesamte Store läuft als
//  Webanwendung in RootView/DemonicWebView. Änderungen am Webserver
//  (Design, Apps, Kategorien, Texte) sind ohne neuen Xcode-Build sichtbar –
//  siehe README, Abschnitt "Web-Update vs. Native Update".
//

import SwiftUI

@main
struct DemonicAppStoreApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
