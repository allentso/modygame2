-- =============================================================================
-- sail_and_iron_map.lua
-- GDD-specific map layer on top of hex_grid.lua
-- Connects § 10 地块系统, § 11 殖民系统, § 12 海军系统
-- =============================================================================

local HexGrid = require("hex_grid")

-- ── § 10  地块类型定义 ────────────────────────────────────────────────────────
-- Extends hex_grid TERRAIN to cover the GDD's sea / colonial / port types.

local TILE_TYPE = {
    -- Land tiles (对应 GDD § 10 资源地块)
    PLAINS   = { id="plains",  move_cost=1, blocks_los=false, is_sea=false },
    FOREST   = { id="forest",  move_cost=2, blocks_los=true,  is_sea=false },
    MOUNTAIN = { id="mountain",move_cost=3, blocks_los=true,  is_sea=false },
    DESERT   = { id="desert",  move_cost=2, blocks_los=false, is_sea=false },
    -- Sea tiles (舰船专用，陆地单位不可通行)
    SEA      = { id="sea",     move_cost=1, blocks_los=false, is_sea=true  },
    COASTAL  = { id="coastal", move_cost=1, blocks_los=false, is_sea=true  },
    -- Special
    PORT     = { id="port",    move_cost=1, blocks_los=false, is_sea=false },
    COLONY   = { id="colony",  move_cost=1, blocks_los=false, is_sea=false },
}

-- § 10 资源类型 → 对应 GDD § 6.2 贸易品
local RESOURCE = {
    SUGAR   = { id="sugar",   base_value=40, good_type="colonial_crop" },
    COTTON  = { id="cotton",  base_value=25, good_type="colonial_crop" },
    TOBACCO = { id="tobacco", base_value=30, good_type="colonial_crop" },
    SILVER  = { id="silver",  base_value=50, good_type="precious_metal" },
    IRON    = { id="iron",    base_value=15, good_type="industrial"     },
    COAL    = { id="coal",    base_value=12, good_type="industrial"     },
    SPICE   = { id="spice",   base_value=60, good_type="luxury"         },
    TIMBER  = { id="timber",  base_value=10, good_type="naval"          },
}

-- ── Map Factory ────────────────────────────────────────────────────────────────

local SailAndIronMap = {}
SailAndIronMap.__index = SailAndIronMap

---Create the game map. Injects GDD-specific fields into every tile.
---@param opts table  { width, height, hex_size, offset_x, offset_y }
function SailAndIronMap.new(opts)
    local self = setmetatable({}, SailAndIronMap)

    -- Core hex grid (coordinates, pathfinding, FOW, events)
    self.grid = HexGrid.new(opts)

    -- Override terrain vocabulary with our extended set
    self.TILE_TYPE = TILE_TYPE
    self.RESOURCE  = RESOURCE

    -- Inject GDD business fields into every tile
    self:_inject_gdd_fields()

    -- Trade route paths stored here: route_id → array of {q,r}
    self.route_paths = {}

    -- Maritime control: faction_id → dijkstra dist table
    self.maritime_zones = {}

    -- Colonial control summary: { q,r } → { faction_id, control_degree }
    self.colonial_control = {}

    return self
end

---Inject GDD-specific fields into all tiles (called once at init).
function SailAndIronMap:_inject_gdd_fields()
    local g = self.grid
    for q = 0, g.width-1 do
        for r = 0, g.height-1 do
            local t = g.tiles[q][r]

            -- § 10 地块字段
            t.tile_type     = TILE_TYPE.PLAINS   -- overwritten by map gen
            t.resource      = nil                -- RESOURCE.* or nil
            t.resource_amt  = 0                  -- richness (0-100)

            -- § 11 殖民字段
            t.colony_id     = nil    -- string key if a colony exists here
            t.control       = {}     -- { faction_id → degree (0-100) }
            t.resistance    = 0      -- 抵抗运动强度

            -- § 12 海军 / 贸易
            t.port_level    = 0      -- 0=无港口, 1-3=港口等级
            t.fleet         = {}     -- list of fleet references docked here
            t.trade_routes  = {}     -- list of route_ids passing through

            -- § 16 事件
            t.event_flag    = nil    -- pending map event
        end
    end
end

