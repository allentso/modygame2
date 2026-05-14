-- ============================================================================
-- WorldMap.lua - 六边形世界地图（Pointy-top，NanoVG 渲染）
-- 方案：纯色块六边形 + 港口标记 + 贸易航线 + 资源图标
-- ============================================================================
local UI = require("urhox-libs/UI")
local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("ui.Theme")
local MapModuleAdapter = require("map.MapModuleAdapter")

local M = {}

-- ── 六边形数学常量（首次渲染时根据视口动态计算）─────
local SQRT3 = math.sqrt(3)
local HEX_EDGE = Theme.hexEdge  -- 初始占位，首次渲染时会重算
local HEX_W = SQRT3 * HEX_EDGE
local HEX_H = 2 * HEX_EDGE
local COL_STEP = HEX_W
local ROW_STEP = HEX_H * 0.75

--- 根据视口高度重算六边形常量，保证 zoom=0.5 时上下顶边
local function recalcHexConstants(gridRows, viewportH)
    -- 目标: GRID_ROWS * ROW_STEP * 0.5 = viewportH
    -- ROW_STEP = 1.5 * HEX_EDGE
    -- → HEX_EDGE = viewportH / (GRID_ROWS * 1.5 * 0.5)
    HEX_EDGE = viewportH / (gridRows * 0.75)
    HEX_W = SQRT3 * HEX_EDGE
    HEX_H = 2 * HEX_EDGE
    COL_STEP = HEX_W
    ROW_STEP = HEX_H * 0.75
end

-- ── 偏移坐标 → 像素中心坐标 ─────────────────────
local function hexToPixel(col, row)
    local x = col * COL_STEP
    if row % 2 == 1 then
        x = x + COL_STEP * 0.5  -- 奇数行右移半格
    end
    local y = row * ROW_STEP
    return x, y
end

-- ── 像素坐标 → 偏移坐标（cube rounding）─────────
local function pixelToHex(px, py)
    local q = (SQRT3 / 3 * px - 1.0 / 3 * py) / HEX_EDGE
    local r = (2.0 / 3 * py) / HEX_EDGE
    local cx, cy, cz = q, -q - r, r
    local rx = math.floor(cx + 0.5)
    local ry = math.floor(cy + 0.5)
    local rz = math.floor(cz + 0.5)
    local dx = math.abs(rx - cx)
    local dy = math.abs(ry - cy)
    local dz = math.abs(rz - cz)
    if dx > dy and dx > dz then
        rx = -ry - rz
    elseif dy > dz then
        ry = -rx - rz
    else
        rz = -rx - ry
    end
    local row = rz
    local col
    if rz % 2 ~= 0 then
        col = rx + math.floor((rz - 1) / 2)
    else
        col = rx + math.floor(rz / 2)
    end
    return col, row
end

-- ── 绘制单个 Pointy-top 六边形 ──────────────────
local function drawHex(nvg, cx, cy, edge)
    nvgBeginPath(nvg)
    for i = 0, 5 do
        local angle = math.rad(30 + 60 * i)
        local vx = cx + edge * math.cos(angle)
        local vy = cy + edge * math.sin(angle)
        if i == 0 then
            nvgMoveTo(nvg, vx, vy)
        else
            nvgLineTo(nvg, vx, vy)
        end
    end
    nvgClosePath(nvg)
end

-- ══════════════════════════════════════════════════════
-- 自定义地图 Widget
-- ══════════════════════════════════════════════════════
local WorldMapWidget = Widget:Extend("WorldMapWidget")

function WorldMapWidget:Init(props)
    Widget.Init(self, props)
    self._state = props.gameState
    self._onPortClick = props.onPortClick
    self._mapAdapter = props.mapAdapter or MapModuleAdapter.new()

    -- 视口变换（平移+缩放）
    self._panX = 0
    self._panY = 0
    self._zoom = 0.5
    self._minZoom = 0.3
    self._maxZoom = 2.5

    -- 拖拽状态
    self._dragging = false
    self._dragStartX = 0
    self._dragStartY = 0
    self._panStartX = 0
    self._panStartY = 0

    -- hover 状态
    self._hoverCol = -1
    self._hoverRow = -1

    -- 鼠标位置缓存（OnWheel 需要）
    self._lastMouseX = nil
    self._lastMouseY = nil

    -- 初始居中
    self._initialized = false
