import XCTest
@testable import Textify

final class OpenAIProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeProvider(apiKey: String? = "sk-test") -> OpenAIProvider {
        OpenAIProvider(apiKey: apiKey, session: MockURLProtocol.makeSession())
    }

    func testSuccessfulRefinement() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            let inner = #"{\"casual\":\"hey\",\"professional\":\"Hello\",\"concise\":\"Hi\"}"#
            let body = """
            {"choices":[{"message":{"content":"\(inner)"}}]}
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        let triple = try await makeProvider().refine("hi")
        XCTAssertEqual(triple, RefinedTriple(casual: "hey", professional: "Hello", concise: "Hi"))
    }

    func testMissingKey() async {
        do {
            _ = try await makeProvider(apiKey: nil).refine("x")
            XCTFail("expected error")
        } catch let e as ProviderError {
            XCTAssertEqual(e, .missingKey)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testUnauthorized() async {
        MockURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await makeProvider().refine("x")
            XCTFail("expected error")
        } catch let e as ProviderError {
            XCTAssertEqual(e, .unauthorized)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testRateLimited() async {
        MockURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await makeProvider().refine("x")
            XCTFail("expected error")
        } catch let e as ProviderError {
            XCTAssertEqual(e, .rateLimited)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testMalformedResponse() async {
        MockURLProtocol.handler = { req in
            let body = #"{"choices":[{"message":{"content":"not json"}}]}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        do {
            _ = try await makeProvider().refine("x")
            XCTFail("expected error")
        } catch let e as ProviderError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }
}
