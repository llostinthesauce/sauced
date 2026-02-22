import SwiftUI

/// A sheet that presents the user's playlists and lets them add a song to one.
struct AddToPlaylistSheet: View {
    let song: Song
    @Environment(NavidromeClient.self) var client
    @Environment(\.dismiss) var dismiss
    
    @State private var playlists: [Playlist] = []
    @State private var isLoading = true
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if playlists.isEmpty {
                    ContentUnavailableView("No Playlists", systemImage: "music.note.list", description: Text("Create a playlist first."))
                } else {
                    List {
                        ForEach(playlists) { playlist in
                            Button {
                                Task {
                                    try? await client.addSongsToPlaylist(id: playlist.id, songIds: [song.id])
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncImage(url: client.getCoverArtURL(id: playlist.coverArt ?? "", size: 100)) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                            .overlay(Image(systemName: "music.note.list").foregroundStyle(.secondary))
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(.prismBody)
                                            .foregroundStyle(.primary)
                                        Text("\(playlist.songCount) Songs")
                                            .font(.prismCaption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                Button("Create & Add") {
                    guard !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task {
                        try? await client.createPlaylist(name: newPlaylistName, songIds: [song.id])
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                do {
                    playlists = try await client.getPlaylists()
                } catch {
                    print("Failed to load playlists: \(error)")
                }
                isLoading = false
            }
        }
        .presentationDetents([.medium, .large])
    }
}
