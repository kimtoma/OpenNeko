# CLAUDE.md

@AGENTS.md

## Claude Code specific notes

- **Remote/Linux sessions cannot build or run this app.** The toolchain
  (Swift, XcodeGen, xcodebuild) is macOS-only here. In a cloud session,
  verify by reading code and reasoning against the tests, push, and let CI
  (`.github/workflows/ci.yml`) be the ground truth. State clearly in the PR
  when a change was not locally built.
- On a macOS machine, the verification loop is:
  `swift test` → `xcodegen generate` → `xcodebuild ... build` (see AGENTS.md
  for the exact command). Run `swift test` before every commit.

## Working style expected in this repo

1. **Plan before editing.** For anything beyond a trivial fix, write the plan
   first (files to touch, tests to add, invariants at risk from the
   "Invariants" section of AGENTS.md), then implement it.
2. **Logic goes to OpenNekoKit with a test.** New decision logic belongs in
   `Sources/OpenNekoKit/` with a matching file in `Tests/OpenNekoKitTests/`.
   A change that only touches `App/` and contains branching logic is a smell.
3. **Small diffs, one topic per PR.** Do not reformat or refactor code you
   are not changing.
4. **Localization discipline.** Any user-visible string change touches the
   en/ko/ja/zh copy tables together, and README changes touch all four
   README files together.
5. **When uncertain, mirror existing patterns.** Find the closest existing
   feature (e.g. an existing state bridge route, an existing provider preset,
   an existing settings pane) and copy its structure, including its test
   structure.
