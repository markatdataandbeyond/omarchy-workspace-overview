// Workspace map for the Omarchy overview. Loaded by QML and the Node
// test harness, so it stays dependency-free.
//
// Dispatches use Hyprland's Lua provider syntax. Addresses arrive from
// Quickshell without the 0x prefix and from hyprctl with it; everything
// here normalizes to the 0x form the selectors expect.

var GRID_COLUMNS = 2
var VISIBLE_ROWS = 2

function ensure0x(address) {
  var value = String(address == null ? "" : address).trim()
  if (value.length === 0) return ""
  return value.indexOf("0x") === 0 ? value : "0x" + value
}

function isValidAddress(address) {
  return /^0x[0-9a-fA-F]+$/.test(ensure0x(address))
}

function focusDispatch(address) {
  var addr = ensure0x(address)
  if (!isValidAddress(addr)) return ""
  return "hl.dsp.focus({ window = hl.get_window('address:" + addr + "') })"
}

function workspaceFocusDispatch(workspaceId) {
  var id = Number(workspaceId)
  if (!isFinite(id) || id <= 0 || id !== Math.floor(id)) return ""
  return "hl.dsp.focus({ workspace = tostring(" + id + ") })"
}

function exposeWorkspaceIds(openIds, liveIds) {
  if (openIds && openIds.length > 0)
    return openIds.slice()
  return liveIds ? liveIds.slice() : []
}

function occupiedWorkspaceIds(workspaces) {
  var list = []
  for (var i = 0; i < (workspaces ? workspaces.length : 0); i++) {
    var workspace = workspaces[i]
    if (!workspace) continue
    var id = Number(workspace.id)
    var count = Number(workspace.windowCount)
    if (!isFinite(id) || id <= 0 || id !== Math.floor(id)) continue
    if (!isFinite(count) || count <= 0) continue
    if (list.indexOf(id) === -1) list.push(id)
  }
  list.sort(function (a, b) { return a - b })
  return list
}

function pageSize() {
  return GRID_COLUMNS * VISIBLE_ROWS
}

function mapContentHeight(count, cellHeight, gap) {
  var rows = rowCount(count)
  if (rows <= 0) return 0
  return rows * (Number(cellHeight) + Number(gap)) - Number(gap)
}

function clampScrollY(y, contentHeight, viewportHeight) {
  var maxY = Math.max(0, Number(contentHeight) - Number(viewportHeight))
  var value = Number(y)
  if (!isFinite(value) || value < 0) return 0
  if (value > maxY) return maxY
  return value
}

function applyWheel(contentY, deltaY, contentHeight, viewportHeight) {
  return clampScrollY(Number(contentY) + Number(deltaY), contentHeight, viewportHeight)
}

function revealScrollY(index, contentY, cellHeight, gap, contentHeight, viewportHeight) {
  var rowHeight = Number(cellHeight) + Number(gap)
  var row = Math.floor(Number(index) / GRID_COLUMNS)
  var top = row * rowHeight
  var next = Number(contentY)
  var view = Number(viewportHeight)
  if (top < next)
    next = top
  else if (top + Number(cellHeight) > next + view)
    next = top + Number(cellHeight) - view
  return snapScrollY(next, cellHeight, gap, contentHeight, viewportHeight, 0)
}

function monitorCanvas(monitor) {
  if (!monitor)
    return { x: 0, y: 0, width: 0, height: 0 }
  var ipc = monitor.lastIpcObject || {}
  var width = Number(monitor.width !== undefined ? monitor.width : ipc.width) || 0
  var height = Number(monitor.height !== undefined ? monitor.height : ipc.height) || 0
  if (width <= 0 || height <= 0) {
    width = Number(ipc.width) || 0
    height = Number(ipc.height) || 0
  }
  return {
    x: Number(monitor.x !== undefined ? monitor.x : ipc.x) || 0,
    y: Number(monitor.y !== undefined ? monitor.y : ipc.y) || 0,
    width: width,
    height: height
  }
}

