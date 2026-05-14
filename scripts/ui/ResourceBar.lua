-- ============================================================================
-- ResourceBar.lua - 顶部资源条（36px 高，水平排列所有资源）
-- 布局: [家族名+年份] | [财富 启蒙 产能 声望 航权 殖民度] | [AP]
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

--- 单个资源指标
local function ResourceItem(res)
    local valText
    if res.value >= 10000 then
        valText = string.format("%.1fk", res.value / 1000)
    else
        valText = tostring(res.value)
    end
    local rateText = res.rate >= 0 and ("+" .. res.rate) or tostring(res.rate)
    local rateColor = res.rate >= 0 and Theme.statusOk or Theme.statusWar

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 2,
        paddingLeft = 6, paddingRight = 6,
        height = 24,
        backgroundColor = {0, 0, 0, 30},
        borderRadius = 4,
        children = {
            UI.Label { text = res.icon, fontSize = 11 },
            UI.Label {
                text = valText,
                fontSize = Theme.fontC1,
                fontColor = Theme.textPrimary,
                fontWeight = "bold",
            },
            UI.Label {
                text = rateText,
                fontSize = Theme.fontTiny,
                fontColor = rateColor,
            },
        },
    }
end

--- 创建资源条
---@param state table GameState
function M.Create(state)
    -- 构建资源列表
    local resChildren = {}
    for _, key in ipairs(state.resourceOrder) do
        local res = state.resources[key]
        resChildren[#resChildren + 1] = ResourceItem(res)
    end

    -- AP 显示
    local apText = Theme.apDisplay(state.ap, state.maxAp)

    return UI.Panel {
        id = "resourceBar",
        width = "100%",
        height = Theme.topBarHeight,
        flexShrink = 0,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 8,
        paddingRight = 8,
        gap = 0,
        backgroundColor = Theme.bgPrimary,
        borderBottomWidth = 1,
        borderBottomColor = Theme.borderSubtle,
        children = {
            -- 左侧：家族名 + 年份
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 6,
                children = {
                    UI.Label {
                        text = state.familyName,
                        fontSize = Theme.fontH2,
                        fontColor = Theme.goldBright,
                        fontWeight = "bold",
                    },
                    UI.Panel {
                        paddingLeft = 6, paddingRight = 6,
                        height = 20,
                        borderRadius = 3,
                        backgroundColor = Theme.bgTertiary,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = tostring(state.year) .. "年",
                                fontSize = Theme.fontB2,
                                fontColor = Theme.textSecondary,
                            },
                        },
                    },
                },
            },

            -- 中间弹性空白
            UI.Panel { width = 12 },

            -- 资源列表
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = 4,
                overflow = "hidden",
                children = resChildren,
            },

            -- 右侧空白
            UI.Panel { width = 8 },

            -- AP 显示
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                height = 24,
                paddingLeft = 8, paddingRight = 8,
                borderRadius = 4,
                backgroundColor = {0, 0, 0, 30},
                children = {
                    UI.Label {
                        text = apText,
                        fontSize = Theme.fontB2,
                        fontColor = Theme.goldMid,
                        fontWeight = "bold",
                    },
                },
            },
        },
    }
end

return M
