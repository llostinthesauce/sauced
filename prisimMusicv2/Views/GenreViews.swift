import SwiftUI

// MARK: - Genre List View
struct GenreListView: View {
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var genres: [Genre] = []

    var body: some View {
        List {
            ForEach(genres.sorted { ($0.songCount ?? 0) > ($1.songCount ?? 0) }) { genre in
                NavigationLink(destination: GenreDetailView(genre: genre)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(genre.value)
                                .font(.prismBody)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 12) {
                                if let albumCount = genre.albumCount {
                                    Text("\(albumCount) Albums")
                                        .font(.prismCaption2)
                                        .foregroundStyle(.secondary)
                                }
                                if let songCount = genre.songCount {
                                    Text("\(songCount) Songs")
                                        .font(.prismCaption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Genres")
        .task {
            do { genres = try await client.getGenres() } catch { print(error) }
        }
    }
}

// MARK: - Genre Detail View
struct GenreDetailView: View {
    let genre: Genre
    @Environment(NavidromeClient.self) var client
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var songs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text(genre.value)
                    .font(.prismLargeTitle)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    if let songCount = genre.songCount {
                        Text("\(songCount) Songs")
                            .font(.prismCaption)
                            .foregroundStyle(.secondary)
                    }
                    if let albumCount = genre.albumCount {
                        Text("\(albumCount) Albums")
                            .font(.prismCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Play / Shuffle buttons
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
                        .frame(height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(audioPlayer.primaryAccent.opacity(0.35), lineWidth: 1))
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
                        .frame(height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(audioPlayer.primaryAccent.opacity(0.35), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .disabled(songs.isEmpty)
            }
            .padding(.vertical, 16)
            
            Divider()
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(songs) { song in
                    Button {
                        audioPlayer.play(song: song, context: songs)
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
                                Text(song.artist ?? "")
                                    .font(.prismCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if let duration = song.duration {
                                Text(formatTime(TimeInterval(duration)))
                                    .font(.prismCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                songs = try await client.getSongsByGenre(genre: genre.value, count: 100)
            } catch {
                print("Failed to load songs for genre: \(error)")
            }
            isLoading = false
        }
    }
}
