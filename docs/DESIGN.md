# prism-music — Design & Architecture

A modern iOS music player for self-hosted [Navidrome](https://www.navidrome.org/) servers, built in SwiftUI. Connects via the Subsonic API and provides a glass-morphic player UI with dynamic accent colors derived from album art.

---

## Architecture Overview

```
NavidromeClient     ← Subsonic API (search, albums, playlists, cover art)
AudioPlayer         ← Singleton @Observable — playback, queue, shuffle, accent colors
PinStore            ← UserDefaults-backed pinned albums/playlists (max 6)
PlaylistArtworkStore ← Documents directory — custom playlist JPEG artwork
```

All four are injected via SwiftUI `.environment()` at the app root in `PrismMusicApp`.

---

## Views

| View | Purpose |
|---|---|
| `ContentView` | 3-tab root: Library / Playlists / Search |
| `LibraryView` | Artists, Albums, Songs nav + pinned horizontal scroll row |
| `LibrarySubviews` | Album list, Playlist list, detail views, PlaylistsTabView |
| `AlbumDetailView` | Track list + Play / Shuffle buttons |
| `GlassPlayer` | Full-screen player with mesh gradient, scrubber, controls |
| `MiniPlayerBar` | Collapsed mini player above tab bar |
| `SearchView` | Search input + results |
| `SettingsView` | Server config (URL, username, password) — accessed via gear icon |
| `QueueView` | Up Next queue with reorder/clear |
| `ServerSetupView` | First-launch server configuration |

### Components (`Views/Components/`)
| Component | Purpose |
|---|---|
| `PlaylistArtworkView` | Artwork with priority: custom local → server → 2×2 collage → placeholder |
| `MiniPlayerBar` | Persistent mini player with glass + accent color styling |
| `AirPlayButton` | Native AirPlay route picker button |
| `CoverFlowView` | Horizontal coverflow album browser |
| `SmartArtworkImage` | AsyncImage wrapper with fallback placeholder |
| `SongInfoSheet` | Share sheet for stream links |

---

## Key Design Decisions

### Dynamic Accent Colors
`AudioPlayer` extracts dominant colors from the current song's cover art using `ImageColorExtractor` and exposes `accentColors: [Color]`. All views consuming accent color read from `audioPlayer.primaryAccent` — no per-view extraction.

### Shuffle
`AudioPlayer.shufflePlay(songs:)` picks a random first song, shuffles the rest into the queue, and sets `isShuffled = true`. Call sites in `AlbumDetailView` and `PlaylistDetailView` use this method — they do not set `isShuffled` directly.

### Pinned Items
`PinStore` stores up to 6 `PinnedItem` values (album or playlist) as JSON in `UserDefaults`. Long-press context menus on album/playlist cards expose Pin / Unpin. A 7th pin attempt shows an alert.

### Playlist Artwork
`PlaylistArtworkStore` saves custom JPEG files keyed by playlist ID to the app's Documents directory. `PlaylistArtworkView` loads these on appear and updates on change via `PhotosPicker`.

### Background Playback
`App-Info.plist` includes `UIBackgroundModes: audio`, enabling playback to continue when the app is backgrounded, the screen is locked, or the device is connected to CarPlay.

---

## Tech Stack

- **SwiftUI** + **Observation** (`@Observable`)
- **AVFoundation / AVKit** — audio playback
- **CryptoKit** — MD5 auth for Subsonic API
- **PhotosUI** — custom playlist artwork upload
- **iOS 17.0+** (requires `@Observable` and `MeshGradient`)
- **Xcode 15.0+**

---

## Server

Connects to any Navidrome or Subsonic-compatible server. Configure on first launch via Settings (gear icon in Library). Supports HTTP via App Transport Security exceptions for local-network use.

This app is designed to work with the Navidrome instance running on the Raspberry Pi at `10.0.0.101:4533`, serving music from a 256GB exFAT USB drive at `/mnt/music`.
