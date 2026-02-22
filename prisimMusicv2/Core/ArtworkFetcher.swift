import Foundation

/// Fetches album artwork from the iTunes Search API when Navidrome has none.
/// Results are cached in memory for the app session.
actor ArtworkFetcher {
    static let shared = ArtworkFetcher()

    private var cache: [String: URL] = [:]   // key → found URL
    private var misses: Set<String> = []      // keys that returned no result

    func artworkURL(artist: String, album: String) async -> URL? {
        let key = cacheKey(artist: artist, album: album)

        if let cached = cache[key] { return cached }
        if misses.contains(key) { return nil }

        let result = await fetch(artist: artist, album: album)

        if let url = result {
            cache[key] = url
        } else {
            misses.insert(key)
        }
        return result
    }

    // MARK: - Private

    private func cacheKey(artist: String, album: String) -> String {
        "\(artist.lowercased())||||\(album.lowercased())"
    }

    private func fetch(artist: String, album: String) async -> URL? {
        let term = "\(artist) \(album)"
        guard
            let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let searchURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=album&limit=5&media=music")
        else { return nil }

        guard
            let (data, _) = try? await URLSession.shared.data(from: searchURL),
            let response = try? JSONDecoder().decode(iTunesResponse.self, from: data),
            let urlString = response.results.first?.artworkUrl100
        else { return nil }

        // iTunes returns 100x100; bump to 600x600 for crisp display
        let highRes = urlString.replacingOccurrences(of: "100x100bb", with: "600x600bb")
        return URL(string: highRes)
    }

    // MARK: - Decodable types

    private struct iTunesResponse: Decodable {
        let results: [iTunesResult]
    }

    private struct iTunesResult: Decodable {
        let artworkUrl100: String?
    }
}
