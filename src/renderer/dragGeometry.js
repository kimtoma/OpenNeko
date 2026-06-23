const DEFAULT_PIN_OFFSET_Y = 4;

function clamp(value, min, max) {
  return Math.max(min, Math.min(value, max));
}

function floorY({ height, size, padding = 2 }) {
  return Math.max(0, height - size - padding);
}

function workAreaWindowBounds(workArea) {
  return {
    x: workArea.x,
    y: workArea.y,
    width: workArea.width,
    height: workArea.height,
  };
}

function dockAwareWindowBounds(display) {
  const bounds = display.bounds || display;
  const workArea = display.workArea || display.workAreaSize || bounds;
  const displayBottom = bounds.y + bounds.height;
  return {
    x: workArea.x,
    y: workArea.y,
    width: workArea.width,
    height: Math.max(workArea.height, displayBottom - workArea.y),
  };
}

function estimateBottomDockRect({ displayBounds, workArea, tileSize = 44, itemCount = 0, padding = 48, gap = 8, dockThreshold = 8 }) {
  if (!displayBounds || !workArea) return null;
  const displayBottom = displayBounds.y + displayBounds.height;
  const workAreaBottom = workArea.y + workArea.height;
  const dockHeight = displayBottom - workAreaBottom;
  if (dockHeight <= dockThreshold) return null;

  const count = Math.max(1, Number(itemCount) || 0);
  const rawWidth = count * tileSize + Math.max(0, count - 1) * gap + padding;
  const minWidth = Math.max(tileSize + padding, dockHeight * 3);
  const maxWidth = displayBounds.width;
  const width = clamp(rawWidth || minWidth, minWidth, maxWidth);
  const x = displayBounds.x + (displayBounds.width - width) / 2;
  return { x, y: workAreaBottom, width, height: dockHeight };
}

function isCatOnDock({ catX, catWidth, dockRect, margin = 12 }) {
  if (!dockRect || catX == null) return false;
  const supportX = catX + catWidth / 2;
  return supportX >= dockRect.x - margin && supportX <= dockRect.x + dockRect.width + margin;
}

function dockAwareFloorY({
  height, size, workArea, displayBounds, dockRect, catX, winX = 0, winY = 0, padding = 2, dockThreshold = 8,
}) {
  const windowFloor = floorY({ height, size, padding });
  if (!workArea || !displayBounds) return windowFloor;
  const workAreaBottom = workArea.y + workArea.height;
  const displayBottom = displayBounds.y + displayBounds.height;
  const bottomDockGap = displayBottom - workAreaBottom;
  if (bottomDockGap <= dockThreshold) return windowFloor;
  if (dockRect && !isCatOnDock({ catX: catX == null ? null : catX + winX, catWidth: size, dockRect })) {
    return windowFloor;
  }
  const dockTopFloor = workAreaBottom - winY - size - padding;
  return clamp(dockTopFloor, 0, windowFloor);
}

function clampDraggedCat({ cursorLocal, size, viewport, pinOffsetY = DEFAULT_PIN_OFFSET_Y }) {
  const maxX = Math.max(0, viewport.width - size);
  const maxY = Math.max(0, viewport.height - size);
  return {
    x: clamp(Math.round(cursorLocal.x - size / 2), 0, maxX),
    y: clamp(Math.round(cursorLocal.y - pinOffsetY), 0, maxY),
  };
}

function fallY({ startY, floorY, eased }) {
  const p = clamp(eased, 0, 1);
  return startY + (floorY - startY) * p;
}

module.exports = {
  DEFAULT_PIN_OFFSET_Y,
  clampDraggedCat,
  dockAwareFloorY,
  dockAwareWindowBounds,
  estimateBottomDockRect,
  fallY,
  floorY,
  isCatOnDock,
  workAreaWindowBounds,
};
