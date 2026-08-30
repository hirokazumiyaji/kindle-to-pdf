# Kindle Edge Background Crop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Remove uniform outer Kindle-window background margins while preserving whitespace inside the page content.

**Architecture:** Add a focused `EdgeBackgroundCropper` that normalizes a captured `CGImage` to RGBA, detects the non-background bounds by scanning inward from the four edges, and crops the original image. `MacOSWindowCapture` applies the cropper after WindowServer capture, keeping the existing `WindowCapturing` interface and CLI unchanged.

**Tech Stack:** Swift 5.9, macOS 13+, CoreGraphics, XCTest, Swift Package Manager.

## Global Constraints

- Crop only outer background strips; preserve page-internal white margins.
- Return the original image when corner colors do not provide a reliable background or no content bounds are found.
- Apply cropping before page-change detection so comparison and saved images use the same range.
- Do not add CLI options or external dependencies.
- Do not add explanatory comments; comments may document intent only.

---

### Task 1: Add failing cropper tests

**Files:**
- Create: `Tests/KindleToPDFCoreTests/EdgeBackgroundCropperTests.swift`
- Modify: `Tests/KindleToPDFCoreTests/TestImageFixtures.swift`

**Interfaces:**
- Consumes: `CGImage` fixtures from the existing test target.
- Produces: Tests defining `EdgeBackgroundCropper.crop(_:) -> CGImage` behavior.

- [x] **Step 1: Add an RGBA fixture builder**

Add a test-only helper with this signature:

```swift
func makeImage(
    width: Int,
    height: Int,
    fill: FixtureRGB,
    rectangles: [(CGRect, FixtureRGB)]
) -> CGImage
```

`FixtureRGB` stores three `UInt8` channels. The helper fills an opaque RGBA pixel buffer and applies each rectangle before constructing a `CGImage` with device RGB and `CGImageAlphaInfo.last`.

- [x] **Step 2: Write the failing cropper tests**

Create tests with these exact cases:

```swift
func testRemovesOuterBackgroundAndPreservesPageMargin() throws {
    let image = makeImage(
        width: 10,
        height: 10,
        fill: .darkGray,
        rectangles: [
            (CGRect(x: 2, y: 2, width: 6, height: 6), .white),
            (CGRect(x: 4, y: 4, width: 2, height: 2), .black)
        ]
    )

    let cropped = EdgeBackgroundCropper().crop(image)

    XCTAssertEqual(cropped.width, 6)
    XCTAssertEqual(cropped.height, 6)
}

func testReturnsOriginalWhenCornerBackgroundIsInconsistent() throws {
    let image = makeImage(
        width: 8,
        height: 8,
        fill: .darkGray,
        rectangles: [(CGRect(x: 0, y: 0, width: 1, height: 1), .white)]
    )

    let cropped = EdgeBackgroundCropper().crop(image)

    XCTAssertEqual(cropped.width, image.width)
    XCTAssertEqual(cropped.height, image.height)
}

func testReturnsOriginalWhenImageContainsOnlyBackground() throws {
    let image = makeImage(width: 8, height: 8, fill: .darkGray, rectangles: [])

    let cropped = EdgeBackgroundCropper().crop(image)

    XCTAssertEqual(cropped.width, image.width)
    XCTAssertEqual(cropped.height, image.height)
}
```

Define `.darkGray`, `.white`, and `.black` as test fixture colors.

- [x] **Step 3: Run the cropper tests and verify they fail for the missing implementation**

Run:

```bash
swift test --filter EdgeBackgroundCropperTests
```

Expected: compilation fails because `EdgeBackgroundCropper` does not exist.

### Task 2: Implement edge-background cropping

**Files:**
- Create: `Sources/KindleToPDFCore/Media/EdgeBackgroundCropper.swift`

**Interfaces:**
- Consumes: Any `CGImage`.
- Produces: `public struct EdgeBackgroundCropper` with `public init()` and `public func crop(_ image: CGImage) -> CGImage`.

