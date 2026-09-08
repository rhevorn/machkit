import Foundation

enum MailDownloadsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "mail-downloads",
        title: "Mail Downloads",
        relativePath: "Library/Mail Downloads",
        minimumAgeDays: 14,
        risk: .review,
        explanation: "Attachments saved by Mail into Mail Downloads. Mailboxes and the Mail library itself are not touched."
    )
}
