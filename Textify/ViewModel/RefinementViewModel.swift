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
        NSLog("[Textify] refine(): sending %d chars to provider — %@", text.count, text)
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
