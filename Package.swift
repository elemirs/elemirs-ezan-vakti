// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EzanVakti",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "EzanCore"),
        .executableTarget(name: "EzanVakti", dependencies: ["EzanCore"]),
        .testTarget(name: "EzanCoreTests", dependencies: ["EzanCore"]),
    ]
)
