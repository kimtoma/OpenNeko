# openNeko sprite generation prompts

사용법:
1. 아래 상태별 프롬프트를 통째로 복사해 이미지 생성 (1:1 비율 권장, 가능하면 2048px 이상)
2. 결과를 `assets/gen/<상태이름>.png`로 저장 (예: `idle.png`, `hover.png`)
3. 11장 모이면 알려주기 → 마젠타 키잉으로 자동 추출해서 적용

체크리스트 (생성 결과 검수):
- [ ] 4프레임이 2×2 균등 사분면에 들어갔는가 (한 칸에 두 마리 X)
- [ ] 배경이 순수 마젠타 단색인가 (그라데이션/그림자/테두리 X)
- [ ] 글자/라벨/워터마크가 없는가
- [ ] 캐릭터 생김새(헤드폰·가슴 코어·귀 색)가 다른 상태와 일치하는가

---

## 공통 캐릭터 블록 (모든 프롬프트에 포함됨)

> cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink.

---

## 1. idle.png — 대기

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: IDLE loop — kitten sitting facing the viewer; frame 1 neutral, frame 2 ears perk and tail flicks, frame 3 eyes blink closed, frame 4 head tilts slightly. Differences between frames are small and natural. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 2. hover.png — 마우스 오버

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: HOVER reaction loop — kitten notices the mouse cursor; frame 1 looks up curiously, frame 2 head tilts with a small blue "?" mark floating above, frame 3 raises one paw toward the viewer, frame 4 happy expression with sparkles. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 3. click.png — 클릭 리액션

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: CLICKED surprise reaction — frame 1 startled with wide eyes and a yellow "!" above the head, frame 2 jumps up slightly with paws spread, frame 3 lands with a happy open-mouth smile, frame 4 cheerful with small sparkle burst. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 4. coding.png — 코딩 중 (에이전트가 일하는 걸 "지켜보는" 포즈 — typing과 확실히 구분)

> 변경 사유: 기존 coding은 키보드 타이핑이라 typing(유저 타이핑)과 너무 비슷했음.
> 새 컨셉 = "AI 에이전트가 코딩하는 걸 고양이가 지켜본다" → **키보드 없음**, 큰 홀로그램 코드 화면을 올려다보는 감독/관전 포즈.

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: WATCHING-THE-CODE loop (the kitten supervises an AI agent that codes, it is NOT typing itself) — kitten sitting back relaxed, paws resting on its lap or one paw raised, with NO keyboard at all, looking UP at a large translucent holographic blue code screen floating in front of it filled with scrolling glowing code lines (abstract glowing bars, not real letters); frame 1 watching calmly, frame 2 code lines scroll upward and ears perk up, frame 3 a small approving nod with a blink, frame 4 a tiny blue sparkle pops as a line finishes. Calm focused supervising expression, eyes on the floating screen. Important: absolutely no keyboard, paws are not typing. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no readable text, no labels, no watermark.

## 5. typing.png — 타이핑

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: TYPING loop — kitten hunched over a glowing blue keyboard, paws drumming quickly; frame 1 left paw down, frame 2 right paw down, frame 3 both paws up, frame 4 fast typing blur with tiny motion lines, focused expression. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 6. thinking.png — 생각 중

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: THINKING loop — kitten sits with one paw on its chin looking up; a small blue thought bubble with three dots floats above its head, the dots fill in one by one across the 4 frames like a loading indicator; thoughtful tilted head. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 7. lunch.png — 점심

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: LUNCH loop — kitten happily eating noodles from a brown bowl with chopsticks; frame 1 picks up noodles, frame 2 slurps with closed happy eyes, frame 3 chews with puffed cheeks, frame 4 satisfied smile with a tiny heart. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 8. yawn.png — 하품/스트레칭

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: YAWN sequence — frame 1 sleepy half-closed eyes, frame 2 stretches both front paws up high, frame 3 big wide yawn with eyes squeezed shut and open pink mouth, frame 4 relaxed content face with a small tear drop near one eye. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 9. nap.png — 낮잠

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: NAP loop — kitten curled up asleep on a round blue cushion, eyes closed; blue "Z z z" symbols float up above it, rising slightly higher each frame; body gently rises and falls with breathing across frames. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no other text besides the Zzz symbols, no labels, no watermark.

