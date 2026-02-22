import SwiftUI

struct SearchView: View {
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    
    @State private var query = ""
    @State private var results: SearchResult3?
    @State private var isSearching = false
    
    var body: some View {
        List {
            if let results = results {
                // Artists
                if let artists = results.artist, !artists.isEmpty {
                    Section("Artists") {
                        ForEach(artists) { artist in
                            NavigationLink(destination: ArtistDetailView(artistId: artist.id, artistName: artist.name)) {
                                HStack {
                                    CachedAsyncImage(url: client.getCoverArtURL(id: artist.coverArt ?? "", size: 100)) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    
                                    Text(artist.name)
                                }
                            }
                        }
                    }
                }
                
                // Albums
                if let albums = results.album, !albums.isEmpty {
                    Section("Albums") {
                        ForEach(albums) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                HStack {
                                    CachedAsyncImage(url: client.getCoverArtURL(id: album.coverArt ?? "", size: 100)) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    VStack(alignment: .leading) {
                                        Text(album.displayName)
                                        Text(album.artist ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Songs
                if let songs = results.song, !songs.isEmpty {
                    Section("Songs") {
                        ForEach(songs) { song in
                            Button {
                                audioPlayer.play(song: song)
                            } label: {
                                HStack {
                                    CachedAsyncImage(url: client.getCoverArtURL(id: song.coverArt ?? "", size: 100)) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    HStack(spacing: 6) {
                                        if audioPlayer.currentSong?.id == song.id {
                                            if audioPlayer.isPlaying {
                                                NowPlayingBarsView(color: audioPlayer.primaryAccent).frame(width: 14, height: 14)
                                            } else {
                                                NowPlayingBarsPausedView(color: audioPlayer.primaryAccent).frame(width: 14, height: 14)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text(song.title)
                                                .foregroundStyle(audioPlayer.currentSong?.id == song.id ? audioPlayer.primaryAccent : .primary)
                                            Text(song.artist ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Artists, Albums, Songs")
        .onChange(of: query) { oldValue, newValue in
            Task {
                if newValue.isEmpty {
                    results = nil
                    return
                }
                // Simple debounce handling could go here.
                // For now, simple delay or direct call
                try? await Task.sleep(nanoseconds: 500_000_000)
                if newValue == query {
                    await performSearch()
                }
            }
        }
        .navigationTitle("Search")
    }
    
    func performSearch() async {
        isSearching = true
        do {
            self.results = try await client.search(query: query)
        } catch {
            print("Search error: \(error)")
        }
        isSearching = false
    }
}
