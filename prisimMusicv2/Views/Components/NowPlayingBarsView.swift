import SwiftUI
import Combine

/// Animated 3-bar equalizer indicator — shows when a song is currently playing.
struct NowPlayingBarsView: View {
    var color: Color = .accentColor
    var barCount: Int = 3
    
    @State private var phases: [Double] = [0.3, 0.7, 0.5]
    
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: CGFloat(phases[i]) * 14)
                    .animation(
                        .easeInOut(duration: 0.4).delay(Double(i) * 0.1),
                        value: phases[i]
                    )
            }
        }
        .onReceive(timer) { _ in
            for i in 0..<barCount {
                phases[i] = Double.random(in: 0.3...1.0)
            }
        }
    }
}

/// A non-animated static version for previews or paused state.
struct NowPlayingBarsPausedView: View {
    var color: Color = .secondary
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach([0.6, 0.9, 0.5], id: \.self) { h in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: CGFloat(h) * 14)
            }
        }
    }
}
