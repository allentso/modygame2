-- =============================================================================
-- hex_renderer.lua
-- Stateless rendering helpers for hex_grid.lua.
-- Depends only on hex_grid.lua – no game framework assumed.
--
-- To integrate with Love2D, replace the draw_* stubs with love.graphics calls.
-- To integrate with another renderer, replace stubs with your own drawing API.
--
-- Usage:
--   local HexRenderer = require("hex_renderer")
--   local renderer    = HexRenderer.new(map, draw_api)
--   -- each frame:
--   renderer:draw_all()
-- =============================================================================

local HexRenderer = {}
HexRenderer.__index = HexRenderer

-- ── Draw API Stub ──────────────────────────────────────────────────────────────
-- Replace these with your actual renderer.
-- draw_api table expected to have:
--   draw_api.polygon(vertices, fill_color, stroke_color)
--     vertices = { {x,y}, {x,y}, ... }
--     color    = { r, g, b, a } all 0‥1
--   draw_api.print(text, x, y, color)

local DEFAULT_API = {
    polygon = function(vertices, fill, stroke)
        -- stub – replace with e.g. love.graphics.polygon
        _ = vertices; _ = fill; _ = stroke
    end,
    print = function(text, x, y, color)
        _ = text; _ = x; _ = y; _ = color
    end,
}

-- ── Color Palette ──────────────────────────────────────────────────────────────

local COLORS = {
    terrain = {
        plains   = { 0.55, 0.78, 0.40, 1 },
        forest   = { 0.18, 0.45, 0.18, 1 },
        mountain = { 0.55, 0.50, 0.45, 1 },
        water    = { 0.22, 0.52, 0.78, 1 },
        desert   = { 0.88, 0.78, 0.45, 1 },
    },
    -- FOW overlays
    explored = { 0, 0, 0, 0.45 },  -- dark semi-transparent
    hidden   = { 0, 0, 0, 0.85 },  -- nearly black

    -- Highlight layers (applied on top)
    hover        = { 1.00, 1.00, 0.60, 0.35 },
    selected     = { 1.00, 0.85, 0.10, 0.55 },
    move_range   = { 0.30, 0.75, 1.00, 0.30 },
    attack_range = { 1.00, 0.30, 0.20, 0.30 },
    path         = { 0.20, 1.00, 0.60, 0.55 },
    danger       = { 1.00, 0.20, 0.10, 0.20 },

    stroke_default  = { 0.1, 0.1, 0.1, 0.6 },
    stroke_selected = { 1.0, 0.9, 0.2, 1.0 },
}

-- ── Constructor ────────────────────────────────────────────────────────────────

---@param map       HexGrid   the map instance from hex_grid.lua
---@param draw_api  table     { polygon, print }  (optional, defaults to stub)
function HexRenderer.new(map, draw_api)
    local self = setmetatable({}, HexRenderer)
    self.map      = map
    self.api      = draw_api or DEFAULT_API

    -- Overlay sets – populated by the game layer, read by the renderer.
    -- Use set-style lookup: overlays.move_range["q,r"] = true
    self.overlays = {
        move_range   = {},   -- tiles the selected unit can reach
        attack_range = {},   -- tiles within attack range
        path         = {},   -- tiles on the current planned path
        selected     = nil,  -- { q, r } of selected tile/unit, or nil
        hover        = nil,  -- { q, r } of hovered tile, or nil
    }

    -- Danger map values (from dijkstra_map): danger[q][r] = number
    -- If set, tiles with danger < danger_threshold get a red tint.
    self.danger_map       = nil
    self.danger_threshold = 6

    return self
end

-- ── Overlay Helpers ────────────────────────────────────────────────────────────

local function overlay_key(q, r) return q .. "," .. r end

---Mark tiles as reachable (move range highlight).
---@param tiles table  array of {q,r,...} from HexGrid:movement_range()
function HexRenderer:set_move_range(tiles)
    self.overlays.move_range = {}
    for _, t in ipairs(tiles or {}) do
        self.overlays.move_range[overlay_key(t.q, t.r)] = true
    end
end

---Mark tiles as being on the current path.
---@param path table  array of {q,r} from HexGrid:find_path()
function HexRenderer:set_path(path)
    self.overlays.path = {}
    for _, t in ipairs(path or {}) do
        self.overlays.path[overlay_key(t.q, t.r)] = true
    end
end

---Clear all overlays.
function HexRenderer:clear_overlays()
    self.overlays.move_range   = {}
    self.overlays.attack_range = {}
    self.overlays.path         = {}
    self.overlays.selected     = nil
    self.overlays.hover        = nil
end

-- ── Core Draw Routines ─────────────────────────────────────────────────────────

---Draw a single hexagonal tile: terrain base + FOW + overlays.
function HexRenderer:draw_tile(q, r)
    local map     = self.map
    local tile    = map.tiles[q][r]
    local fow     = map.fow[q][r]
    local corners = map:hex_corners(q, r)
    local key     = overlay_key(q, r)

    -- ── 1. Terrain base ──
    local base_color = COLORS.terrain[tile.terrain.id] or COLORS.terrain.plains
    -- Dim terrain under explored-but-not-visible fog
    if fow == "explored" then
        base_color = self:_dim(base_color, 0.5)
    elseif fow == "hidden" then
        base_color = { 0.08, 0.08, 0.10, 1 }
    end

    local stroke = COLORS.stroke_default
    if self.overlays.selected
       and self.overlays.selected.q == q
       and self.overlays.selected.r == r then
        stroke = COLORS.stroke_selected
    end

    self.api.polygon(corners, base_color, stroke)

    -- ── 2. Overlay layers (skip hidden tiles) ──
    if fow ~= "hidden" then
        -- Danger tint (from AI influence map)
        if self.danger_map
           and self.danger_map[q]
           and self.danger_map[q][r] ~= math.huge
           and self.danger_map[q][r] < self.danger_threshold then
            self.api.polygon(corners, COLORS.danger, nil)
        end

        if self.overlays.move_range[key] then
            self.api.polygon(corners, COLORS.move_range, nil)
        end
        if self.overlays.attack_range[key] then
            self.api.polygon(corners, COLORS.attack_range, nil)
        end
        if self.overlays.path[key] then
            self.api.polygon(corners, COLORS.path, nil)
        end
    end

    -- ── 3. Hover highlight (always on top) ──
    if self.overlays.hover
       and self.overlays.hover.q == q
       and self.overlays.hover.r == r then
        self.api.polygon(corners, COLORS.hover, nil)
    end

    -- ── 4. FOW overlay ──
    if fow == "explored" then
        -- already dimmed the terrain; optionally add a subtle vignette here
    elseif fow == "hidden" then
        -- terrain already set to near-black above
    end
end

---Draw all tiles.  Call once per frame.
function HexRenderer:draw_all()
    for q = 0, self.map.width - 1 do
        for r = 0, self.map.height - 1 do
            self:draw_tile(q, r)
        end
    end
end

---Draw coordinate labels (debugging aid).
function HexRenderer:draw_debug_coords()
    for q = 0, self.map.width - 1 do
        for r = 0, self.map.height - 1 do
            local px, py = self.map:hex_to_pixel(q, r)
            self.api.print(q..","..r, px - 10, py - 5, { 1,1,1,0.7 })
        end
    end
end

-- ── Internal Helpers ───────────────────────────────────────────────────────────

function HexRenderer:_dim(color, factor)
    return { color[1]*factor, color[2]*factor, color[3]*factor, color[4] }
end

return HexRenderer
