import SwiftUI

struct PenStyleMenu: View {
    @Binding var selectedStyle: PenStyle
    let previewColor: String
    var onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PenStyle.allCases) { style in
                Button {
                    selectedStyle = style
                    onSelect()
                } label: {
                    HStack(spacing: 12) {
                        PenStylePreview(style: style, color: previewColor)
                            .frame(width: 40, height: 40)
                        Text(style.displayName)
                        Spacer()
                        if style == selectedStyle {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 220)
    }
}

private struct PenStylePreview: View {
    let style: PenStyle
    let color: String

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 4, y: size.height - 8))
            path.addQuadCurve(
                to: CGPoint(x: size.width - 4, y: 8),
                control: CGPoint(x: size.width / 2, y: size.height / 2)
            )
            context.applyPenStyle(style)
            context.stroke(path, with: .color(Color(hex: color)), lineWidth: style.maxWidth)
        }
    }
}
