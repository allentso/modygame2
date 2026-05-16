-- ============================================================================
-- MapModuleAdapter.lua - Bridge current Atlantic map data to map-module.
-- ============================================================================
local MapData = require("data.MapData")

local TileMap = require("map-module.tile_map")
local FogOfWar = require("map-module.fog_of_war")
local MapView = require("map-module.map_view")

local M = {}
M.__index = M

M.GRID_COLS = MapData.GRID_COLS
M.GRID_ROWS = MapData.GRID_ROWS
M.PLAYER_ID = "player"
M.DEFAULT_REVEAL_RADIUS = 4

local function key(col, row)
    return tostring(col) .. "," .. tostring(row)
end

local function offsetToHex(col, row)
    local q = col - math.floor(row / 2)
    local r = row
    return {
        x = -q - r,
        y = -r,
    }
end

local function copyArrayItems(items)
    local copied = {}
    for index, item in ipairs(items or {}) do
        local entry = {}
        for field, value in pairs(item) do
            entry[field] = value
        end
        copied[index] = entry
    end
    return copied
end

local function createTileMap()
    local tileMap = TileMap.new({
        name = "Atlantic World",
        shape = "offset-hex",
        width = MapData.GRID_COLS,
        height = MapData.GRID_ROWS,
        defaultTerrain = "atlantic",
    })

    local byOffset = {}
    local byPort = {}

    for _, sourceTile in ipairs(MapData.tiles) do
        local hex = offsetToHex(sourceTile.col, sourceTile.row)
        local tile = {}
        for field, value in pairs(sourceTile) do
            tile[field] = value
        end
        tile.x = hex.x
        tile.y = hex.y
        tile.terrain = sourceTile.type

        tileMap:setTile(tile)

        local stored = tileMap:getTile(hex)
        byOffset[key(sourceTile.col, sourceTile.row)] = stored
        if sourceTile.portId then
            byPort[sourceTile.portId] = stored
        end
    end

    return tileMap, byOffset, byPort
end

function M.new(options)
    options = options or {}

    local tileMap, byOffset, byPort = createTileMap()
    return setmetatable({
        tileMap = tileMap,
        tilesByOffset = byOffset,
        portsById = byPort,
        fog = FogOfWar.new(),
        mapView = MapView.new({ tileRadius = options.tileRadius or 1 }),
        playerId = options.playerId or M.PLAYER_ID,
        revealRadius = options.revealRadius or M.DEFAULT_REVEAL_RADIUS,
    }, M)
end

function M:GetGridCols()
    return MapData.GRID_COLS
end

function M:GetGridRows()
    return MapData.GRID_ROWS
end

function M:GetTile(col, row)
    return self.tilesByOffset[key(col, row)]
end

function M:GetPortTile(portId)
    return self.portsById[portId]
end

function M:GetTileStyle(tile)
    return tile and MapData.tileStyles[tile.type or tile.terrain] or nil
end

function M:GetResourceIcon(resource)
    return MapData.resourceIcons[resource]
end

function M:GetRoutes()
    return MapData.tradeRoutes
end

function M:GetRouteLegend()
    return MapData.routeLegend
end

function M:GetUnexploredStyle()
    return MapData.tileStyles.unexplored
end

function M:RefreshFog(state)
    self.fog = FogOfWar.new()

    local revealedAny = false
    for _, colony in ipairs((state and state.colonies) or {}) do
        local portTile = self:GetPortTile(colony.portId)
        if portTile then
            self.fog:reveal(self.playerId, portTile, self.revealRadius, self.tileMap)
            revealedAny = true
        end
    end

    return revealedAny
end

function M:BuildDrawList(state)
    if not state then
        return self.mapView:buildDrawList(self.tileMap, nil, nil, self.playerId)
    end

    self:RefreshFog(state)
    return self.mapView:buildDrawList(self.tileMap, nil, self.fog, self.playerId)
end

function M:ExportRoutes()
    return copyArrayItems(MapData.tradeRoutes)
end

return M
