import SwiftUI

struct CoverFlowView: View {
    let albums: [Album]
    @Environment(NavidromeClient.self) var client
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(albums) { album in
                    NavigationLink(destination: AlbumDetailView(album: album)) {
                        CoverFlowItem(album: album)
                            .frame(width: 280, height: 280)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.8)
                                    .rotation3DEffect(
                                        .degrees(phase.value * -30),
                                        axis: (x: 0, y: 1, z: 0)
                                    )
                                    .opacity(phase.isIdentity ? 1.0 : 0.6)
                                    .offset(y: phase.isIdentity ? 0 : 20)
                            }
                    }
                    .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 40, for: .scrollContent)
        .frame(height: 320)
    }
}

struct CoverFlowItem: View {
    let album: Album

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SmartArtworkImage(
                coverArtId: album.coverArt,
                artist: album.artist,
                album: album.displayName,
                size: 600
            )
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 8)
            
            // Glass overlay
            LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .bottom, endPoint: .top)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(album.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(20)
        }
    }
}
