-- =============================================================================
-- sail_and_iron_renderer.lua
-- GDD-specific rendering layer on top of hex_renderer.lua
-- Handles: faction territory color, trade route arcs, resource icons,
--          maritime control heat-map, colonial control gradient
-- =============================================================================

local HexRenderer = require("hex_renderer")

local SailRenderer = {}
SailRenderer.__index = SailRenderer

-- ── Faction Color Palette (GDD §19.2) ─────────────────────────────────────────

local FACTION_COLORS = {
    hawkins  = { 0.20, 0.50, 0.90, 0.45 },  -- Blue (England)
    van_der_hel = { 1.00, 0.80, 0.10, 0.45 },-- Gold (Holland)
    dubois   = { 0.85, 0.15, 0.20, 0.45 },  -- Red  (France)
    castro   = { 0.10, 0.60, 0.35, 0.45 },  -- Green (Portugal)
    braun    = { 0.55, 0.55, 0.55, 0.45 },  -- Gray (Prussia)
    colonna  = { 0.65, 0.25, 0.65, 0.45 },  -- Purple (Venice)
}
-- Fallback for unknown factions
local FACTION_DEFAULT = { 0.80, 0.80, 0.80, 0.35 }

-- Resource icon characters (for text-based renderers / debug display)
local RESOURCE_ICONS = {
    sugar   = "☆",  cotton = "≈",  tobacco = "~",
    silver  = "$",  iron   = "▲",  coal    = "■",
    spice   = "✦",  timber = "↑",
}

-- ── Constructor ────────────────────────────────────────────────────────────────

---@param sail_map  SailAndIronMap
---@param draw_api  table  { polygon, line, print, arc? }
function SailRenderer.new(sail_map, draw_api)
    local self = setmetatable({}, SailRenderer)
    self.sail_map = sail_map
    self.grid_renderer = HexRenderer.new(sail_map:get_grid(), draw_api)
    self.api = draw_api

    -- Display mode: "normal" | "wealth" | "influence" | "colonial"
    self.heat_map_mode = "normal"

    -- Overlay flags
    self.show_resources   = true
    self.show_routes      = true
    self.show_maritime    = false   -- maritime control heat-map toggle
    self.player_faction   = nil     -- e.g. "hawkins"

    return self
end

-- ── Main Draw Entry Point ──────────────────────────────────────────────────────

---Draw everything. Call once per frame.
function SailRenderer:draw_all()
    local map  = self.sail_map
    local grid = map:get_grid()

    -- 1. Base tiles + FOW + standard overlays
    self.grid_renderer:draw_all()

    -- 2. Faction territory tint (on top of terrain)
    self:draw_territory_tint()

    -- 3. Resource icons
    if self.show_resources then
        self:draw_resource_icons()
    end

    -- 4. Trade route arcs
    if self.show_routes then
        self:draw_trade_routes()
    end

    -- 5. Maritime heat-map (optional toggle)
    if self.show_maritime then
        self:draw_maritime_heatmap()
    end

    -- 6. Colony control bars (mini progress bar per colony hex)
    self:draw_colony_control_bars()
end

-- ── Territory Tint ─────────────────────────────────────────────────────────────
-- Overlay each tile with the dominant faction's color at partial opacity.
-- Intensity = control_degree / 100.

function SailRenderer:draw_territory_tint()
    local map  = self.sail_map
    local grid = map:get_grid()

    for q = 0, grid.width-1 do
        for r = 0, grid.height-1 do
            if grid.fow[q][r] ~= "hidden" then
                local tile    = grid.tiles[q][r]
                local corners = grid:hex_corners(q, r)

                -- Find dominant controlling faction
                local best_faction, best_ctrl = nil, 0
                for fid, ctrl in pairs(tile.control or {}) do
                    if ctrl > best_ctrl then
                        best_ctrl   = ctrl
                        best_faction = fid
                    end
                end

                if best_faction and best_ctrl > 10 then
                    local base_color = FACTION_COLORS[best_faction] or FACTION_DEFAULT
                    local alpha      = base_color[4] * (best_ctrl / 100)
                    local tint       = { base_color[1], base_color[2], base_color[3], alpha }
                    self.api.polygon(corners, tint, nil)
                end
            end
        end
    end
end

-- ── Resource Icons ─────────────────────────────────────────────────────────────
-- Draw resource type icon at tile center for explored tiles with resources.

function SailRenderer:draw_resource_icons()
    local map  = self.sail_map
    local grid = map:get_grid()

    for q = 0, grid.width-1 do
        for r = 0, grid.height-1 do
            if grid.fow[q][r] == "visible" then
                local tile = grid.tiles[q][r]
                if tile.resource then
                    local px, py = grid:hex_to_pixel(q, r)
                    local icon   = RESOURCE_ICONS[tile.resource.id] or "?"
                    -- Richness-based color: dim for low, bright for high
                    local bright = tile.resource_amt / 100
                    local color  = { bright, bright * 0.8, 0.2, 0.9 }
                    self.api.print(icon, px - 6, py - 6, color)
                end
            end
        end
    end
end

-- ── Trade Route Arcs ──────────────────────────────────────────────────────────
-- Draw each trade route as a sequence of highlighted hex edges
-- or, if api.arc is available, as a smooth Bezier arc.
-- Colour = faction colour; alpha varies with route safety.

