-- ============================================================================
-- BottomBar.lua - 底部导航栏（两种形态，44px，纯图标导航）
-- 形态 A: 默认导航（6 纯图标按钮 + 结束回合）
-- 形态 B: 地块已选中（关闭 + 地块名 + 快捷操作 + 结束回合）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

-- ── 导航按钮定义 ─────────────────────────────────
M.NAV_ITEMS = {
    { id = "build",     icon = "\u{1F3D7}", label = "建设" },
    { id = "trade",     icon = "\u{1F4E6}", label = "贸易" },
    { id = "diplomacy", icon = "\u{1F91D}", label = "外交" },
    { id = "navy",      icon = "\u{2693}",  label = "海军" },
    { id = "family",    icon = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}", label = "家族" },
    { id = "tech",      icon = "\u{1F52C}", label = "科技" },
}

-- ── 纯图标导航按钮（38px 宽）─────────────────────
local function NavButton(item, isActive, onNav)
    return UI.Button(Theme.navButtonStyle(isActive, {
        text = item.icon,
        fontSize = 18,
        fontColor = isActive and Theme.goldBright or Theme.parchment2,
        onClick = function(self)
            if onNav then onNav(item.id) end
        end,
    }))
end

-- ── 结束回合按钮（紧凑版）───────────────────────
local function EndTurnButton(onEndTurn)
    return UI.Button {
        height = 30,
        paddingLeft = 10, paddingRight = 10,
        backgroundGradient = {
            type = "linear", direction = "to-right",
            from = Theme.goldDark, to = Theme.goldMid,
        },
        borderWidth = 1.5,
        borderColor = Theme.goldBright,
        borderRadius = 4,
        text = "结束回合→",
        fontSize = Theme.fontB2,
        fontColor = Theme.ink0,
        fontWeight = "bold",
        onClick = function(self)
            if onEndTurn then onEndTurn() end
        end,
    }
end

-- ── 底栏容器基础样式 ─────────────────────────────
local function BarContainer(children)
    return UI.Panel {
        id = "bottomBar",
        width = "100%",
        height = Theme.bottomBarHeight,
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = Theme.wood1,
        borderTopWidth = 1.5,
        borderTopColor = Theme.goldDark,
        boxShadow = {
            { x = 0, y = -2, blur = 6, spread = 0, color = {40, 25, 10, 100} },
        },
        children = children,
    }
end

--- 形态 A: 默认导航（S1）
---@param activeNav string|nil 当前选中的导航 id
---@param callbacks table { onNav, onEndTurn }
function M.FormA(activeNav, callbacks)
    callbacks = callbacks or {}
    local navBtns = {}
    for _, item in ipairs(M.NAV_ITEMS) do
        navBtns[#navBtns + 1] = NavButton(item, activeNav == item.id, callbacks.onNav)
    end

    return BarContainer({
        -- 导航按钮组
        UI.Panel {
            flexGrow = 1,
            flexShrink = 1,
            flexBasis = 0,
            flexDirection = "row",
            alignItems = "center",
            justifyContent = "space-evenly",
            children = navBtns,
        },
        -- 分隔线
        UI.Panel { width = 1, height = 28, backgroundColor = Theme.parchment3 },
        -- 结束回合
        UI.Panel {
            paddingLeft = 6, paddingRight = 6,
            children = {
                EndTurnButton(callbacks.onEndTurn),
            },
        },
    })
end

--- 形态 B: 地块已选中（S2）
---@param tileName string 地块名称
---@param actions table 快捷操作列表 { {icon, label, onAction}, ... }
---@param callbacks table { onClose, onEndTurn }
function M.FormB(tileName, actions, callbacks)
    callbacks = callbacks or {}
    actions = actions or {}

    -- 快捷操作按钮
    local actionBtns = {}
    for _, act in ipairs(actions) do
        actionBtns[#actionBtns + 1] = UI.Button {
            height = 28,
            paddingLeft = 6, paddingRight = 6,
            backgroundColor = Theme.wood2,
            hoverBackgroundColor = Theme.wood1,
            borderRadius = 3,
            text = (act.icon or "") .. " " .. act.label,
            fontSize = Theme.fontTiny,
            fontColor = Theme.parchment1,
            onClick = function(self)
                if act.onAction then act.onAction() end
            end,
        }
    end

    return BarContainer({
        -- 关闭按钮
        UI.Button {
            width = 36, height = Theme.bottomBarHeight,
            backgroundColor = {0, 0, 0, 0},
            hoverBackgroundColor = Theme.wood2,
            text = "✕",
            fontSize = 14,
            fontColor = Theme.parchment2,
            onClick = function(self)
                if callbacks.onClose then callbacks.onClose() end
            end,
        },
        -- 地块名称
        UI.Label {
            text = tileName,
            fontSize = Theme.fontB2,
            fontColor = Theme.parchment1,
            fontWeight = "bold",
            paddingLeft = 2, paddingRight = 6,
            maxWidth = 80,
        },
        -- 分隔线
        UI.Panel { width = 1, height = 24, backgroundColor = Theme.parchment3 },
        -- 快捷操作
        UI.Panel {
            flexGrow = 1,
            flexShrink = 1,
            flexBasis = 0,
            flexDirection = "row",
            alignItems = "center",
            gap = 4,
            paddingLeft = 4,
            children = actionBtns,
        },
        -- 分隔线
        UI.Panel { width = 1, height = 28, backgroundColor = Theme.parchment3 },
        -- 结束回合
        UI.Panel {
            paddingLeft = 6, paddingRight = 6,
            children = {
                EndTurnButton(callbacks.onEndTurn),
            },
        },
    })
end

return M
