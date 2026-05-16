local Hex = {}

local sqrt = math.sqrt
local abs = math.abs
local floor = math.floor

local SQRT3 = sqrt(3)

-- Coordinate system:
-- x points to the upper-left neighbor, y points to the upper-right neighbor.
-- The six neighbor steps are clockwise from top: (1,1), (0,1), (-1,0),
-- (-1,-1), (0,-1), (1,0).
Hex.directions = {
    { x = 1, y = 1 },
    { x = 0, y = 1 },
    { x = -1, y = 0 },
    { x = -1, y = -1 },
    { x = 0, y = -1 },
    { x = 1, y = 0 },
}

function Hex.new(x, y)
    return { x = x or 0, y = y or 0 }
end

function Hex.copy(hex)
    return { x = hex.x, y = hex.y }
end

function Hex.key(x, y)
    if type(x) == "table" then
        return tostring(x.x) .. "," .. tostring(x.y)
    end
    return tostring(x) .. "," .. tostring(y)
end

function Hex.fromKey(key)
    local comma = string.find(key, ",", 1, true)
    if not comma then
        error("Invalid hex key: " .. tostring(key))
    end
    return {
        x = tonumber(string.sub(key, 1, comma - 1)),
        y = tonumber(string.sub(key, comma + 1)),
    }
end

function Hex.add(a, b)
    return { x = a.x + b.x, y = a.y + b.y }
end

function Hex.subtract(a, b)
    return { x = a.x - b.x, y = a.y - b.y }
end

function Hex.scale(hex, factor)
    return { x = hex.x * factor, y = hex.y * factor }
end

function Hex.equals(a, b)
    return a.x == b.x and a.y == b.y
end

function Hex.neighbor(hex, directionIndex)
    local direction = Hex.directions[((directionIndex - 1) % 6) + 1]
    return Hex.add(hex, direction)
end

function Hex.neighbors(hex)
    local result = {}
    for i = 1, 6 do
        result[i] = Hex.neighbor(hex, i)
    end
    return result
end

function Hex.distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    if dx * dy >= 0 then
        return math.max(abs(dx), abs(dy))
    end
    return abs(dx) + abs(dy)
end

function Hex.range(center, radius)
    local result = {}
    for x = center.x - radius, center.x + radius do
        for y = center.y - radius, center.y + radius do
            local hex = { x = x, y = y }
            if Hex.distance(center, hex) <= radius then
                result[#result + 1] = hex
            end
        end
    end
    return result
end

function Hex.ring(center, radius)
    if radius == 0 then
        return { Hex.copy(center) }
    end

    local result = {}
    local current = Hex.add(center, Hex.scale(Hex.directions[4], radius))
    local walkOrder = { 6, 1, 2, 3, 4, 5 }
    for _, side in ipairs(walkOrder) do
        for _ = 1, radius do
            result[#result + 1] = Hex.copy(current)
            current = Hex.add(current, Hex.directions[side])
        end
    end
    return result
end

function Hex.numberOfTilesInHexagon(radius)
    if radius < 0 then
        return 0
    end
    return 1 + 3 * radius * (radius + 1)
end

function Hex.fromColumnRow(column, row)
    local twoRows = row * 2
    if abs(column) % 2 == 1 then
        twoRows = twoRows + 1
    end
    return {
        x = floor((twoRows - column) / 2),
        y = floor((twoRows + column) / 2),
    }
end

function Hex.toColumnRow(hex)
    return {
        column = hex.y - hex.x,
        row = floor((hex.x + hex.y) / 2),
    }
end

function Hex.toWorld(hex, tileRadius)
    local radius = tileRadius or 1
    return {
        x = 1.5 * (hex.y - hex.x) * radius,
        y = (SQRT3 * 0.5) * (hex.x + hex.y) * radius,
    }
end

local function roundNumber(value)
    if value >= 0 then
        return floor(value + 0.5)
    end
    return -floor(-value + 0.5)
end

function Hex.round(fractional)
    local cubeX = fractional.y - fractional.x
    local cubeY = fractional.x
    local cubeZ = -fractional.y

    local rx = roundNumber(cubeX)
    local ry = roundNumber(cubeY)
    local rz = roundNumber(cubeZ)

    local dx = abs(rx - cubeX)
    local dy = abs(ry - cubeY)
    local dz = abs(rz - cubeZ)

    if dx > dy and dx > dz then
        rx = -ry - rz
    elseif dy > dz then
        ry = -rx - rz
    else
        rz = -rx - ry
    end

    return { x = ry, y = -rz }
end

function Hex.fromWorld(world, tileRadius)
    local radius = tileRadius or 1
    local diagonal = world.x / (1.5 * radius)
    local layer = world.y / (SQRT3 * 0.5 * radius)
    return Hex.round({
        x = (layer - diagonal) / 2,
        y = (layer + diagonal) / 2,
    })
end

return Hex
