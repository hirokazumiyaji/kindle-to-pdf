# Kindle Page Capture PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS上のKindleアプリの表示ページを自動キャプチャし、途中停止・再開に対応した画像PDFを作成するCLIを実装する。

**Architecture:** Swift Package ManagerでCoreライブラリとCLI実行ターゲットを分離する。純粋なCLI解析、セッション管理、画像比較、PDF生成、ワークフローはテスト可能なCoreに置き、ウィンドウ列挙・ページ送り・ウィンドウキャプチャ・権限確認だけをmacOSアダプタに閉じ込める。

**Tech Stack:** Swift 5.9、macOS 13+、Swift Package Manager、CoreGraphics、ImageIO、PDFKit、CryptoKit、Accessibility API、XCTest。外部ライブラリは使用しない。

## Global Constraints

- Kindle内部ファイルの読み出し、DRM解除、暗号化データの復号は実装しない。
- macOS 13以上を対象にする。
- 初期版はCLIとして提供する。
- Kindleウィンドウは最小化せず、別デスクトップまたは別ディスプレイに配置する。
- 出力は画像PDFとし、OCR・テキスト検索可能化・自動トリミングは実装しない。
- すべての処理はローカルで完結し、ネットワーク通信を追加しない。
- 実装コードを書く前に、その動作を示す失敗テストを実行する。
- コメントは実装方法ではなく、仕様上の意図を残す場合だけ書く。

---

### Task 1: Swift PackageとCLI引数解析

**Files:**
- Create: `Package.swift`
- Create: `Sources/KindleToPDFCore/CLI/CLICommand.swift`
- Create: `Sources/KindleToPDFCore/CLI/CLIParser.swift`
- Create: `Sources/KindleToPDF/main.swift`
- Create: `Tests/KindleToPDFCoreTests/CLIParserTests.swift`

**Interfaces:**
- Produces `CaptureOptions`, `NextKey`, `CLICommand`, and `CLIParser.parse(_:)` for later tasks.

```swift
public enum NextKey: String, Equatable, Codable {
    case right
    case pagedown
}

public struct CaptureOptions: Equatable {
    public let outputURL: URL
    public let pageCount: Int
    public let windowTitle: String?
    public let nextKey: NextKey
    public let sessionURL: URL?
    public let resume: Bool
    public let overwrite: Bool
}

public enum CLICommand: Equatable {
    case capture(CaptureOptions)
    case help
}

public enum CLIParser {
    public static func parse(_ arguments: [String]) throws -> CLICommand
}
```

- [ ] **Step 1: Write the failing parser tests**

```swift
import XCTest
@testable import KindleToPDFCore

final class CLIParserTests: XCTestCase {
    func testParsesCaptureOptions() throws {
        let command = try CLIParser.parse([
            "capture", "--output", "book.pdf", "--pages", "3",
            "--window", "My book", "--next-key", "pagedown",
            "--session", "book-session", "--resume", "--overwrite"
        ])

        XCTAssertEqual(command, .capture(CaptureOptions(
            outputURL: URL(fileURLWithPath: "book.pdf"),
            pageCount: 3,
            windowTitle: "My book",
            nextKey: .pagedown,
            sessionURL: URL(fileURLWithPath: "book-session"),
            resume: true,
            overwrite: true
        )))
    }

    func testRejectsMissingPageCount() {
        XCTAssertThrowsError(try CLIParser.parse(["capture", "--output", "book.pdf"]))
    }

    func testUsesRightKeyAndNoOptionalFlagsByDefault() throws {
        let command = try CLIParser.parse([
            "capture", "--output", "book.pdf", "--pages", "1"
        ])

        XCTAssertEqual(command, .capture(CaptureOptions(
            outputURL: URL(fileURLWithPath: "book.pdf"),
            pageCount: 1,
            windowTitle: nil,
            nextKey: .right,
            sessionURL: nil,
            resume: false,
            overwrite: false
        )))
    }
}
```

- [ ] **Step 2: Run the parser tests and verify they fail because the parser types do not exist**

Run: `swift test --filter CLIParserTests`

