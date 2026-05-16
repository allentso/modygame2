-- =============================================================================
-- hex_grid.lua
-- Pure-Lua axial-coordinate hex grid.
-- Drop this file into your project and require it:
--   local HexGrid = require("hex_grid")
--   local map = HexGrid.new({ width=20, height=15, hex_size=40 })
--
-- Coordinate convention: axial (q, r).  "Pointy-top" hexagons.
-- Pixel origin is top-left of the viewport.
-- =============================================================================

local HexGrid = {}
HexGrid.__index = HexGrid

-- ── Constants ──────────────────────────────────────────────────────────────────

-- Six axial directions (pointy-top), in clockwise order starting from NE.
HexGrid.DIRECTIONS = {
    { q= 1, r= 0 }, -- E
    { q= 1, r=-1 }, -- NE
    { q= 0, r=-1 }, -- NW
    { q=-1, r= 0 }, -- W
    { q=-1, r= 1 }, -- SW
    { q= 0, r= 1 }, -- SE
}

-- Terrain types – extend freely.
HexGrid.TERRAIN = {
    PLAINS  = { id="plains",  move_cost=1, blocks_los=false },
    FOREST  = { id="forest",  move_cost=2, blocks_los=true  },
    MOUNTAIN= { id="mountain",move_cost=3, blocks_los=true  },
    WATER   = { id="water",   move_cost=99,blocks_los=false },
    DESERT  = { id="desert",  move_cost=2, blocks_los=false },
}

-- ── Constructor ────────────────────────────────────────────────────────────────

---Create a new hex map.
---@param opts table  { width, height, hex_size, offset_x?, offset_y? }
---@return HexGrid
function HexGrid.new(opts)
    local self = setmetatable({}, HexGrid)

    self.width    = opts.width    or 20
    self.height   = opts.height   or 15
    self.hex_size = opts.hex_size or 40      -- pixel radius (center → vertex)
    self.offset_x = opts.offset_x or 0
    self.offset_y = opts.offset_y or 0

    -- tiles[q][r] = Tile
    self.tiles = {}

    -- Fog-of-war table: fow[q][r] = "hidden" | "explored" | "visible"
    self.fow = {}

    -- Registered event listeners: { click=[], hover=[], right_click=[] }
    self._listeners = { click={}, hover={}, right_click={} }

    -- Internal: last hovered tile (for change-detection)
    self._last_hover = nil

    self:_init_tiles()
    return self
end

-- ── Tile Initialization ────────────────────────────────────────────────────────

---Populate self.tiles with default flat-plains tiles.
---Call map:set_terrain(q,r,terrain) afterwards to paint terrain.
function HexGrid:_init_tiles()
    for q = 0, self.width - 1 do
        self.tiles[q] = {}
        self.fow[q]   = {}
        for r = 0, self.height - 1 do
            self.tiles[q][r] = {
                q        = q,
                r        = r,
                terrain  = HexGrid.TERRAIN.PLAINS,
                -- game data – attach whatever your sim needs:
                unit     = nil,   -- reference to a unit table
                building = nil,   -- reference to a building table
                resource = nil,   -- e.g. { type="iron", amount=5 }
                owner    = nil,   -- player id
            }
            self.fow[q][r] = "hidden"
        end
    end
end

-- ── Coordinate Helpers ─────────────────────────────────────────────────────────

---Check whether (q,r) is inside the map bounds.
function HexGrid:in_bounds(q, r)
    return q >= 0 and q < self.width and r >= 0 and r < self.height
end

---Axial distance between two hexes.
function HexGrid.distance(q1, r1, q2, r2)
    return (math.abs(q1 - q2)
          + math.abs(q1 + r1 - q2 - r2)
          + math.abs(r1 - r2)) / 2
end

