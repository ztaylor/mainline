import SwiftData

/// Seeded with the `-seed-sample-data` launch argument, used for screenshots.
enum SampleData {
    @MainActor
    static func insert(into context: ModelContext) {
        let samples: [(String, Int, CounterColor)] = [
            ("Glasses of water", 6, .blue),
            ("Push-ups", 42, .orange),
            ("Pages read", 128, .purple),
            ("Coffees", 2, .teal),
        ]
        for (offset, sample) in samples.enumerated() {
            context.insert(Counter(
                name: sample.0, count: sample.1, color: sample.2,
                createdAt: .now.addingTimeInterval(Double(offset))))
        }
        try? context.save()
    }
}
