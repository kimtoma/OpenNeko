# Codex Pet Punch Sequence Design

## Goal

When OpenNeko sees the on-screen Codex pet, it should approach without animation stalls, stop at contact, face the pet, and perform three clearly visible full-body nyang punches before returning to idle.

## Confirmed Behavior

- Approach the Codex pet using the normal walk animation.
- Preserve the final approach direction for the entire punch sequence.
- Mirror the punch horizontally so every hit points toward the Codex pet.
- Stop movement at contact and perform three punches over 2.4-2.7 seconds.
- Suppress unrelated autonomous actions until the sequence finishes.
- Keep the generated full-body punch art, but normalize its displayed body size and floor line to the walk sprites.
- Keep detecting pets that do not expose a useful Codex window title by retaining pixel-based fallback detection.

## Architecture

### Detection

`ScreenPetPixelCaptureDetector` performs full-screen capture and pixel analysis on a dedicated serial background queue. `AppDelegate` starts at most one scan at a time and consumes the most recently completed candidate list on the main thread.

Once an encounter target is selected, the app locks that candidate through approach and punching. Background scans may revalidate and refresh that same target during approach, but cannot switch the encounter to a different pet. Scanning pauses for the punch sequence. Window metadata detection remains the inexpensive first choice.

### Encounter State

The encounter follows four explicit phases:

1. `searching`: periodically request a detector refresh and select the closest candidate.
2. `approaching`: walk toward the locked target while recording the target-facing direction.
3. `punching`: stop translation, hold the locked direction, play three punches, and block autonomous overrides.
4. `cooldown`: return to idle and delay another encounter with the same visible pet.

The pure timing and phase decisions live in `OpenNekoKit` so unit tests do not depend on AppKit windows or SpriteKit rendering.

### Punch Presentation

`CatScene` owns one full-body punch node. A single punch contains all four generated frames. The scene repeats that action three times with short recovery pauses, then restores the base sprite and idle animation once.

The punch node uses independent horizontal and vertical scale values. Horizontal sign handles direction, while vertical scale stays positive. No uniform `scale(to:)` action may overwrite the horizontal mirror. The generated art is displayed at 1.16 times its current size and shifted 12 points toward the window floor. These values compensate for the measured difference between the walk and punch alpha bounds; live capture verifies that the result meets the stable-size requirement.

## Failure Handling

- If generated punch textures are missing, use the existing click animation three times in the same direction.
- If the locked pet disappears during approach, abandon the encounter and resume idle behavior.
- If it disappears during the short punch sequence, finish the sequence rather than snapping back mid-hit.
- Detector failures leave the latest valid result untouched only for the current scan interval; stale targets are not retained across a completed empty scan.

## Verification

- Unit-test three-punch timing, interaction duration, cooldown, direction preservation, and normalized presentation scale/offset.
- Verify the detector never launches overlapping scans.
- Run the complete Swift test suite and Debug Xcode build.
- Fully quit and relaunch the newest Debug app.
- Use a visible Codex-like smoke target to confirm smooth approach, target-facing left/right mirroring, three distinct punches, stable body size, and a clean return to idle.
- Save a success screenshot showing the live punch interaction.

## Out Of Scope

- Changing the generated punch artwork itself.
- Reworking general autonomous behavior unrelated to screen-pet encounters.
- Removing peer-network pet behavior.
