import SwiftUI

struct ContentView: View {
    @State private var expandPlayer = false
    @Environment(AudioPlayer.self) var audioPlayer

    var body: some View {
        ZStack(alignment: .bottom) {
            // Explicit background prevents transparent/black rendering in iOS 26
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            TabView {
                Tab("Library", systemImage: "music.note.house.fill") {
                    NavigationStack {
                        LibraryView()
                    }
                }

                Tab("Playlists", systemImage: "music.note.list") {
                    NavigationStack {
                        PlaylistsTabView()
                    }
                }

                Tab("Search", systemImage: "magnifyingglass") {
                    NavigationStack {
                        SearchView()
                    }
                }
            }
            .toolbar(expandPlayer ? .hidden : .visible, for: .tabBar)
            .animation(.easeInOut(duration: 0.3), value: expandPlayer)

            if audioPlayer.currentSong != nil && !expandPlayer {
                MiniPlayerBar(expandPlayer: $expandPlayer)
                    .padding(.bottom, 55)
            }

            if expandPlayer {
                GlassPlayer(isExpanded: $expandPlayer)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: expandPlayer)
                    .zIndex(1)
            }
        }
    }
}