---Return table of valid in-bounds neighbors of (q,r).
function HexGrid:neighbors(q, r)
    local result = {}
    for _, d in ipairs(HexGrid.DIRECTIONS) do
        local nq, nr = q + d.q, r + d.r
        if self:in_bounds(nq, nr) then
            result[#result+1] = self.tiles[nq][nr]
        end
    end
    return result
end

-- ── Pixel ↔ Hex Conversion ─────────────────────────────────────────────────────

---Convert axial (q,r) to screen pixel (px, py). Pointy-top layout.
function HexGrid:hex_to_pixel(q, r)
    local size = self.hex_size
    local px = size * (math.sqrt(3) * q + math.sqrt(3)/2 * r) + self.offset_x
    local py = size * (                              3/2 * r) + self.offset_y
    return px, py
end

---Convert screen pixel (px,py) to the nearest hex (q,r).
---Returns q, r (may be out of bounds – caller should check in_bounds).
function HexGrid:pixel_to_hex(px, py)
    local size = self.hex_size
    local x = (px - self.offset_x) / size
    local y = (py - self.offset_y) / size
    -- fractional axial coordinates
    local fq =  math.sqrt(3)/3 * x - 1/3 * y
    local fr =                        2/3 * y
    return self:_axial_round(fq, fr)
end

---Round fractional axial coordinates to the nearest integer hex.
function HexGrid:_axial_round(fq, fr)
    local fs = -fq - fr
    local rq, rr, rs = math.floor(fq+0.5), math.floor(fr+0.5), math.floor(fs+0.5)
    local dq = math.abs(rq - fq)
    local dr = math.abs(rr - fr)
    local ds = math.abs(rs - fs)
    if dq > dr and dq > ds then
        rq = -rr - rs
    elseif dr > ds then
        rr = -rq - rs
    end
    return rq, rr
end

---Return the six corner pixel positions of the hex at (q,r), for drawing.
function HexGrid:hex_corners(q, r)
    local cx, cy = self:hex_to_pixel(q, r)
    local size   = self.hex_size
    local corners = {}
    for i = 0, 5 do
        local angle = math.pi / 180 * (60 * i - 30) -- pointy-top
        corners[i+1] = {
            x = cx + size * math.cos(angle),
            y = cy + size * math.sin(angle),
        }
    end
    return corners
end

-- ── Terrain API ────────────────────────────────────────────────────────────────

---Set the terrain of a tile.  terrain = one of HexGrid.TERRAIN values.
function HexGrid:set_terrain(q, r, terrain)
    assert(self:in_bounds(q,r), "set_terrain: out of bounds")
    self.tiles[q][r].terrain = terrain
end

---Get the tile at (q,r), or nil if out of bounds.
function HexGrid:get_tile(q, r)
    if not self:in_bounds(q, r) then return nil end
    return self.tiles[q][r]
end

-- ── Pathfinding (A*) ───────────────────────────────────────────────────────────
--
-- Usage:
--   local path = map:find_path(0,0, 5,5)
--   -- path = { {q,r}, {q,r}, ... } from start (exclusive) to goal (inclusive)
--   -- path = nil if unreachable
--
-- The heuristic is hex distance; move cost comes from tile.terrain.move_cost.
-- Water and tiles occupied by enemy units are treated as impassable by default.
-- Override map.is_passable(tile, mover) to customise.

---Default passability check.  Override to add unit-blocking logic.
function HexGrid:is_passable(tile, _mover)
    return tile.terrain.move_cost < 99
end

---A* pathfinding.  Returns array of {q,r} tables or nil.
---@param sq number  start q
---@param sr number  start r
---@param eq number  goal  q
---@param er number  goal  r
---@param mover any  passed to is_passable (optional, for unit context)
function HexGrid:find_path(sq, sr, eq, er, mover)
    if not self:in_bounds(sq,sr) or not self:in_bounds(eq,er) then return nil end

    -- min-heap implemented as a sorted list (small maps don't need a binary heap)
    local open   = {}
    local closed = {}
    local g      = {}   -- g[key] = cost from start
    local parent = {}   -- parent[key] = {q,r}

    local function key(q,r) return q * 1000 + r end
    local function heuristic(q,r) return HexGrid.distance(q,r,eq,er) end
    local function insert_open(q, r, f)
        local node = { q=q, r=r, f=f }
        local inserted = false
        for i, n in ipairs(open) do
            if f < n.f then
                table.insert(open, i, node)
                inserted = true
                break
            end
        end
        if not inserted then open[#open+1] = node end
    end

    local sk = key(sq, sr)
    g[sk]      = 0
    parent[sk] = nil
    insert_open(sq, sr, heuristic(sq,sr))

    while #open > 0 do
        local current = table.remove(open, 1)
        local cq, cr  = current.q, current.r
        local ck       = key(cq, cr)

        if cq == eq and cr == er then
            -- Reconstruct path
            local path = {}
            local k = ck
            while parent[k] do
                local p = parent[k]
                table.insert(path, 1, { q = p.q_to, r = p.r_to })
                k = key(p.q_from, p.r_from)
            end
            path[#path+1] = { q=eq, r=er }
            return path
        end

        if not closed[ck] then
            closed[ck] = true
            for _, nb in ipairs(self:neighbors(cq, cr)) do
                local nk = key(nb.q, nb.r)
                if not closed[nk] and self:is_passable(nb, mover) then
                    local ng = g[ck] + nb.terrain.move_cost
                    if not g[nk] or ng < g[nk] then
                        g[nk]      = ng
                        parent[nk] = { q_from=cq, r_from=cr, q_to=nb.q, r_to=nb.r }
                        insert_open(nb.q, nb.r, ng + heuristic(nb.q, nb.r))
                    end
                end
            end
        end
    end

    return nil  -- no path found
end

-- ── Movement Range (BFS) ───────────────────────────────────────────────────────
--
-- Usage:
--   local reachable = map:movement_range(q, r, move_points)
--   -- reachable = { {q,r,cost}, ... }

---Return all tiles reachable within move_points from (sq,sr).
function HexGrid:movement_range(sq, sr, move_points, mover)
    local visited = {}  -- key → cost
    local result  = {}
    local queue   = { { q=sq, r=sr, cost=0 } }
    local function key(q,r) return q * 1000 + r end

    visited[key(sq,sr)] = 0

    while #queue > 0 do
        local cur = table.remove(queue, 1)
        result[#result+1] = { q=cur.q, r=cur.r, cost=cur.cost }

        for _, nb in ipairs(self:neighbors(cur.q, cur.r)) do
            local nk      = key(nb.q, nb.r)
            local new_cost = cur.cost + nb.terrain.move_cost
            if new_cost <= move_points
               and (not visited[nk] or visited[nk] > new_cost)
               and self:is_passable(nb, mover) then
                visited[nk] = new_cost
                queue[#queue+1] = { q=nb.q, r=nb.r, cost=new_cost }
            end
        end
    end

    return result
end

-- ── Line of Sight (Bresenham on Hex) ──────────────────────────────────────────
--
-- Usage:
--   local visible = map:has_los(0,0, 5,5)   → true/false

---Linearly interpolate between two hex centers, sample terrain along the way.
---Returns true if there is a clear line of sight.
function HexGrid:has_los(q1, r1, q2, r2)
    local n = math.max(1, HexGrid.distance(q1,r1,q2,r2))
    for i = 0, n do
        local t  = i / n
        local fq = q1 + (q2 - q1) * t
        local fr = r1 + (r2 - r1) * t
        -- nudge to avoid integer boundaries causing ambiguous rounding
        local sq, sr = self:_axial_round(fq + 1e-6, fr + 1e-6)
        if self:in_bounds(sq, sr) then
            local tile = self.tiles[sq][sr]
            if i > 0 and i < n and tile.terrain.blocks_los then
                return false
            end
        end
    end
    return true
end

-- ── Fog of War ─────────────────────────────────────────────────────────────────
--
-- Usage:
--   map:update_fow({ { q=2, r=3, sight=4 }, ... })   -- list of sighted units
--   map.fow[q][r]  → "visible" | "explored" | "hidden"

---Reset all "visible" tiles back to "explored", then recompute for all units.
---@param units table  array of { q, r, sight } – one entry per sighted unit.
function HexGrid:update_fow(units)
    -- Reset visible → explored
    for q = 0, self.width-1 do
        for r = 0, self.height-1 do
            if self.fow[q][r] == "visible" then
                self.fow[q][r] = "explored"
            end
        end
    end

    -- Recompute visibility for each unit
    for _, u in ipairs(units) do
        local uq, ur, sight = u.q, u.r, u.sight
        for dq = -sight, sight do
            for dr = -sight, sight do
                local tq, tr = uq+dq, ur+dr
                if self:in_bounds(tq, tr)
                   and HexGrid.distance(uq, ur, tq, tr) <= sight
                   and self:has_los(uq, ur, tq, tr) then
                    self.fow[tq][tr] = "visible"
                end
            end
        end
    end
end

-- ── Input Event System ─────────────────────────────────────────────────────────
--
-- Wire up your framework's mouse callbacks to:
--   map:on_mouse_press(px, py, button)
--   map:on_mouse_move(px, py)
--
-- Then register listeners:
--   map:on("click",       function(tile) ... end)
--   map:on("right_click", function(tile) ... end)
--   map:on("hover",       function(tile, prev_tile) ... end)

---Register an event listener.
---@param event string  "click" | "right_click" | "hover"
---@param fn    function
function HexGrid:on(event, fn)
    assert(self._listeners[event], "Unknown event: " .. tostring(event))
    self._listeners[event][#self._listeners[event]+1] = fn
end

---Fire all listeners for an event.
function HexGrid:_emit(event, ...)
    for _, fn in ipairs(self._listeners[event]) do
        fn(...)
    end
end

---Call this from your framework's mousepressed / pointerdown callback.
---button: 1 = left, 2 = right (Love2D convention)
function HexGrid:on_mouse_press(px, py, button)
    local q, r = self:pixel_to_hex(px, py)
    if not self:in_bounds(q, r) then return end
    local tile = self.tiles[q][r]
    if button == 1 then
        self:_emit("click", tile)
    elseif button == 2 then
        self:_emit("right_click", tile)
    end
end

---Call this from your framework's mousemoved / pointermove callback.
function HexGrid:on_mouse_move(px, py)
    local q, r = self:pixel_to_hex(px, py)
    if not self:in_bounds(q, r) then return end
    local tile = self.tiles[q][r]
    local last = self._last_hover
    if not last or last.q ~= q or last.r ~= r then
        self._last_hover = tile
        self:_emit("hover", tile, last)
    end
end

-- ── Dijkstra Influence Map ─────────────────────────────────────────────────────
-- Useful for AI: compute "cost distance from all enemy units" in one pass,
-- then any friendly unit can look up threat[q][r] to evaluate a tile.
--
-- Usage:
--   local threat = map:dijkstra_map(sources)
--   -- sources = { {q,r}, ... }
--   -- threat[q][r] = number (distance in movement cost, math.huge if unreachable)

function HexGrid:dijkstra_map(sources)
    local dist = {}
    local queue = {}
    for q = 0, self.width-1 do
        dist[q] = {}
        for r = 0, self.height-1 do
            dist[q][r] = math.huge
        end
    end
    for _, src in ipairs(sources) do
        dist[src.q][src.r] = 0
        queue[#queue+1]    = { q=src.q, r=src.r, d=0 }
    end
    -- Simple priority queue via sorted insert (good enough for typical map sizes)
    table.sort(queue, function(a,b) return a.d < b.d end)
    local head = 1
    while head <= #queue do
        local cur = queue[head]; head = head + 1
        for _, nb in ipairs(self:neighbors(cur.q, cur.r)) do
            local nd = cur.d + nb.terrain.move_cost
            if nd < dist[nb.q][nb.r] then
                dist[nb.q][nb.r] = nd
                -- Insert in sorted order
                local node = { q=nb.q, r=nb.r, d=nd }
                local pos  = #queue + 1
                for i = head, #queue do
                    if queue[i].d > nd then pos = i; break end
                end
                table.insert(queue, pos, node)
            end
        end
    end
    return dist
end

-- ── Serialization ──────────────────────────────────────────────────────────────
-- Minimal save/load so your simulation state can be persisted.

---Export the map to a plain Lua table (JSON-friendly structure).
function HexGrid:export()
    local data = { width=self.width, height=self.height,
                   hex_size=self.hex_size,
                   tiles={}, fow={} }
    for q = 0, self.width-1 do
        data.tiles[q] = {}
        data.fow[q]   = {}
        for r = 0, self.height-1 do
            local t = self.tiles[q][r]
            data.tiles[q][r] = {
                terrain  = t.terrain.id,
                owner    = t.owner,
                resource = t.resource,
                -- units/buildings are runtime objects; re-attach after loading
            }
            data.fow[q][r] = self.fow[q][r]
        end
    end
    return data
end

---Restore a map from a previously exported table.
function HexGrid:import(data)
    local terrain_by_id = {}
    for _, v in pairs(HexGrid.TERRAIN) do terrain_by_id[v.id] = v end

    for q = 0, self.width-1 do
        for r = 0, self.height-1 do
            local d = data.tiles[q] and data.tiles[q][r]
            if d then
                self.tiles[q][r].terrain  = terrain_by_id[d.terrain] or HexGrid.TERRAIN.PLAINS
                self.tiles[q][r].owner    = d.owner
                self.tiles[q][r].resource = d.resource
            end
            if data.fow[q] then
                self.fow[q][r] = data.fow[q][r] or "hidden"
            end
        end
    end
end

return HexGrid
