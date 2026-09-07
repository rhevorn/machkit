import Foundation

struct TimeMachineLocalSnapshot: Sendable, Hashable {
    let identifier: String
    let createdAt: Date?
}

enum TimeMachineSnapshotParser {
    private static let prefix = "com.apple.TimeMachine."
    private static let suffix = ".local"

    static func parseList(_ output: String) -> [TimeMachineLocalSnapshot] {
        var seen = Set<String>()
        return output
            .split(whereSeparator: { $0.isNewline })
            .compactMap { rawLine -> TimeMachineLocalSnapshot? in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.hasPrefix(prefix), line.hasSuffix(suffix) else { return nil }
                let start = line.index(line.startIndex, offsetBy: prefix.count)
                let end = line.index(line.endIndex, offsetBy: -suffix.count)
                let identifier = String(line[start..<end])
                guard isValidDeletionIdentifier(identifier), seen.insert(identifier).inserted else {
                    return nil
                }
                return TimeMachineLocalSnapshot(
                    identifier: identifier,
                    createdAt: snapshotDate(identifier)
                )
            }
            .sorted { $0.identifier < $1.identifier }
    }

    static func isValidDeletionIdentifier(_ identifier: String) -> Bool {
        let components = identifier.split(separator: "-")
        guard components.count == 4 else { return false }
        let expectedLengths = [4, 2, 2, 6]
        return zip(components, expectedLengths).allSatisfy { component, length in
            component.count == length && component.allSatisfy(\.isNumber)
        }
    }

    private static func snapshotDate(_ identifier: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.isLenient = false
        return formatter.date(from: identifier)
    }
}
