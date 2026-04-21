import Foundation

final class GeminiProvider: RefinementProvider {
    private let apiKey: String?
    private let session: URLSession
    private let model = "gemini-2.5-flash"

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
        if http.statusCode != 200 {
            // Pull out Google's actual error message so we see the real cause
            // (quota exhausted, model unavailable, billing required, bad key, etc.)
            // instead of a generic status-code error.
            struct ErrorEnvelope: Decodable {
                struct Err: Decodable { let code: Int?; let message: String; let status: String? }
                let error: Err
            }
            let body = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message
            switch http.statusCode {
            case 401, 403: throw ProviderError.network("Gemini \(http.statusCode): \(body ?? "unauthorized")")
            case 429:      throw ProviderError.network("Gemini 429: \(body ?? "rate limited")")
            default:       throw ProviderError.network("Gemini \(http.statusCode): \(body ?? "unknown error")")
            }
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
