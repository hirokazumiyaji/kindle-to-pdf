# KindleToPDF GUI App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a FolioBinder-style SwiftUI macOS app that shares `KindleToPDFCore` for scan → crop → PDF, while keeping the existing CLI.

**Architecture:** Extend Core with progress callbacks, library/settings stores, and manual crop insets. Add a SwiftUI executable target packaged as `KindleToPDF.app`. Capture runs off the main actor via `Task`; UI observes progress through callbacks.

**Tech Stack:** Swift 5.9, macOS 13+, SwiftUI, AppKit (activation/permissions), CoreGraphics, PDFKit, XCTest, Swift Package Manager.

**Spec:** `docs/superpowers/specs/2026-08-31-kindle-gui-app-design.md`

## Global Constraints

- macOS 13+ / Swift 5.9+; no external dependencies.
- CLI `kindle-to-pdf` behavior and flags must remain backward compatible.
- DRM bypass and Kindle internal file access are forbidden; screen capture only.
- Library manages GUI-created books only; no CLI import in v1.
- OCR title/author detection is out of scope for v1.
- Page turns still activate Kindle (existing Core behavior).
- Comments only when documenting non-obvious intent; no explanatory narration.

## File Structure

```text
Sources/KindleToPDFCore/
  Library/
    BookEntry.swift              # Codable book metadata + status
    LibraryPaths.swift           # Root layout helpers
    LibraryStore.swift           # CRUD for Library/*.json + delete session/PDF
  Settings/
    AppSettings.swift            # Codable app defaults
    AppSettingsStore.swift       # settings.json + crop-defaults.json
    CropInsets.swift             # Manual inset model
  Media/
    ManualInsetCropper.swift     # Apply CropInsets after edge crop
  Capture/
    CaptureCoordinator.swift     # + onProgress callback
  Platform/
    MacOSWindowCapture.swift     # Optional ManualInsetCropper chain
    MacOSWindowLocator.swift     # + listWindows()
    WindowListing.swift          # Protocol for listing Kindle windows

Sources/KindleToPDFApp/
  KindleToPDFApp.swift           # @main SwiftUI App
  AppModel.swift                 # Shared stores + navigation selection
  Views/
    RootView.swift               # NavigationSplitView
    ScanView.swift
    LibraryView.swift
    SetupView.swift
    SettingsView.swift
    PermissionSetupSheet.swift
    PDFPreviewView.swift
  ViewModels/
    ScanViewModel.swift
    LibraryViewModel.swift
    SetupViewModel.swift
    SettingsViewModel.swift

Resources/
  Info.plist                     # CLI bundle (existing)
  AppInfo.plist                  # GUI bundle

Tests/KindleToPDFCoreTests/
  ManualInsetCropperTests.swift
  LibraryStoreTests.swift
  AppSettingsStoreTests.swift
  CaptureCoordinatorProgressTests.swift  # or extend CaptureCoordinatorTests
  MacOSWindowLocatorTests.swift          # listWindows coverage

scripts/package-app.sh           # Support CLI and GUI packaging
```

---

### Task 1: Manual crop insets in Core

**Files:**
- Create: `Sources/KindleToPDFCore/Settings/CropInsets.swift`
- Create: `Sources/KindleToPDFCore/Media/ManualInsetCropper.swift`
- Create: `Tests/KindleToPDFCoreTests/ManualInsetCropperTests.swift`
- Modify: `Sources/KindleToPDFCore/Platform/MacOSWindowCapture.swift`

**Interfaces:**
- Consumes: `CGImage`, existing `EdgeBackgroundCropper`
- Produces:
  - `public struct CropInsets: Codable, Equatable` with `top`, `bottom`, `left`, `right` as `Int`
  - `public struct ManualInsetCropper` with `public init()` and `public func crop(_ image: CGImage, insets: CropInsets) -> CGImage`
  - `MacOSWindowCapture` internal init gains `manualCropper: ManualInsetCropper = .init()` and `insets: CropInsets? = nil`; when insets are non-nil and non-zero, apply after edge crop

- [ ] **Step 1: Write failing ManualInsetCropper tests**

