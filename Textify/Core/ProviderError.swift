import Foundation

enum ProviderError: LocalizedError, Equatable {
    case missingKey
    case network(String)
    case unauthorized
    case rateLimited
    case server(Int)
    case malformedResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingKey:        return "Add your API key in Settings"
        case .network(let msg):  return "Network error: \(msg)"
        case .unauthorized:      return "API key rejected. Update it in Settings."
        case .rateLimited:       return "Rate limit hit. Try again in a moment."
        case .server(let code):  return "Provider server error (\(code)). Try again."
        case .malformedResponse: return "Unexpected response. Please try again."
        case .timeout:           return "Request timed out. Check your connection."
        }
    }
}