-- ── § 11  殖民地控制度系统 ────────────────────────────────────────────────────

---Set colony on a tile. faction_id takes initial ownership.
---@param q number
---@param r number
---@param colony_id  string   e.g. "virginia_colony"
---@param faction_id string   e.g. "hawkins"
---@param initial_control number  0-100
function SailAndIronMap:establish_colony(q, r, colony_id, faction_id, initial_control)
    local tile = self.grid:get_tile(q, r)
    assert(tile, "establish_colony: tile OOB")
    tile.colony_id            = colony_id
    tile.control[faction_id]  = initial_control or 20
    tile.tile_type            = TILE_TYPE.COLONY
    self.colonial_control[q.."_"..r] = { q=q, r=r, faction_id=faction_id }
end

---Apply annual control_degree changes (called in回合 阶段7).
---Resistance grows when control < 50; declines when control ≥ 70.
---Returns net control change for logging.
function SailAndIronMap:tick_colonial_control(q, r, faction_id, delta)
    local tile = self.grid:get_tile(q, r)
    if not tile then return 0 end
    local cur = tile.control[faction_id] or 0
    -- Resistance mechanics (GDD § 11)
    if cur < 50 then
        tile.resistance = math.min(100, tile.resistance + 3)
    elseif cur >= 70 then
        tile.resistance = math.max(0, tile.resistance - 2)
    end
    -- Resistance suppresses control gain
    local effective_delta = delta - math.floor(tile.resistance * 0.1)
    tile.control[faction_id] = math.max(0, math.min(100, cur + effective_delta))
    return effective_delta
end

---Compute total colonial_degree stat for a faction (GDD § 3.2 殖民度产出).
---Sums all controlled tiles' control degrees / 10.
function SailAndIronMap:compute_colonial_output(faction_id)
    local total = 0
    local g = self.grid
    for q = 0, g.width-1 do
        for r = 0, g.height-1 do
            local ctrl = g.tiles[q][r].control[faction_id]
            if ctrl and ctrl > 0 then
                total = total + math.floor(ctrl / 10)
            end
        end
    end
    return total
end

-- ── § 12  海军：制海权区域计算 ───────────────────────────────────────────────
--
-- Replaces the GDD's global "maritime" value with a spatial one:
-- each sea hex has an effective controller determined by proximity
-- and strength of nearby fleets (Dijkstra from fleet positions).
--
-- maritime_power_for_hex(q,r,faction_id) → local maritime strength
-- The global Maritime stat is then the count of controlled sea hexes × weight.

