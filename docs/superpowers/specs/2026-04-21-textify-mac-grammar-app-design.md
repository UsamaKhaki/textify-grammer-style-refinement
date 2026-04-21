# Textify — Mac Grammar Refinement App

**Status:** Design approved 2026-04-21
**Platform:** macOS (Ventura / 13+)
**Language:** Swift 5.9+, SwiftUI

## Problem

The user writes chat messages that often contain grammar and spelling errors.
Their current workflow is to paste the draft into ChatGPT, ask for a refined
version, then copy the result back. This context switch is slow and repetitive.

## Goal

A background Mac app that turns the whole flow into a single keyboard shortcut:
copy the draft → press ⌘⇧T → pick one of three style-variant refinements →
paste it back into the chat app.

## Scope (v1)

**In scope**

- Global hotkey ⌘⇧T (rebindable) to invoke the app.
- Read clipboard, call an LLM, show three refined versions (Casual,
  Professional, Concise) in a floating window.
- Keyboard shortcuts (1/2/3) to copy a version and auto-close the window.
- Menu-bar presence (icon, Settings, Quit).
- Settings window: provider choice, per-provider API keys, launch-at-login.
- Three providers: **Gemini 2.0 Flash** (default, free),
  OpenAI GPT-4o-mini, Groq Llama 3.3 70B.
- API keys stored in macOS Keychain.
- Dark/light mode support.

**Out of scope (v1)**

- Custom style labels (v1 ships a fixed set of three: Casual / Professional /
  Concise).
- Auto-paste into the previous app (user pastes manually with ⌘V).
- Code signing / notarization for public distribution (personal build only).
- Streaming responses.
- History of past refinements.
- Mobile (Expo) version — separate project later, reuses concepts but not code.

## User Flow

```
1. User writes a chat message somewhere and copies it.
2. User presses ⌘⇧T.
3. Textify reads the clipboard:
   - If empty / non-text → open window with a paste textarea and "Refine" button.
   - If text → open window in Loading state, send text to the configured provider.
4. Provider returns three refined versions (one API call, JSON response).
5. Window shows three stacked cards:
      Casual [1]
      Professional [2]
      Concise [3]
   with the original text shown above them in a dimmed, collapsed box.
6. User presses 1, 2, or 3 (or clicks a card):
   - That version is written to the clipboard.
   - Window closes.
7. User pastes (⌘V) in the original chat app.
```

Total interaction time target: ≤ 3 seconds from ⌘⇧T to window showing results.

## Architecture

Native SwiftUI app. Single process. Runs in the background with a menu-bar
status item. No Dock icon.

### Components

| Component             | Responsibility                                                                         |
| --------------------- | -------------------------------------------------------------------------------------- |
| `MenuBarController`   | Owns the status-bar icon, its menu, and lifecycle.                                     |
| `HotkeyService`       | Registers the global hotkey via the `KeyboardShortcuts` Swift package. Fires on press. |
| `ClipboardService`    | Reads current clipboard text; writes the chosen refined version back.                  |
| `RefinementProvider`  | Protocol with `refine(text) async throws -> RefinedTriple`. Three implementations.     |
| `GeminiProvider`      | Calls Gemini 2.0 Flash `generateContent` endpoint with JSON response format.           |
| `OpenAIProvider`      | Calls OpenAI Chat Completions with `response_format: json_object`.                     |
| `GroqProvider`        | Calls Groq Chat Completions (OpenAI-compatible) with JSON mode.                        |
| `KeychainStore`       | Save / load / delete API keys in macOS Keychain.                                       |
| `SettingsStore`       | Non-secret preferences (selected provider, hotkey, launch-at-login).                   |
| `RefinementViewModel` | Drives the refinement window state machine (Empty / Loading / Result / Error).         |
| `RefinementWindow`    | SwiftUI view for the floating panel.                                                   |
| `SettingsWindow`      | SwiftUI settings scene, three tabs: General / AI Provider / About.                     |

### Data flow

