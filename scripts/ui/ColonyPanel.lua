-- ============================================================================
-- ColonyPanel.lua - 右侧殖民地详情面板（羊皮纸风格）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

--- 风险标签（徽章样式）
local function RiskBadge(label, level)
    local color = Theme.getRiskColor(level)
    local displayLevel = Theme.getRiskLabel(level)
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingTop = 3, paddingBottom = 3,
        children = {
            UI.Label { text = label, fontSize = Theme.fontB2, fontColor = Theme.ink2 },
            UI.Panel {
                paddingLeft = 8, paddingRight = 8,
                paddingTop = 2, paddingBottom = 2,
                backgroundColor = { color[1], color[2], color[3], 60 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { color[1], color[2], color[3], 120 },
                children = {
                    UI.Label {
                        text = displayLevel,
                        fontSize = Theme.fontTiny,
                        fontColor = color,
                        fontWeight = "bold",
                    },
                },
            },
        },
    }
end

--- 资源产出行（交替背景）
local function ResourceRow(res, index)
    local bgColor = (index % 2 == 0) and Theme.parchment0 or nil
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        paddingTop = 4, paddingBottom = 4,
        paddingLeft = 6, paddingRight = 6,
        backgroundColor = bgColor,
        borderRadius = 3,
        children = {
            UI.Label {
                text = res.name,
                fontSize = Theme.fontB2,
                fontColor = Theme.ink1,
                flexGrow = 1,
            },
            UI.Label {
                text = "x" .. res.count,
                fontSize = Theme.fontB2,
                fontColor = Theme.ink2,
                width = 30,
                textAlign = "center",
            },
            UI.Label {
                text = "+" .. res.income,
                fontSize = Theme.fontB2,
                fontColor = Theme.statusOk,
                fontWeight = "bold",
                width = 40,
                textAlign = "right",
            },
        },
    }
end

--- 进度条区块
local function BarSection(label, value, maxVal, fillColor)
    local pct = math.min(value / maxVal, 1.0)
    return UI.Panel {
        gap = 3,
        children = {
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between",
                children = {
                    UI.Label { text = label, fontSize = Theme.fontB2, fontColor = Theme.ink2 },
                    UI.Label {
                        text = value .. "%",
                        fontSize = Theme.fontB2,
                        fontColor = Theme.ink1,
                        fontWeight = "bold",
                    },
                },
            },
            UI.ProgressBar {
                value = pct, height = 6,
                trackColor = Theme.parchment3, fillColor = fillColor,
                borderRadius = 3,
            },
        },
    }
end

--- 分隔标题
local function SectionTitle(text)
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        marginTop = 4,
        children = {
            UI.Panel { width = 3, height = 12, backgroundColor = Theme.goldMid, borderRadius = 1 },
            UI.Label { text = text, fontSize = Theme.fontB2, fontColor = Theme.ink0, fontWeight = "bold" },
        },
    }
end

