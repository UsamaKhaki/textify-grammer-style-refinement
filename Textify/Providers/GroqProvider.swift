import Foundation

final class GroqProvider: RefinementProvider {
    private let apiKey: String?
    private let session: URLSession
    private let model = "llama-3.3-70b-versatile"
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    init(apiKey: String?, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func refine(_ text: String) async throws -> RefinedTriple {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingKey }

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.4,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": RefinementPrompt.system],
                ["role": "user", "content": text]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        struct Envelope: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }
        do {
            let env = try JSONDecoder().decode(Envelope.self, from: data)
            guard let inner = env.choices.first?.message.content,
                  let innerData = inner.data(using: .utf8) else {
                throw ProviderError.malformedResponse
            }
            return try JSONDecoder().decode(RefinedTriple.self, from: innerData)
        } catch {
            throw ProviderError.malformedResponse
        }
    }
}