function SailRenderer:draw_trade_routes()
    local map  = self.sail_map
    local grid = map:get_grid()
    local api  = self.api

    for route_id, route in pairs(map.route_paths) do
        if #route.path < 2 then goto continue end

        local faction_color = FACTION_COLORS[route.faction_id] or FACTION_DEFAULT
        local safety = map:route_safety(route_id, route.faction_id)
        -- Unsafe routes shown in orange/red; safe routes in faction color
        local route_color
        if safety >= 0.95 then
            route_color = { faction_color[1], faction_color[2], faction_color[3], 0.8 }
        elseif safety >= 0.85 then
            route_color = { 1.0, 0.65, 0.0, 0.8 }   -- orange: moderate risk
        else
            route_color = { 0.9, 0.2, 0.2, 0.8 }    -- red: high risk
        end

        -- Draw hex-to-hex dashed line along the path
        -- (Replace with arc/bezier if your renderer supports it)
        for i = 2, #route.path do
            local a  = route.path[i-1]
            local b  = route.path[i]
            local ax, ay = grid:hex_to_pixel(a.q, a.r)
            local bx, by = grid:hex_to_pixel(b.q, b.r)
            -- api.line is a suggested extension – add to your draw_api
            if api.line then
                api.line(ax, ay, bx, by, route_color, 2)
            end
        end

        -- Route endpoint icons (from / to)
        local first = route.path[1]
        local last  = route.path[#route.path]
        if first and api.print then
            local px, py = grid:hex_to_pixel(first.q, first.r)
            api.print("⚓", px - 7, py - 7, route_color)
        end
        if last and api.print then
            local px, py = grid:hex_to_pixel(last.q, last.r)
            api.print("⚑", px - 5, py - 7, route_color)
        end

        ::continue::
    end
end

-- ── Maritime Heat-map ─────────────────────────────────────────────────────────
-- §19.2 GDD calls for "影响力热力图" toggle.
-- Each sea hex is tinted by its maritime controller.

function SailRenderer:draw_maritime_heatmap()
    local map  = self.sail_map
    local grid = map:get_grid()

    for q = 0, grid.width-1 do
        for r = 0, grid.height-1 do
            local tile = grid.tiles[q][r]
            if tile.tile_type and tile.tile_type.is_sea
               and grid.fow[q][r] ~= "hidden" then
                local ctrl_faction, dist = map:maritime_controller(q, r)
                if ctrl_faction then
                    local base = FACTION_COLORS[ctrl_faction] or FACTION_DEFAULT
                    -- Fade out at the edges of control (dist 0=strong, 8=weak)
                    local alpha  = math.max(0, 0.5 - dist * 0.05)
                    local color  = { base[1], base[2], base[3], alpha }
                    local corners = grid:hex_corners(q, r)
                    self.api.polygon(corners, color, nil)
                end
            end
        end
    end
end

-- ── Colony Control Bars ───────────────────────────────────────────────────────
-- Draw a tiny horizontal bar at the bottom of each colony hex
-- showing control degree. Color = dominant faction's hue.

function SailRenderer:draw_colony_control_bars()
    local map  = self.sail_map
    local grid = map:get_grid()
    local api  = self.api
    if not api.rect then return end   -- requires api.rect(x,y,w,h,color)

    for q = 0, grid.width-1 do
        for r = 0, grid.height-1 do
            local tile = grid.tiles[q][r]
            if tile.colony_id and grid.fow[q][r] ~= "hidden" then
                local px, py = grid:hex_to_pixel(q, r)
                local bar_w  = grid.hex_size * 0.9
                local bar_h  = 4
                local bx     = px - bar_w / 2
                local by     = py + grid.hex_size * 0.6

                -- Background bar
                api.rect(bx, by, bar_w, bar_h, { 0.1, 0.1, 0.1, 0.7 })

                -- Per-faction segments
                local total_ctrl = 0
                for _, ctrl in pairs(tile.control) do total_ctrl = total_ctrl + ctrl end
                total_ctrl = math.max(1, total_ctrl)

                local offset = 0
                for fid, ctrl in pairs(tile.control) do
                    local seg_w = bar_w * (ctrl / total_ctrl)
                    local col   = FACTION_COLORS[fid] or FACTION_DEFAULT
                    api.rect(bx + offset, by, seg_w, bar_h,
                             { col[1], col[2], col[3], 0.9 })
                    offset = offset + seg_w
                end

                -- Resistance indicator (red dot if > 50)
                if tile.resistance > 50 and api.print then
                    api.print("⚡", px - 4, by - 10, { 1, 0.3, 0.2, 0.9 })
                end
            end
        end
    end
end

-- ── Overlay Shortcuts (wraps grid_renderer) ───────────────────────────────────

function SailRenderer:set_move_range(tiles)    self.grid_renderer:set_move_range(tiles) end
function SailRenderer:set_path(path)           self.grid_renderer:set_path(path) end
function SailRenderer:clear_overlays()         self.grid_renderer:clear_overlays() end

function SailRenderer:set_hover(tile)
    self.grid_renderer.overlays.hover    = tile
end
function SailRenderer:set_selected(tile)
    self.grid_renderer.overlays.selected = tile
end

return SailRenderer