Expected: FAIL during compilation with missing `CLIParser`, `CaptureOptions`, and `NextKey` symbols.

- [ ] **Step 3: Add the package manifest and minimal parser implementation**

`Package.swift` must declare a macOS 13 platform, a `KindleToPDFCore` library target, a `kindle-to-pdf` executable target depending on the library, and a test target depending on the library.

`CLIParser.parse(_:)` must accept `capture`, require `--output` and a positive `--pages` value, use `.right` when `--next-key` is absent, and reject unknown or incomplete options with a typed error.

- [ ] **Step 4: Run the parser tests and verify they pass**

Run: `swift test --filter CLIParserTests`

Expected: PASS with all parser tests green.

- [ ] **Step 5: Commit the CLI foundation**

```bash
git add Package.swift Sources Tests
git commit -m "feat: add Kindle capture CLI parser"
```

### Task 2: セッション状態とページファイル管理

**Files:**
- Create: `Sources/KindleToPDFCore/Session/SessionState.swift`
- Create: `Sources/KindleToPDFCore/Session/SessionStore.swift`
- Create: `Tests/KindleToPDFCoreTests/SessionStoreTests.swift`

**Interfaces:**
- Consumes `CaptureOptions` from Task 1.
- Produces `SessionState`, `SessionStatus`, and `SessionStore` for the capture coordinator and PDF writer.

```swift
public enum SessionStatus: String, Codable, Equatable {
    case capturing
    case completed
}

public struct SessionState: Codable, Equatable {
    public let schemaVersion: Int
    public let outputPath: String
    public let requestedPageCount: Int
    public var capturedPageCount: Int
    public let windowTitle: String?
    public let windowID: UInt32?
    public let processID: Int32?
    public var lastImageHash: String?
    public var status: SessionStatus
}

public struct SessionStore {
    public let rootURL: URL
    public init(rootURL: URL)
    public func createDirectories() throws
    public func save(_ state: SessionState) throws
    public func load() throws -> SessionState
    public func savePage(_ data: Data, index: Int) throws
    public func pageURL(index: Int) -> URL
    public func pageURLs(count: Int) -> [URL]
}
```

- [ ] **Step 1: Write failing tests for atomic state and ordered pages**

```swift
import XCTest
@testable import KindleToPDFCore

final class SessionStoreTests: XCTestCase {
    func testSavesAndLoadsStateAndPage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = SessionStore(rootURL: root)
        let state = SessionState(
            schemaVersion: 1,
            outputPath: "/tmp/book.pdf",
            requestedPageCount: 2,
            capturedPageCount: 1,
            windowTitle: "Kindle",
            windowID: 42,
            processID: 99,
            lastImageHash: "abc",
            status: .capturing
        )

        try store.save(state)
        try store.savePage(Data([1, 2, 3]), index: 1)

        XCTAssertEqual(try store.load(), state)
        XCTAssertEqual(try Data(contentsOf: store.pageURL(index: 1)), Data([1, 2, 3]))
    }

    func testReturnsNaturalPageOrder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = SessionStore(rootURL: root)

        XCTAssertEqual(
            store.pageURLs(count: 3).map(\.lastPathComponent),
            ["0001.png", "0002.png", "0003.png"]
        )
    }
}
```

- [ ] **Step 2: Run the session tests and verify they fail because the store does not exist**

Run: `swift test --filter SessionStoreTests`

Expected: FAIL during compilation with missing session types.

- [ ] **Step 3: Implement session serialization and page persistence**

Create the `pages` directory and write `state.json` using atomic replacement. Use four-digit page names beginning at `0001.png`. `savePage` must create the directory before writing and reject indices less than one. `load` must report a missing or invalid state file as a typed session error.

- [ ] **Step 4: Run the session tests and verify they pass**

Run: `swift test --filter SessionStoreTests`

Expected: PASS with state round-trip and page ordering green.

- [ ] **Step 5: Commit session persistence**

```bash
git add Sources/KindleToPDFCore/Session Tests/KindleToPDFCoreTests/SessionStoreTests.swift
git commit -m "feat: persist capture sessions"
```

### Task 3: 画像比較・PNG保存・画像PDF生成

