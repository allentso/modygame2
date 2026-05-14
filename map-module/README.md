# Standalone Hex Map Module

This folder is a clean Lua map-data module for a Civ-like hex map prototype.
It does not import or reuse Unciv Kotlin code. The coordinate model is inspired
by the same kind of two-axis hex grid:

- `x` points to the upper-left neighbor.
- `y` points to the upper-right neighbor.
- Moving up is `(x + 1, y + 1)`.

## Files

- `hex.lua`: hex coordinate math, neighbors, distance, range, ring, and world conversion helpers.
- `tile_map.lua`: tile storage, rectangle/hexagon creation, tile lookup, neighbors, ranges, and JSON conversion.
- `terrain_rules.lua`: terrain definitions for passability, movement cost, yield, defense, and material names.
- `unit_store.lua`: independent unit data storage with owner, position, movement, vision, and health.
- `fog_of_war.lua`: per-player `visible` and `explored` map state.
- `map_generator.lua`: deterministic simple hex map generation with land, water, hills, forests, mountains, and resources.
- `map_view.lua`: engine-agnostic draw-list builder for tiles, units, and fog state.
- `json.lua`: small dependency-free JSON encoder/decoder for this module's simple map format.
- `sample_map.json`: example static map data.

## Map Data Shape

```json
{
  "version": 1,
  "name": "Sample Hex Map",
  "shape": "hexagon",
  "radius": 2,
  "defaultTerrain": "Grassland",
  "tiles": [
    {
      "x": 0,
      "y": 0,
      "terrain": "Grassland",
      "feature": "Forest",
      "resource": "Wheat",
      "improvement": null,
      "owner": null,
      "unitId": "warrior-1"
    }
  ]
}
```

Only `x`, `y`, and `terrain` are required for a tile. Other fields are optional.

## Basic Usage

Make sure this folder is on Lua's module path. In many embedded runtimes this is
done by adding the folder to `package.path`.

```lua
package.path = package.path .. ";map-module/?.lua"

local Hex = require("hex")
local TileMap = require("tile_map")
local TerrainRules = require("terrain_rules")
local UnitStore = require("unit_store")
local FogOfWar = require("fog_of_war")
local MapGenerator = require("map_generator")
local MapView = require("map_view")

local map = MapGenerator.generateHexagon({ radius = 6, seed = 1234 })
map:setTerrain(0, 0, "Plains")
map:setResource(1, 0, "Iron")

local units = UnitStore.new()
units:create({
  id = "warrior-1",
  type = "Warrior",
  owner = "Player",
  x = 0,
  y = 0,
  movementType = "land",
  visionRange = 2
})

local fog = FogOfWar.new()
fog:recalculate("Player", units, map)

local center = Hex.new(0, 0)
local neighbors = map:getNeighbors(center, nil, true)
local nearbyTiles = map:getTilesInRange(center, 2, true)

local worldPosition = Hex.toWorld(center, 32)
local clickedHex = Hex.fromWorld(worldPosition, 32)

local view = MapView.new({
  tileRadius = 32,
  terrainRules = TerrainRules.new()
})
local drawList = view:buildDrawList(map, units, fog, "Player")

local jsonText = map:toJson(true)
local loaded = TileMap.fromJson(jsonText)
```

## Notes For UrhoX Integration

This module does not directly call UrhoX APIs yet. `map_view.lua` produces a
draw list that an UrhoX adapter can consume. A renderer can use:

- `Hex.toWorld(tile, tileRadius)` to position tile nodes.
- `Hex.fromWorld(position, tileRadius)` to convert a click/raycast point back to a tile coordinate.
- `map:getTile(hex)` to resolve whether that coordinate exists.
- `map:getNeighbors(hex, nil, true)` for hover outlines or adjacency logic.
- `view:buildDrawList(map, units, fog, playerId)` to get renderable tile/unit entries.

An adapter only needs to implement:

```lua
local adapter = {
  draw = function(drawList)
    for _, item in ipairs(drawList) do
      -- Create or update UrhoX nodes here.
      -- item.kind is "tile" or "unit".
      -- item.worldX/worldY are map positions.
      -- item.material is the terrain material name for tiles.
      -- item.visibility is "visible", "explored", or "hidden".
    end
  end
}
```

The next natural layer is a real UrhoX adapter that maps `material` strings to
materials/textures and creates scene nodes from the draw list.
