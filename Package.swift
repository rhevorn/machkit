// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sift",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SiftCore", targets: ["SiftCore"])
    ],
    targets: [
        .target(
            name: "SiftPrivilegedShim",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .target(name: "SiftCore", dependencies: ["SiftPrivilegedShim"]),
        .testTarget(name: "SiftCoreTests", dependencies: ["SiftCore"])
    ]
)
