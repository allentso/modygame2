# hex_map — Lua 地图交互模块
## AI Coding 上下文说明

将此文件放入项目根目录，用于 Cursor / Claude Code / Copilot 补全时提供上下文。

---

## 文件结构

```
hex_grid.lua       ← 核心：坐标系、寻路、FOW、事件系统（纯 Lua，无依赖）
hex_renderer.lua   ← 渲染：颜色、高亮层、FOW 绘制（需替换 draw_api）
main_example.lua   ← 接入示例：Love2D 接线模板（AI 改写入口）
```

---

## 核心数据结构

### Tile（地图格子）
```lua
{
  q        = number,  -- axial 列坐标
  r        = number,  -- axial 行坐标
  terrain  = HexGrid.TERRAIN.*,  -- 地形
  unit     = Unit | nil,         -- 占据该格的单位（你的仿真对象）
  building = Building | nil,     -- 建筑（你的仿真对象）
  resource = { type=string, amount=number } | nil,
  owner    = number | nil,       -- 玩家 ID
}
```

### Unit（最小接口，可扩展）
```lua
{
  q     = number,  -- 当前格子 q
  r     = number,  -- 当前格子 r
  sight = number,  -- 视野半径（格数）
  move  = number,  -- 每回合移动点数
  owner = number,  -- 所属玩家
  name  = string,
}
```

---

## 关键 API 速查

```lua
-- 创建地图
local map = HexGrid.new({ width=20, height=15, hex_size=36, offset_x=50, offset_y=50 })

-- 地形
map:set_terrain(q, r, HexGrid.TERRAIN.FOREST)
local tile = map:get_tile(q, r)  -- nil if OOB

-- 坐标转换
local px, py = map:hex_to_pixel(q, r)
local q, r   = map:pixel_to_hex(px, py)

-- 寻路（A*）
local path = map:find_path(sq, sr, eq, er)
-- → { {q,r}, ... } or nil

-- 移动范围（BFS）
local tiles = map:movement_range(q, r, move_points)
-- → { {q,r,cost}, ... }

-- 视野检查
local clear = map:has_los(q1,r1, q2,r2)  -- → bool

-- 战争迷雾（每回合调用）
map:update_fow({ {q=2,r=3,sight=4}, ... })
-- map.fow[q][r] = "visible"|"explored"|"hidden"

-- AI 影响图（Dijkstra 从多个源点扩散）
local threat = map:dijkstra_map({ {q=8,r=7}, {q=10,r=3} })
-- threat[q][r] = number (math.huge if unreachable)

-- 事件
map:on("click",       function(tile) end)
map:on("right_click", function(tile) end)
map:on("hover",       function(tile, prev_tile) end)

-- 鼠标输入（在你的框架回调里调用）
map:on_mouse_press(px, py, button)  -- button: 1=left 2=right
map:on_mouse_move(px, py)

-- 存档
local data = map:export()
map:import(data)
```

---

## 与现有仿真逻辑对接的三步

### Step 1：把你的单位挂到 tile 上
```lua
-- 在你的仿真初始化时：
for _, unit in ipairs(my_sim.units) do
    local tile = map:get_tile(unit.q, unit.r)
    if tile then tile.unit = unit end
end
```

### Step 2：在 click 事件里发出移动指令
```lua
map:on("click", function(tile)
    if selected_unit and is_in_range(tile) then
        -- 通知你的仿真层
        my_sim:move_unit(selected_unit, tile.q, tile.r)
        -- 同步地图状态
        map:get_tile(selected_unit.q, selected_unit.r).unit = nil
        selected_unit.q = tile.q
        selected_unit.r = tile.r
        tile.unit = selected_unit
        -- 刷新战争迷雾
        map:update_fow(my_sim:get_all_units())
    end
end)
```

### Step 3：每回合结束时更新 FOW 和威胁图
```lua
function my_sim:end_turn()
    -- ... 你原有的回合逻辑 ...
    map:update_fow(self:get_friendly_units())
    renderer.danger_map = map:dijkstra_map(self:get_enemy_positions())
end
```

---

## 扩展任务 Prompt（复制给 AI 直接执行）

### A. 增加地图滚动/缩放
```
在 main_example.lua 中添加相机系统：
- 用 WASD 或方向键平移地图（修改 map.offset_x/offset_y）
- 用鼠标滚轮缩放（修改 map.hex_size，并同步 offset 使缩放中心为鼠标位置）
- 限制平移不超出地图边界
```

### B. 增加攻击范围显示
```
在 hex_grid.lua 中添加 map:attack_range(q, r, min_range, max_range) 函数，
返回距离在 [min_range, max_range] 之间的所有可见格子（受 FOW 过滤）。
在 hex_renderer.lua 中 overlays.attack_range 已预留，只需填充该 set。
```

### C. 程序化地形生成（Simplex Noise）
```
在 hex_grid.lua 中添加 HexGrid.generate_terrain(map, opts) 静态函数：
- 使用纯 Lua Simplex Noise（内联实现，约 80 行）
- noise < 0.3 → WATER，0.3~0.5 → PLAINS，0.5~0.7 → FOREST，>0.7 → MOUNTAIN
- opts = { seed, scale, water_level, mountain_level }
```

### D. 多层地图（地下城 / 楼层）
```
将 HexGrid 实例装入 layers 数组：
layers[1] = HexGrid.new(...)  -- 地面
layers[2] = HexGrid.new(...)  -- 地下
添加 active_layer 变量，鼠标事件和渲染只作用于 active_layer。
传送点：tile.portal = { target_layer, target_q, target_r }。
```

---

## 常见坑

| 问题 | 原因 | 解决 |
|------|------|------|
| 点击总是偏一格 | offset_x/offset_y 没传或和渲染不一致 | 确保 map.offset_x == 渲染时的偏移 |
| 寻路跑到 Water 格 | `is_passable` 默认用 move_cost<99 | 覆写 `map.is_passable = function(tile) ... end` |
| FOW 每帧卡顿 | `update_fow` 在 draw 里调用 | 只在回合结束 / 单位移动后调用一次 |
| 六角格点击判断错位 | hex_size 用的是边长而非半径 | hex_size = 顶点到中心距离（外接圆半径）|
