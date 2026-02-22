import SwiftUI
import UIKit
import Observation
import AVKit

struct GlassPlayer: View {
    @Binding var isExpanded: Bool
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(NavidromeClient.self) var client
    @State private var dragOffset: CGSize = .zero
    
    // UI State
    @State private var showQueue = false
    @State private var showInfo = false
    @State private var showAlbum = false
    @State private var showLyrics = false
    @State private var sleepTimer = SleepTimerManager.shared
    
    // Dynamic State
    @State private var isFavorite = false
    
    // Album Sheet State
    @State private var selectedAlbum: Album?
    @State private var isLoadingAlbum = false
    
    var body: some View {
        ZStack {
            // SOLID BASE to prevent bleed-through
            Color.black.ignoresSafeArea()
            
            // MARK: - Dynamic Background
            if #available(iOS 18.0, *) {
                MeshGradient(width: 3, height: 3, points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ], colors: audioPlayer.accentColors)
                .ignoresSafeArea()
                .blur(radius: 60)
                .opacity(0.6)
                .animation(.easeInOut(duration: 2.0), value: audioPlayer.accentColors)
            } else {
                LinearGradient(colors: [audioPlayer.accentColors.first ?? .purple, audioPlayer.accentColors.last ?? .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            
            // MARK: - Content
            VStack(spacing: 0) {
                // Header: Down Arrow & Ellipsis
                HStack {
                    Button {
                        withAnimation { isExpanded = false }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    
                    Spacer()
                    
                    // Grabber
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 5)
                    
                    Spacer()
                    
                    // Top Menu
                    Menu {
                        if let song = audioPlayer.currentSong, let url = client.streamURL(for: song.id) {
                            ShareLink(item: url) {
                                Label("Share Song", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        if let song = audioPlayer.currentSong {
                            Button {
                                toggleFavorite(song: song)
                            } label: {
                                Label(isFavorite ? "Unfavorite" : "Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                            .background(.white.opacity(0.1), in: Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)
                
                Spacer()
                
                // Artwork
                if let song = audioPlayer.currentSong {
                    AsyncImage(url: client.getCoverArtURL(id: song.coverArt ?? "", size: 1000)) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                            .overlay(Image(systemName: "music.note").font(.system(size: 80)).foregroundStyle(.white.opacity(0.5)))
                    }
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                    .scaleEffect(audioPlayer.isPlaying ? 1.0 : 0.92)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: audioPlayer.isPlaying)
                }
                
                Spacer()
                
                // Info & Controls
                VStack(spacing: 30) {
                    
                    // Title, Artist, Favorites
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(audioPlayer.currentSong?.title ?? "Not Playing")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            Text(audioPlayer.currentSong?.artist ?? "Select a song")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                            
                            if let album = audioPlayer.currentSong?.album {
                                Text(album)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                            
                            // Audio Quality Badge
                            if let song = audioPlayer.currentSong, isLossless(song) {
                                HStack(spacing: 4) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(qualityLabel(song))
                                        .font(.system(size: 10, weight: .semibold))
                                        .textCase(.uppercase)
                                }
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.12), in: Capsule())
                            }
                        }
                        
                        Spacer()
                        
                        // Favorite Button (Direct Access)
                         Button {
                             if let song = audioPlayer.currentSong {
                                 toggleFavorite(song: song)
                             }
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 24))
                                .foregroundStyle(isFavorite ? .pink : .white.opacity(0.4))
                        }
                        .padding(.trailing, 8)

                        // Bottom Menu (Options)
                        Menu {
                            if let song = audioPlayer.currentSong {
                                Button {
                                    audioPlayer.playNext(song)
                                } label: { Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") }
                                
                                Button {
                                    audioPlayer.playLast(song)
                                } label: { Label("Play Last", systemImage: "text.line.last.and.arrowtriangle.forward") }
                                
                                Button {
                                    loadAndShowAlbum(for: song)
                                } label: { Label("Go to Album", systemImage: "arrow.right") }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(10)
                                .background(.white.opacity(0.1), in: Circle())
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Updated Slider (Glossy & Fluid)
                    VStack(spacing: 8) {
                        Slider(value: Binding(get: {
                            audioPlayer.currentTime
                        }, set: { newValue in
                            audioPlayer.seek(to: newValue)
                        }), in: 0...(audioPlayer.duration > 0 ? audioPlayer.duration : 1))
                        .tint(.white.opacity(0.8))
                        
                        HStack {
                            Text(formatTime(audioPlayer.currentTime))
                            Spacer()
                            Text(formatTime(audioPlayer.duration))
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                    }
                    .padding(.horizontal, 32)
                    
                    // Main Controls
                    HStack(spacing: 50) {
                        Button {
                            audioPlayer.previous()
                            impactHaptic(style: .medium)
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                        
                        Button {
                            audioPlayer.togglePlayPause()
                            impactHaptic(style: .light)
                        } label: {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                                .shadow(radius: 5)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        
                        Button {
                            audioPlayer.next()
                            impactHaptic(style: .medium)
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 4)
                    
                    // Shuffle & Repeat Controls
                    HStack {
                        Spacer()

                        Button {
                            audioPlayer.toggleShuffle()
                            selectionHaptic()
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(audioPlayer.isShuffled ? .black : .white.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .background(
                                    audioPlayer.isShuffled
                                        ? AnyShapeStyle(.white)
                                        : AnyShapeStyle(Color.white.opacity(0.12)),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioPlayer.isShuffled)

                        Spacer()

                        Button {
                            switch audioPlayer.repeatMode {
                            case .none: audioPlayer.repeatMode = .all
                            case .all:  audioPlayer.repeatMode = .one
                            case .one:  audioPlayer.repeatMode = .none
                            }
                            selectionHaptic()
                        } label: {
                            let isActive = audioPlayer.repeatMode != .none
                            Image(systemName: audioPlayer.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 18, weight: .semibold))
                                .contentTransition(.symbolEffect(.replace))
                                .foregroundStyle(isActive ? .black : .white.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .background(
                                    isActive
                                        ? AnyShapeStyle(.white)
                                        : AnyShapeStyle(Color.white.opacity(0.12)),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioPlayer.repeatMode)

                        Spacer()
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, 10)
                    
                    // Bottom Actions
                    HStack(spacing: 30) {
                        Button {
                            showLyrics.toggle()
                            selectionHaptic()
                        } label: {
                            Image(systemName: "quote.opening")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Button {
                            showInfo.toggle()
                            selectionHaptic()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        // AirPlay
                        AirPlayButton()
                            .frame(width: 30, height: 30)
                        
                        // Sleep Timer
                        Menu {
                            if sleepTimer.isActive {
                                Button(role: .destructive) {
                                    sleepTimer.cancel()
                                    selectionHaptic()
                                } label: {
                                    Label("Cancel Timer", systemImage: "xmark")
                                }
                            } else {
                                ForEach(SleepTimerManager.presets, id: \.minutes) { preset in
                                    Button {
                                        sleepTimer.start(minutes: preset.minutes)
                                        selectionHaptic()
                                    } label: {
                                        Text(preset.label)
                                    }
                                }
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: sleepTimer.isActive ? "moon.fill" : "moon.zzz")
                                    .font(.title3)
                                    .foregroundStyle(sleepTimer.isActive ? audioPlayer.primaryAccent : .white.opacity(0.5))
                                if sleepTimer.isActive && !sleepTimer.endOfTrackMode {
                                    Text(sleepTimer.formattedRemaining)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(audioPlayer.primaryAccent)
                                }
                            }
                        }
                        
                        Button {
                            showQueue.toggle()
                            selectionHaptic()
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .presentationBackground(.clear)
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        withAnimation { isExpanded = false }
                    }
                    withAnimation { dragOffset = .zero }
                }
        )
        .onChange(of: audioPlayer.currentSong) { _, song in
             updateFavoriteState(for: song)
        }
        .task {
            updateFavoriteState(for: audioPlayer.currentSong)
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        .sheet(isPresented: $showInfo) {
            if let song = audioPlayer.currentSong {
                SongInfoSheet(song: song)
            } else {
                Text("No Song Playing")
            }
        }
        .sheet(isPresented: $showAlbum) {
            if isLoadingAlbum {
                ProgressView("Loading Album...")
                    .presentationDetents([.medium])
            } else if let album = selectedAlbum {
                AlbumDetailView(album: album)
            } else {
                 Text("Album not found")
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showLyrics) {
            if let song = audioPlayer.currentSong {
                LyricsView(song: song)
            }
        }
    }
    
    // MARK: - Helpers
    
    func loadAndShowAlbum(for song: Song) {
        guard let albumId = song.albumId else { return }
        isLoadingAlbum = true
        showAlbum = true // Show sheet immediately
        
        Task {
            if let container = try? await client.getAlbumDetails(id: albumId) {
                // Map to Album
                 let album = Album(id: container.id,
                                name: container.name ?? "",
                                title: container.name,
                                artist: container.artist,
                                artistId: nil,
                                coverArt: container.coverArt,
                                songCount: container.song?.count,
                                duration: nil,
                                created: nil,
                                year: container.year)
                
                await MainActor.run {
                    self.selectedAlbum = album
                    self.isLoadingAlbum = false
                }
            } else {
                await MainActor.run {
                    self.isLoadingAlbum = false
                }
            }
        }
    }
    
    func updateFavoriteState(for song: Song?) {
        guard let song = song else {
            isFavorite = false
            return
        }
        // If 'starred' is present (not nil), it's a favorite
        isFavorite = (song.starred != nil)
    }
    
    func toggleFavorite(song: Song) {
        let newState = !isFavorite
        // Optimistic update
        isFavorite = newState 
        
        Task {
            do {
                try await client.toggleFavorite(id: song.id, isFavorite: newState)
                
                // Update Local State in AudioPlayer so it persists across queue/history
                await MainActor.run {
                    if var current = audioPlayer.currentSong, current.id == song.id {
                        current.starred = newState ? ISO8601DateFormatter().string(from: Date()) : nil
                        audioPlayer.updateSong(current)
                    }
                }
            } catch {
                print("Failed to toggle favorite: \(error)")
                // Revert on failure
                await MainActor.run { isFavorite = !newState }
            }
        }
    }
    
    // formatTime is defined in PrismStyle.swift
    
    
    func selectionHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    func impactHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func isLossless(_ song: Song) -> Bool {
        if let bitRate = song.bitRate, bitRate > 320 { return true }
        if let suffix = song.suffix?.lowercased(), ["flac", "alac", "wav", "aiff"].contains(suffix) { return true }
        return false
    }
    
    func qualityLabel(_ song: Song) -> String {
        let codec = song.suffix?.uppercased() ?? "Lossless"
        if let bitRate = song.bitRate {
            return "\(codec) • \(bitRate) kbps"
        }
        return codec
    }
}

