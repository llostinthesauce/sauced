import SwiftUI

@main
struct PrismMusicApp: App {
    @State private var audioPlayer = AudioPlayer.shared
    @State private var navidromeClient = NavidromeClient.shared
    @State private var pinStore = PinStore.shared
    @State private var artworkStore = PlaylistArtworkStore.shared
    @State private var themeStore = ThemeStore.shared
    @State private var errorBanner = ErrorBanner.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !navidromeClient.baseURL.isEmpty {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environment(audioPlayer)
            .environment(navidromeClient)
            .environment(pinStore)
            .environment(artworkStore)
            .environment(themeStore)
            .environment(errorBanner)
            .preferredColorScheme(themeStore.selectedTheme.colorScheme)
            .onChange(of: themeStore.selectedTheme) { _, newTheme in
                // Only apply theme mesh colors if the player hasn't overridden them with artwork colors.
                // We update the default so it takes effect between tracks or on launch.
                audioPlayer.accentColors = newTheme.meshColors
            }
            .onAppear {
                // Apply theme defaults on first launch.
                audioPlayer.accentColors = themeStore.selectedTheme.meshColors
            }
        }
    }
}
