import Foundation

enum ProjectBuildArtifactsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "project-build-artifacts",
        title: "Project Build Artifacts",
        relativePaths: [
            "Developer", "Projects", "GitHub", "Code", "Workspace", "Work", "Sites",
        ],
        minimumAgeDays: 7,
        enumerationMode: .projectBuildArtifacts,
        risk: .review,
        explanation: "Rebuildable dependency and compiler output inside recognized projects. Source files are never selected; the next install or build may take longer."
    )
}
