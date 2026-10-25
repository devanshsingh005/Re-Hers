// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OemerKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        // What the app links: photo in, MusicXML (+ note positions) out.
        .library(name: "OemerKit", targets: ["OemerKit"]),
        // Platform-independent recognition engine (no Core ML), also usable on its own.
        .library(name: "OemerCore", targets: ["OemerCore"]),
    ],
    targets: [
        .target(
            name: "OemerCore",
            path: "Sources/OemerCore"
        ),
        .target(
            name: "OemerKit",
            dependencies: ["OemerCore"],
            path: "Sources/OemerKit",
            resources: [
                .copy("Resources/UNetStaffSymbols.mlpackage"),
                .copy("Resources/SegNetDetails.mlpackage"),
                .copy("Resources/classifiers.bin"),
                .copy("Resources/selftest.bin"),
            ]
        ),
        // Command-line checker used to compare the Swift engine with the Python reference.
        .executableTarget(
            name: "oemer-check",
            dependencies: ["OemerCore"],
            path: "Sources/oemer-check"
        ),
        // macOS demo: full pipeline (Core ML + engine) on an image file, and the model self-test.
        .executableTarget(
            name: "oemer-demo",
            dependencies: ["OemerKit"],
            path: "Sources/oemer-demo"
        ),
        .testTarget(
            name: "OemerCoreTests",
            dependencies: ["OemerCore"],
            path: "Tests/OemerCoreTests",
            // end-to-end fixtures, read from disk by EndToEndTests
            exclude: ["Fixtures"]
        ),
        // Apple layer: photo inputs (orientations, HEIC, large images, CGImage/UIImage) and Core ML.
        .testTarget(
            name: "OemerKitTests",
            dependencies: ["OemerKit"],
            path: "Tests/OemerKitTests"
        ),
    ]
)
