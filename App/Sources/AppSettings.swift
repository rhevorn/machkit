import AppKit
import Foundation
import SwiftUI

struct AppSettingsView: View {
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(AppPreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage(AppPreferenceKey.aiAssistanceEnabled) private var aiAssistanceEnabled = false
    @AppStorage(AppPreferenceKey.aiBaseURL) private var aiBaseURL = "https://api.openai.com/v1"
    @AppStorage(AppPreferenceKey.aiModel) private var aiModel = ""
    @AppStorage(AppPreferenceKey.aiModels) private var aiModelsJSON = "[]"
    @State private var aiAPIKey = ""
    @State private var aiKeyStatus: String?
    @State private var newAIModel = ""

    private var aiModels: [String] {
        guard let data = aiModelsJSON.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings").font(.system(size: 18, weight: .semibold))
                    Text("Manage language, appearance, and other preferences")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            settingsContent
        }
        .environment(\.locale, language.locale)
        .preferredColorScheme(appearance.colorScheme)
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Interface and display".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                VStack(spacing: 0) {
                    settingRow(
                        icon: "character.bubble",
                        color: .blue,
                        title: "Language",
                        detail: "Select the interface language used by Sift"
                    ) {
                        Picker("Language", selection: $languageRawValue) {
                            ForEach(AppLanguage.allCases) { option in
                                Text(verbatim: option.title).tag(option.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 168, idealWidth: 190, maxWidth: 220)
                    }

                    Divider().padding(.leading, 64)

                    settingRow(
                        icon: "circle.lefthalf.filled",
                        color: .indigo,
                        title: "Display Mode",
                        detail: "Follow macOS, or stick to light or dark colors"
                    ) {
                        Picker("Appearance", selection: $appearanceRawValue) {
                            ForEach(AppAppearance.allCases) { option in
                                Text(option.title.localized).tag(option.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(minWidth: 180, idealWidth: 270, maxWidth: 340)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
                }

                Label("Changes are applied immediately.".localized, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, 2)

                Text("AI Features".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, 14)

                VStack(spacing: 0) {
                    settingRow(
                        icon: "sparkles",
                        color: .purple,
                        title: "AI Assistance",
                        detail: "Enable AI explanations and personalized recommendations"
                    ) {
                        Toggle("AI Assistance", isOn: $aiAssistanceEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().padding(.leading, 64)

                    settingRow(
                        icon: "link",
                        color: .teal,
                        title: "Base URL",
                        detail: "OpenAI-compatible API endpoint"
                    ) {
                        TextField("Base URL", text: $aiBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 180, idealWidth: 300, maxWidth: 340)
                            .disabled(!aiAssistanceEnabled)
                    }

                    Divider().padding(.leading, 64)

                    settingRow(
                        icon: "key",
                        color: .orange,
                        title: "API Key",
                        detail: aiKeyStatus ?? "Stored securely in the macOS Keychain"
                    ) {
                        HStack(spacing: 8) {
                            SecureField("API Key", text: $aiAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(saveAPIKey)
                            Button("Save", action: saveAPIKey)
                        }
                        .frame(minWidth: 180, idealWidth: 300, maxWidth: 340)
                        .disabled(!aiAssistanceEnabled)
                    }

                    Divider().padding(.leading, 64)

                    settingRow(
                        icon: "cpu",
                        color: .blue,
                        title: "Model",
                        detail: "Model identifier used for AI requests"
                    ) {
                        HStack(spacing: 8) {
                            Picker("Model", selection: $aiModel) {
                                if aiModels.isEmpty {
                                    Text("No models added").tag("")
                                } else {
                                    ForEach(aiModels, id: \.self) { Text(verbatim: $0).tag($0) }
                                }
                            }
                            .labelsHidden()
                            .frame(minWidth: 150, idealWidth: 220, maxWidth: 270)

                            Button {
                                removeSelectedModel()
                            } label: {
                                Image(systemName: "minus")
                            }
                            .disabled(!aiAssistanceEnabled || aiModel.isEmpty)
                        }
                        .disabled(!aiAssistanceEnabled)
                    }

                    Divider().padding(.leading, 64)

                    settingRow(
                        icon: "plus",
                        color: .green,
                        title: "Add Model",
                        detail: "Add a model identifier supported by this endpoint"
                    ) {
                        HStack(spacing: 8) {
                            TextField("Model identifier", text: $newAIModel)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(addModel)
                            Button("Add", action: addModel)
                                .disabled(newAIModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .frame(minWidth: 180, idealWidth: 300, maxWidth: 340)
                        .disabled(!aiAssistanceEnabled)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
                }

                Label(
                    "AI only provides explanations and recommendations. It never deletes files or ends processes automatically.".localized,
                    systemImage: "shield.checkered"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.top, 2)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if aiAPIKey.isEmpty { aiAPIKey = AIKeychain.load() }
            if aiModels.isEmpty, !aiModel.isEmpty { saveModels([aiModel]) }
        }
    }

    private func settingRow<Control: View>(
        icon: String,
        color: Color,
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 14) {
            settingsIcon(icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 13, weight: .semibold))
                Text(detail.localized).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 24)
            control()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
    }

    private func settingsIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12))
            Image(systemName: systemName).foregroundStyle(color)
        }
        .frame(width: 34, height: 34)
    }

    private func addModel() {
        let value = newAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var models = aiModels
        if !models.contains(value) { models.append(value) }
        saveModels(models)
        aiModel = value
        newAIModel = ""
    }

    private func removeSelectedModel() {
        var models = aiModels
        models.removeAll { $0 == aiModel }
        saveModels(models)
        aiModel = models.first ?? ""
    }

    private func saveModels(_ models: [String]) {
        guard let data = try? JSONEncoder().encode(models),
              let value = String(data: data, encoding: .utf8) else { return }
        aiModelsJSON = value
    }

    private func saveAPIKey() {
        switch AIKeychain.save(aiAPIKey) {
        case .success:
            aiKeyStatus = aiAPIKey.isEmpty ? "API Key removed".localized : "API Key saved".localized
        case .failure(let error):
            aiKeyStatus = error.localizedDescription
        }
    }
}
