import SwiftUI
import Observation

struct QueueView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(NavidromeClient.self) var client
    @Environment(\.dismiss) var dismiss
    
    @State private var editMode: EditMode = .inactive
    @State private var showSaveDialog = false
    @State private var playlistName = ""

    var body: some View {
        NavigationStack {
            List {
                // Now Playing section
                if let current = audioPlayer.currentSong {
                    Section("Now Playing") {
                        SongRow(song: current, isPlaying: true)
                    }
                }
                
                // Up Next
                Section {
                    ForEach(audioPlayer.queue) { song in
                        SongRow(song: song, isPlaying: false)
                    }
                    .onMove { from, to in
                        var newQueue = audioPlayer.queue
                        newQueue.move(fromOffsets: from, toOffset: to)
                        audioPlayer.queue = newQueue
                    }
                    .onDelete { indexSet in
                        var newQueue = audioPlayer.queue
                        newQueue.remove(atOffsets: indexSet)
                        audioPlayer.queue = newQueue
                    }
                } header: {
                    HStack {
                        Text("Up Next")
                        Spacer()
                        Text("\(audioPlayer.queue.count) songs")
                            .font(.caption)
                    }
                } footer: {
                    if !audioPlayer.queue.isEmpty {
                        HStack(spacing: 20) {
                            Button {
                                playlistName = ""
                                showSaveDialog = true
                            } label: {
                                Label("Save as Playlist", systemImage: "music.note.list")
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Button("Clear Queue") {
                                withAnimation {
                                    audioPlayer.queue = []
                                }
                            }
                            .foregroundStyle(.red)
                            .font(.caption)
                        }
                        .padding(.top, 8)
                    }
                }
                
                // History
                if !audioPlayer.history.isEmpty {
                    Section("History") {
                        ForEach(audioPlayer.history.reversed()) { song in
                            SongRow(song: song, isPlaying: false)
                                .opacity(0.6)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(editMode == .active ? "Done" : "Edit") {
                        withAnimation {
                            editMode = (editMode == .active) ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Save as Playlist", isPresented: $showSaveDialog) {
                TextField("Playlist Name", text: $playlistName)
                Button("Save") {
                    guard !playlistName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let songIds = audioPlayer.queue.map { $0.id }
                    Task {
                        try? await client.createPlaylist(name: playlistName, songIds: songIds)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save the current \(audioPlayer.queue.count) queued songs as a new playlist.")
            }
        }
        .presentationDetents([.large])
    }
}

struct SongRow: View {
    @Environment(AudioPlayer.self) var audioPlayer
    let song: Song
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if isPlaying {
                if audioPlayer.isPlaying {
                    NowPlayingBarsView(color: .purple)
                        .frame(width: 16, height: 16)
                } else {
                    NowPlayingBarsPausedView(color: .purple)
                        .frame(width: 16, height: 16)
                }
            }
            
            VStack(alignment: .leading) {
                Text(song.title)
                    .foregroundStyle(isPlaying ? .purple : .primary)
                    .lineLimit(1)
                Text(song.artist ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            
            if let duration = song.duration {
                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !isPlaying {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
            }
        }
    }
    // formatTime is defined in PrismStyle.swift
}


