//
//  LoadingView.swift
//  DemonicAppStore
//
//  Nativer Ladebildschirm im Demonic-Stil (schwarz, dunkles Rot, dezentes
//  Violett), gezeigt bis die Website vollständig geladen ist. Verhindert
//  eine weiße WKWebView beim Start.
//

import SwiftUI

struct LoadingView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.75, green: 0.08, blue: 0.14).opacity(pulse ? 0.55 : 0.28), .clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: 140
                            )
                        )
                        .frame(width: 260, height: 260)
                        .blur(radius: 6)

                    Image("LaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 132)
                        .shadow(color: Color(red: 0.7, green: 0.1, blue: 0.15).opacity(pulse ? 0.85 : 0.45), radius: pulse ? 22 : 10)
                }
                .scaleEffect(pulse ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)

                VStack(spacing: 6) {
                    Text("DEMONIC")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .tracking(6)
                        .foregroundStyle(.white)
                    Text("APP STORE")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .tracking(5)
                        .foregroundStyle(Color(red: 0.62, green: 0.42, blue: 0.85))
                }

                Spacer()

                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(red: 0.82, green: 0.15, blue: 0.2))
                    Text("Store wird geladen …")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 56)
            }
        }
        .onAppear { pulse = true }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.03, blue: 0.06),
                Color(red: 0.02, green: 0.01, blue: 0.02),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    LoadingView()
}
