import XCTest
import AppKit
@testable import Textify

final class ClipboardServiceTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var service: ClipboardService!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: NSPasteboard.Name("com.textify.tests.pb"))
        pasteboard.clearContents()
        service = ClipboardService(pasteboard: pasteboard)
    }

    func testReadReturnsNilWhenEmpty() {
        XCTAssertNil(service.readText())
    }

    func testReadReturnsString() {
        pasteboard.setString("hello world", forType: .string)
        XCTAssertEqual(service.readText(), "hello world")
    }

    func testReadReturnsNilForWhitespaceOnly() {
        pasteboard.setString("   \n\t ", forType: .string)
        XCTAssertNil(service.readText())
    }

    func testWriteReplacesContents() {
        pasteboard.setString("old", forType: .string)
        service.writeText("new")
        XCTAssertEqual(pasteboard.string(forType: .string), "new")
    }
}
