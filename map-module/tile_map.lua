local Hex = require("hex")
local Json = require("json")

local TileMap = {}
TileMap.__index = TileMap

local DEFAULT_TERRAIN = "Grassland"

local function copyTile(tile)
    local copied = {}
    for key, value in pairs(tile) do
        copied[key] = value
    end
    return copied
end

local function makeTile(x, y, terrain)
    return {
        x = x,
        y = y,
        terrain = terrain or DEFAULT_TERRAIN,
        feature = nil,
        resource = nil,
        improvement = nil,
        owner = nil,
        unitId = nil,
    }
end

function TileMap.new(options)
    options = options or {}
    local map = {
        name = options.name or "Untitled Map",
        shape = options.shape or "custom",
        width = options.width,
        height = options.height,
        radius = options.radius,
        defaultTerrain = options.defaultTerrain or DEFAULT_TERRAIN,
        tiles = {},
        tileKeys = {},
    }
    return setmetatable(map, TileMap)
end

function TileMap:createTile(x, y, terrain)
    local tile = makeTile(x, y, terrain or self.defaultTerrain)
    self:setTile(tile)
    return tile
end

function TileMap:setTile(tile)
    if tile.x == nil or tile.y == nil then
        error("Tile requires x and y fields")
    end

    local key = Hex.key(tile.x, tile.y)
    if not self.tiles[key] then
        self.tileKeys[#self.tileKeys + 1] = key
    end
    self.tiles[key] = copyTile(tile)
end

function TileMap:getTile(x, y)
    if type(x) == "table" then
        return self.tiles[Hex.key(x)]
    end
    return self.tiles[Hex.key(x, y)]
end

function TileMap:hasTile(x, y)
    return self:getTile(x, y) ~= nil
end

function TileMap:removeTile(x, y)
    local key = type(x) == "table" and Hex.key(x) or Hex.key(x, y)
    if not self.tiles[key] then
        return false
    end

    self.tiles[key] = nil
    for index, existingKey in ipairs(self.tileKeys) do
        if existingKey == key then
            table.remove(self.tileKeys, index)
            break
        end
    end
    return true
end

function TileMap:count()
    return #self.tileKeys
end

function TileMap:allTiles()
    table.sort(self.tileKeys)
    local index = 0
    return function()
        index = index + 1
        local key = self.tileKeys[index]
        if not key then
            return nil
        end
        return self.tiles[key]
    end
end

function TileMap:getNeighbors(hexOrX, y, onlyExisting)
    local center = type(hexOrX) == "table" and hexOrX or { x = hexOrX, y = y }
    local result = {}
    for _, neighbor in ipairs(Hex.neighbors(center)) do
        local tile = self:getTile(neighbor)
        if tile or not onlyExisting then
            result[#result + 1] = tile or neighbor
        end
    end
    return result
end

function TileMap:getTilesInRange(center, radius, onlyExisting)
    local result = {}
    for _, hex in ipairs(Hex.range(center, radius)) do
        local tile = self:getTile(hex)
        if tile or not onlyExisting then
            result[#result + 1] = tile or hex
        end
    end
    return result
end

function TileMap:setTerrain(x, y, terrain)
    local tile = self:getTile(x, y)
    if not tile then
        tile = makeTile(x, y, terrain)
    else
        tile.terrain = terrain
    end
    self:setTile(tile)
end

function TileMap:setResource(x, y, resource)
    local tile = self:getTile(x, y)
    if not tile then
        tile = makeTile(x, y, self.defaultTerrain)
    end
    tile.resource = resource
    self:setTile(tile)
end

function TileMap:setUnit(x, y, unitId)
    local tile = self:getTile(x, y)
    if not tile then
        error("Cannot place unit on missing tile " .. Hex.key(x, y))
    end
    tile.unitId = unitId
    self:setTile(tile)
end

function TileMap:clearUnit(x, y)
    local tile = self:getTile(x, y)
    if not tile then
        return false
    end
    tile.unitId = nil
    self:setTile(tile)
    return true
end

function TileMap:getBounds()
    local bounds = nil
    for tile in self:allTiles() do
        if not bounds then
            bounds = { minX = tile.x, maxX = tile.x, minY = tile.y, maxY = tile.y }
        else
            bounds.minX = math.min(bounds.minX, tile.x)
            bounds.maxX = math.max(bounds.maxX, tile.x)
            bounds.minY = math.min(bounds.minY, tile.y)
            bounds.maxY = math.max(bounds.maxY, tile.y)
        end
    end
    return bounds
end

function TileMap:toTable()
    local tiles = {}
    for tile in self:allTiles() do
        tiles[#tiles + 1] = copyTile(tile)
    end

    return {
        version = 1,
        name = self.name,
        shape = self.shape,
        width = self.width,
        height = self.height,
        radius = self.radius,
        defaultTerrain = self.defaultTerrain,
        tiles = tiles,
    }
end

function TileMap:toJson(pretty)
    return Json.encode(self:toTable(), { pretty = pretty ~= false })
end

function TileMap.fromTable(data)
    local map = TileMap.new({
        name = data.name,
        shape = data.shape,
        width = data.width,
        height = data.height,
        radius = data.radius,
        defaultTerrain = data.defaultTerrain,
    })

    for _, tile in ipairs(data.tiles or {}) do
        map:setTile(tile)
    end
    return map
end

function TileMap.fromJson(text)
    return TileMap.fromTable(Json.decode(text))
end

function TileMap.createHexagon(radius, defaultTerrain)
    local map = TileMap.new({
        name = "Hexagon " .. tostring(radius),
        shape = "hexagon",
        radius = radius,
        defaultTerrain = defaultTerrain or DEFAULT_TERRAIN,
    })

    for _, hex in ipairs(Hex.range({ x = 0, y = 0 }, radius)) do
        map:createTile(hex.x, hex.y)
    end
    return map
end

function TileMap.createRectangle(width, height, defaultTerrain)
    local map = TileMap.new({
        name = "Rectangle " .. tostring(width) .. "x" .. tostring(height),
        shape = "rectangle",
        width = width,
        height = height,
        defaultTerrain = defaultTerrain or DEFAULT_TERRAIN,
    })

    local left = -math.floor(width / 2)
    local right = left + width - 1
    local bottom = -math.floor(height / 2)
    local top = bottom + height - 1

    for column = left, right do
        for row = bottom, top do
            local hex = Hex.fromColumnRow(column, row)
            map:createTile(hex.x, hex.y)
        end
    end
    return map
end

return TileMap