- [x] **Step 1: Add the minimal cropper implementation**

Implement `EdgeBackgroundCropper` with these fixed rules:

Expose this public API:

```swift
public struct EdgeBackgroundCropper {
    public init()
    public func crop(_ image: CGImage) -> CGImage
}
```

Normalize the input into an 8-bit RGBA pixel buffer using a `CGContext`. Use the four corner pixels as background samples. If any pair of corner samples differs by more than 16 in any RGB channel, return the original image.

Use the average of the four corner samples as the reference color. Treat a pixel as background when each RGB channel is within 16 of that reference. For each edge, find the first row or column whose background-pixel ratio is below `0.995`. If any edge has no content boundary, return the original image. Build the rectangle between those four boundaries and return `image.cropping(to:)`, falling back to the original image if CoreGraphics returns `nil`.

Keep at least one pixel on every side while finding boundaries. If the computed rectangle equals the original bounds, return the original image.

- [x] **Step 2: Run the cropper tests and verify they pass**

Run:

```bash
swift test --filter EdgeBackgroundCropperTests
```

Expected: all three cropper tests pass.

### Task 3: Integrate cropping into WindowServer capture

**Files:**
- Modify: `Sources/KindleToPDFCore/Platform/MacOSWindowCapture.swift`
- Create: `Tests/KindleToPDFCoreTests/MacOSWindowCaptureTests.swift`

**Interfaces:**
- Consumes: `EdgeBackgroundCropper` from Task 2 and the existing WindowServer image provider.
- Produces: `MacOSWindowCapture.capture(window:)` returns the cropped image while retaining the existing `WindowCapturing` protocol.

- [x] **Step 1: Add an injectable image provider and failing integration test**

Keep `public init()` as the production initializer and add an internal initializer used by tests:

```swift
init(
    imageProvider: @escaping (CGWindowID) -> CGImage?,
    cropper: EdgeBackgroundCropper = EdgeBackgroundCropper()
)
```

Add a test that supplies the same 10x10 fixture from Task 1, captures a `KindleWindow` with window ID `42`, and asserts that the returned image is 6x6. Before changing production code, run:

```bash
swift test --filter MacOSWindowCaptureTests
```

Expected: compilation fails because the injectable initializer and cropper integration do not exist.

- [x] **Step 2: Apply the cropper after WindowServer capture**

Make the public initializer delegate to the injected provider whose body calls `CGWindowListCreateImage` with the existing options. After the existing nil guard, return `cropper.crop(image)`.

- [x] **Step 3: Run the integration test**

Run:

```bash
swift test --filter MacOSWindowCaptureTests
```

Expected: the test passes and the capture still throws `PlatformError.unableToCaptureWindow` when the provider returns `nil`.

### Task 4: Update documentation and verify the complete change

**Files:**
- Modify: `docs/superpowers/specs/2026-08-07-kindle-page-capture-design.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: The behavior implemented in Tasks 2 and 3.
- Produces: User-facing documentation that states outer background margins are automatically cropped and ambiguous images are preserved.

- [x] **Step 1: Update the design and README text**

Replace the initial-version statement that says toolbar and whitespace are not automatically removed with text explaining that uniform outer background margins are cropped, while page-internal whitespace is retained and uncertain images are left unchanged.

- [x] **Step 2: Run all tests and inspect the diff**

Run:

```bash
git diff --check
swift test
swift build -c release
```

Expected: all tests pass, the release build succeeds, and the diff contains only cropper implementation, tests, and documentation changes. The pre-existing user changes to `scripts/package-app.sh` must remain unstaged.

- [x] **Step 3: Perform manual verification with Kindle**

Rebuild the App Bundle, grant its existing macOS permissions again if the signature changes, capture a short PDF from a Kindle page with visible outer margins, and inspect that the PDF excludes the uniform outer background while retaining the page's internal white margin.
