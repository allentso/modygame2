local TerrainRules = {}

local function copyTable(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = copyTable(child)
    end
    return result
end

TerrainRules.defaults = {
    unknown = {
        name = "Unknown",
        isWater = false,
        passable = true,
        moveCost = 1,
        defenseBonus = 0,
        yield = { food = 0, production = 0, gold = 0 },
        material = "terrain_unknown",
    },
}

TerrainRules.builtin = {
    Grassland = {
        name = "Grassland",
        isWater = false,
        passable = true,
        moveCost = 1,
        defenseBonus = 0,
        yield = { food = 2, production = 0, gold = 0 },
        material = "terrain_grassland",
    },
    Plains = {
        name = "Plains",
        isWater = false,
        passable = true,
        moveCost = 1,
        defenseBonus = 0,
        yield = { food = 1, production = 1, gold = 0 },
        material = "terrain_plains",
    },
    Hill = {
        name = "Hill",
        isWater = false,
        passable = true,
        moveCost = 2,
        defenseBonus = 25,
        yield = { food = 0, production = 2, gold = 0 },
        material = "terrain_hill",
    },
    Forest = {
        name = "Forest",
        isWater = false,
        passable = true,
        moveCost = 2,
        defenseBonus = 25,
        yield = { food = 1, production = 1, gold = 0 },
        material = "terrain_forest",
    },
    Desert = {
        name = "Desert",
        isWater = false,
        passable = true,
        moveCost = 1,
        defenseBonus = 0,
        yield = { food = 0, production = 0, gold = 0 },
        material = "terrain_desert",
    },
    Mountain = {
        name = "Mountain",
        isWater = false,
        passable = false,
        moveCost = 999,
        defenseBonus = 0,
        yield = { food = 0, production = 0, gold = 0 },
        material = "terrain_mountain",
    },
    Coast = {
        name = "Coast",
        isWater = true,
        passable = true,
        moveCost = 1,
        defenseBonus = 0,
        yield = { food = 1, production = 0, gold = 1 },
        material = "terrain_coast",
    },
    Ocean = {
        name = "Ocean",
        isWater = true,
        passable = true,
        moveCost = 1,
        defenseBonus = 0,
        yield = { food = 1, production = 0, gold = 0 },
        material = "terrain_ocean",
    },
}

function TerrainRules.new(definitions)
    local rules = {
        definitions = copyTable(TerrainRules.builtin),
    }

    for name, definition in pairs(definitions or {}) do
        rules.definitions[name] = definition
    end

    return setmetatable(rules, { __index = TerrainRules })
end

function TerrainRules:get(name)
    return self.definitions[name] or TerrainRules.defaults.unknown
end

function TerrainRules:isPassable(name, movementType)
    local terrain = self:get(name)
    if movementType == "land" and terrain.isWater then
        return false
    end
    if movementType == "water" and not terrain.isWater then
        return false
    end
    return terrain.passable ~= false
end

function TerrainRules:getMoveCost(name, movementType)
    if not self:isPassable(name, movementType) then
        return math.huge
    end
    return self:get(name).moveCost or 1
end

function TerrainRules:getYield(name)
    return copyTable(self:get(name).yield or {})
end

function TerrainRules:getMaterial(name)
    return self:get(name).material
end

return TerrainRules
