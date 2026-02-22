import SwiftUI

// MARK: - Artist List View
struct ArtistListView: View {
    @Environment(NavidromeClient.self) var client
    @State private var indices: [ArtistIndex] = []

    var body: some View {
        List {
            ForEach(indices) { index in
                Section(header: Text(index.name).font(.prismCaption).fontWeight(.bold)) {
                    ForEach(index.artist) { artist in
                        NavigationLink(destination: ArtistDetailView(artistId: artist.id, artistName: artist.name)) {
                            HStack(spacing: 12) {
                                AsyncImage(url: client.getCoverArtURL(id: artist.coverArt ?? "", size: 100)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                        .overlay(Text(String(artist.name.prefix(1))).font(.prismTitle3).foregroundStyle(.white))
                                }
                                .frame(width: 42, height: 42)
                                .clipShape(Circle())

                                Text(artist.name)
                                    .font(.prismBody)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Artists")
        .task {
            do { indices = try await client.getArtists() } catch { print(error) }
        }
    }
}

// MARK: - Artist Detail View
struct ArtistDetailView: View {
    let artistId: String
    let artistName: String
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var details: ArtistContainer?
    @State private var sortOrder: ArtistAlbumSortOrder = .newest

    enum ArtistAlbumSortOrder: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case az     = "A–Z"

        func sort(_ albums: [Album]) -> [Album] {
            switch self {
            case .newest: return albums.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
            case .oldest: return albums.sorted { ($0.year ?? 0) < ($1.year ?? 0) }
            case .az:     return albums.sorted { $0.displayName < $1.displayName }
            }
        }
    }

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var sortedAlbums: [Album] { sortOrder.sort(details?.album ?? []) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(artistName)
                        .font(.prismLargeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top)

                    if details != nil {
                        SectionHeader(title: "Albums", accent: audioPlayer.primaryAccent)

                        SortChipRow(selection: sortOrder, accent: audioPlayer.primaryAccent) { sortOrder = $0 }

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(sortedAlbums) { album in
                                NavigationLink(destination: AlbumDetailView(album: album)) {
                                    AlbumGridCell(
                                        album: album,
                                        size: (geometry.size.width - 64) / 3
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .id(sortOrder) // force full re-render on sort change
                    } else {
                        ProgressView().padding()
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            details = try? await client.getArtist(id: artistId)
        }
    }
}

// MARK: - Playlist List View
struct PlaylistListView: View {
    @Environment(NavidromeClient.self) var client
    @Environment(PinStore.self) var pinStore
    @State private var playlists: [Playlist] = []
    @State private var showMaxPinsAlert = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(playlists) { playlist in
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                        VStack(alignment: .leading, spacing: 4) {
                            PlaylistArtworkView(playlist: playlist)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)

                            Text(playlist.name)
                                .font(.prismSubheadline).fontWeight(.semibold).lineLimit(1)
                                .foregroundStyle(.primary)
                            Text("\(playlist.songCount) Songs")
                                .font(.prismCaption2).foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button {
                            if pinStore.isPinned(playlist.id) {
                                pinStore.unpin(playlist.id)
                            } else {
                                let item = PinnedItem(id: playlist.id, type: .playlist, name: playlist.name, coverArtId: playlist.coverArt)
                                if !pinStore.pin(item) { showMaxPinsAlert = true }
                            }
                        } label: {
                            Label(
                                pinStore.isPinned(playlist.id) ? "Remove Pin" : "Pin to Library",
                                systemImage: pinStore.isPinned(playlist.id) ? "pin.slash" : "pin"
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Playlists")
        .alert("Pin Limit Reached", isPresented: $showMaxPinsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can pin up to 6 items. Remove a pin to add a new one.")
        }
        .task {
            do { playlists = try await client.getPlaylists() } catch { print(error) }
        }
    }
}

// MARK: - Playlist Detail View
struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var details: Playlist?

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    PlaylistArtworkView(playlist: details ?? playlist)
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)

                    Text(playlist.name)
                        .font(.prismTitle2)
                        .fontWeight(.bold)

                    HStack(spacing: 12) {
                        Button {
                            if let songs = details?.entry, let first = songs.first {
                                audioPlayer.play(song: first, context: songs)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .font(.prismHeadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(audioPlayer.primaryAccent)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(audioPlayer.primaryAccent.opacity(0.35), lineWidth: 1))
                            .shadow(color: audioPlayer.primaryAccent.opacity(0.18), radius: 8, x: 0, y: 3)
                        }

                        Button {
                            if let songs = details?.entry {
                                audioPlayer.shufflePlay(songs: songs)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                Text("Shuffle")
                            }
                            .font(.prismHeadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(audioPlayer.primaryAccent)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(audioPlayer.primaryAccent.opacity(0.35), lineWidth: 1))
                            .shadow(color: audioPlayer.primaryAccent.opacity(0.18), radius: 8, x: 0, y: 3)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if let songs = details?.entry {
                ForEach(songs) { song in
                    Button {
                        audioPlayer.play(song: song, context: songs)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title).font(.prismBody).foregroundStyle(.primary)
                                Text(song.artist ?? "").font(.prismCaption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formatTime(TimeInterval(song.duration ?? 0))).font(.prismCaption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .task {
            details = try? await client.getPlaylist(id: playlist.id)
        }
    }
}

// MARK: - Album List View
struct AlbumListView: View {
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var albums: [Album] = []
    @State private var sortOrder: AlbumSortOrder = .az

    enum AlbumSortOrder: String, CaseIterable {
        case az     = "A–Z"
        case za     = "Z–A"
        case newest = "Newest"
        case oldest = "Oldest"

        func sort(_ albums: [Album]) -> [Album] {
            switch self {
            case .az:      return albums.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
            case .za:      return albums.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedDescending }
            case .newest:  return albums.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
            case .oldest:  return albums.sorted { ($0.year ?? 0) < ($1.year ?? 0) }
            }
        }
    }

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var sortedAlbums: [Album] { sortOrder.sort(albums) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    SortChipRow(selection: sortOrder, accent: audioPlayer.primaryAccent) { sortOrder = $0 }
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(sortedAlbums) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                AlbumGridCell(
                                    album: album,
                                    size: (geometry.size.width - 64) / 3
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .id(sortOrder) // force full re-render on sort change
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Albums")
        .task {
            do { albums = try await client.getAlbumList(type: "alphabeticalByName", size: 500) } catch { print(error) }
        }
    }
}

// MARK: - Song List View
struct SongListView: View {
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var songs: [Song] = []
    @State private var sortOrder: SongSortOrder = .az

    enum SongSortOrder: String, CaseIterable {
        case az       = "A–Z"
        case za       = "Z–A"
        case byArtist = "By Artist"

        func sort(_ songs: [Song]) -> [Song] {
            switch self {
            case .az:       return songs.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
            case .za:       return songs.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
            case .byArtist: return songs.sorted { ($0.artist ?? "").localizedCompare($1.artist ?? "") == .orderedAscending }
            }
        }
    }

    var sortedSongs: [Song] { sortOrder.sort(songs) }

    var body: some View {
        VStack(spacing: 0) {
            SortChipRow(selection: sortOrder, accent: audioPlayer.primaryAccent) { sortOrder = $0 }
                .padding(.vertical, 8)

            List(sortedSongs.indices, id: \.self) { i in
                let song = sortedSongs[i]
                Button {
                    audioPlayer.play(song: song, context: sortedSongs)
                } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: client.getCoverArtURL(id: song.coverArt ?? "", size: 50)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.gray.opacity(0.2) }
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title).font(.prismBody).foregroundStyle(.primary).lineLimit(1)
                            Text(song.artist ?? "").font(.prismCaption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .id(sortOrder)
        }
        .navigationTitle("Songs")
        .task {
            do { songs = try await client.getRandomSongs(size: 100) } catch { print(error) }
        }
    }
}

// MARK: - Helpers
func formatTime(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

// MARK: - Playlists Tab (top-level)
struct PlaylistsTabView: View {
    @Environment(NavidromeClient.self) var client
    @Environment(PinStore.self) var pinStore
    @State private var playlists: [Playlist] = []
    @State private var showMaxPinsAlert = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(playlists) { playlist in
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                        VStack(alignment: .leading, spacing: 4) {
                            PlaylistArtworkView(playlist: playlist)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)

                            Text(playlist.name)
                                .font(.prismSubheadline).fontWeight(.semibold).lineLimit(1)
                                .foregroundStyle(.primary)
                            Text("\(playlist.songCount) Songs")
                                .font(.prismCaption2).foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button {
                            if pinStore.isPinned(playlist.id) {
                                pinStore.unpin(playlist.id)
                            } else {
                                let item = PinnedItem(id: playlist.id, type: .playlist, name: playlist.name, coverArtId: playlist.coverArt)
                                if !pinStore.pin(item) { showMaxPinsAlert = true }
                            }
                        } label: {
                            Label(
                                pinStore.isPinned(playlist.id) ? "Remove Pin" : "Pin to Library",
                                systemImage: pinStore.isPinned(playlist.id) ? "pin.slash" : "pin"
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .navigationTitle("Playlists")
        .alert("Pin Limit Reached", isPresented: $showMaxPinsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can pin up to 6 items. Remove a pin to add a new one.")
        }
        .task {
            do { playlists = try await client.getPlaylists() } catch { print(error) }
        }
    }
}
