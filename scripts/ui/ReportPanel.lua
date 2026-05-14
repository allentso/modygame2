-- ============================================================================
-- ReportPanel.lua - 年度报告面板（羊皮纸风格）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

--- 奖牌颜色
local function getMedalColor(rank)
    if rank == 1 then return {255, 215, 0, 255} end   -- 金
    if rank == 2 then return {192, 192, 192, 255} end  -- 银
    if rank == 3 then return {205, 127, 50, 255} end   -- 铜
    return Theme.ink3
end

--- 创建年度报告面板
function M.Create(state)
    local diamond = "\u{25C6}"  -- ◆

    -- 重大事件列表
    local eventChildren = {}
    for _, evt in ipairs(state.history.events) do
        eventChildren[#eventChildren + 1] = UI.Panel {
            flexDirection = "row",
            gap = 6,
            alignItems = "flex-start",
            paddingTop = 2, paddingBottom = 2,
            children = {
                UI.Label { text = diamond, fontSize = 9, fontColor = Theme.goldMid },
                UI.Label {
                    text = evt,
                    fontSize = Theme.fontB2,
                    fontColor = Theme.ink1,
                    flexShrink = 1,
                },
            },
        }
    end

    -- 世界排名列表
    local rankChildren = {}
    for i, entry in ipairs(state.ranking) do
        local isPlayer = (entry.name == state.familyName)
        local medalColor = getMedalColor(i)
        rankChildren[#rankChildren + 1] = UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            justifyContent = "space-between",
            paddingTop = 4, paddingBottom = 4,
            paddingLeft = 6, paddingRight = 6,
            backgroundColor = isPlayer and Theme.parchment0 or nil,
            borderRadius = 4,
            borderWidth = isPlayer and 1 or 0,
            borderColor = isPlayer and Theme.goldMid or nil,
            children = {
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 6,
                    children = {
                        -- 排名徽章
                        UI.Panel {
                            width = 20, height = 20,
                            borderRadius = 10,
                            backgroundColor = i <= 3 and { medalColor[1], medalColor[2], medalColor[3], 60 } or Theme.parchment3,
                            borderWidth = i <= 3 and 1 or 0,
                            borderColor = medalColor,
                            justifyContent = "center",
                            alignItems = "center",
                            children = {
                                UI.Label {
                                    text = tostring(i),
                                    fontSize = Theme.fontTiny,
                                    fontColor = i <= 3 and medalColor or Theme.ink3,
                                    fontWeight = "bold",
                                },
                            },
                        },
                        UI.Label {
                            text = entry.name,
                            fontSize = Theme.fontB2,
                            fontColor = isPlayer and Theme.ink0 or Theme.ink1,
                            fontWeight = isPlayer and "bold" or "normal",
                        },
                    },
                },
                UI.Label {
                    text = tostring(entry.wealth),
                    fontSize = Theme.fontB2,
                    fontColor = Theme.goldDark,
                    fontWeight = "bold",
                },
            },
        }
    end

    -- 财富趋势简要
    local wh = state.history.wealthHistory
    local trend = ""
    if #wh >= 2 then
        local diff = wh[#wh] - wh[#wh - 1]
        local pct = math.floor(diff / math.max(wh[#wh - 1], 1) * 100)
        local sign = diff >= 0 and "+" or ""
        trend = sign .. tostring(diff) .. " (" .. sign .. pct .. "%)"
    end

    return UI.Panel {
        width = "100%", flexGrow = 1, flexBasis = 0,
        flexDirection = "row",
        gap = 8,
        padding = 8,
        children = {
            -- 左侧：财富 + 事件
            UI.Panel {
                flexGrow = 1, flexBasis = 0,
                flexShrink = 1,
                gap = 6,
                children = {
                    -- 年度标题
                    UI.Label {
                        text = state.year .. " 年度报告",
                        fontSize = Theme.fontH1,
                        fontColor = Theme.ink0,
                        fontWeight = "bold",
                    },
                    -- 财富摘要
                    UI.Panel {
                        padding = 8,
                        backgroundColor = Theme.parchment0,
                        borderRadius = 4,
                        borderLeftWidth = 3,
                        borderLeftColor = Theme.goldMid,
                        gap = 4,
                        children = {
                            UI.Panel {
                                flexDirection = "row", justifyContent = "space-between",
                                children = {
                                    UI.Label { text = "当前财富", fontSize = Theme.fontB2, fontColor = Theme.ink2 },
                                    UI.Label {
                                        text = tostring(state.resources.wealth.value) .. " 杜卡特",
                                        fontSize = Theme.fontB1,
                                        fontColor = Theme.goldDark,
                                        fontWeight = "bold",
                                    },
                                },
                            },
                            #trend > 0 and UI.Panel {
                                flexDirection = "row", justifyContent = "space-between",
                                children = {
                                    UI.Label { text = "年度变化", fontSize = Theme.fontB2, fontColor = Theme.ink2 },
                                    UI.Label {
                                        text = trend,
                                        fontSize = Theme.fontB2,
                                        fontColor = wh[#wh] >= wh[#wh - 1] and Theme.statusOk or Theme.statusWar,
                                        fontWeight = "bold",
                                    },
                                },
                            } or nil,
                        },
                    },
                    -- 事件标题
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Panel { width = 3, height = 12, backgroundColor = Theme.goldMid, borderRadius = 1 },
                            UI.Label { text = "重大事件", fontSize = Theme.fontB2, fontColor = Theme.ink0, fontWeight = "bold" },
                        },
                    },
                    UI.Panel { gap = 2, children = eventChildren },
                },
            },
            -- 分隔线
            UI.Panel { width = 1, backgroundColor = Theme.parchment3 },
            -- 右侧：排名
            UI.Panel {
                width = 170,
                flexShrink = 0,
                gap = 4,
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Panel { width = 3, height = 12, backgroundColor = Theme.goldMid, borderRadius = 1 },
                            UI.Label {
                                text = "世界排名",
                                fontSize = Theme.fontH1,
                                fontColor = Theme.ink0,
                                fontWeight = "bold",
                            },
                        },
                    },
                    UI.Panel { gap = 2, children = rankChildren },
                },
            },
        },
    }
end

return M