```
⌘⇧T pressed
  → HotkeyService.fire
      → ClipboardService.read
          → if empty/non-text: show RefinementWindow in Empty state
          → if text: show RefinementWindow in Loading state
                     → RefinementViewModel.refine(text)
                        → provider = SettingsStore.selectedProvider
                        → provider.refine(text)
                           → returns RefinedTriple { casual, professional, concise }
                        → state = Result(triple)
          → user presses 1/2/3 → ClipboardService.write(selected) → window.close()
```

### Minimum macOS version

macOS 13 (Ventura) — covers ~95% of active Mac users and gives us modern
SwiftUI (`MenuBarExtra`, `Settings` scene, `.windowStyle(.hiddenTitleBar)`).

## UI

Chosen layout: **stacked vertical cards** (Variant A from the brainstorming
session).

### Refinement window

- Floating panel, ~560×420 px, centered on the active screen, not resizable,
  stays on top.
- Native macOS vibrancy background. SF Pro font. System colors.
- Title bar with the three standard window controls.

**States:**

| State   | Contents                                                                                                                                                                                                                                                          |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Empty   | A multi-line textarea labelled "Paste your message here". Primary button: "Refine" (⌘↵).                                                                                                                                                                          |
| Loading | Original text pinned at top in a dimmed read-only box. Below it, three shimmer placeholders for the cards.                                                                                                                                                        |
| Result  | Original text pinned at top (collapsible). Three cards stacked vertically, each showing: style label (uppercase, muted) + keyboard hint pill (1/2/3) in the header, refined text below, small copy icon on hover. Footer: `Press 1/2/3 to copy · Esc to close`. |
| Error   | Card-style error message with an appropriate action button (Open Settings / Retry / Paste key).                                                                                                                                                                   |

### Keyboard shortcuts inside the window

- `1` / `2` / `3` → copy that version, close window.
- `Esc` or `⌘W` → close without copying.
- `⌘,` → open Settings.
- `⌘↵` in Empty state → run refinement on textarea contents.

### Menu-bar icon

A monochrome "T" glyph. Click opens menu:

- Refine clipboard (⌘⇧T)
- Settings…
- Launch at login (toggle)
- Quit

### Settings window

Standard macOS Settings scene with three tabs:

1. **General**
   - Launch at login (toggle)
   - Global hotkey (default ⌘⇧T, rebindable)
   - Close window after copy (toggle, default on)

2. **AI Provider**
   - Provider picker: Gemini Flash / OpenAI / Groq
   - API key field per provider (each persisted separately in Keychain)
   - "Test key" button — sends a minimal request, shows ✓ / error inline
   - Link: "Get a free Gemini key →" opens https://aistudio.google.com

3. **About**
   - App name, version, a link, credits

## LLM Integration

### Prompt (shared across providers)

System message:

> You are a grammar and style assistant. The user will give you a message they
> wrote. Fix all grammar and spelling errors, then produce three versions of
> the message in different styles: **casual** (relaxed, friendly, contractions
> OK), **professional** (polished, respectful, suitable for work), and
> **concise** (shortest clear version that still conveys the meaning). Preserve
> the user's intent exactly. Do not add content, do not answer questions, do
> not explain your changes. Respond only with JSON in the exact format:
> `{"casual": "...", "professional": "...", "concise": "..."}`.

User message: the raw clipboard text, untransformed.

### Response contract

Every provider must return an object conforming to:

```swift
struct RefinedTriple: Decodable {
    let casual: String
    let professional: String
    let concise: String
}
```

All three providers support structured JSON output, which removes the need for
defensive parsing:

- Gemini: `generationConfig.responseMimeType = "application/json"` plus the
  schema.
- OpenAI: `response_format: { type: "json_object" }`.
- Groq: `response_format: { type: "json_object" }` (OpenAI-compatible).

### Networking

- `URLSession.shared` with a 20-second request timeout.
- One retry on transient failures (network drop, HTTP 5xx). No retry on 4xx.
- No streaming — wait for full JSON then render.

### Defaults and cost

