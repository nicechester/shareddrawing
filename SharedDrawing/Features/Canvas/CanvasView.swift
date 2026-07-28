import SwiftUI

struct CanvasView: View {
    @State private var viewModel: CanvasViewModel
    @State private var currentStroke: Stroke?
    @State private var isDrawing = false
    @State private var lastUpdateTime: Date?
    @State private var showCanvasIDSheet = false
    @State private var showClearConfirmation = false
    @State private var isPaletteCollapsed = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var backgroundImage: UIImage?

    @Binding var canvasId: String
    let repository: CanvasRepository
    let authService: AuthService

    private let throttleInterval: TimeInterval = 0.05  // ~50ms throttle for live updates

    init(canvasId: Binding<String>, repository: CanvasRepository, authService: AuthService) {
        self._canvasId = canvasId
        self.repository = repository
        self.authService = authService
        self._viewModel = State(initialValue: CanvasViewModel(
            canvasId: canvasId.wrappedValue,
            repository: repository,
            authService: authService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Canvas ID header with Undo/Share buttons
            HStack(spacing: 8) {
                Button(action: {
                    Task { await viewModel.undo() }
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                }
                .disabled(!viewModel.canUndo)

                Button(action: {
                    showCanvasIDSheet = true
                }) {
                    HStack {
                        Text("\(canvasId)")
                            .font(.title)
                            .monospaced()
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }

                ShareLink(
                    item: URL(string: "https://shared-drawing.web.app/?id=\(canvasId)") ?? URL(fileURLWithPath: ""),
                    subject: Text("Join my canvas"),
                    message: Text("Draw together on canvas \(canvasId)")
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                }

                Button(action: {
                    showClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(.systemGray6)
                    .ignoresSafeArea(edges: .top)
            )
            .sheet(isPresented: $showCanvasIDSheet) {
                ChangeCanvasIDSheet(
                    canvasId: $canvasId,
                    isPresented: $showCanvasIDSheet
                )
            }
            .alert("Clear All Strokes?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllStrokes()
                }
            } message: {
                Text("This will permanently delete all drawings on this canvas. This action cannot be undone.")
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(isPresented: $showImagePicker, selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                guard let newImage = newImage else { return }
                self.backgroundImage = newImage
                Task {
                    do {
                        // TODO: Upload to GCS and get signed URL
                        try await viewModel.updateBackgroundImage("placeholder-url")
                    } catch {
                        print("❌ Error uploading image: \(error)")
                    }
                }
            }

            // Drawing Canvas with floating palette on top
            ZStack(alignment: .topLeading) {
                // Canvas
                    ZStack {
                        Color.white

                        if let bgImage = backgroundImage {
                            Image(uiImage: bgImage)
                                .resizable()
                                .ignoresSafeArea()
                        }

                        Canvas { context, size in
                            for stroke in viewModel.strokes {
                                renderStroke(stroke, in: &context)
                            }

                            if let current = currentStroke {
                                renderStroke(current, in: &context)
                            }
                        }
                    }

                    StrokeCaptureView(
                        onPointsCapture: { points in
                            print("📍 Touch: \(points.count) points, isDrawing=\(isDrawing)")
                            guard !points.isEmpty else { return }

                            if !isDrawing {
                                print("🎨 Starting new stroke")
                                isDrawing = true
                                currentStroke = viewModel.startStroke(at: points.first ?? .zero)
                            }

                            if var stroke = currentStroke {
                                for point in points {
                                    viewModel.addStrokePoint(point, to: &stroke)
                                }
                                currentStroke = stroke

                                let now = Date()
                                if lastUpdateTime == nil || now.timeIntervalSince(lastUpdateTime ?? now) >= throttleInterval {
                                    lastUpdateTime = now
                                    Task {
                                        do {
                                            try await viewModel.repository.updateStroke(stroke, in: canvasId)
                                        } catch {
                                            print("❌ Error updating stroke: \(error)")
                                        }
                                    }
                                }
                            }
                        },
                        onStrokeEnded: {
                            print("✋ Stroke ended, submitting \(currentStroke?.points.count ?? 0) points")
                            guard let stroke = currentStroke else { return }
                            let endedStroke = stroke
                            currentStroke = nil
                            isDrawing = false
                            Task {
                                await viewModel.submitStroke(endedStroke)
                                print("✅ Stroke submitted")
                            }
                        }
                    )

                // Floating color palette (top-left)
                VStack(spacing: 12) {
                    Button(action: { isPaletteCollapsed.toggle() }) {
                        Text(isPaletteCollapsed ? "v" : "^")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                            .frame(width: 24, height: 24)
                    }

                    if !isPaletteCollapsed {
                        ColorPalettePicker(
                            selectedColor: $viewModel.currentColor,
                            vertical: true,
                            onImagePickerTapped: { showImagePicker = true }
                        )
                    } else {
                        Circle()
                            .fill(Color(hex: viewModel.currentColor))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 48)
        .onChange(of: canvasId) { _, newCanvasId in
            guard !newCanvasId.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            currentStroke = nil
            isDrawing = false
            viewModel.switchToCanvas(newCanvasId)
        }
    }
    
    private func clearAllStrokes() {
        Task {
            viewModel.recordClear(viewModel.strokes)
            for stroke in viewModel.strokes {
                do {
                    try await repository.removeStroke(id: stroke.id, from: canvasId)
                } catch {
                    print("❌ Error clearing stroke: \(error)")
                }
            }
            viewModel.strokes = []
        }
    }

    private func renderStroke(_ stroke: Stroke, in context: inout GraphicsContext) {
        guard stroke.points.count > 1 else { return }

        var path = Path()
        let firstPoint = stroke.points[0]
        path.move(to: CGPoint(x: firstPoint.x, y: firstPoint.y))

        for point in stroke.points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: point.y))
        }

        let color = Color(hex: stroke.color)
        context.stroke(
            path,
            with: .color(color),
            lineWidth: stroke.width
        )
    }
}

struct ChangeCanvasIDSheet: View {
    @Binding var canvasId: String
    @Binding var isPresented: Bool
    @State private var editingID = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Canvas ID")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Canvas ID")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Canvas ID", text: $editingID)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        editingID = generateRandomID()
                    }) {
                        Text("Generate")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        let trimmed = editingID.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            canvasId = trimmed
                            isPresented = false
                        }
                    }) {
                        Text("Open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .onAppear {
                editingID = canvasId
            }
        }
    }

    private func generateRandomID() -> String {
        let characters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<5).map { _ in characters.randomElement()! })
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgb = Int(hex, radix: 16) ?? 0

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
