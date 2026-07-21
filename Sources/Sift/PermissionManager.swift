import AppKit
import Foundation

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var hasFullDiskAccess = false

    init() {
        refresh()
    }

    /// There is no public API that directly reports Full Disk Access. This
    /// checks whether a known TCC-protected user directory can be enumerated,
    /// without reading any file contents.
    func refresh() {
        let protectedDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Mail")
        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: protectedDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            hasFullDiskAccess = true
        } catch {
            hasFullDiskAccess = false
        }
    }

    func openFullDiskAccessSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) { return }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