| Provider      | Model                          | Cost per refinement        | Free tier                      |
| ------------- | ------------------------------ | -------------------------- | ------------------------------ |
| Gemini Flash  | `gemini-2.0-flash`             | $0                         | ~15 req/min, ~1,500 req/day    |
| OpenAI        | `gpt-4o-mini`                  | ~$0.0002                   | no (small trial credit only)   |
| Groq          | `llama-3.3-70b-versatile`      | $0                         | ~30 req/min                    |

Default provider: **Gemini Flash**. This is what the app uses out of the box;
the user only configures OpenAI or Groq if they want to switch.

## Error Handling

All provider / state errors surface in the Refinement window's Error state.
The error card shows a short message and a single actionable button.

| Condition                 | Message                                               | Action button            |
| ------------------------- | ----------------------------------------------------- | ------------------------ |
| No API key for provider   | "Add your &lt;Provider&gt; API key in Settings"       | Open Settings            |
| Network unreachable       | "Can't reach &lt;Provider&gt;. Check your connection" | Retry                    |
| 401 / invalid key         | "API key rejected. Update it in Settings."            | Open Settings            |
| 429 / rate limit          | "Rate limit hit. Try again in a moment."              | Retry                    |
| 5xx                       | "&lt;Provider&gt; had a server error. Try again."     | Retry                    |
| Malformed JSON            | "Unexpected response. Please try again."              | Retry                    |
| Empty/non-text clipboard  | (not an error — fall through to Empty state textarea) | —                        |

Settings-tab "Test key" surfaces the same error types inline, so the user can
debug before pressing ⌘⇧T for real.

## Security

- API keys live only in macOS Keychain, never in `UserDefaults` or plain files.
- No user text is logged anywhere — neither the original draft nor the refined
  versions.
- The only outbound network calls are to the configured provider's API host.
  No analytics, no telemetry in v1.

## Testing

### Unit tests (XCTest)

- Each provider: mock `URLSession`, verify
  - request URL, method, headers, body shape (including JSON-mode flags)
  - correct decoding of a valid response
  - proper error types for malformed JSON, 401, 429, 5xx, timeout
- `KeychainStore`: round-trip save / load / delete for each provider's key.
- `ClipboardService`: against a fake `NSPasteboard`, test the empty /
  non-text / text paths.
- `RefinementViewModel`: drive through Empty → Loading → Result and
  Empty → Loading → Error transitions with a stub provider.

### Manual verification checklist (run on a real Mac before shipping v1)

- [ ] Fresh install, no key set → ⌘⇧T → Error state with "Open Settings"
  button works.
- [ ] Paste Gemini key → "Test key" returns ✓ within 2s.
- [ ] Copy a grammatically broken message → ⌘⇧T → three cards appear within
  ~2s on Gemini Flash.
- [ ] Press `1` → clipboard contains the Casual version → window closed →
  paste into Messages app shows correct text.
- [ ] Turn off Wi-Fi → ⌘⇧T → network error with Retry; Retry after reconnect
  succeeds.
- [ ] Switch provider to OpenAI (with key) → refinement still works.
- [ ] Rebind hotkey in Settings to ⌥⇧R → old shortcut no longer fires, new one
  does.
- [ ] Toggle "Launch at login" off/on → confirm behavior after reboot.
- [ ] Dark mode and light mode both render correctly.

## Build & Distribution

- Xcode project, SwiftPM for the single third-party dependency
  (`sindresorhus/KeyboardShortcuts`).
- Debug builds run locally from Xcode.
- For personal use: unsigned `.app` exported via Archive → "Copy App".
- Code signing + notarization deferred until / unless the app is shared
  publicly.

## Open Questions (not blocking v1)

- If Gemini Flash's free quota becomes a real limit, consider caching identical
  inputs for a short window (likely unnecessary — refinements are rarely
  repeated).
- Whether to add a "custom style" option in v2 (e.g. user-defined "Slack to
  boss" style).
- Mobile Expo version: out of scope for this spec. Will live in a separate
  project and likely share only the prompt and provider concepts, not code.
