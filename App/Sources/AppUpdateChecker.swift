import AppKit
import Foundation
import MachKitCore

/// User-initiated GitHub Releases check. Never runs automatically.
@MainActor
final class AppUpdateChecker {
    static let shared = AppUpdateChecker()

    private var inFlight: Task<Void, Never>?

    private init() {}

    func checkForUpdates() {
        if inFlight != nil {
            presentSimple(
                title: L10n.string("Checking for Updates…"),
                message: L10n.string("An update check is already in progress."),
                style: .informational
            )
            return
        }

        MachKitAppLifecycle.showInForeground()
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"

        inFlight = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.inFlight = nil }

            let result = await Self.fetchLatestRelease()
            if Task.isCancelled { return }

            switch result {
            case .success(let latest):
                self.present(status: AppUpdateCheck.status(currentVersionRaw: currentVersion, latest: latest))
            case .failure(let error):
                if error is CancellationError { return }
                self.presentFailure(error)
            }
        }
    }

    private func present(status: AppUpdateStatus) {
        switch status {
        case let .upToDate(current, _):
            presentSimple(
                title: L10n.string("You're Up to Date"),
                message: L10n.format("You're running MachKit %@.", current),
                style: .informational
            )
        case let .updateAvailable(current, latest, releaseURL):
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = L10n.string("Update Available")
            alert.informativeText = L10n.format(
                "MachKit %@ is available. You have %@.",
                latest,
                current
            )
            alert.addButton(withTitle: L10n.string("View on GitHub"))
            alert.addButton(withTitle: L10n.string("Later"))
            if runAlert(alert) == .alertFirstButtonReturn {
                NSWorkspace.shared.open(releaseURL)
            }
        }
    }

    private func presentFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.string("Unable to Check for Updates")
        alert.informativeText = Self.localizedMessage(for: error)
        alert.addButton(withTitle: L10n.string("OK"))
        alert.addButton(withTitle: L10n.string("View on GitHub"))
        if runAlert(alert) == .alertSecondButtonReturn {
            NSWorkspace.shared.open(AppUpdateCheck.releasesPageURL)
        }
    }

    private func presentSimple(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L10n.string("OK"))
        _ = runAlert(alert)
    }

    private func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        MachKitAppLifecycle.showInForeground()
        return alert.runModal()
    }

    private static func localizedMessage(for error: Error) -> String {
        if error is CancellationError {
            return L10n.string("This check was canceled.")
        }
        if let checkError = error as? AppUpdateCheckError {
            switch checkError {
            case .invalidResponse, .missingReleaseFields, .unreadableLatestVersion:
                return L10n.string("Couldn't understand the GitHub release response.")
            case let .httpStatus(code):
                return L10n.format("GitHub returned HTTP %lld.", Int64(code))
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return L10n.string("Couldn't reach GitHub Releases. Check your network connection and try again.")
        }
        return error.localizedDescription
    }

    private static func fetchLatestRelease() async -> Result<GitHubLatestRelease, Error> {
        // Use the public Atom feed instead of api.github.com. Unauthenticated
        // REST calls frequently receive HTTP 403 from GitHub’s edge/rate limits.
        var request = URLRequest(url: AppUpdateCheck.releasesFeedURL)
        request.timeoutInterval = 15
        request.setValue("application/atom+xml, application/xml;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("MachKit/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return .failure(CancellationError()) }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return .failure(AppUpdateCheckError.httpStatus(http.statusCode))
            }
            return .success(try AppUpdateCheck.parseLatestRelease(fromAtom: data))
        } catch {
            return .failure(error)
        }
    }
}
