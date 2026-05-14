-- ============================================================================
-- 帆与铁：商业帝国 - 回合制策略游戏
-- 布局: Sidebar(左) | ResourceBar(顶) + WorldMap(中央)
-- 二级面板: 右侧 Drawer 弹出
-- 状态: S1(地图空闲) S2(地块选中+浮动卡) S3(右侧面板)
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("GameState")
local GameEngine = require("GameEngine")
local Theme = require("ui.Theme")
local Sidebar = require("ui.Sidebar")
local ResourceBar = require("ui.ResourceBar")
local WorldMap = require("ui.WorldMap")
local GamePanel = require("ui.GamePanel")
local ColonyPanel = require("ui.ColonyPanel")
local FamilyPanel = require("ui.FamilyPanel")
local TechPanel = require("ui.TechPanel")
local DiplomacyPanel = require("ui.DiplomacyPanel")
local ReportPanel = require("ui.ReportPanel")
local TradePanel = require("ui.TradePanel")
local BattlePanel = require("ui.BattlePanel")

-- ============================================================================
-- 全局状态
-- ============================================================================
---@type table
local uiRoot_ = nil
---@type table
local state_ = nil
---@type table
local drawer_ = nil

--- 屏幕状态: "S1" | "S2" | "S3"
local screenState_ = "S1"
--- 当前打开的模块（S3态）
local activeModule_ = nil
--- 侧栏当前选中的导航 id
local activeNav_ = nil
--- 侧栏是否展开
local sidebarExpanded_ = false

local CONFIG = {
    Title = "帆与铁：商业帝国",
}

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = CONFIG.Title

    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    state_ = GameState.New()
    CreateUI()

    SubscribeToEvent("KeyDown", "HandleKeyDown")

    print("=== " .. CONFIG.Title .. " 已启动 ===")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 状态转换
-- ============================================================================

local function GoS1()
    screenState_ = "S1"
    activeModule_ = nil
    activeNav_ = nil
    state_.selectedColony = nil
    if drawer_ then drawer_:Close() end
    RefreshUI()
end

local function GoS2(colonyIdx)
    screenState_ = "S2"
    activeModule_ = nil
    state_.selectedColony = colonyIdx
    if drawer_ then drawer_:Close() end
    RefreshUI()
end

local function GoS3(moduleId)
    screenState_ = "S3"
    activeModule_ = moduleId
    activeNav_ = moduleId
    RefreshUI()
end

local function GoBack()
    if screenState_ == "S3" then
        activeModule_ = nil
        activeNav_ = nil
        if drawer_ then drawer_:Close() end
        if state_.selectedColony then
            screenState_ = "S2"
        else
            screenState_ = "S1"
        end
    elseif screenState_ == "S2" then
        state_.selectedColony = nil
        screenState_ = "S1"
    end
    RefreshUI()
end

-- ============================================================================
-- 游戏逻辑回调
-- ============================================================================

function OnEndTurn()
    print("[Game] 结束回合 - 年份 " .. state_.year)
    local report = GameEngine.EndTurn(state_)

    if #report.events > 0 then
        for _, evt in ipairs(report.events) do
            print("[Event] " .. evt)
        end
        UI.Toast({ message = report.events[1], duration = 3000 })
    end

    -- 年度报告用 Drawer 弹出
    GoS3("report")
end

function OnPortClick(portId)
    print("[Map] 港口点击: " .. portId)
    for i, colony in ipairs(state_.colonies) do
        if colony.portId == portId then
            GoS2(i)
            return
        end
    end
    UI.Toast({ message = "该港口尚未建立殖民地", duration = 2000 })
end

function OnColonyAction(action, colonyId)
    print("[Colony] 操作: " .. action .. " 殖民地: " .. colonyId)
    local ok, msg = GameEngine.ColonyAction(state_, action, colonyId)
    UI.Toast({ message = msg, duration = 2000 })
    if ok then
        state_.ap = math.max(0, state_.ap - 1)
        RefreshUI()
    end
end

function OnResearchTech(techId)
    print("[Tech] 开始研究: " .. techId)
    local ok, msg = GameEngine.StartResearch(state_, techId)
    if ok then
        state_.ap = math.max(0, state_.ap - 1)
        UI.Toast({ message = "开始研究科技", duration = 2000 })
        RefreshUI()
    else
        UI.Toast({ message = msg or "无法研究", duration = 2000 })
    end
end

