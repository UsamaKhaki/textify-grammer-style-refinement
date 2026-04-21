import Foundation

final class GeminiProvider: RefinementProvider {
    private let apiKey: String?
    private let session: URLSession
    private let model = "gemini-2.0-flash"

    init(apiKey: String?, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func refine(_ text: String) async throws -> RefinedTriple {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingKey }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw ProviderError.malformedResponse }

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": RefinementPrompt.system]]
            ],
            "contents": [
                ["role": "user", "parts": [["text": text]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.4
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

        // Decode Gemini envelope → extract `text` field → parse that as RefinedTriple JSON.
        struct Envelope: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard let inner = envelope.candidates.first?.content.parts.first?.text,
                  let innerData = inner.data(using: .utf8) else {
                throw ProviderError.malformedResponse
            }
            return try JSONDecoder().decode(RefinedTriple.self, from: innerData)
        } catch is ProviderError {
            throw ProviderError.malformedResponse
        } catch {
            throw ProviderError.malformedResponse
        }
    }
}
