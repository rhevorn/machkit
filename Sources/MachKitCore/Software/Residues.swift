import Foundation

public enum ResidueKind: String, Sendable {
    case cache = "cache"
    case preferences = "Preferences"
    case support = "application data"
    case state = "window status"
    case logs = "Log"
    case container = "sandbox container"
}

public struct ApplicationResidue: Identifiable, Sendable, Hashable {
    public let id: String
    public let url: URL
    public let kind: ResidueKind
    public let bytes: Int64
    public let risk: RiskLevel

    public init(url: URL, kind: ResidueKind, bytes: Int64, risk: RiskLevel) {
        self.id = url.path
        self.url = url
        self.kind = kind
        self.bytes = bytes
        self.risk = risk
    }
}

public struct ApplicationResidueGroup: Identifiable, Sendable, Hashable {
    public let identifier: String
    public let residues: [ApplicationResidue]

    public var id: String { identifier }
    public var bytes: Int64 { residues.reduce(0) { $0 + $1.bytes } }

    public init(identifier: String, residues: [ApplicationResidue]) {
        self.identifier = identifier
        self.residues = residues
    }
}

public struct ApplicationResidueScanProgress: Sendable {
    public let completedPaths: Int
    public let totalPaths: Int
    public let inspectedFiles: Int
    public let currentPathInspectedFiles: Int

    public var fractionCompleted: Double {
        guard totalPaths > 0 else { return 1 }
        let activity: Double
        if currentPathInspectedFiles > 0 {
            activity = min(0.9, 0.12 + log10(Double(currentPathInspectedFiles) + 1) * 0.13)
        } else {
            activity = 0
        }
        return min((Double(completedPaths) + activity) / Double(totalPaths), 1)
    }

    public init(completedPaths: Int, totalPaths: Int, inspectedFiles: Int, currentPathInspectedFiles: Int) {
        self.completedPaths = completedPaths
        self.totalPaths = totalPaths
        self.inspectedFiles = inspectedFiles
        self.currentPathInspectedFiles = currentPathInspectedFiles
    }
}