**Files:**
- Create: `Sources/KindleToPDFCore/Media/PNGImageCodec.swift`
- Create: `Sources/KindleToPDFCore/Media/ImageChangeDetector.swift`
- Create: `Sources/KindleToPDFCore/Media/PDFWriter.swift`
- Create: `Tests/KindleToPDFCoreTests/ImageChangeDetectorTests.swift`
- Create: `Tests/KindleToPDFCoreTests/PDFWriterTests.swift`
- Create: `Tests/KindleToPDFCoreTests/TestImageFixtures.swift`

**Interfaces:**
- Produces `PNGImageCodec`, `ImageChangeDetector`, and `PDFWriter`.

```swift
public struct PNGImageCodec {
    public init()
    public func encode(_ image: CGImage) throws -> Data
    public func decode(_ data: Data) throws -> CGImage
}

public struct ImageChangeDetector {
    public let changedPixelRatio: Double
    public init(changedPixelRatio: Double = 0.01)
    public func hasChanged(_ before: CGImage, _ after: CGImage) throws -> Bool
    public func isStable(_ samples: [CGImage]) throws -> Bool
}

public protocol PDFWriting {
    func write(imageURLs: [URL], to outputURL: URL) throws
}

public struct PDFWriter: PDFWriting {
    public init()
    public func write(imageURLs: [URL], to outputURL: URL) throws
}
```

- [ ] **Step 1: Write failing image and PDF tests**

```swift
import XCTest
import CoreGraphics
import PDFKit
@testable import KindleToPDFCore

final class ImageChangeDetectorTests: XCTestCase {
    func testDetectsDifferentPixels() throws {
        let detector = ImageChangeDetector(changedPixelRatio: 0.01)
        let first = try makeImage(color: .black)
        let second = try makeImage(color: .white)

        XCTAssertTrue(try detector.hasChanged(first, second))
    }

    func testRequiresStableSamples() throws {
        let detector = ImageChangeDetector()
        let image = try makeImage(color: .black)

        XCTAssertTrue(try detector.isStable([image, image, image]))
    }
}

final class PDFWriterTests: XCTestCase {
    func testWritesOnePDFPagePerPNG() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let codec = PNGImageCodec()
        let firstURL = directory.appendingPathComponent("0001.png")
        let secondURL = directory.appendingPathComponent("0002.png")
        try codec.encode(try makeImage(color: .black)).write(to: firstURL)
        try codec.encode(try makeImage(color: .white)).write(to: secondURL)
        let output = directory.appendingPathComponent("book.pdf")

        try PDFWriter().write(imageURLs: [firstURL, secondURL], to: output)

        XCTAssertEqual(PDFDocument(url: output)?.pageCount, 2)
    }
}
```

The test target must provide this 2x2 `CGImage` fixture helper, which creates deterministic RGBA pixels without reading external files.

```swift
import Foundation
import CoreGraphics

enum FixtureColor: Equatable {
    case black
    case white
}

func makeImage(color: FixtureColor) throws -> CGImage {
    let value: UInt8 = color == .black ? 0 : 255
    let pixels = Array(repeating: value, count: 2 * 2 * 4)
    var data = pixels
    for index in stride(from: 3, to: data.count, by: 4) {
        data[index] = 255
    }
    let provider = CGDataProvider(data: Data(data) as CFData)!
    return CGImage(
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: 8,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}
```

- [ ] **Step 2: Run the media tests and verify they fail because media types do not exist**

Run: `swift test --filter ImageChangeDetectorTests` and `swift test --filter PDFWriterTests`

Expected: FAIL during compilation with missing media types.

- [ ] **Step 3: Implement ImageIO encoding, pixel comparison, and PDF creation**

Encode screenshots as PNG using ImageIO. Compare equal-sized images by normalized pixel difference and return true when the changed pixel ratio reaches the configured threshold. Treat a sample list as stable only when it contains at least two images and every adjacent pair is unchanged. Create one `PDFPage` per decoded PNG, preserve the image aspect ratio, reject empty input and invalid images, and write the PDF atomically.

- [ ] **Step 4: Run the media tests and verify they pass**

