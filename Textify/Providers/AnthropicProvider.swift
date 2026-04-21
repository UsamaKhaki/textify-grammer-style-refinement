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
            ],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "casual":       ["type": "string"],
                            "professional": ["type": "string"],
                            "concise":      ["type": "string"]
                        ],
                        "required": ["casual", "professional", "concise"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("structured-outputs-2025-11-13", forHTTPHeaderField: "anthropic-beta")
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
        case 500...599: throw ProviderError.server(http.statusCode)
        default:       throw ProviderError.server(http.statusCode)
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
                  let innerData = inner.data(using: .utf8) else {
                throw ProviderError.malformedResponse
            }
            return try JSONDecoder().decode(RefinedTriple.self, from: innerData)
        } catch {
            throw ProviderError.malformedResponse
        }
    }
}
