//
//  OfflineView.swift
//  DemonicAppStore
//
//  Native Offline-/Fehleransicht, wenn der Store-Server nicht erreichbar
//  ist. Kein weißer Fehlerbildschirm, kein technischer Stacktrace für den
//  Nutzer.
//

import SwiftUI

struct OfflineView: View {
    let reason: WebViewStore.FailureReason
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.03, blue: 0.06),
                    Color(red: 0.02, green: 0.01, blue: 0.02),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "bolt.horizontal.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(Color(red: 0.82, green: 0.15, blue: 0.2))
                    .shadow(color: Color(red: 0.7, green: 0.1, blue: 0.15).opacity(0.6), radius: 16)

                VStack(spacing: 8) {
                    Text("DEMONIC APP STORE")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(Color(red: 0.62, green: 0.42, blue: 0.85))

                    Text(reason.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(reason.message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 32)
                }

                Button(action: onRetry) {
                    Text("ERNEUT VERSUCHEN")
                        .font(.subheadline.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(Color(red: 0.7, green: 0.1, blue: 0.15))
                        )
                }
                .padding(.top, 8)

                Spacer()
                Spacer()
            }
        }
    }
}

#Preview {
    OfflineView(reason: .serverUnreachable, onRetry: {})
}
