// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KindleToPDF",
    platforms: [.macOS(.v13)],
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
)