## 10. success.png — 성공

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink plus gold sparkles. Animation: SUCCESS celebration — frame 1 raises both paws up cheering with open-mouth smile, frame 2 jumps in the air with golden star sparkles around, frame 3 happy spin with closed-eye grin and confetti, frame 4 lands with a proud pose and sparkles fading. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 11. error.png — 에러

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink plus red accents. Animation: ERROR reaction — frame 1 worried face with a small red "X" mark floating beside its head, frame 2 flinches with ears folded back and tiny red sparks, frame 3 dizzy with swirly eyes and head tilted, frame 4 apologetic droopy ears with a sweat drop. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 12. dragging.png — 드래그 (커서에 대롱대롱)

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Animation: DANGLING swing loop — the kitten is pinched and suspended in mid-air from a single point at the very top of its scruff, body hanging below that point and stretched soft like mochi, swinging side to side like a pendulum as if being dragged around by a mouse cursor: frame 1 hangs straight down, body elongated, paws dangling, surprised round eyes; frame 2 whole body swings to the LEFT, body curving like a comma with the lower half trailing behind, tail flying out to the right, ears folded back; frame 3 passes back through center with the body stretched at its longest, squished pouty face; frame 4 whole body swings to the RIGHT, body curving the other way, tail flying out to the left. The top scruff point stays at the same position in all 4 frames so the swing pivots around it. The kitten must hang in mid-air in every frame, never touching the ground; no hand, no arm, no cursor drawn in the image. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 13. walk.png — 사뿐사뿐 걷기 (옆모습, 오른쪽 방향)

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. IMPORTANT: shown in SIDE PROFILE, facing and walking toward the RIGHT, the exact same right-facing side view in all 4 frames (do not rotate or face the viewer). Animation: WALK cycle — a light, dainty, graceful tip-toe trot ("walking softly and lightly"), tail held up in a gentle curve, ears up, calm content smile, with a small springy up-and-down bounce. Frame 1 contact pose: front leg reaching forward and touching down, rear leg pushing back behind, body slightly lowered. Frame 2 passing pose: all four legs gathered under the body, body lifted at the top of a little bounce, tail flicking up. Frame 3 opposite contact pose: the other legs now reaching forward / pushing back, body slightly lowered again. Frame 4 passing pose: legs gathered, gentle bounce, tail curving the other way. Keep the feet near the bottom of each quadrant and the body the same size in every frame so the walk reads as smooth. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

## 14. jump.png — 점프 (정면)

Pixel art animation sprite sheet: exactly 4 frames arranged in a 2x2 grid of equal quadrants, frame order top-left, top-right, bottom-left, bottom-right. Subject: cute chibi white robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten, large sparkly blue eyes, pink inner ears with dark tips, sky-blue glowing glowing headphones over its ears, small glowing blue core gem on its chest, soft white body with pale-blue robotic limb accents, tiny smile. Clean crisp retro pixel art style (like 64x64 game sprites scaled up), bold dark outlines, limited palette of white / sky blue / navy / pink. Facing the viewer (front view). Animation: a single happy JUMP in place, conveyed by POSE only (each frame should be drawn centered and the same overall size). Frame 1 anticipation crouch: kitten squashes down low and wide, legs bent, ears tipped slightly back, eager excited eyes (squash). Frame 2 launch: springs upward, body stretched tall and narrow, front paws tucked up, back legs extended pushing off, open-mouth "yay" smile, a tiny puff of dust at the feet (stretch). Frame 3 airborne peak: rounded compact body with all four paws tucked in, ears up, bright happy closed-eye grin, one or two small sparkles around it (float). Frame 4 landing: a soft squash-and-stretch landing, body low and wide again, paws spread to catch, content smile, small impact puff at the feet. Keep the kitten horizontally centered. Background: every pixel of the background must be flat solid magenta, uniform, no gradient, no shadows on background, no panel borders, no grid lines, no text, no labels, no watermark.

---

## 스킨 변형

각 스킨은 위의 상태별 프롬프트에서 **'공통 캐릭터 블록'(Subject: 부분)만 아래 해당 스킨 블록으로 교체**해서 생성한다. 구도·상태·2×2 그리드·마젠타 배경·Animation 설명은 그대로 유지.

저장 위치: `assets/gen/<skin>/<state>.png` (예: `assets/gen/black/idle.png`)
추출: `python3 tools/extract_gen.py <skin>` (예: `python3 tools/extract_gen.py black`)

생성 전까지는 해당 스킨의 모든 프레임이 화이트(기본)로 표시됨 — 앱이 깨지지 않음.

---

### black (블랙)

`cute chibi BLACK robot kitten desktop pet ("openNeko robot kitten") — round charcoal-black chibi kitten, large glowing cyan eyes, dark-pink inner ears, glowing cyan glowing headphones, violet glowing core gem on chest, charcoal body with neon cyan/violet robotic limb accents, tiny smile. Clean crisp retro pixel art, bold dark outlines, limited palette of charcoal black / cyan / violet / white.`

---

### orange (오렌지 태비)

`cute chibi ORANGE TABBY robot kitten desktop pet ("openNeko robot kitten") — round orange tabby chibi kitten with darker orange stripes and cream muzzle/belly, large amber eyes, pink inner ears, warm amber glowing glowing headphones, amber glowing core gem on chest, warm-toned robotic limb accents, tiny smile. Clean crisp retro pixel art, bold dark outlines, limited palette of orange / amber / cream / dark brown.`

---

### pink (핑크)

`cute chibi PINK robot kitten desktop pet ("openNeko robot kitten") — round soft-pink and cream chibi kitten, large sparkly magenta eyes, deep-pink inner ears, pastel-pink glowing glowing headphones, heart-pink glowing core gem on chest, pastel lavender/pink robotic limb accents, tiny smile. Clean crisp retro pixel art, bold dark outlines, limited palette of pink / cream / lavender / white.`

---

### calico (칼리코)

`cute chibi CALICO (tricolor) robot kitten desktop pet ("openNeko robot kitten") — round white chibi kitten with orange and black calico patches, large green eyes, pink inner ears, mint-green glowing glowing headphones, amber glowing core gem on chest, mixed robotic limb accents, tiny smile. Clean crisp retro pixel art, bold dark outlines, limited palette of white / orange / black / pink / mint.`
