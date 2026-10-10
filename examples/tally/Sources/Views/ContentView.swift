import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Counter.createdAt) private var counters: [Counter]
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Group {
                if counters.isEmpty {
                    ContentUnavailableView {
                        Label("No Counters", systemImage: "plus.circle")
                    } description: {
                        Text("Count anything: glasses of water, push-ups, pages read.")
                    } actions: {
                        Button("Add Counter") { isAdding = true }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("emptyAddCounter")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(counters) { counter in
                                CounterCard(counter: counter) {
                                    withAnimation { context.delete(counter) }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Tally")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Counter", systemImage: "plus") { isAdding = true }
                        .accessibilityIdentifier("addCounter")
                }
            }
            .sheet(isPresented: $isAdding) {
                AddCounterView { name, color in
                    context.insert(Counter(name: name, color: color))
                }
            }
        }
        .accessibilityIdentifier("home")
    }
}

#Preview("With counters") {
    let container = try! ModelContainer(for: Counter.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    SampleData.insert(into: container.mainContext)
    return ContentView().modelContainer(container)
}

#Preview("Empty") {
    ContentView().modelContainer(for: Counter.self, inMemory: true)
}
