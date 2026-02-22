import Foundation
import UIKit
import Observation

@Observable
class PlaylistArtworkStore {
    static let shared = PlaylistArtworkStore()
    private init() {}

    private func fileURL(for playlistId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeId = playlistId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? playlistId
        return docs.appendingPathComponent("playlist-art-\(safeId).jpg")
    }

    func hasCustomArtwork(for playlistId: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: playlistId).path)
    }

    func loadImage(for playlistId: String) -> UIImage? {
        let url = fileURL(for: playlistId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func saveImage(_ image: UIImage, for playlistId: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: fileURL(for: playlistId))
    }

    func deleteImage(for playlistId: String) {
        try? FileManager.default.removeItem(at: fileURL(for: playlistId))
    }
}