```swift
func testAppliesInsetsFromAllSides() {
    let image = makeImage(width: 10, height: 10, fill: .white, rectangles: [
        (CGRect(x: 0, y: 0, width: 10, height: 10), .darkGray),
        (CGRect(x: 2, y: 2, width: 6, height: 6), .black)
    ])
    let cropped = ManualInsetCropper().crop(
        image,
        insets: CropInsets(top: 2, bottom: 2, left: 2, right: 2)
    )
    XCTAssertEqual(cropped.width, 6)
    XCTAssertEqual(cropped.height, 6)
}

func testReturnsOriginalWhenInsetsAreZero() {
    let image = makeImage(width: 8, height: 8, fill: .white, rectangles: [])
    let cropped = ManualInsetCropper().crop(image, insets: .zero)
    XCTAssertEqual(cropped.width, 8)
    XCTAssertEqual(cropped.height, 8)
}

func testClampsInsetsThatWouldEmptyTheImage() {
    let image = makeImage(width: 4, height: 4, fill: .white, rectangles: [])
    let cropped = ManualInsetCropper().crop(
        image,
        insets: CropInsets(top: 3, bottom: 3, left: 3, right: 3)
    )
    XCTAssertGreaterThanOrEqual(cropped.width, 1)
    XCTAssertGreaterThanOrEqual(cropped.height, 1)
}
```

Add `CropInsets.zero` as a static constant of all zeros.

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ManualInsetCropperTests`

Expected: FAIL — `CropInsets` / `ManualInsetCropper` missing.

- [ ] **Step 3: Implement CropInsets and ManualInsetCropper**

```swift
public struct CropInsets: Codable, Equatable {
    public var top: Int
    public var bottom: Int
    public var left: Int
    public var right: Int

    public static let zero = CropInsets(top: 0, bottom: 0, left: 0, right: 0)

    public init(top: Int, bottom: Int, left: Int, right: Int) {
        self.top = max(0, top)
        self.bottom = max(0, bottom)
        self.left = max(0, left)
        self.right = max(0, right)
    }

    public var isZero: Bool { self == .zero }
}

public struct ManualInsetCropper {
    public init() {}

    public func crop(_ image: CGImage, insets: CropInsets) -> CGImage {
        guard !insets.isZero else { return image }
        let maxLeftRight = max(0, image.width - 1)
        let maxTopBottom = max(0, image.height - 1)
        let left = min(insets.left, maxLeftRight)
        let right = min(insets.right, maxLeftRight - left)
        let top = min(insets.top, maxTopBottom)
        let bottom = min(insets.bottom, maxTopBottom - top)
        let rect = CGRect(
            x: left,
            y: top,
            width: image.width - left - right,
            height: image.height - top - bottom
        )
        return image.cropping(to: rect) ?? image
    }
}
```

- [ ] **Step 4: Wire insets into MacOSWindowCapture**

Extend the internal initializer:

```swift
init(
    imageProvider: @escaping (CGWindowID) -> CGImage?,
    cropper: EdgeBackgroundCropper = EdgeBackgroundCropper(),
    manualCropper: ManualInsetCropper = ManualInsetCropper(),
    insets: CropInsets? = nil
)
```

After `cropper.crop(image)`, if `let insets`, `!insets.isZero`, return `manualCropper.crop(cropped, insets: insets)`. Keep `public init()` unchanged (no insets) so CLI behavior is identical.

Add a test in `MacOSWindowCaptureTests` that supplies insets and asserts the final size shrinks further than edge crop alone.

- [ ] **Step 5: Run tests and commit**

Run: `swift test --filter ManualInsetCropperTests` and `swift test --filter MacOSWindowCaptureTests`

Expected: PASS

```bash
git add Sources/KindleToPDFCore/Settings/CropInsets.swift \
  Sources/KindleToPDFCore/Media/ManualInsetCropper.swift \
  Sources/KindleToPDFCore/Platform/MacOSWindowCapture.swift \
  Tests/KindleToPDFCoreTests/ManualInsetCropperTests.swift \
  Tests/KindleToPDFCoreTests/MacOSWindowCaptureTests.swift
