# Textify — Mac Grammar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI Mac menu-bar app that reads the clipboard when ⌘⇧T is pressed, calls an LLM provider (default Gemini 2.0 Flash, free), and shows three refined versions (Casual / Professional / Concise) in a floating window, each selectable via 1/2/3 to copy and auto-close.

**Architecture:** Swift 5.9+ SwiftUI app for macOS 13+. Single process, background (no Dock). A protocol-based provider layer (`RefinementProvider`) with three implementations (Gemini, OpenAI, Groq) isolates networking behind one tested interface. API keys live in Keychain. A `RefinementViewModel` drives the UI state machine. Project is generated via `xcodegen` (reproducible, scripted) and built/tested from the command line with `xcodebuild`.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, `URLSession`, macOS Keychain Services, `sindresorhus/KeyboardShortcuts` SPM package, `xcodegen` for project generation.

---

## File Structure

```
textify/
├── project.yml                              (xcodegen input)
├── Textify.xcodeproj/                       (generated — do NOT hand-edit)
├── Textify/
│   ├── Info.plist                           LSUIElement = true (menu-bar app)
│   ├── TextifyApp.swift                     @main — wires MenuBarExtra + Settings
│   ├── App/
│   │   └── AppCoordinator.swift             Owns services, opens Refinement window
│   ├── Core/
│   │   ├── RefinedTriple.swift              The {casual, professional, concise} DTO
│   │   ├── ProviderError.swift              Typed errors from any provider
│   │   ├── ProviderKind.swift               Enum: gemini / openai / groq
│   │   └── RefinementProvider.swift         Protocol + shared prompt constant
│   ├── Providers/
│   │   ├── GeminiProvider.swift
│   │   ├── OpenAIProvider.swift
│   │   └── GroqProvider.swift
│   ├── Services/
│   │   ├── KeychainStore.swift              API-key storage
│   │   ├── SettingsStore.swift              Non-secret preferences (UserDefaults)
│   │   ├── ClipboardService.swift           Read/write NSPasteboard
│   │   └── HotkeyService.swift              Wraps KeyboardShortcuts package
│   ├── ViewModel/
│   │   └── RefinementViewModel.swift        Empty/Loading/Result/Error state machine
│   └── Views/
│       ├── RefinementWindow.swift           The main floating panel
│       ├── SettingsWindow.swift             Tabbed settings (General/Provider/About)
│       └── Components/
│           ├── RefinementCard.swift         One card per style
│           └── OriginalTextBox.swift        Dimmed original preview
├── TextifyTests/
│   ├── MockURLProtocol.swift                URLProtocol subclass for network stubbing
│   ├── GeminiProviderTests.swift
│   ├── OpenAIProviderTests.swift
│   ├── GroqProviderTests.swift
│   ├── KeychainStoreTests.swift
│   ├── ClipboardServiceTests.swift
│   └── RefinementViewModelTests.swift
├── docs/superpowers/
│   ├── specs/2026-04-21-textify-mac-grammar-app-design.md   (existing)
│   └── plans/2026-04-21-textify-mac-grammar-app.md          (this file)
└── .gitignore
```

Each file has **one responsibility**. Providers share the protocol but don't know about each other. UI code never calls providers directly — it goes through the view model.

---

## Prerequisites