end

function WorldMapWidget:Render(nvg)
    self:RenderFullBackground(nvg)

    local layout = self:GetLayout()
    local lx, ly, lw, lh = layout.x, layout.y, layout.w, layout.h

    -- 首次渲染：根据视口计算 hex 大小，zoom=0.5 时上下顶边
    if not self._initialized then
        self._initialized = true
        recalcHexConstants(self._mapAdapter:GetGridRows(), lh)

        self._zoom = 0.5

        local mapW = self._mapAdapter:GetGridCols() * COL_STEP
        -- 垂直居中（上下顶边）
        self._panY = 0
        -- 水平居中
        self._panX = (lw - mapW * self._zoom) / 2
    end

    nvgSave(nvg)
    nvgIntersectScissor(nvg, lx, ly, lw, lh)

    -- ═══════════════════════════════════════════════
    -- Layer 0: 深色海洋底色（渐变）
    -- ═══════════════════════════════════════════════
    nvgBeginPath(nvg)
    nvgRect(nvg, lx, ly, lw, lh)
    local seaGrad = nvgLinearGradient(nvg, lx, ly, lx, ly + lh,
        nvgRGBA(8, 14, 26, 255), nvgRGBA(4, 8, 18, 255))
    nvgFillPaint(nvg, seaGrad)
    nvgFill(nvg)

    -- 应用视口变换参数
    local ox = lx + self._panX
    local oy = ly + self._panY
    local z = self._zoom

    -- 获取选中港口
    local selectedPortId = nil
    if self._state and self._state.selectedColony then
        local colony = self._state.colonies[self._state.selectedColony]
        if colony then selectedPortId = colony.portId end
    end

    local drawList = self._mapAdapter:BuildDrawList(self._state)
    local tileDrawItems = {}
    for _, item in ipairs(drawList) do
        if item.kind == "tile" then
            tileDrawItems[#tileDrawItems + 1] = item
        end
    end

    -- ═══════════════════════════════════════════════
    -- Layer 1: 色块填充六边形（地形）
    -- ═══════════════════════════════════════════════
    for _, tile in ipairs(tileDrawItems) do
        local cx, cy = hexToPixel(tile.col, tile.row)
        local sx = ox + cx * z
        local sy = oy + cy * z
        local se = HEX_EDGE * z

        -- 裁剪：跳过屏幕外的瓦片
        if sx > lx - se * 2 and sx < lx + lw + se * 2
            and sy > ly - se * 2 and sy < ly + lh + se * 2 then

            local style = self._mapAdapter:GetTileStyle(tile)
            if tile.visibility == "hidden" then
                style = self._mapAdapter:GetUnexploredStyle() or style
            end
            if style then
                local f = style.fill
                local s_c = style.stroke

                -- 填充
                drawHex(nvg, sx, sy, se * 0.96)
                nvgFillColor(nvg, nvgRGBA(f[1], f[2], f[3], f[4] or 255))
                nvgFill(nvg)

                -- 边框
                drawHex(nvg, sx, sy, se * 0.96)
                nvgStrokeColor(nvg, nvgRGBA(s_c[1], s_c[2], s_c[3], s_c[4] or 255))
                nvgStrokeWidth(nvg, 0.8)
                nvgStroke(nvg)
            end

            if tile.visibility == "explored" then
                drawHex(nvg, sx, sy, se * 0.96)
                nvgFillColor(nvg, nvgRGBA(8, 12, 18, 105))
                nvgFill(nvg)
            end

            -- hover 高亮
            local isHover = (tile.col == self._hoverCol and tile.row == self._hoverRow)
            if isHover then
                drawHex(nvg, sx, sy, se * 0.96)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 25))
                nvgFill(nvg)
                -- hover 边框
                drawHex(nvg, sx, sy, se * 0.96)
                nvgStrokeColor(nvg, nvgRGBA(200, 210, 240, 100))
                nvgStrokeWidth(nvg, 1.2)
                nvgStroke(nvg)
            end
        end
    end

    -- ═══════════════════════════════════════════════
    -- Layer 2: 资源图标叠加
    -- ═══════════════════════════════════════════════
    local effectiveEdge = HEX_EDGE * z
    if effectiveEdge > 8 then  -- 有效六边形边长足够大时才显示资源
        for _, tile in ipairs(tileDrawItems) do
            if tile.resource and tile.visibility == "visible" then
                local resInfo = self._mapAdapter:GetResourceIcon(tile.resource)
                if resInfo then
                    local cx, cy = hexToPixel(tile.col, tile.row)
                    local sx = ox + cx * z
                    local sy = oy + cy * z
                    local se = HEX_EDGE * z

                    if sx > lx - se * 2 and sx < lx + lw + se * 2
                        and sy > ly - se * 2 and sy < ly + lh + se * 2 then

                        -- 资源圆形底板
                        local iconR = math.max(3, se * 0.25)
                        local iconX = sx + se * 0.35
                        local iconY = sy - se * 0.35
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, iconX, iconY, iconR + 1)
                        nvgFillColor(nvg, nvgRGBA(10, 16, 28, 180))
                        nvgFill(nvg)

                        -- 资源文字
                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, math.max(6, 8 * z))
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(nvg, nvgRGBA(resInfo.color[1], resInfo.color[2], resInfo.color[3], 230))
                        nvgText(nvg, iconX, iconY, resInfo.icon, nil)
                    end
                end
            end
        end
    end

    -- ═══════════════════════════════════════════════
    -- Layer 3: 港口标记 — 核心交互元素
    -- ═══════════════════════════════════════════════
    for _, tile in ipairs(tileDrawItems) do
        if tile.portId and tile.visibility ~= "hidden" then
            local cx, cy = hexToPixel(tile.col, tile.row)
            local sx = ox + cx * z
            local sy = oy + cy * z
            local se = HEX_EDGE * z

            if sx > lx - se * 2 and sx < lx + lw + se * 2
                and sy > ly - se * 2 and sy < ly + lh + se * 2 then

                local isSelected = (tile.portId == selectedPortId)

                -- 选中金圈
                if isSelected then
                    drawHex(nvg, sx, sy, se * 1.02)
                    nvgStrokeColor(nvg, nvgRGBA(235, 195, 100, 180))
                    nvgStrokeWidth(nvg, 2.0)
                    nvgStroke(nvg)
                end

                -- 底座光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, se * 0.6)
                if isSelected then
                    local glow = nvgRadialGradient(nvg, sx, sy, se * 0.15, se * 0.6,
                        nvgRGBA(235, 195, 100, 100), nvgRGBA(235, 195, 100, 0))
                    nvgFillPaint(nvg, glow)
                else
                    local glow = nvgRadialGradient(nvg, sx, sy, se * 0.1, se * 0.55,
                        nvgRGBA(60, 110, 180, 80), nvgRGBA(60, 110, 180, 0))
                    nvgFillPaint(nvg, glow)
                end
                nvgFill(nvg)

                -- 港口圆形标记
                local markerR = math.max(3, se * 0.28)
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, markerR)
                if isSelected then
                    nvgFillColor(nvg, nvgRGBA(235, 195, 100, 230))
                else
                    nvgFillColor(nvg, nvgRGBA(180, 210, 240, 200))
                end
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, isSelected and 220 or 120))
                nvgStrokeWidth(nvg, isSelected and 1.5 or 0.8)
                nvgStroke(nvg)

                -- 港口名称标签
                if tile.name and effectiveEdge > 6 then
                    nvgFontFace(nvg, "sans")
                    local fontSize = math.max(7, 9 * z)
                    nvgFontSize(nvg, fontSize)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

                    local labelY = sy + markerR + 2

                    -- 名称背景
                    local textW = nvgTextBounds(nvg, 0, 0, tile.name, nil)
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, sx - textW / 2 - 3, labelY - 1, textW + 6, fontSize + 3, 3)
                    nvgFillColor(nvg, nvgRGBA(10, 16, 28, 190))
                    nvgFill(nvg)

                    -- 名称文字
                    if isSelected then
                        nvgFillColor(nvg, nvgRGBA(235, 195, 100, 240))
                    else
                        nvgFillColor(nvg, nvgRGBA(200, 215, 235, 220))
                    end
                    nvgText(nvg, sx, labelY, tile.name, nil)
                end
            end
        end
    end

    -- ═══════════════════════════════════════════════
    -- Layer 4: 贸易航线
    -- ═══════════════════════════════════════════════
    self:DrawTradeRoutes(nvg, ox, oy, z)

    -- ═══════════════════════════════════════════════
    -- Layer 5: HUD 叠加（图例 + 缩放指示器）
    -- ═══════════════════════════════════════════════
    self:DrawLegend(nvg, lx, ly, lw, lh)
    self:DrawZoomIndicator(nvg, lx, ly, lw, lh)

    nvgRestore(nvg)
