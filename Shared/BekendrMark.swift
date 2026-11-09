import SwiftUI

/// Het beeldmerk van Bekendr: een locatiespeld met een bekendmaking erin.
struct BekendrMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                .fill(Theme.accentFill)
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
