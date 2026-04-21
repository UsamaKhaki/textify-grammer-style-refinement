import XCTest
@testable import Textify

final class AnthropicProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeProvider(apiKey: String? = "sk-ant-test") -> AnthropicProvider {
        AnthropicProvider(apiKey: apiKey, session: MockURLProtocol.makeSession())
    }

    func testSuccessfulRefinement() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            let inner = #"{\"casual\":\"hi!\",\"professional\":\"Hello.\",\"concise\":\"Hi.\"}"#
            let body = """
            {"content":[{"type":"text","text":"\(inner)"}]}
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        let triple = try await makeProvider().refine("hi")
        XCTAssertEqual(triple, RefinedTriple(casual: "hi!", professional: "Hello.", concise: "Hi."))
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
            let body = #"{"content":[{"type":"text","text":"not json"}]}"#
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