These must exist on the machine before Task 1:
- macOS **14+** (the app's own minimum — we use the `.onKeyPress` SwiftUI API which is macOS 14+ only).
- Xcode 15+ (`xcode-select -p` returns a path).
- Homebrew (`brew --version` works).

Task 1 installs the one missing dev tool (`xcodegen`).

> Spec originally said macOS 13. Bumped to 14 during plan self-review because
> `.onKeyPress` (used for the 1/2/3 shortcuts inside the window) requires
> macOS 14. The user's machine is on a newer macOS, so this is a non-issue.

---

## Task 1: Project bootstrap

**Files:**
- Create: `.gitignore`
- Create: `project.yml`
- Create: `Textify/Info.plist`
- Create: `Textify/TextifyApp.swift` (stub — enough to build an empty menu-bar app)
- Create: `Textify/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Textify/Assets.xcassets/Contents.json`
- Generated: `Textify.xcodeproj/` (via xcodegen)

- [ ] **Step 1.1: Ensure xcodegen is installed**

Run:
```bash
which xcodegen || brew install xcodegen
xcodegen --version
```
Expected: prints a version (≥ 2.38).

- [ ] **Step 1.2: Initialize git**

Run from the project root (`/Users/usamakhaki/Desktop/Practice/textify`):
```bash
git init
git add docs/
git commit -m "chore: seed repo with design spec and implementation plan"
```
Expected: commit succeeds with `docs/` contents.

- [ ] **Step 1.3: Write `.gitignore`**

Create `.gitignore` with this exact content:
```
# macOS
.DS_Store

# Xcode — generated project (regenerate with xcodegen)
Textify.xcodeproj/
*.xcworkspace/
xcuserdata/

# Build output
build/
DerivedData/
*.xcuserstate

# SwiftPM
.build/
Package.resolved

# Brainstorming scratch
.superpowers/
```

- [ ] **Step 1.4: Write `project.yml`**

Create `project.yml` with this exact content:
```yaml
name: Textify
options:
  bundleIdPrefix: com.textify
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    DEVELOPMENT_TEAM: ""
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"
    ENABLE_HARDENED_RUNTIME: NO

packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: "2.2.0"

targets:
  Textify:
    type: application
    platform: macOS
    sources:
      - Textify
    info:
      path: Textify/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: Textify
        CFBundleDisplayName: Textify
        NSHumanReadableCopyright: ""
    dependencies:
      - package: KeyboardShortcuts
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.textify.Textify
        GENERATE_INFOPLIST_FILE: NO

  TextifyTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - TextifyTests
    dependencies:
      - target: Textify
    settings:
      base:
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Textify.app/Contents/MacOS/Textify"
```

- [ ] **Step 1.5: Write `Textify/Info.plist`**

Create `Textify/Info.plist` with this exact content:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key>
  <string>$(CURRENT_PROJECT_VERSION)</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
```

- [ ] **Step 1.6: Write minimal `TextifyApp.swift` stub**

Create `Textify/TextifyApp.swift`:
```swift
import SwiftUI

@main
struct TextifyApp: App {
    var body: some Scene {
        MenuBarExtra("Textify", systemImage: "t.square") {
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
```

- [ ] **Step 1.7: Write empty asset catalogs**

Create `Textify/Assets.xcassets/Contents.json`:
```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

Create `Textify/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 1.8: Generate the Xcode project**

Run:
```bash
xcodegen generate
```
Expected: outputs `⚙️ Generated project successfully.` and creates `Textify.xcodeproj`.

- [ ] **Step 1.9: Build the empty app**

Run:
```bash
xcodebuild -project Textify.xcodeproj -scheme Textify -configuration Debug -destination 'platform=macOS' build | xcpretty || true
xcodebuild -project Textify.xcodeproj -scheme Textify -configuration Debug -destination 'platform=macOS' build
```
Expected: `** BUILD SUCCEEDED **` at the end.

> If `xcpretty` isn't installed, the second command (without pipe) is authoritative.

- [ ] **Step 1.10: Commit**

```bash
git add .gitignore project.yml Textify/
git commit -m "chore: bootstrap Textify Xcode project via xcodegen"
```

---

## Task 2: Core types and `RefinementProvider` protocol

**Files:**
- Create: `Textify/Core/RefinedTriple.swift`
- Create: `Textify/Core/ProviderError.swift`
- Create: `Textify/Core/ProviderKind.swift`
- Create: `Textify/Core/RefinementProvider.swift`
- Create: `TextifyTests/RefinedTripleTests.swift`

- [ ] **Step 2.1: Write the failing test**

Create `TextifyTests/RefinedTripleTests.swift`:
```swift
import XCTest
@testable import Textify

final class RefinedTripleTests: XCTestCase {
    func testDecodesFromJSON() throws {
        let json = #"{"casual":"hey","professional":"Hello","concise":"Hi"}"#
        let data = Data(json.utf8)
        let triple = try JSONDecoder().decode(RefinedTriple.self, from: data)
        XCTAssertEqual(triple.casual, "hey")
        XCTAssertEqual(triple.professional, "Hello")
        XCTAssertEqual(triple.concise, "Hi")
    }

    func testRejectsMissingField() {
        let json = #"{"casual":"hey","professional":"Hello"}"#
        let data = Data(json.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(RefinedTriple.self, from: data))
    }
}
```

- [ ] **Step 2.2: Regenerate project and verify test fails**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/RefinedTripleTests
```
Expected: compile error — `cannot find 'RefinedTriple' in scope`.

- [ ] **Step 2.3: Implement `RefinedTriple`**

Create `Textify/Core/RefinedTriple.swift`:
```swift
import Foundation

struct RefinedTriple: Codable, Equatable {
    let casual: String
    let professional: String
    let concise: String
}
```

- [ ] **Step 2.4: Implement `ProviderError`**

Create `Textify/Core/ProviderError.swift`:
```swift
import Foundation

enum ProviderError: LocalizedError, Equatable {
    case missingKey
    case network(String)
    case unauthorized
    case rateLimited
    case server(Int)
    case malformedResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingKey:        return "Add your API key in Settings"
        case .network(let msg):  return "Network error: \(msg)"
        case .unauthorized:      return "API key rejected. Update it in Settings."
        case .rateLimited:       return "Rate limit hit. Try again in a moment."
        case .server(let code):  return "Provider server error (\(code)). Try again."
        case .malformedResponse: return "Unexpected response. Please try again."
        case .timeout:           return "Request timed out. Check your connection."
        }
    }
}
```

- [ ] **Step 2.5: Implement `ProviderKind`**

Create `Textify/Core/ProviderKind.swift`:
```swift
import Foundation

enum ProviderKind: String, CaseIterable, Identifiable, Codable {
    case gemini
    case openai
    case groq

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .gemini: return "Gemini 2.0 Flash (free)"
        case .openai: return "OpenAI GPT-4o-mini"
        case .groq:   return "Groq Llama 3.3 70B (free)"
        }
    }
}
```

- [ ] **Step 2.6: Implement `RefinementProvider` protocol + shared prompt**

Create `Textify/Core/RefinementProvider.swift`:
```swift
import Foundation

protocol RefinementProvider {
    func refine(_ text: String) async throws -> RefinedTriple
}

enum RefinementPrompt {
    static let system: String = """
    You are a grammar and style assistant. The user will give you a message they wrote. \
    Fix all grammar and spelling errors, then produce three versions of the message in \
    different styles: casual (relaxed, friendly, contractions OK), professional \
    (polished, respectful, suitable for work), and concise (shortest clear version that \
    still conveys the meaning). Preserve the user's intent exactly. Do not add content, \
    do not answer questions, do not explain your changes. Respond only with JSON in the \
    exact format: {"casual": "...", "professional": "...", "concise": "..."}.
    """
}
```

- [ ] **Step 2.7: Run tests — they should pass**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/RefinedTripleTests
```
Expected: `Test Suite 'RefinedTripleTests' passed`.

- [ ] **Step 2.8: Commit**

```bash
git add Textify/Core/ TextifyTests/RefinedTripleTests.swift
git commit -m "feat(core): add RefinedTriple, ProviderError, ProviderKind, RefinementProvider"
```

---

## Task 3: MockURLProtocol (shared test helper)

This class is used by all three provider test files. Build it once.

**Files:**
- Create: `TextifyTests/MockURLProtocol.swift`

- [ ] **Step 3.1: Write `MockURLProtocol`**

Create `TextifyTests/MockURLProtocol.swift`:
```swift
import Foundation
import XCTest

/// URLProtocol stub that returns a canned response or error for each outgoing request.
/// Install it by creating a URLSession with URLSessionConfiguration.ephemeral and
/// adding MockURLProtocol.self to protocolClasses.
final class MockURLProtocol: URLProtocol {
    /// Handler inspects the request and returns either (HTTPURLResponse, Data) or throws.
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotLoadFromNetwork))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// Build a URLSession that routes all requests through this mock.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
```

- [ ] **Step 3.2: Regenerate and verify it builds**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' build-for-testing
```
Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 3.3: Commit**

```bash
git add TextifyTests/MockURLProtocol.swift
git commit -m "test: add MockURLProtocol for provider unit tests"
```

---

## Task 4: `KeychainStore`

**Files:**
- Create: `Textify/Services/KeychainStore.swift`
- Create: `TextifyTests/KeychainStoreTests.swift`

- [ ] **Step 4.1: Write failing tests**

Create `TextifyTests/KeychainStoreTests.swift`:
```swift
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
```

- [ ] **Step 4.2: Verify tests fail to compile**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/KeychainStoreTests
```
Expected: compile error — `cannot find 'KeychainStore' in scope`.

- [ ] **Step 4.3: Implement `KeychainStore`**

Create `Textify/Services/KeychainStore.swift`:
```swift
import Foundation
import Security

struct KeychainStore {
    let service: String

    init(service: String = "com.textify.apiKeys") {
        self.service = service
    }

    func save(_ value: String, for kind: ProviderKind) throws {
        let data = Data(value.utf8)
        let account = kind.rawValue
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.status(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.status(status)
        }
    }

    func load(for kind: ProviderKind) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.status(status)
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(for kind: ProviderKind) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.status(status)
        }
    }

    enum KeychainError: Error, Equatable { case status(OSStatus) }
}
```

- [ ] **Step 4.4: Run tests — verify pass**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/KeychainStoreTests
```
Expected: `Test Suite 'KeychainStoreTests' passed`.

- [ ] **Step 4.5: Commit**

```bash
git add Textify/Services/KeychainStore.swift TextifyTests/KeychainStoreTests.swift
git commit -m "feat(services): add KeychainStore for per-provider API keys"
```

---

## Task 5: `SettingsStore`

**Files:**
- Create: `Textify/Services/SettingsStore.swift`

`SettingsStore` is a thin wrapper around `UserDefaults` — no network, no I/O
failure modes. We verify it through manual use in the Settings UI rather
than writing unit tests (tests would essentially test `UserDefaults` itself).

- [ ] **Step 5.1: Implement `SettingsStore`**

Create `Textify/Services/SettingsStore.swift`:
```swift
import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults: UserDefaults
    private enum Keys {
        static let selectedProvider = "selectedProvider"
        static let closeAfterCopy = "closeAfterCopy"
        static let launchAtLogin = "launchAtLogin"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    @Published var selectedProvider: ProviderKind = {
        let raw = UserDefaults.standard.string(forKey: Keys.selectedProvider) ?? ProviderKind.gemini.rawValue
        return ProviderKind(rawValue: raw) ?? .gemini
    }() {
        didSet { defaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider) }
    }

    @Published var closeAfterCopy: Bool = UserDefaults.standard.object(forKey: Keys.closeAfterCopy) as? Bool ?? true {
        didSet { defaults.set(closeAfterCopy, forKey: Keys.closeAfterCopy) }
    }

    @Published var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: Keys.launchAtLogin) {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
}
```

- [ ] **Step 5.2: Verify it builds**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5.3: Commit**

```bash
git add Textify/Services/SettingsStore.swift
git commit -m "feat(services): add SettingsStore (UserDefaults-backed preferences)"
```

---

## Task 6: `GeminiProvider`

**Files:**
- Create: `Textify/Providers/GeminiProvider.swift`
- Create: `TextifyTests/GeminiProviderTests.swift`

- [ ] **Step 6.1: Write failing tests**

Create `TextifyTests/GeminiProviderTests.swift`:
```swift
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
```

- [ ] **Step 6.2: Verify tests fail to compile**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/GeminiProviderTests
```
Expected: compile error — `cannot find 'GeminiProvider' in scope`.

- [ ] **Step 6.3: Implement `GeminiProvider`**

Create `Textify/Providers/GeminiProvider.swift`:
```swift
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
```

- [ ] **Step 6.4: Run tests — verify pass**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/GeminiProviderTests
```
Expected: all tests in `GeminiProviderTests` pass.

- [ ] **Step 6.5: Commit**

```bash
git add Textify/Providers/GeminiProvider.swift TextifyTests/GeminiProviderTests.swift
git commit -m "feat(providers): add GeminiProvider with JSON-mode responses"
```

---

## Task 7: `OpenAIProvider`

**Files:**
- Create: `Textify/Providers/OpenAIProvider.swift`
- Create: `TextifyTests/OpenAIProviderTests.swift`

- [ ] **Step 7.1: Write failing tests**

Create `TextifyTests/OpenAIProviderTests.swift`:
```swift
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
```

- [ ] **Step 7.2: Verify tests fail to compile**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/OpenAIProviderTests
```
Expected: `cannot find 'OpenAIProvider' in scope`.

- [ ] **Step 7.3: Implement `OpenAIProvider`**

Create `Textify/Providers/OpenAIProvider.swift`:
```swift
import Foundation

final class OpenAIProvider: RefinementProvider {
    private let apiKey: String?
    private let session: URLSession
    private let model = "gpt-4o-mini"
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

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
```

- [ ] **Step 7.4: Run tests — verify pass**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/OpenAIProviderTests
```
Expected: all tests pass.

- [ ] **Step 7.5: Commit**

```bash
git add Textify/Providers/OpenAIProvider.swift TextifyTests/OpenAIProviderTests.swift
git commit -m "feat(providers): add OpenAIProvider with json_object response_format"
```

---

## Task 8: `GroqProvider`

**Files:**
- Create: `Textify/Providers/GroqProvider.swift`
- Create: `TextifyTests/GroqProviderTests.swift`

Groq is OpenAI-compatible (same request shape) but with a different endpoint
and default model. We implement it as a sibling of `OpenAIProvider` rather
than sharing code — the duplication is small and keeps each provider readable.

- [ ] **Step 8.1: Write failing tests**

Create `TextifyTests/GroqProviderTests.swift`:
```swift
import XCTest
@testable import Textify

final class GroqProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeProvider(apiKey: String? = "gsk_test") -> GroqProvider {
        GroqProvider(apiKey: apiKey, session: MockURLProtocol.makeSession())
    }

    func testSuccessfulRefinement() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.groq.com/openai/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer gsk_test")
            let inner = #"{\"casual\":\"yo\",\"professional\":\"Greetings.\",\"concise\":\"Hi.\"}"#
            let body = """
            {"choices":[{"message":{"content":"\(inner)"}}]}
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        let triple = try await makeProvider().refine("hi")
        XCTAssertEqual(triple, RefinedTriple(casual: "yo", professional: "Greetings.", concise: "Hi."))
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
}
```

- [ ] **Step 8.2: Verify tests fail to compile**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/GroqProviderTests
```
Expected: `cannot find 'GroqProvider' in scope`.

- [ ] **Step 8.3: Implement `GroqProvider`**

Create `Textify/Providers/GroqProvider.swift`:
```swift
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
```

- [ ] **Step 8.4: Run tests — verify pass**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/GroqProviderTests
```
Expected: all tests pass.

- [ ] **Step 8.5: Commit**

```bash
git add Textify/Providers/GroqProvider.swift TextifyTests/GroqProviderTests.swift
git commit -m "feat(providers): add GroqProvider (Llama 3.3 70B)"
```

---

## Task 9: `ClipboardService`

**Files:**
- Create: `Textify/Services/ClipboardService.swift`
- Create: `TextifyTests/ClipboardServiceTests.swift`

`NSPasteboard` is a singleton, but we can pass one in for testing
(`NSPasteboard.init(name:)` lets us create a named private pasteboard that
doesn't collide with the system clipboard).

- [ ] **Step 9.1: Write failing tests**

Create `TextifyTests/ClipboardServiceTests.swift`:
```swift
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
```

- [ ] **Step 9.2: Verify tests fail to compile**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/ClipboardServiceTests
```
Expected: `cannot find 'ClipboardService' in scope`.

- [ ] **Step 9.3: Implement `ClipboardService`**

Create `Textify/Services/ClipboardService.swift`:
```swift
import AppKit

final class ClipboardService {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Returns the clipboard text if present and not just whitespace, else nil.
    func readText() -> String? {
        guard let raw = pasteboard.string(forType: .string) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }

    /// Replace the pasteboard contents with the given string.
    func writeText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
```

- [ ] **Step 9.4: Run tests — verify pass**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/ClipboardServiceTests
```
Expected: all tests pass.

- [ ] **Step 9.5: Commit**

```bash
git add Textify/Services/ClipboardService.swift TextifyTests/ClipboardServiceTests.swift
git commit -m "feat(services): add ClipboardService (read/write NSPasteboard)"
```

---

## Task 10: `RefinementViewModel`

**Files:**
- Create: `Textify/ViewModel/RefinementViewModel.swift`
- Create: `TextifyTests/RefinementViewModelTests.swift`

- [ ] **Step 10.1: Write failing tests**

Create `TextifyTests/RefinementViewModelTests.swift`:
```swift
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
```

- [ ] **Step 10.2: Verify tests fail to compile**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/RefinementViewModelTests
```
Expected: `cannot find 'RefinementViewModel' in scope`.

- [ ] **Step 10.3: Implement `RefinementViewModel`**

Create `Textify/ViewModel/RefinementViewModel.swift`:
```swift
import Foundation
import SwiftUI

@MainActor
final class RefinementViewModel: ObservableObject {
    enum State: Equatable {
        case empty
        case loading
        case result(RefinedTriple)
        case error(ProviderError)
    }

    @Published var state: State
    @Published var original: String

    /// Callback invoked when the user picks a refined version (1/2/3 or click).
    /// Receives the chosen text; the caller is responsible for copying it and closing the window.
    var onPick: ((String) -> Void)?

    private let providerFactory: (ProviderKind) -> RefinementProvider
    private let providerKindResolver: () -> ProviderKind

    init(
        clipboardText: String?,
        providerKindResolver: @escaping () -> ProviderKind = { SettingsStore.shared.selectedProvider },
        providerFactory: @escaping (ProviderKind) -> RefinementProvider
    ) {
        self.providerFactory = providerFactory
        self.providerKindResolver = providerKindResolver
        if let text = clipboardText {
            self.original = text
            self.state = .loading
        } else {
            self.original = ""
            self.state = .empty
        }
    }

    /// Kick off refinement. If the current state is `.empty`, uses `original` (which the
    /// user may have typed in). Otherwise uses `original` as set from the clipboard.
    func refine() async {
        let text = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { state = .empty; return }
        state = .loading
        let kind = providerKindResolver()
        let provider = providerFactory(kind)
        do {
            let triple = try await provider.refine(text)
            state = .result(triple)
        } catch let e as ProviderError {
            state = .error(e)
        } catch {
            state = .error(.network(error.localizedDescription))
        }
    }

    func pick(_ option: Int) {
        guard case .result(let triple) = state else { return }
        let text: String
        switch option {
        case 1: text = triple.casual
        case 2: text = triple.professional
        case 3: text = triple.concise
        default: return
        }
        onPick?(text)
    }
}
```

- [ ] **Step 10.4: Run tests — verify pass**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test -only-testing:TextifyTests/RefinementViewModelTests
```
Expected: all tests pass.

- [ ] **Step 10.5: Commit**

```bash
git add Textify/ViewModel/RefinementViewModel.swift TextifyTests/RefinementViewModelTests.swift
git commit -m "feat(vm): add RefinementViewModel state machine"
```

---

## Task 11: `HotkeyService`

**Files:**
- Create: `Textify/Services/HotkeyService.swift`

This wraps the `KeyboardShortcuts` Swift package. The package handles the
macOS hotkey registration (Carbon APIs under the hood) — we just name a shortcut
and subscribe to its events. We do not add a unit test here: the logic is a
thin configuration of a third-party library, verified during manual testing
in Task 14.

- [ ] **Step 11.1: Implement `HotkeyService`**

Create `Textify/Services/HotkeyService.swift`:
```swift
import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let refineClipboard = Self("refineClipboard", default: .init(.t, modifiers: [.command, .shift]))
}

final class HotkeyService {
    /// Register an action to run each time the global hotkey fires.
    /// KeyboardShortcuts.onKeyUp delivers on the main thread.
    init(onTriggered: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .refineClipboard, action: onTriggered)
    }
}
```

- [ ] **Step 11.2: Verify it builds**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 11.3: Commit**

```bash
git add Textify/Services/HotkeyService.swift
git commit -m "feat(services): add HotkeyService for global ⌘⇧T"
```

---

## Task 12: UI — `RefinementWindow` and components

**Files:**
- Create: `Textify/Views/Components/OriginalTextBox.swift`
- Create: `Textify/Views/Components/RefinementCard.swift`
- Create: `Textify/Views/RefinementWindow.swift`

SwiftUI views are verified by building + manual check. We write no unit
tests for them — the `RefinementViewModel` has the logic coverage.

- [ ] **Step 12.1: Implement `OriginalTextBox`**

Create `Textify/Views/Components/OriginalTextBox.swift`:
```swift
import SwiftUI

struct OriginalTextBox: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ORIGINAL")
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 12.2: Implement `RefinementCard`**

Create `Textify/Views/Components/RefinementCard.swift`:
```swift
import SwiftUI

struct RefinementCard: View {
    let label: String
    let shortcut: String
    let text: String
    let onPick: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(label.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(shortcut)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 5)
                        .background(Color.primary.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.12)))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.primary)
                }
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(hovering ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
```

- [ ] **Step 12.3: Implement `RefinementWindow`**

Create `Textify/Views/RefinementWindow.swift`:
```swift
import SwiftUI

struct RefinementWindow: View {
    @ObservedObject var vm: RefinementViewModel
    @EnvironmentObject private var settings: SettingsStore
    var openSettings: () -> Void
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(width: 560, height: 440)
        .background(.background)
        .focusable()
        .onKeyPress(.escape) { close(); return .handled }
        .onKeyPress(.init("1")) { vm.pick(1); return .handled }
        .onKeyPress(.init("2")) { vm.pick(2); return .handled }
        .onKeyPress(.init("3")) { vm.pick(3); return .handled }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .empty:
            emptyView
        case .loading:
            OriginalTextBox(text: vm.original)
            loadingView
        case .result(let triple):
            OriginalTextBox(text: vm.original)
            resultsView(triple)
        case .error(let err):
            OriginalTextBox(text: vm.original.isEmpty ? "(no clipboard text)" : vm.original)
            errorView(err)
        }
        Spacer(minLength: 0)
        footer
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your message here")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextEditor(text: $vm.original)
                .font(.system(size: 13))
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12)))
            HStack {
                Spacer()
                Button("Refine") { Task { await vm.refine() } }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.original.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(ProgressView().controlSize(.small))
                    .frame(height: 68)
            }
        }
    }

    private func resultsView(_ t: RefinedTriple) -> some View {
        VStack(spacing: 8) {
            RefinementCard(label: "Casual",       shortcut: "1", text: t.casual)       { vm.pick(1) }
            RefinementCard(label: "Professional", shortcut: "2", text: t.professional) { vm.pick(2) }
            RefinementCard(label: "Concise",      shortcut: "3", text: t.concise)      { vm.pick(3) }
        }
    }

    private func errorView(_ err: ProviderError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(err.errorDescription ?? "Something went wrong")
                .foregroundStyle(.primary)
            HStack {
                switch err {
                case .missingKey, .unauthorized:
                    Button("Open Settings", action: openSettings).buttonStyle(.borderedProminent)
                case .network, .timeout, .rateLimited, .server, .malformedResponse:
                    Button("Retry") { Task { await vm.refine() } }.buttonStyle(.borderedProminent)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color.red.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Text("Press 1/2/3 to copy").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("Esc to close").font(.caption).foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 12.4: Build to verify the views compile**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 12.5: Commit**

```bash
git add Textify/Views/
git commit -m "feat(ui): add RefinementWindow + card/original-text components"
```

---

## Task 13: UI — `SettingsWindow`

**Files:**
- Create: `Textify/Views/SettingsWindow.swift`

- [ ] **Step 13.1: Implement `SettingsWindow`**

Create `Textify/Views/SettingsWindow.swift`:
```swift
import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsWindow: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            ProviderTab().tabItem { Label("AI Provider", systemImage: "cpu") }
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 380)
        .padding(20)
    }
}

private struct GeneralTab: View {
    @EnvironmentObject private var settings: SettingsStore
    var body: some View {
        Form {
            Section {
                Toggle("Close window after copy", isOn: $settings.closeAfterCopy)
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        applyLaunchAtLogin(newValue)
                    }
                ))
            }
            Section("Global hotkey") {
                KeyboardShortcuts.Recorder(for: .refineClipboard)
            }
        }
        .formStyle(.grouped)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else       { try SMAppService.mainApp.unregister() }
        } catch {
            // Surface silently for v1. User can retry via the toggle.
            NSLog("Launch-at-login toggle failed: \(error)")
        }
    }
}

private struct ProviderTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var keys: [ProviderKind: String] = [:]
    @State private var testMessage: String?
    @State private var testMessageIsError = false
    @State private var testing = false

    private let store = KeychainStore()

    var body: some View {
        Form {
            Picker("Provider", selection: $settings.selectedProvider) {
                ForEach(ProviderKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            Section("API key for \(settings.selectedProvider.displayName)") {
                SecureField("Paste your key", text: Binding(
                    get: { keys[settings.selectedProvider] ?? "" },
                    set: { keys[settings.selectedProvider] = $0 }
                ))
                HStack {
                    Button("Save") { save() }
                    Button("Test key") { Task { await test() } }
                        .disabled(testing || (keys[settings.selectedProvider]?.isEmpty ?? true))
                    if let msg = testMessage {
                        Text(msg).foregroundStyle(testMessageIsError ? .red : .green).font(.callout)
                    }
                }
            }
            if settings.selectedProvider == .gemini {
                Link("Get a free Gemini key →", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
            }
        }
        .formStyle(.grouped)
        .onAppear { loadKeyForCurrent() }
        .onChange(of: settings.selectedProvider) { _ in
            testMessage = nil
            loadKeyForCurrent()
        }
    }

    private func loadKeyForCurrent() {
        keys[settings.selectedProvider] = (try? store.load(for: settings.selectedProvider)) ?? ""
    }

    private func save() {
        let raw = keys[settings.selectedProvider] ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try store.delete(for: settings.selectedProvider)
            } else {
                try store.save(trimmed, for: settings.selectedProvider)
            }
            testMessage = "Saved."
            testMessageIsError = false
        } catch {
            testMessage = "Save failed: \(error.localizedDescription)"
            testMessageIsError = true
        }
    }

    private func test() async {
        save() // persist before testing
        testing = true
        defer { testing = false }
        let kind = settings.selectedProvider
        let key = (try? store.load(for: kind)) ?? ""
        let provider: RefinementProvider
        switch kind {
        case .gemini: provider = GeminiProvider(apiKey: key)
        case .openai: provider = OpenAIProvider(apiKey: key)
        case .groq:   provider = GroqProvider(apiKey: key)
        }
        do {
            _ = try await provider.refine("hello")
            testMessage = "Key works ✓"
            testMessageIsError = false
        } catch let e as ProviderError {
            testMessage = e.errorDescription
            testMessageIsError = true
        } catch {
            testMessage = error.localizedDescription
            testMessageIsError = true
        }
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Textify").font(.title2.bold())
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0")")
            Text("Grammar and style refinement at ⌘⇧T.").foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 13.2: Build to verify**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 13.3: Commit**

```bash
git add Textify/Views/SettingsWindow.swift
git commit -m "feat(ui): add Settings window with General/Provider/About tabs"
```

---

## Task 14: `AppCoordinator` and `TextifyApp` — wire everything together

**Files:**
- Create: `Textify/App/AppCoordinator.swift`
- Modify: `Textify/TextifyApp.swift` (replace the stub from Task 1)

- [ ] **Step 14.1: Implement `AppCoordinator`**

Create `Textify/App/AppCoordinator.swift`:
```swift
import SwiftUI
import AppKit

@MainActor
final class AppCoordinator: ObservableObject {
    let settings: SettingsStore
    private let clipboard = ClipboardService()
    private let keychain = KeychainStore()
    private var hotkey: HotkeyService?
    private var refinementWindow: NSWindow?

    init(settings: SettingsStore = .shared) {
        self.settings = settings
        self.hotkey = HotkeyService { [weak self] in self?.onHotkey() }
    }

    /// Menu-bar / hotkey entry point. Reads clipboard, opens a refinement window.
    func onHotkey() {
        let text = clipboard.readText()
        showRefinementWindow(initialText: text)
    }

    private func makeProvider(for kind: ProviderKind) -> RefinementProvider {
        let key = try? keychain.load(for: kind)
        switch kind {
        case .gemini: return GeminiProvider(apiKey: key)
        case .openai: return OpenAIProvider(apiKey: key)
        case .groq:   return GroqProvider(apiKey: key)
        }
    }

    func showRefinementWindow(initialText: String?) {
        // Close any existing window first so hot-pressing ⌘⇧T doesn't stack them.
        refinementWindow?.close()

        let vm = RefinementViewModel(
            clipboardText: initialText,
            providerKindResolver: { [settings] in settings.selectedProvider },
            providerFactory: { [weak self] kind in
                self?.makeProvider(for: kind) ?? GeminiProvider(apiKey: nil)
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.title = "Textify"

        vm.onPick = { [weak self, weak window] chosen in
            self?.clipboard.writeText(chosen)
            if self?.settings.closeAfterCopy ?? true {
                window?.close()
            }
        }

        let root = RefinementWindow(
            vm: vm,
            openSettings: { [weak self] in self?.openSettings() },
            close: { [weak window] in window?.close() }
        )
        .environmentObject(settings)

        let hosting = NSHostingController(rootView: root)
        window.contentViewController = hosting
        refinementWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Auto-kick refinement if we started from clipboard.
        if initialText != nil {
            Task { await vm.refine() }
        }
    }

    func openSettings() {
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 14.2: Replace `TextifyApp.swift` with full wiring**

Replace the contents of `Textify/TextifyApp.swift` with:
```swift
import SwiftUI

@main
struct TextifyApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        MenuBarExtra("Textify", systemImage: "t.square") {
            Button("Refine clipboard") { coordinator.onHotkey() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Settings…") { coordinator.openSettings() }
                .keyboardShortcut(",")
            Divider()
            Button("Quit Textify") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsWindow()
                .environmentObject(settings)
        }
    }
}
```

- [ ] **Step 14.3: Build**

```bash
xcodegen generate
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 14.4: Run the full test suite**

```bash
xcodebuild -project Textify.xcodeproj -scheme Textify -destination 'platform=macOS' test
```
Expected: all test suites pass (`RefinedTripleTests`, `KeychainStoreTests`, `GeminiProviderTests`, `OpenAIProviderTests`, `GroqProviderTests`, `ClipboardServiceTests`, `RefinementViewModelTests`).

- [ ] **Step 14.5: Commit**

```bash
git add Textify/App/AppCoordinator.swift Textify/TextifyApp.swift
git commit -m "feat(app): wire hotkey → coordinator → refinement window → clipboard"
```

---

## Task 15: Manual verification on a real Mac

This task is not TDD — it's the golden-path smoke test to confirm the app
actually works end-to-end. Run through the checklist; fix anything that
fails, re-run the failing step, then commit any fixes.

- [ ] **Step 15.1: Launch the app**

```bash
xcodebuild -project Textify.xcodeproj -scheme Textify -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
open build/Build/Products/Debug/Textify.app
```
Expected: a "T" icon appears in the menu bar. No Dock icon.

- [ ] **Step 15.2: Menu bar → Settings → paste Gemini API key**

1. Click the "T" menu-bar icon → Settings…
2. AI Provider tab → provider should default to "Gemini 2.0 Flash (free)".
3. Paste a real Gemini API key (obtained from https://aistudio.google.com/app/apikey).
4. Click Save → expect "Saved." in green.
5. Click Test key → within ~3s expect "Key works ✓" in green.

- [ ] **Step 15.3: Refine a real message**

1. Copy this text to your clipboard: `hey i wanted to checking if you free for meeting tomorrow at 3 pm to discus the project`
2. Press ⌘⇧T.
3. Expect the Refinement window to appear centered on screen.
4. Within ~3s, three cards should appear: Casual, Professional, Concise.
5. Each should be a grammatically correct version of the original.

- [ ] **Step 15.4: Test the 1/2/3 shortcuts**

1. With results showing, press `1`.
2. Window should close.
3. In any text field (e.g. Notes app), press ⌘V.
4. Expect the Casual version to paste.

- [ ] **Step 15.5: Test network-error path**

1. Turn off Wi-Fi (or briefly disable networking).
2. Copy some text, press ⌘⇧T.
3. Expect the error state showing a network message with a Retry button.
4. Turn Wi-Fi back on, click Retry.
5. Expect successful refinement.

- [ ] **Step 15.6: Test missing-key path**

1. Open Settings → AI Provider → switch to OpenAI (no key saved).
2. Copy text, press ⌘⇧T.
3. Expect "Add your OpenAI API key in Settings" error with "Open Settings" button.
4. Switch back to Gemini.

- [ ] **Step 15.7: Test empty clipboard path**

1. Clear the clipboard (copy something then delete, or paste from an image/file).
2. Press ⌘⇧T.
3. Expect the Empty state with a paste textarea and "Refine" button.
4. Type some text, click Refine (or ⌘↵) → three cards appear.

- [ ] **Step 15.8: Test dark mode / light mode**

1. System Settings → Appearance → toggle between Light and Dark.
2. With Textify open in each mode, confirm the window renders correctly
   (text legible, cards visible, no white-on-white).

- [ ] **Step 15.9: Test hotkey rebinding**

1. Open Settings → General → click the Global hotkey recorder.
2. Press ⌥⇧R.
3. Confirm old shortcut (⌘⇧T) no longer opens the window.
4. Press ⌥⇧R → window opens.
5. Rebind back to ⌘⇧T.

- [ ] **Step 15.10: Commit any fixes from manual testing**

```bash
git status
# If any files changed during troubleshooting:
git add <changed files>
git commit -m "fix: adjustments from manual verification"
```

Once all 15.1–15.9 pass, the v1 app is complete and ready for daily use.
Copy the `.app` bundle from `build/Build/Products/Debug/` to `~/Applications/`
for convenient launching, or add it to Login Items manually if you prefer
not to toggle Launch-at-login in the app.

---

## Done criteria

- [ ] All automated tests green.
- [ ] Steps 15.1–15.9 pass by hand.
- [ ] `git log` shows one commit per task.

## Not doing (out of scope per spec)

- Code signing / notarization.
- Auto-paste into the previous app.
- Streaming responses.
- History of past refinements.
- Custom user-defined styles.
- Mobile Expo version (separate project).

## Deferred from spec

- **One retry on transient failures (network drop / 5xx)** — the spec calls
  for this but we skip it in v1 to keep providers simple. Cleanest way to
  add later: a `RetryingProvider` decorator that wraps the underlying
  `RefinementProvider` in `AppCoordinator.makeProvider(for:)`. No provider
  code changes required.
