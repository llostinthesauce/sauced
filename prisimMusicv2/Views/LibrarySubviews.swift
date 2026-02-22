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
                                CachedAsyncImage(url: client.getCoverArtURL(id: artist.coverArt ?? "", size: 100)) { image in
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
        GridItem(.adaptive(minimum: 120), spacing: 16)
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
                                    AlbumGridCell(album: album)
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
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""

    let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

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
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            Task {
                                try? await client.deletePlaylist(id: playlist.id)
                                playlists.removeAll { $0.id == playlist.id }
                                pinStore.unpin(playlist.id)
                            }
                        } label: {
                            Label("Delete Playlist", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newPlaylistName = ""
                    showNewPlaylist = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Playlist", isPresented: $showNewPlaylist) {
            TextField("Playlist Name", text: $newPlaylistName)
            Button("Create") {
                guard !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    try? await client.createPlaylist(name: newPlaylistName)
                    playlists = (try? await client.getPlaylists()) ?? playlists
                }
            }
            Button("Cancel", role: .cancel) {}
        }
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
    @Environment(\.dismiss) var dismiss
    @State private var details: Playlist?
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    PlaylistArtworkView(playlist: details ?? playlist)
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)

                    Text(details?.name ?? playlist.name)
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
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    Button {
                        audioPlayer.play(song: song, context: songs)
                    } label: {
                        HStack {
                            if audioPlayer.currentSong?.id == song.id {
                                if audioPlayer.isPlaying {
                                    NowPlayingBarsView(color: audioPlayer.primaryAccent)
                                        .frame(width: 14, height: 14)
                                } else {
                                    NowPlayingBarsPausedView(color: audioPlayer.primaryAccent)
                                        .frame(width: 14, height: 14)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.prismBody)
                                    .foregroundStyle(audioPlayer.currentSong?.id == song.id ? audioPlayer.primaryAccent : .primary)
                                    .lineLimit(1)
                                Text(song.artist ?? "").font(.prismCaption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formatTime(TimeInterval(song.duration ?? 0))).font(.prismCaption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                try? await client.removeSongFromPlaylist(id: playlist.id, index: index)
                                details = try? await client.getPlaylist(id: playlist.id)
                            }
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        renameText = details?.name ?? playlist.name
                        showRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Playlist", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") {
                guard !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    try? await client.renamePlaylist(id: playlist.id, name: renameText)
                    details = try? await client.getPlaylist(id: playlist.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Playlist?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await client.deletePlaylist(id: playlist.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(details?.name ?? playlist.name)\".")
        }
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
        GridItem(.adaptive(minimum: 120), spacing: 16)
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
                                AlbumGridCell(album: album)
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
    @State private var downloads = DownloadManager.shared
    
    // Pagination state
    @State private var offset = 0
    @State private var isLoading = false
    @State private var hasMore = true

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

            List {
                ForEach(sortedSongs.indices, id: \.self) { i in
                    let song = sortedSongs[i]
                    Button {
                        audioPlayer.play(song: song, context: sortedSongs)
                    } label: {
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: client.getCoverArtURL(id: song.coverArt ?? "", size: 50)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Color.gray.opacity(0.2) }
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    if audioPlayer.currentSong?.id == song.id {
                                        if audioPlayer.isPlaying {
                                            NowPlayingBarsView(color: audioPlayer.primaryAccent)
                                                .frame(width: 14, height: 14)
                                        } else {
                                            NowPlayingBarsPausedView(color: audioPlayer.primaryAccent)
                                                .frame(width: 14, height: 14)
                                        }
                                    }
                                    Text(song.title)
                                        .font(.prismBody)
                                        .foregroundStyle(audioPlayer.currentSong?.id == song.id ? audioPlayer.primaryAccent : .primary)
                                        .lineLimit(1)
                                }
                                Text(song.artist ?? "").font(.prismCaption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Download state
                            if downloads.isDownloaded(song.id) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else if let pct = downloads.progress[song.id] {
                                CircularProgressView(progress: pct)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                    .contextMenu {
                        if !downloads.isDownloaded(song.id) && !downloads.isDownloading(song.id) {
                            Button {
                                downloads.download(song: song)
                            } label: {
                                Label("Download", systemImage: "arrow.down.circle")
                            }
                        }
                    }
                }
                
                if hasMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .onAppear {
                                Task { await loadMore() }
                            }
                        Spacer()
                    }
                    .padding()
                }
            }
            .listStyle(.plain)
            .id(sortOrder)
        }
        .navigationTitle("Songs")
    }
    
    private func loadMore() async {
        guard !isLoading && hasMore else { return }
        isLoading = true
        do {
            let newSongs = try await client.getAllSongs(count: 100, offset: offset)
            if newSongs.isEmpty {
                hasMore = false
            } else {
                songs.append(contentsOf: newSongs)
                offset += newSongs.count
            }
        } catch {
            print(error)
        }
        isLoading = false
    }
}

// formatTime is defined in PrismStyle.swift

// MARK: - Playlists Tab (top-level, wraps PlaylistListView)
struct PlaylistsTabView: View {
    var body: some View {
        PlaylistListView()
            .padding(.bottom, 100)
    }
}

