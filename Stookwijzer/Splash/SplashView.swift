import SwiftUI

/// Geanimeerd splashscreen: vlam springt in beeld en flakkert, vonken stijgen op,
/// daarna schuiven de naam en de drie codekleuren in.
struct SplashView: View {
    var onFinish: () -> Void

    @State private var appear = false
    @State private var flicker = false
    @State private var glow = false
    @State private var showText = false
    @State private var showCodes = false

    var body: some View {
        ZStack {
            // Warme, lichte achtergrond (sluit naadloos aan op de LaunchBackground-kleur)
            LinearGradient(colors: [Color(hex: 0xFFF8F1), Color(hex: 0xFDE7D6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [Theme.ember.opacity(glow ? 0.30 : 0.14), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42),
                           startRadius: 8,
                           endRadius: glow ? 300 : 200)
                .ignoresSafeArea()
                .opacity(appear ? 1 : 0)

            EmberField()
                .opacity(appear ? 1 : 0)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                ZStack {
                    // Gloed achter de vlam
                    Circle()
                        .fill(Theme.flameGold.opacity(0.35))
                        .frame(width: 150, height: 150)
                        .blur(radius: 30)
                        .scaleEffect(glow ? 1.15 : 0.9)

                    FlameLogo(flicker: flicker)
                        .frame(width: 112, height: 140)
                        .shadow(color: Theme.ember.opacity(0.45), radius: 22, y: 10)
                }
                .scaleEffect(appear ? 1 : 0.3)
                .opacity(appear ? 1 : 0)
                .rotationEffect(.degrees(appear ? 0 : -12))

                VStack(spacing: 8) {
                    Text("Stookwijzer")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x2A2320))
                    Text("Kan ik vandaag stoken?")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color(hex: 0x8A7A70))
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 18)

                HStack(spacing: 10) {
                    ForEach(AdviceCode.allCases) { code in
                        Capsule()
                            .fill(code.gradient)
                            .frame(width: showCodes ? 34 : 8, height: 8)
                    }
                }
                .opacity(showCodes ? 1 : 0)
            }
            .offset(y: -20)

            VStack {
                Spacer()
                Text("Data: RIVM Stookwijzer")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: 0xA8968A))
                    .padding(.bottom, 24)
                    .opacity(showText ? 1 : 0)
            }
        }
        .environment(\.colorScheme, .light)
        .task {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.58)) { appear = true }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                flicker = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { showText = true }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { showCodes = true }
            try? await Task.sleep(for: .milliseconds(1700))
            onFinish()
        }
    }
}

/// Opstijgende vonkjes, getekend met Canvas zodat het licht blijft.
struct EmberField: View {
    var count = 26

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let seed = Double(i) * 12.9898
                    let rnd = seed - floor(seed)                          // 0…1
                    let rnd2 = sin(seed * 1.7) * 0.5 + 0.5                // 0…1
                    let speed = 0.07 + rnd2 * 0.10
                    let progress = (t * speed + rnd).truncatingRemainder(dividingBy: 1)

                    let x = size.width * (0.5 + 0.38 * sin(seed * 3.1))
                        + sin(t * 1.3 + seed) * 14
                    let y = size.height * (0.78 - progress * 0.62)
                    let r = 1.4 + rnd2 * 2.6
                    let alpha = sin(progress * .pi) * 0.75

                    let color = i % 3 == 0 ? Theme.flameGold : Theme.ember
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    SplashView {}
}
