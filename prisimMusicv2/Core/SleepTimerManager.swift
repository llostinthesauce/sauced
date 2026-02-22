import Foundation
import SwiftUI
import Observation

/// Manages a countdown-based sleep timer that pauses audio playback when it expires.
@Observable
class SleepTimerManager {
    static let shared = SleepTimerManager()
    
    /// Preset durations offered to the user (in minutes).
    static let presets: [(label: String, minutes: Int)] = [
        ("15 min", 15),
        ("30 min", 30),
        ("45 min", 45),
        ("1 hour", 60),
        ("End of Track", -1) // Special case: stop after current track ends
    ]
    
    var isActive = false
    var remainingSeconds: TimeInterval = 0
    var endOfTrackMode = false  // If true, pause after the current song ends
    
    var formattedRemaining: String {
        let m = Int(remainingSeconds) / 60
        let s = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private var timer: Timer?
    
    private init() {}
    
    /// Start a sleep timer for the given number of minutes.
    func start(minutes: Int) {
        cancel()
        
        if minutes == -1 {
            // "End of Track" mode
            endOfTrackMode = true
            isActive = true
            return
        }
        
        endOfTrackMode = false
        remainingSeconds = TimeInterval(minutes * 60)
        isActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            
            if self.remainingSeconds <= 1 {
                self.fire()
            } else {
                self.remainingSeconds -= 1
            }
        }
    }
    
    /// Cancel the active timer.
    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
        endOfTrackMode = false
        remainingSeconds = 0
    }
    
    /// Called when the timer expires — pauses playback.
    private func fire() {
        AudioPlayer.shared.pause()
        cancel()
    }
    
    /// Call this from AudioPlayer when a track ends to handle "End of Track" mode.
    func trackDidEnd() {
        if endOfTrackMode && isActive {
            fire()
        }
    }
}
