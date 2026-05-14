-- ============================================================================
-- Theme.lua - 帆与铁：深蓝灰·现代策略主题
-- 设计风格：深色科技蓝 + 金色点缀，参考4X策略游戏UI
-- ============================================================================
local M = {}

-- ══════════════════════════════════════════════════════
-- 色彩系统
-- ══════════════════════════════════════════════════════

-- ── 背景层级（从深到浅）────────────────────────────
M.bgPrimary     = {14, 20, 32, 255}      -- 最深：全局底色 / Sidebar 底
M.bgSecondary   = {20, 28, 44, 255}      -- 面板底色 / Drawer 底
M.bgTertiary    = {28, 38, 58, 255}      -- 卡片 / 浮层
M.bgQuaternary  = {36, 50, 74, 255}      -- Hover 态 / 输入框底
M.bgElevated    = {44, 60, 88, 255}      -- 高亮激活态

-- ── 文字层级 ────────────────────────────────────────
M.textPrimary   = {225, 232, 242, 255}    -- 主标题 / 重要数字
M.textSecondary = {158, 172, 195, 255}    -- 正文 / 描述
M.textMuted     = {95, 110, 140, 255}     -- 提示 / 禁用文字
M.textInverse   = {14, 20, 32, 255}       -- 反色文字（金按钮上）

-- ── 金色系（点缀 + 强调）───────────────────────────
M.goldBright    = {235, 195, 100, 255}    -- 高光金：选中态 / 重要数字
M.goldMid       = {200, 165, 70, 255}     -- 主要金色：按钮 / 边框
M.goldDark      = {150, 120, 50, 255}     -- 暗金：阴影 / 分隔线
M.bronze        = {170, 130, 75, 255}     -- 铜色：次级装饰

-- ── 边框 / 分隔 ────────────────────────────────────
M.borderSubtle  = {40, 55, 82, 255}       -- 微弱边框
M.borderDefault = {55, 72, 105, 255}      -- 默认边框
M.borderBright  = {80, 100, 140, 255}     -- 明显边框
M.borderGold    = {200, 165, 70, 120}     -- 金色半透明边框

-- ── 海洋色 ──────────────────────────────────────────
M.oceanDeep     = {10, 16, 28, 255}
M.oceanMid      = {18, 32, 58, 255}
M.oceanShallow  = {30, 60, 100, 255}
M.oceanCoast    = {55, 95, 140, 255}
M.oceanFoam     = {120, 165, 200, 255}

-- ── 陆地色 ──────────────────────────────────────────
M.landEurope    = {160, 145, 110, 255}
M.landAfrica    = {145, 120, 78, 255}
M.landAmerica   = {100, 145, 85, 255}
M.landColony    = {80, 120, 60, 255}
M.landMountain  = {125, 112, 100, 255}
M.landForest    = {65, 95, 50, 255}

-- ── 状态色 ──────────────────────────────────────────
M.statusWar     = {200, 60, 60, 255}      -- 战争/危险
M.statusWarn    = {220, 165, 50, 255}      -- 警告/注意
M.statusOk      = {60, 175, 90, 255}      -- 正常/完成
M.statusInfo    = {65, 140, 225, 255}      -- 信息/中性

-- ── 家族专属色 ──────────────────────────────────────
M.factionColors = {
    hawkins = {65, 140, 210, 255},     -- 英格兰：海蓝
    van     = {235, 150, 50, 255},     -- 荷兰：橙
    dubois  = {150, 70, 195, 255},     -- 法兰西：紫
    castro  = {60, 185, 105, 255},     -- 葡萄牙：翠绿
    braun   = {140, 140, 150, 255},    -- 普鲁士：铁灰
    colonna = {210, 65, 65, 255},      -- 威尼斯：深红
}

-- ══════════════════════════════════════════════════════
-- 向后兼容别名（子面板直接引用的旧名称）
-- ══════════════════════════════════════════════════════
M.parchment0    = M.bgElevated
M.parchment1    = M.bgTertiary
M.parchment2    = M.bgSecondary
M.parchment3    = M.borderSubtle

