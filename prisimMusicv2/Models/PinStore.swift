import Foundation
import Observation

struct PinnedItem: Codable, Identifiable, Equatable {
    let id: String
    let type: PinType
    let name: String
    let coverArtId: String?

    enum PinType: String, Codable {
        case album, playlist
    }
}

@Observable
class PinStore {
    static let shared = PinStore()
    private let key = "pinnedItems"
    static let maxPins = 6

    private var _pins: [PinnedItem] = []
    var pins: [PinnedItem] {
        get { _pins }
        set { _pins = newValue; save() }
    }

    private init() { load() }

    func isPinned(_ id: String) -> Bool {
        pins.contains { $0.id == id }
    }

    /// Adds the item to the pin list.
    /// Returns `true` if the item was added or was already pinned.
    /// Returns `false` if the pin list is at max capacity (`maxPins`).
    @discardableResult
    func pin(_ item: PinnedItem) -> Bool {
        guard !isPinned(item.id) else { return true }
        guard pins.count < PinStore.maxPins else { return false }
        pins.append(item)
        return true
    }

    func unpin(_ id: String) {
        pins.removeAll { $0.id == id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pins) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PinnedItem].self, from: data) else { return }
        _pins = decoded
    }
}
