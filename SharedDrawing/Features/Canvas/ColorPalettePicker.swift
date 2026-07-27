import SwiftUI

struct ColorPalettePicker: View {
    @Binding var selectedColor: String

    private let colors: [(name: String, hex: String)] = [
        ("Black", "#000000"),
        ("Red", "#FF3B30"),
        ("Green", "#34C759"),
        ("Blue", "#007AFF"),
        ("Yellow", "#FFCC00"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(colors, id: \.hex) { color in
                Button(action: { selectedColor = color.hex }) {
                    Circle()
                        .fill(Color(hex: color.hex))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedColor == color.hex ? 3 : 0)
                        )
                }
                .accessibilityLabel(color.name)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    @Previewable @State var selectedColor = "#000000"
    ColorPalettePicker(selectedColor: $selectedColor)
        .padding()
}
