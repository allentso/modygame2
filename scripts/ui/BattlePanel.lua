-- ============================================================================
-- BattlePanel.lua - 海战面板（羊皮纸风格 + 双色战力条）
-- ============================================================================
local UI = require("urhox-libs/UI")
local Theme = require("ui.Theme")

local M = {}

--- 舰队信息块
local function FleetInfo(label, name, power, icon, color, bgGrad)
    return UI.Panel {
        alignItems = "center",
        gap = 4,
        children = {
            UI.Label { text = label, fontSize = Theme.fontTiny, fontColor = Theme.ink2 },
            UI.Label {
                text = name,
                fontSize = Theme.fontB1,
                fontColor = color,
                fontWeight = "bold",
            },
            UI.Panel {
                width = 46, height = 46,
                borderRadius = 23,
                backgroundGradient = bgGrad,
                borderWidth = 2,
                borderColor = color,
                justifyContent = "center",
                alignItems = "center",
                boxShadow = {
                    { x = 0, y = 2, blur = 8, spread = 0, color = { color[1], color[2], color[3], 60 } },
                },
                children = {
                    UI.Label { text = icon, fontSize = 22 },
                },
            },
            UI.Label {
                text = tostring(power),
                fontSize = Theme.fontH1,
                fontColor = Theme.ink0,
                fontWeight = "bold",
            },
            UI.Label {
                text = "战力",
                fontSize = Theme.fontTiny,
                fontColor = Theme.ink3,
            },
        },
    }
end

--- 创建海战面板
function M.Create(state, onAction)
    local battle = state.currentBattle or {
        title = "加的斯海战",
        date = state.year .. "年6月",
        playerName = state.familyName,
        enemyName = "西班牙海军",
        playerPower = state.fleet.power,
        enemyPower = 1180,
        playerLoss = 12,
        enemyLoss = 28,
        seaControl = "我方占优",
    }

    local totalPower = battle.playerPower + battle.enemyPower
    local playerPercent = totalPower > 0 and (battle.playerPower / totalPower) or 0.5

    return UI.Panel {
        width = "100%", flexGrow = 1, flexBasis = 0,
        flexDirection = "column",
        alignItems = "center",
        justifyContent = "center",
        gap = 10,
        padding = 12,
        children = {
            -- 标题
            UI.Label {
                text = "海战: " .. battle.title,
                fontSize = Theme.fontH1,
                fontColor = Theme.ink0,
                fontWeight = "bold",
            },
            UI.Label { text = battle.date, fontSize = Theme.fontTiny, fontColor = Theme.ink2 },
            -- VS 区域
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = 20,
                children = {
                    -- 我方
                    FleetInfo(
                        "我方舰队", battle.playerName, battle.playerPower,
                        "\u{2693}", Theme.goldMid,
                        { type = "linear", direction = "to-bottom",
                          from = Theme.goldMid, to = Theme.goldDark }
                    ),
                    -- VS
                    UI.Panel {
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "VS",
                                fontSize = 22,
                                fontColor = Theme.statusWar,
                                fontWeight = "bold",
                                textShadow = { offsetX = 0, offsetY = 1, blur = 4, color = {139, 24, 24, 80} },
                            },
                        },
                    },
                    -- 敌方
                    FleetInfo(
                        "敌方舰队", battle.enemyName, battle.enemyPower,
                        "\u{2694}", Theme.statusWar,
                        { type = "linear", direction = "to-bottom",
                          from = {180, 60, 60, 255}, to = {120, 30, 30, 255} }
                    ),
                },
            },
            -- 战力对比条（双色）
            UI.Panel {
                width = "85%", maxWidth = 380,
                gap = 4,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label { text = "制海权", fontSize = Theme.fontB2, fontColor = Theme.ink2 },
                            UI.Label { text = battle.seaControl, fontSize = Theme.fontB2, fontColor = Theme.statusOk, fontWeight = "bold" },
                        },
                    },
                    -- 双色条：蓝色 vs 红色
                    UI.Panel {
                        width = "100%", height = 14,
                        flexDirection = "row",
                        borderRadius = 7,
                        overflow = "hidden",
                        boxShadow = Theme.shadowPanel,
                        children = {
                            UI.Panel {
                                flexGrow = math.max(1, math.floor(playerPercent * 100)),
                                flexBasis = 0,
                                backgroundGradient = {
                                    type = "linear", direction = "to-right",
                                    from = {60, 130, 220, 255}, to = {80, 160, 255, 255},
                                },
                            },
                            UI.Panel {
                                flexGrow = math.max(1, math.floor((1 - playerPercent) * 100)),
                                flexBasis = 0,
                                backgroundGradient = {
                                    type = "linear", direction = "to-right",
                                    from = {220, 80, 80, 255}, to = {180, 50, 50, 255},
                                },
                            },
                        },
                    },
                    -- 损失
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = "己方损失: " .. battle.playerLoss .. "%",
                                fontSize = Theme.fontTiny,
                                fontColor = Theme.ink2,
                            },
                            UI.Label {
                                text = "敌方损失: " .. battle.enemyLoss .. "%",
                                fontSize = Theme.fontTiny,
                                fontColor = Theme.ink2,
                            },
                        },
                    },
                },
            },
            -- 操作按钮
            UI.Panel {
                flexDirection = "row",
                gap = 12,
                marginTop = 4,
                children = {
                    UI.Button(Theme.dangerButton({
                        text = "撤退",
                        onClick = function()
                            if onAction then onAction("retreat") end
                        end,
                    })),
                    UI.Button(Theme.primaryButton({
                        text = "继续追击",
                        onClick = function()
                            if onAction then onAction("pursue") end
                        end,
                    })),
                },
            },
        },
    }
end

return M
