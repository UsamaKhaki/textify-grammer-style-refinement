import XCTest
@testable import Textify

private final class StubProvider: RefinementProvider {
    var result: Result<RefinedTriple, Error>
    init(_ r: Result<RefinedTriple, Error>) { self.result = r }
    func refine(_ text: String) async throws -> RefinedTriple {
        switch result {
        case .success(let t): return t
        case .failure(let e): throw e
        }
    }
}

@MainActor
final class RefinementViewModelTests: XCTestCase {
    func testInitialStateIsEmptyWhenNoClipboard() {
        let vm = RefinementViewModel(
            clipboardText: nil,
            providerFactory: { _ in StubProvider(.success(.init(casual: "", professional: "", concise: ""))) }
        )
        if case .empty = vm.state { /* ok */ } else { XCTFail("expected .empty, got \(vm.state)") }
    }

    func testSuccessfulRefineTransitionsLoadingThenResult() async {
        let triple = RefinedTriple(casual: "a", professional: "b", concise: "c")
        let vm = RefinementViewModel(
            clipboardText: "raw text",
            providerFactory: { _ in StubProvider(.success(triple)) }
        )
        XCTAssertEqual(vm.original, "raw text")
        await vm.refine()
        if case .result(let t) = vm.state { XCTAssertEqual(t, triple) } else { XCTFail("expected .result, got \(vm.state)") }
    }

    func testProviderErrorSurfacesAsErrorState() async {
        let vm = RefinementViewModel(
            clipboardText: "hi",
            providerFactory: { _ in StubProvider(.failure(ProviderError.unauthorized)) }
        )
        await vm.refine()
        if case .error(let e) = vm.state { XCTAssertEqual(e, .unauthorized) } else { XCTFail("expected .error, got \(vm.state)") }
    }

    func testUpdatingPastedTextThenRefineUsesThatText() async {
        let triple = RefinedTriple(casual: "x", professional: "y", concise: "z")
        var received: String = ""
        let vm = RefinementViewModel(
            clipboardText: nil,
            providerFactory: { _ in
                let s = StubProvider(.success(triple))
                return SpyProvider(inner: s) { received = $0 }
            }
        )
        vm.original = "pasted message"
        await vm.refine()
        XCTAssertEqual(received, "pasted message")
        if case .result(let t) = vm.state { XCTAssertEqual(t, triple) } else { XCTFail("expected .result") }
    }
}

// Tiny spy that captures the input text and then delegates.
private final class SpyProvider: RefinementProvider {
    let inner: RefinementProvider
    let onCall: (String) -> Void
    init(inner: RefinementProvider, onCall: @escaping (String) -> Void) {
        self.inner = inner; self.onCall = onCall
    }
    func refine(_ text: String) async throws -> RefinedTriple {
        onCall(text)
        return try await inner.refine(text)
    }
}
