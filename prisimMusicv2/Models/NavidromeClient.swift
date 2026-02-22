import Foundation
import SwiftUI
import CryptoKit
import Observation

@Observable
class NavidromeClient {
    // MARK: - Configuration
    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "navidrome_url") }
    }
    var username: String {
        didSet { UserDefaults.standard.set(username, forKey: "navidrome_user") }
    }
    var password: String {
        didSet { UserDefaults.standard.set(password, forKey: "navidrome_pass") }
    }
    
    // MARK: - State
    var isConnected = false
    var lastError: String?
    
    // MARK: - Shared Instance
    static let shared = NavidromeClient()
    
    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "navidrome_url") ?? ""
        self.username = UserDefaults.standard.string(forKey: "navidrome_user") ?? ""
        self.password = UserDefaults.standard.string(forKey: "navidrome_pass") ?? ""
    }
    
    func ping() async -> Bool {
        do {
            let _: SubsonicResponse = try await request("ping.view")
            self.isConnected = true
            return true
        } catch {
            print("Ping failed: \(error)")
            self.isConnected = false
            self.lastError = error.localizedDescription
            return false
        }
    }
    
    func getAlbumList(type: String = "newest", size: Int = 20, offset: Int = 0) async throws -> [Album] {
        let response: SubsonicResponse = try await request("getAlbumList2.view", params: [
            "type": type,
            "size": String(size),
            "offset": String(offset)
        ])
        return response.albumList2?.album ?? []
    }
    
    func getRandomSongs(size: Int = 20) async throws -> [Song] {
        let response: SubsonicResponse = try await request("getRandomSongs.view", params: [
            "size": String(size)
        ])
        return response.randomSongs?.song ?? []
    }
    
    func search(query: String) async throws -> SearchResult3? {
        if query.isEmpty { return nil }
        let response: SubsonicResponse = try await request("search3.view", params: [
            "query": query,
            "songCount": "20",
            "albumCount": "10",
            "artistCount": "5"
        ])
        return response.searchResult3
    }
    
    func getAlbumDetails(id: String) async throws -> AlbumContainer? {
        let response: SubsonicResponse = try await request("getAlbum.view", params: ["id": id])
        return response.album
    }
    
    // MARK: - New Fetchers
    
    func getArtists() async throws -> [ArtistIndex] {
        let response: SubsonicResponse = try await request("getArtists.view")
        return response.artists?.index ?? []
    }
    
    func getArtist(id: String) async throws -> ArtistContainer? {
        let response: SubsonicResponse = try await request("getArtist.view", params: ["id": id])
        return response.artist
    }
    
    func getPlaylists() async throws -> [Playlist] {
        let response: SubsonicResponse = try await request("getPlaylists.view")
        return response.playlists?.playlist ?? []
    }
    
    func getPlaylist(id: String) async throws -> Playlist? {
        let response: SubsonicResponse = try await request("getPlaylist.view", params: ["id": id])
        return response.playlist
    }
    
    func toggleFavorite(id: String, isFavorite: Bool) async throws {
        let endpoint = isFavorite ? "star.view" : "unstar.view"
        let _: SubsonicResponse = try await request(endpoint, params: ["id": id])
    }
    
    // MARK: - URL Construction
    
    func getCoverArtURL(id: String, size: Int = 500) -> URL? {
        // Raw URL construction for AsyncImage
        guard let url = constructURL(endpoint: "getCoverArt.view", params: [
            "id": id,
            "size": String(size)
        ]) else { return nil }
        return url
    }
    
    func streamURL(for songId: String) -> URL? {
        constructURL(endpoint: "stream.view", params: ["id": songId])
    }
    
    // MARK: - Internal Helpers
    
    private func constructURL(endpoint: String, params: [String: String]) -> URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        
        // Ensure path ends correctly
        if components.path.last != "/" { components.path += "/" }
        components.path += "rest/\(endpoint)"
        
        // Auth Items
        let salt = String(Int.random(in: 100000...999999))
        let token = md5("\(password)\(salt)")
        
        var queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"), // API Version
            URLQueryItem(name: "c", value: "PrismMusic"), // Client ID
            URLQueryItem(name: "f", value: "json") // Request JSON format
        ]
        
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    private func request<T: Codable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        guard let url = constructURL(endpoint: endpoint, params: params) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Debugging JSON output if needed
        // if let str = String(data: data, encoding: .utf8) { print("DEBUG JSON: \(str)") }
        
        let root = try JSONDecoder().decode(SubsonicResponseRoot.self, from: data)
        guard root.subsonicResponse.isSuccess else {
            throw NSError(domain: "SubsonicError", code: root.subsonicResponse.error?.code ?? 0, userInfo: [NSLocalizedDescriptionKey: root.subsonicResponse.error?.message ?? "Unknown API Error"])
        }
        
        // We return the generic SubsonicResponse wrapper usually, as T is inferred to be SubsonicResponse
        // But the caller expects T. If T is SubsonicResponse, this works.
        if let response = root.subsonicResponse as? T {
            return response
        }
        
        throw NSError(domain: "ParsingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not cast response to expected type"])
    }
    
    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