end

--- 获取港口的屏幕坐标
function WorldMapWidget:GetPortScreenPos(portId, ox, oy, z)
    local tile = self._mapAdapter:GetPortTile(portId)
    if not tile then return 0, 0 end
    local cx, cy = hexToPixel(tile.col, tile.row)
    return ox + cx * z, oy + cy * z
end

--- 绘制贸易航线
function WorldMapWidget:DrawTradeRoutes(nvg, ox, oy, z)
    for _, route in ipairs(self._mapAdapter:GetRoutes()) do
        local x1, y1 = self:GetPortScreenPos(route.from, ox, oy, z)
        local x2, y2 = self:GetPortScreenPos(route.to, ox, oy, z)

        if x1 == 0 and y1 == 0 then goto continue end
        if x2 == 0 and y2 == 0 then goto continue end

        local c = route.color

        -- 弧线
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], 140))
        nvgStrokeWidth(nvg, math.max(1, 1.5 * z))
        nvgLineCap(nvg, NVG_ROUND)

        local mx = (x1 + x2) / 2
        local dy = math.abs(y2 - y1) + math.abs(x2 - x1)
        local my = (y1 + y2) / 2 - dy * 0.12

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgQuadTo(nvg, mx, my, x2, y2)
        nvgStroke(nvg)

        -- 弧线中点圆
        local t = 0.6
        local ax = (1 - t) * (1 - t) * x1 + 2 * (1 - t) * t * mx + t * t * x2
        local ay = (1 - t) * (1 - t) * y1 + 2 * (1 - t) * t * my + t * t * y2
        nvgBeginPath(nvg)
        nvgCircle(nvg, ax, ay, math.max(1.5, 2 * z))
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 200))
        nvgFill(nvg)

        ::continue::
    end
