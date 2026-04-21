import XCTest
@testable import Textify

final class GeminiProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeProvider(apiKey: String? = "gemini-key-xyz") -> GeminiProvider {
        GeminiProvider(apiKey: apiKey, session: MockURLProtocol.makeSession())
    }

    func testSuccessfulRefinement() async throws {
        MockURLProtocol.handler = { request in
            // Verify URL shape
            XCTAssertEqual(request.httpMethod, "POST")
            let url = request.url!.absoluteString
            XCTAssertTrue(url.contains("gemini-2.0-flash"))
            XCTAssertTrue(url.contains("key=gemini-key-xyz"))
            // Fake a successful Gemini response that wraps our JSON in its candidates structure
            let inner = #"{"casual":"Hey!","professional":"Hello.","concise":"Hi."}"#
            let body = """
            {"candidates":[{"content":{"parts":[{"text":\(Self.jsonQuote(inner))}]}}]}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
        let triple = try await makeProvider().refine("heyy how r u")
        XCTAssertEqual(triple, RefinedTriple(casual: "Hey!", professional: "Hello.", concise: "Hi."))
    }

    func testMissingKey() async {
        do {
            _ = try await makeProvider(apiKey: nil).refine("anything")
            XCTFail("expected error")
        } catch let e as ProviderError {
            XCTAssertEqual(e, .missingKey)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testUnauthorized() async {
        MockURLProtocol.handler = { req in
            let body = #"{"error":{"code":401,"message":"API key not valid","status":"UNAUTHENTICATED"}}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        do {
            _ = try await makeProvider().refine("x")
            XCTFail("expected error")
        } catch let e as ProviderError {
            if case .network(let msg) = e {
                XCTAssertTrue(msg.contains("401"), "message should mention 401: \(msg)")
                XCTAssertTrue(msg.contains("API key not valid"), "message should include Google's body: \(msg)")
            } else { XCTFail("expected .network(...), got \(e)") }
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testRateLimited() async {
        MockURLProtocol.handler = { req in
            let body = #"{"error":{"code":429,"message":"Quota exceeded","status":"RESOURCE_EXHAUSTED"}}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        do {
            _ = try await makeProvider().refine("x")
            XCTFail("expected error")
        } catch let e as ProviderError {
            if case .network(let msg) = e {
                XCTAssertTrue(msg.contains("429"), "message should mention 429: \(msg)")
                XCTAssertTrue(msg.contains("Quota exceeded"), "message should include Google's body: \(msg)")
            } else { XCTFail("expected .network(...), got \(e)") }
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testMalformedResponse() async {
        MockURLProtocol.handler = { req in
            let body = #"{"candidates":[{"content":{"parts":[{"text":"not json"}]}}]}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        do {
            _ = try await makeProvider().refine("x")
            XCTFail("expected error")
        } catch let e as ProviderError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }

    private static func jsonQuote(_ s: String) -> String {
        // Produce a JSON-string literal of s (with surrounding quotes and escaped inner quotes).
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
