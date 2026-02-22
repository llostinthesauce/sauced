import SwiftUI
import Observation

/// Lightweight, app-wide error banner system.
/// Post errors from anywhere via `ErrorBanner.shared.show("message")`.
@Observable
class ErrorBanner {
    static let shared = ErrorBanner()

    var message: String?
    var isVisible = false

    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// Show an error banner for a configurable duration (default 4s).
    func show(_ message: String, duration: TimeInterval = 4.0) {
        dismissTask?.cancel()
        self.message = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.isVisible = true
        }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.dismiss()
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            self.isVisible = false
        }
    }
}

// MARK: - Banner View

struct ErrorBannerView: View {
    @Environment(ErrorBanner.self) var banner

    var body: some View {
        if banner.isVisible, let message = banner.message {
            VStack {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(message)
                        .font(.prismCaption)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        banner.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .background(Color.red.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 16)

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(100)
        }
    }
}
