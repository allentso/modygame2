-- ============================================================================
-- TradePanel.lua - 贸易路线面板（羊皮纸风格）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

--- 贸易类型颜色
local function getTypeColor(tradeType)
    if tradeType == "三角贸易" then
        return Theme.statusOk
    elseif tradeType == "直贸易" then
        return Theme.statusInfo
    end
    return Theme.ink2
end

--- 贸易路线行
local function TradeRow(route, index)
    local riskColor = Theme.getRiskColor(route.risk)
    local riskLabel = Theme.getRiskLabel(route.risk)
    local typeColor = getTypeColor(route.type)
    local bgColor = (index % 2 == 0) and Theme.parchment0 or nil

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 4,
        paddingTop = 5, paddingBottom = 5,
        paddingLeft = 6, paddingRight = 6,
        backgroundColor = bgColor,
        borderRadius = 3,
        children = {
            -- 路线名
            UI.Label {
                text = route.name,
                fontSize = Theme.fontB2,
                fontColor = Theme.ink1,
                flexGrow = 1,
                flexShrink = 1,
            },
            -- 类型徽章
            UI.Panel {
                paddingLeft = 6, paddingRight = 6,
                paddingTop = 1, paddingBottom = 1,
                backgroundColor = { typeColor[1], typeColor[2], typeColor[3], 180 },
                borderRadius = 8,
                children = {
                    UI.Label {
                        text = route.type,
                        fontSize = 9,
                        fontColor = Theme.parchment0,
                        fontWeight = "bold",
                    },
                },
            },
            -- 等级
            UI.Label {
                text = "Lv." .. route.grade,
                fontSize = Theme.fontB2,
                fontColor = Theme.goldMid,
                fontWeight = "bold",
                width = 35,
                textAlign = "center",
            },
            -- 收益
            UI.Label {
                text = "+" .. route.income,
                fontSize = Theme.fontB2,
                fontColor = Theme.statusOk,
                fontWeight = "bold",
                width = 50,
                textAlign = "right",
            },
            -- 风险徽章
            UI.Panel {
                paddingLeft = 6, paddingRight = 6,
                paddingTop = 1, paddingBottom = 1,
                backgroundColor = { riskColor[1], riskColor[2], riskColor[3], 50 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { riskColor[1], riskColor[2], riskColor[3], 120 },
                width = 40,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = riskLabel,
                        fontSize = 9,
                        fontColor = riskColor,
                        fontWeight = "bold",
                    },
                },
            },
        },
    }
end

--- 创建贸易面板
function M.Create(state, onAction)
    local rows = {}
    -- 表头
    rows[#rows + 1] = UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 4,
        paddingTop = 4, paddingBottom = 6,
        paddingLeft = 6, paddingRight = 6,
        borderBottomWidth = 1.5,
        borderBottomColor = Theme.parchment3,
        children = {
            UI.Label { text = "路线", fontSize = Theme.fontTiny, fontColor = Theme.ink2, fontWeight = "bold", flexGrow = 1 },
            UI.Label { text = "类型", fontSize = Theme.fontTiny, fontColor = Theme.ink2, width = 60, textAlign = "center" },
            UI.Label { text = "等级", fontSize = Theme.fontTiny, fontColor = Theme.ink2, width = 35, textAlign = "center" },
            UI.Label { text = "年收益", fontSize = Theme.fontTiny, fontColor = Theme.ink2, width = 50, textAlign = "right" },
            UI.Label { text = "风险", fontSize = Theme.fontTiny, fontColor = Theme.ink2, width = 40, textAlign = "center" },
        },
    }
    for i, route in ipairs(state.tradeRoutes) do
        rows[#rows + 1] = TradeRow(route, i)
    end

    return UI.Panel {
        width = "100%", flexGrow = 1, flexBasis = 0,
        flexDirection = "column",
        children = {
            UI.ScrollView {
                flexGrow = 1, flexBasis = 0,
                scrollY = true,
                padding = 6,
                gap = 1,
                children = rows,
            },
            -- 底部操作
            UI.Panel {
                flexDirection = "row",
                justifyContent = "center",
                gap = 10,
                padding = 6,
                borderTopWidth = 1,
                borderTopColor = Theme.parchment3,
                children = {
                    UI.Button(Theme.primaryButton({
                        text = "开辟新路线",
                        onClick = function()
                            if onAction then onAction("new_route") end
                        end,
                    })),
                    UI.Button(Theme.secondaryButton({
                        text = "升级路线",
                        onClick = function()
                            if onAction then onAction("upgrade_route") end
                        end,
                    })),
                },
            },
        },
    }
end

return M
