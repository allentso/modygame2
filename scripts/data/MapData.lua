-- ============================================================================
-- MapData.lua - 六边形世界地图数据（大西洋贸易时代 1640-1840）
-- Pointy-top 六边形，偏移坐标 (col, row)，奇数行右移半格
-- 72 列 × 40 行网格（高精度版）
-- 大陆轮廓参照真实地理形态精细雕刻
-- ============================================================================
local M = {}

-- ── 网格尺寸 ─────────────────────────────────────
M.GRID_COLS = 72
M.GRID_ROWS = 40

-- ── 瓦片类型定义 ─────────────────────────────────
M.tileStyles = {
    -- 海洋
    deepOcean    = { fill = { 18,  52, 100, 255}, stroke = { 12,  36,  72, 255} },
    atlantic     = { fill = { 12,  34,  68, 255}, stroke = {  8,  24,  50, 255} },
    shallowOcean = { fill = { 55, 115, 160, 255}, stroke = { 40,  90, 135, 255} },
    -- 冻土 / 苔原
    tundra       = { fill = {195, 200, 198, 255}, stroke = {160, 168, 165, 255} },
    -- 欧洲
    europeCity   = { fill = {185, 175, 155, 255}, stroke = {140, 130, 110, 255} },
    europePort   = { fill = {140, 165, 190, 255}, stroke = { 40,  80, 130, 255} },
    -- 殖民地
    colonyWild   = { fill = {110, 140,  78, 255}, stroke = { 82, 108,  56, 255} },
    colonyPort   = { fill = {190, 155,  70, 255}, stroke = {155, 120,  45, 255} },
    colonized    = { fill = { 60, 110,  50, 255}, stroke = { 42,  80,  35, 255} },
    -- 非洲
    landAfrica   = { fill = {175, 142,  88, 255}, stroke = {135, 108,  65, 255} },
    africaPort   = { fill = {185, 145,  75, 255}, stroke = { 40,  80, 130, 255} },
    desert       = { fill = {210, 190, 140, 255}, stroke = {175, 158, 112, 255} },
    savanna      = { fill = {165, 155,  85, 255}, stroke = {130, 120,  62, 255} },
    jungle       = { fill = { 55, 100,  45, 255}, stroke = { 38,  72,  30, 255} },
    -- 美洲
    landAmerica  = { fill = {120, 165, 100, 255}, stroke = { 88, 128,  70, 255} },
    -- 美洲山地
    mountain     = { fill = {148, 130, 105, 255}, stroke = {115, 100,  78, 255} },
    -- 北非/地中海沿岸
    landMediterr = { fill = {195, 175, 130, 255}, stroke = {155, 138,  98, 255} },
    -- 斯堪的纳维亚
    landNordic   = { fill = {155, 160, 148, 255}, stroke = {118, 122, 112, 255} },
    -- 东欧草原
    steppe       = { fill = {170, 175, 135, 255}, stroke = {135, 140, 100, 255} },
    -- 未探索
    unexplored   = { fill = {130, 122, 112, 160}, stroke = {100,  94,  85, 130} },
}

-- ── 资源图标 & 颜色 ───────────────────────────────
M.resourceIcons = {
    sugar   = { icon = "S",  label = "蔗糖",  color = {100, 180, 80, 255} },
    cotton  = { icon = "C",  label = "棉花",  color = {220, 220, 220, 255} },
    tobacco = { icon = "T",  label = "烟草",  color = {165, 120, 55, 255} },
    silver  = { icon = "$",  label = "白银",  color = {200, 200, 210, 255} },
    spice   = { icon = "*",  label = "香料",  color = {200, 60, 60, 255} },
    coal    = { icon = "c",  label = "煤炭",  color = {60, 60, 65, 255} },
    iron    = { icon = "I",  label = "铁矿",  color = {140, 140, 150, 255} },
    timber  = { icon = "W",  label = "木材",  color = {140, 100, 55, 255} },
    gold    = { icon = "G",  label = "黄金",  color = {220, 190, 50, 255} },
    fur     = { icon = "F",  label = "毛皮",  color = {160, 120, 80, 255} },
}

-- ══════════════════════════════════════════════════════
-- 辅助函数：批量生成瓦片行
-- ══════════════════════════════════════════════════════
local tiles = {}

