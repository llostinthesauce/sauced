import Foundation
import Observation

/// Tracks the download state of a single song.
struct DownloadRecord: Codable, Identifiable {
    let songId: String
    let title: String
    let artist: String?
    let album: String?
    let coverArt: String?
    let bitRate: Int?
    let suffix: String?
    let duration: Int?
    let fileName: String   // Relative filename in the downloads directory
    
    var id: String { songId }
}

/// Manages background song downloads, progress tracking, and local file storage.
@Observable
class DownloadManager: NSObject {
    static let shared = DownloadManager()
    
    /// Progress values (0.0–1.0) keyed by song ID.
    var progress: [String: Double] = [:]
    
    /// Song IDs currently being downloaded.
    var activeDownloads: Set<String> = []
    
    private var session: URLSession!
    private let downloadsDir: URL
    private let recordsKey = "downloaded_songs"
    
    /// Persisted list of completed downloads.
    private(set) var records: [DownloadRecord] = []
    
    private override init() {
        // Set up downloads directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        downloadsDir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        
        super.init()
        
        // URLSession with background identifier
        let config = URLSessionConfiguration.background(withIdentifier: "com.sauced.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        loadRecords()
    }
    
    // MARK: - Public API
    
    func isDownloaded(_ songId: String) -> Bool {
        records.contains { $0.songId == songId }
    }
    
    func isDownloading(_ songId: String) -> Bool {
        activeDownloads.contains(songId)
    }
    
    /// Start downloading a song. No-ops if already downloaded or in progress.
    func download(song: Song) {
        guard !isDownloaded(song.id), !isDownloading(song.id) else { return }
        guard let url = NavidromeClient.shared.streamURL(for: song.id) else {
            ErrorBanner.shared.show("Cannot download \"\(song.title)\" — no stream URL")
            return
        }
        
        let task = session.downloadTask(with: url)
        task.taskDescription = song.id  // Use taskDescription to identify the song later
        
        // Store song metadata so we can create a record on completion
        pendingSongs[song.id] = song
        activeDownloads.insert(song.id)
        progress[song.id] = 0
        task.resume()
    }
    
    /// Delete a downloaded song and remove its record.
    func delete(songId: String) {
        guard let record = records.first(where: { $0.songId == songId }) else { return }
        let fileURL = downloadsDir.appendingPathComponent(record.fileName)
        try? FileManager.default.removeItem(at: fileURL)
        records.removeAll { $0.songId == songId }
        saveRecords()
    }
    
    /// Returns the local file URL for a downloaded song, if available.
    func localURL(for songId: String) -> URL? {
        guard let record = records.first(where: { $0.songId == songId }) else { return nil }
        let url = downloadsDir.appendingPathComponent(record.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    // MARK: - Private
    
    /// Temporary store of songs pending download completion.
    private var pendingSongs: [String: Song] = [:]
    
    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: recordsKey),
              let decoded = try? JSONDecoder().decode([DownloadRecord].self, from: data) else { return }
        records = decoded
    }
    
    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: recordsKey)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let songId = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progress[songId] = pct
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let songId = downloadTask.taskDescription,
              let song = pendingSongs[songId] else { return }
        
        let ext = song.suffix ?? "mp3"
        let fileName = "\(songId).\(ext)"
        let dest = downloadsDir.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            
            let record = DownloadRecord(
                songId: song.id,
                title: song.title,
                artist: song.artist,
                album: song.album,
                coverArt: song.coverArt,
                bitRate: song.bitRate,
                suffix: song.suffix,
                duration: song.duration,
                fileName: fileName
            )
            
            DispatchQueue.main.async {
                self.records.append(record)
                self.saveRecords()
                self.activeDownloads.remove(songId)
                self.progress.removeValue(forKey: songId)
                self.pendingSongs.removeValue(forKey: songId)
            }
        } catch {
            DispatchQueue.main.async {
                self.activeDownloads.remove(songId)
                self.progress.removeValue(forKey: songId)
                ErrorBanner.shared.show("Download failed: \(song.title)")
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let songId = task.taskDescription else { return }
        DispatchQueue.main.async {
            self.activeDownloads.remove(songId)
            self.progress.removeValue(forKey: songId)
            ErrorBanner.shared.show("Download failed — check your connection")
            print("Download error for \(songId): \(error)")
        }
    }
}
