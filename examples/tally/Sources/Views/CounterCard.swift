import SwiftUI

/// Tap anywhere on the card to count up; the minus button counts down.
struct CounterCard: View {
    let counter: Counter
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(counter.name)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                Text(counter.count, format: .number)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(counter.count)))
                    .accessibilityIdentifier("count.\(counter.name)")
            }
            Spacer()
            Button {
                withAnimation(.snappy) { counter.decrement() }
            } label: {
                Image(systemName: "minus")
                    .font(.title2.weight(.bold))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.25), in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(counter.count == 0)
            .accessibilityLabel("Decrease \(counter.name)")
            .accessibilityIdentifier("decrement.\(counter.name)")
        }
        .padding(20)
        .background(counter.color.color.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            withAnimation(.snappy) { counter.increment() }
        }
        .sensoryFeedback(.increase, trigger: counter.count)
        .contextMenu {
            Button("Reset", systemImage: "arrow.counterclockwise") {
                withAnimation { counter.reset() }
            }
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Increase") { counter.increment() }
        .accessibilityIdentifier("counter.\(counter.name)")
    }
}
