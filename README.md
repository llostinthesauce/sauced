# Sauced

A modern, glassmorphic music player for iOS, built with SwiftUI and designed for **Navidrome** / **Subsonic** servers.

## Features

- **Glass Player UI**: Immersive player interface with dynamic blur and mesh gradients.
- **Subsonic Core**: Full integration with the Subsonic API (v1.16.1+).
- **Library Management**: Browse Artists, Albums, Songs, and Playlists.
- **Favorites**: Toggle favorite songs with sync back to the server.
- **Queue Management**: Viewing, reordering, and clearing the "Up Next" queue.
- **AirPlay Support**: Native AirPlay routing from the player.
- **Share**: Share direct stream links to songs.
- **Search**: Fast search across your entire library.
- **Offline First**: (Coming Soon / foundational support via Cache)

## Requirements

- **iOS 17.0+** (Uses `@Observable` and `MeshGradient`)
- **Xcode 15.0+**
- A self-hosted **Navidrome** (or compatible Subsonic) server.

## Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/llostinthesauce/sauced.git
   cd sauced
   ```

2. **Open in Xcode**:
   Open `prisimMusicv2.xcodeproj`.

3. **Configure Signing**:
   Click on the project root in the navigator -> Signing & Capabilities -> Select your Team.

4. **Build & Run**:
   Select your simulator or device and press `Cmd+R`.

## Configuration

On the first launch, navigate to the **Settings** tab (gear icon) and enter your server details:

- **Server URL**: e.g., `https://music.yourdomain.com` or `http://192.168.1.100:4533`
- **Username**
- **Password**

*Note: The app supports HTTP (non-SSL) connections via configured App Transport Security exceptions, useful for local network testing.*

## Technologies

- **SwiftUI**
- **Observation Framework** (`@Observable`)
- **AVKit / AVFoundation**
- **CryptoKit** (MD5 Auth)