---Build maritime influence maps for all factions.
---fleets = { faction_id → list of { q, r, power } }
function SailAndIronMap:update_maritime_zones(fleets)
    self.maritime_zones = {}
    local g = self.grid

    for faction_id, fleet_list in pairs(fleets) do
        -- Source positions weighted by fleet power
        local sources = {}
        for _, ship in ipairs(fleet_list) do
            sources[#sources+1] = { q=ship.q, r=ship.r }
            -- Weight: add the hex multiple times proportional to power
            for i = 2, math.min(ship.power, 8) do
                sources[#sources+1] = { q=ship.q, r=ship.r }
            end
        end
        if #sources > 0 then
            -- Only sea/coastal tiles are in the maritime influence graph
            -- Override is_passable for sea-only traversal
            local old_pass = g.is_passable
            g.is_passable = function(_, tile)
                return tile.tile_type.is_sea
            end
            self.maritime_zones[faction_id] = g:dijkstra_map(sources)
            g.is_passable = old_pass
        end
    end
end

---Compute the controlling faction for a sea hex.
---Returns faction_id, strength  (or nil if unclaimed).
function SailAndIronMap:maritime_controller(q, r)
    local best_faction, best_dist = nil, math.huge
    for faction_id, dist_map in pairs(self.maritime_zones) do
        local d = dist_map[q] and dist_map[q][r]
        if d and d < best_dist then
            best_dist    = d
            best_faction = faction_id
        end
    end
    -- Only controlled if within effective range (≤ 8 moves)
    if best_dist <= 8 then
        return best_faction, best_dist
    end
    return nil, nil
end

---Recompute the Maritime stat for a faction from spatial control.
---Replaces the global §3.2 formula with a map-derived one.
function SailAndIronMap:compute_maritime_stat(faction_id)
    local count = 0
    local g = self.grid
    for q = 0, g.width-1 do
        for r = 0, g.height-1 do
            if g.tiles[q][r].tile_type.is_sea then
                local ctrl = self:maritime_controller(q, r)
                if ctrl == faction_id then count = count + 1 end
            end
        end
    end
    -- Scale: 1 controlled sea hex ≈ 0.5 Maritime (matches GDD §3.2 passive)
    return count * 0.5
end

-- ── § 6  三角贸易路线路径 ─────────────────────────────────────────────────────
--
-- Trade routes in the GDD are abstract level-1..5 connections.
-- With the hex map, routes now have a physical hex path, which:
--   1. Determines which sea hexes the route crosses (piracy risk)
--   2. Allows visual rendering as a curved arc
--   3. Makes route safety depend on local maritime control

---Register a trade route and compute its hex path.
---@param route_id   string
---@param from_q number  departure port hex
---@param from_r number
---@param to_q   number  destination port hex
---@param to_r   number
---@param faction_id string
---@return table path  array of {q,r}
function SailAndIronMap:register_trade_route(route_id, from_q, from_r, to_q, to_r, faction_id)
    local g = self.grid
    -- Sea-only pathfinding for naval routes
    local old_pass = g.is_passable
    g.is_passable = function(_, tile)
        return tile.tile_type.is_sea or tile.port_level > 0
    end
    local path = g:find_path(from_q, from_r, to_q, to_r) or {}
    g.is_passable = old_pass

    self.route_paths[route_id] = {
        path       = path,
        faction_id = faction_id,
        from       = { q=from_q, r=from_r },
        to         = { q=to_q,   r=to_r   },
    }

    -- Mark each tile on this route
    for _, hex in ipairs(path) do
        local tile = g:get_tile(hex.q, hex.r)
        if tile then
            tile.trade_routes[route_id] = true
        end
    end

    return path
end

---Compute effective safety for a route based on maritime control.
---Returns safety multiplier (0.7 ~ 1.0) matching GDD §6.4.
function SailAndIronMap:route_safety(route_id, faction_id)
    local route = self.route_paths[route_id]
    if not route or #route.path == 0 then return 1.0 end

    local hostile_hexes = 0
    for _, hex in ipairs(route.path) do
        local ctrl = self:maritime_controller(hex.q, hex.r)
        if ctrl and ctrl ~= faction_id then
            hostile_hexes = hostile_hexes + 1
        end
    end

    local hostile_ratio = hostile_hexes / #route.path

    -- Maps to GDD §6.4 loss table
    if hostile_ratio < 0.1 then return 1.00     -- ≥20 maritime: 0% loss
    elseif hostile_ratio < 0.3 then return 0.95  -- 10-19:  5% loss
    elseif hostile_ratio < 0.6 then return 0.85  -- 5-9:   15% loss
    else return 0.70                              -- <5:    30% loss
    end
end

-- ── § 11  FOW: 탐探险与迷雾 ──────────────────────────────────────────────────
--
-- Unexplored sea = hidden. Explorer / fleet reveals hexes in LOS.
-- This replaces the abstract "殖民度" exploration with spatial discovery.

---Reveal hexes around an explorer at (q,r) with given sight.
---Newly revealed hexes with resources trigger discovery events.
---@return table  list of newly revealed tiles { q, r, resource }
function SailAndIronMap:explorer_reveal(q, r, sight)
    local g = self.grid
    local newly_found = {}

    -- update_fow expects { {q,r,sight} } list
    g:update_fow({ { q=q, r=r, sight=sight } })

    -- Check for resource discoveries in the revealed ring
    for dq = -sight, sight do
        for dr = -sight, sight do
            local tq, tr = q+dq, r+dr
            if g:in_bounds(tq, tr) and g.fow[tq][tr] == "visible" then
                local tile = g.tiles[tq][tr]
                if tile.resource and not tile._discovered then
                    tile._discovered = true
                    newly_found[#newly_found+1] = {
                        q        = tq,
                        r        = tr,
                        resource = tile.resource,
                        amount   = tile.resource_amt,
                    }
                end
            end
        end
    end

    return newly_found
end

-- ── § 15  海战触发检测 ────────────────────────────────────────────────────────
--
-- Naval combat triggers when fleets from opposing factions
-- are within engagement range (≤ 2 hexes by default).

---Check all fleet positions for combat triggers.
---fleets = { faction_id → list of { q,r,power,id } }
---@return table  list of { attacker, defender, q, r }
function SailAndIronMap:detect_naval_combats(fleets, engagement_range)
    engagement_range = engagement_range or 2
    local combats = {}
    local factions = {}
    for fid, fleet in pairs(fleets) do factions[#factions+1] = { id=fid, fleet=fleet } end

    for i = 1, #factions do
        for j = i+1, #factions do
            local fa, fb = factions[i], factions[j]
            for _, sa in ipairs(fa.fleet) do
                for _, sb in ipairs(fb.fleet) do
                    local dist = HexGrid.distance(sa.q, sa.r, sb.q, sb.r)
                    if dist <= engagement_range then
                        combats[#combats+1] = {
                            attacker = fa.id,
                            defender = fb.id,
                            hex_a    = { q=sa.q, r=sa.r },
                            hex_b    = { q=sb.q, r=sb.r },
                        }
                    end
                end
            end
        end
    end
    return combats
end

-- ── § 14  AI 地图决策辅助 ────────────────────────────────────────────────────
--
-- Provides spatial intelligence for the AI faction system.
-- The AI's existing value-based logic stays unchanged;
-- these helpers translate spatial data back into value signals.

---Find the best uncolonized tile for a faction to target.
---Scores by: resource value + distance penalty + resistance.
---@param faction_id string
---@param from_q number  AI's nearest port
---@param from_r number
---@return table|nil  { q, r, score }
function SailAndIronMap:ai_best_colony_target(faction_id, from_q, from_r)
    local g = self.grid
    local dist_map = g:dijkstra_map({ { q=from_q, r=from_r } })
    local best = nil

    for q = 0, g.width-1 do
        for r = 0, g.height-1 do
            local tile = g.tiles[q][r]
            -- Target: visible, has resource, not already fully controlled
            local ctrl = tile.control[faction_id] or 0
            if g.fow[q][r] ~= "hidden"
               and tile.resource
               and ctrl < 60
               and not tile.tile_type.is_sea then
                local d    = (dist_map[q] and dist_map[q][r]) or math.huge
                local res_val = tile.resource.base_value * (tile.resource_amt / 100)
                local score   = res_val - d * 2 - tile.resistance * 0.5
                if not best or score > best.score then
                    best = { q=q, r=r, score=score }
                end
            end
        end
    end
    return best
end

---Find the best sea route for an AI fleet to patrol (maximize maritime control).
---Returns the hex path of highest-value patrol route.
function SailAndIronMap:ai_best_patrol_route(faction_id, from_q, from_r, patrol_range)
    -- Find sea hexes not yet controlled by this faction within patrol_range
    local g = self.grid
    local candidates = g:movement_range(from_q, from_r, patrol_range)
    local best_hex, best_val = nil, -math.huge

    for _, c in ipairs(candidates) do
        local tile = g.tiles[c.q][c.r]
        if tile.tile_type.is_sea then
            local ctrl_faction = self:maritime_controller(c.q, c.r)
            -- Prioritise: uncontrolled > enemy-controlled > friendly
            local val = (ctrl_faction == nil and 10)
                     or (ctrl_faction ~= faction_id and 6)
                     or 1
            -- Bonus for hexes on existing trade routes (protect income)
            if next(tile.trade_routes) then val = val + 5 end
            if val > best_val then
                best_val = val
                best_hex = c
            end
        end
    end

    if best_hex then
        local g2 = self.grid
        local old_pass = g2.is_passable
        g2.is_passable = function(_, tile) return tile.tile_type.is_sea end
        local path = g2:find_path(from_q, from_r, best_hex.q, best_hex.r)
        g2.is_passable = old_pass
        return path
    end
    return nil
end

-- ── Convenience Accessors ─────────────────────────────────────────────────────

SailAndIronMap.TILE_TYPE = TILE_TYPE
SailAndIronMap.RESOURCE  = RESOURCE

---Pass-through to the underlying hex grid (for renderer, event wiring, etc.)
function SailAndIronMap:get_grid() return self.grid end

return SailAndIronMap