git commit -m "feat: add manual crop insets after edge background crop"
```

---

### Task 2: Capture progress callback

**Files:**
- Modify: `Sources/KindleToPDFCore/Capture/CaptureCoordinator.swift`
- Modify: `Tests/KindleToPDFCoreTests/CaptureCoordinatorTests.swift`

**Interfaces:**
- Consumes: existing `CaptureCoordinator.run`
- Produces: `run(options:stopRequested:onProgress:)` where `onProgress: ((Int) -> Void)? = nil` is invoked with `capturedPageCount` after each successful page save (including page 1)

- [ ] **Step 1: Write failing progress test**

```swift
func testReportsProgressAfterEachSavedPage() throws {
    let fixture = try CaptureFixture(images: [.black, .white, .white, .black, .black])
    var progress: [Int] = []

    try fixture.coordinator.run(
        options: fixture.options(pageCount: 3),
        stopRequested: { false },
        onProgress: { progress.append($0) }
    )

    XCTAssertEqual(progress, [1, 2, 3])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter testReportsProgressAfterEachSavedPage`

Expected: FAIL — extra argument / missing parameter.

- [ ] **Step 3: Add onProgress to CaptureCoordinator**

Change signature to:

```swift
public func run(
    options: CaptureOptions,
    stopRequested: @escaping () -> Bool,
    onProgress: ((Int) -> Void)? = nil
) throws
```

Call `onProgress?(state.capturedPageCount)` after saving page 1 and after each subsequent page save. Do not call it when stopping early without a new page. Keep CLI call sites compiling via the default `nil`.

- [ ] **Step 4: Run CaptureCoordinatorTests and commit**

Run: `swift test --filter CaptureCoordinatorTests`

Expected: PASS

```bash
git add Sources/KindleToPDFCore/Capture/CaptureCoordinator.swift \
  Tests/KindleToPDFCoreTests/CaptureCoordinatorTests.swift
git commit -m "feat: report capture progress after each saved page"
```

---

### Task 3: Library models and store

**Files:**
- Create: `Sources/KindleToPDFCore/Library/BookEntry.swift`
- Create: `Sources/KindleToPDFCore/Library/LibraryPaths.swift`
- Create: `Sources/KindleToPDFCore/Library/LibraryStore.swift`
- Create: `Tests/KindleToPDFCoreTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: Foundation `FileManager`, `Codable`
- Produces:
  - `public enum BookStatus: String, Codable` — `scanning`, `ready`, `completed`
  - `public struct BookEntry: Codable, Equatable, Identifiable` with fields from the spec (`id: UUID`, `displayName`, dates, `status`, relative `sessionPath`/`pdfPath`, counts, optional `cropOverride: CropInsets?`)
  - `public struct LibraryPaths` with `rootURL`, `libraryURL`, `sessionsURL`, `pdfsURL`, `settingsURL`, helpers `sessionURL(for:)`, `pdfURL(for:)`, `entryURL(for:)`
  - `public final class LibraryStore` with:
    - `init(rootURL: URL, fileManager: FileManager = .default)`
    - `func ensureLayout() throws`
    - `func list() throws -> [BookEntry]` (sorted by `updatedAt` descending)
    - `func save(_ entry: BookEntry) throws`
    - `func load(id: UUID) throws -> BookEntry`
    - `func delete(id: UUID) throws` (removes entry JSON, session dir, PDF if present)
    - `func makeNewEntry(displayName: String, requestedPageCount: Int?) -> BookEntry`

- [ ] **Step 1: Write failing LibraryStore tests**

```swift
func testCreatesLayoutAndSavesEntry() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = LibraryStore(rootURL: root)
    try store.ensureLayout()
    var entry = store.makeNewEntry(displayName: "Sample", requestedPageCount: 10)
    entry.status = .scanning
    try store.save(entry)

    let loaded = try store.load(id: entry.id)
    XCTAssertEqual(loaded.displayName, "Sample")
    XCTAssertTrue(FileManager.default.fileExists(atPath: store.paths.entryURL(for: entry.id).path))
}

func testListsNewestFirstAndDeletesArtifacts() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = LibraryStore(rootURL: root)
    try store.ensureLayout()
    let first = store.makeNewEntry(displayName: "A", requestedPageCount: nil)
    try store.save(first)
    Thread.sleep(forTimeInterval: 0.01)
    var second = store.makeNewEntry(displayName: "B", requestedPageCount: nil)
    second.status = .completed
    try store.save(second)
    // create dummy session + pdf files
    try Data().write(to: store.paths.sessionURL(for: second.id).appendingPathComponent("state.json"))
    try Data().write(to: store.paths.pdfURL(for: second.id))

    XCTAssertEqual(try store.list().map(\.displayName), ["B", "A"])
    try store.delete(id: second.id)
    XCTAssertEqual(try store.list().map(\.displayName), ["A"])
    XCTAssertFalse(FileManager.default.fileExists(atPath: store.paths.pdfURL(for: second.id).path))
}
```

Use ISO8601 dates via `Codable` with a shared encoder/decoder strategy on the store.

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LibraryStoreTests`

Expected: FAIL — missing types.

- [ ] **Step 3: Implement BookEntry, LibraryPaths, LibraryStore**

Default root helper:

```swift
public static var defaultRootURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/KindleToPDF", isDirectory: true)
}
```

`makeNewEntry` sets `id = UUID()`, `createdAt`/`updatedAt = Date()`, `status = .scanning`, `sessionPath = "Sessions/<id>"`, `pdfPath = nil`, `capturedPageCount = 0`, `cropOverride = nil`.

`save` updates `updatedAt` to `Date()` before writing JSON.

`delete` removes `Library/<id>.json`, the session directory, and `PDFs/<id>.pdf` if they exist; ignore missing files.

- [ ] **Step 4: Run tests and commit**

Run: `swift test --filter LibraryStoreTests`

Expected: PASS

```bash
git add Sources/KindleToPDFCore/Library Tests/KindleToPDFCoreTests/LibraryStoreTests.swift
git commit -m "feat: add library store for GUI-managed books"
```

---

### Task 4: App settings store

**Files:**
- Create: `Sources/KindleToPDFCore/Settings/AppSettings.swift`
- Create: `Sources/KindleToPDFCore/Settings/AppSettingsStore.swift`
- Create: `Tests/KindleToPDFCoreTests/AppSettingsStoreTests.swift`

**Interfaces:**
- Consumes: `LibraryPaths`, `CropInsets`, `NextKey`
- Produces:
  - `public struct AppSettings: Codable, Equatable` with `libraryRootPath: String`, `defaultNextKey: NextKey`, `defaultPageCount: Int?`, `autoCropEnabled: Bool`, `globalCropInsets: CropInsets`
  - `public static let `default`` using `LibraryPaths.defaultRootURL.path`, `.right`, `nil`, `true`, `.zero`
  - `public final class AppSettingsStore` with `init(paths: LibraryPaths)`, `func load() throws -> AppSettings`, `func save(_ settings: AppSettings) throws`, reading/writing `Settings/settings.json` (include `globalCropInsets` in the same file; do not require a separate `crop-defaults.json` unless already created — prefer single file for YAGNI; if both paths exist in the spec layout, write `crop-defaults.json` only as a mirror of `globalCropInsets` OR store insets only in `settings.json` and document the simplification in the commit message)

Prefer **single `settings.json`** containing `globalCropInsets` to avoid dual-source drift. Spec layout's `crop-defaults.json` becomes unused; note this in README later.

- [ ] **Step 1: Write failing settings tests**

```swift
func testLoadsDefaultsWhenMissing() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let paths = LibraryPaths(rootURL: root)
    try FileManager.default.createDirectory(at: paths.settingsURL, withIntermediateDirectories: true)
    let store = AppSettingsStore(paths: paths)
    let settings = try store.load()
    XCTAssertEqual(settings.defaultNextKey, .right)
    XCTAssertTrue(settings.autoCropEnabled)
}

