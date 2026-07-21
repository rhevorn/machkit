import Foundation

public enum DefaultRules {
    /// Conservative rules only. These paths are resolved beneath a directory
    /// explicitly chosen by the user; no absolute path is accepted here.
    public static let conservative: [ScanRule] = [
        ScanRule(
            id: "user-caches",
            title: "用户缓存",
            relativePath: "Library/Caches",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: "30 天未修改的普通缓存；应用下次启动时可能重新生成。"
        ),
        ScanRule(
            id: "user-logs",
            title: "旧日志",
            relativePath: "Library/Logs",
            minimumAgeDays: 14,
            allowedExtensions: ["log", "txt", "old"],
            risk: .safe,
            explanation: "14 天前的日志文件，不包含当前正在写入的文件。"
        ),
        ScanRule(
            id: "downloads-archives",
            title: "旧安装包与压缩包",
            relativePath: "Downloads",
            minimumAgeDays: 30,
            allowedExtensions: ["dmg", "pkg", "zip"],
            risk: .review,
            explanation: "旧下载文件可能仍有价值，必须由用户逐项确认。"
        ),
        ScanRule(
            id: "npm-cache",
            title: "npm 下载缓存",
            relativePath: ".npm/_cacache",
            minimumAgeDays: 14,
            risk: .safe,
            explanation: "npm 可重新下载的内容寻址缓存；不会删除全局包或项目 node_modules。"
        ),
        ScanRule(
            id: "npm-logs",
            title: "npm 调试日志",
            relativePath: ".npm/_logs",
            minimumAgeDays: 7,
            allowedExtensions: ["log"],
            risk: .safe,
            explanation: "旧 npm 调试日志。"
        ),
        ScanRule(
            id: "python-pip-cache",
            title: "Python pip 缓存",
            relativePath: "Library/Caches/pip",
            minimumAgeDays: 14,
            risk: .safe,
            explanation: "pip 下载和构建缓存；不会删除 Python、site-packages 或虚拟环境。"
        ),
        ScanRule(
            id: "python-uv-cache",
            title: "Python uv 缓存",
            relativePath: ".cache/uv",
            minimumAgeDays: 14,
            risk: .safe,
            explanation: "uv 可重新生成的缓存；不会删除项目虚拟环境。"
        ),
        ScanRule(
            id: "cargo-cache",
            title: "Cargo 下载缓存",
            relativePath: ".cargo/registry/cache",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: "Rust crate 下载缓存；不会删除工具链、源码或已安装命令。"
        ),
        ScanRule(
            id: "xcode-derived-data",
            title: "Xcode Derived Data",
            relativePath: "Library/Developer/Xcode/DerivedData",
            minimumAgeDays: 14,
            risk: .review,
            explanation: "Xcode 构建产物，可重新生成，但下次构建会变慢。"
        )
    ]
}