function OnTradeAction(action)
    print("[Trade] 操作: " .. action)
    if action == "new_route" then
        if state_.resources.wealth.value >= 500 then
            state_.resources.wealth.value = state_.resources.wealth.value - 500
            state_.tradeRoutes[#state_.tradeRoutes + 1] = {
                name = "新航线 #" .. (#state_.tradeRoutes + 1),
                type = "直贸易", grade = 1,
                income = math.random(60, 120), risk = "medium",
            }
            state_.ap = math.max(0, state_.ap - 1)
            UI.Toast({ message = "已开辟新贸易路线", duration = 2000 })
            RefreshUI()
        else
            UI.Toast({ message = "财富不足（需要500）", duration = 2000 })
        end
    elseif action == "upgrade_route" then
        if #state_.tradeRoutes > 0 and state_.resources.wealth.value >= 300 then
            state_.resources.wealth.value = state_.resources.wealth.value - 300
            local route = state_.tradeRoutes[1]
            route.grade = route.grade + 1
            route.income = route.income + math.random(50, 100)
            state_.ap = math.max(0, state_.ap - 1)
            UI.Toast({ message = "路线已升级", duration = 2000 })
            RefreshUI()
        else
            UI.Toast({ message = "财富不足（需要300）", duration = 2000 })
        end
    end
end

function OnBattleAction(action)
    print("[Battle] 操作: " .. action)
    if action == "pursue" then
        UI.Toast({ message = "舰队继续追击敌军！", duration = 2000 })
    else
        UI.Toast({ message = "舰队已撤退", duration = 2000 })
    end
end

-- ============================================================================
-- UI 构建
-- ============================================================================

function CreateUI()
    -- 右侧 Drawer（用于 S3 二级面板）
    local drawerContent, drawerOpts = nil, {}
    if screenState_ == "S3" and activeModule_ then
        drawerContent, drawerOpts = GetModuleContent(activeModule_)
    end

    -- 地图区域子元素
    local mapChildren = {
        WorldMap.Create(state_, OnPortClick),
    }

    -- S2 态：浮动信息卡片
    if screenState_ == "S2" and state_.selectedColony then
        local colony = state_.colonies[state_.selectedColony]
        if colony then
            mapChildren[#mapChildren + 1] = CreateFloatingCard(colony)
        end
    end

    -- 主布局：水平 Sidebar | 垂直(ResourceBar + Map)
    local mainContent = UI.Panel {
        id = "gameRoot",
        width = "100%",
        height = "100%",
        flexDirection = "row",
        backgroundColor = Theme.bgPrimary,
        children = {
            -- 左侧导航栏
            Sidebar.Create(activeNav_, sidebarExpanded_, {
                onNav = function(navId)
                    if navId == "overview" then
                        GoS1()
                    else
                        GoS3(navId)
                    end
                end,
                onToggle = function()
                    sidebarExpanded_ = not sidebarExpanded_
                    RefreshUI()
                end,
                onEndTurn = OnEndTurn,
            }),
            -- 右侧主区域
            UI.Panel {
                id = "mainColumn",
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                flexDirection = "column",
                overflow = "hidden",
                children = {
                    -- 顶部资源条
                    ResourceBar.Create(state_),
                    -- 地图区域
                    UI.Panel {
                        id = "mapArea",
                        flexGrow = 1,
                        flexShrink = 1,
                        flexBasis = 0,
                        overflow = "hidden",
                        children = mapChildren,
                    },
                },
            },
        },
    }

    -- 创建右侧 Drawer
    local panelTitle = drawerOpts.title or ""
    local panelIcon = drawerOpts.icon or ""
    drawer_ = UI.Drawer.Right {
        size = 360,
        isOpen = (screenState_ == "S3" and drawerContent ~= nil),
        backgroundColor = Theme.bgSecondary,
        showCloseButton = true,
        header = (panelIcon ~= "" and (panelIcon .. " ") or "") .. panelTitle,
        headerHeight = 44,
        headerPadding = {10, 14},
        content = drawerContent or UI.Panel { width = "100%", height = "100%" },
        onClose = function()
            GoBack()
        end,
    }

    uiRoot_ = UI.Panel {
        width = "100%",
        height = "100%",
        children = {
            mainContent,
            drawer_,
        },
    }

    UI.SetRoot(uiRoot_)
end

--- S2 态浮动信息卡片
function CreateFloatingCard(colony)
    return UI.Panel {
        position = "absolute",
        top = 8, right = 8,
        width = Theme.floatingCardW,
        backgroundColor = Theme.bgSecondary,
        borderRadius = Theme.borderRadius,
        borderWidth = 1,
        borderColor = Theme.borderDefault,
        boxShadow = Theme.shadowDeep,
        overflow = "hidden",
        children = {
            -- 标题栏
            UI.Panel(Theme.headerStyle({
                height = 30,
                children = {
                    UI.Label(Theme.titleStyle({
                        text = colony.name,
                        fontSize = Theme.fontH2,
                        flexGrow = 1,
                    })),
                    UI.Button {
                        width = 22, height = 22,
                        backgroundColor = {0, 0, 0, 0},
                        hoverBackgroundColor = Theme.bgQuaternary,
                        borderRadius = 3,
                        text = "✕",
                        fontSize = 12,
                        fontColor = Theme.textMuted,
                        onClick = function() GoBack() end,
                    },
                },
            })),
            -- 信息区
            UI.Panel {
                padding = 8,
                gap = 5,
                children = {
                    -- 等级
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label { text = "等级", fontSize = Theme.fontB2, fontColor = Theme.textMuted },
                            UI.Label {
                                text = "Lv." .. (colony.level or 1),
                                fontSize = Theme.fontB2, fontColor = Theme.textPrimary, fontWeight = "bold",
                            },
                        },
                    },
                    -- 收入
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label { text = "年收入", fontSize = Theme.fontB2, fontColor = Theme.textMuted },
                            UI.Label {
                                text = "+" .. (colony.income or 0),
                                fontSize = Theme.fontB2, fontColor = Theme.statusOk, fontWeight = "bold",
                            },
                        },
                    },
                    -- 防御
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label { text = "防御", fontSize = Theme.fontB2, fontColor = Theme.textMuted },
                            UI.Label {
                                text = tostring(colony.defense or 0),
                                fontSize = Theme.fontB2, fontColor = Theme.textSecondary,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel(Theme.divider({ marginTop = 2, marginBottom = 2 })),
                    -- 操作按钮
                    UI.Panel {
                        flexDirection = "row",
                        gap = 4,
                        children = {
                            UI.Button(Theme.primaryButton({
                                text = "管理",
                                fontSize = Theme.fontTiny,
                                height = 26,
                                paddingLeft = 8, paddingRight = 8,
                                flexGrow = 1,
                                onClick = function() GoS3("build") end,
                            })),
                            UI.Button(Theme.secondaryButton({
                                text = "探索",
                                fontSize = Theme.fontTiny,
                                height = 26,
                                paddingLeft = 8, paddingRight = 8,
                                flexGrow = 1,
                                onClick = function()
                                    UI.Toast({ message = "探索功能开发中", duration = 1500 })
                                end,
                            })),
                        },
                    },
                },
            },
        },
    }