M.ink0          = M.textPrimary
M.ink1          = M.textPrimary
M.ink2          = M.textSecondary
M.ink3          = M.textMuted

M.wood0         = M.bgPrimary
M.wood1         = M.bgPrimary
M.wood2         = M.bgSecondary

M.bg            = M.bgSecondary
M.bgPanel       = M.bgSecondary
M.bgPanelLight  = M.bgTertiary
M.bgHeader      = M.bgPrimary
M.bgDark        = M.bgPrimary

M.gold          = M.goldMid
M.goldLight     = M.goldBright
M.goldBorder    = M.borderGold
M.goldBorderDim = {100, 120, 155, 100}

M.textGold      = M.goldBright

M.positive      = M.statusOk
M.negative      = M.statusWar
M.warning       = M.statusWarn
M.info          = M.statusInfo
M.neutral       = {120, 130, 148, 255}

-- ── 国家颜色（兼容旧 key）──────────────────────────
M.nationColors = {
    england  = {200, 65, 65, 255},
    france   = {75, 135, 225, 255},
    spain    = {225, 185, 45, 255},
    portugal = {45, 170, 85, 255},
}

function M.getNationColor(name)
    if M.nationColors[name] then return M.nationColors[name] end
    return M.neutral
end

-- ── 关系状态色（英文 key）──────────────────────────
M.relationColors = {
    ally    = M.statusOk,
    friend  = {80, 160, 90, 255},
    neutral = {180, 165, 80, 255},
    hostile = {210, 110, 60, 255},
    war     = M.statusWar,
}

M.relationLabels = {
    ally    = "盟友",
    friend  = "友好",
    neutral = "中立",
    hostile = "敌对",
    war     = "战争",
}

function M.getRelationColor(status)
    if M.relationColors[status] then return M.relationColors[status] end
    return M.neutral
end

function M.getRelationLabel(status)
    return M.relationLabels[status] or status
end

-- ── 风险等级色（英文 key）──────────────────────────
M.riskColors = {
    low    = M.statusOk,
    medium = M.statusWarn,
    high   = M.statusWar,
}

M.riskLabels = {
    low    = "低",
    medium = "中等",
    high   = "高",
}

function M.getRiskColor(level)
    if M.riskColors[level] then return M.riskColors[level] end
    return M.statusWarn
end

function M.getRiskLabel(level)
    return M.riskLabels[level] or level
end

-- ══════════════════════════════════════════════════════
-- 尺寸常量
-- ══════════════════════════════════════════════════════
M.borderRadius    = 6
M.borderWidth     = 1
M.panelPadding    = 10
M.gap             = 6
M.topBarHeight    = 36         -- 资源条高度（略增）
M.bottomBarHeight = 44
M.panelHeaderH    = 34
M.hexEdge         = 16         -- 六边形边长(px)
M.floatingCardW   = 210        -- S2 态浮动信息卡宽度
M.sidebarExpandedW = 140       -- 侧栏展开宽度
M.sidebarCollapsedW = 48       -- 侧栏收起宽度（仅图标）
M.sidebarWidth    = 48         -- 兼容旧引用

-- ══════════════════════════════════════════════════════
-- 字号（对齐设计文档字号规范）
-- ══════════════════════════════════════════════════════
M.fontD1      = 22     -- 游戏标题
M.fontD2      = 18     -- 章节/胜利标题
M.fontH1      = 15     -- 面板主标题
M.fontH2      = 13     -- 组件小标题
M.fontB1      = 12     -- 正文/描述
M.fontB2      = 11     -- 次级说明
M.fontC1      = 13     -- 数值标签
M.fontC2      = 16     -- 数值数字
M.fontTiny    = 9      -- 地图标注

-- 兼容别名
M.fontTitle   = M.fontH1
M.fontBody    = M.fontB1
M.fontSmall   = M.fontB2
M.fontCaption = 10

