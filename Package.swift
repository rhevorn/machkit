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
        .target(
            name: "SiftPrivilegedShim",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .target(name: "SiftCore", dependencies: ["SiftPrivilegedShim"]),
        .executableTarget(name: "Sift", dependencies: ["SiftCore"]),
        .testTarget(name: "SiftCoreTests", dependencies: ["SiftCore"])
    ]
)