func testRoundTripsSettings() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let paths = LibraryPaths(rootURL: root)
    try LibraryStore(rootURL: root).ensureLayout()
    let store = AppSettingsStore(paths: paths)
    var settings = AppSettings.default
    settings.defaultNextKey = .left
    settings.defaultPageCount = 50
    settings.globalCropInsets = CropInsets(top: 1, bottom: 2, left: 3, right: 4)
    try store.save(settings)
    XCTAssertEqual(try store.load(), settings)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AppSettingsStoreTests`

Expected: FAIL — missing types.

- [ ] **Step 3: Implement AppSettings and AppSettingsStore**

`load()` returns `.default` (with `libraryRootPath` set to `paths.rootURL.path`) when the file is missing. `save` creates `Settings/` if needed and writes pretty-printed JSON.

- [ ] **Step 4: Run tests and commit**

Run: `swift test --filter AppSettingsStoreTests`

Expected: PASS

```bash
git add Sources/KindleToPDFCore/Settings/AppSettings.swift \
  Sources/KindleToPDFCore/Settings/AppSettingsStore.swift \
  Tests/KindleToPDFCoreTests/AppSettingsStoreTests.swift
git commit -m "feat: persist GUI app settings including crop insets"
```

---

### Task 5: List Kindle windows for GUI picker

**Files:**
- Modify: `Sources/KindleToPDFCore/Platform/PlatformProtocols.swift`
- Modify: `Sources/KindleToPDFCore/Platform/MacOSWindowLocator.swift`
- Modify: `Tests/KindleToPDFCoreTests/MacOSWindowLocatorTests.swift`
- Modify: `Tests/KindleToPDFCoreTests/WindowSelectorTests.swift` if needed

**Interfaces:**
- Consumes: existing window enumeration in `MacOSWindowLocator`
- Produces: `public protocol WindowListing { func listWindows() throws -> [KindleWindow] }` implemented by `MacOSWindowLocator`; filters to Kindle process windows with non-empty titles OR the largest on-screen-looking content window. Prefer returning all Kindle-owned windows with `bounds.height >= 200` so chrome-only strips are dropped, then let `WindowSelector` / GUI pick by title.

- [ ] **Step 1: Write failing unit test for size filtering helper**

Extract a pure function used by the locator:

```swift
enum KindleWindowFilter {
    static func contentWindows(from windows: [KindleWindow], minimumHeight: CGFloat = 200) -> [KindleWindow]
}
```

Test that a 33pt title-bar strip is dropped and a 1084pt main window remains.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KindleWindowFilter`

