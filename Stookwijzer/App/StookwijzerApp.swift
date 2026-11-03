import SwiftUI

@main
struct StookwijzerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Toont eerst het splashscreen en laadt ondertussen al het advies op de achtergrond.
struct RootView: View {
    @State private var showSplash = true
    @State private var places = PlaceStore()
    @State private var advice = AdviceViewModel()
    @State private var location = LocationManager()

    var body: some View {
        ZStack {
            ContentView()
                .environment(places)
                .environment(advice)
                .environment(location)
                .environment(PushManager.shared)
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.55)) { showSplash = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.12)))
                .zIndex(1)
            }
        }
        .tint(Theme.ember)
    }
}
