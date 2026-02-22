import SwiftUI

/// A downloads manager view showing all downloaded songs with delete and playback support.
struct DownloadsView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var downloads = DownloadManager.shared
    
    var body: some View {
        Group {
            if downloads.records.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Long-press any song, album, or playlist to download for offline playback.")
                )
            } else {
                List {
                    ForEach(downloads.records) { record in
                        Button {
                            // Build a Song from the record and play it
                            if let song = songFrom(record) {
                                let allSongs = downloads.records.compactMap { songFrom($0) }
                                audioPlayer.play(song: song, context: allSongs)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                // Artwork
                                if let coverId = record.coverArt,
                                   let url = NavidromeClient.shared.getCoverArtURL(id: coverId, size: 50) {
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
                                    }
                                    .frame(width: 42, height: 42)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 42, height: 42)
                                        .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        // Animated bars when playing
                                        if audioPlayer.currentSong?.id == record.songId {
                                            if audioPlayer.isPlaying {
                                                NowPlayingBarsView(color: audioPlayer.primaryAccent)
                                                    .frame(width: 14, height: 14)
                                            } else {
                                                NowPlayingBarsPausedView(color: audioPlayer.primaryAccent)
                                                    .frame(width: 14, height: 14)
                                            }
                                        }
                                        Text(record.title)
                                            .font(.prismBody)
                                            .foregroundStyle(audioPlayer.currentSong?.id == record.songId ? audioPlayer.primaryAccent : .primary)
                                            .lineLimit(1)
                                    }
                                    Text(record.artist ?? "")
                                        .font(.prismCaption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.body)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                downloads.delete(songId: record.songId)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Downloads")
        .toolbar {
            if !downloads.records.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(downloads.records.count) Songs")
                        .font(.prismCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func songFrom(_ record: DownloadRecord) -> Song? {
        Song(
            id: record.songId,
            title: record.title,
            album: record.album,
            albumId: nil,
            artist: record.artist,
            track: nil,
            year: nil,
            genre: nil,
            coverArt: record.coverArt,
            duration: record.duration,
            bitRate: record.bitRate,
            suffix: record.suffix,
            contentType: nil,
            isVideo: false,
            path: nil,
            starred: nil
        )
    }
}
