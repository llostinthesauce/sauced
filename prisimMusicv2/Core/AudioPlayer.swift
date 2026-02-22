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
    var queue: [Song] = []       // Songs coming up next
    var history: [Song] = []     // Songs already played
    var originalQueue: [Song] = [] // Backup for shuffle
    
    var isShuffled = false
    var repeatMode: RepeatMode = .none

    enum RepeatMode {
        case none, all, one
    }

    // Dynamic accent colors derived from current artwork (9 values required for MeshGradient 3x3)
    var accentColors: [Color] = [.purple, .indigo, .blue, .blue, .black.opacity(0.8), .indigo, .black, .black, .purple]
    var primaryAccent: Color { accentColors.first ?? .purple }
    
    // MARK: - Private
    private var player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var nowPlayingInfo = [String: Any]()
    private var colorExtractionTask: Task<Void, Never>?
    
    // MARK: - Singleton
    static let shared = AudioPlayer()

    // MARK: - API
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupEndOfTrackObserver()
    }
    
    /// Plays a song and sets the remaining songs in the context as the queue.
    /// - Parameters:
    ///   - song: The specific song to start with.
    ///   - context: The full list of songs (e.g., Album tracks) the song belongs to.
    func play(song: Song, context: [Song]? = nil) {
        // 1. Update History
        if let current = currentSong {
            history.append(current)
        }
        
        // 2. Set Current
        self.currentSong = song
        
        // 3. Setup Queue from Context
        if let context = context {
            // Find index of song in context
            if let index = context.firstIndex(where: { $0.id == song.id }) {
                // Queue is everything after this song
                let nextSongs = Array(context.suffix(from: index + 1))
                self.queue = nextSongs
                self.originalQueue = nextSongs // Save for un-shuffle (not impl yet)
            } else {
                // Song not in context? Just clear queue or set usage
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
        // Optimistic update
        currentTime = time
        updateNowPlayingInfo()
    }
    
    func next() {
        // 1. Check Repeat One
        if repeatMode == .one, let song = currentSong {
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
            // Rebuild queue from history + current and restart
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
            // Queue empty, nothing to repeat
            isPlaying = false
            updateNowPlayingInfo()
        }
    }
    
    func previous() {
        // If > 3 seconds in, restart song
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        // Else go to history
        if let prevSong = history.popLast() {
            // Push current back to queue front
            if let current = currentSong {
                queue.insert(current, at: 0)
            }
            // Play previous without adding to history (we just popped it)
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
            // Restore original order, filtering out songs already played
            let remainingIds = Set(queue.map { $0.id })
            queue = originalQueue.filter { remainingIds.contains($0.id) }
        }
    }

    /// Picks a random song from the list, plays it, and shuffles the remaining queue.
    func shufflePlay(songs: [Song]) {
        guard !songs.isEmpty else { return }
        var pool = songs.shuffled()
        let first = pool.removeFirst()
        history.removeAll()
        currentSong = first
        queue = pool
        // Store the original unshuffled order (minus the first song) so toggling shuffle off can restore it
        originalQueue = songs.filter { $0.id != first.id }
        isShuffled = true
        startPlayback(for: first)
    }

    // MARK: - Internal
    
    private func setupEndOfTrackObserver() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.next()
        }
    }
    
    private func startPlayback(for song: Song) {
        guard let url = NavidromeClient.shared.streamURL(for: song.id) else {
            print("No URL for song")
            return
        }
        
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        
        setupTimeObserver()
        updateNowPlayingInfo()
        updateArtwork(for: song)
        updateAccentColors(for: song)
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
        // Remove existing observer if any
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
                
                // Update Now Playing Info periodically for progress bar on lock screen
                if Int(self.currentTime) % 5 == 0 { // Update every 5 seconds to keep sync
                     self.updateNowPlayingInfo()
                }
            }
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        // Pause
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Next Track
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        
        // Previous Track
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        
        // Scrubbing (Change Playback Position)
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

    func updateSong(_ newSong: Song) {
        if currentSong?.id == newSong.id {
            currentSong = newSong
        }
        
        // Update in Queue
        if let index = queue.firstIndex(where: { $0.id == newSong.id }) {
            queue[index] = newSong
        }
        
        // Update in History
        if let index = history.firstIndex(where: { $0.id == newSong.id }) {
            history[index] = newSong
        }
        
        // Update in Original Queue
        if let index = originalQueue.firstIndex(where: { $0.id == newSong.id }) {
            originalQueue[index] = newSong
        }
    }
}
