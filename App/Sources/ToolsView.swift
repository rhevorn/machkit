import SwiftUI

private struct ToolDefinition: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let windowID: String
}

struct ToolsView: View {
    @Environment(\.openWindow) private var openWindow

    private let tools = [
        ToolDefinition(
            id: "hosts-manager",
            title: "Hosts Manager",
            description: "View the system hosts file and switch mappings between development environments",
            icon: "network.badge.shield.half.filled",
            color: .blue,
            windowID: "hosts-manager"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tools".localized).font(.system(size: 18, weight: .semibold))
                    Text("A growing collection of focused utilities for developers".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Developer Tools".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 14)],
                        alignment: .leading,
                        spacing: 14
                    ) {
                        ForEach(tools) { tool in
                            toolCard(tool)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private func toolCard(_ tool: ToolDefinition) -> some View {
        Button {
            openWindow(id: tool.windowID)
        } label: {
            HStack(spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(tool.color.opacity(0.12))
                    Image(systemName: tool.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(tool.color)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text(tool.title.localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(tool.description.localized)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .help(tool.title.localized)
    }
}
