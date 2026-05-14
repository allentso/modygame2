-- ============================================================================
-- TechPanel.lua - 科技树面板（羊皮纸风格）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")
local TechData = require("data.TechData")

local M = {}

--- 检查科技是否已研究
local function isResearched(state, techId)
    for _, id in ipairs(state.researchedTechs) do
        if id == techId then return true end
    end
    return false
end

--- 检查科技是否可研究（前置已完成）
local function isAvailable(state, tech)
    if isResearched(state, tech.id) then return false end
    for _, prereq in ipairs(tech.prereqs) do
        if not isResearched(state, prereq) then return false end
    end
    return true
end

--- 科技节点（羊皮纸风格）
local function TechNode(tech, state, onResearch)
    local researched = isResearched(state, tech.id)
    local available = isAvailable(state, tech)
    local isResearching = (state.researchingTech == tech.id)

    local bgColor, textColor, borderC
    if researched then
        bgColor = {210, 230, 200, 255}      -- 浅绿色羊皮纸
        textColor = Theme.statusOk
        borderC = Theme.statusOk
    elseif isResearching then
        bgColor = {200, 210, 230, 255}       -- 浅蓝色羊皮纸
        textColor = Theme.statusInfo
        borderC = Theme.statusInfo
    elseif available then
        bgColor = Theme.parchment0            -- 亮色羊皮纸
        textColor = Theme.ink0
        borderC = Theme.goldMid
    else
        bgColor = Theme.parchment3            -- 暗旧纸色（禁用态）
        textColor = Theme.ink3
        borderC = {170, 145, 110, 120}
    end

    -- 状态指示
    local statusIcon = ""
    if researched then
        statusIcon = "\u{2713}" -- ✓
    elseif isResearching then
        statusIcon = "..."
    end

    local nodeChildren = {
        UI.Label {
            text = tech.name,
            fontSize = Theme.fontTiny,
            fontColor = textColor,
            fontWeight = (researched or available) and "bold" or "normal",
            textAlign = "center",
        },
    }

    -- 状态标记
    if statusIcon ~= "" then
        nodeChildren[#nodeChildren + 1] = UI.Label {
            text = statusIcon,
            fontSize = 10,
            fontColor = researched and Theme.statusOk or Theme.statusInfo,
            fontWeight = "bold",
        }
    end

    -- 花费显示
    if not researched and tech.cost then
        nodeChildren[#nodeChildren + 1] = UI.Label {
            text = tostring(tech.cost),
            fontSize = Theme.fontTiny,
            fontColor = Theme.ink3,
        }
    end

    return UI.Button {
        width = 95,
        height = 48,
        backgroundColor = bgColor,
        borderRadius = 5,
        borderWidth = researched and 1.5 or 1,
        borderColor = borderC,
        hoverBackgroundColor = available and Theme.parchment1 or bgColor,
        justifyContent = "center",
        alignItems = "center",
        gap = 1,
        boxShadow = researched and {
            { x = 0, y = 0, blur = 6, spread = 0, color = {58, 107, 40, 40} },
        } or nil,
        children = nodeChildren,
        onClick = function()
            if available and onResearch then onResearch(tech.id) end
        end,
    }
end

--- 创建科技面板
function M.Create(state, onResearch)
    -- 按分类组织科技节点
    local allNodes = {}
    for _, catName in ipairs(TechData.categories) do
        -- 分类标题
        allNodes[#allNodes + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            marginTop = #allNodes > 0 and 6 or 0,
            paddingBottom = 4,
            borderBottomWidth = 1,
            borderBottomColor = Theme.parchment3,
            children = {
                UI.Panel { width = 3, height = 12, backgroundColor = Theme.goldMid, borderRadius = 1 },
                UI.Label {
                    text = catName,
                    fontSize = Theme.fontB2,
                    fontColor = Theme.ink0,
                    fontWeight = "bold",
                },
            },
        }

        -- 该分类下的科技节点
        local catNodes = {}
        for _, tech in ipairs(TechData.techs) do
            if tech.category == catName then
                catNodes[#catNodes + 1] = TechNode(tech, state, onResearch)
            end
        end

        allNodes[#allNodes + 1] = UI.Panel {
            flexDirection = "row",
            flexWrap = "wrap",
            gap = 6,
            paddingTop = 4,
            children = catNodes,
        }
    end

    return UI.Panel {
        width = "100%", flexGrow = 1, flexBasis = 0,
        children = {
            -- 启蒙点显示
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingLeft = 8, paddingRight = 8,
                paddingTop = 4, paddingBottom = 4,
                borderBottomWidth = 1,
                borderBottomColor = Theme.parchment3,
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Label { text = "启蒙点:", fontSize = Theme.fontB2, fontColor = Theme.ink2 },
                            UI.Label {
                                text = tostring(state.resources.enlightenment.value),
                                fontSize = Theme.fontB1,
                                fontColor = Theme.statusInfo,
                                fontWeight = "bold",
                            },
                        },
                    },
                    state.researchingTech and UI.Label {
                        text = "研究中...",
                        fontSize = Theme.fontTiny,
                        fontColor = Theme.statusInfo,
                    } or nil,
                },
            },
            -- 科技节点网格
            UI.ScrollView {
                flexGrow = 1, flexBasis = 0,
                scrollY = true,
                padding = 8,
                gap = 4,
                children = allNodes,
            },
        },
    }
end

return M
