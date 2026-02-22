import Foundation
import CarPlay
import UIKit

/// Manages the CarPlay audio session lifecycle and template hierarchy.
/// Registered in the app's scene manifest as the CarPlay scene delegate.
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    private var interfaceController: CPInterfaceController?
    
    // MARK: - CPTemplateApplicationSceneDelegate
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        // Push the root tab bar template
        let rootTemplate = makeRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: false, completion: nil)
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
    
    // MARK: - Template Construction
    
    /// Builds a tab bar with Now Playing, Albums, and Playlists.
    private func makeRootTemplate() -> CPTabBarTemplate {
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.add(self)
        
        let albumsTab = makeAlbumsListTemplate()
        let playlistsTab = makePlaylistsListTemplate()
        
        return CPTabBarTemplate(templates: [nowPlaying, albumsTab, playlistsTab])
    }
    
    // MARK: - Albums
    
    private func makeAlbumsListTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "Albums", sections: [])
        template.tabImage = UIImage(systemName: "square.stack.fill")
        template.emptyViewTitleVariants = ["Loading Albums…"]
        
        Task {
            do {
                let albums = try await NavidromeClient.shared.getAlbumList(type: "alphabeticalByName", size: 100)
                let items = albums.map { album -> CPListItem in
                    let item = CPListItem(text: album.displayName, detailText: album.artist)
                    item.accessoryType = .disclosureIndicator
                    item.handler = { [weak self] _, completion in
                        self?.pushAlbumDetail(album: album)
                        completion()
                    }
                    return item
                }
                let section = CPListSection(items: items)
                await MainActor.run {
                    template.updateSections([section])
                }
            } catch {
                print("CarPlay albums fetch failed: \(error)")
            }
        }
        
        return template
    }
    
    private func pushAlbumDetail(album: Album) {
        Task {
            do {
                guard let container = try await NavidromeClient.shared.getAlbumDetails(id: album.id),
                      let songs = container.song else { return }
                
                let items = songs.enumerated().map { index, song -> CPListItem in
                    _ = song.duration.map { formatTime($0) } ?? ""
                    let item = CPListItem(text: song.title, detailText: song.artist ?? "")
                    item.handler = { _, completion in
                        AudioPlayer.shared.play(song: song, context: songs)
                        completion()
                    }
                    return item
                }
                
                let section = CPListSection(items: items)
                let detailTemplate = CPListTemplate(title: album.displayName, sections: [section])
                
                await MainActor.run {
                    self.interfaceController?.pushTemplate(detailTemplate, animated: true, completion: nil)
                }
            } catch {
                print("CarPlay album detail fetch failed: \(error)")
            }
        }
    }
    
    // MARK: - Playlists
    
    private func makePlaylistsListTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "Playlists", sections: [])
        template.tabImage = UIImage(systemName: "music.note.list")
        template.emptyViewTitleVariants = ["Loading Playlists…"]
        
        Task {
            do {
                let playlists = try await NavidromeClient.shared.getPlaylists()
                let items = playlists.map { playlist -> CPListItem in
                    let detail = "\(playlist.songCount) Songs"
                    let item = CPListItem(text: playlist.name, detailText: detail)
                    item.accessoryType = .disclosureIndicator
                    item.handler = { [weak self] _, completion in
                        self?.pushPlaylistDetail(playlist: playlist)
                        completion()
                    }
                    return item
                }
                let section = CPListSection(items: items)
                await MainActor.run {
                    template.updateSections([section])
                }
            } catch {
                print("CarPlay playlists fetch failed: \(error)")
            }
        }
        
        return template
    }
    
    private func pushPlaylistDetail(playlist: Playlist) {
        Task {
            do {
                guard let detail = try await NavidromeClient.shared.getPlaylist(id: playlist.id),
                      let songs = detail.entry else { return }
                
                let items = songs.map { song -> CPListItem in
                    let item = CPListItem(text: song.title, detailText: song.artist ?? "")
                    item.handler = { _, completion in
                        AudioPlayer.shared.play(song: song, context: songs)
                        completion()
                    }
                    return item
                }
                
                let section = CPListSection(items: items)
                let detailTemplate = CPListTemplate(title: playlist.name, sections: [section])
                
                await MainActor.run {
                    self.interfaceController?.pushTemplate(detailTemplate, animated: true, completion: nil)
                }
            } catch {
                print("CarPlay playlist detail fetch failed: \(error)")
            }
        }
    }
}

// MARK: - CPNowPlayingTemplateObserver

extension CarPlaySceneDelegate: CPNowPlayingTemplateObserver {
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        // Could show a queue list template here in a future iteration
    }
    
    func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {}
}

// MARK: - Handlers (formatTime removed, using global)
