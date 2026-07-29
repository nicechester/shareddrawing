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
    @State private var isPointerMode = false  // false=pen, true=pointer/pan
    @State private var lastPointerPosition: CGPoint = .zero
    @GestureState private var gestureZoom: CGFloat = 1.0
    @GestureState private var gestureRotation: Double = 0.0
    @State private var canvasSize: CGSize = .zero

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
            // Canvas ID header with Undo/Pan/Share buttons
            HStack(spacing: 8) {
                Button(action: {
                    Task { await viewModel.undo() }
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                }
                .disabled(!viewModel.canUndo)

                if viewModel.zoomScale != 1.0 || viewModel.rotationAngle != 0.0 {
                    Button(action: {
                        viewModel.resetTransform()
                    }) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: 14))
                    }
                }

                // Pointer/Pen toggle
                Button(action: { isPointerMode.toggle() }) {
                    Image(systemName: isPointerMode ? "hand.point.up.fill" : "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(isPointerMode ? .blue : .primary)
                }

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
                        guard let jpegData = newImage.jpegData(compressionQuality: 0.8) else {
                            print("❌ Failed to compress image")
                            return
                        }

                        // Upload to GCS and get signed URL
                        guard let serviceAccount = ServiceAccountLoader.loadKey() else {
                            print("❌ Service account key not found")
                            return
                        }

                        let uploader = GCSImageUploader(
                            bucket: "shared-drawing",
                            serviceAccountEmail: serviceAccount.client_email,
                            privateKeyPEM: serviceAccount.private_key,
                            projectId: serviceAccount.project_id
                        )

                        let signedURL = try await uploader.uploadImage(jpegData, canvasId: canvasId, userId: authService.currentUserID ?? "anonymous")
                        let width = Double(newImage.size.width)
                        let height = Double(newImage.size.height)
                        try await viewModel.updateBackgroundImage(signedURL, width: width, height: height)
                        print("✅ Background image uploaded and stored: \(signedURL)")
                    } catch {
                        print("❌ Error uploading image: \(error)")
                    }
                }
            }
            .onChange(of: viewModel.backgroundImageUrl) { _, newUrl in
                if let urlString = newUrl, let url = URL(string: urlString) {
                    Task {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            if let uiImage = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    self.backgroundImage = uiImage
                                    print("✅ Background image loaded from URL")
                                }
                                // Backfill dimensions if not already set
                                let width = Double(uiImage.size.width)
                                let height = Double(uiImage.size.height)
                                await viewModel.backfillImageDimensionsIfNeeded(width: width, height: height)
                            }
                        } catch {
                            print("❌ Failed to load background image from URL: \(error)")
                        }
                    }
                } else {
                    // URL was cleared, remove background image
                    backgroundImage = nil
                    print("✅ Background image cleared")
                }
            }

            // Drawing Canvas with floating palette on top
            ZStack(alignment: .topLeading) {
                // Canvas
                ZStack {
                    Color.white

                    Canvas { context, size in
                        let worldSize = viewModel.worldSize(fallback: size)
                        let fitScale = viewModel.fitScale(canvasSize: size)
                        let transform = canvasTransform(worldSize: worldSize, fitScale: fitScale, canvasSize: size)

                        // Apply transform to context so all drawing (image + strokes) moves together
                        context.transform = transform

                        // Draw background image if present (now transformed with strokes)
                        if let bgImage = backgroundImage {
                            let uiImage = UIImage(cgImage: bgImage.cgImage!)
                            context.draw(
                                Image(uiImage: uiImage),
                                in: CGRect(x: 0, y: 0, width: worldSize.width, height: worldSize.height)
                            )
                        }

                        for stroke in viewModel.strokes {
                            renderStroke(stroke, in: &context)
                        }

                        if let current = currentStroke {
                            renderStroke(current, in: &context)
                        }
                    }
                    .coordinateSpace(.named("canvas"))
                    .onGeometryChange(for: CGSize.self, of: { $0.size }) { newSize in
                        canvasSize = newSize
                    }
                }

                StrokeCaptureView(
                    onPointsCapture: { points in
                        guard !points.isEmpty else { return }

                        if isPointerMode {
                            // In pointer mode, use drag to pan
                            guard let currentPoint = points.last else { return }

                            if lastPointerPosition != .zero {
                                let delta = CGPoint(
                                    x: currentPoint.x - lastPointerPosition.x,
                                    y: currentPoint.y - lastPointerPosition.y
                                )
                                let fitScale = viewModel.fitScale(canvasSize: canvasSize)
                                viewModel.pan(screenDelta: delta, fitScale: fitScale)
                            }
                            lastPointerPosition = currentPoint
                        } else {
                            // In pen mode, draw strokes
                            print("📍 Touch: \(points.count) points, isDrawing=\(isDrawing)")

                            // Convert screen coordinates to world coordinates
                            let adjustedPoints = points.map { screenToWorld($0) }

                            if !isDrawing {
                                print("🎨 Starting new stroke")
                                isDrawing = true
                                currentStroke = viewModel.startStroke(at: adjustedPoints.first ?? .zero)
                            }

                            if var stroke = currentStroke {
                                for point in adjustedPoints {
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
                        }
                    },
                    onStrokeEnded: {
                        if isPointerMode {
                            // Reset pointer tracking
                            lastPointerPosition = .zero
                        } else {
                            print("✋ Stroke ended, submitting \(currentStroke?.points.count ?? 0) points")
                            guard let stroke = currentStroke else { return }
                            guard stroke.points.count >= 2 else {
                                print("⚠️ Ignoring single-point stroke")
                                currentStroke = nil
                                isDrawing = false
                                return
                            }
                            let endedStroke = stroke
                            currentStroke = nil
                            isDrawing = false
                            Task {
                                await viewModel.submitStroke(endedStroke)
                                print("✅ Stroke submitted")
                            }
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
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .updating($gestureZoom) { value, state, _ in
                            state = isPointerMode ? value : 1.0
                        }
                        .onEnded { value in
                            if isPointerMode {
                                viewModel.zoom(by: value)
                            }
                        },
                    RotationGesture()
                        .updating($gestureRotation) { value, state, _ in
                            state = isPointerMode ? value.radians : 0.0
                        }
                        .onEnded { value in
                            if isPointerMode {
                                viewModel.rotate(by: value.radians)
                            }
                        }
                )
            )
        }
        .padding(.vertical, 48)
        .onChange(of: canvasId) { _, newCanvasId in
            guard !newCanvasId.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            currentStroke = nil
            isDrawing = false
            viewModel.switchToCanvas(newCanvasId)
        }
    }

    private func canvasTransform(worldSize: CGSize, fitScale: CGFloat, canvasSize: CGSize) -> CGAffineTransform {
        let screenCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let imageCenterOffset = CGPoint(x: -worldSize.width / 2, y: -worldSize.height / 2)
        let liveScale = viewModel.zoomScale * gestureZoom * fitScale
        let liveRotation = viewModel.rotationAngle + gestureRotation

        return CGAffineTransform.identity
            .translatedBy(x: screenCenter.x, y: screenCenter.y)
            .rotated(by: liveRotation)
            .scaledBy(x: liveScale, y: liveScale)
            .translatedBy(x: imageCenterOffset.x + viewModel.viewportOffset.x, y: imageCenterOffset.y + viewModel.viewportOffset.y)
    }

    private func screenToWorld(_ screenPoint: CGPoint) -> CGPoint {
        // Convert screen coordinate to world coordinate accounting for transform
        let worldSize = viewModel.worldSize(fallback: canvasSize)
        let fitScale = viewModel.fitScale(canvasSize: canvasSize)
        let screenCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let imageCenterOffset = CGPoint(x: -worldSize.width / 2, y: -worldSize.height / 2)
        let scale = viewModel.zoomScale * gestureZoom * fitScale
        let rotation = viewModel.rotationAngle + gestureRotation

        // Translate from screen center
        var point = CGPoint(x: screenPoint.x - screenCenter.x, y: screenPoint.y - screenCenter.y)

        // Inverse scale
        point.x /= scale
        point.y /= scale

        // Inverse rotation
        let cos = cos(-rotation)
        let sin = sin(-rotation)
        let rotatedX = point.x * cos - point.y * sin
        let rotatedY = point.x * sin + point.y * cos

        // Add back image center offset and viewport offset (inverse of transform)
        // The transform translates by (imageCenterOffset + viewportOffset), so we add those back
        return CGPoint(
            x: rotatedX - imageCenterOffset.x - viewModel.viewportOffset.x,
            y: rotatedY - imageCenterOffset.y - viewModel.viewportOffset.y
        )
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

            // Also clear background image
            do {
                try await repository.removeBackgroundImage(for: canvasId)
                viewModel.backgroundImageUrl = nil
                viewModel.imageSize = nil
                backgroundImage = nil
                print("✅ Canvas and background image cleared")
            } catch {
                print("❌ Error clearing background image: \(error)")
            }
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

        // context.transform is already applied, no need to transform path
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