end

--- 获取模块内容和配置（Drawer 内容）
function GetModuleContent(moduleId)
    if moduleId == "family" then
        return FamilyPanel.Create(state_), {
            title = "家族管理", icon = "👪",
        }
    elseif moduleId == "tech" then
        return TechPanel.Create(state_, OnResearchTech), {
            title = "启蒙科技树", icon = "🔬",
        }
    elseif moduleId == "diplomacy" then
        return DiplomacyPanel.Create(state_), {
            title = "外交厅", icon = "🏳",
        }
    elseif moduleId == "trade" then
        return TradePanel.Create(state_, OnTradeAction), {
            title = "贸易管理", icon = "🚢",
        }
    elseif moduleId == "fleet" or moduleId == "navy" then
        return BattlePanel.Create(state_, OnBattleAction), {
            title = "海军指挥", icon = "⚓",
        }
    elseif moduleId == "build" then
        if state_.selectedColony then
            return ColonyPanel.Create(state_, OnColonyAction, function() GoBack() end), {
                title = "殖民地管理", icon = "🏗",
            }
        end
        return nil, {}
    elseif moduleId == "report" then
        return ReportPanel.Create(state_), {
            title = "年度报告: " .. state_.year .. "年", icon = "📜",
        }
    end
    return nil, {}
end

-- ============================================================================
-- UI 刷新
-- ============================================================================

function RefreshUI()
    CreateUI()
    print("[UI] 界面已刷新 - 年份: " .. state_.year .. " 状态: " .. screenState_)
end

-- ============================================================================
-- 事件处理
-- ============================================================================

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if key == KEY_ESCAPE then
        GoBack()
    end
end
