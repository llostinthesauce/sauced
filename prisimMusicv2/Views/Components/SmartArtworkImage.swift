import SwiftUI

/// Album artwork view that always fetches from the iTunes Search API.
/// While the iTunes fetch is in-flight, Navidrome art is shown as an interim placeholder.
/// Once iTunes resolves, iTunes artwork takes over. If iTunes has nothing, Navidrome stays.
struct SmartArtworkImage: View {
    let coverArtId: String?
    let artist: String?
    let album: String?
    let size: Int

    @Environment(NavidromeClient.self) var client
    @State private var itunesURL: URL?
    @State private var itunesFetched = false

    var body: some View {
        AsyncImage(url: displayURL) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .task(id: taskKey) {
            guard let artist, let album else {
                itunesFetched = true
                return
            }
            itunesURL = await ArtworkFetcher.shared.artworkURL(artist: artist, album: album)
            itunesFetched = true
        }
    }

    // Before iTunes resolves: show Navidrome art (if any) as interim.
    // After iTunes resolves: prefer iTunes, fall back to Navidrome for niche/indie albums.
    private var displayURL: URL? {
        if itunesFetched {
            return itunesURL ?? navidromeURL
        }
        return navidromeURL
    }

    private var navidromeURL: URL? {
        guard let id = coverArtId, !id.isEmpty else { return nil }
        return client.getCoverArtURL(id: id, size: size)
    }

    private var taskKey: String { "\(artist ?? "")_\(album ?? "")" }

    private var placeholder: some View {
        Color.gray.opacity(0.15)
            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
    }
}