function windowFromToplevel(toplevel) {
  if (!toplevel)
    return null
  var parsed = windowFromIpc(toplevel.lastIpcObject || null)
  if (parsed)
    return parsed
  return windowFromIpc({
    address: toplevel.address,
    at: [0, 0],
    size: [1, 1],
    title: toplevel.title
  })
}

function windowsFromToplevels(toplevels) {
  var out = []
  for (var i = 0; i < (toplevels ? toplevels.length : 0); i++) {
    var parsed = windowFromToplevel(toplevels[i])
    if (parsed)
      out.push(parsed)
  }
  return out
}

function snapScrollY(contentY, cellHeight, gap, contentHeight, viewportHeight, direction) {
  var rowHeight = Number(cellHeight) + Number(gap)
  var y = clampScrollY(contentY, contentHeight, viewportHeight)
  var maxY = Math.max(0, Number(contentHeight) - Number(viewportHeight))
  if (!isFinite(rowHeight) || rowHeight <= 0 || maxY <= 0)
    return 0
  var current = y / rowHeight
  var dir = Number(direction)
  var row
  if (dir > 0)
    row = Math.ceil(current - 1e-6)
  else if (dir < 0)
    row = Math.floor(current + 1e-6)
  else
    row = Math.round(current)
  if (row < 0)
    row = 0
  var snapped = clampScrollY(row * rowHeight, contentHeight, viewportHeight)
  return snapped === 0 ? 0 : snapped
}

function stepScrollY(contentY, cellHeight, gap, contentHeight, viewportHeight, steps) {
  var rowHeight = Number(cellHeight) + Number(gap)
  var current = snapScrollY(contentY, cellHeight, gap, contentHeight, viewportHeight, 0)
  if (!isFinite(rowHeight) || rowHeight <= 0)
    return current
  return clampScrollY(current + Number(steps) * rowHeight, contentHeight, viewportHeight)
}

function wheelDelta(pixelY, angleY) {
  var pixel = Number(pixelY)
  var angle = Number(angleY)
  if (isFinite(pixel) && Math.abs(pixel) >= 1)
    return -pixel
  if (isFinite(angle) && angle !== 0)
    return -(angle / 4)
  return 0
}

function rowCount(n) {
  var count = Math.max(0, Number(n) || 0)
  if (count === 0) return 0
  return Math.ceil(count / GRID_COLUMNS)
}

function pageCount(n) {
  var count = Math.max(0, Number(n) || 0)
  if (count === 0) return 0
  return Math.ceil(count / pageSize())
}

function pageForIndex(index) {
  var i = Number(index)
  if (!isFinite(i) || i < 0) return 0
  return Math.floor(i / pageSize())
}

function clampIndex(index, n) {
  var count = Math.max(0, Number(n) || 0)
  if (count === 0) return -1
  var i = Number(index)
  if (!isFinite(i)) return 0
  if (i < 0) return 0
  if (i >= count) return count - 1
  return Math.floor(i)
}

function clampPage(page, n) {
  var pages = pageCount(n)
  if (pages === 0) return 0
  var p = Number(page)
  if (!isFinite(p) || p < 0) return 0
  if (p >= pages) return pages - 1
  return Math.floor(p)
}

function moveIndex(index, dx, dy, count) {
  var current = clampIndex(index, count)
  if (current < 0) return -1
  var col = current % GRID_COLUMNS
  var row = Math.floor(current / GRID_COLUMNS)
  col = Math.max(0, Math.min(GRID_COLUMNS - 1, col + Number(dx || 0)))
  row = Math.max(0, row + Number(dy || 0))
  return clampIndex(row * GRID_COLUMNS + col, count)
}

function pageDown(index, count) {
  return clampIndex(Number(index) + pageSize(), count)
}

function pageUp(index, count) {
  return clampIndex(Number(index) - pageSize(), count)
}

function workspaceIdFromDigit(text) {
  var value = String(text == null ? "" : text)
  if (value === "0") return 10
  if (value >= "1" && value <= "9") return Number(value)
  return 0
}

