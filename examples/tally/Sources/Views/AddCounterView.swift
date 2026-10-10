import SwiftUI

struct AddCounterView: View {
    let onSave: (String, CounterColor) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color: CounterColor = .orange
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Glasses of water", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .accessibilityIdentifier("counterName")
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(CounterColor.allCases) { option in
                            Circle()
                                .fill(option.color.gradient)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if option == color {
                                        Image(systemName: "checkmark").font(.headline).foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { color = option }
                                .accessibilityLabel(option.rawValue.capitalized)
                                .accessibilityAddTraits(option == color ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                        .accessibilityIdentifier("saveCounter")
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        onSave(trimmedName, color)
        dismiss()
    }
}
