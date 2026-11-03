import SwiftUI

/// Druppelvormige vlam, schaalt mee met het frame.
struct FlameShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + w * x, y: r.minY + h * y) }

        var p = Path()
        p.move(to: pt(0.5, 0))
        p.addCurve(to: pt(0.94, 0.63), control1: pt(0.60, 0.20), control2: pt(1.02, 0.36))
        p.addCurve(to: pt(0.5, 1.0), control1: pt(0.88, 0.87), control2: pt(0.70, 1.0))
        p.addCurve(to: pt(0.06, 0.63), control1: pt(0.30, 1.0), control2: pt(0.12, 0.87))
        p.addCurve(to: pt(0.5, 0), control1: pt(-0.02, 0.36), control2: pt(0.40, 0.20))
        p.closeSubpath()
        return p
    }
}

/// Gelaagd vlam-logo. Met `flicker` aan/uit wisselend animeert hij als een echte vlam.
struct FlameLogo: View {
    var flicker: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .bottom) {
                FlameShape()
                    .fill(LinearGradient(colors: [Theme.flameRed, Theme.ember], startPoint: .bottom, endPoint: .top))
                    .scaleEffect(x: flicker ? 0.97 : 1.02, y: flicker ? 1.04 : 0.97, anchor: .bottom)

                FlameShape()
                    .fill(LinearGradient(colors: [Theme.ember, Theme.flameGold], startPoint: .bottom, endPoint: .top))
                    .frame(width: w * 0.64, height: h * 0.66)
                    .scaleEffect(x: flicker ? 1.05 : 0.95, y: flicker ? 0.94 : 1.06, anchor: .bottom)
                    .offset(y: -h * 0.05)

                FlameShape()
                    .fill(LinearGradient(colors: [Theme.flameGold, Theme.flameCore], startPoint: .bottom, endPoint: .top))
                    .frame(width: w * 0.32, height: h * 0.36)
                    .scaleEffect(flicker ? 1.08 : 0.92, anchor: .bottom)
                    .offset(y: -h * 0.08)
            }
            .frame(width: w, height: h, alignment: .bottom)
        }
        .aspectRatio(0.8, contentMode: .fit)
    }
}

#Preview {
    FlameLogo().frame(width: 120).padding()
}
