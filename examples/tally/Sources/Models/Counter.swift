import Foundation
import SwiftData

@Model
final class Counter {
    var name: String
    var count: Int
    var colorName: String
    var createdAt: Date

    init(name: String, count: Int = 0, color: CounterColor = .orange, createdAt: Date = .now) {
        self.name = name
        self.count = max(0, count)
        self.colorName = color.rawValue
        self.createdAt = createdAt
    }

    var color: CounterColor {
        get { CounterColor(rawValue: colorName) ?? .orange }
        set { colorName = newValue.rawValue }
    }

    func increment(by step: Int = 1) {
        count += step
    }

    /// Counts never go below zero.
    func decrement(by step: Int = 1) {
        count = max(0, count - step)
    }

    func reset() {
        count = 0
    }
}
