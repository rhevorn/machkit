import Foundation

public enum DefaultRules {
    public static let uninstallLeftovers = ScanRule(
        id: "uninstall-leftovers",
        title: "Uninstall Leftovers",
        relativePath: "Library",
        minimumAgeDays: 0,
        risk: .review,
        explanation: "Files whose app is no longer installed; review them before moving them to Trash."
    )

    /// Conservative rules only. These paths are resolved beneath a directory
    /// explicitly chosen by the user; no absolute path is accepted here.
    public static let conservative: [ScanRule] = [
        ScanRule(
            id: "user-caches",
            title: "User Caches",
            relativePath: "Library/Caches",
            minimumAgeDays: 30,
            excludedRelativePaths: ["Homebrew", "CocoaPods", "org.swift.swiftpm", "Yarn", "pip"],
            risk: .safe,
            explanation: "Regular caches unchanged for 30 days; apps may recreate them at next launch."
        ),
        ScanRule(
            id: "user-logs",
            title: "Old Logs",
            relativePath: "Library/Logs",
            minimumAgeDays: 14,
            allowedExtensions: ["log", "txt", "old"],
            risk: .safe,
            explanation: "Log files older than 14 days, excluding files currently being written."
        ),
        ScanRule(
            id: "downloads-archives",
            title: "Old installation packages and compressed packages",
            relativePath: "Downloads",
            minimumAgeDays: 30,
            allowedExtensions: ["dmg", "pkg", "zip"],
            risk: .review,
            explanation: "Old downloads may still have value and must be confirmed individually by the user."
        ),
        ScanRule(
            id: "npm-cache",
            title: "npm Download Cache",
            relativePath: ".npm/_cacache",
            minimumAgeDays: 14,
            risk: .safe,
            explanation: "Redownloadable npm content-addressed cache; global packages and project node_modules are not deleted."
        ),
        ScanRule(
            id: "npm-logs",
            title: "npm Debug Logs",
            relativePath: ".npm/_logs",
            minimumAgeDays: 7,
            allowedExtensions: ["log"],
            risk: .safe,
            explanation: "Old npm debug logs."
        ),
        ScanRule(
            id: "homebrew-download-cache",
            title: "Homebrew Download Cache",
            relativePath: "Library/Caches/Homebrew/downloads",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: "Downloaded formula and cask archives; installed packages in Cellar and Caskroom are not touched."
        ),
        ScanRule(
            id: "cocoapods-cache",
            title: "CocoaPods Cache",
            relativePath: "Library/Caches/CocoaPods",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: "Downloaded pod archives and specs can be fetched again; project Pods directories are not scanned."
        ),
        ScanRule(
            id: "swiftpm-cache",
            title: "Swift Package Manager Cache",
            relativePath: "Library/Caches/org.swift.swiftpm",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: "Swift package metadata and downloads can be resolved again; project checkouts and source packages are preserved."
        ),
        ScanRule(
            id: "yarn-cache",
            title: "Yarn Download Cache",
            relativePath: "Library/Caches/Yarn",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: "Global Yarn download cache; project node_modules and offline mirrors are not scanned."
        ),
        ScanRule(
            id: "gradle-cache",
            title: "Gradle Build Cache",
            relativePath: ".gradle/caches",
            minimumAgeDays: 30,
            risk: .review,
            explanation: "Gradle can rebuild or redownload these files, but the next Android or JVM build may be much slower."
        ),
        ScanRule(
            id: "android-cache",
            title: "Android Tool Cache",
            relativePath: ".android/cache",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: "Regenerable Android tool downloads and metadata; SDK platforms, emulators, and projects are not scanned."
        ),
        ScanRule(
            id: "simulator-cache",
            title: "Apple Simulator Cache",
            relativePath: "Library/Developer/CoreSimulator/Caches",
            minimumAgeDays: 30,
            risk: .review,
            explanation: "Regenerable simulator caches only; simulator devices, installed runtimes, and app data are preserved."
        ),
        ScanRule(
            id: "python-pip-cache",
            title: "Python pip cache",
            relativePath: "Library/Caches/pip",
            minimumAgeDays: 14,
            risk: .safe,
            explanation: "pip download and build cache; Python, site-packages, or virtual environments will not be deleted."
        ),
        ScanRule(
            id: "python-uv-cache",
            title: "Python uv cache",
            relativePath: ".cache/uv",
            minimumAgeDays: 14,
            risk: .safe,
            explanation: "uv Regenerable cache; project virtual environment will not be deleted."
        ),
        ScanRule(
            id: "cargo-cache",
            title: "Cargo download cache",
            relativePath: ".cargo/registry/cache",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: "Rust crate download cache; does not delete toolchains, source code, or installed commands."
        ),
        ScanRule(
            id: "xcode-derived-data",
            title: "Xcode Derived Data",
            relativePath: "Library/Developer/Xcode/DerivedData",
            minimumAgeDays: 14,
            risk: .review,
            explanation: "Xcode build products can be regenerated, but the next build will be slower."
        )
    ]
}
