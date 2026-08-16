// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MachKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MachKitCore", targets: ["MachKitCore"])
    ],
    targets: [
        .target(name: "MachKitCore"),
        .testTarget(name: "MachKitCoreTests", dependencies: ["MachKitCore"])
    ]
)
