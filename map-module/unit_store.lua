local Hex = require("hex")

local UnitStore = {}
UnitStore.__index = UnitStore

local function copyUnit(unit)
    return {
        id = unit.id,
        type = unit.type,
        owner = unit.owner,
        x = unit.x,
        y = unit.y,
        movementType = unit.movementType,
        maxMovement = unit.maxMovement,
        movement = unit.movement,
        visionRange = unit.visionRange,
        health = unit.health,
    }
end

function UnitStore.new()
    return setmetatable({
        units = {},
        unitIds = {},
        nextId = 1,
    }, UnitStore)
end

function UnitStore:create(unit)
    local id = unit.id or ("unit-" .. tostring(self.nextId))
    if self.units[id] then
        error("Duplicate unit id: " .. tostring(id))
    end

    self.nextId = self.nextId + 1
    local created = {
        id = id,
        type = unit.type or "Unit",
        owner = unit.owner or "Neutral",
        x = unit.x or 0,
        y = unit.y or 0,
        movementType = unit.movementType or "land",
        maxMovement = unit.maxMovement or 2,
        movement = unit.movement or unit.maxMovement or 2,
        visionRange = unit.visionRange or 2,
        health = unit.health or 100,
    }

    self.units[id] = created
    self.unitIds[#self.unitIds + 1] = id
    return created
end

function UnitStore:get(id)
    return self.units[id]
end

function UnitStore:remove(id)
    if not self.units[id] then
        return false
    end

    self.units[id] = nil
    for index, existingId in ipairs(self.unitIds) do
        if existingId == id then
            table.remove(self.unitIds, index)
            break
        end
    end
    return true
end

function UnitStore:move(id, x, y)
    local unit = self:get(id)
    if not unit then
        error("Unknown unit id: " .. tostring(id))
    end
    unit.x = x
    unit.y = y
    return unit
end

function UnitStore:getAt(x, y)
    local key = type(x) == "table" and Hex.key(x) or Hex.key(x, y)
    local result = {}
    for _, id in ipairs(self.unitIds) do
        local unit = self.units[id]
        if Hex.key(unit.x, unit.y) == key then
            result[#result + 1] = unit
        end
    end
    return result
end

function UnitStore:all()
    local index = 0
    return function()
        index = index + 1
        local id = self.unitIds[index]
        if not id then
            return nil
        end
        return self.units[id]
    end
end

function UnitStore:resetMovement(owner)
    for unit in self:all() do
        if owner == nil or unit.owner == owner then
            unit.movement = unit.maxMovement
        end
    end
end

function UnitStore:toTable()
    local units = {}
    for unit in self:all() do
        units[#units + 1] = copyUnit(unit)
    end
    return {
        nextId = self.nextId,
        units = units,
    }
end

function UnitStore.fromTable(data)
    local store = UnitStore.new()
    local nextId = data.nextId or 1
    for _, unit in ipairs(data.units or {}) do
        store:create(unit)
    end
    store.nextId = nextId
    return store
end

return UnitStore
