// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sift", targets: ["Sift"]),
        .library(name: "SiftCore", targets: ["SiftCore"])
    ],
    targets: [
        .target(name: "SiftCore"),
        .executableTarget(name: "Sift", dependencies: ["SiftCore"]),
        .testTarget(name: "SiftCoreTests", dependencies: ["SiftCore"])
    ]
)