--- 创建殖民地面板
---@param state table GameState
---@param onAction function(actionName, colonyId)
---@param onClose function? 关闭回调
function M.Create(state, onAction, onClose)
    local colony = state.colonies[state.selectedColony]
    if not colony then
        return UI.Panel { width = "100%", height = "100%" }
    end

    -- 资源列表
    local resChildren = {}
    -- 表头
    resChildren[#resChildren + 1] = UI.Panel {
        flexDirection = "row",
        paddingLeft = 6, paddingRight = 6, paddingBottom = 2,
        borderBottomWidth = 1,
        borderBottomColor = Theme.parchment3,
        children = {
            UI.Label { text = "资源", fontSize = Theme.fontTiny, fontColor = Theme.ink2, flexGrow = 1 },
            UI.Label { text = "数量", fontSize = Theme.fontTiny, fontColor = Theme.ink2, width = 30, textAlign = "center" },
            UI.Label { text = "收益", fontSize = Theme.fontTiny, fontColor = Theme.ink2, width = 40, textAlign = "right" },
        },
    }
    for i, res in ipairs(colony.resources) do
        resChildren[#resChildren + 1] = ResourceRow(res, i)
    end

    return UI.Panel {
        id = "colonyPanel",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = Theme.parchment2,
        children = {
            -- 标题区：名称 + 关闭按钮（深木色标题栏）
            UI.Panel {
                padding = 10,
                backgroundGradient = Theme.headerGradient,
                borderBottomWidth = 1,
                borderBottomColor = Theme.goldDark,
                children = {
                    -- 标题行
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "flex-start",
                        children = {
                            UI.Panel {
                                gap = 2,
                                flexShrink = 1,
                                children = {
                                    UI.Label(Theme.titleStyle({ text = colony.name })),
                                    UI.Label { text = colony.region, fontSize = Theme.fontTiny, fontColor = Theme.parchment3 },
                                },
                            },
                            onClose and UI.Button {
                                text = "\u{00D7}",
                                fontSize = 16,
                                width = 24, height = 24,
                                backgroundColor = {0, 0, 0, 0},
                                hoverBackgroundColor = {139, 24, 24, 120},
                                fontColor = Theme.parchment3,
                                borderRadius = 4,
                                borderWidth = 0,
                                onClick = function() onClose() end,
                            } or nil,
                        },
                    },
                    -- 子标签行
                    UI.Panel {
                        flexDirection = "row",
                        gap = 4,
                        marginTop = 6,
                        children = {
                            UI.Button(Theme.subTabStyle(true, { text = "总览" })),
                            UI.Button(Theme.subTabStyle(false, { text = "人口" })),
                            UI.Button(Theme.subTabStyle(false, { text = "生产" })),
                            UI.Button(Theme.subTabStyle(false, { text = "贸易" })),
                        },
                    },
                },
            },
            -- 可滚动内容（羊皮纸底色）
            UI.ScrollView {
                flexGrow = 1, flexBasis = 0,
                padding = 10,
                gap = 6,
                children = {
                    -- 控制度 & 稳定度
                    BarSection("控制度", colony.control, 100, Theme.statusOk),
                    BarSection("稳定度", colony.stability, 100, Theme.statusInfo),
                    -- 资源产出
                    SectionTitle("资源与产出"),
                    UI.Panel { gap = 2, children = resChildren },
                    -- 产能
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        marginTop = 2,
                        children = {
                            UI.Label { text = "产能", fontSize = Theme.fontB2, fontColor = Theme.ink2 },
                            UI.Label {
                                text = tostring(colony.capacity) .. " (+" .. colony.capacityRate .. "/年)",
                                fontSize = Theme.fontB2, fontColor = Theme.statusOk,
                            },
                        },
                    },
                    -- 风险评估
                    SectionTitle("风险评估"),
                    RiskBadge("抵抗运动", colony.risks.resistance),
                    RiskBadge("疾病风险", colony.risks.disease),
                    RiskBadge("海盗威胁", colony.risks.pirate),
                    -- 当前事件
                    colony.currentEvent and UI.Panel {
                        marginTop = 4,
                        padding = 8,
                        backgroundColor = {139, 24, 24, 30},
                        borderRadius = 4,
                        borderLeftWidth = 3,
                        borderLeftColor = Theme.statusWarn,
                        gap = 2,
                        children = {
                            UI.Label { text = "当前事件", fontSize = Theme.fontTiny, fontColor = Theme.statusWarn, fontWeight = "bold" },
                            UI.Label { text = colony.currentEvent, fontSize = Theme.fontTiny, fontColor = Theme.ink1 },
                        },
                    } or nil,
                    -- 操作按钮
                    UI.Panel {
                        flexDirection = "row",
                        gap = 6,
                        marginTop = 8,
                        flexWrap = "wrap",
                        children = {
                            UI.Button(Theme.primaryButton({
                                text = "升级种植园", flexGrow = 1,
                                onClick = function() if onAction then onAction("upgrade", colony.id) end end,
                            })),
                            UI.Button(Theme.secondaryButton({
                                text = "驻扎舰队", flexGrow = 1,
                                onClick = function() if onAction then onAction("fleet", colony.id) end end,
                            })),
                            UI.Button(Theme.secondaryButton({
                                text = "减税安抚", flexGrow = 1,
                                onClick = function() if onAction then onAction("tax", colony.id) end end,
                            })),
                        },
                    },
                },
            },
        },
    }
end

return M
