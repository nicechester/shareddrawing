# SharedDrawing iOS Rewrite

## Overview

Complete rewrite of the shared drawing app using modern iOS tech stack (SwiftUI, Firebase SPM, async/await).

**Why rewrite?**
- Old architecture uses UIKit + Storyboards, CocoaPods (outdated dependency model)
- No real-time incremental sync (strokes only appear when finished)
- Bitmap caching + full-redraw on delete is inefficient at scale
- Open Firebase rules (`.read: true, .write: true`)
- Unused Core Data model, no persistent canvas history
- Manual canvas join UI (popover with bare text field)

**What stays?**
- Realtime Database as transport (cheap, ordered, low-latency)
- Point-buffer + Bézier smoothing concept from `MyView.swift`
- Coalesced touch capture from `StrokeGestureRecognizer.swift`
- Simple 5-color palette
- Local undo stack concept from `Stack.swift`

---

## Architecture

### Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| UI | SwiftUI (iOS 17+) | Modern default; `Canvas` is fast enough for MVP |
| Input | UIViewRepresentable + UIView | SwiftUI `DragGesture` lacks coalesced touches & pressure data |
| Firebase | SPM only (no CocoaPods) | Official SDK support; cleaner dependency model |
| Auth | Anonymous + optional Sign in with Apple | Frictionless + persistent across devices |
| Database | RTDB (strokes) + Firestore (metadata, Phase 2) | RTDB for firehose; Firestore for queries & offline cache |
| Concurrency | async/await + AsyncStream | Modern Swift, clean abstraction over Firebase listeners |
| Architecture | MVVM + Repository pattern | Testable; `FakeCanvasRepository` enables unit tests without network |

### Data Model

**Realtime Database** (`/v2/canvases/{canvasId}/`):
```
meta: { name, createdBy, createdAt, lastActivityAt }
strokes/{strokeId}: {
  userId: string,          // Firebase Auth uid
  color: string,           // hex, e.g. "#FF3B30"
  width: number,           // default ~2
  points: [{ x, y, t }],   // t = ms since stroke start
  isComplete: bool,        // false while drawing, true when finished
  createdAt: ServerValue.TIMESTAMP
}
```

**Security Rules** (RTDB):
```json
{
  "rules": {
    "v2": {
      "canvases": {
        "{canvasId}": {
          "meta": { ".read": true, ".write": "auth != null" },
          "strokes": {
            "{strokeId}": {
              ".read": true,
              ".write": "auth.uid === data.child('userId').val()"
            }
          }
        }
      }
    }
  }
}
```
- Require authentication for all writes
- Only allow users to write their own strokes
- Everyone can read strokes (async viewer mode is possible)

### Key Differences from Old Code

1. **Live incremental sync**: While drawing, stroke points are written every ~50ms with `isComplete=false`. On touch-up, one final write sets `isComplete=true`. Old code uploaded whole stroke once on touch-up.
2. **No full redraw on delete**: SwiftUI `Canvas` re-renders the remaining strokes array on `child_removed`. No bitmap cache rebuild needed.
3. **Undo stays local**: Per-user local stack; undo = pop + `removeValue()` on Firebase. All clients react uniformly.
4. **Typed models**: `Stroke`, `StrokePoint`, `CanvasMeta` replace free-text strings and the unused Core Data model.

---

## Project Structure

```
SharedDrawing/
  SharedDrawingApp.swift              // @main, FirebaseApp.configure()
  Core/
    Models/
      Stroke.swift
      StrokePoint.swift
      CanvasMeta.swift
    Networking/
      CanvasRepository.swift          // protocol
      FirebaseCanvasRepository.swift   // impl
      FakeCanvasRepository.swift       // test doubles
    Auth/
      AuthService.swift
  Features/
    Canvas/
      CanvasView.swift                // main drawing UI
      CanvasViewModel.swift           // @Observable, state
      StrokeCaptureView.swift         // UIViewRepresentable, touch input
      ColorPalettePicker.swift
    CanvasList/
      CanvasListView.swift
      CanvasListViewModel.swift
      JoinCanvasSheet.swift           // replaces old popover
  Shared/
    Stack.swift                       // genericized undo stack
    Extensions/
    DesignSystem/
  Resources/
    Assets.xcassets
SharedDrawingTests/
  CanvasViewModelTests.swift
  StrokeSmoothingTests.swift
SharedDrawingUITests/

.gitignore:
  GoogleService-Info.plist            # NOT committed; injected via CI
  *.xcworkspace/
  Pods/
  Build/
```

---

## Implementation Phases

### Phase 1: Core MVP (~10 steps)
**Goal**: Functional shared canvas with real-time sync.

