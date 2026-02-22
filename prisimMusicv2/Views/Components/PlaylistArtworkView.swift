import SwiftUI
import PhotosUI

struct PlaylistArtworkView: View {
    let playlist: Playlist
    @Environment(NavidromeClient.self) var client
    @Environment(PlaylistArtworkStore.self) var artworkStore

    @State private var customImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false

    var body: some View {
        Group {
            if let custom = customImage {
                Image(uiImage: custom)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let coverId = playlist.coverArt, !coverId.isEmpty,
                      let url = client.getCoverArtURL(id: coverId, size: 300) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        collageOrPlaceholder
                    }
                }
            } else {
                collageOrPlaceholder
            }
        }
        .contextMenu {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Set Custom Artwork", systemImage: "photo")
            }

            if artworkStore.hasCustomArtwork(for: playlist.id) {
                Button(role: .destructive) {
                    artworkStore.deleteImage(for: playlist.id)
                    customImage = nil
                } label: {
                    Label("Remove Custom Artwork", systemImage: "trash")
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .task {
            let loaded = artworkStore.loadImage(for: playlist.id)
            await MainActor.run { customImage = loaded }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    artworkStore.saveImage(image, for: playlist.id)
                    customImage = image
                }
            }
        }
    }

    @ViewBuilder
    private var collageOrPlaceholder: some View {
        let songs = playlist.entry ?? []
        if songs.count >= 4 {
            let quadrants = Array(songs.prefix(4))
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)],
                spacing: 0
            ) {
                ForEach(quadrants) { song in
                    AsyncImage(url: song.coverArt.flatMap { client.getCoverArtURL(id: $0, size: 150) }) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                }
            }
        } else {
            LinearGradient(
                colors: [Color.pink.opacity(0.6), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "music.note.list")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.8))
            )
        }
    }
}
