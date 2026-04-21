import Foundation

enum ProviderKind: String, CaseIterable, Identifiable, Codable {
    case gemini
    case openai
    case groq
    case anthropic

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .gemini:    return "Gemini 2.5 Flash (free)"
        case .openai:    return "OpenAI GPT-4o-mini"
        case .groq:      return "Groq Llama 3.3 70B (free)"
        case .anthropic: return "Anthropic Claude Opus 4.7"
        }
    }
}