**Issues**: [#49](https://github.com/nicechester/shareddrawing/issues/49) (epic)
- [#50](https://github.com/nicechester/shareddrawing/issues/50): New Xcode project (SwiftUI)
- [#51](https://github.com/nicechester/shareddrawing/issues/51): Firebase SDK via SPM
- [#52](https://github.com/nicechester/shareddrawing/issues/52): Anonymous Auth + RTDB rules
- [#53](https://github.com/nicechester/shareddrawing/issues/53): Stroke models + CanvasRepository
- [#54](https://github.com/nicechester/shareddrawing/issues/54): StrokeCaptureView (touch input)
- [#55](https://github.com/nicechester/shareddrawing/issues/55): CanvasView + CanvasViewModel
- [#56](https://github.com/nicechester/shareddrawing/issues/56): Color palette (5 fixed colors)
- [#57](https://github.com/nicechester/shareddrawing/issues/57): Canvas join/create (short random ID)
- [#58](https://github.com/nicechester/shareddrawing/issues/58): Local undo stack
- [#59](https://github.com/nicechester/shareddrawing/issues/59): End-to-end sync test (two simulators)

**Entry point**: #50 (new project)

### Phase 2: Feature Expansion
**Issues**: [#60](https://github.com/nicechester/shareddrawing/issues/60) (epic)
- Firestore-backed "my canvases" list (cross-device sync)
- URL-based canvas sharing (e.g., `shareddrawing.app/abc12`) with web redirect (Universal Links for mobile)
- Background image import
- Drawing export to image/PDF
- Pannable/zoomable canvas
- Presence indicators (show active users drawing)
- Redo stack, pressure-sensitive width, custom color picker

**Blocked by**: Phase 1 MVP working end-to-end

### Phase 3: Polish & Production
**Issues**: [#61](https://github.com/nicechester/shareddrawing/issues/61) (epic)
- Performance (profiling, culling, bitmap cache if needed)
- Accessibility (VoiceOver, Dynamic Type, colorblind palette)
- Animations & haptics
- App Check (App Attest)
- iPad support (Pencil hover, Stage Manager)
- TestFlight + App Store submission

**Blocked by**: Phase 2 features stable

---

## Development Guidelines

### Testing
- **Unit tests**: `CanvasViewModel` + `FakeCanvasRepository` (network-free)
- **Integration tests**: Firebase Emulator Suite (`firebase emulators:start`) for real RTDB behavior
- **Manual**: Two simulators (or iPhone + simulator) drawing on the same canvas

### Firebase Setup
1. Use an existing Firebase project or create a new one
2. Enable Anonymous Auth (Firebase Console → Auth → Anonymous)
3. Deploy RTDB rules under `/v2/...` (see above)
4. Download `GoogleService-Info.plist` — **DO NOT COMMIT**
5. CI/CD injects it at build time (GitHub Actions secret decoded to base64)

### Code Style
- SwiftUI-first; minimal UIKit (only `StrokeCaptureView`)
- Async/await for all async operations (no completion handlers)
- `@Observable` for ViewModels (Swift 5.9+)
- No premature abstractions; 3 similar lines is fine

### Git Workflow
- Branch per phase or issue (e.g., `phase-1/core-mvp`, `phase-1/canvas-view`)
- Atomic commits grouped by logical change, not by file
- PR description references the GitHub issue number

### GitHub Access
**CRITICAL**: Use GitHub MCP tools exclusively, never use `gh` CLI.
- For creating/updating PRs, use `mcp__github__create_pull_request` / `mcp__github__update_pull_request`
- For file operations, use `mcp__github__create_or_update_file` / `mcp__github__get_file_contents`
- For issues, use `mcp__github__issue_read` / `mcp__github__issue_write`
- For code search, use `mcp__github__search_code` / `mcp__github__search_issues`
- Reason: The `gh` CLI is authenticated to a work account; personal account is via MCP tokens only

---

## Edge Cases to Watch

1. **Throttling live-stroke writes**: Too aggressive → jank on remote viewer; too loose → RTDB write spam. Start at ~50ms per update.
2. **In-progress strokes on removal**: A stroke marked `isComplete=false` arrives on a `child_removed` listener (user undid mid-draw). ViewModel must handle gracefully.
3. **Anonymous auth on reinstall**: User loses canvas history unless upgraded to Sign in with Apple. UX should set expectations.
4. **Namespace `/v2`**: New code coexists with old `/paths` data in the same Firebase project. Don't overwrite old data; don't migrate it unless Phase 2 explicitly does.

---

## Resources

- [Firebase iOS SDK (SPM)](https://github.com/firebase/firebase-ios-sdk)
- [SwiftUI Canvas docs](https://developer.apple.com/documentation/swiftui/canvas)
- [UIViewRepresentable pattern](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)
- [Firebase Realtime Database security rules](https://firebase.google.com/docs/database/security)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)

---

## Next Steps

1. Implement Phase 1.1 ([#50](https://github.com/nicechester/shareddrawing/issues/50)): Create new Xcode project
2. Get Firebase project ID and `GoogleService-Info.plist`
3. Follow Phase 1 issues in order (#51 → #59)
4. Manual end-to-end test on two simulators (#59)
5. Cut Phase 1 branch, open PR for review
6. Plan Phase 2 after Phase 1 merge
