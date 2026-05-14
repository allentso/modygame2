-- ============================================================================
-- FamilyPanel.lua - 家族面板（羊皮纸风格 + 六维属性色条）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

--- 属性色条
local function StatBar(key, value)
    local label = Theme.statLabels[key] or key
    local color = Theme.statColors[key] or Theme.statusInfo
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 3,
        children = {
            UI.Label {
                text = label,
                fontSize = Theme.fontTiny,
                fontColor = Theme.ink3,
                width = 22,
            },
            UI.ProgressBar {
                value = value / 100,
                width = 50, height = 5,
                trackColor = Theme.parchment3,
                fillColor = color,
                borderRadius = 2,
            },
            UI.Label {
                text = tostring(value),
                fontSize = Theme.fontTiny,
                fontColor = Theme.ink2,
                width = 18,
                textAlign = "right",
            },
        },
    }
end

--- 家族成员节点（羊皮纸卡片风格）
local function MemberNode(member, isLeader)
    -- 属性条列表
    local statChildren = {}
    for _, key in ipairs(Theme.statOrder) do
        statChildren[#statChildren + 1] = StatBar(key, member.stats[key] or 0)
    end

    local borderC = isLeader and Theme.goldMid or Theme.parchment3
    local bgC = isLeader and Theme.parchment0 or Theme.parchment1

    return UI.Panel {
        width = 170,
        padding = 8,
        backgroundColor = bgC,
        borderRadius = 6,
        borderWidth = isLeader and 2 or 1,
        borderColor = borderC,
        boxShadow = Theme.shadowPanel,
        gap = 4,
        alignItems = "center",
        children = {
            -- 头像圆（金色渐变 / 木色渐变）
            UI.Panel {
                width = 36, height = 36,
                borderRadius = 18,
                backgroundGradient = isLeader and Theme.goldButtonGradient or {
                    type = "linear", direction = "to-bottom",
                    from = Theme.bronze, to = Theme.wood2,
                },
                borderWidth = 1.5,
                borderColor = isLeader and Theme.goldMid or Theme.parchment3,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = string.sub(member.name, 1, 3),
                        fontSize = 14,
                        fontColor = Theme.parchment0,
                        fontWeight = "bold",
                    },
                },
            },
            -- 名字 + 职务
            UI.Label {
                text = member.name,
                fontSize = Theme.fontB2,
                fontColor = Theme.ink0,
                fontWeight = "bold",
                textAlign = "center",
            },
            UI.Panel {
                flexDirection = "row",
                gap = 6,
                children = {
                    UI.Label {
                        text = member.role,
                        fontSize = Theme.fontTiny,
                        fontColor = Theme.goldDark,
                    },
                    UI.Label {
                        text = member.age .. "岁",
                        fontSize = Theme.fontTiny,
                        fontColor = Theme.ink3,
                    },
                },
            },
            -- 分隔线
            UI.Panel(Theme.divider()),
            -- 属性条
            UI.Panel {
                width = "100%",
                gap = 2,
                children = statChildren,
            },
        },
    }
end

--- 创建家族面板（首领在上方居中，子女分两行排列）
function M.Create(state)
    local family = state.family
    if not family or #family == 0 then
        return UI.Label { text = "无家族成员", fontColor = Theme.ink3 }
    end

    -- 首领（第一个成员）
    local leader = family[1]
    -- 其他成员
    local others = {}
    for i = 2, #family do
        others[#others + 1] = MemberNode(family[i], false)
    end

    return UI.ScrollView {
        id = "familyContent",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        padding = 8,
        gap = 10,
        alignItems = "center",
        children = {
            -- 首领节点（居中）
            MemberNode(leader, true),
            -- 连接线指示
            UI.Panel {
                width = 2, height = 16,
                backgroundColor = Theme.parchment3,
            },
            -- 子女行（flexWrap）
            UI.Panel {
                flexDirection = "row",
                flexWrap = "wrap",
                justifyContent = "center",
                gap = 8,
                children = others,
            },
        },
    }
end

return M