Run: `swift test --filter ImageChangeDetectorTests` and `swift test --filter PDFWriterTests`

Expected: PASS with changed-image detection, stable-sample detection, and two-page PDF creation green.

- [ ] **Step 5: Commit media handling**

```bash
git add Sources/KindleToPDFCore/Media Tests/KindleToPDFCoreTests
git commit -m "feat: create image PDFs from captured pages"
```

### Task 4: macOS権限・ウィンドウ・ページ送り・キャプチャアダプタ

**Files:**
- Create: `Sources/KindleToPDFCore/Platform/KindleWindow.swift`
- Create: `Sources/KindleToPDFCore/Platform/PlatformProtocols.swift`
- Create: `Sources/KindleToPDFCore/Platform/WindowSelector.swift`
- Create: `Sources/KindleToPDFCore/Platform/MacOSPermissionChecker.swift`
- Create: `Sources/KindleToPDFCore/Platform/MacOSWindowLocator.swift`
- Create: `Sources/KindleToPDFCore/Platform/MacOSPageTurner.swift`
- Create: `Sources/KindleToPDFCore/Platform/MacOSWindowCapture.swift`
- Create: `Tests/KindleToPDFCoreTests/WindowSelectorTests.swift`

**Interfaces:**
- Produces platform protocols for dependency injection and macOS implementations for the CLI.

```swift
public struct KindleWindow: Equatable {
    public let windowID: UInt32
    public let processID: Int32
    public let title: String
    public let bounds: CGRect
}

public protocol WindowLocating {
    func locate(title: String?) throws -> KindleWindow
}

public protocol PageTurning {
    func turn(window: KindleWindow, key: NextKey) throws
}

public protocol WindowCapturing {
    func capture(window: KindleWindow) throws -> CGImage
}

public protocol PermissionChecking {
    func check() throws
}

public enum WindowSelector {
    public static func select(
        from windows: [KindleWindow],
        title: String?
    ) throws -> KindleWindow
}
```

- [ ] **Step 1: Write failing selector tests**

```swift
import XCTest
@testable import KindleToPDFCore

final class WindowSelectorTests: XCTestCase {
    func testSelectsTheOnlyKindleWindow() throws {
        let windows = [KindleWindow(
            windowID: 1, processID: 2, title: "Kindle - Book", bounds: .zero
        )]

        XCTAssertEqual(try WindowSelector.select(from: windows, title: nil), windows[0])
    }

    func testRejectsAmbiguousWindowsWithoutTitle() {
        let windows = [
            KindleWindow(windowID: 1, processID: 2, title: "Book A", bounds: .zero),
            KindleWindow(windowID: 3, processID: 4, title: "Book B", bounds: .zero)
        ]

        XCTAssertThrowsError(try WindowSelector.select(from: windows, title: nil))
    }
}
```

- [ ] **Step 2: Run the selector tests and verify they fail because platform types do not exist**

Run: `swift test --filter WindowSelectorTests`

Expected: FAIL during compilation with missing window types and selector.

- [ ] **Step 3: Implement the selector and macOS adapters**

`WindowSelector` must select the only candidate, select an exact title match when supplied, and throw for zero or ambiguous matches. `MacOSWindowLocator` must enumerate WindowServer windows, filter to the Kindle application process and non-empty bounds, then delegate selection.

`MacOSPermissionChecker` must check Accessibility trust with `AXIsProcessTrustedWithOptions` and Screen Recording access with `CGPreflightScreenCaptureAccess`, then throw an error containing both the permission name and the System Settings location when either check fails.

`MacOSPageTurner` must create a keyboard event for `right` or `pagedown` using Carbon virtual-key constants and post the event to the target process. It must send key-down and key-up events without activating an unrelated application.

`MacOSWindowCapture` must use the WindowServer window ID to create a best-resolution image that ignores the window frame. It must throw when the system returns no image.

- [ ] **Step 4: Run unit tests and compile the macOS adapters**

Run: `swift test --filter WindowSelectorTests`

Expected: PASS with selector tests green and all macOS adapter sources compiling on macOS.

