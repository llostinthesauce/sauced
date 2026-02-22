import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Recently Added Widget

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), albums: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), albums: .placeholder)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // In a real implementation with App Groups, we would fetch from Navidrome here.
        // For now, we supply placeholder data indicating the widget is ready.
        let entry = SimpleEntry(date: Date(), albums: .placeholder)
        
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let albums: [WidgetAlbum]
}

struct WidgetAlbum: Identifiable {
    let id: String
    let title: String
    let artist: String
    let coverName: String // Placeholder for local asset or data
    
    static let placeholder: [WidgetAlbum] = [
        WidgetAlbum(id: "1", title: "Midnight Marauders", artist: "A Tribe Called Quest", coverName: "PlaceholderArt1"),
        WidgetAlbum(id: "2", title: "Currents", artist: "Tame Impala", coverName: "PlaceholderArt2"),
        WidgetAlbum(id: "3", title: "Blonde", artist: "Frank Ocean", coverName: "PlaceholderArt3"),
        WidgetAlbum(id: "4", title: "In Rainbows", artist: "Radiohead", coverName: "PlaceholderArt4")
    ]
}

struct SaucedWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading) {
            Text("Recently Added")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                ForEach(entry.albums.prefix(family == .systemMedium ? 4 : 2)) { album in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(systemName: "music.quarternote.3")
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                        
                        Text(album.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(album.artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            Color("WidgetBackground") // Ensure this color asset exists in the Widget target
        }
    }
}

@main
struct SaucedWidget: Widget {
    let kind: String = "SaucedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SaucedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recently Added")
        .description("See your newest albums from Navidrome.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