--- 添加一行连续瓦片
---@param row number
---@param startCol number
---@param endCol number
---@param tileType string
---@param extras? table[] 特殊格覆盖 { {col, type?, name?, portId?, nation?, resource?}, ... }
local function addRow(row, startCol, endCol, tileType, extras)
    local extraMap = {}
    if extras then
        for _, e in ipairs(extras) do
            extraMap[e[1]] = e
        end
    end
    for c = startCol, endCol do
        local ex = extraMap[c]
        if ex then
            local t = {
                col = c, row = row,
                type = ex.type or tileType,
                name = ex.name,
                portId = ex.portId,
                nation = ex.nation,
                resource = ex.resource,
            }
            tiles[#tiles + 1] = t
        else
            tiles[#tiles + 1] = { col = c, row = row, type = tileType }
        end
    end
end

--- 添加一行有间隔的瓦片（跳过指定列，用于海湾/内海）
---@param row number
---@param startCol number
---@param endCol number
---@param tileType string
---@param skipCols table<number,string|boolean> 跳过的列 → 替代类型 or true 表示空
---@param extras? table[]
local function addRowGap(row, startCol, endCol, tileType, skipCols, extras)
    local extraMap = {}
    if extras then
        for _, e in ipairs(extras) do
            extraMap[e[1]] = e
        end
    end
    for c = startCol, endCol do
        local ex = extraMap[c]
        local skip = skipCols[c]
        if ex then
            local t = {
                col = c, row = row,
                type = ex.type or tileType,
                name = ex.name,
                portId = ex.portId,
                nation = ex.nation,
                resource = ex.resource,
            }
            tiles[#tiles + 1] = t
        elseif skip then
            if type(skip) == "string" then
                tiles[#tiles + 1] = { col = c, row = row, type = skip }
            end
            -- skip == true: 什么都不放
        else
            tiles[#tiles + 1] = { col = c, row = row, type = tileType }
        end
    end
end

--- 添加单个瓦片
local function addTile(col, row, tileType, name, portId, nation, resource)
    tiles[#tiles + 1] = {
        col = col, row = row, type = tileType,
        name = name, portId = portId, nation = nation, resource = resource,
    }
end

-- ══════════════════════════════════════════════════════
-- 地图布局（72列 × 40行）
--
--   col  0-22  →  美洲
--   col 20-50  →  大西洋
--   col 44-71  →  欧洲 + 非洲
--
--   row  0-3   →  北极冻土 / 冰岛 / 斯堪的纳维亚
--   row  4-8   →  加拿大 / 北欧
--   row  9-13  →  美东海岸 / 英法德
--   row 14-17  →  佛罗里达·墨西哥湾 / 伊比利亚·意大利
--   row 18-21  →  加勒比·中美 / 北非·撒哈拉
--   row 22-27  →  南美北部·巴西凸起 / 西非凸起
--   row 28-33  →  巴西南部 / 中非·安哥拉
--   row 34-39  →  阿根廷·巴塔哥尼亚 / 南非
-- ══════════════════════════════════════════════════════

-- ╔═══════════════════════════════════════════════════╗
-- ║  北美大陆                                          ║
-- ╚═══════════════════════════════════════════════════╝

-- Row 0: 北极冻土
addRow(0, 2, 18, "tundra")

-- Row 1: 加拿大极北—最宽
addRow(1, 1, 20, "tundra")

-- Row 2: 加拿大北部—寒带森林开始
addRow(2, 1, 20, "tundra", {
    {4, resource = "fur"},
    {14, resource = "fur"},
})

-- Row 3: 哈德逊湾入口出现
addRowGap(3, 0, 20, "landAmerica", {[10]="shallowOcean", [11]="shallowOcean", [12]="shallowOcean"}, {
    {0, type = "tundra"}, {1, type = "tundra"},
    {3, resource = "timber"}, {17, resource = "timber"},
    {19, type = "tundra"}, {20, type = "tundra"},
})

-- Row 4: 哈德逊湾扩大
addRowGap(4, 0, 20, "landAmerica", {[9]="shallowOcean", [10]="shallowOcean", [11]="shallowOcean", [12]="shallowOcean"}, {
    {0, type = "tundra"},
    {5, resource = "timber"},
    {19, type = "colonyWild"}, {20, type = "colonyWild"},
})

-- Row 5: 哈德逊湾南部 + 拉布拉多
addRowGap(5, 0, 20, "landAmerica", {[10]="shallowOcean", [11]="shallowOcean"}, {
    {7, resource = "timber"},
    {18, resource = "timber"},
    {19, type = "colonyWild"}, {20, type = "colonyWild", resource = "timber"},
})

-- Row 6: 五大湖区
addRowGap(6, 0, 19, "landAmerica", {[8]="shallowOcean", [9]="shallowOcean"}, {
    {5, resource = "timber"},
    {17, type = "colonyWild"},
    {18, type = "shallowOcean"}, -- 圣劳伦斯湾
    {19, type = "shallowOcean"},
})

-- Row 7: 五大湖南 + 新英格兰
addRowGap(7, 0, 18, "landAmerica", {[9]="shallowOcean"}, {
    {3, resource = "timber"},
    {16, type = "colonyWild", resource = "timber"},
    {17, type = "colonyWild"},
    {18, type = "shallowOcean"},
})

-- Row 8: 新英格兰海岸
addRow(8, 0, 17, "landAmerica", {
    {14, type = "colonyWild", resource = "timber"},
    {15, type = "colonyWild"},
    {16, type = "colonyPort", name = "波士顿", portId = "boston", nation = "england"},
    {17, type = "shallowOcean"},
})

-- Row 9: 阿巴拉契亚山脉 + 纽约
addRow(9, 0, 16, "landAmerica", {
    {3, type = "mountain"}, {4, type = "mountain"},
    {12, type = "colonyWild"},
    {13, type = "colonyWild"},
    {14, type = "colonyPort", name = "纽约", portId = "new_york", nation = "england"},
    {15, type = "shallowOcean"},
    {16, type = "shallowOcean"},
})

-- Row 10: 弗吉尼亚
addRow(10, 0, 14, "landAmerica", {
    {3, type = "mountain"}, {4, type = "mountain"},
    {9, resource = "tobacco"},
    {10, type = "colonyWild", resource = "tobacco"},
    {11, type = "colonyWild", resource = "cotton"},
    {12, type = "colonyPort", name = "詹姆斯敦", portId = "jamestown", nation = "england"},
    {13, type = "shallowOcean"},
    {14, type = "shallowOcean"},
})

-- Row 11: 卡罗来纳
addRow(11, 0, 13, "landAmerica", {
    {2, type = "mountain"}, {3, type = "mountain"},
    {8, resource = "cotton"}, {9, resource = "cotton"},
    {10, type = "colonyWild"},
    {11, type = "colonyPort", name = "查尔斯顿", portId = "charleston", nation = "england"},
    {12, type = "shallowOcean"},
    {13, type = "shallowOcean"},
})

-- Row 12: 乔治亚 + 佛罗里达北部
addRow(12, 0, 12, "landAmerica", {
    {2, type = "mountain"},
    {9, type = "colonyWild"},
    {10, type = "colonyWild"},
    {11, type = "shallowOcean"},
    {12, type = "shallowOcean"},
})

-- Row 13: 佛罗里达半岛开始
addRowGap(13, 0, 11, "landAmerica", {}, {
    {8, type = "landAmerica"},
    {9, type = "landAmerica"},
    {10, type = "shallowOcean"},
    {11, type = "shallowOcean"},
})

-- Row 14: 墨西哥湾 + 佛罗里达半岛
addRow(14, 0, 5, "landAmerica", {
    {0, resource = "silver"},
})
addTile(6, 14, "shallowOcean") -- 墨西哥湾
addTile(7, 14, "shallowOcean")
addTile(8, 14, "shallowOcean")
addTile(9, 14, "landAmerica") -- 佛罗里达半岛
addTile(10, 14, "shallowOcean")

-- Row 15: 墨西哥 + 古巴
addRow(15, 0, 4, "landAmerica", {
    {2, type = "colonyPort", name = "韦拉克鲁斯", portId = "veracruz", nation = "spain"},
    {3, resource = "silver"},
})
addTile(5, 15, "shallowOcean") -- 墨西哥湾
addTile(6, 15, "shallowOcean")
addTile(7, 15, "shallowOcean")
addTile(8, 15, "shallowOcean")
addTile(9, 15, "shallowOcean") -- 佛罗里达尖端
addTile(10, 15, "shallowOcean")

-- Row 16: 尤卡坦 + 古巴
addRow(16, 0, 3, "landAmerica")
addTile(4, 16, "shallowOcean")
addTile(5, 16, "shallowOcean")
addTile(6, 16, "shallowOcean") -- 墨西哥湾
addTile(10, 16, "colonyPort", "哈瓦那", "havana", "spain", "tobacco")
addTile(11, 16, "colonyWild", nil, nil, nil, "sugar")
addTile(12, 16, "colonyWild")

-- Row 17: 中美地峡 + 加勒比
addTile(0, 17, "landAmerica")
addTile(1, 17, "landAmerica")
addTile(2, 17, "colonyPort", "巴拿马", "panama", "spain")
addTile(3, 17, "shallowOcean")
addTile(4, 17, "shallowOcean")
addTile(9, 17, "shallowOcean")
addTile(10, 17, "colonyPort", "牙买加", "jamaica", "england", "sugar")
addTile(11, 17, "colonyPort", "圣多明各", "santo_domingo", "spain")
addTile(12, 17, "shallowOcean")

-- Row 18: 加勒比小安的列斯
addTile(0, 18, "landAmerica") -- 哥伦比亚北
addTile(1, 18, "landAmerica")
addTile(2, 18, "shallowOcean")
addTile(3, 18, "shallowOcean")
addTile(11, 18, "colonyPort", "波多黎各", "puerto_rico", "spain")
addTile(12, 18, "colonyPort", "巴巴多斯", "barbados", "england", "sugar")
addTile(13, 18, "colonyWild", nil, nil, nil, "spice") -- 格林纳达

-- ╔═══════════════════════════════════════════════════╗
-- ║  南美大陆 — 精细轮廓                               ║
-- ╚═══════════════════════════════════════════════════╝

-- Row 19: 委内瑞拉/哥伦比亚
addRow(19, 0, 9, "landAmerica", {
    {0, type = "mountain"}, -- 安第斯
    {1, type = "mountain"},
    {4, type = "colonyPort", name = "加拉加斯", portId = "caracas", nation = "spain"},
    {7, type = "colonyWild", resource = "sugar"},
    {8, type = "colonyWild"},
    {9, type = "shallowOcean"},
})

-- Row 20: 圭亚那 + 亚马逊入口
addRow(20, 0, 11, "landAmerica", {
    {0, type = "mountain"},
    {1, type = "mountain"},
    {3, resource = "silver"},
    {8, type = "colonyWild"},
    {9, type = "colonyWild"},
    {10, type = "colonyWild"},
    {11, type = "shallowOcean"},
})

-- Row 21: 亚马逊盆地
addRow(21, 0, 13, "landAmerica", {
    {0, type = "mountain"},
    {1, type = "mountain"},
    {4, type = "jungle"},
    {5, type = "jungle"},
    {6, type = "jungle"},
    {7, type = "jungle"},
    {10, type = "colonyWild"},
    {11, type = "colonyWild", resource = "sugar"},
    {12, type = "colonyWild"},
    {13, type = "shallowOcean"},
})

-- Row 22: 亚马逊 + 巴西凸起开始
addRow(22, 0, 15, "landAmerica", {
    {0, type = "mountain"},
    {1, type = "mountain"},
    {3, type = "jungle"},
    {4, type = "jungle"},
    {5, type = "jungle"},
    {6, type = "jungle"},
    {7, type = "jungle"},
    {11, resource = "sugar"},
    {13, type = "colonyWild", resource = "sugar"},
    {14, type = "colonyWild"},
    {15, type = "shallowOcean"},
})

-- Row 23: 巴西东北凸起最宽！
addRow(23, 0, 17, "landAmerica", {
    {0, type = "mountain"},
    {1, type = "mountain"},
    {3, type = "jungle"},
    {4, type = "jungle"},
    {5, type = "jungle"},
    {12, resource = "sugar"},
    {14, type = "colonyPort", name = "萨尔瓦多", portId = "salvador", nation = "portugal", resource = "sugar"},
    {15, type = "colonyWild"},
    {16, type = "colonyWild"}, -- 雷西菲
    {17, type = "shallowOcean"},
})

-- Row 24: 巴西东部 — 凸起继续
addRow(24, 0, 16, "landAmerica", {
    {0, type = "mountain"},
    {1, type = "mountain"},
    {3, type = "jungle"},
    {4, type = "jungle"},
    {12, resource = "sugar"},
    {13, type = "colonyWild"},
    {14, type = "colonyWild"},
    {15, type = "colonyWild"},
    {16, type = "shallowOcean"},
})

-- Row 25: 巴西高原
addRow(25, 1, 14, "landAmerica", {
    {1, type = "mountain"},
    {2, type = "mountain"},
    {10, resource = "sugar"},
    {13, type = "colonyWild"},
    {14, type = "shallowOcean"},
})

-- Row 26: 巴西中南
addRow(26, 1, 13, "landAmerica", {
    {1, type = "mountain"},
    {12, type = "colonyWild"},
    {13, type = "shallowOcean"},
})

-- Row 27: 里约区域
addRow(27, 2, 12, "landAmerica", {
    {2, type = "mountain"},
    {10, type = "colonyWild"},
    {11, type = "colonyPort", name = "里约", portId = "rio", nation = "portugal"},
    {12, type = "shallowOcean"},
})

-- Row 28: 巴西南部
addRow(28, 2, 11, "landAmerica", {
    {2, type = "mountain"},
    {10, type = "colonyWild"},
    {11, type = "shallowOcean"},
})

-- Row 29: 乌拉圭/巴拉圭
addRow(29, 3, 10, "landAmerica", {
    {3, type = "mountain"},
    {9, type = "colonyPort", name = "布宜诺斯", portId = "buenos_aires", nation = "spain"},
    {10, type = "shallowOcean"},
})

-- Row 30: 潘帕斯
addRow(30, 3, 9, "landAmerica", {
    {3, type = "mountain"}, {4, type = "mountain"},
    {9, type = "shallowOcean"},
})

-- Row 31: 阿根廷
addRow(31, 4, 8, "landAmerica", {
    {4, type = "mountain"},
    {8, type = "shallowOcean"},
})

-- Row 32: 阿根廷南部
addRow(32, 4, 7, "landAmerica", {
    {4, type = "mountain"},
    {7, type = "shallowOcean"},
})

-- Row 33: 巴塔哥尼亚
addRow(33, 5, 7, "landAmerica", {
    {5, type = "mountain"},
    {7, type = "shallowOcean"},
})

-- Row 34: 巴塔哥尼亚南
addRow(34, 5, 6, "landAmerica", {
    {5, type = "mountain"},
})

-- Row 35: 火地岛
addTile(5, 35, "landAmerica")
addTile(6, 35, "shallowOcean")

-- Row 36: 最南端
addTile(6, 36, "tundra")

-- ╔═══════════════════════════════════════════════════╗
-- ║  大西洋 — 大面积海洋填充                           ║
-- ╚═══════════════════════════════════════════════════╝

-- 逐行填充大西洋海域
-- Row 0-3: 极北大西洋
for c = 19, 42 do addTile(c, 0, "atlantic") end
for c = 21, 42 do addTile(c, 1, "atlantic") end
for c = 21, 43 do addTile(c, 2, "atlantic") end
for c = 21, 43 do addTile(c, 3, "atlantic") end

-- Row 4-8: 北大西洋
for c = 21, 42 do addTile(c, 4, c >= 26 and c <= 32 and "deepOcean" or "atlantic") end
for c = 21, 42 do addTile(c, 5, c >= 25 and c <= 33 and "deepOcean" or "atlantic") end
for c = 20, 41 do addTile(c, 6, c >= 24 and c <= 33 and "deepOcean" or "atlantic") end
for c = 19, 41 do addTile(c, 7, c >= 23 and c <= 32 and "deepOcean" or "atlantic") end
for c = 18, 40 do addTile(c, 8, c >= 22 and c <= 31 and "deepOcean" or "atlantic") end

-- Row 9-13: 中北大西洋
for c = 17, 39 do addTile(c, 9, c >= 21 and c <= 30 and "deepOcean" or "atlantic") end
for c = 15, 38 do addTile(c, 10, c >= 20 and c <= 29 and "deepOcean" or "atlantic") end
for c = 14, 37 do addTile(c, 11, c >= 19 and c <= 28 and "deepOcean" or "atlantic") end
for c = 13, 36 do addTile(c, 12, c >= 19 and c <= 27 and "deepOcean" or "atlantic") end
for c = 12, 35 do addTile(c, 13, c >= 18 and c <= 26 and "deepOcean" or "atlantic") end

-- Row 14-18: 中大西洋 (加勒比以东)
for c = 11, 35 do addTile(c, 14, c >= 18 and c <= 26 and "deepOcean" or "atlantic") end
for c = 11, 35 do addTile(c, 15, c >= 17 and c <= 25 and "deepOcean" or "atlantic") end
for c = 7, 35 do
    if c ~= 10 and c ~= 11 and c ~= 12 then
        addTile(c, 16, c >= 17 and c <= 25 and "deepOcean" or "atlantic")
    end
end
for c = 5, 35 do
    if c ~= 10 and c ~= 11 then
        addTile(c, 17, c >= 17 and c <= 25 and "deepOcean" or "atlantic")
    end
end
for c = 4, 35 do
    if c ~= 11 and c ~= 12 and c ~= 13 then
        addTile(c, 18, c >= 17 and c <= 25 and "deepOcean" or "atlantic")
    end
end

-- Row 19-23: 中南大西洋
for c = 10, 35 do addTile(c, 19, c >= 16 and c <= 25 and "deepOcean" or "atlantic") end
for c = 12, 34 do addTile(c, 20, c >= 16 and c <= 25 and "deepOcean" or "atlantic") end
for c = 14, 34 do addTile(c, 21, c >= 18 and c <= 26 and "deepOcean" or "atlantic") end
for c = 16, 34 do addTile(c, 22, c >= 19 and c <= 27 and "deepOcean" or "atlantic") end
for c = 18, 34 do addTile(c, 23, c >= 20 and c <= 28 and "deepOcean" or "atlantic") end

-- Row 24-28: 南大西洋
for c = 17, 34 do addTile(c, 24, c >= 20 and c <= 27 and "deepOcean" or "atlantic") end
for c = 15, 34 do addTile(c, 25, c >= 19 and c <= 27 and "deepOcean" or "atlantic") end
for c = 14, 35 do addTile(c, 26, c >= 19 and c <= 27 and "deepOcean" or "atlantic") end
for c = 13, 36 do addTile(c, 27, c >= 18 and c <= 27 and "deepOcean" or "atlantic") end
for c = 12, 36 do addTile(c, 28, c >= 18 and c <= 27 and "deepOcean" or "atlantic") end

-- Row 29-36: 远南大西洋
for c = 11, 37 do addTile(c, 29, c >= 17 and c <= 27 and "deepOcean" or "atlantic") end
for c = 10, 37 do addTile(c, 30, c >= 16 and c <= 27 and "deepOcean" or "atlantic") end
for c = 9, 38 do addTile(c, 31, c >= 15 and c <= 27 and "deepOcean" or "atlantic") end
for c = 8, 38 do addTile(c, 32, c >= 14 and c <= 27 and "deepOcean" or "atlantic") end
for c = 8, 39 do addTile(c, 33, c >= 14 and c <= 28 and "deepOcean" or "atlantic") end
for c = 7, 39 do addTile(c, 34, "atlantic") end
for c = 7, 40 do addTile(c, 35, "atlantic") end
for c = 7, 40 do addTile(c, 36, "atlantic") end
for c = 7, 40 do addTile(c, 37, "atlantic") end
for c = 7, 40 do addTile(c, 38, "atlantic") end
for c = 7, 40 do addTile(c, 39, "atlantic") end

-- ╔═══════════════════════════════════════════════════╗
-- ║  冰岛                                              ║
-- ╚═══════════════════════════════════════════════════╝
addTile(43, 0, "shallowOcean")
addTile(44, 0, "landNordic", "冰岛")
addTile(45, 0, "landNordic")
addTile(46, 0, "shallowOcean")

-- ╔═══════════════════════════════════════════════════╗
-- ║  斯堪的纳维亚半岛 — 极窄（2-3格宽）               ║
-- ╚═══════════════════════════════════════════════════╝
-- Row 0: 北角（2格宽）
addTile(49, 0, "landNordic", "北角", nil, nil, "timber")
addTile(50, 0, "landNordic")
-- Row 1: 挪威/瑞典（3格宽）
addTile(48, 1, "landNordic", "挪威")
addTile(49, 1, "landNordic")
addTile(50, 1, "landNordic", "瑞典", nil, nil, "iron")
-- Row 2: 中斯堪（3格宽）
addTile(48, 2, "landNordic", "卑尔根", nil, nil, "timber")
addTile(49, 2, "landNordic")
addTile(50, 2, "landNordic", "斯德哥尔摩")
-- Row 3: 南部（2格）
addTile(48, 3, "landNordic") -- 挪威南端
addTile(49, 3, "landNordic") -- 瑞典南
-- Row 4: 丹麦
addTile(48, 4, "landNordic", "哥本哈根")

-- 挪威海（冰岛与斯堪的纳维亚之间）
addTile(47, 0, "shallowOcean")
addTile(48, 0, "shallowOcean")
addTile(47, 1, "shallowOcean")
addTile(47, 2, "shallowOcean")
addTile(47, 3, "shallowOcean") -- 北海北部

-- 波罗的海（斯堪的纳维亚与芬兰之间的水域）
addTile(51, 0, "shallowOcean")
addTile(52, 0, "shallowOcean")
addTile(51, 1, "shallowOcean")
addTile(51, 2, "shallowOcean")
addTile(50, 3, "shallowOcean")
addTile(51, 3, "shallowOcean")
addTile(49, 4, "shallowOcean") -- 波罗的海入口
addTile(50, 4, "shallowOcean")
addTile(51, 4, "shallowOcean")

-- ╔═══════════════════════════════════════════════════╗
-- ║  芬兰（独立区域，波罗的海东岸）                     ║
-- ╚═══════════════════════════════════════════════════╝
addTile(53, 0, "landNordic", "芬兰")
addTile(54, 0, "landNordic")
addTile(52, 1, "landNordic", "芬兰")
addTile(53, 1, "landNordic")
addTile(52, 2, "landNordic")
addTile(53, 2, "landNordic")
addTile(52, 3, "landNordic") -- 芬兰南/爱沙尼亚

-- ╔═══════════════════════════════════════════════════╗
-- ║  英国群岛 — 独立岛屿                                ║
-- ╚═══════════════════════════════════════════════════╝
-- 爱尔兰
addTile(43, 2, "europeCity", "都柏林")
addTile(43, 3, "europeCity") -- 爱尔兰南
-- 苏格兰
addTile(45, 1, "europeCity", "爱丁堡")
addTile(46, 1, "europeCity") -- 苏格兰东
-- 英格兰
addTile(45, 2, "europeCity")
addTile(46, 2, "europePort", "伦敦", "london", "england", "coal")
addTile(46, 3, "europeCity") -- 英格兰南

-- 北海（英国与大陆之间）
addTile(44, 1, "shallowOcean") -- 苏格兰-挪威间
addTile(44, 2, "shallowOcean") -- 北海中
addTile(44, 3, "shallowOcean") -- 北海
addTile(45, 3, "shallowOcean") -- 北海南
-- 英吉利海峡
addTile(44, 4, "shallowOcean")
addTile(45, 4, "shallowOcean")
addTile(46, 4, "shallowOcean")
-- 爱尔兰海
addTile(43, 1, "shallowOcean")
addTile(42, 2, "shallowOcean")
addTile(42, 3, "shallowOcean")

-- ╔═══════════════════════════════════════════════════╗
-- ║  低地国家 + 北德 + 波兰                             ║
-- ╚═══════════════════════════════════════════════════╝
addTile(47, 4, "europePort", "阿姆斯特丹", "amsterdam", "netherlands")
addTile(48, 4, "europeCity", nil, nil, nil, "coal") -- 鲁尔
addTile(47, 5, "europeCity", "布鲁塞尔")
addTile(48, 5, "europePort", "汉堡", "hamburg", "prussia")
addTile(49, 5, "europeCity", "柏林")
addTile(50, 5, "europeCity") -- 波兰
addTile(51, 5, "europeCity") -- 波兰东

-- ╔═══════════════════════════════════════════════════╗
-- ║  法兰西 — 大块梯形                                  ║
-- ╚═══════════════════════════════════════════════════╝
addTile(43, 4, "shallowOcean") -- 布列塔尼北海
addTile(43, 5, "europeCity") -- 布列塔尼
addTile(44, 5, "europeCity", "巴黎")
addTile(45, 5, "europeCity")
addTile(46, 5, "europeCity") -- 里昂
addTile(43, 6, "shallowOcean") -- 比斯开湾
addTile(44, 6, "europePort", "波尔多", "bordeaux", "france")
addTile(45, 6, "europeCity")
addTile(46, 6, "europeCity", "马赛")

-- 比斯开湾
addTile(42, 4, "shallowOcean")
addTile(42, 5, "shallowOcean")
addTile(42, 6, "shallowOcean")
addTile(42, 7, "shallowOcean")
addTile(43, 7, "shallowOcean")

-- ╔═══════════════════════════════════════════════════╗
-- ║  中欧 — 德意志/奥地利/匈牙利                       ║
-- ╚═══════════════════════════════════════════════════╝
addTile(47, 6, "europeCity", "慕尼黑")
addTile(48, 6, "europeCity", "维也纳")
addTile(49, 6, "europeCity") -- 匈牙利
addTile(50, 6, "europeCity")

-- ╔═══════════════════════════════════════════════════╗
-- ║  东欧 / 俄罗斯西部（紧凑，到col 57）               ║
-- ╚═══════════════════════════════════════════════════╝
-- Row 0: 俄罗斯极北
addRow(0, 55, 58, "steppe")
-- Row 1: 俄罗斯北
addRow(1, 54, 58, "steppe", {
    {56, resource = "timber"},
})
-- Row 2: 俄罗斯
addRow(2, 54, 57, "steppe")
-- Row 3: 俄罗斯（莫斯科）
addRow(3, 53, 57, "steppe", {
    {55, name = "莫斯科"},
    {56, resource = "timber"},
})
-- Row 4: 波兰东 + 俄
addRow(4, 52, 56, "steppe", {
    {52, type = "europeCity"}, -- 波兰
})
-- Row 5: 东欧
addRow(5, 52, 55, "steppe")
-- Row 6: 乌克兰
addRow(6, 51, 55, "steppe")

-- ╔═══════════════════════════════════════════════════╗
-- ║  伊比利亚半岛 — 方形，row 7-9                      ║
-- ╚═══════════════════════════════════════════════════╝
addTile(43, 8, "europePort", "里斯本", "lisbon", "portugal")
addTile(44, 7, "europeCity") -- 北部
addTile(45, 7, "europeCity")
addTile(44, 8, "europeCity", "马德里")
addTile(45, 8, "europeCity")
addTile(46, 8, "europeCity", "巴塞罗那")
addTile(44, 9, "europePort", "塞维利亚", "seville", "spain")
addTile(45, 9, "europeCity") -- 安达卢西亚东
-- 直布罗陀
addTile(43, 9, "shallowOcean") -- 大西洋侧
addTile(46, 9, "shallowOcean") -- 地中海入口

-- ╔═══════════════════════════════════════════════════╗
-- ║  意大利半岛 — 靴子形 row 6-10                      ║
-- ╚═══════════════════════════════════════════════════╝
-- 北意/阿尔卑斯
addTile(47, 7, "europeCity", "热那亚")
addTile(48, 7, "europePort", "威尼斯", "venice", "venice", "iron")
-- 中意（罗马）
addTile(47, 8, "europeCity", "罗马")
addTile(48, 8, "shallowOcean") -- 亚得里亚海
-- 南意（那不勒斯→脚尖）
addTile(47, 9, "europeCity", "那不勒斯")
addTile(48, 9, "shallowOcean") -- 亚得里亚海南
-- 西西里 + 脚尖
addTile(47, 10, "europeCity") -- 西西里
addTile(48, 10, "shallowOcean") -- 爱奥尼亚海

-- ╔═══════════════════════════════════════════════════╗
-- ║  巴尔干 / 东南欧 / 奥斯曼                          ║
-- ╚═══════════════════════════════════════════════════╝
addTile(49, 7, "europeCity") -- 克罗地亚
addTile(50, 7, "europeCity") -- 塞尔维亚
addTile(51, 7, "europeCity") -- 罗马尼亚
addTile(52, 7, "europeCity") -- 黑海沿岸
addTile(49, 8, "europeCity") -- 波黑
addTile(50, 8, "europeCity") -- 保加利亚
addTile(51, 8, "europeCity", "君士坦丁堡")
addTile(52, 8, "europeCity") -- 安纳托利亚西
addTile(53, 8, "europeCity") -- 安纳托利亚
addTile(49, 9, "shallowOcean") -- 爱琴海
addTile(50, 9, "europeCity") -- 希腊
addTile(51, 9, "shallowOcean") -- 爱琴海
addTile(52, 9, "europeCity") -- 安纳托利亚南
addTile(53, 9, "europeCity")
addTile(54, 9, "europeCity") -- 叙利亚
-- 希腊南部（伯罗奔尼撒）
addTile(50, 10, "europeCity") -- 雅典
-- 安纳托利亚东 + 黎凡特
addTile(54, 8, "europeCity")
addTile(55, 8, "europeCity") -- 安纳托利亚东
addTile(55, 9, "europeCity") -- 黎凡特
addTile(55, 10, "shallowOcean") -- 东地中海

-- 黑海
addRow(7, 53, 58, "shallowOcean")
addRow(8, 54, 59, "shallowOcean")

-- ╔═══════════════════════════════════════════════════╗
-- ║  地中海 — 精细填充                                  ║
-- ╚═══════════════════════════════════════════════════╝
-- 西地中海（row 8-9 法国-西班牙之间）— 已由具体tiles覆盖

-- 中地中海（row 10-11 全水域带，仅 Sicily/Athens 作为小岛突出）
addRow(10, 47, 55, "shallowOcean") -- row 10 东部全部为海（41-46已由北非段覆盖）
addRow(11, 46, 55, "shallowOcean") -- row 11 全部为海（40-45已由北非段覆盖）
addRow(9, 53, 55, "shallowOcean") -- 东地中海补充

-- ╔═══════════════════════════════════════════════════╗
-- ║  欧洲周边浅海补充                                   ║
-- ╚═══════════════════════════════════════════════════╝
-- 大西洋到欧洲过渡（补充之前大西洋没覆盖到的格子）
addTile(41, 4, "shallowOcean")
addTile(41, 5, "shallowOcean")
addTile(41, 6, "shallowOcean")
addTile(41, 7, "shallowOcean")
addTile(41, 8, "shallowOcean")
addTile(41, 9, "shallowOcean")
addTile(42, 8, "shallowOcean")
addTile(42, 9, "shallowOcean")
addTile(42, 10, "shallowOcean") -- 直布罗陀以南
addTile(43, 10, "shallowOcean") -- 摩洛哥以北
addTile(42, 11, "shallowOcean")
addTile(43, 11, "shallowOcean")

-- ╔═══════════════════════════════════════════════════╗
-- ║  北非 — 摩洛哥到埃及（row 10-16）                  ║
-- ╚═══════════════════════════════════════════════════╝

-- Row 10: 地中海水域（欧洲与北非之间——全部为海，仅保留小岛）
for c = 41, 46 do addTile(c, 10, "shallowOcean") end
-- 补回被地中海 addRow 覆盖的岛屿（确保在所有海水之后）
addTile(47, 10, "europeCity") -- 西西里岛
addTile(50, 10, "europeCity") -- 雅典/克里特

-- Row 11: 地中海南部水域（北非海岸以北——全部为海）
for c = 40, 55 do addTile(c, 11, "shallowOcean") end

-- Row 12: 北非海岸（马格里布→埃及，地中海南岸）
addRow(12, 40, 55, "landMediterr", {
    {40, type = "shallowOcean"},
    {41, type = "shallowOcean"},
    {42, name = "丹吉尔"},
    {43, name = "摩洛哥"},
    {45, name = "阿尔及尔"},
    {47, name = "突尼斯"},
    {48, type = "desert"},
    {49, type = "desert"},
    {50, type = "desert", name = "昔兰尼加"},
    {51, type = "desert"},
    {52, type = "desert"},
    {53, type = "desert"},
    {54, type = "landAfrica", name = "开罗"},
    {55, type = "landAfrica", name = "亚历山大", resource = "cotton"},
})

-- Row 13: 撒哈拉
addRow(13, 40, 55, "desert", {
    {40, type = "shallowOcean"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- Row 14: 撒哈拉腹地
addRow(14, 40, 55, "desert", {
    {40, type = "shallowOcean"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- Row 15: 撒哈拉南缘→萨赫勒过渡
addRow(15, 39, 55, "desert", {
    {39, type = "shallowOcean"},
    {40, type = "shallowOcean"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- Row 16: 萨赫勒
addRow(16, 38, 55, "savanna", {
    {38, type = "shallowOcean"},
    {39, type = "shallowOcean"},
    {40, type = "desert"},
    {41, type = "desert"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- ╔═══════════════════════════════════════════════════╗
-- ║  西非 — 凸起更明显 (row 17-21)                     ║
-- ╚═══════════════════════════════════════════════════╝

-- Row 17: 塞内加尔凸起尖端
addRow(17, 36, 55, "savanna", {
    {36, type = "shallowOcean"},
    {37, type = "africaPort", name = "达喀尔", portId = "dakar", nation = "none"},
    {38, type = "savanna"},
    {39, type = "savanna"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- Row 18: 西非凸起（几内亚湾上方）
addRow(18, 35, 55, "savanna", {
    {35, type = "shallowOcean"},
    {36, type = "shallowOcean"},
    {37, type = "landAfrica"},
    {38, type = "landAfrica"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- Row 19: 几内亚沿海（最凸）
addRow(19, 35, 55, "landAfrica", {
    {35, type = "shallowOcean"},
    {36, type = "shallowOcean"},
    {37, type = "africaPort", name = "黄金海岸", portId = "gold_coast", nation = "none", resource = "gold"},
    {38, type = "landAfrica"},
    {39, type = "africaPort", name = "拉各斯", portId = "lagos", nation = "none"},
    {40, type = "landAfrica"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- Row 20: 几内亚湾内凹（海水深入）
addRowGap(20, 37, 55, "landAfrica", {
    [37]="shallowOcean", [38]="shallowOcean", [39]="shallowOcean", [40]="shallowOcean",
}, {
    {41, type = "jungle"},
    {42, type = "jungle"},
    {43, type = "jungle"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- Row 21: 刚果盆地
addRowGap(21, 38, 55, "landAfrica", {
    [38]="shallowOcean", [39]="shallowOcean",
}, {
    {40, type = "jungle"},
    {41, type = "jungle"},
    {42, type = "jungle"},
    {43, type = "jungle"},
    {44, type = "jungle"},
    {45, type = "jungle"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- ╔═══════════════════════════════════════════════════╗
-- ║  中非 + 东非 (row 22-27)                           ║
-- ╚═══════════════════════════════════════════════════╝

-- Row 22: 刚果/安哥拉 + 东非
addRow(22, 39, 55, "landAfrica", {
    {39, type = "shallowOcean"},
    {40, type = "africaPort", name = "罗安达", portId = "luanda", nation = "portugal"},
    {41, type = "jungle"},
    {42, type = "jungle"},
    {43, type = "jungle"},
    {44, type = "jungle"},
    {53, type = "savanna"},
    {54, type = "savanna"},
    {55, type = "landAfrica"}, -- 东非海岸
})

-- Row 23: 安哥拉 + 坦噶尼喀 + 非洲之角
addRow(23, 39, 57, "landAfrica", {
    {39, type = "shallowOcean"},
    {40, type = "shallowOcean"},
    {41, type = "landAfrica"},
    {42, type = "savanna"},
    {43, type = "savanna"},
    {53, type = "savanna"},
    {54, type = "savanna"},
    {55, type = "landAfrica"},
    {56, type = "landAfrica"}, -- 非洲之角（索马里）
    {57, type = "landAfrica"}, -- 索马里尖端
})

-- Row 24: 赞比亚/坦桑尼亚
addRow(24, 40, 55, "landAfrica", {
    {40, type = "shallowOcean"},
    {41, type = "shallowOcean"},
    {42, type = "savanna"},
    {43, type = "savanna"},
    {44, type = "savanna"},
    {53, type = "savanna"},
    {54, type = "landAfrica"},
    {55, type = "landAfrica"},
})

-- Row 25: 莫桑比克/马拉维
addRow(25, 41, 54, "landAfrica", {
    {41, type = "shallowOcean"},
    {42, type = "shallowOcean"},
    {43, type = "savanna"},
    {44, type = "savanna"},
    {52, type = "savanna"},
    {53, type = "landAfrica"},
    {54, type = "landAfrica"},
})

-- Row 26: 津巴布韦/莫桑比克
addRow(26, 41, 53, "landAfrica", {
    {41, type = "shallowOcean"},
    {42, type = "shallowOcean"},
    {43, type = "landAfrica"},
    {44, type = "savanna"},
    {51, type = "savanna"},
    {52, type = "landAfrica"},
    {53, type = "landAfrica"},
})

-- ╔═══════════════════════════════════════════════════╗
-- ║  南非 — 自然收窄到好望角 (row 27-33)               ║
-- ╚═══════════════════════════════════════════════════╝

-- Row 27: 纳米比亚/博茨瓦纳/莫桑比克南
addRow(27, 42, 52, "landAfrica", {
    {42, type = "shallowOcean"},
    {43, type = "shallowOcean"},
    {44, type = "landAfrica"},
    {45, type = "savanna"},
    {50, type = "savanna"},
    {51, type = "landAfrica"},
    {52, type = "landAfrica"},
})

-- Row 28: 南非北部
addRow(28, 43, 51, "landAfrica", {
    {43, type = "shallowOcean"},
    {44, type = "shallowOcean"},
    {45, type = "landAfrica"},
    {46, type = "savanna"},
    {50, type = "landAfrica"},
    {51, type = "landAfrica"},
})

-- Row 29: 南非中部
addRow(29, 44, 50, "landAfrica", {
    {44, type = "shallowOcean"},
    {45, type = "shallowOcean"},
    {46, type = "landAfrica"},
    {49, type = "landAfrica"},
    {50, type = "landAfrica"},
})

-- Row 30: 南非南部（开普省）
addRow(30, 45, 49, "landAfrica", {
    {45, type = "shallowOcean"},
    {46, type = "shallowOcean"},
    {49, type = "landAfrica"},
})

-- Row 31: 好望角区域
addTile(46, 31, "shallowOcean")
addTile(47, 31, "landAfrica")
addTile(48, 31, "landAfrica")
addTile(49, 31, "shallowOcean")

-- Row 32: 好望角尖端
addTile(47, 32, "landAfrica")
addTile(48, 32, "shallowOcean")

-- Row 33: 最南端
addTile(47, 33, "shallowOcean")

-- ── 非洲侧大西洋补充 ───
for c = 35, 39 do addTile(c, 20, "atlantic") end
for c = 36, 40 do addTile(c, 21, "atlantic") end
for c = 37, 39 do addTile(c, 22, "atlantic") end
for c = 37, 39 do addTile(c, 23, "atlantic") end
for c = 38, 40 do addTile(c, 24, "atlantic") end
for c = 39, 41 do addTile(c, 25, "atlantic") end
for c = 39, 41 do addTile(c, 26, "atlantic") end
for c = 40, 42 do addTile(c, 27, "atlantic") end
for c = 41, 43 do addTile(c, 28, "atlantic") end
for c = 42, 44 do addTile(c, 29, "atlantic") end
for c = 43, 45 do addTile(c, 30, "atlantic") end
for c = 44, 46 do addTile(c, 31, "atlantic") end
for c = 44, 47 do addTile(c, 32, "atlantic") end
for c = 44, 47 do addTile(c, 33, "atlantic") end
for c = 44, 47 do addTile(c, 34, "atlantic") end
for c = 44, 47 do addTile(c, 35, "atlantic") end
for c = 44, 47 do addTile(c, 36, "atlantic") end
for c = 44, 47 do addTile(c, 37, "atlantic") end
for c = 44, 47 do addTile(c, 38, "atlantic") end
for c = 44, 47 do addTile(c, 39, "atlantic") end
-- 东非侧海洋补充
for c = 56, 58 do addTile(c, 22, "shallowOcean") end
addTile(58, 23, "shallowOcean") -- 索马里东
for c = 56, 58 do addTile(c, 24, "shallowOcean") end
for c = 55, 57 do addTile(c, 25, "shallowOcean") end
for c = 54, 56 do addTile(c, 26, "shallowOcean") end
for c = 53, 55 do addTile(c, 27, "shallowOcean") end
for c = 52, 54 do addTile(c, 28, "shallowOcean") end
for c = 51, 53 do addTile(c, 29, "shallowOcean") end
for c = 50, 52 do addTile(c, 30, "shallowOcean") end
for c = 49, 51 do addTile(c, 31, "shallowOcean") end
addTile(49, 32, "shallowOcean")
addTile(50, 32, "shallowOcean")
addTile(48, 33, "shallowOcean")
addTile(49, 33, "shallowOcean")

-- ══════════════════════════════════════════════════════
-- 组装最终数据
-- ══════════════════════════════════════════════════════
M.tiles = tiles

-- ── 建立快速查找表 ───────────────────────────────
M.tileMap = {}
for _, tile in ipairs(M.tiles) do
    local key = tile.col .. "," .. tile.row
    M.tileMap[key] = tile
end

--- 根据坐标查找瓦片
function M.GetTile(col, row)
    return M.tileMap[col .. "," .. row]
end

--- 查找港口瓦片
function M.GetPortTile(portId)
    for _, tile in ipairs(M.tiles) do
        if tile.portId == portId then return tile end
    end
    return nil
end

-- ── 贸易航线（港口间弧线）────────────────────────
M.tradeRoutes = {
    -- ═══ 三角贸易（欧洲→非洲→美洲→欧洲）═══
    { from = "bordeaux",    to = "dakar",       type = "triangle", color = {232, 112, 64, 255} },
    { from = "dakar",       to = "barbados",    type = "triangle", color = {160, 64, 160, 255} },
    { from = "barbados",    to = "bordeaux",    type = "triangle", color = { 64, 160, 64, 255} },

    { from = "london",      to = "gold_coast",  type = "triangle", color = {232, 112, 64, 255} },
    { from = "gold_coast",  to = "jamaica",     type = "triangle", color = {160, 64, 160, 255} },
    { from = "jamaica",     to = "london",      type = "triangle", color = { 64, 160, 64, 255} },

    -- ═══ 直贸路线 ═══
    { from = "lisbon",      to = "salvador",    type = "direct",   color = {201, 160, 48, 255} },
    { from = "lisbon",      to = "rio",         type = "direct",   color = {201, 160, 48, 255} },
    { from = "seville",     to = "havana",      type = "direct",   color = {201, 160, 48, 255} },
    { from = "seville",     to = "veracruz",    type = "direct",   color = {201, 160, 48, 255} },
    { from = "amsterdam",   to = "boston",      type = "direct",   color = {201, 160, 48, 255} },
    { from = "hamburg",     to = "jamestown",   type = "direct",   color = {201, 160, 48, 255} },

    -- ═══ 危险航线 ═══
    { from = "jamaica",     to = "gold_coast",  type = "dangerous",color = {220, 80, 80, 255} },
    { from = "luanda",      to = "rio",         type = "dangerous",color = {220, 80, 80, 255} },
}

-- ── 航线图例 ────────────────────────────────────
M.routeLegend = {
    { type = "triangle",  label = "三角贸易", color = {232, 112, 64, 255} },
    { type = "direct",    label = "直贸路线", color = {201, 160, 48, 255} },
    { type = "dangerous", label = "危险航线", color = {220, 80, 80, 255} },
}

-- ── 海域区定义 ──────────────────────────────────
M.seaZones = {
    { id = "north_atlantic", name = "北大西洋",    revenue = 10 },
    { id = "caribbean",      name = "加勒比海",    revenue = 15 },
    { id = "south_atlantic", name = "南大西洋",    revenue = 8  },
    { id = "mediterranean",  name = "地中海",      revenue = 12 },
    { id = "north_sea",      name = "北海",        revenue = 6  },
    { id = "west_indian",    name = "印度洋西部",  revenue = 20 },
}

return M
