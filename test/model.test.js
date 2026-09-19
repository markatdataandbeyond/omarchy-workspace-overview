const assert = require('node:assert/strict')
const model = require('../model/OverviewModel.js')

// ---- address hygiene --------------------------------------------------------

assert.equal(model.ensure0x('563e004c1e40'), '0x563e004c1e40')
assert.equal(model.ensure0x('0x563e004c1e40'), '0x563e004c1e40')
assert.equal(model.ensure0x(''), '')
assert.equal(model.isValidAddress('563e004c1e40'), true)
assert.equal(model.isValidAddress('0xdeadBEEF'), true)
assert.equal(model.isValidAddress("0xdead'); os.execute('rm"), false)
assert.equal(model.isValidAddress(''), false)

// ---- dispatch builders ------------------------------------------------------

assert.equal(model.focusDispatch('563e004c1e40'),
  "hl.dsp.focus({ window = hl.get_window('address:0x563e004c1e40') })")
assert.equal(model.focusDispatch('nope'), '')
assert.equal(model.workspaceFocusDispatch(4), "hl.dsp.focus({ workspace = tostring(4) })")
assert.equal(model.workspaceFocusDispatch(0), '')
assert.equal(model.workspaceFocusDispatch(-1), '')

// ---- occupied workspaces: only numbered desks with windows ------------------

assert.deepEqual(model.occupiedWorkspaceIds([
  { id: 3, windowCount: 2 },
  { id: 1, windowCount: 1 },
  { id: 2, windowCount: 0 },
  { id: -98, windowCount: 4 },
  { id: 1, windowCount: 1 },
  { id: 0, windowCount: 1 },
  { id: 5, windowCount: 3 }
]), [1, 3, 5])
assert.deepEqual(model.occupiedWorkspaceIds(null), [])
assert.deepEqual(model.occupiedWorkspaceIds([]), [])
assert.deepEqual(model.exposeWorkspaceIds([1, 2, 3, 5, 6], [1, 2]), [1, 2, 3, 5, 6])
assert.deepEqual(model.exposeWorkspaceIds([], [1, 3, 5]), [1, 3, 5])
assert.deepEqual(model.exposeWorkspaceIds(null, [4]), [4])

// ---- 2x2 map math -----------------------------------------------------------

assert.equal(model.GRID_COLUMNS, 2)
assert.equal(model.VISIBLE_ROWS, 2)
assert.equal(model.pageSize(), 4)
assert.equal(model.rowCount(0), 0)
assert.equal(model.rowCount(1), 1)
assert.equal(model.rowCount(4), 2)
assert.equal(model.rowCount(5), 3)
assert.equal(model.pageCount(0), 0)
assert.equal(model.pageCount(4), 1)
assert.equal(model.pageCount(5), 2)
assert.equal(model.pageForIndex(0), 0)
assert.equal(model.pageForIndex(3), 0)
assert.equal(model.pageForIndex(4), 1)
assert.equal(model.clampIndex(9, 5), 4)
assert.equal(model.clampIndex(-1, 5), 0)
assert.equal(model.clampIndex(2, 0), -1)
assert.equal(model.clampPage(3, 5), 1)
assert.equal(model.clampPage(-1, 5), 0)

// Arrow navigation stays on the 2-column map and does not wrap.
assert.equal(model.moveIndex(0, 1, 0, 5), 1)
assert.equal(model.moveIndex(0, -1, 0, 5), 0)
assert.equal(model.moveIndex(0, 0, 1, 5), 2)
assert.equal(model.moveIndex(1, 0, 1, 5), 3)
assert.equal(model.moveIndex(3, 0, 1, 5), 5 > 4 ? 4 : 3)
assert.equal(model.moveIndex(4, 0, -1, 5), 2)
assert.equal(model.moveIndex(2, 0, -1, 5), 0)
assert.equal(model.pageDown(1, 6), 5)
assert.equal(model.pageDown(4, 6), 5)
assert.equal(model.pageUp(5, 6), 1)
assert.equal(model.pageUp(1, 6), 0)

const cell = 400
const gap = 20
const viewport = cell * 2 + gap
assert.equal(model.mapContentHeight(4, cell, gap), viewport)
assert.ok(model.mapContentHeight(5, cell, gap) > viewport, 'a fifth workspace must overflow the 2x2 viewport')
assert.equal(model.applyWheel(0, 80, model.mapContentHeight(5, cell, gap), viewport), 80)
assert.equal(model.applyWheel(0, -40, model.mapContentHeight(5, cell, gap), viewport), 0)
assert.equal(model.wheelDelta(40, 120), -40)
assert.equal(model.wheelDelta(0, 120), -30)
assert.equal(model.wheelDelta(-80, 0), 80)
assert.equal(model.wheelDelta(0, 0), 0)
assert.equal(
  model.applyWheel(10000, 0, model.mapContentHeight(5, cell, gap), viewport),
  model.mapContentHeight(5, cell, gap) - viewport
)

