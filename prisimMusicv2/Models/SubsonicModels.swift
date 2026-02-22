import Foundation

// MARK: - API Response Wrapper
struct SubsonicResponseRoot: Codable {
    let subsonicResponse: SubsonicResponse
    
    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct SubsonicResponse: Codable {
    let status: String
    let version: String
    let type: String?
    let serverVersion: String?
    let error: SubsonicError?
    
    // Data Containers
    let albumList2: AlbumList?
    let randomSongs: SongList?
    let searchResult3: SearchResult3?
    let album: AlbumContainer?
    let artist: ArtistContainer?
    let directory: Directory?
    let lyrics: Lyrics?
    let genres: GenresResponse?
    let songsByGenre: SongList?
    
    var isSuccess: Bool { status == "ok" }
    
    // Additional Data
    let artists: ArtistsResponse?
    let playlists: Playlists?
    let playlist: Playlist? // for getPlaylist
}

// ... (keep existing structs)

// MARK: - New Index Models

struct ArtistsResponse: Codable {
    let index: [ArtistIndex]?
    let ignoredArticles: String
}

struct ArtistIndex: Codable, Identifiable {
    let name: String
    let artist: [Artist]
    var id: String { name }
}

struct Playlists: Codable {
    let playlist: [Playlist]?
}

struct Playlist: Codable, Identifiable {
    let id: String
    let name: String
    let comment: String?
    let owner: String?
    let songCount: Int
    let duration: Int
    let created: String
    let coverArt: String?
    let entry: [Song]?
}

struct SubsonicError: Codable {
    let code: Int
    let message: String
}

// MARK: - Data Collections
struct AlbumList: Codable {
    let album: [Album]?
}

struct SongList: Codable {
    let song: [Song]?
}

struct SearchResult3: Codable {
    let artist: [Artist]?
    let album: [Album]?
    let song: [Song]?
}

struct AlbumContainer: Codable {
    // getAlbum returns just generic "album" keys usually, or wrapped in an object?
    // Subsonic often returns { "album": { ... properties ... } }
    // But sometimes the properties are top level depending on endpoint.
    // For getAlbum, it returns <album ...><song .../></album>
    // In JSON: "album": { "id": "...", "song": [...] }
    let id: String
    let name: String?
    let artist: String?
    let coverArt: String?
    let song: [Song]?
    let year: Int?
    let genre: String?
    let playCount: Int?
}

struct ArtistContainer: Codable {
    let id: String
    let name: String
    let coverArt: String?
    let album: [Album]?
}

struct Directory: Codable {
    let id: String
    let name: String
    let child: [ChildItem]?
}

struct ChildItem: Codable {
    let id: String
    let title: String
    let artist: String?
    let isDir: Bool
    let coverArt: String?
}

// MARK: - Core Entity Models

struct Album: Codable, Identifiable {
    let id: String
    let name: String? // Made optional
    let title: String?
    let artist: String?
    let artistId: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Int?
    let created: String?
    let year: Int?
    
    var displayName: String { (name ?? title) ?? "Unknown Album" }
}

struct Artist: Codable, Identifiable {
    let id: String
    let name: String
    let coverArt: String?
    let albumCount: Int?
}

struct Song: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let album: String?
    let albumId: String?
    let artist: String?
    let track: Int?
    let year: Int?
    let genre: String?
    let coverArt: String?
    let duration: Int? // Seconds
    let bitRate: Int?
    let suffix: String?
    let contentType: String?
    let isVideo: Bool?
    let path: String?
    var starred: String? // Timestamp if starred, nil otherwise
    
    // Hashable conformance for UI Diffing
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Lyrics

struct Lyrics: Codable {
    let artist: String?
    let title: String?
    let value: String? // The actual lyrics text
}

// MARK: - Genres

struct GenresResponse: Codable {
    let genre: [Genre]?
}

struct Genre: Codable, Identifiable, Hashable {
    let value: String      // genre name
    let songCount: Int?
    let albumCount: Int?
    
    var id: String { value }
    
    enum CodingKeys: String, CodingKey {
        case value, songCount, albumCount
    }
}
