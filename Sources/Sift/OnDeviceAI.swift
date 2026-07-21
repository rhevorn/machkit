import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class OnDeviceAI: ObservableObject {
    @Published private(set) var answer = ""
    @Published private(set) var isGenerating = false
    @Published private(set) var availabilityText = "正在检查设备端 AI…"
    @Published private(set) var isAvailable = false

    init() {
        refreshAvailability()
    }

    func refreshAvailability() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                isAvailable = true
                availabilityText = "Apple 设备端模型 · 内容不会上传"
            case .unavailable(.appleIntelligenceNotEnabled):
                isAvailable = false
                availabilityText = "Apple Intelligence 尚未开启，请前往系统设置启用"
            case .unavailable(.deviceNotEligible):
                isAvailable = false
                availabilityText = "此设备或所在地区暂不支持 Apple Intelligence"
            case .unavailable(.modelNotReady):
                isAvailable = false
                availabilityText = "设备端模型尚未准备好，可能仍在下载"
            case .unavailable:
                isAvailable = false
                availabilityText = "Apple Intelligence 当前不可用，可能受设备、语言或地区限制"
            }
        } else {
            isAvailable = false
            availabilityText = "需要 macOS 26 或更高版本"
        }
        #else
        isAvailable = false
        availabilityText = "当前系统未包含 Foundation Models"
        #endif
    }

    func ask(_ prompt: String) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isGenerating = true
        answer = ""
        Task {
            do {
                answer = try await generate(prompt)
            } catch {
                answer = "暂时无法生成解释：\(error.localizedDescription)"
            }
            isGenerating = false
        }
    }

    private func generate(_ prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                return availabilityText
            }
            let session = LanguageModelSession(instructions: """
                你是 Sift 的本地存储助手。请使用简洁中文解释扫描结果或用户指令。
                你只能提供解释和候选清理方案，不能声称已经执行删除。
                不得建议删除系统目录、用户文档、照片、邮件、钥匙串或未知数据。
                明确区分缓存、可重新生成数据和可能包含用户状态的重要数据。
                回答控制在 220 字以内，优先使用短段落或清单。
                """)
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        return availabilityText
    }
}
