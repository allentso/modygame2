-- ============================================================================
-- TopBar.lua - 顶部精简栏（32px，5 元素）
-- 布局：[家族徽章 26px] [年份] [💰 财富] [AP 沙漏] [☰ 菜单]
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

-- ── 盾牌徽章（26×26，点击展开资源详情）─────────
local function Crest(familyName, onCrestClick)
    return UI.Button {
        width = 26, height = 26,
        borderRadius = 4,
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = Theme.goldMid, to = Theme.goldDark,
        },
        borderWidth = 1.5,
        borderColor = Theme.goldBright,
        justifyContent = "center",
        alignItems = "center",
        text = string.sub(familyName, 1, 3),
        fontSize = 11,
        fontColor = Theme.wood0,
        fontWeight = "bold",
        onClick = function(self)
            if onCrestClick then onCrestClick() end
        end,
    }
end

--- 创建顶栏
---@param state table GameState
---@param callbacks table { onCrestClick, onMenuClick }
function M.Create(state, callbacks)
    callbacks = callbacks or {}

    -- 财富显示（唯一在顶栏显示的资源）
    local wealth = state.resources.wealth
    local wealthVal = wealth.value >= 10000
        and string.format("%.1fk", wealth.value / 1000)
        or tostring(wealth.value)
    local wealthRate = wealth.rate >= 0 and ("+" .. wealth.rate) or tostring(wealth.rate)
    local rateColor = wealth.rate >= 0 and Theme.statusOk or Theme.statusWar

    -- AP 显示
    local apText = Theme.apDisplay(state.ap, state.maxAp)

    return UI.Panel {
        id = "topBar",
        width = "100%",
        height = Theme.topBarHeight,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 6,
        paddingRight = 4,
        gap = 0,
        backgroundColor = Theme.wood1,
        borderBottomWidth = 1.5,
        borderBottomColor = Theme.goldDark,
        boxShadow = {
            { x = 0, y = 2, blur = 6, spread = 0, color = {40, 25, 10, 100} },
        },
        children = {
            -- 1. 家族徽章
            Crest(state.familyName, callbacks.onCrestClick),

            -- 间隔
            UI.Panel { width = 6 },

            -- 2. 年份
            UI.Label {
                text = tostring(state.year) .. "年",
                fontSize = Theme.fontB1,
                fontColor = Theme.parchment1,
                fontWeight = "bold",
            },

            -- 弹性空白
            UI.Panel { flexGrow = 1 },

            -- 3. 财富（唯一显示的资源）
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 3,
                paddingLeft = 6, paddingRight = 6,
                height = 24,
                backgroundColor = {0, 0, 0, 40},
                borderRadius = 4,
                children = {
                    UI.Label { text = wealth.icon, fontSize = 12 },
                    UI.Label {
                        text = wealthVal,
                        fontSize = Theme.fontC1,
                        fontColor = Theme.goldBright,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        text = wealthRate,
                        fontSize = Theme.fontTiny,
                        fontColor = rateColor,
                    },
                },
            },

            UI.Panel { width = 6 },

            -- 4. AP 沙漏
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                height = 24,
                paddingLeft = 4, paddingRight = 4,
                children = {
                    UI.Label {
                        text = apText,
                        fontSize = 10,
                        fontColor = Theme.goldMid,
                        letterSpacing = 1,
                    },
                },
            },

            UI.Panel { width = 4 },

            -- 5. 汉堡菜单
            UI.Button {
                width = 26, height = 26,
                borderRadius = 4,
                backgroundColor = {0, 0, 0, 0},
                hoverBackgroundColor = Theme.wood2,
                text = "☰",
                fontSize = 16,
                fontColor = Theme.parchment2,
                onClick = function(self)
                    if callbacks.onMenuClick then callbacks.onMenuClick() end
                end,
            },
        },
    }
end

return M
