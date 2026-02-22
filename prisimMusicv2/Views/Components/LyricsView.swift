import SwiftUI

/// Full-screen lyrics overlay, toggled from the GlassPlayer info area.
struct LyricsView: View {
    let song: Song
    @Environment(NavidromeClient.self) var client
    @Environment(\.dismiss) var dismiss
    
    @State private var lyrics: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title)
                            .font(.prismTitle2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        if let artist = song.artist {
                            Text(artist)
                                .font(.prismBody)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Divider()
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if let lyrics, !lyrics.isEmpty {
                        Text(lyrics)
                            .font(.prismBody)
                            .lineSpacing(8)
                            .foregroundStyle(.primary)
                            .padding(.horizontal)
                            .textSelection(.enabled)
                    } else {
                        ContentUnavailableView(
                            "No Lyrics Available",
                            systemImage: "text.quote",
                            description: Text("Lyrics for this track were not found on the server.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await loadLyrics()
        }
    }
    
    private func loadLyrics() async {
        isLoading = true
        do {
            let result = try await client.getLyrics(artist: song.artist, title: song.title)
            lyrics = result?.value
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