end

--- 绘制图例
function WorldMapWidget:DrawLegend(nvg, lx, ly, lw, lh)
    local legendX = lx + 6
    local legendY = ly + lh - 56
    local legendW = 110
    local legendH = 50

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, legendX, legendY, legendW, legendH, 6)
    nvgFillColor(nvg, nvgRGBA(10, 16, 28, 190))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(60, 90, 140, 60))
    nvgStrokeWidth(nvg, 0.5)
    nvgStroke(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 9)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(200, 210, 230, 200))
    nvgText(nvg, legendX + 6, legendY + 4, "航线图例", nil)

    for i, item in ipairs(self._mapAdapter:GetRouteLegend()) do
        local iy = legendY + 15 + (i - 1) * 12
        nvgStrokeColor(nvg, nvgRGBA(item.color[1], item.color[2], item.color[3], 255))
        nvgStrokeWidth(nvg, 2)
        nvgLineCap(nvg, NVG_ROUND)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, legendX + 6, iy + 5)
        nvgLineTo(nvg, legendX + 24, iy + 5)
        nvgStroke(nvg)

        nvgFillColor(nvg, nvgRGBA(175, 190, 215, 210))
        nvgFontSize(nvg, 8)
        nvgText(nvg, legendX + 28, iy, item.label, nil)
    end