-- ══════════════════════════════════════════════════════
-- 属性名映射（对齐 GDD 六维属性）
-- ══════════════════════════════════════════════════════
M.statLabels = {
    leadership  = "领导力",
    commercial  = "商业",
    sailing     = "航海",
    engineering = "工程",
    diplomacy   = "外交",
    exploration = "探险",
}
M.statOrder = { "leadership", "commercial", "sailing", "engineering", "diplomacy", "exploration" }

M.statColors = {
    leadership  = {235, 195, 100, 255},    -- 金色
    commercial  = {220, 165, 50, 255},      -- 铜色
    sailing     = {65, 140, 225, 255},      -- 海蓝
    engineering = {170, 130, 75, 255},      -- 铜棕
    diplomacy   = {60, 175, 90, 255},       -- 绿色
    exploration = {150, 70, 195, 255},      -- 紫色
}

-- ══════════════════════════════════════════════════════
-- 阴影预设
-- ══════════════════════════════════════════════════════
M.shadowPanel = {
    { x = 0, y = 2, blur = 10, spread = 0, color = {0, 0, 0, 80} },
}
M.shadowDeep = {
    { x = 0, y = 4, blur = 20, spread = 0, color = {0, 0, 0, 100} },
    { x = 0, y = 1, blur = 4, spread = 0, color = {0, 0, 0, 50}, inset = true },
}
M.shadowGlow = {
    { x = 0, y = 0, blur = 12, spread = 2, color = {200, 165, 70, 40} },
}

-- ══════════════════════════════════════════════════════
-- 渐变预设
-- ══════════════════════════════════════════════════════

-- 标题栏渐变：深蓝色
M.headerGradient = {
    type = "linear", direction = "to-bottom",
    from = M.bgTertiary, to = M.bgSecondary,
}

-- 面板体渐变：深蓝灰色
M.panelBodyGradient = {
    type = "linear", direction = "to-bottom",
    from = M.bgSecondary, to = M.bgPrimary,
}

-- 遮罩
M.modalBackdrop = {5, 8, 18, 160}

-- 金色按钮渐变
M.goldButtonGradient = {
    type = "linear", direction = "to-bottom",
    from = M.goldMid, to = M.goldDark,
}

-- 侧栏渐变
M.sidebarGradient = {
    type = "linear", direction = "to-bottom",
    from = {18, 24, 40, 255}, to = {12, 16, 28, 255},
}

-- ══════════════════════════════════════════════════════
-- 样式工厂函数
-- ══════════════════════════════════════════════════════

