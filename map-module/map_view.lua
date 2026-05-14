local Hex = require("hex")
local TerrainRules = require("terrain_rules")

local MapView = {}
MapView.__index = MapView

function MapView.new(options)
    options = options or {}
    return setmetatable({
        tileRadius = options.tileRadius or 32,
        terrainRules = options.terrainRules or TerrainRules.new(),
        adapter = options.adapter,
    }, MapView)
end

function MapView:buildTileDrawList(map, fog, playerId)
    local drawList = {}
    for tile in map:allTiles() do
        local position = Hex.toWorld(tile, self.tileRadius)
        local visibility = fog and playerId and fog:getVisibility(playerId, tile) or "visible"
        local material = self.terrainRules:getMaterial(tile.terrain)

        local item = {}
        for key, value in pairs(tile) do
            item[key] = value
        end
        item.kind = "tile"
        item.worldX = position.x
        item.worldY = position.y
        item.material = material
        item.visibility = visibility

        drawList[#drawList + 1] = item
    end
    return drawList
end

function MapView:buildUnitDrawList(unitStore, fog, playerId)
    local drawList = {}
    for unit in unitStore:all() do
        local visibility = fog and playerId and fog:getVisibility(playerId, unit) or "visible"
        if visibility == "visible" then
            local position = Hex.toWorld(unit, self.tileRadius)
            drawList[#drawList + 1] = {
                kind = "unit",
                id = unit.id,
                type = unit.type,
                owner = unit.owner,
                x = unit.x,
                y = unit.y,
                worldX = position.x,
                worldY = position.y,
                health = unit.health,
            }
        end
    end
    return drawList
end

function MapView:buildDrawList(map, unitStore, fog, playerId)
    local drawList = self:buildTileDrawList(map, fog, playerId)
    if unitStore then
        for _, item in ipairs(self:buildUnitDrawList(unitStore, fog, playerId)) do
            drawList[#drawList + 1] = item
        end
    end
    return drawList
end

function MapView:render(map, unitStore, fog, playerId)
    if not self.adapter or not self.adapter.draw then
        error("MapView requires an adapter with a draw(drawList) function")
    end
    return self.adapter.draw(self:buildDrawList(map, unitStore, fog, playerId))
end

return MapView
