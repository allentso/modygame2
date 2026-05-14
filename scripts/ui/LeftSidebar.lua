-- ============================================================================
-- LeftSidebar.lua - 左侧图标导航栏（浮层版）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

-- 导航项定义
local NAV_ITEMS = {
    { id = "overview",  icon = "🏠", label = "概述" },
    { id = "trade",     icon = "🚢", label = "贸易" },
    { id = "fleet",     icon = "⚓", label = "舰队" },
    { id = "family",    icon = "👪", label = "家族" },
    { id = "diplomacy", icon = "🏳", label = "外交" },
    { id = "tech",      icon = "🔬", label = "科技" },
    { id = "report",    icon = "📊", label = "年报" },
    { id = "event",     icon = "🔔", label = "事件" },
}

--- 创建侧边栏按钮
local function NavButton(item, isActive, onClick, badgeCount)
    local bgColor = isActive and {70, 55, 40, 255} or {0, 0, 0, 0}
    local hoverBg = isActive and {70, 55, 40, 255} or {50, 40, 32, 200}
    local borderLeftW = isActive and 3 or 0
    local borderLeftC = Theme.gold

    local btnChildren = {
        UI.Label {
            text = item.icon,
            fontSize = 18,
            textAlign = "center",
        },
        UI.Label {
            text = item.label,
            fontSize = Theme.fontTiny,
            fontColor = isActive and Theme.goldLight or Theme.textMuted,
            textAlign = "center",
        },
    }

    -- 角标
    if badgeCount and badgeCount > 0 then
        btnChildren[#btnChildren + 1] = UI.Panel {
            position = "absolute",
            top = -4, right = -4,
            minWidth = 16, height = 16,
            borderRadius = 8,
            backgroundColor = Theme.negative,
            justifyContent = "center",
            alignItems = "center",
            paddingLeft = 3, paddingRight = 3,
            children = {
                UI.Label { text = tostring(badgeCount), fontSize = 9, fontColor = {255,255,255,255}, fontWeight = "bold" },
            },
        }
    end

    return UI.Button {
        width = Theme.sidebarWidth,
        height = 52,
        backgroundColor = bgColor,
        hoverBackgroundColor = hoverBg,
        borderRadius = 0,
        borderWidth = 0,
        borderLeftWidth = borderLeftW,
        borderLeftColor = borderLeftC,
        justifyContent = "center",
        alignItems = "center",
        gap = 2,
        paddingTop = 3,
        paddingBottom = 3,
        children = btnChildren,
        onClick = function(self)
            if onClick then onClick(item.id) end
        end,
    }
end

--- 创建左侧导航栏
---@param activeId string? 当前激活项（面板名或 "overview"）
---@param onNav function(navId:string) 导航回调
---@param badges table? {navId=count,...} 角标
function M.Create(activeId, onNav, badges)
    badges = badges or {}
    local children = {}
    for _, item in ipairs(NAV_ITEMS) do
        local isActive = (item.id == activeId)
        children[#children + 1] = NavButton(item, isActive, onNav, badges[item.id])
    end

    return UI.Panel {
        id = "leftSidebar",
        width = Theme.sidebarWidth,
        height = "100%",
        flexShrink = 0,
        backgroundColor = Theme.bgDark,
        borderRightWidth = 1,
        borderRightColor = Theme.goldBorderDim,
        alignItems = "center",
        paddingTop = 4,
        gap = 1,
        children = children,
    }
end

return M
