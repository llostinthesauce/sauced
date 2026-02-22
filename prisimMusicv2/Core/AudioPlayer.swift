import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit
import Observation

@Observable
class AudioPlayer {
    // MARK: - State
    var isPlaying = false
    var currentSong: Song?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    
    // Queue System
    var queue: [Song] = [] {
        didSet { enqueueNextTrack() }
    }
    var history: [Song] = []
    var originalQueue: [Song] = []
    
    var isShuffled = false
    var repeatMode: RepeatMode = .none

    enum RepeatMode {
        case none, all, one
    }

    // Dynamic accent colors derived from current artwork (9 values required for MeshGradient 3x3)
    var accentColors: [Color] = [.purple, .indigo, .blue, .blue, .black.opacity(0.8), .indigo, .black, .black, .purple]
    var primaryAccent: Color { accentColors.first ?? .purple }
    
    // Scrobbling – set to true once the 50% mark has been reported for the current track
    private var hasScrobbled = false
    
    // MARK: - Private
    private var player = AVQueuePlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var nowPlayingInfo = [String: Any]()
    private var colorExtractionTask: Task<Void, Never>?
    
    /// The song that corresponds to the item currently enqueued as "next" in AVQueuePlayer.
    /// This lets us detect when AVQueuePlayer auto-advances and sync our state.
    private var enqueuedNextSong: Song?
    
    // MARK: - Singleton
    static let shared = AudioPlayer()

