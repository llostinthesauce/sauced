import SwiftUI

// MARK: - Font
// Verdana is the closest iOS-available match to the Lucida Grande / Lucida Sans stack.

extension Font {
    static func prism(size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom("Verdana", size: size, relativeTo: style)
    }

    static var prismLargeTitle:  Font { .custom("Verdana", size: 32, relativeTo: .largeTitle) }
    static var prismTitle:       Font { .custom("Verdana", size: 26, relativeTo: .title) }
    static var prismTitle2:      Font { .custom("Verdana", size: 21, relativeTo: .title2) }
    static var prismTitle3:      Font { .custom("Verdana", size: 18, relativeTo: .title3) }
    static var prismHeadline:    Font { .custom("Verdana", size: 16, relativeTo: .headline) }
    static var prismBody:        Font { .custom("Verdana", size: 15, relativeTo: .body) }
    static var prismSubheadline: Font { .custom("Verdana", size: 13, relativeTo: .subheadline) }
    static var prismCaption:     Font { .custom("Verdana", size: 11, relativeTo: .caption) }
    static var prismCaption2:    Font { .custom("Verdana", size: 10, relativeTo: .caption2) }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var material: Material

    func body(content: Content) -> some View {
        content
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, material: Material = .ultraThinMaterial) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, material: material))
    }
}

// MARK: - Sort Chip Row

struct SortChipRow<T: RawRepresentable & CaseIterable & Hashable>: View
where T.RawValue == String, T.AllCases: RandomAccessCollection {
    let selection: T
    let accent: Color
    let onSelect: (T) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    let isSelected = selection == option
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onSelect(option)
                        }
                    } label: {
                        Text(option.rawValue)
                            .font(.prismCaption)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(isSelected ? accent : Color.clear)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                isSelected ? Color.clear : Color.primary.opacity(0.2),
                                                lineWidth: 0.8
                                            )
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Section Header Chip

struct SectionHeader: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.prismCaption)
                .fontWeight(.bold)
                .foregroundStyle(accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accent.opacity(0.12))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Shared Utilities

/// Format a TimeInterval (seconds as Double) into "m:ss" string.
func formatTime(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

/// Format an Int (seconds) into "m:ss" string.
func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}