- [ ] **Step 5: Commit the platform adapters**

```bash
git add Sources/KindleToPDFCore/Platform Tests/KindleToPDFCoreTests/WindowSelectorTests.swift
git commit -m "feat: add macOS Kindle window adapters"
```

### Task 5: キャプチャワークフローと再開処理

**Files:**
- Create: `Sources/KindleToPDFCore/Capture/CaptureError.swift`
- Create: `Sources/KindleToPDFCore/Capture/CaptureCoordinator.swift`
- Create: `Sources/KindleToPDFCore/Capture/Sleeper.swift`
- Create: `Tests/KindleToPDFCoreTests/CaptureCoordinatorTests.swift`

**Interfaces:**
- Consumes `CaptureOptions`, `SessionStore`, media services, and platform protocols.
- Produces `CaptureCoordinator.run(options:stopRequested:)`.

```swift
public protocol Sleeper {
    func sleep(for duration: TimeInterval) throws
}

public final class CaptureCoordinator {
    public init(
        windowLocator: WindowLocating,
        permissionChecker: PermissionChecking,
        pageTurner: PageTurning,
        windowCapture: WindowCapturing,
        imageCodec: PNGImageCodec,
        imageChangeDetector: ImageChangeDetector,
        pdfWriter: PDFWriting,
        sleeper: Sleeper
    )

    public func run(
        options: CaptureOptions,
        stopRequested: @escaping () -> Bool
    ) throws
}
```

- [ ] **Step 1: Write failing workflow tests using fakes**

```swift
import XCTest
@testable import KindleToPDFCore

final class CaptureCoordinatorTests: XCTestCase {
    func testCapturesCurrentPageThenTurnsForRemainingPages() throws {
        let fixture = try CaptureFixture(images: [.black, .white, .white, .black, .black])
        let options = fixture.options(pageCount: 3)

        try fixture.coordinator.run(options: options, stopRequested: { false })

        XCTAssertEqual(fixture.pageTurner.turnCount, 2)
        XCTAssertEqual(fixture.savedPageCount, 3)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 3)
    }

    func testStopsWithoutSavingDuplicateWhenPageDoesNotChange() throws {
        let fixture = try CaptureFixture(images: [.black, .black])
        let options = fixture.options(pageCount: 2)

        XCTAssertThrowsError(try fixture.coordinator.run(
            options: options,
            stopRequested: { false }
        ))

        XCTAssertEqual(fixture.savedPageCount, 1)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 0)
    }

    func testResumeUsesTheNextPageAfterSavedPages() throws {
        let fixture = try CaptureFixture(images: [.white, .white])
        try fixture.seedSession(capturedPageCount: 1)

        try fixture.coordinator.run(
            options: fixture.options(pageCount: 2, resume: true),
            stopRequested: { false }
        )

        XCTAssertEqual(fixture.savedPageCount, 2)
        XCTAssertEqual(fixture.pageTurner.turnCount, 1)
    }
}
```

The test target must define fakes for `WindowLocating`, `PermissionChecking`, `PageTurning`, `WindowCapturing`, `Sleeper`, and `PDFWriting` behavior, plus a temporary `CaptureFixture`. The fakes must record calls and return a deterministic image sequence. The fixture has this shape:

```swift
import Foundation
import CoreGraphics

private final class RecordingPDFWriter: PDFWriting {
    private(set) var writtenImageCount = 0

    func write(imageURLs: [URL], to outputURL: URL) throws {
        writtenImageCount = imageURLs.count
    }
}

private final class RecordingPageTurner: PageTurning {
    private(set) var turnCount = 0

    func turn(window: KindleWindow, key: NextKey) throws {
        turnCount += 1
    }
}

private final class FixtureWindowCapture: WindowCapturing {
    private var images: [CGImage]
    private var index = 0

    init(images: [CGImage]) {
        self.images = images
    }

    func capture(window: KindleWindow) throws -> CGImage {
        let image = images[min(index, images.count - 1)]
        index += 1
        return image
    }
}

private struct AllowingPermissionChecker: PermissionChecking {
    func check() throws {}
}

private struct FixtureWindowLocator: WindowLocating {
    let window = KindleWindow(windowID: 1, processID: 2, title: "Kindle", bounds: .zero)

    func locate(title: String?) throws -> KindleWindow {
        window
    }
}

private struct NoOpSleeper: Sleeper {
    func sleep(for duration: TimeInterval) throws {}
}

private final class CaptureFixture {
    let rootURL: URL
    let store: SessionStore
    let pageTurner = RecordingPageTurner()
    let pdfWriter = RecordingPDFWriter()
    let coordinator: CaptureCoordinator

    init(images: [FixtureColor]) throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        store = SessionStore(rootURL: rootURL)
        let capturedImages = try images.map { try makeImage(color: $0) }
        coordinator = CaptureCoordinator(
            windowLocator: FixtureWindowLocator(),
            permissionChecker: AllowingPermissionChecker(),
            pageTurner: pageTurner,
            windowCapture: FixtureWindowCapture(images: capturedImages),
            imageCodec: PNGImageCodec(),
            imageChangeDetector: ImageChangeDetector(changedPixelRatio: 0.01),
            pdfWriter: pdfWriter,
            sleeper: NoOpSleeper()
        )
    }

    func options(pageCount: Int, resume: Bool = false) -> CaptureOptions {
        CaptureOptions(
            outputURL: rootURL.appendingPathComponent("book.pdf"),
            pageCount: pageCount,
            windowTitle: nil,
            nextKey: .right,
            sessionURL: rootURL.appendingPathComponent("book.kindle-session"),
            resume: resume,
            overwrite: false
        )
    }

    func seedSession(capturedPageCount: Int) throws {
        let session = SessionStore(rootURL: options(pageCount: 2).sessionURL!)
        let page = try PNGImageCodec().encode(try makeImage(color: .black))
        try session.savePage(page, index: 1)
        try session.save(SessionState(
            schemaVersion: 1,
            outputPath: options(pageCount: 2).outputURL.path,
            requestedPageCount: 2,
            capturedPageCount: capturedPageCount,
            windowTitle: "Kindle",
            windowID: 1,
            processID: 2,
            lastImageHash: nil,
            status: .capturing
        ))
    }

    var savedPageCount: Int {
        (try? SessionStore(rootURL: options(pageCount: 2).sessionURL!).load().capturedPageCount) ?? 0
    }
}
```

`CaptureFixture` must construct these fakes, a temporary `SessionStore`, a `CaptureCoordinator` using the fakes, and an `options(pageCount:resume:)` helper. Its `seedSession(capturedPageCount:)` helper must write page images and a capturing `SessionState` before the resume test. `savedPageCount` must read the session state's `capturedPageCount` after the run.

- [ ] **Step 2: Run the workflow tests and verify they fail because the coordinator does not exist**

Run: `swift test --filter CaptureCoordinatorTests`

Expected: FAIL during compilation with missing coordinator and fake dependency interfaces.

- [ ] **Step 3: Implement the red-green workflow**

Resolve the session directory from `--session` or the output filename. Reject an existing incomplete session unless `resume` is true, reject a completed output unless `overwrite` is true, and validate that a resumed session matches output path and requested page count.

For a new session, check permissions, locate the window, capture and save page 1, then save state. For every remaining page, check `stopRequested`, send the configured page-turn key, poll captures through `Sleeper`, require one changed sample followed by stable samples, save the next PNG, hash the saved data with SHA256, and update state. On a stability timeout, throw without saving the candidate image or writing the PDF. On normal completion, call `PDFWriting` with all stored page URLs and mark the state completed only after the writer succeeds.

- [ ] **Step 4: Run the workflow tests and verify they pass**

Run: `swift test --filter CaptureCoordinatorTests`

Expected: PASS with first-page capture, duplicate prevention, and resume behavior green.

- [ ] **Step 5: Commit the capture workflow**

```bash
git add Sources/KindleToPDFCore/Capture Tests/KindleToPDFCoreTests/CaptureCoordinatorTests.swift
git commit -m "feat: orchestrate Kindle page capture sessions"
```

### Task 6: CLI実行、SIGINT、ドキュメント、検証