function windowFromIpc(ipc) {
  if (!ipc || typeof ipc !== "object") return null
  var at = ipc.at || []
  var size = ipc.size || []
  var width = Number(size[0])
  var height = Number(size[1])
  if (!isFinite(width) || !isFinite(height) || width <= 0 || height <= 0) return null
  var address = ensure0x(ipc.address)
  if (!isValidAddress(address)) return null
  return {
    address: address,
    x: Number(at[0]) || 0,
    y: Number(at[1]) || 0,
    width: width,
    height: height,
    title: String(ipc.title || "")
  }
}

function boundingCanvas(windows) {
  var minX = Infinity
  var minY = Infinity
  var maxX = -Infinity
  var maxY = -Infinity
  for (var i = 0; i < windows.length; i++) {
    var win = windows[i]
    minX = Math.min(minX, win.x)
    minY = Math.min(minY, win.y)
    maxX = Math.max(maxX, win.x + win.width)
    maxY = Math.max(maxY, win.y + win.height)
  }
  if (!isFinite(minX) || !isFinite(minY) || maxX <= minX || maxY <= minY) return null
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
}

function clipRect(x, y, width, height, tileWidth, tileHeight) {
  var right = Math.min(x + width, tileWidth)
  var bottom = Math.min(y + height, tileHeight)
  var left = Math.max(0, x)
  var top = Math.max(0, y)
  if (right <= left || bottom <= top) return null
  return {
    x: left,
    y: top,
    width: right - left,
    height: bottom - top
  }
}

function layoutWindows(windows, canvas, tile) {
  var list = windows || []
  var tw = Number(tile && tile.width)
  var th = Number(tile && tile.height)
  if (!isFinite(tw) || !isFinite(th) || tw <= 0 || th <= 0) return []

  var parsed = []
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    if (!item) continue
    var addr = ensure0x(item.address)
    var width = Number(item.width)
    var height = Number(item.height)
    if (!isValidAddress(addr) || !isFinite(width) || !isFinite(height) || width <= 0 || height <= 0) continue
    parsed.push({
      address: addr,
      x: Number(item.x) || 0,
      y: Number(item.y) || 0,
      width: width,
      height: height
    })
  }
  if (parsed.length === 0) return []

  var board = canvas && Number(canvas.width) > 0 && Number(canvas.height) > 0
    ? {
        x: Number(canvas.x) || 0,
        y: Number(canvas.y) || 0,
        width: Number(canvas.width),
        height: Number(canvas.height)
      }
    : boundingCanvas(parsed)
  if (!board) return []

  var scaleX = tw / board.width
  var scaleY = th / board.height
  var out = []
  for (var j = 0; j < parsed.length; j++) {
    var win = parsed[j]
    var rect = clipRect(
      (win.x - board.x) * scaleX,
      (win.y - board.y) * scaleY,
      win.width * scaleX,
      win.height * scaleY,
      tw,
      th
    )
    if (!rect) continue
    out.push({
      address: win.address,
      x: rect.x,
      y: rect.y,
      width: rect.width,
      height: rect.height
    })
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    GRID_COLUMNS: GRID_COLUMNS,
    VISIBLE_ROWS: VISIBLE_ROWS,
    ensure0x: ensure0x,
    isValidAddress: isValidAddress,
    focusDispatch: focusDispatch,
    workspaceFocusDispatch: workspaceFocusDispatch,
    occupiedWorkspaceIds: occupiedWorkspaceIds,
    exposeWorkspaceIds: exposeWorkspaceIds,
    pageSize: pageSize,
    mapContentHeight: mapContentHeight,
    clampScrollY: clampScrollY,
    applyWheel: applyWheel,
    revealScrollY: revealScrollY,
    monitorCanvas: monitorCanvas,
    windowFromToplevel: windowFromToplevel,
    windowsFromToplevels: windowsFromToplevels,
    snapScrollY: snapScrollY,
    stepScrollY: stepScrollY,
    wheelDelta: wheelDelta,
    rowCount: rowCount,
    pageCount: pageCount,
    pageForIndex: pageForIndex,
    clampIndex: clampIndex,
    clampPage: clampPage,
    moveIndex: moveIndex,
    pageDown: pageDown,
    pageUp: pageUp,
    workspaceIdFromDigit: workspaceIdFromDigit,
    windowFromIpc: windowFromIpc,
    layoutWindows: layoutWindows
  }
}
