// swift-tools-version:5.9
// Dependency-free helper CLIs used by bin/mainline.
//   asc     — minimal App Store Connect API client (JWT signed with CryptoKit)
//   appicon — renders a 1024×1024 opaque App Store icon from an SF Symbol or text
import PackageDescription

let package = Package(
    name: "MainlineTools",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "asc", path: "Sources/asc"),
        .executableTarget(name: "appicon", path: "Sources/appicon"),
        .testTarget(name: "ASCTests", dependencies: ["asc"]),
    ]
)
