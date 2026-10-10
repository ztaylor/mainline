import SwiftData
import SwiftUI

@main
struct TallyApp: App {
    let container: ModelContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        // UI tests and screenshot runs use a throwaway in-memory store.
        let inMemory = arguments.contains("-ui-testing") || arguments.contains("-seed-sample-data")
        do {
            container = try ModelContainer(
                for: Counter.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        if arguments.contains("-seed-sample-data") {
            SampleData.insert(into: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
