import SwiftUI

struct LibraryView: View {
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(PinStore.self) var pinStore

    @State private var albums: [Album] = []
    @State private var offset = 0
    @State private var canLoadMore = true
    @State private var isLoading = false
    @State private var showMaxPinsAlert = false

    let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    Color.clear.frame(height: 0)

                    // MARK: - Pinned Section
                    if !pinStore.pins.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Pinned", accent: audioPlayer.primaryAccent)
                                .padding(.top, 10)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(pinStore.pins) { pin in
                                        PinnedItemCard(pin: pin)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // MARK: - Navigation Cards
                    VStack(spacing: 10) {
                        NavigationLink(destination: ArtistListView()) {
                            LibraryRow(icon: "mic.fill", title: "Artists", color: audioPlayer.primaryAccent)
                        }
                        NavigationLink(destination: AlbumListView()) {
                            LibraryRow(icon: "square.stack.fill", title: "Albums", color: audioPlayer.primaryAccent)
                        }
                        NavigationLink(destination: SongListView()) {
                            LibraryRow(icon: "music.note", title: "Songs", color: audioPlayer.primaryAccent)
                        }
                        NavigationLink(destination: GenreListView()) {
                            LibraryRow(icon: "guitars", title: "Genres", color: audioPlayer.primaryAccent)
                        }
                        NavigationLink(destination: DownloadsView()) {
                            LibraryRow(icon: "arrow.down.circle.fill", title: "Downloads", color: audioPlayer.primaryAccent)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, pinStore.pins.isEmpty ? 10 : 0)

                    // MARK: - Featured Album
                    if let featured = albums.first {
                        FeaturedAlbumCard(album: featured)
                            .padding(.horizontal)
                    }

                    // MARK: - Recently Added Header
                    SectionHeader(title: "Recently Added", accent: audioPlayer.primaryAccent)

                    // MARK: - Infinite Grid
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(albums) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                AlbumGridCell(album: album)
                                .contextMenu {
                                    Button {
                                        Task { await playAlbumNext(album) }
                                    } label: { Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") }

                                    Button {
                                        Task { await playAlbumLast(album) }
                                    } label: { Label("Play Later", systemImage: "text.line.last.and.arrowtriangle.forward") }

                                    NavigationLink(destination: AlbumDetailView(album: album)) {
                                        Label("Go to Album", systemImage: "arrow.right")
                                    }

                                    Divider()

                                    Button {
                                        if pinStore.isPinned(album.id) {
                                            pinStore.unpin(album.id)
                                        } else {
                                            let item = PinnedItem(
                                                id: album.id,
                                                type: .album,
                                                name: album.displayName,
                                                coverArtId: album.coverArt
                                            )
                                            if !pinStore.pin(item) {
                                                showMaxPinsAlert = true
                                            }
                                        }
                                    } label: {
                                        Label(
                                            pinStore.isPinned(album.id) ? "Remove Pin" : "Pin to Library",
                                            systemImage: pinStore.isPinned(album.id) ? "pin.slash" : "pin"
                                        )
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if canLoadMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .onAppear {
                                    Task { await loadMore() }
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .alert("Pin Limit Reached", isPresented: $showMaxPinsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can pin up to 6 items. Remove a pin to add a new one.")
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            if albums.isEmpty { await loadMore() }
        }
    }

    func loadMore() async {
        guard !isLoading && canLoadMore else { return }
        isLoading = true
        do {
            let newAlbums = try await client.getAlbumList(type: "newest", size: 20, offset: offset)
            if newAlbums.isEmpty {
                canLoadMore = false
            } else {
                albums.append(contentsOf: newAlbums)
                offset += newAlbums.count
            }
        } catch {
            print("Failed to load: \(error)")
        }
        isLoading = false
    }

    func playAlbumNext(_ album: Album) async {
        if let details = try? await client.getAlbumDetails(id: album.id) {
            let songs = (details.song ?? []).sorted { ($0.track ?? 0) < ($1.track ?? 0) }
            for song in songs.reversed() { audioPlayer.playNext(song) }
        }
    }

    func playAlbumLast(_ album: Album) async {
        if let details = try? await client.getAlbumDetails(id: album.id) {
            let songs = (details.song ?? []).sorted { ($0.track ?? 0) < ($1.track ?? 0) }
            for song in songs { audioPlayer.playLast(song) }
        }
    }
}

// MARK: - Album Grid Cell

struct AlbumGridCell: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SmartArtworkImage(
                coverArtId: album.coverArt,
                artist: album.artist,
                album: album.displayName,
                size: 400
            )
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.displayName)
                    .font(.prismCaption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(album.artist ?? "")
                    .font(.prismCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Featured Album Card

struct FeaturedAlbumCard: View {
    let album: Album

    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            ZStack(alignment: .bottomLeading) {
                SmartArtworkImage(
                    coverArtId: album.coverArt,
                    artist: album.artist,
                    album: album.displayName,
                    size: 600
                )
                .aspectRatio(1, contentMode: .fit)

                // Gradient overlay
                LinearGradient(
                    colors: [.black.opacity(0.80), .black.opacity(0.20), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Featured")
                        .font(.prismCaption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.65))
                        .kerning(1.5)
                        .textCase(.uppercase)

                    Text(album.displayName)
                        .font(.prismTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let artist = album.artist {
                        Text(artist)
                            .font(.prismBody)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Library Row (Glassy Card)

struct LibraryRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.prismHeadline)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassCard(cornerRadius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Pinned Item Card

struct PinnedItemCard: View {
    let pin: PinnedItem
    @Environment(NavidromeClient.self) var client
    @Environment(PinStore.self) var pinStore

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 6) {
                AsyncImage(url: client.getCoverArtURL(id: pin.coverArtId ?? "", size: 200)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                        .overlay(
                            Image(systemName: pin.type == .album ? "square.stack.fill" : "music.note.list")
                                .foregroundStyle(.secondary)
                        )
                }
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

                Text(pin.name)
                    .font(.prismCaption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .frame(width: 110, alignment: .leading)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                pinStore.unpin(pin.id)
            } label: {
                Label("Remove Pin", systemImage: "pin.slash")
            }
        }
    }

    @ViewBuilder
    private var destination: some View {
        switch pin.type {
        case .album:
            AlbumDetailView(album: Album(
                id: pin.id,
                name: pin.name,
                title: pin.name,
                artist: nil,
                artistId: nil,
                coverArt: pin.coverArtId,
                songCount: nil,
                duration: nil,
                created: nil,
                year: nil
            ))
        case .playlist:
            PlaylistDetailView(playlist: Playlist(
                id: pin.id,
                name: pin.name,
                comment: nil,
                owner: nil,
                songCount: 0,
                duration: 0,
                created: "",
                coverArt: pin.coverArtId,
                entry: nil
            ))
        }
    }
}
