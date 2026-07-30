import SwiftUI

struct ColorPalettePicker: View {
    @Binding var selectedColor: String
    @Binding var selectedPenStyle: PenStyle
    @Binding var isPointerMode: Bool
    @Binding var isAMode: Bool
    var onImagePickerTapped: (() -> Void)?
    var onClearTapped: () -> Void

    @State private var isExpanded: Bool = false
    @State private var showingStyleSubmenu: Bool = false
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .alert("Clear All Strokes?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { isExpanded = false }
            Button("Clear", role: .destructive) {
                onClearTapped()
                isExpanded = false
            }
        } message: {
            Text("This will permanently delete all drawings on this canvas. This action cannot be undone.")
        }
    }

    private var collapsedContent: some View {
        Group {
            if isPointerMode {
                pointerCollapsedView
            } else if isAMode {
                aCollapsedView
            } else {
                penCollapsedView
            }
        }
        .padding(8)
        .accessibilityLabel(isPointerMode ? "Pointer mode — tap to expand palette" : isAMode ? "A mode — tap to expand palette" : "Expand palette")
    }

    private var pointerCollapsedView: some View {
        Button(action: { isExpanded = true }) {
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
        }
    }

    private var aCollapsedView: some View {
        Button(action: { isExpanded = true }) {
            Text("A")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.green))
        }
    }

    private var penCollapsedView: some View {
        Button(action: { isExpanded = true }) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(hex: selectedColor))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color.blue))
                    .offset(x: 4, y: 4)
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showingStyleSubmenu {
                styleSubmenuContent
            } else {
                mainPaletteContent
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    private var mainPaletteContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color row
            HStack(spacing: 8) {
                ForEach(["#000000", "#FF3B30", "#00C7BE", "#FFCC00", "#5856D6"], id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                        isPointerMode = false
                        isAMode = false
                        isExpanded = false
                    }) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2)
                            )
                    }
                }
                Spacer()
            }

            Divider()

            // Pen row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "pencil")
                        Text(selectedPenStyle.displayName)
                        if !isPointerMode && !isAMode {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                }
                Spacer()
                Button(action: { showingStyleSubmenu = true }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
            .onTapGesture {
                isPointerMode = false
                isAMode = false
                isExpanded = false
            }

            // Pointer row
            HStack {
                Image(systemName: "hand.point.up.fill")
                Text("Pointer")
                if isPointerMode {
                    Image(systemName: "checkmark")
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                isPointerMode = true
                isAMode = false
                isExpanded = false
            }

            // A mode row
            HStack {
                Text("A")
                    .font(.system(size: 16, weight: .bold))
                Text("Handwrite")
                if isAMode {
                    Image(systemName: "checkmark")
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                isPointerMode = false
                isAMode = true
                isExpanded = false
            }

            Divider()

            // Image row
            HStack {
                Image(systemName: "photo.fill")
                Text("Add Image")
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                onImagePickerTapped?()
                isExpanded = false
            }

            // Clear row
            HStack {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                Text("Clear")
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                showClearConfirmation = true
            }
        }
    }

    private var styleSubmenuContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { showingStyleSubmenu = false }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .padding(.bottom, 8)

            PenStyleMenu(
                selectedStyle: $selectedPenStyle,
                previewColor: selectedColor,
                onSelect: {
                    isPointerMode = false
                    isAMode = false
                    showingStyleSubmenu = false
                    isExpanded = false
                }
            )
        }
    }
}
