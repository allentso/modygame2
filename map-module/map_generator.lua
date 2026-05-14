local Hex = require("hex")
local TileMap = require("tile_map")

local MapGenerator = {}

local function hash(seed, x, y, salt)
    local value = math.sin(seed * 12.9898 + x * 78.233 + y * 37.719 + salt * 19.19) * 43758.5453
    return value - math.floor(value)
end

local function smoothNoise(seed, x, y, salt)
    local total = hash(seed, x, y, salt) * 4
    for _, neighbor in ipairs(Hex.neighbors({ x = x, y = y })) do
        total = total + hash(seed, neighbor.x, neighbor.y, salt)
    end
    return total / 10
end

local function chooseLandTerrain(seed, x, y)
    local height = smoothNoise(seed, x, y, 1)
    local moisture = smoothNoise(seed, x, y, 2)

    if height > 0.78 then
        return "Mountain"
    elseif height > 0.62 then
        return "Hill"
    elseif moisture > 0.68 then
        return "Forest"
    elseif moisture < 0.25 then
        return "Desert"
    elseif moisture < 0.45 then
        return "Plains"
    end
    return "Grassland"
end

local function maybePlaceResource(map, seed, tile)
    local roll = hash(seed, tile.x, tile.y, 7)
    if tile.terrain == "Grassland" and roll > 0.88 then
        map:setResource(tile.x, tile.y, "Wheat")
    elseif tile.terrain == "Plains" and roll > 0.90 then
        map:setResource(tile.x, tile.y, "Horses")
    elseif tile.terrain == "Hill" and roll > 0.86 then
        map:setResource(tile.x, tile.y, "Iron")
    elseif tile.terrain == "Coast" and roll > 0.90 then
        map:setResource(tile.x, tile.y, "Fish")
    end
end

function MapGenerator.generateHexagon(options)
    options = options or {}
    local radius = options.radius or 8
    local seed = options.seed or 1
    local waterLevel = options.waterLevel or 0.34
    local coastLevel = options.coastLevel or 0.44

    local map = TileMap.createHexagon(radius, "Grassland")
    map.name = options.name or ("Generated Hexagon " .. tostring(radius))

    for tile in map:allTiles() do
        local edgeFactor = Hex.distance({ x = 0, y = 0 }, tile) / math.max(radius, 1)
        local continent = smoothNoise(seed, tile.x, tile.y, 3) - edgeFactor * 0.18

        if continent < waterLevel then
            tile.terrain = "Ocean"
        elseif continent < coastLevel then
            tile.terrain = "Coast"
        else
            tile.terrain = chooseLandTerrain(seed, tile.x, tile.y)
        end

        map:setTile(tile)
    end

    for tile in map:allTiles() do
        maybePlaceResource(map, seed, tile)
    end

    return map
end

return MapGenerator
