import SwiftUI
import Observation

struct QueueView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(\.dismiss) var dismiss
    
    @State private var editMode: EditMode = .inactive

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
                        Button("Clear Queue") {
                            withAnimation {
                                audioPlayer.queue = []
                            }
                        }
                        .foregroundStyle(.red)
                        .padding(.top)
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
        }
        .presentationDetents([.large])
    }
}

struct SongRow: View {
    let song: Song
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundStyle(.purple)
            }
            
            VStack(alignment: .leading) {
                Text(song.title)
                    .foregroundStyle(.primary)
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
    
    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
