import SwiftUI
import os.log

private let logger = Logger(subsystem: "io.github.nicechester.shareddrawing", category: "CanvasView")
import Observation

struct CanvasView: View {
    @State private var viewModel: CanvasViewModel
    @State private var currentStroke: Stroke?
    @State private var isDrawing = false
    @State private var lastUpdateTime: Date?
    @State private var showCanvasIDSheet = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var backgroundImage: UIImage?
    @State private var isPointerMode = false  // false=pen, true=pointer/pan
    @State private var lastPointerPosition: CGPoint = .zero
    @GestureState private var gestureZoom: CGFloat = 1.0
    @GestureState private var gestureRotation: Double = 0.0
    @State private var canvasSize: CGSize = .zero
    @State private var showSignInPrompt = false
    @State private var signInErrorMessage: String? = nil
    @State private var showSignInError = false
    @State private var isAMode = false
    @State private var aModeStrokes: [Stroke] = []
    @State private var pointerTouchStartPoint: CGPoint?
    @State private var pointerTouchStartTime: Date?
    private let recognizer = HandwritingRecognizer()

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
                if isAMode {
                    Button(action: {
                        Task {
                            do {
                                let text = try await recognizer.recognizeText(from: aModeStrokes)
                                if let recognizedText = text, !recognizedText.isEmpty {
                                    // Calculate bounding box of strokes
                                    var minX = Double.infinity, maxX = -Double.infinity
                                    var minY = Double.infinity, maxY = -Double.infinity
                                    for stroke in aModeStrokes {
                                        for point in stroke.points {
                                            minX = min(minX, point.x)
                                            maxX = max(maxX, point.x)
                                            minY = min(minY, point.y)
                                            maxY = max(maxY, point.y)
                                        }
                                    }

                                    let textObject = TextObject(
                                        id: UUID().uuidString,
                                        userId: authService.currentUserID ?? "anonymous",
                                        text: recognizedText,
                                        x: (minX + maxX) / 2,
                                        y: (minY + maxY) / 2,
                                        color: viewModel.currentColor,
                                        fontSize: 24,
                                        isComplete: true,
                                        createdAt: Date().timeIntervalSince1970
                                    )
                                    await viewModel.submitTextObject(textObject)
                                    logger.info("Recognized text: \(recognizedText)")
                                } else {
                                    // Fall back to strokes if no recognition
                                    for stroke in aModeStrokes {
                                        await viewModel.submitStroke(stroke)
                                    }
                                    logger.info("No text recognized, submitted as \(aModeStrokes.count) strokes")
                                }
                                aModeStrokes = []
                                isAMode = false
                            } catch {
                                logger.error("Handwriting recognition error: \(error)")
                                aModeStrokes = []
                                isAMode = false
                            }
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14))
                    }

                    Button(action: {
                        aModeStrokes = []
                        isAMode = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                    }
                } else {
                    Button(action: {
                        Task { await viewModel.undo() }
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14))
                    }
                    .disabled(!viewModel.canUndo)
                }

