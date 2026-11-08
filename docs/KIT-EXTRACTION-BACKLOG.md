# OpenNekoKit extraction backlog

Audit of decision logic still embedded in `App/` that belongs in
`Sources/OpenNekoKit/` with tests (see the layering rule in AGENTS.md).
Ranked by value × ease. Line numbers are as of 2026-07 — re-locate by
symbol name if they have drifted. Work through items top to bottom, one
extraction per PR, running `swift test` after each.

Already extracted (for pattern reference): state bridge HTTP parsing
(`StateBridgeHTTP.swift`), animation timing (`CatAnimationTiming`),
one-shot states (`NekoStatePriority.oneShotStates`),
`DailyBGMSelector.isStopCommand`, `AIProviderType.cliExecutableName`.

## 1. Menu bar copy table — easy, high value

`App/MenuBarController.swift` (`MenuCopy` enum + `localized(_:language:count:)`,
around lines 359–427): localized menu strings (Always on Top / Sound /
Chat History / Settings / Quit / Skills / neighbor wave with count) across
en/ko/ja/zh. Pure string mapping via `AppLanguage.normalized` — identical
pattern to the existing `SettingsCopy` / `NekoBubbleCopy` / `CatStateMenu`.

Plan: create `Sources/OpenNekoKit/State/MenuBarCopy.swift` mirroring
`SettingsCopy`'s shape, move the table verbatim, keep `MenuBarController`
calling it. Test all four languages per key like `NekoBubbleCopyTests`.
Localization invariant applies: never drop a language.

## 2. Built-in slash command descriptors — easy

`App/OpenNekoApp.swift` (`SlashDescriptionKey` + localization ~2125–2152,
built-in descriptor list ~2086–2114): names/kinds and localized one-line
descriptions of built-in slash commands (help/reset/skin/lang/sound).
`SlashCommandDescriptor`/`SlashCommandKind` already live in OpenNekoKit;
only skill descriptors need app state.

Plan: add `SlashCommandParser.builtinDescriptors(languageCode:) -> [SlashCommandDescriptor]`
in `Sources/OpenNekoKit/Skills/SlashCommand.swift`; app-side
`slashCommandCatalog()` concatenates the live skill descriptors.

## 3. WebSocket frame codec — medium, highest correctness value

`App/NeighborNetwork.swift`: `acceptKey` (~651), `headerValue` (~639),
`sendFrame` framing (~609–637), `popFrame` parser (~523–585). RFC 6455
mechanics: Sec-WebSocket-Accept (SHA1+magic+base64), header lookup,
frame encode (opcode/length/mask), frame decode (length forms 126/127,
mask XOR, opcode → text/ping/close). This is untested protocol code today.

Plan: `Sources/OpenNekoKit/Neighbors/WebSocketFrameCodec.swift`:
- `acceptKey(_:) -> String`, `headerValue(_:in:) -> String?`,
  `encode(opcode:payload:mask:) -> Data` — direct moves, easy.
- `popFrame` needs a refactor: it currently mutates the instance buffer and
  calls `close()` on oversize frames. Reshape to
  `decode(_ buffer: inout Data, maxBytes: Int) -> WebSocketFrameResult`
  with cases `.frame(opcode:payload:)/.needMoreData/.protocolError`, and let
  NeighborNetwork act on `.protocolError` by closing. Mask bytes must be
  injectable for deterministic encode tests.
Test vectors: RFC 6455 §5.7 examples ("Hello" masked/unmasked, 256-byte and
64KiB payloads for the 126/127 length forms).

## 4. Chat suggestion panel geometry — easy

`App/CatChatWindow.swift`: `currentSize` (~112–125) and
`suggestionListHeight` (~318–322) duplicate the same constants (row height
28, 2pt gap, paddings, base 64, width 320, max 6 rows); plus the
`visibleSuggestions` gating predicate (leading "/" and no whitespace).
Mirrors the existing `CatLayoutMetrics`.

Plan: `ChatSuggestionLayout` in OpenNekoKit (constants + 
`panelHeight(suggestionCount:)` + `clampedRows(_:)`), replacing both copies
so they cannot drift.

## 5. Slash argument interpreters (sound/lang) — medium

`App/OpenNekoApp.swift` `handleSlashCommand`: sound argument mapping
(~2052–2068: on/true/1/켜기 → on, off/false/0/끄기 → off, empty → toggle,
else invalid) and lang argument mapping (~2033–2051: system/auto/default →
follow system, else `AppLanguage.normalized`). Parsing is interleaved with
`showBubble` side effects.

Plan: decide-then-render. Add `SlashArgumentParser` to OpenNekoKit returning
enums (`.set(Bool)/.toggle/.invalid`, `.system/.language(String)/.invalid`);
the delegate switches on the result to do UI. Restructures early returns —
keep the bubble copy exactly as-is (it is localized).

## 6. PATH probing — medium

`App/OpenNekoApp.swift` `commandExists` (~1000–1010): splits the augmented
PATH (`ProcessPathEnvironment.augmentPath`) and checks candidates. Only the
final `isExecutableFile` is IO.

Plan: extend `ProcessPathEnvironment` with
`executableSearchPaths(path:) -> [String]` and
`commandExists(_:path:isExecutable:) -> Bool` taking an injected
`(String) -> Bool` probe (same injection style as `AppUpdateDecision`).

## 7. Git update string helpers — easy/medium

`App/GitUpdateController.swift`: `normalizedBranch` (~89–95; empty/HEAD →
main) is a pure move next to `AppUpdateDecision`. `repositoryRoot` (~64–82)
is a directory walk-up with an `OPENNEKO_UPDATE_ROOT` override — extract
with an injected `isRepo: (URL) -> Bool`.

## 8. Autonomous walk decisions — hard, do last

`App/OpenNekoApp.swift` `maybeStartAutonomousWalk` (~655–669), cooldown
randomization (~675–679), `scheduleNextAutoEffect` (~701–703): walk-start
probability 0.72, 2–5s duration, cooldown windows. Entangled with mutable
delegate state (`autonomousModeUntil`, `autonomousWalkUntil`, direction)
and timers. Needs a state struct + injected RNG draws to become a
`CatAutonomousBehavior.walkDecision(...)` returning new deadlines/direction.
Do not attempt as a quick fix.

## Blocked / not worth it

- `chatErrorMessage` (~2401–2413): pure error→message mapping but switches
  over `CodexChatError`/`HTTPChatError`/`AgentCLIChatError` which are
  defined in App (providers use Process/URLSession). Blocked until those
  error enums move to OpenNekoKit — which is reasonable, but is its own PR.
- Chat history caps (`suffix(12)`, `prefix(2000/6000)` around ~2171–2380):
  duplicated trivial caps; only extract if touching that code anyway.
- SF Symbol name maps in `MenuBarController` (~430–459): pure but AppKit
  iconography — leave in App.
- `SkinPackageService`, `AgentProcessMonitor`, `shellQuoted`, debug JSON
  builders: dominated by IO; real decisions already live in
  `SkinPackageSupport` / `AgentProcessDetector`.
