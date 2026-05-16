local Hex = require("map-module.hex")

local FogOfWar = {}
FogOfWar.__index = FogOfWar

local function ensurePlayerState(self, playerId)
    local state = self.players[playerId]
    if not state then
        state = {
            explored = {},
            visible = {},
        }
        self.players[playerId] = state
    end
    return state
end

local function mark(target, hex)
    target[Hex.key(hex)] = true
end

local function isMarked(target, hexOrX, y)
    local key = type(hexOrX) == "table" and Hex.key(hexOrX) or Hex.key(hexOrX, y)
    return target[key] == true
end

function FogOfWar.new()
    return setmetatable({
        players = {},
    }, FogOfWar)
end

function FogOfWar:clearVisible(playerId)
    ensurePlayerState(self, playerId).visible = {}
end

function FogOfWar:reveal(playerId, center, radius, map)
    local state = ensurePlayerState(self, playerId)
    for _, hex in ipairs(Hex.range(center, radius)) do
        if not map or map:hasTile(hex) then
            mark(state.explored, hex)
            mark(state.visible, hex)
        end
    end
end

function FogOfWar:recalculate(playerId, unitStore, map)
    self:clearVisible(playerId)
    for unit in unitStore:all() do
        if unit.owner == playerId then
            self:reveal(playerId, { x = unit.x, y = unit.y }, unit.visionRange or 1, map)
        end
    end
end

function FogOfWar:isVisible(playerId, hexOrX, y)
    local state = ensurePlayerState(self, playerId)
    return isMarked(state.visible, hexOrX, y)
end

function FogOfWar:isExplored(playerId, hexOrX, y)
    local state = ensurePlayerState(self, playerId)
    return isMarked(state.explored, hexOrX, y)
end

function FogOfWar:getVisibility(playerId, hexOrX, y)
    if self:isVisible(playerId, hexOrX, y) then
        return "visible"
    end
    if self:isExplored(playerId, hexOrX, y) then
        return "explored"
    end
    return "hidden"
end

function FogOfWar:toTable()
    return {
        players = self.players,
    }
end

function FogOfWar.fromTable(data)
    local fog = FogOfWar.new()
    fog.players = data.players or {}
    return fog
end

return FogOfWar
