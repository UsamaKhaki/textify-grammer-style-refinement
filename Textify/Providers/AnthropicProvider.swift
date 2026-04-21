import Foundation

final class AnthropicProvider: RefinementProvider {
    private let apiKey: String?
    private let session: URLSession
    private let model = "claude-opus-4-7"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String?, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func refine(_ text: String) async throws -> RefinedTriple {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingKey }

        // Prompt caching on the system block so repeated refinements pay ~90% less
        // for the system tokens. cache_control: ephemeral = 5-minute TTL.
        // The shared RefinementPrompt.system already instructs Claude to respond
        // with JSON in the {casual, professional, concise} shape — Claude follows
        // this reliably, so we don't need structured-output schema enforcement.
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": [
                [
                    "type": "text",
                    "text": RefinementPrompt.system,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw ProviderError.timeout
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw ProviderError.malformedResponse }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw ProviderError.unauthorized
        case 429:      throw ProviderError.rateLimited
        case 500...599:
            throw ProviderError.server(http.statusCode)
        default:
            // Non-2xx: pull out the actual Anthropic error message so the user
            // sees something more useful than "server error 400".
            struct ErrorEnvelope: Decodable {
                struct Err: Decodable { let type: String; let message: String }
                let error: Err
            }
            if let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw ProviderError.network("Anthropic \(http.statusCode): \(env.error.message)")
            }
            throw ProviderError.server(http.statusCode)
        }

        // Anthropic envelope: { content: [{ type: "text", text: "<JSON>" }, ...] }
        struct Envelope: Decodable {
            struct Block: Decodable {
                let type: String
                let text: String?
            }
            let content: [Block]
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard let inner = envelope.content.first(where: { $0.type == "text" })?.text,
                  let innerData = extractJSON(from: inner) else {
                throw ProviderError.malformedResponse
            }
            return try JSONDecoder().decode(RefinedTriple.self, from: innerData)
        } catch {
            throw ProviderError.malformedResponse
        }
    }

    /// Claude sometimes wraps JSON in markdown code fences (```json ... ```).
    /// Strip them if present, then return the inner JSON bytes.
    private func extractJSON(from text: String) -> Data? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            // Drop opening fence line (```json or ```)
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            // Drop closing fence
            if let fenceRange = s.range(of: "```", options: .backwards) {
                s = String(s[..<fenceRange.lowerBound])
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s.data(using: .utf8)
    }
}
