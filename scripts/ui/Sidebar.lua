-- ============================================================================
-- Sidebar.lua - 可收起/展开左侧导航栏
-- 展开: 140px (图标+文字)  |  收起: 48px (仅图标)
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

-- 导航项定义
local NAV_ITEMS = {
    { id = "overview",  icon = "🏠", label = "总览" },
    { id = "trade",     icon = "🚢", label = "贸易" },
    { id = "fleet",     icon = "⚓", label = "舰队" },
    { id = "family",    icon = "👪", label = "家族" },
    { id = "diplomacy", icon = "🏳", label = "外交" },
    { id = "tech",      icon = "🔬", label = "科技" },
    { id = "build",     icon = "🏗", label = "建设" },
}

--- 创建侧边栏导航按钮
local function NavButton(item, isActive, isExpanded, onClick, badgeCount)
    local btnChildren = {
        UI.Label {
            text = item.icon,
            fontSize = isExpanded and 16 or 18,
            textAlign = "center",
            width = isExpanded and 20 or nil,
        },
    }

    if isExpanded then
        btnChildren[#btnChildren + 1] = UI.Label {
            text = item.label,
            fontSize = Theme.fontB1,
            fontColor = isActive and Theme.goldBright or Theme.textSecondary,
            flexGrow = 1,
        }
    end

    -- 角标
    if badgeCount and badgeCount > 0 then
        btnChildren[#btnChildren + 1] = UI.Panel {
            position = "absolute",
            top = isExpanded and 10 or 4,
            right = isExpanded and 10 or 4,
            minWidth = 16, height = 16,
            borderRadius = 8,
            backgroundColor = Theme.statusWar,
            justifyContent = "center",
            alignItems = "center",
            paddingLeft = 3, paddingRight = 3,
            children = {
                UI.Label { text = tostring(badgeCount), fontSize = 8, fontColor = {255, 255, 255, 255}, fontWeight = "bold" },
            },
        }
    end

    return UI.Button(Theme.sidebarNavStyle(isActive, isExpanded, {
        children = btnChildren,
        onClick = function(self)
            if onClick then onClick(item.id) end
        end,
    }))
end

--- 创建收起/展开切换按钮
local function ToggleButton(isExpanded, onToggle)
    return UI.Button {
        width = "100%",
        height = 36,
        backgroundColor = {0, 0, 0, 0},
        hoverBackgroundColor = Theme.bgQuaternary,
        borderRadius = 0,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = isExpanded and 6 or 0,
        children = {
            UI.Label {
                text = isExpanded and "◀" or "▶",
                fontSize = 10,
                fontColor = Theme.textMuted,
            },
            isExpanded and UI.Label {
                text = "收起",
                fontSize = Theme.fontTiny,
                fontColor = Theme.textMuted,
            } or nil,
        },
        onClick = function(self)
            if onToggle then onToggle() end
        end,
    }
end

--- 创建左侧导航栏
---@param activeId string|nil 当前激活的导航项 id
---@param isExpanded boolean 是否展开
---@param callbacks table { onNav, onToggle, onEndTurn }
---@param badges table|nil {navId=count,...}
function M.Create(activeId, isExpanded, callbacks, badges)
    callbacks = callbacks or {}
    badges = badges or {}
    local w = isExpanded and Theme.sidebarExpandedW or Theme.sidebarCollapsedW

    -- 导航按钮列表
    local navChildren = {}
    for _, item in ipairs(NAV_ITEMS) do
        local isActive = (item.id == activeId)
        navChildren[#navChildren + 1] = NavButton(item, isActive, isExpanded, callbacks.onNav, badges[item.id])
    end

    -- 家族徽章（侧栏顶部标识）
    local crestSection = UI.Panel {
        width = "100%",
        height = isExpanded and 52 or 48,
        justifyContent = "center",
        alignItems = "center",
        borderBottomWidth = 1,
        borderBottomColor = Theme.borderSubtle,
        children = {
            isExpanded and UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                paddingLeft = 12,
                width = "100%",
                children = {
                    UI.Panel {
                        width = 28, height = 28,
                        borderRadius = 6,
                        backgroundGradient = {
                            type = "linear", direction = "to-bottom",
                            from = Theme.goldMid, to = Theme.goldDark,
                        },
                        borderWidth = 1,
                        borderColor = Theme.goldBright,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "⚜", fontSize = 14 },
                        },
                    },
                    UI.Label {
                        text = "帆与铁",
                        fontSize = Theme.fontH2,
                        fontColor = Theme.goldBright,
                        fontWeight = "bold",
                    },
                },
            } or UI.Panel {
                width = 30, height = 30,
                borderRadius = 6,
                backgroundGradient = {
                    type = "linear", direction = "to-bottom",
                    from = Theme.goldMid, to = Theme.goldDark,
                },
                borderWidth = 1,
                borderColor = Theme.goldBright,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label { text = "⚜", fontSize = 14 },
                },
            },
        },
    }

    -- 结束回合按钮（底部）
    local endTurnBtn
    if isExpanded then
        endTurnBtn = UI.Button {
            width = w - 16,
            height = 32,
            marginLeft = 8,
            marginRight = 8,
            marginBottom = 6,
            backgroundGradient = Theme.goldButtonGradient,
            borderWidth = 1,
            borderColor = Theme.goldBright,
            borderRadius = 4,
            text = "结束回合 →",
            fontSize = Theme.fontB2,
            fontColor = Theme.textInverse,
            fontWeight = "bold",
            onClick = function(self)
                if callbacks.onEndTurn then callbacks.onEndTurn() end
            end,
        }
    else
        endTurnBtn = UI.Button {
            width = 36, height = 36,
            marginLeft = 6, marginRight = 6,
            marginBottom = 6,
            backgroundGradient = Theme.goldButtonGradient,
            borderWidth = 1,
            borderColor = Theme.goldBright,
            borderRadius = 4,
            justifyContent = "center",
            alignItems = "center",
            text = "→",
            fontSize = 14,
            fontColor = Theme.textInverse,
            fontWeight = "bold",
            onClick = function(self)
                if callbacks.onEndTurn then callbacks.onEndTurn() end
            end,
        }
    end

    return UI.Panel {
        id = "sidebar",
        width = w,
        height = "100%",
        flexShrink = 0,
        backgroundGradient = Theme.sidebarGradient,
        borderRightWidth = 1,
        borderRightColor = Theme.borderSubtle,
        flexDirection = "column",
        children = {
            -- 顶部标识
            crestSection,
            -- 导航按钮（占满中间）
            UI.Panel {
                flexGrow = 1,
                flexDirection = "column",
                paddingTop = 4,
                gap = 1,
                children = navChildren,
            },
            -- 分隔线
            UI.Panel(Theme.divider({ marginLeft = 8, marginRight = 8, marginBottom = 4 })),
            -- 结束回合按钮
            endTurnBtn,
            -- 收起/展开切换
            ToggleButton(isExpanded, callbacks.onToggle),
        },
    }
end

return M