    // MARK: - API
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupEndOfTrackObserver()
    }
    
    /// Plays a song and sets the remaining songs in the context as the queue.
    func play(song: Song, context: [Song]? = nil) {
        // 1. Update History
        if let current = currentSong {
            history.append(current)
        }
        
        // 2. Set Current
        self.currentSong = song
        
        // 3. Setup Queue from Context
        if let context = context {
            if let index = context.firstIndex(where: { $0.id == song.id }) {
                let nextSongs = Array(context.suffix(from: index + 1))
                self.queue = nextSongs
                self.originalQueue = nextSongs
            } else {
                self.queue = []
            }
        }
        
        // 4. Start Playback
        startPlayback(for: song)
    }
    
    func playNext(_ song: Song) {
        queue.insert(song, at: 0)
    }
    
    func playLast(_ song: Song) {
        queue.append(song)
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func resume() {
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func seek(to time: TimeInterval) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
        currentTime = time
        updateNowPlayingInfo()
    }
    
    func next() {
        // 1. Check Repeat One
        if repeatMode == .one, let _ = currentSong {
            player.seek(to: .zero)
            player.play()
            isPlaying = true
            updateNowPlayingInfo()
            return
        }
        
        // 2. Play from Queue
        if !queue.isEmpty {
            let nextSong = queue.removeFirst()
            play(song: nextSong, context: nil)
        } else if repeatMode == .all && !history.isEmpty {
            var allSongs = history
            if let current = currentSong {
                allSongs.append(current)
            }
            history.removeAll()
            if let first = allSongs.first {
                let rest = Array(allSongs.dropFirst())
                queue = rest
                originalQueue = rest
                currentSong = first
                startPlayback(for: first)
            }
        } else {
            isPlaying = false
            updateNowPlayingInfo()
        }
    }
    
    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        if let prevSong = history.popLast() {
            if let current = currentSong {
                queue.insert(current, at: 0)
            }
            self.currentSong = prevSong
            startPlayback(for: prevSong)
        } else {
            seek(to: 0)
        }
    }
    
    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            originalQueue = queue
            queue.shuffle()
        } else {
            let remainingIds = Set(queue.map { $0.id })
            queue = originalQueue.filter { remainingIds.contains($0.id) }
        }
    }

    func shufflePlay(songs: [Song]) {
        guard !songs.isEmpty else { return }
        var pool = songs.shuffled()
        let first = pool.removeFirst()
        history.removeAll()
        currentSong = first
        queue = pool
        originalQueue = songs.filter { $0.id != first.id }
        isShuffled = true
        startPlayback(for: first)
    }

    // MARK: - Internal
    
    /// Called when AVQueuePlayer finishes a track.
    /// If a next track was pre-enqueued, AVQueuePlayer auto-advances to it (gapless).
    /// We just need to sync our state.
    private func setupEndOfTrackObserver() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // Notify sleep timer that a track ended
            SleepTimerManager.shared.trackDidEnd()
            
            // Check if AVQueuePlayer already moved to the enqueued next song
            if let nextSong = self.enqueuedNextSong, self.player.currentItem != nil {
                // AVQueuePlayer auto-advanced — sync our state
                if let current = self.currentSong {
                    self.history.append(current)
                }
                self.currentSong = nextSong
                self.enqueuedNextSong = nil
                self.hasScrobbled = false
                
                // Remove this song from our logical queue (it was at index 0)
                if !self.queue.isEmpty {
                    self.queue.removeFirst()
                }
                
                self.setupTimeObserver()
                self.updateNowPlayingInfo()
                self.updateArtwork(for: nextSong)
                self.updateAccentColors(for: nextSong)
            } else {
                // No pre-enqueued track — use standard next() logic
                self.enqueuedNextSong = nil
                self.next()
            }
        }
    }
    
    private func startPlayback(for song: Song) {
        // Prefer local file if downloaded, otherwise stream
        let url: URL?
        if let localURL = DownloadManager.shared.localURL(for: song.id) {
            url = localURL
        } else {
            url = NavidromeClient.shared.streamURL(for: song.id)
        }
        
        guard let url else {
            print("No URL for song")
            ErrorBanner.shared.show("Unable to stream \"\(song.title)\"")
            return
        }
        
        // Clear AVQueuePlayer and start fresh
        player.removeAllItems()
        enqueuedNextSong = nil
        hasScrobbled = false
        
        let item = AVPlayerItem(url: url)
        player.insert(item, after: nil)
        player.play()
        isPlaying = true
        
        setupTimeObserver()
        updateNowPlayingInfo()
        updateArtwork(for: song)
        updateAccentColors(for: song)
        
        // Pre-enqueue the next track for gapless playback
        enqueueNextTrack()
    }
    
    /// Pre-loads the next song into AVQueuePlayer so playback is gapless.
    private func enqueueNextTrack() {
        // Only enqueue if there's a next song and nothing is already enqueued
        guard enqueuedNextSong == nil,
              let nextSong = queue.first,
              let url = NavidromeClient.shared.streamURL(for: nextSong.id) else { return }
        
        // Only enqueue if AVQueuePlayer currently has exactly 1 item (the current track)
        guard player.items().count == 1 else { return }
        
        let nextItem = AVPlayerItem(url: url)
        player.insert(nextItem, after: player.items().last)
        enqueuedNextSong = nextSong
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        
        // Handle Interruptions (Calls, etc.)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            if type == .began {
                self?.pause()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.resume()
                    }
                }
            }
        }
    }
    
    private func setupTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            if let duration = self.player.currentItem?.duration.seconds, !duration.isNaN {
                self.duration = duration
                
                // Scrobble at 50% mark
                if !self.hasScrobbled && self.currentTime >= duration * 0.5 {
                    self.hasScrobbled = true
                    self.scrobbleCurrentTrack()
                }
                
                if Int(self.currentTime) % 5 == 0 {
                     self.updateNowPlayingInfo()
                }
            }
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: event.positionTime)
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist ?? "Unknown Artist"
        info[MPMediaItemPropertyAlbumTitle] = song.album ?? "Unknown Album"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        info[MPMediaItemPropertyPlaybackDuration] = player.currentItem?.duration.seconds ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        self.nowPlayingInfo = info
    }
    
    private func updateArtwork(for song: Song) {
        guard let url = NavidromeClient.shared.getCoverArtURL(id: song.coverArt ?? "", size: 1000) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    await MainActor.run {
                        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                        info[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                        self.nowPlayingInfo = info
                    }
                }
            } catch {
                print("Failed to fetch artwork for lock screen: \(error)")
            }
        }
    }
    
    private func updateAccentColors(for song: Song) {
        colorExtractionTask?.cancel()
        colorExtractionTask = Task {
            guard let coverId = song.coverArt,
                  let url = NavidromeClient.shared.getCoverArtURL(id: coverId, size: 500) else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                if let image = UIImage(data: data) {
                    let colors = ImageColorExtractor.shared.extractColors(from: image)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 1.5)) {
                            self.accentColors = colors
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("Failed to extract accent colors: \(error)")
                }
            }
        }
    }
    
    // MARK: - Scrobbling
    
    private func scrobbleCurrentTrack() {
        guard let song = currentSong else { return }
        Task {
            try? await NavidromeClient.shared.scrobble(id: song.id)
        }
    }

    // MARK: - Public Helpers
    
    func updateSong(_ newSong: Song) {
        if currentSong?.id == newSong.id {
            currentSong = newSong
        }
        
        if let index = queue.firstIndex(where: { $0.id == newSong.id }) {
            queue[index] = newSong
        }
        
        if let index = history.firstIndex(where: { $0.id == newSong.id }) {
            history[index] = newSong
        }
        
        if let index = originalQueue.firstIndex(where: { $0.id == newSong.id }) {
            originalQueue[index] = newSong
        }
    }
}
