import AppKit
import MachKitCore
import SwiftUI

struct RemovalOperationReport: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let movedToTrash: [URL]
    let permanentlyDeleted: [URL]
    let failures: [CleanFailure]

    init(
        title: String,
        summary: String,
        movedToTrash: [URL],
        permanentlyDeleted: [URL] = [],
        failures: [CleanFailure]
    ) {
        self.title = title
        self.summary = summary
        self.movedToTrash = movedToTrash
        self.permanentlyDeleted = permanentlyDeleted
        self.failures = failures
    }
}

struct OperationResultView: View {
    let report: RemovalOperationReport
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title).font(.title2.weight(.semibold))
                    Text(report.summary).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: onDone).keyboardShortcut(.defaultAction)
            }

            if !report.failures.isEmpty {
                resultGroup(title: "Need to be processed") {
                    ForEach(Array(report.failures.enumerated()), id: \.offset) { _, failure in
                        resultRow(url: failure.url, detail: failure.reason, succeeded: false)
                    }
                }
            }

            if !report.permanentlyDeleted.isEmpty {
                resultGroup(title: "Permanently deleted") {
                    ForEach(report.permanentlyDeleted, id: \.path) { url in
                        resultRow(url: url, detail: "Removed permanently", succeeded: true)
                    }
                }
            }

            if !report.movedToTrash.isEmpty {
                resultGroup(title: "Moved to trash") {
                    ForEach(report.movedToTrash, id: \.path) { url in
                        resultRow(url: url, detail: "Recoverable from Trash", succeeded: true)
                    }
                }
            }
        }
        .padding(MachKitLayout.sheetPadding)
        .frame(minWidth: 620, minHeight: 260)
    }

    private func resultGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox(title) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    content()
                }
            }
            .frame(maxHeight: 230)
        }
    }

    private func resultRow(url: URL, detail: String, succeeded: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(succeeded ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(L10n.diagnostic(detail)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(url.path).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer()
            Button("Show") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, MachKitLayout.controlSpacing)
        .overlay(alignment: .bottom) { Divider() }
    }
}
