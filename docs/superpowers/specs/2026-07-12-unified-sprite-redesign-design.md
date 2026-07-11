# Unified Sprite Redesign

## Objective

Replace every bundled openNeko character sprite with a coherent, lively pixel-art system. The redesign must eliminate character-model drift between states, repair clipped and poorly masked frames, and make every animation read clearly at desktop-pet scale.

The approved direction is a full character redesign rather than a cleanup of the existing art. The concept reference is [`docs/assets/sprite-redesign/full-redesign-concept.png`](../../assets/sprite-redesign/full-redesign-concept.png). It is a visual reference only: its checkerboard is baked into the image and it must not be used directly as a production sprite.

## Scope

The bundled sprite set contains five skins:

- `default`: pearl-white fur
- `black`: graphite-black fur with cyan and restrained magenta accents
- `calico`: pearl, orange, and graphite patches
- `orange`: warm orange tabby fur
- `pink`: soft pink fur

Each skin will contain four frames for these 15 states:

`idle`, `hover`, `click`, `coding`, `typing`, `thinking`, `lunch`, `yawn`, `nap`, `success`, `error`, `dragging`, `walk`, `jump`, and `punch`.

The finished bundle therefore contains 300 production frames: 5 skins x 15 states x 4 frames. The existing global `sprites/effects/nyang_punch_*.png` character frames will be replaced by the selected skin's `punch` state so the attacking cat never changes appearance.

## Character Model

All states and skins share one canonical model:

- large rounded head and compact, short body
- consistent triangular ears, muzzle, eye shape, and cheek placement
- circular integrated headset with a cyan luminous ring and one restrained magenta accent
- small cyan collar core
- deep navy paws and tail tip
- one stable forehead marking whose color follows the skin palette
- readable silhouette at 128 x 128 without exaggerated bloom or soft rendering

The following measurements are locked across states unless the pose explicitly foreshortens them:

- head width and height
- eye spacing and muzzle center
- ear roots and headset centers
- torso length and paw size
- tail thickness and band positions
- collar-core size and placement

Skin variants may change fur color and markings only. They must not change anatomy, equipment geometry, pose, alignment, or alpha silhouette.

## Animation Choreography

Each state uses a deliberate four-frame cycle:

| State | Four-frame motion |
| --- | --- |
| `idle` | breathe, blink, tail-tip motion, settle |
| `hover` | ears rise, lean forward, eyes track, settle |
| `click` | startle, lift paw, react, recover |
| `coding` | panel lights, eye scan, panel pulse, settle |
| `typing` | left paw press, transition, right paw press, keyboard response |
| `thinking` | head tilt, tail sway, thought pixel, return |
| `lunch` | lift food, bite, chew, satisfied settle |
| `yawn` | eyes narrow, mouth opens, full yawn, recover |
| `nap` | settle down, breathe in, ear twitch, breathe out |
| `success` | brace, raise paws, joyful lift with sparkle, land |
| `error` | flinch, ears drop, error indicator, recover |
| `dragging` | dangle center, swing left, center stretch, swing right |
| `walk` | contact, passing, push-off, opposite passing |
| `jump` | crouch, rise, apex, landing preparation |
| `punch` | lower body, extend front paw, impact, retract |

Props and particles remain inside their frame cell and may not hide the face or destroy the body silhouette. Motion should be expressive through pose, ears, eyes, tail, and paws rather than by changing the character's proportions.

## Generation Strategy

### 1. Canonical master

Generate one high-quality identity sheet for the redesigned default cat. It records the front, side, and three-quarter model, palette, equipment, tail pattern, and proportion rules.

### 2. Default state sheets

Generate one transparent 2 x 2 sheet per state, always using the canonical master as the identity reference. Each cell contains one full-body frame with equal scale, consistent baseline, and at least 12 pixels of safe padding after extraction.

### 3. Skin transformations

Create black, calico, orange, and pink variants by editing the approved default state sheet with high input fidelity. Prompts may alter fur palette and markings only. The default sheet supplies the authoritative geometry and alpha silhouette.

### 4. Extraction

An extraction tool converts each approved sheet into four 128 x 128 RGBA PNG files using manifest-compatible names. It removes background contamination, trims isolated edge noise, aligns the subject to the state baseline, and writes frames only after validation.

### 5. Mask enforcement

For each state and frame index, the default frame defines the canonical silhouette. Variant frames are constrained to that silhouette, with a small controlled allowance for fur-pattern edge color but no geometry growth. This prevents ears, tails, props, or paws from changing shape between skins.

## Canvas And Alpha Rules

- Output is exactly 128 x 128 pixels, 8-bit RGBA PNG.
- Transparent pixels have zero RGB values to avoid matte fringes.
- No checkerboard, solid background, shadow plane, border, label, or watermark is allowed.
- Opaque or partially opaque pixels may not touch the canvas edge.
- Every pose keeps at least 12 pixels of safe padding unless a state-specific prop requires a documented exception.
- The body baseline may vary by no more than 2 pixels within a state.
- The face center may vary by no more than 2 pixels within a state unless the choreography explicitly moves the head.
- Body-area variation within a state may not exceed 8 percent unless the pose is `dragging` or `jump` and the exception is documented.
- Isolated alpha components smaller than the configured noise threshold are removed unless they are approved particles.

## Validation Pipeline

The validator checks all 300 frames and fails on:

- missing or extra manifest files
- incorrect dimensions, color type, or alpha channel
- nontransparent canvas background
- alpha touching any canvas edge
- unsafe padding or clipped ears, tail, paws, props, glow, or particles
- face-center or baseline jitter above tolerance
- unexpected silhouette mismatch between skin variants
- excessive body-scale change within one state
- isolated noise, white matte fringe, or baked checkerboard pixels
- duplicate frames where visible motion is required

It produces:

- a machine-readable validation report
- one contact sheet per skin showing all 60 frames
- one state comparison sheet showing all five skins for each state
- alpha-bound and alignment statistics

## Runtime Integration

The root manifest gains the `punch` state. `CatScene` loads punch frames from the active `Skin` instead of the global effect directory. Existing animation timing remains code-controlled, but each selected skin now keeps its own appearance through the complete punch sequence.

Existing imported skin packages that do not define `punch` remain loadable. At runtime, a missing or incomplete four-frame `punch` state falls back to that skin's `click` frames; newly generated packages use the updated 60-frame contract.

The replacement must preserve:

- current state names and four-frame timing contracts
- nearest-neighbor SpriteKit filtering
- transparent-window hit testing and click pass-through
- settings and onboarding sprite previews
- custom skin-package compatibility

The existing bundled sprites are preserved under `output/sprite-backups/<timestamp>` before replacement. That backup is outside the runtime resource path and is not packaged into the app.

## Verification

Completion requires all of the following evidence:

1. The manifest resolves exactly 60 frames for each of five skins.
2. The validator passes all 300 files with no edge-contact, alpha, alignment, or silhouette failures.
3. Contact sheets are visually reviewed for model consistency and animation readability.
4. `swift test` passes, including new manifest and sprite-quality tests.
5. The macOS app builds successfully.
6. The app is fully quit, rebuilt, and relaunched from the new product.
7. Runtime captures show every state for the default skin and representative full cycles for all variants.
8. The active skin remains visually consistent during the full three-hit punch sequence.

## Non-Goals

- changing application UI layout or animation timing unrelated to sprite readability
- redesigning the Codex pet
- changing user-imported custom skins
- increasing the runtime canvas beyond 128 x 128
- adding more bundled skins or more than four frames per state