Expected: FAIL — missing type.

- [ ] **Step 3: Implement filter and `listWindows()`**

`locate(title:)` should use `listWindows()` then `WindowSelector.select`. Keep existing error cases.

- [ ] **Step 4: Run related tests and commit**

Run: `swift test --filter MacOSWindowLocatorTests` and `swift test --filter WindowSelectorTests`

Expected: PASS

```bash
git add Sources/KindleToPDFCore/Platform \
  Tests/KindleToPDFCoreTests/MacOSWindowLocatorTests.swift
git commit -m "feat: list Kindle content windows for GUI selection"
```

---

### Task 6: SwiftUI app shell and packaging target

**Files:**
- Modify: `Package.swift`
- Create: `Sources/KindleToPDFApp/KindleToPDFApp.swift`
- Create: `Sources/KindleToPDFApp/AppModel.swift`
- Create: `Sources/KindleToPDFApp/Views/RootView.swift`
- Create: `Resources/AppInfo.plist`

**Interfaces:**
- Consumes: SwiftUI, `KindleToPDFCore`
- Produces: executable product `KindleToPDFApp`; `@main struct KindleToPDFApp: App`; `AppModel: ObservableObject` holding `libraryStore`, `settingsStore`, `selectedSection`

- [ ] **Step 1: Add executable target to Package.swift**

```swift
products: [
    .library(name: "KindleToPDFCore", targets: ["KindleToPDFCore"]),
    .executable(name: "kindle-to-pdf", targets: ["KindleToPDF"]),
    .executable(name: "KindleToPDFApp", targets: ["KindleToPDFApp"])
],
targets: [
    .target(name: "KindleToPDFCore"),
    .executableTarget(name: "KindleToPDF", dependencies: ["KindleToPDFCore"]),
    .executableTarget(name: "KindleToPDFApp", dependencies: ["KindleToPDFCore"]),
    .testTarget(name: "KindleToPDFCoreTests", dependencies: ["KindleToPDFCore"])
]
```

- [ ] **Step 2: Create minimal SwiftUI shell**

```swift
@main
struct KindleToPDFApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case scan, library, setup, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .scan: return "スキャン"
        case .library: return "ライブラリ"
        case .setup: return "セットアップ"
        case .settings: return "設定"
        }
    }
}
```

`RootView` uses `NavigationSplitView` with a sidebar listing `AppSection.allCases` and detail placeholders (`Text(section.title)`).

`AppModel.init` creates `LibraryPaths` from settings (or default), calls `ensureLayout()`, loads `AppSettings`.

- [ ] **Step 3: Add AppInfo.plist**

Copy CLI plist; set:

- `CFBundleExecutable` = `KindleToPDFApp`
- `CFBundleIdentifier` = `com.hirokazumiyaji.kindle-to-pdf-app`
- `CFBundleDisplayName` = `Kindle to PDF`
- `NSHighResolutionCapable` = true
- `NSAppleEventsUsageDescription` = Japanese string explaining Kindle activation for page turns

- [ ] **Step 4: Verify build**

