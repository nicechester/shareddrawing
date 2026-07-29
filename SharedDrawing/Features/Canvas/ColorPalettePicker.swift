import SwiftUI

struct ColorPalettePicker: View {
    @Binding var selectedColor: String
    var vertical: Bool = false
    var onImagePickerTapped: (() -> Void)?

    private let colors: [(name: String, hex: String)] = [
        ("Black", "#000000"),
        ("Red", "#FF3B30"),
        ("Green", "#34C759"),
        ("Blue", "#007AFF"),
        ("Yellow", "#FFCC00"),
    ]

    var body: some View {
        if vertical {
            VStack(spacing: 12) {
                ForEach(colors, id: \.hex) { color in
                    Button(action: { selectedColor = color.hex }) {
                        Circle()
                            .fill(Color(hex: color.hex))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color.hex ? 3 : 0)
                            )
                    }
                    .accessibilityLabel(color.name)
                }

                Divider()
                    .padding(.vertical, 4)

                Button(action: { onImagePickerTapped?() }) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Add background image")
            }
            .frame(width: 48)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
        } else {
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

                Button(action: { onImagePickerTapped?() }) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Add background image")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    @Previewable @State var selectedColor = "#000000"
    ColorPalettePicker(selectedColor: $selectedColor, onImagePickerTapped: {
        print("Image picker tapped")
    })
        .padding()
}
