-- =============================================================================
-- main_example.lua
-- Minimal wiring example: connect hex_grid.lua + hex_renderer.lua
-- to your existing simulation logic.
--
-- This file is written for Love2D but the pattern works for any framework.
-- Replace the love.* calls with your engine's equivalents.
--
-- AI CODING HINT: The three sections marked "── YOUR SIM ──" are where you
-- plug in your existing simulation tables.  Everything else is map/UI plumbing.
-- =============================================================================

local HexGrid    = require("hex_grid")
local HexRenderer= require("hex_renderer")

-- ── YOUR SIM: import your existing data here ───────────────────────────────────
-- local Sim = require("your_simulation")

-- ── Map & Renderer Setup ───────────────────────────────────────────────────────

local map      -- HexGrid instance
local renderer -- HexRenderer instance

-- State for the interaction layer
local state = {
    selected_tile  = nil,   -- tile the player has clicked
    selected_unit  = nil,   -- unit on that tile (nil if empty)
    move_range     = {},    -- reachable tiles for selected unit
    path_preview   = {},    -- path from selected unit to hovered tile
    hover_tile     = nil,   -- tile under the mouse cursor
    turn_units     = {},    -- units that have acted this turn (greyed out)
}

-- ── Love2D Draw API adapter ────────────────────────────────────────────────────
-- Swap this block for your own renderer adapter.

