import SwiftUI

struct SongInfoSheet: View {
    let song: Song
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Tech Specs")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)
            
            VStack(spacing: 16) {
                InfoRow(label: "Format", value: song.suffix?.uppercased() ?? "UNKNOWN")
                InfoRow(label: "Bitrate", value: song.bitRate.map { "\($0) kbps" } ?? "Unknown")
                InfoRow(label: "Year", value: song.year.map(String.init) ?? "-")
                InfoRow(label: "Genre", value: song.genre ?? "-")
                InfoRow(label: "Duration", value: formatDuration(song.duration))
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if let path = song.path {
                VStack(alignment: .leading, spacing: 4) {
                    Text("File Path")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }
    
    func formatDuration(_ duration: Int?) -> String {
        guard let d = duration else { return "-" }
        let m = d / 60
        let s = d % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}
