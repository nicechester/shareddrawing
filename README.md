# SharedDrawing

A real-time collaborative drawing canvas for iOS, built with SwiftUI and Firebase Realtime Database.

## Features

- **Real-time sync**: Draw strokes that appear on other users' devices in real-time
- **Shared canvas**: Create a canvas and share the ID with others to draw together
- **Undo**: Undo your own strokes (stays local to your device)
- **Multiple colors**: 5 color palette for drawing

## Architecture

- **iOS 17+** with SwiftUI
- **Firebase Realtime Database** for real-time stroke sync
- **Swift Package Manager** for dependencies (no CocoaPods)
- **MVVM + Repository pattern** for clean architecture

## Getting Started

1. Clone the repo
2. Open `SharedDrawing.xcodeproj` in Xcode
3. Set your bundle ID and development team in Signing & Capabilities
4. Configure Firebase (see CLAUDE.md for setup)
5. Build and run on iOS 17+ device/simulator

## Documentation

See [CLAUDE.md](./CLAUDE.md) for detailed architecture, implementation phases, and development guidelines.

## License

TBD
