import SwiftUI
import UIKit

/// A drop-in replacement for `AsyncImage` that caches images in memory (NSCache)
/// and on disk, preventing redundant network fetches when scrolling or revisiting views.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear { loadImage() }
            }
        }
    }
    
    private func loadImage() {
        guard let url, !isLoading else { return }
        
        let key = url.absoluteString
        
        // 1. Check memory cache
        if let cached = ImageCacheManager.shared.memoryCache.object(forKey: key as NSString) {
            self.image = cached
            return
        }
        
        // 2. Check disk cache
        if let diskImage = ImageCacheManager.shared.loadFromDisk(key: key) {
            ImageCacheManager.shared.memoryCache.setObject(diskImage, forKey: key as NSString)
            self.image = diskImage
            return
        }
        
        // 3. Fetch from network
        isLoading = true
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let downloaded = UIImage(data: data) else { return }
                
                // Store in both caches
                ImageCacheManager.shared.memoryCache.setObject(downloaded, forKey: key as NSString)
                ImageCacheManager.shared.saveToDisk(key: key, data: data)
                
                await MainActor.run {
                    self.image = downloaded
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

// MARK: - Cache Manager (Singleton)

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200            // Max 200 images in memory
        cache.totalCostLimit = 100_000_000 // ~100 MB
        return cache
    }()
    
    private let diskCacheURL: URL
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    func saveToDisk(key: String, data: Data) {
        let fileURL = diskCacheURL.appendingPathComponent(key.sha256Hash)
        try? data.write(to: fileURL)
    }
    
    func loadFromDisk(key: String) -> UIImage? {
        let fileURL = diskCacheURL.appendingPathComponent(key.sha256Hash)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    /// Returns the total size of the disk cache in bytes.
    var diskCacheSize: Int64 {
        let enumerator = FileManager.default.enumerator(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
    
    /// Clears both memory and disk caches.
    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}

// MARK: - Simple SHA-256 hash for cache file names

import CryptoKit

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