local function make_love2d_api()
    return {
        polygon = function(corners, fill, stroke)
            local verts = {}
            for _, c in ipairs(corners) do
                verts[#verts+1] = c.x
                verts[#verts+1] = c.y
            end
            if fill then
                love.graphics.setColor(fill)
                love.graphics.polygon("fill", verts)
            end
            if stroke then
                love.graphics.setColor(stroke)
                love.graphics.polygon("line", verts)
            end
        end,
        print = function(text, x, y, color)
            love.graphics.setColor(color or {1,1,1,1})
            love.graphics.print(text, x, y)
        end,
    }
end

-- ── Terrain Painting ───────────────────────────────────────────────────────────
-- Replace with your procedural generator or loaded map data.

local function paint_example_terrain(m)
    local T = HexGrid.TERRAIN
    -- Islands of forest
    for _, pos in ipairs({ {2,1},{2,2},{3,2},{3,1},{4,2} }) do
        if m:in_bounds(pos[1], pos[2]) then m:set_terrain(pos[1],pos[2],T.FOREST) end
    end
    -- Mountain range
    for r = 4, 8 do
        if m:in_bounds(7, r) then m:set_terrain(7, r, T.MOUNTAIN) end
    end
    -- River
    for q = 0, 6 do
        if m:in_bounds(q, 10) then m:set_terrain(q, 10, T.WATER) end
    end
    -- Desert patch
    for q = 12, 16 do
        for r = 2, 5 do
            if m:in_bounds(q, r) then m:set_terrain(q, r, T.DESERT) end
        end
    end
end

-- ── Unit Stubs ─────────────────────────────────────────────────────────────────
-- Replace with your actual unit objects from your simulation.

local function make_demo_units()
    return {
        { q=1,  r=1, sight=4, move=3, owner=1, name="Warrior" },
        { q=3,  r=5, sight=3, move=2, owner=1, name="Settler" },
        { q=10, r=6, sight=4, move=4, owner=2, name="Enemy"   },
    }
end

-- ── Interaction Helpers ────────────────────────────────────────────────────────

---Select a tile: compute move range and clear path preview.
local function select_tile(tile)
    state.selected_tile = tile
    state.path_preview  = {}

    -- Find unit on tile (adapt to your sim's unit lookup)
    state.selected_unit = tile.unit  -- set by your sim when a unit occupies the tile

    renderer.overlays.selected = tile
    renderer:set_path({})

    if state.selected_unit then
        local move_pts = state.selected_unit.move or 3
        state.move_range = map:movement_range(tile.q, tile.r, move_pts)
        renderer:set_move_range(state.move_range)
    else
        state.move_range = {}
        renderer:set_move_range({})
    end
end

---Deselect everything.
local function deselect()
    state.selected_tile = nil
    state.selected_unit = nil
    state.move_range    = {}
    state.path_preview  = {}
    renderer:clear_overlays()
end

---On hover: show path preview if a unit is selected.
local function on_hover(tile, _prev)
    state.hover_tile           = tile
    renderer.overlays.hover    = tile

    if state.selected_unit then
        -- Compute path from selected unit to hovered tile
        local su = state.selected_unit
        local path = map:find_path(su.q, su.r, tile.q, tile.r)
        state.path_preview = path or {}
        renderer:set_path(state.path_preview)
    end
end

---On left-click.
local function on_click(tile)
    if state.selected_unit then
        -- ── YOUR SIM: issue a move order ──────────────────────────────────────
        -- If the tile is reachable, move the unit there.
        local function is_in_range(t)
            for _, r in ipairs(state.move_range) do
                if r.q == t.q and r.r == t.r then return true end
            end
            return false
        end
        if is_in_range(tile) then
            -- Move unit in your simulation:
            -- Sim:move_unit(state.selected_unit, tile.q, tile.r)
            -- Then update the tile references:
            local u = state.selected_unit
            map:get_tile(u.q, u.r).unit = nil   -- vacate old tile
            u.q = tile.q;  u.r = tile.r         -- update unit position
            tile.unit = u                        -- occupy new tile

            -- Refresh FOW after move
            map:update_fow(demo_units)

            deselect()
        else
            -- Clicked outside range – reselect the new tile
            deselect()
            select_tile(tile)
        end
    else
        -- Nothing selected yet – select this tile
        select_tile(tile)
    end
end

---On right-click: cancel selection.
local function on_right_click(_tile)
    deselect()
end

-- ── Love2D Lifecycle ───────────────────────────────────────────────────────────

local demo_units  -- forward reference

function love.load()
    -- 1. Create map
    map = HexGrid.new({
        width    = 20,
        height   = 15,
        hex_size = 36,
        offset_x = 50,
        offset_y = 50,
    })

    -- 2. Paint terrain
    paint_example_terrain(map)

    -- 3. Place demo units onto tiles
    demo_units = make_demo_units()
    for _, u in ipairs(demo_units) do
        local tile = map:get_tile(u.q, u.r)
        if tile then tile.unit = u end
    end

    -- 4. Initial FOW
    map:update_fow(demo_units)

    -- 5. Create renderer
    renderer = HexRenderer.new(map, make_love2d_api())

    -- 6. Wire input events
    map:on("click",       on_click)
    map:on("right_click", on_right_click)
    map:on("hover",       on_hover)

    -- 7. (Optional) build AI danger map from enemy units
    local enemies = {}
    for _, u in ipairs(demo_units) do
        if u.owner == 2 then enemies[#enemies+1] = u end
    end
    renderer.danger_map = map:dijkstra_map(enemies)
end

function love.draw()
    -- ── YOUR SIM: draw anything behind the map here ──

    renderer:draw_all()

    -- Draw unit sprites on top of tiles (adapt to your asset pipeline)
    for _, u in ipairs(demo_units) do
        local px, py = map:hex_to_pixel(u.q, u.r)
        love.graphics.setColor(u.owner == 1 and {0.3,0.6,1,1} or {1,0.3,0.3,1})
        love.graphics.circle("fill", px, py, 10)
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(u.name:sub(1,1), px - 4, py - 7)
    end

    -- Debug: toggle with a key
    if love.keyboard.isDown("d") then
        renderer:draw_debug_coords()
    end

    -- ── YOUR SIM: draw UI / HUD on top here ──
    love.graphics.setColor(1,1,1,1)
    if state.selected_tile then
        local t = state.selected_tile
        love.graphics.print(
            string.format("Selected: (%d,%d)  terrain: %s%s",
                t.q, t.r, t.terrain.id,
                t.unit and ("  unit: "..t.unit.name) or ""),
            10, 10)
    else
        love.graphics.print("Click a tile to select.  Right-click to deselect.", 10, 10)
    end
end

function love.mousepressed(x, y, button)
    map:on_mouse_press(x, y, button)
end

function love.mousemoved(x, y)
    map:on_mouse_move(x, y)
end

function love.keypressed(key)
    if key == "escape" then deselect() end
    if key == "n" then
        -- ── YOUR SIM: advance turn ────────────────────────────────────────────
        -- Reset unit movement points, advance game clock, etc.
        -- Sim:next_turn()
        -- Refresh FOW and danger map
        map:update_fow(demo_units)
        local enemies = {}
        for _, u in ipairs(demo_units) do
            if u.owner == 2 then enemies[#enemies+1] = u end
        end
        renderer.danger_map = map:dijkstra_map(enemies)
    end
end

-- =============================================================================
-- NON-LOVE2D USAGE (headless, for AI / unit tests, text-based sims)
-- Comment out the love.* block above and use this instead:
-- =============================================================================
--[[

local map = HexGrid.new({ width=10, height=8, hex_size=1 })
-- paint terrain ...

-- Pathfind
local path = map:find_path(0,0, 5,5)
if path then
    for _, p in ipairs(path) do
        print(string.format("  → (%d,%d)", p.q, p.r))
    end
end

-- Movement range
local reachable = map:movement_range(2, 2, 4)
print("Reachable tiles:", #reachable)

-- FOW update
map:update_fow({{ q=2, r=2, sight=4 }})
print("FOW at 4,4:", map.fow[4][4])

-- Danger map
local danger = map:dijkstra_map({{ q=8, r=7 }})
print("Threat distance from enemy to 0,0:", danger[0][0])

--]]
