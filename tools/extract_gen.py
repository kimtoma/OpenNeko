#!/usr/bin/env python3
"""assets/gen/<state>.png (2x2 그리드, 마젠타 배경) → 상태별 프레임 추출.

크기 균일화: 프레임 bbox가 아니라 "고양이 본체(최대 연결 성분)의 픽셀 면적"을
기준으로 전 상태에 공통 스케일을 적용한다. 소품(홀로 패널, 방석, 반짝이)이
큰 상태에서 고양이만 작아지는 문제를 막는다.

사용법:
  python3 tools/extract_gen.py            # 화이트(기본) — assets/gen/*.png → src/renderer/sprites/*.png
  python3 tools/extract_gen.py black      # 스킨 지정 — assets/gen/black/*.png → src/renderer/sprites/black/*.png
  python3 tools/extract_gen.py orange     # 오렌지 태비 스킨
  python3 tools/extract_gen.py pink       # 핑크 스킨
  python3 tools/extract_gen.py calico     # 칼리코 스킨

스킨 지정 시 manifest.json은 재생성하지 않음(화이트와 동일한 상태/프레임 목록 공유).

출력: src/renderer/sprites/<state>_<n>.png + manifest.json (화이트 기본)
      src/renderer/sprites/<skin>/<state>_<n>.png (스킨 지정 시)
"""
import sys
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent

# 스킨 인자 처리: 없으면 white(루트), 있으면 해당 스킨 하위폴더
SKIN = sys.argv[1].strip() if len(sys.argv) > 1 else None
GEN = ROOT / "assets/gen" / SKIN if SKIN else ROOT / "assets/gen"
OUT = ROOT / "src/renderer/sprites" / SKIN if SKIN else ROOT / "src/renderer/sprites"
OUT.mkdir(parents=True, exist_ok=True)

STATES = ["idle", "hover", "click", "coding", "typing", "thinking",
          "lunch", "yawn", "nap", "success", "error", "dragging",
          "walk", "jump"]
TOP_ALIGN = {"dragging"}  # 핀치 포인트가 위 — 위 정렬해야 커서 부착점이 일정하다

FRAME = 128
SPRITE_BOX = 118
MAX_DIM = 126        # 캔버스 안 최대 허용 변 (이상이면 그 상태만 개별 축소)
KEY_TOL = 70

# 1패스: 사분면별 RGBA 크롭 + 본체 면적/최대 변 수집 -------------------------------

def cut_quadrant(q):
    corners = np.array([q[2, 2], q[2, -3], q[-3, 2], q[-3, -3]])
    bgc = np.median(corners, axis=0)
    dist = np.sqrt(((q - bgc) ** 2).sum(axis=2))
    bg = dist < KEY_TOL

    border = np.zeros_like(bg)
    border[0, :] = border[-1, :] = True
    border[:, 0] = border[:, -1] = True
    lbl, _ = ndimage.label(bg)
    bg_conn = np.zeros_like(bg)
    for l in np.unique(lbl[bg & border]):
        if l > 0:
            bg_conn |= lbl == l

    solid = ~bg_conn
    solid = ndimage.binary_erosion(solid, iterations=1, border_value=0)
    if not solid.any():
        return None

    # 본체 = 최대 연결 성분 (떠 있는 소품/장식 제외)
    lbl2, n2 = ndimage.label(solid)
    sizes = ndimage.sum(solid, lbl2, range(1, n2 + 1))
    main_area = float(sizes.max())

    alpha_f = ndimage.gaussian_filter(solid.astype(np.float32), 0.6)
    alpha = (np.clip((alpha_f - 0.25) / 0.5, 0, 1) * 255).astype(np.uint8)

    ys, xs = np.where(solid)
    pad = 4
    y0, y1 = max(0, ys.min() - pad), min(q.shape[0], ys.max() + pad)
    x0, x1 = max(0, xs.min() - pad), min(q.shape[1], xs.max() + pad)
    rgba = np.dstack([q[y0:y1, x0:x1].astype(np.uint8), alpha[y0:y1, x0:x1]])
    sprite = Image.fromarray(rgba, "RGBA")
    return sprite, main_area, max(sprite.size)


collected = {}
for state in STATES:
    src = GEN / f"{state}.png"
    if not src.exists():
        print(f"{state}: 파일 없음, 건너뜀")
        continue
    img = np.asarray(Image.open(src).convert("RGB")).astype(np.int32)
    H, W = img.shape[:2]
    qh, qw = H // 2, W // 2
    quads = [img[:qh, :qw], img[:qh, qw:], img[qh:, :qw], img[qh:, qw:]]
    items = [r for r in (cut_quadrant(q) for q in quads) if r]
    if items:
        collected[state] = items

# 2패스: 본체 면적 기준 공통 스케일 산출 ------------------------------------------
# scale_s = sqrt(TARGET_AREA / state_area) → 모든 상태의 "고양이 질량"이 같아진다

state_area = {s: float(np.median([a for _, a, _ in items])) for s, items in collected.items()}
# 특수 포즈(드래그=세로로 김, walk=옆으로 넓음, jump=쭉 뻗음)는 기본 상태들의 크기를
# 흔들면 안 되므로 기준 면적/베이스 계산에서 빼고, 각자 rel*base로 맞춘 뒤 넘치면 개별 축소.
SPECIAL = {"dragging", "walk", "jump", "coding"}  # coding=홀로 코드화면 소품이 커서 본체 기준 정규화(키보드 X 새 포즈)
area_states = [s for s in state_area if s not in {"walk", "jump"}]  # 기존 상태 크기 보존
target_area = float(np.median([state_area[s] for s in area_states]))
rel = {s: (target_area / a) ** 0.5 for s, a in state_area.items()}

base_states = [s for s in collected if s not in SPECIAL] or list(collected)
base = min(SPRITE_BOX / (max(d for _, _, d in collected[s]) * rel[s]) for s in base_states)

manifest = {}
for state, items in collected.items():
    scale = rel[state] * base
    # 캔버스를 넘는 상태(주로 dragging)만 개별 축소
    dim = max(d for _, _, d in items) * scale
    if dim > MAX_DIM:
        scale *= MAX_DIM / dim
    frames = []
    for sprite, _a, _d in items:
        w, h = sprite.size
        sprite = sprite.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
        canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        py = 2 if state in TOP_ALIGN else FRAME - sprite.height - 2
        canvas.paste(sprite, ((FRAME - sprite.width) // 2, py))
        name = f"{state}_{len(frames)}.png"
        canvas.save(OUT / name)
        frames.append(name)
    manifest[state] = frames
    print(f"{state}: {len(frames)} frames, scale {scale:.3f} (rel {rel[state]:.2f})")

if not SKIN:
    # manifest는 화이트(루트)에서만 생성 — 모든 스킨이 동일한 상태/프레임 목록을 공유
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("→", OUT)
else:
    print(f"→ {OUT} (스킨: {SKIN}, manifest 재생성 안 함 — 화이트와 공유)")