Run: `swift build --product KindleToPDFApp`

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/KindleToPDFApp Resources/AppInfo.plist
git commit -m "feat: add SwiftUI app shell target"
```

---

### Task 7: Permissions sheet and settings view

**Files:**
- Create: `Sources/KindleToPDFApp/Views/PermissionSetupSheet.swift`
- Create: `Sources/KindleToPDFApp/Views/SettingsView.swift`
- Create: `Sources/KindleToPDFApp/ViewModels/SettingsViewModel.swift`
- Modify: `Sources/KindleToPDFApp/Views/RootView.swift`
- Modify: `Sources/KindleToPDFCore/Platform/MacOSPermissionChecker.swift` (add non-throwing status API)

**Interfaces:**
- Consumes: `MacOSPermissionChecker`, `AppSettingsStore`
- Produces:
  - `public struct PermissionStatus: Equatable { var accessibility: Bool; var screenRecording: Bool }`
  - `MacOSPermissionChecker.status() -> PermissionStatus` (no prompt) and keep `check()` for capture start
  - Settings UI bound to `AppSettings` with save button
  - Sheet shown when `!status.accessibility || !status.screenRecording` on launch or before scan

- [ ] **Step 1: Add failing Core test for status()**

```swift
func testReportsPermissionStatusWithoutThrowing() {
    let checker = MacOSPermissionChecker(
        executablePath: "/tmp/x",
        accessibilityTrusted: { false },
        screenCaptureAuthorized: { true },
        requestScreenCapture: { true }
    )
    let status = checker.status()
    XCTAssertFalse(status.accessibility)
    XCTAssertTrue(status.screenRecording)
}
```

Extend the existing injectable initializer if needed. Automation (AppleScript) cannot be preflighted reliably; document it in the sheet as “初回のページ送り時に許可ダイアログが出ることがあります”.

- [ ] **Step 2: Implement status() and Settings/Permission UI**

Settings fields: library root path (read-only text + “Finderで開く”), default next key picker (`right`/`left`/`pagedown`), optional page count, auto-crop toggle, global inset steppers, “権限を再確認”, note about adhoc resigning.

Permission sheet: checklist rows, button to open System Settings (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` and ScreenCapture URL), refresh button.

- [ ] **Step 3: Build app target and run Core permission tests**

Run: `swift test --filter MacOSPermissionCheckerTests` and `swift build --product KindleToPDFApp`

Expected: PASS / build OK

- [ ] **Step 4: Commit**

```bash
git add Sources/KindleToPDFCore/Platform/MacOSPermissionChecker.swift \
  Tests/KindleToPDFCoreTests/MacOSPermissionCheckerTests.swift \
  Sources/KindleToPDFApp
git commit -m "feat: add permission setup sheet and settings view"
```

---

### Task 8: Scan view model and scan screen

**Files:**
- Create: `Sources/KindleToPDFApp/ViewModels/ScanViewModel.swift`
- Create: `Sources/KindleToPDFApp/Views/ScanView.swift`
- Modify: `Sources/KindleToPDFApp/Views/RootView.swift`

**Interfaces:**
- Consumes: `CaptureCoordinator`, `LibraryStore`, `AppSettings`, `SignalStopController`, `WindowListing`
- Produces: `@MainActor final class ScanViewModel: ObservableObject` with:
  - Inputs: `displayName`, `pageCountText`, `windowTitle`, `nextKey`, `isRunning`, `capturedPageCount`, `statusMessage`, `errorMessage`
  - Actions: `refreshWindows()`, `start()`, `stop()`
  - On start: validate permissions → create/update `BookEntry` → build `CaptureOptions` pointing PDF to `paths.pdfURL(for:)` and session to `paths.sessionURL(for:)` → `overwrite: true` for GUI-managed path → run coordinator on `Task.detached` / background queue → hop to MainActor for progress
  - On `CaptureError.stopRequested`: set entry status `.scanning`, clear running flag, no error alert
  - On success: status `.completed`, `pdfPath` set, `capturedPageCount` updated
  - On other errors: keep session, set `errorMessage`

Wire `MacOSWindowCapture` with `insets` from `entry.cropOverride ?? settings.globalCropInsets` when auto-crop is enabled; if `autoCropEnabled == false`, still capture but pass a capture wrapper that skips edge crop — simplest approach: pass `EdgeBackgroundCropper` always (existing), and only skip **manual** insets when disabled is false… Spec says “自動クロップのオンオフ”. When off, use an image provider path that returns the raw image without `EdgeBackgroundCropper`. Add `MacOSWindowCapture` option `edgeCropEnabled: Bool = true` for this.

- [ ] **Step 1: Add edgeCropEnabled to MacOSWindowCapture (with test)**

When `edgeCropEnabled` is false, return provider image (still apply manual insets if present).

- [ ] **Step 2: Implement ScanViewModel.start/stop**

Factory for coordinator:

```swift
func makeCoordinator(insets: CropInsets?, edgeCropEnabled: Bool) -> CaptureCoordinator {
    CaptureCoordinator(
        windowLocator: MacOSWindowLocator(),
        permissionChecker: MacOSPermissionChecker(),
        pageTurner: MacOSPageTurner(),
        applicationActivator: MacOSApplicationActivator(),
        windowCapture: MacOSWindowCapture(edgeCropEnabled: edgeCropEnabled, insets: insets),
        imageCodec: PNGImageCodec(),
        imageChangeDetector: ImageChangeDetector(),
        pdfWriter: PDFWriter(),
        sleeper: ThreadSleeper()
    )
}
```

