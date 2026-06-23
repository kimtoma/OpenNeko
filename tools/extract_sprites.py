#!/usr/bin/env python3
"""전뇌고양이 스프라이트 시트(assets/sprites/source.png)에서 상태별 프레임 추출.

각 상태 패널은 라벨(상단) + 가로로 균등한 4프레임 구성이므로:
1) 패널에서 라벨 띠를 잘라내고 콘텐츠를 4등분 컬럼으로 분할
2) 컬럼마다 가장 큰 밝은 성분 + 그 주변 장식을 묶어 bbox 결정
3) 외곽 연결 어두운 배경만 플러드필 제거 → RGBA, 128x128 정규화

출력: src/renderer/sprites/<state>_<n>.png + manifest.json
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/sprites/source.png"
OUT = ROOT / "src/renderer/sprites"
OUT.mkdir(parents=True, exist_ok=True)

PANELS = {
    "idle":     (0.012, 0.205, 0.328, 0.385),
    "hover":    (0.330, 0.205, 0.642, 0.385),
    "click":    (0.644, 0.205, 0.992, 0.385),
    "coding":   (0.012, 0.390, 0.328, 0.570),
    "typing":   (0.330, 0.390, 0.642, 0.570),
    "thinking": (0.644, 0.390, 0.992, 0.570),
    "lunch":    (0.012, 0.575, 0.328, 0.755),
    "yawn":     (0.330, 0.575, 0.642, 0.755),
    "nap":      (0.644, 0.575, 0.992, 0.755),
    "success":  (0.012, 0.760, 0.328, 0.965),
    "error":    (0.330, 0.760, 0.585, 0.965),
}
COLS = {"error": 3}  # EXTRA ASSETS 패널과 붙어 있어 3프레임만


LABEL_CUT = 0.24     # 패널 상단 라벨 띠 비율
FRAME = 128
SPRITE_BOX = 118
BG_LUM = 60
MIN_COMP = 250       # 장식 최소 면적
NEAR = 22            # 본체 bbox에 이만큼 근접한 장식은 포함

img = Image.open(SRC).convert("RGB")
W, H = img.size
arr = np.asarray(img).astype(np.int32)
lum = arr @ [299, 587, 114] // 1000

manifest = {}
for state, (rx0, ry0, rx1, ry1) in PANELS.items():
    px0, py0, px1, py1 = int(rx0 * W), int(ry0 * H), int(rx1 * W), int(ry1 * H)
    cy0 = py0 + int((py1 - py0) * LABEL_CUT)
    ncols = COLS.get(state, 4)
    colw = (px1 - px0) / ncols

    crops = []
    for ci in range(ncols):
        x0 = px0 + int(ci * colw)
        x1 = px0 + int((ci + 1) * colw)
        col = arr[cy0:py1, x0:x1]
        clum = lum[cy0:py1, x0:x1]

        mask = clum > BG_LUM
        labels, n = ndimage.label(ndimage.binary_dilation(mask, iterations=2))
        comps = []
        for i in range(1, n + 1):
            ys, xs = np.where(labels == i)
            if len(ys) < MIN_COMP:
                continue
            comps.append([xs.min(), xs.max(), ys.min(), ys.max(), len(ys)])
        if not comps:
            continue
        main = max(comps, key=lambda c: c[4])
        bx0, bx1, by0, by1 = main[:4]
        # 본체 근처 장식 병합 (반짝이, ?, !, Zzz…)
        for c in comps:
            if c is main:
                continue
            if (c[0] < bx1 + NEAR and c[1] > bx0 - NEAR and
                    c[2] < by1 + NEAR and c[3] > by0 - NEAR):
                bx0, bx1 = min(bx0, c[0]), max(bx1, c[1])
                by0, by1 = min(by0, c[2]), max(by1, c[3])

        pad = 3
        fx0, fy0 = max(0, bx0 - pad), max(0, by0 - pad)
        fx1, fy1 = min(col.shape[1], bx1 + pad), min(col.shape[0], by1 + pad)
        crop = col[fy0:fy1, fx0:fx1]
        flum = clum[fy0:fy1, fx0:fx1]

        # 외곽 연결 어두운 배경만 제거
        bg = flum < BG_LUM
        border = np.zeros_like(bg)
        border[0, :] = border[-1, :] = True
        border[:, 0] = border[:, -1] = True
        lbl, _ = ndimage.label(bg)
        bg_conn = np.zeros_like(bg)
        for l in np.unique(lbl[bg & border]):
            if l > 0:
                bg_conn |= lbl == l

        # 고양이의 어두운 로봇 파츠는 배경 네이비와 색이 거의 같아 플러드필에
        # 같이 갉아먹힌다 → closing으로 물린 자리를 복원 (메워진 픽셀은 원본
        # 네이비가 드러나 어두운 파츠처럼 보인다)
        solid = ~bg_conn
        solid = ndimage.binary_closing(solid, structure=np.ones((3, 3), bool), iterations=4)
        # 가장자리 정리: 배경과 닿은 1px 블렌딩 링을 깎고 알파를 살짝 부드럽게
        solid = ndimage.binary_erosion(solid, iterations=1, border_value=0)
        alpha = ndimage.gaussian_filter(solid.astype(np.float32), 0.6)
        alpha = np.clip((alpha - 0.25) / 0.5, 0, 1)
        alpha = (alpha * 255).astype(np.uint8)

        crops.append(Image.fromarray(np.dstack([crop.astype(np.uint8), alpha]), "RGBA"))

    # 상태 내 모든 프레임에 같은 스케일을 적용해야 애니메이션이 들썩이지 않는다.
    # 가장 큰 프레임이 SPRITE_BOX에 맞도록 확대/축소 (시트에서 작게 그려진 상태도 통일)
    frames = []
    if crops:
        max_dim = max(max(c.size) for c in crops)
        scale = SPRITE_BOX / max_dim
        for sprite in crops:
            w, h = sprite.size
            sprite = sprite.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
            canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
            canvas.paste(sprite, ((FRAME - sprite.width) // 2, FRAME - sprite.height - 2))
            name = f"{state}_{len(frames)}.png"
            canvas.save(OUT / name)
            frames.append(name)

    manifest[state] = frames
    print(f"{state}: {len(frames)} frames")

(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
print("→", OUT)
