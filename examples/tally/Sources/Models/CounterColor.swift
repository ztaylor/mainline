import SwiftUI

enum CounterColor: String, CaseIterable, Identifiable {
    case orange, red, pink, purple, indigo, blue, teal, green

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        case .indigo: .indigo
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        }
    }
}
