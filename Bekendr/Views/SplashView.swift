import SwiftUI

/// Kort geanimeerd startscherm (onder de seconde), nooit wachtend op het netwerk.
struct SplashView: View {
    @State private var appeared = false
    @State private var ring = false

    var body: some View {
        ZStack {
            Theme.accentFill.ignoresSafeArea()
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: 2)
                .frame(width: 120, height: 120)
                .scaleEffect(ring ? 2.6 : 0.8)
                .opacity(ring ? 0 : 1)
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { appeared = true }
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) { ring = true }
        }
        .accessibilityLabel("Bekendr")
    }
}