const row = cell + gap
const six = model.mapContentHeight(6, cell, gap)
assert.equal(model.snapScrollY(0, cell, gap, six, viewport, 1), 0)
assert.equal(model.snapScrollY(80, cell, gap, six, viewport, 1), row)
assert.equal(model.snapScrollY(80, cell, gap, six, viewport, -1), 0)
assert.equal(model.snapScrollY(row, cell, gap, six, viewport, 0), row)
assert.equal(model.snapScrollY(row - 40, cell, gap, six, viewport, -1), 0)
assert.equal(model.stepScrollY(0, cell, gap, six, viewport, 1), row)
assert.equal(model.stepScrollY(row, cell, gap, six, viewport, -1), 0)
assert.equal(model.stepScrollY(0, cell, gap, six, viewport, -1), 0)
assert.equal(model.stepScrollY(row, cell, gap, six, viewport, 1), row)
assert.equal(model.revealScrollY(0, 0, cell, gap, six, viewport), 0)
assert.equal(model.revealScrollY(4, 0, cell, gap, six, viewport), row)
assert.deepEqual(model.monitorCanvas(null), { x: 0, y: 0, width: 0, height: 0 })
assert.deepEqual(model.monitorCanvas({ x: 1920, y: 0, width: 1920, height: 1080 }), {
  x: 1920, y: 0, width: 1920, height: 1080
})
assert.deepEqual(model.windowsFromToplevels([
  { lastIpcObject: { address: '0xaa', at: [0, 0], size: [10, 10], title: 'a' } },
  { address: '0xbb', title: 'b' }
]), [
  { address: '0xaa', x: 0, y: 0, width: 10, height: 10, title: 'a' },
  { address: '0xbb', x: 0, y: 0, width: 1, height: 1, title: 'b' }
])

assert.equal(model.workspaceIdFromDigit('1'), 1)
assert.equal(model.workspaceIdFromDigit('0'), 10)
assert.equal(model.workspaceIdFromDigit('a'), 0)
assert.equal(model.workspaceIdFromKeyCode(49), 1)
assert.equal(model.workspaceIdFromKeyCode(50), 2)
assert.equal(model.workspaceIdFromKeyCode(48), 10)
assert.equal(model.workspaceIdFromKeyCode(0), 0)

// ---- miniature geometry: real layout, monitor-relative ----------------------

const tiled = model.layoutWindows(
  [
    { address: '0xaa', x: 0, y: 0, width: 960, height: 1200 },
    { address: '0xbb', x: 960, y: 0, width: 960, height: 1200 }
  ],
  { x: 0, y: 0, width: 1920, height: 1200 },
  { width: 192, height: 120 }
)
assert.equal(tiled.length, 2)
assert.deepEqual(tiled[0], { address: '0xaa', x: 0, y: 0, width: 96, height: 120 })
assert.deepEqual(tiled[1], { address: '0xbb', x: 96, y: 0, width: 96, height: 120 })

const offset = model.layoutWindows(
  [{ address: '0xcc', x: 1920, y: 0, width: 1920, height: 1080 }],
  { x: 1920, y: 0, width: 1920, height: 1080 },
  { width: 100, height: 50 }
)
assert.deepEqual(offset[0], { address: '0xcc', x: 0, y: 0, width: 100, height: 50 })

assert.deepEqual(model.layoutWindows([], { width: 1920, height: 1080 }, { width: 100, height: 50 }), [])
assert.deepEqual(model.layoutWindows([{ address: '0xdd', x: 0, y: 0, width: 100, height: 100 }], { width: 0, height: 0 }, { width: 50, height: 50 }).length, 1)

const ipc = model.windowFromIpc({
  address: '0x559de2f37ad0',
  at: [12, 38],
  size: [941, 1150],
  title: 'Home / X'
})
assert.deepEqual(ipc, {
  address: '0x559de2f37ad0',
  x: 12,
  y: 38,
  width: 941,
  height: 1150,
  title: 'Home / X'
})
assert.equal(model.windowFromIpc(null), null)
assert.equal(model.windowFromIpc({ address: '0x1', at: [0, 0], size: [0, 10] }), null)

console.log('ok - workspace overview model')
