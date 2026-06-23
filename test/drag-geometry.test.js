const test = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_PIN_OFFSET_Y,
  clampDraggedCat,
  dockAwareFloorY,
  dockAwareWindowBounds,
  estimateBottomDockRect,
  fallY,
  floorY,
  isCatOnDock,
  workAreaWindowBounds,
} = require('../src/renderer/dragGeometry');

test('cat window uses the full work area height', () => {
  assert.deepEqual(
    workAreaWindowBounds({ x: 0, y: 25, width: 1440, height: 875 }),
    { x: 0, y: 25, width: 1440, height: 875 },
  );
});

test('dock-aware window keeps bottom Dock area drawable', () => {
  assert.deepEqual(
    dockAwareWindowBounds({
      bounds: { x: 0, y: 0, width: 1440, height: 900 },
      workArea: { x: 0, y: 25, width: 1440, height: 805 },
    }),
    { x: 0, y: 25, width: 1440, height: 875 },
  );
});

test('dock-aware window keeps work area height when Dock is hidden', () => {
  assert.deepEqual(
    dockAwareWindowBounds({
      bounds: { x: 0, y: 0, width: 1440, height: 900 },
      workArea: { x: 0, y: 25, width: 1440, height: 875 },
    }),
    { x: 0, y: 25, width: 1440, height: 875 },
  );
});

test('dock-aware floor uses the visible bottom Dock top as the floor', () => {
  assert.equal(
    dockAwareFloorY({
      height: 875,
      size: 128,
      winY: 25,
      workArea: { x: 0, y: 25, width: 1440, height: 805 },
      displayBounds: { x: 0, y: 0, width: 1440, height: 900 },
    }),
    675,
  );
});

test('estimateBottomDockRect: infers a centered bottom Dock span', () => {
  assert.deepEqual(
    estimateBottomDockRect({
      displayBounds: { x: 0, y: 0, width: 1440, height: 900 },
      workArea: { x: 0, y: 25, width: 1440, height: 805 },
      tileSize: 44,
      itemCount: 18,
    }),
    { x: 232, y: 830, width: 976, height: 70 },
  );
});

test('dock-aware floor uses Dock top only while the cat is over the Dock span', () => {
  const base = {
    height: 875,
    size: 128,
    winX: 0,
    winY: 25,
    workArea: { x: 0, y: 25, width: 1440, height: 805 },
    displayBounds: { x: 0, y: 0, width: 1440, height: 900 },
    dockRect: { x: 300, y: 830, width: 840, height: 70 },
  };

  assert.equal(dockAwareFloorY({ ...base, catX: 400 }), 675);
  assert.equal(dockAwareFloorY({ ...base, catX: 0 }), 745);
  assert.equal(isCatOnDock({ catX: 400, catWidth: 128, dockRect: base.dockRect }), true);
  assert.equal(isCatOnDock({ catX: 0, catWidth: 128, dockRect: base.dockRect }), false);
});

test('dock-aware floor uses the window bottom when Dock is hidden', () => {
  assert.equal(
    dockAwareFloorY({
      height: 875,
      size: 128,
      winY: 25,
      workArea: { x: 0, y: 25, width: 1440, height: 875 },
      displayBounds: { x: 0, y: 0, width: 1440, height: 900 },
    }),
    745,
  );
});

test('dragged cat can reach the top edge of the window', () => {
  assert.deepEqual(
    clampDraggedCat({
      cursorLocal: { x: 500, y: DEFAULT_PIN_OFFSET_Y },
      size: 128,
      viewport: { width: 1440, height: 875 },
    }),
    { x: 436, y: 0 },
  );
});

test('dragged cat is clamped inside the viewport', () => {
  assert.deepEqual(
    clampDraggedCat({
      cursorLocal: { x: -100, y: -100 },
      size: 128,
      viewport: { width: 1440, height: 875 },
    }),
    { x: 0, y: 0 },
  );

  assert.deepEqual(
    clampDraggedCat({
      cursorLocal: { x: 2000, y: 2000 },
      size: 128,
      viewport: { width: 1440, height: 875 },
    }),
    { x: 1312, y: 747 },
  );
});

test('falling interpolation starts at release y and ends on the floor', () => {
  const bottom = floorY({ height: 875, size: 128 });
  assert.equal(bottom, 745);
  assert.equal(fallY({ startY: 10, floorY: bottom, eased: 0 }), 10);
  assert.equal(fallY({ startY: 10, floorY: bottom, eased: 0.5 }), 377.5);
  assert.equal(fallY({ startY: 10, floorY: bottom, eased: 1 }), bottom);
});
