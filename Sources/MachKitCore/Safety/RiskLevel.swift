import Foundation

public enum RiskLevel: String, Codable, Sendable, CaseIterable {
    case safe
    case review
    case blocked
}
