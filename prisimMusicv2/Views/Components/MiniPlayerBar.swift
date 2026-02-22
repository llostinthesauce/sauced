import SwiftUI
import UIKit

struct MiniPlayerBar: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(NavidromeClient.self) var client
    @Binding var expandPlayer: Bool
    
    var body: some View {
        if let song = audioPlayer.currentSong {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Album Art
                    CachedAsyncImage(url: client.getCoverArtURL(id: song.coverArt ?? "", size: 100)) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(song.artist ?? "Unknown Artist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 20) {
                        Button {
                            audioPlayer.togglePlayPause()
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundStyle(.primary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        
                        Button {
                            audioPlayer.next()
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Progress Bar
                GeometryReader { geo in
                    let progress = audioPlayer.duration > 0 ? audioPlayer.currentTime / audioPlayer.duration : 0
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(audioPlayer.primaryAccent)
                                .frame(width: geo.size.width * progress, height: 3)
                                .animation(.linear(duration: 0.5), value: progress)
                        }
                }
                .frame(height: 3)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            .background {
                ZStack {
                    Color.clear.background(.regularMaterial)
                    audioPlayer.primaryAccent.opacity(0.08)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    expandPlayer = true
                }
            }
            .transition(.move(edge: .bottom))
        }
    }
}

