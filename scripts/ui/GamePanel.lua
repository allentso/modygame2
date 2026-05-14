-- ============================================================================
-- GamePanel.lua - 全屏面板容器（S3/S4 态）
-- 替代原 Bottom Sheet，占满整个屏幕
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

--- 创建全屏面板
---@param opts table
---  - title    string   面板标题
---  - icon     string?  标题图标 emoji
---  - tabs     table?   子页签 { {id, label}, ... }
---  - activeTab string? 当前激活页签
---  - onTabChange function?  页签切换回调(tabId)
---  - onClose  function?  关闭/返回回调
---  - children table    内容子元素
function M.Create(opts)
    opts = opts or {}
    local title = opts.title or "面板"
    local icon = opts.icon
    local tabs = opts.tabs
    local activeTab = opts.activeTab
    local onTabChange = opts.onTabChange
    local onClose = opts.onClose
    local children = opts.children or {}

    -- ── 标题栏（深木色）────────────────────
    local headerChildren = {}
    -- 返回按钮
    if onClose then
        headerChildren[#headerChildren + 1] = UI.Button {
            text = "← 返回",
            fontSize = Theme.fontB2,
            height = 28,
            paddingLeft = 8, paddingRight = 8,
            backgroundColor = {0, 0, 0, 0},
            hoverBackgroundColor = Theme.bgQuaternary,
            fontColor = Theme.textSecondary,
            borderRadius = 4,
            borderWidth = 0,
            onClick = function(self)
                if onClose then onClose() end
            end,
        }
    end
    -- 图标
    if icon then
        headerChildren[#headerChildren + 1] = UI.Label {
            text = icon,
            fontSize = Theme.fontB1,
            marginLeft = 4,
        }
    end
    -- 标题文字
    headerChildren[#headerChildren + 1] = UI.Label(Theme.titleStyle({
        text = title,
        flexGrow = 1,
        marginLeft = 4,
    }))

    local header = UI.Panel(Theme.headerStyle({
        height = Theme.panelHeaderH,
        borderRadius = 0,
        borderTopLeftRadius = 0,
        borderTopRightRadius = 0,
        children = headerChildren,
    }))

    -- ── 子页签栏 ─────────────────────────────
    ---@type table?
    local tabBar = nil
    if tabs and #tabs > 0 then
        local tabChildren = {}
        for _, tab in ipairs(tabs) do
            local isActive = (tab.id == activeTab)
            tabChildren[#tabChildren + 1] = UI.Button(Theme.subTabStyle(isActive, {
                text = tab.label,
                onClick = function(self)
                    if onTabChange then onTabChange(tab.id) end
                end,
            }))
        end
        tabBar = UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = 2,
            paddingLeft = 8,
            paddingRight = 8,
            paddingTop = 4,
            paddingBottom = 4,
            backgroundColor = Theme.bgTertiary,
            children = tabChildren,
        }
    end

    -- ── 内容区域（可滚动）─────────────────
    local body = UI.ScrollView {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        padding = Theme.panelPadding,
        children = children,
    }

    -- ── 组装全屏面板 ────────────────────────
    local panelChildren = { header }
    if tabBar then panelChildren[#panelChildren + 1] = tabBar end
    panelChildren[#panelChildren + 1] = body

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = Theme.parchment2,
        overflow = "hidden",
        children = panelChildren,
    }
end

return M
