// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MachKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MachKitCore", targets: ["MachKitCore"])
    ],
    targets: [
        .target(
            name: "MachKitPrivilegedShim",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .target(name: "MachKitCore", dependencies: ["MachKitPrivilegedShim"]),
        .testTarget(name: "MachKitCoreTests", dependencies: ["MachKitCore"])
    ]
)