Expose a public/internal `MacOSWindowCapture` initializer used by the app (same module visibility via `public init(edgeCropEnabled:insets:)`).

Scan UI: form fields, Start/Stop buttons, progress (`"\(capturedPageCount) ページ"`), warning text that Kindle will be brought forward, window picker `Picker` from `listWindows()` titles plus optional manual text field.

- [ ] **Step 3: Build app and run Core tests**

Run: `swift test` and `swift build --product KindleToPDFApp`

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/KindleToPDFCore/Platform/MacOSWindowCapture.swift \
  Tests/KindleToPDFCoreTests/MacOSWindowCaptureTests.swift \
  Sources/KindleToPDFApp
git commit -m "feat: connect scan UI to capture coordinator"
```

---

### Task 9: Library view (list, preview, resume, delete)

**Files:**
- Create: `Sources/KindleToPDFApp/ViewModels/LibraryViewModel.swift`
- Create: `Sources/KindleToPDFApp/Views/LibraryView.swift`
- Create: `Sources/KindleToPDFApp/Views/PDFPreviewView.swift`

**Interfaces:**
- Consumes: `LibraryStore`, `PDFKit`
- Produces: list UI; actions `reload()`, `delete(id:)`, `revealInFinder(id:)`, `regeneratePDF(id:)` (rebuild from session pages via `PDFWriter`), `resume(id:)` (switch to Scan tab and prefill resume options)

- [ ] **Step 1: Implement LibraryViewModel with regeneratePDF**

```swift
func regeneratePDF(id: UUID) throws {
    let entry = try store.load(id: id)
    let session = SessionStore(rootURL: paths.sessionURL(for: id))
    let state = try session.load()
    let urls = session.pageURLs(count: state.capturedPageCount)
    let pdfURL = paths.pdfURL(for: id)
    try PDFWriter().write(imageURLs: urls, to: pdfURL)
    var updated = entry
    updated.pdfPath = "PDFs/\(id.uuidString).pdf"
    updated.status = .completed
    updated.capturedPageCount = state.capturedPageCount
    try store.save(updated)
}
```

- [ ] **Step 2: Build LibraryView**

`List` of books showing displayName, status badge, page count, updatedAt. Context menu: 再開, PDFを再生成, Finderに表示, 削除. Double-click / button opens `PDFPreviewView` using `PDFKit.PDFView` wrapped in `NSViewRepresentable` when `pdfPath` exists.

Resume posts a message to `AppModel` (`pendingResume: BookEntry?`) that `ScanViewModel` observes to set `resume = true`, matching page count, and display name.

- [ ] **Step 3: Build and commit**

Run: `swift build --product KindleToPDFApp`

```bash
git add Sources/KindleToPDFApp
git commit -m "feat: add library list, PDF preview, resume and delete"
```

---

### Task 10: Setup view (test scan + inset preview)

**Files:**
- Create: `Sources/KindleToPDFApp/ViewModels/SetupViewModel.swift`
- Create: `Sources/KindleToPDFApp/Views/SetupView.swift`

**Interfaces:**
- Consumes: `CaptureCoordinator` with `pageCount: 3`, `ManualInsetCropper`, `AppSettingsStore`
- Produces: test scan into a temporary session under `Sessions/.setup-test/` (or a fixed UUID `00000000-0000-0000-0000-000000000001` marked non-library); load first page PNG; show `NSImage` preview; sliders for top/bottom/left/right; live preview via `ManualInsetCropper` on the decoded `CGImage`; Save writes `settings.globalCropInsets`

- [ ] **Step 1: Implement SetupViewModel**

```swift
@MainActor
final class SetupViewModel: ObservableObject {
    @Published var insets: CropInsets
    @Published var previewImage: NSImage?
    @Published var isRunning = false
    @Published var message: String?

    func runTestScan() async { /* pageCount 3, then load page 1 into preview */ }
    func refreshPreview() { /* decode base image, apply ManualInsetCropper, assign NSImage */ }
    func saveAsDefaults() throws { /* settings.globalCropInsets = insets; store.save */ }
}
```

Keep the uncropped-after-edge-crop image as `baseImage: CGImage?` from the test session’s first page (already edge-cropped by capture). Manual sliders adjust further.

- [ ] **Step 2: Build SetupView UI**

Buttons: テストスキャン (3ページ), 保存. Four sliders 0…100. Image view. Short help text.

- [ ] **Step 3: Build and commit**

Run: `swift build --product KindleToPDFApp`

```bash
git add Sources/KindleToPDFApp
git commit -m "feat: add crop setup view with test scan preview"
```

---

### Task 11: Package script and README

**Files:**
- Modify: `scripts/package-app.sh`
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-08-31-kindle-gui-app-design.md` (note single settings.json if changed)

