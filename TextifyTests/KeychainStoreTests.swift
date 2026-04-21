import XCTest
@testable import Textify

final class KeychainStoreTests: XCTestCase {
    let store = KeychainStore(service: "com.textify.tests")

    override func setUp() {
        super.setUp()
        // Ensure a clean slate before each test
        for kind in ProviderKind.allCases { try? store.delete(for: kind) }
    }

    override func tearDown() {
        for kind in ProviderKind.allCases { try? store.delete(for: kind) }
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        try store.save("sk-test-123", for: .openai)
        XCTAssertEqual(try store.load(for: .openai), "sk-test-123")
    }

    func testLoadReturnsNilWhenMissing() throws {
        XCTAssertNil(try store.load(for: .gemini))
    }

    func testOverwrite() throws {
        try store.save("first", for: .groq)
        try store.save("second", for: .groq)
        XCTAssertEqual(try store.load(for: .groq), "second")
    }

    func testDelete() throws {
        try store.save("to-be-deleted", for: .gemini)
        try store.delete(for: .gemini)
        XCTAssertNil(try store.load(for: .gemini))
    }

    func testKeysAreIsolatedPerProvider() throws {
        try store.save("gem", for: .gemini)
        try store.save("oai", for: .openai)
        XCTAssertEqual(try store.load(for: .gemini), "gem")
        XCTAssertEqual(try store.load(for: .openai), "oai")
    }
}
