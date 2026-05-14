-- ============================================================================
-- DiplomacyPanel.lua - 外交面板（羊皮纸风格）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

--- 国家关系行（卡片样式）
local function DiplomacyRow(entry)
    local relColor = entry.relation >= 0 and Theme.statusOk or Theme.statusWar
    local statusColor = Theme.getRelationColor(entry.status)
    local statusLabel = Theme.getRelationLabel(entry.status)
    local barValue = (entry.relation + 100) / 200  -- -100~100 -> 0~1

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        padding = 8,
        backgroundColor = Theme.parchment0,
        borderRadius = 6,
        borderWidth = 1,
        borderColor = Theme.parchment3,
        boxShadow = Theme.shadowPanel,
        children = {
            -- 国旗色标（带边框）
            UI.Panel {
                width = 32, height = 22,
                borderRadius = 3,
                backgroundColor = entry.color,
                borderWidth = 1,
                borderColor = {255, 255, 255, 60},
                boxShadow = {
                    { x = 0, y = 1, blur = 2, spread = 0, color = {80, 50, 20, 40} },
                },
            },
            -- 国名
            UI.Label {
                text = entry.nation,
                fontSize = Theme.fontB1,
                fontColor = Theme.ink0,
                fontWeight = "bold",
                width = 55,
            },
            -- 关系条
            UI.Panel {
                flexGrow = 1, flexBasis = 0,
                gap = 2,
                children = {
                    UI.ProgressBar {
                        value = barValue,
                        height = 8,
                        trackColor = Theme.parchment3,
                        fillColor = relColor,
                        borderRadius = 4,
                    },
                },
            },
            -- 关系数值
            UI.Label {
                text = (entry.relation >= 0 and "+" or "") .. tostring(entry.relation),
                fontSize = Theme.fontB1,
                fontColor = relColor,
                fontWeight = "bold",
                width = 38,
                textAlign = "right",
            },
            -- 状态徽章
            UI.Panel {
                paddingLeft = 8, paddingRight = 8,
                paddingTop = 3, paddingBottom = 3,
                backgroundColor = { statusColor[1], statusColor[2], statusColor[3], 200 },
                borderRadius = 10,
                children = {
                    UI.Label {
                        text = statusLabel,
                        fontSize = Theme.fontTiny,
                        fontColor = Theme.parchment0,
                        fontWeight = "bold",
                    },
                },
            },
        },
    }
end

--- 创建外交面板
function M.Create(state)
    local rows = {}
    for _, entry in ipairs(state.diplomacy) do
        rows[#rows + 1] = DiplomacyRow(entry)
    end

    return UI.ScrollView {
        id = "diplomacyContent",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        padding = 8,
        gap = 6,
        children = rows,
    }
end

return M