**Interfaces:**
- Consumes: release binaries `kindle-to-pdf` and `KindleToPDFApp`
- Produces: GUI app at default `$HOME/Documents/KindleToPDF.app` (or `dist/KindleToPDF.app`) containing `KindleToPDFApp` executable; optional CLI packaging mode

- [ ] **Step 1: Extend package-app.sh**

```zsh
#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
mode="${1:-gui}"          # gui | cli
destination="${2:-$HOME/Documents/KindleToPDF.app}"

swift build -c release
mkdir -p "$destination/Contents/MacOS"

if [[ "$mode" == "cli" ]]; then
  cp "$project_root/.build/release/kindle-to-pdf" "$destination/Contents/MacOS/kindle-to-pdf"
  cp "$project_root/Resources/Info.plist" "$destination/Contents/Info.plist"
  codesign --force --sign - "$destination/Contents/MacOS/kindle-to-pdf"
else
  cp "$project_root/.build/release/KindleToPDFApp" "$destination/Contents/MacOS/KindleToPDFApp"
  cp "$project_root/Resources/AppInfo.plist" "$destination/Contents/Info.plist"
  codesign --force --sign - "$destination/Contents/MacOS/KindleToPDFApp"
fi
codesign --force --sign - "$destination"
print "$destination"
```

- [ ] **Step 2: Update README**

Document:

1. GUI install via `zsh scripts/package-app.sh gui`
2. Permissions: Accessibility, Screen Recording, Automation
3. Library location `~/Documents/KindleToPDF/`
4. CLI still available via `zsh scripts/package-app.sh cli "$HOME/Documents/KindleToPDFCLI.app"`
5. Scan / Library / Setup / Settings overview

- [ ] **Step 3: Package and smoke-launch**

Run:

```bash
zsh scripts/package-app.sh gui "$HOME/Documents/KindleToPDF.app"
open "$HOME/Documents/KindleToPDF.app"
swift test
swift build -c release
```

Expected: app launches to sidebar shell; all tests pass; CLI binary still builds.

- [ ] **Step 4: Commit**

```bash
git add scripts/package-app.sh README.md docs/superpowers/specs/2026-08-31-kindle-gui-app-design.md
git commit -m "docs: package GUI app and document install flow"
```

---

### Task 12: End-to-end verification checklist

**Files:** none (manual + automated verification)

- [ ] **Step 1: Automated suite**

Run: `swift test && swift build -c release`

Expected: 0 failures; both products link.

- [ ] **Step 2: Manual GUI checklist**

1. Fresh app → permission sheet appears if needed → grant → refresh becomes green.
2. Setup → test scan 3 pages → adjust insets → save.
3. Scan → name “Smoke” → start → pages increment → stop → library shows `scanning`.
4. Resume from library → completes → PDF preview opens.
5. Delete book → files removed under `~/Documents/KindleToPDF`.
6. CLI still captures with `--output` / `--pages` as before.

- [ ] **Step 3: Commit any fixes discovered; do not commit without tests for Core regressions**

---

## Spec coverage self-review

| Spec requirement | Task |
|---|---|
| SwiftUI app with Scan/Library/Setup/Settings | 6, 7, 8, 9, 10 |
| One-button scan to PDF | 8 |
| Direction auto-switch / end detection (existing Core) | reused by 8 |
| Library list / preview / resume / delete | 9 |
| Test scan + crop adjustment UI | 1, 10 |
| Settings persistence | 4, 7 |
| Progress callback | 2 |
| Manual insets after edge crop | 1, 8 |
| Permissions sheet | 7 |
| package-app + README | 11 |
| CLI unchanged | 1/2/8 keep defaults; 11 cli mode |
| No OCR / no CLI import | omitted intentionally |

## Placeholder / consistency notes

- Settings use a **single `settings.json`** (insets included). Spec’s `crop-defaults.json` is not implemented separately — document in README Task 11.
- `MacOSWindowCapture` public API gains `edgeCropEnabled` and `insets` for GUI; CLI `init()` stays edge-crop only.
- Automation permission is explained in UI; not part of `PermissionStatus` preflight.
