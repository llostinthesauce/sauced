import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Art (Apple Music Style)
                VStack(spacing: 16) {
                    SmartArtworkImage(
                        coverArtId: album.coverArt,
                        artist: album.artist,
                        album: album.displayName,
                        size: 600
                    )
                    .frame(width: 250, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .padding(.top, 20)
                    
                    // Metadata
                    VStack(spacing: 4) {
                        Text(album.displayName)
                            .font(.prismTitle2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        Text(album.artist ?? "Unknown Artist")
                            .font(.prismBody)
                            .foregroundStyle(audioPlayer.primaryAccent)

                        if let year = album.year {
                            Text("Album • \(String(year))")
                                .font(.prismCaption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                    }
                    .padding(.horizontal)

                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            if let first = songs.first {
                                audioPlayer.play(song: first, context: songs)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .font(.prismHeadline)
                            .foregroundStyle(audioPlayer.primaryAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(audioPlayer.primaryAccent.opacity(0.35), lineWidth: 1))
                            .shadow(color: audioPlayer.primaryAccent.opacity(0.18), radius: 8, x: 0, y: 3)
                        }

                        Button {
                            audioPlayer.shufflePlay(songs: songs)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                Text("Shuffle")
                            }
                            .font(.prismHeadline)
                            .foregroundStyle(audioPlayer.primaryAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(audioPlayer.primaryAccent.opacity(0.35), lineWidth: 1))
                            .shadow(color: audioPlayer.primaryAccent.opacity(0.18), radius: 8, x: 0, y: 3)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .disabled(songs.isEmpty)
                }
                .padding(.bottom, 20)
                
                Divider()
                
                if isLoading {
                    ProgressView().padding()
                } else if let error = errorMessage {
                    Text("Error: \(error)").foregroundStyle(.red)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(songs) { song in
                            Button {
                                audioPlayer.play(song: song, context: songs)
                            } label: {
                                HStack(spacing: 16) {
                                    Text(song.track.map(String.init) ?? "-")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .leading)
                                    
                                    VStack(alignment: .leading) {
                                        Text(song.title)
                                            .foregroundStyle(audioPlayer.currentSong?.id == song.id ? audioPlayer.primaryAccent : .primary)
                                            .fontWeight(audioPlayer.currentSong?.id == song.id ? .semibold : .regular)
                                        if let duration = song.duration {
                                            Text(formatTime(TimeInterval(duration)))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if audioPlayer.currentSong?.id == song.id {
                                        if audioPlayer.isPlaying {
                                            NowPlayingBarsView(color: audioPlayer.primaryAccent)
                                                .frame(width: 14, height: 14)
                                        } else {
                                            NowPlayingBarsPausedView(color: audioPlayer.primaryAccent)
                                                .frame(width: 14, height: 14)
                                        }
                                    }
                                }
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            Divider().padding(.leading, 46)
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .offset(y: -30)
        }
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadSongs()
        }
    }
    
    func loadSongs() async {
        isLoading = true
        do {
            if let details = try await client.getAlbumDetails(id: album.id) {
                self.songs = (details.song ?? []).sorted { ($0.track ?? 0) < ($1.track ?? 0) }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading album details: \(error)")
        }
        isLoading = false
    }
    // formatTime is defined in PrismStyle.swift
}
