import Foundation
import MachKitCore

struct JunkScanGroup: Identifiable, Sendable {
    let id: String
    let title: String
    let explanation: String
    let risk: RiskLevel
    let items: [ScanItem]
    let bytes: Int64
}

enum ApplicationCategory: String, CaseIterable, Sendable {
    case user = "User Apps"
    case appStore = "App Store"
    case thirdParty = "Third-Party Apps"
    case system = "Apple System Apps"

    var subtitle: String {
        switch self {
        case .user: "Installed in the current user's folder"
        case .appStore: "Installed from the Mac App Store"
        case .thirdParty: "Installed from a developer or another source"
        case .system: "Built into macOS and system protected"
        }
    }
}

struct ApplicationGroup: Identifiable, Sendable {
    let category: ApplicationCategory
    let applications: [InstalledApplication]
    var id: String { category.rawValue }
    var bytes: Int64 { applications.reduce(0) { $0 + $1.bytes } }
}

struct SystemStorageSnapshot: Sendable {
    let totalCapacity: Int64
    let availableCapacity: Int64

    static let empty = SystemStorageSnapshot(totalCapacity: 0, availableCapacity: 0)

    var usedCapacity: Int64 { max(0, totalCapacity - availableCapacity) }
    var usedFraction: Double {
        guard totalCapacity > 0 else { return 0 }
        return min(1, max(0, Double(usedCapacity) / Double(totalCapacity)))
    }
}