--- 通用面板样式
function M.panelStyle(extra)
    local s = {
        backgroundColor = M.bgSecondary,
        borderRadius = M.borderRadius,
        borderWidth = M.borderWidth,
        borderColor = M.borderSubtle,
        padding = M.panelPadding,
        boxShadow = M.shadowPanel,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 面板标题栏样式
function M.headerStyle(extra)
    local s = {
        height = M.panelHeaderH,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10,
        paddingRight = 6,
        gap = 6,
        backgroundGradient = M.headerGradient,
        borderBottomWidth = 1,
        borderBottomColor = M.borderSubtle,
        borderTopLeftRadius = M.borderRadius,
        borderTopRightRadius = M.borderRadius,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 标题文字样式（浅色背景上用金色文字）
function M.titleStyle(extra)
    local s = {
        fontSize = M.fontH1,
        fontColor = M.goldBright,
        fontWeight = "bold",
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 主按钮样式（金色渐变，深色文字）
function M.primaryButton(extra)
    local s = {
        fontSize = M.fontB2,
        height = 30,
        paddingLeft = 14, paddingRight = 14,
        backgroundGradient = M.goldButtonGradient,
        hoverBackgroundColor = M.goldBright,
        fontColor = M.textInverse,
        fontWeight = "bold",
        borderRadius = 4,
        borderWidth = 1,
        borderColor = M.goldBright,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 次级按钮样式（透明底 + 边框）
function M.secondaryButton(extra)
    local s = {
        fontSize = M.fontB2,
        height = 30,
        paddingLeft = 14, paddingRight = 14,
        backgroundColor = M.bgTertiary,
        hoverBackgroundColor = M.bgQuaternary,
        fontColor = M.textPrimary,
        borderRadius = 4,
        borderWidth = 1,
        borderColor = M.borderDefault,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 危险按钮样式（红色）
function M.dangerButton(extra)
    local s = {
        fontSize = M.fontB2,
        height = 30,
        paddingLeft = 14, paddingRight = 14,
        backgroundColor = M.statusWar,
        hoverBackgroundColor = {220, 70, 70, 255},
        fontColor = {255, 255, 255, 255},
        fontWeight = "bold",
        borderRadius = 4,
        borderWidth = 1,
        borderColor = {230, 90, 90, 255},
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 分隔线（半透明细线）
function M.divider(extra)
    local s = {
        width = "100%", height = 1,
        backgroundColor = M.borderSubtle,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 角标（红色数字）
function M.badge(count)
    return {
        position = "absolute",
        top = -4, right = -4,
        minWidth = 16, height = 16,
        borderRadius = 8,
        backgroundColor = M.statusWar,
        justifyContent = "center",
        alignItems = "center",
        paddingLeft = 3, paddingRight = 3,
        children = {
            { text = tostring(count), fontSize = 9, fontColor = {255, 255, 255, 255}, fontWeight = "bold" },
        }
    }
end

--- 子页签按钮样式
function M.subTabStyle(isActive, extra)
    local s = {
        fontSize = M.fontCaption,
        height = 24,
        paddingLeft = 10, paddingRight = 10,
        backgroundColor = isActive and M.bgQuaternary or {0, 0, 0, 0},
        fontColor = isActive and M.goldBright or M.textMuted,
        fontWeight = isActive and "bold" or "normal",
        borderRadius = 4,
        borderBottomWidth = isActive and 2 or 0,
        borderBottomColor = M.goldMid,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- AP 沙漏文本
function M.apDisplay(current, max)
    return string.format("\u{23F3} %d/%d", current, max)
end

--- 操作卡片样式（面板内操作项）
function M.actionCardStyle(isDisabled, isSelected, extra)
    local s = {
        height = 44,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10, paddingRight = 10,
        backgroundColor = isSelected and M.bgTertiary or M.bgSecondary,
        borderWidth = 1,
        borderColor = isSelected and M.goldMid or M.borderSubtle,
        borderRadius = 4,
        opacity = isDisabled and 0.4 or 1.0,
    }
    if isSelected then
        s.borderLeftWidth = 3
        s.borderLeftColor = M.goldBright
    end
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 进度条样式
function M.progressBarStyle(fillColor, extra)
    local s = {
        height = 8,
        backgroundColor = M.bgQuaternary,
        borderRadius = 4,
        overflow = "hidden",
        fillColor = fillColor or M.goldMid,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 底栏导航按钮样式（纯图标，38px 宽）
function M.navButtonStyle(isActive, extra)
    local s = {
        width = 38, height = M.bottomBarHeight,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = isActive and M.bgTertiary or M.bgPrimary,
        borderTopWidth = isActive and 2 or 0,
        borderTopColor = M.goldBright,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

--- 侧栏导航按钮样式
function M.sidebarNavStyle(isActive, isExpanded, extra)
    local s = {
        height = isExpanded and 42 or 48,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = isExpanded and "flex-start" or "center",
        gap = isExpanded and 10 or 0,
        paddingLeft = isExpanded and 14 or 0,
        backgroundColor = isActive and M.bgTertiary or {0, 0, 0, 0},
        hoverBackgroundColor = M.bgQuaternary,
        borderRadius = 0,
        borderLeftWidth = isActive and 3 or 0,
        borderLeftColor = M.goldBright,
    }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

return M