end

--- 绘制缩放指示器
function WorldMapWidget:DrawZoomIndicator(nvg, lx, ly, lw, lh)
    local zoomPct = math.floor(self._zoom * 100)
    local text = zoomPct .. "%"
    local px = lx + lw - 44
    local py = ly + lh - 22

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, px - 2, py - 2, 40, 18, 4)
    nvgFillColor(nvg, nvgRGBA(10, 16, 28, 170))
    nvgFill(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(158, 172, 195, 190))
    nvgText(nvg, px + 18, py + 7, text, nil)
end

-- ── 事件处理：拖拽平移 ──────────────────────────
function WorldMapWidget:OnPointerDown(event)
    self._dragging = true
    self._dragStartX = event.x
    self._dragStartY = event.y
    self._panStartX = self._panX
    self._panStartY = self._panY
    return true
end

function WorldMapWidget:OnPointerMove(event)
    local layout = self:GetLayout()
    self._lastMouseX = event.x - layout.x
    self._lastMouseY = event.y - layout.y

    -- 更新 hover 的 hex
    local mapX = (event.x - layout.x - self._panX) / self._zoom
    local mapY = (event.y - layout.y - self._panY) / self._zoom
    local hc, hr = pixelToHex(mapX, mapY)
    self._hoverCol = hc
    self._hoverRow = hr

    if self._dragging then
        local dx = event.x - self._dragStartX
        local dy = event.y - self._dragStartY
        self._panX = self._panStartX + dx
        self._panY = self._panStartY + dy
        return true
    end
    return false
end

function WorldMapWidget:OnPointerUp(event)
    if self._dragging then
        local dx = math.abs(event.x - self._dragStartX)
        local dy = math.abs(event.y - self._dragStartY)
        self._dragging = false

        if dx < 5 and dy < 5 then
            return self:HandleClick(event)
        end
        return true
    end
    return false
end

--- 处理点击
function WorldMapWidget:HandleClick(event)
    local layout = self:GetLayout()
    local mapX = (event.x - layout.x - self._panX) / self._zoom
    local mapY = (event.y - layout.y - self._panY) / self._zoom

    local col, row = pixelToHex(mapX, mapY)
    local tile = self._mapAdapter:GetTile(col, row)
    if tile and tile.portId and self._onPortClick then
        self._onPortClick(tile.portId)
        return true
    end
    return false
end

-- ── 事件处理：滚轮缩放 ──────────────────────────
function WorldMapWidget:OnWheel(dx, dy)
    local layout = self:GetLayout()
    local mx = self._lastMouseX or (layout.w / 2)
    local my = self._lastMouseY or (layout.h / 2)

    local oldZoom = self._zoom
    local zoomDelta = dy > 0 and 1.1 or 0.9
    local newZoom = oldZoom * zoomDelta
    newZoom = math.max(self._minZoom, math.min(self._maxZoom, newZoom))

    self._panX = mx - (mx - self._panX) * (newZoom / oldZoom)
    self._panY = my - (my - self._panY) * (newZoom / oldZoom)
    self._zoom = newZoom

    return true
end

-- ══════════════════════════════════════════════════════
-- 公开接口
-- ══════════════════════════════════════════════════════

--- 创建六边形世界地图
---@param state table GameState
---@param onPortClick function(portId)
function M.Create(state, onPortClick)
    return WorldMapWidget {
        id = "worldMap",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        backgroundColor = Theme.oceanDeep,
        gameState = state,
        onPortClick = onPortClick,
    }
end

return M
