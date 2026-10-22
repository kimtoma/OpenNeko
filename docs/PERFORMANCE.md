# Performance verification — 2026-09-06

This is a historical measurement snapshot from **before the sprite revisions**.
The intermediate 256px artwork increased the homepage's measured decoded resources to
994,447 bytes (20 entries), 13.8% above the original 873,716-byte baseline; offscreen
animation callbacks remain zero. The 63.3% reduction below describes the earlier
asset set. See [the 1024px pixel sprite report](SPRITES-PIXEL-1024-2026-09-06.md) for current assets,
validation, and the updated app archive.

The refactor is based on the latest published release, **v0.1.1** (`03c0745`),
plus the working checkout's existing sprite and screen-pet changes. Those local
changes were preserved. This work has not been published as a new release.

## What changed

- `CatScene` lazily retains textures for the current skin instead of rereading
  its PNGs on every drag update or state transition. Reapplying a skin clears
  both regular and punch textures, including cached missing-frame results.
- Autonomous movement and encounters retain their 60 Hz timing. Calendar and
  behavior decisions run at most every 250 ms; Dock preferences refresh at most
  once per second while display and visible-frame geometry stay live.
- Window enumeration runs on the utility scan queue. Screen geometry is
  captured on the main thread; scan-ticket cancellation and pixel-capture
  fidelity remain unchanged.
- The static homepage now has four languages, an interactive five-skin demo,
  keyboard navigation, motion controls, and responsive layouts. It uses local
  fonts, lazy images, cached decoded frames, and no animation work offscreen.

## Measured results

Tests ran on an arm64 Mac with macOS 27.0, Xcode 27 beta, and Swift 6.4.

| Measurement | Before | After |
| --- | ---: | ---: |
| 600 CPU-side drag scene updates, median of 7 samples, optimized build | 1,416.56 ms | 0.1344 ms |
| Calendar/behavior decisions during 600 simulated 60 Hz ticks | Up to 600 | 40 |
| Dock preference snapshots during those 600 ticks | Up to 600 | 10 |
| Homepage resource entries, excluding the HTML document | 55 | 20 |
| Decoded resource bytes, desktop page before demo interaction | 873,716 | 320,423 |
| Offscreen repeating animation callbacks | 74 in 1 second | 0 in 1.1 seconds |

The drag benchmark calls the real `CatScene.showDragging` with the same four
bundled PNG frames. It excludes GPU rendering, window compositing, and input
delivery; it is not an overall application speed multiplier. Cold initial
texture loading is still required. The original source fails the texture-reuse
regression check, while the new source passes.

Homepage measurements used headless Chrome, a 1440 × 1000 viewport, a local
static server, and a full-page scroll to load static imagery. No external font
or script requests occurred after the change. Additional skin frames load only
when selected. Resource bytes fell **63.3%** under these conditions.

Single-run native smoke observations were 137.84 → 139.31 MiB RSS and
6.39% → 7.98% CPU while resting. Startup-to-health was 1,594 → 539 ms. These
short, sequential observations are affected by caches and concurrent work and
do **not** establish a startup, idle CPU, or memory improvement.

## Validation

- Baseline: 269 Swift tests passed. Refactor: **278 tests passed**.
- Baseline and refactor: Release Xcode builds succeeded.
- Native integration: **10 checks passed** for each build: health, four state
  transitions, invalid-state rejection, PNG capture, typing activity, drag/drop,
  and health after interaction. Test settings/history/ports were isolated.
- Browser: **47 checks passed**, including four languages at 360/390/768/1440 px,
  language persistence, real skin changes, rapid selection, typing, pause,
  offscreen and simulated hidden-page events, clipboard, reduced motion,
  JavaScript-disabled downloads, and missing-resource/exception checks.
- An independent review of the changes found no actionable regressions.
  Physical display reconfiguration during an in-flight scan and the complete
  on-screen punch GPU sequence were not exercised by automation.

Preference changes can take up to one second to affect the estimated Dock
surface. New autonomous decisions can take up to 250 ms. Motion, landing,
mouse pass-through, and key-content privacy behavior are retained.

## Reproduce

Select an installed full Xcode for the command if Command Line Tools is the
system default; this does not require changing the machine's global selection.

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
swift test
xcodegen generate
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath /tmp/openneko-build CODE_SIGNING_ALLOWED=NO build
bash scripts/verify-cat-scene-cache.sh
python3 scripts/verify-native-runtime.py \
  /tmp/openneko-build/Build/Products/Release/OpenNeko.app \
  --output /tmp/openneko-runtime-qa
```

The texture benchmark accepts `--benchmark-only --scene-source <baseline/CatScene.swift>`
to compare against a preserved pre-change source using the same assets/toolchain.
Browser verification needs Python Playwright and Chromium (or installed Chrome):

```bash
python3 -m http.server 8000 --bind 127.0.0.1 --directory docs
# In another terminal:
python3 scripts/verify-homepage.py --url http://127.0.0.1:8000/ \
  --output /tmp/openneko-homepage-qa
```

Pass `--browser-executable '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'`
to use installed Chrome. The local evidence snapshot is in
`output/performance-20260906/`. A locally signed, non-notarized test app and ZIP
are in `dist/performance-20260906/`; existing installed applications were not
replaced, and public GitHub releases/Pages were not deployed.