                if viewModel.zoomScale != 1.0 || viewModel.rotationAngle != 0.0 {
                    Button(action: {
                        viewModel.resetTransform()
                    }) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: 14))
                    }
                }

                if !viewModel.isAnonymous {
                    Button(action: { Task { try? await authService.signOut() } }) {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .font(.system(size: 14))
                    }
                    .accessibilityLabel("Sign out")
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
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(isPresented: $showImagePicker, selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                guard let newImage = newImage else { return }
                self.backgroundImage = newImage
                Task {
                    do {
                        guard let jpegData = newImage.jpegData(compressionQuality: 0.8) else {
                            logger.error("Failed to compress image")
                            return
                        }

                        // Upload to GCS and get signed URL
                        guard let serviceAccount = ServiceAccountLoader.loadKey() else {
                            logger.error("Service account key not found")
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
                        logger.info("Background image uploaded and stored: \(signedURL)")
                    } catch {
                        logger.error("Error uploading image: \(error)")
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
                                    logger.info("Background image loaded from URL")
                                }
                                // Backfill dimensions if not already set
                                let width = Double(uiImage.size.width)
                                let height = Double(uiImage.size.height)
                                await viewModel.backfillImageDimensionsIfNeeded(width: width, height: height)
                            }
                        } catch {
                            logger.error("Failed to load background image from URL: \(error)")
                        }
                    }
                } else {
                    // URL was cleared, remove background image
                    backgroundImage = nil
                    logger.info("Background image cleared")
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

                        for stroke in aModeStrokes {
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
                            // In pointer mode, use drag to pan or tap to edit text
                            guard let currentPoint = points.last else { return }

                            if pointerTouchStartPoint == nil {
                                pointerTouchStartPoint = currentPoint
                                pointerTouchStartTime = Date()
                            }

                            if lastPointerPosition != .zero {
                                let delta = CGPoint(
                                    x: currentPoint.x - lastPointerPosition.x,
                                    y: currentPoint.y - lastPointerPosition.y
                                )
                                let fitScale = viewModel.fitScale(canvasSize: canvasSize)
                                viewModel.pan(screenDelta: delta, fitScale: fitScale)
                            }
                            lastPointerPosition = currentPoint
                        } else if isAMode {
                            // In A mode, collect strokes for handwriting recognition
                            let adjustedPoints = points.map { screenToWorld($0) }

                            if !isDrawing {
                                logger.debug("Starting new A mode stroke")
                                isDrawing = true
                                currentStroke = viewModel.startStroke(at: adjustedPoints.first ?? .zero)
                            }

                            if var stroke = currentStroke {
                                for point in adjustedPoints {
                                    viewModel.addStrokePoint(point, to: &stroke)
                                }
                                currentStroke = stroke
                            }
                        } else {
                            // In pen mode, draw strokes normally
                            logger.debug("Touch: \(points.count) points, isDrawing=\(isDrawing)")

                            // Convert screen coordinates to world coordinates
                            let adjustedPoints = points.map { screenToWorld($0) }

                            if !isDrawing {
                                logger.debug("Starting new stroke")
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
                                            logger.error("Error updating stroke: \(error)")
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
                            pointerTouchStartPoint = nil
                            pointerTouchStartTime = nil
                        } else if isAMode {
                            logger.debug("A mode stroke ended, collecting \(currentStroke?.points.count ?? 0) points")
                            guard let stroke = currentStroke else { return }
                            guard stroke.points.count >= 2 else {
                                logger.warning("Ignoring single-point A mode stroke")
                                currentStroke = nil
                                isDrawing = false
                                return
                            }
                            aModeStrokes.append(stroke)
                            currentStroke = nil
                            isDrawing = false
                        } else {
                            logger.debug("Stroke ended, submitting \(currentStroke?.points.count ?? 0) points")
                            guard let stroke = currentStroke else { return }
                            guard stroke.points.count >= 2 else {
                                logger.warning("Ignoring single-point stroke")
                                currentStroke = nil
                                isDrawing = false
                                return
                            }
                            let endedStroke = stroke
                            currentStroke = nil
                            isDrawing = false
                            Task {
                                await viewModel.submitStroke(endedStroke)
                                logger.info("Stroke submitted")
                            }
                        }
                    }
                    )

                // Text objects overlay
                ForEach(viewModel.textObjects) { textObject in
                    let worldPosition = CGPoint(x: textObject.x, y: textObject.y)
                    let screenPosition = worldToScreen(worldPosition)

                    Text(textObject.text)
                        .font(.system(size: textObject.fontSize))
                        .foregroundColor(Color(hex: textObject.color))
                        .position(screenPosition)
                }

                ColorPalettePicker(
                    selectedColor: $viewModel.currentColor,
                    selectedPenStyle: $viewModel.selectedPenStyle,
                    isPointerMode: $isPointerMode,
                    isAMode: $isAMode,
                    onImagePickerTapped: { handleAddImageTapped() },
                    onClearTapped: { clearAllStrokes() }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
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
        .alert("Sign in required", isPresented: $showSignInPrompt) {
            Button("Sign in with Google") { Task { await performGoogleSignIn() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Sign in with Google to add a background image.")
        }
        .alert("Sign-In Failed", isPresented: $showSignInError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(signInErrorMessage ?? "Something went wrong.")
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

    private func worldToScreen(_ worldPoint: CGPoint) -> CGPoint {
        // Convert world coordinate to screen coordinate accounting for transform
        let worldSize = viewModel.worldSize(fallback: canvasSize)
        let fitScale = viewModel.fitScale(canvasSize: canvasSize)
        let screenCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let imageCenterOffset = CGPoint(x: -worldSize.width / 2, y: -worldSize.height / 2)
        let scale = viewModel.zoomScale * gestureZoom * fitScale
        let rotation = viewModel.rotationAngle + gestureRotation

        // Apply viewport offset and image center offset
        let point = CGPoint(
            x: worldPoint.x + imageCenterOffset.x + viewModel.viewportOffset.x,
            y: worldPoint.y + imageCenterOffset.y + viewModel.viewportOffset.y
        )

        // Apply rotation
        let cos = cos(rotation)
        let sin = sin(rotation)
        let rotatedX = point.x * cos - point.y * sin
        let rotatedY = point.x * sin + point.y * cos

        // Apply scale
        let scaledX = rotatedX * scale
        let scaledY = rotatedY * scale

        // Translate to screen center
        return CGPoint(
            x: scaledX + screenCenter.x,
            y: scaledY + screenCenter.y
        )
    }

    private func clearAllStrokes() {
        Task {
            viewModel.recordClear(viewModel.strokes)

            // Clear all strokes
            for stroke in viewModel.strokes {
                do {
                    try await repository.removeStroke(id: stroke.id, from: canvasId)
                } catch {
                    logger.error("Error clearing stroke: \(error)")
                }
            }
            viewModel.strokes = []

            // Clear all text objects
            for textObject in viewModel.textObjects {
                do {
                    try await repository.removeTextObject(id: textObject.id, from: canvasId)
                } catch {
                    logger.error("Error clearing text object: \(error)")
                }
            }
            viewModel.textObjects = []

            // Also clear background image
            do {
                try await repository.removeBackgroundImage(for: canvasId)
                viewModel.backgroundImageUrl = nil
                viewModel.imageSize = nil
                backgroundImage = nil
                logger.info("Canvas, text objects, and background image cleared")
            } catch {
                logger.error("Error clearing background image: \(error)")
            }
        }
    }

    private func renderStroke(_ stroke: Stroke, in context: inout GraphicsContext) {
        guard stroke.points.count > 1 else { return }
        let style = PenStyle(rawValue: stroke.style) ?? .default
        let color = Color(hex: stroke.color)
        context.applyPenStyle(style)

        if style == .calligraphy {
            renderCalligraphyStroke(stroke, style: style, color: color, in: &context)
            return
        }

        var path = Path()
        path.move(to: CGPoint(x: stroke.points[0].x, y: stroke.points[0].y))
        for point in stroke.points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: point.y))
        }
        context.stroke(path, with: .color(color), lineWidth: style.baseWidth)
    }

    private func renderCalligraphyStroke(_ stroke: Stroke, style: PenStyle, color: Color, in context: inout GraphicsContext) {
        let nibAngle = Double.pi / 4
        let points = stroke.points
        for i in 0..<(points.count - 1) {
            let p0 = CGPoint(x: points[i].x, y: points[i].y)
            let p1 = CGPoint(x: points[i + 1].x, y: points[i + 1].y)
            let segmentAngle = atan2(p1.y - p0.y, p1.x - p0.x)
            let widthFactor = abs(cos(segmentAngle - nibAngle))
            let width = style.minWidth + (style.maxWidth - style.minWidth) * widthFactor
            var segmentPath = Path()
            segmentPath.move(to: p0)
            segmentPath.addLine(to: p1)
            context.stroke(segmentPath, with: .color(color), lineWidth: width)
        }
    }

    private func handleAddImageTapped() {
        if viewModel.isAnonymous && authService.currentUserEmail == nil {
            showSignInPrompt = true
        } else {
            showImagePicker = true
        }
    }

    private func performGoogleSignIn() async {
        do {
            try await authService.signInWithGoogle()
            showImagePicker = true
        } catch AuthError.cancelled {
            // Silent — user backed out of Google sheet
        } catch {
            signInErrorMessage = error.localizedDescription
            showSignInError = true
        }
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

extension GraphicsContext {
    mutating func applyPenStyle(_ style: PenStyle) {
        opacity = style.opacity
        blendMode = style.usesScreenBlend ? .screen : .normal
    }
}