**Files:**
- Modify: `Sources/KindleToPDF/main.swift`
- Create: `Sources/KindleToPDFCore/Process/SignalStopController.swift`
- Create: `README.md`
- Create: `Tests/KindleToPDFCoreTests/SignalStopControllerTests.swift`

**Interfaces:**
- Consumes `CLIParser`, `CaptureCoordinator`, and macOS adapters from Tasks 1, 4, and 5.
- Produces the user-facing `kindle-to-pdf capture` command and documented setup instructions.

- [ ] **Step 1: Write a failing stop-controller test**

```swift
import XCTest
@testable import KindleToPDFCore

final class SignalStopControllerTests: XCTestCase {
    func testStartsNotRequestedAndCanBeRequested() {
        let controller = SignalStopController()

        XCTAssertFalse(controller.isRequested)
        controller.requestStop()
        XCTAssertTrue(controller.isRequested)
    }
}
```

- [ ] **Step 2: Run the stop-controller test and verify it fails because the controller does not exist**

Run: `swift test --filter SignalStopControllerTests`

Expected: FAIL during compilation with missing `SignalStopController`.

- [ ] **Step 3: Implement command wiring and documentation**

Implement `SignalStopController` with a synchronized boolean and install a SIGINT handler in `main.swift`. The handler must request a stop; the coordinator must finish the current safe boundary and leave the session on disk.

`main.swift` must parse arguments, construct `MacOSPermissionChecker`, `MacOSWindowLocator`, `MacOSPageTurner`, `MacOSWindowCapture`, `PNGImageCodec`, `ImageChangeDetector`, `PDFWriter`, and a real `Sleeper`, then call `CaptureCoordinator.run`. It must print concise errors to stderr and return a non-zero exit status for invalid arguments, missing permissions, missing windows, failed captures, failed page changes, and invalid sessions.

`README.md` must document:

- macOS 13+ requirement
- Swift build and run commands
- Accessibility and Screen Recording permission setup
- opening the Kindle book and positioning the first page
- placing the Kindle window on another desktop or display without minimizing it
- the capture command and resume command
- the meaning of `--pages`, `--next-key`, `--resume`, and `--overwrite`
- the image-PDF limitation and the absence of DRM handling
- the fact that the same book and position must be restored before resuming

- [ ] **Step 4: Run the complete automated verification**

Run: `swift test`

Expected: exit code 0 with every XCTest passing.

Run: `swift build -c release`

Expected: exit code 0 and a release executable at `.build/release/kindle-to-pdf`.

Run: `git diff --check HEAD`

Expected: no whitespace errors.

- [ ] **Step 5: Perform the manual macOS integration checklist**

1. Run the CLI without Accessibility permission and verify it reports the permission and settings location without sending input.
2. Grant Accessibility and Screen Recording permission to the terminal application.
3. Open a user-provided or otherwise authorized book in Kindle and place the Kindle window on a second desktop or display without minimizing it.
4. Run `kindle-to-pdf capture --output /tmp/kindle-test.pdf --pages 3` and verify that the current page is page 1 and the PDF has three pages.
5. Stop a five-page capture with `Ctrl-C`, verify the session directory contains only complete page images, then run the same command with `--resume` and verify the remaining pages are added.
6. Cover the Kindle window or minimize it and verify the tool stops with a capture error rather than adding a duplicate or blank page.

- [ ] **Step 6: Commit the CLI and documentation**

```bash
git add Sources/KindleToPDF Sources/KindleToPDFCore/Process README.md Tests
git commit -m "feat: ship Kindle page capture CLI"
```

## Plan Self-Review

- The specification's CLI options map to `CaptureOptions` and Task 1 parser tests.
- Window detection, permission checks, page sending, and capture are isolated in Task 4 adapters.
- Session persistence, resume, and overwrite rules are covered by Tasks 2 and 5.
- Image stability and image-PDF output are covered by Task 3.
- SIGINT behavior, user setup, build verification, and manual parallel-work verification are covered by Task 6.
- No task depends on DRM access or network services.
- No placeholder steps, `TODO`, or undefined fallback behavior remain.
