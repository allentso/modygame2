-- ============================================================================
-- EventData.lua - 随机事件定义
-- ============================================================================
local M = {}

-- 随机事件池 { id, title, desc, probability, effects, type }
-- probability: 每回合触发概率(0~100)
-- type: "positive"好事, "negative"坏事, "neutral"中性
-- effects 键名对齐 GameState 资源键: wealth/enlightenment/production/prestige/maritime/colonial
M.events = {
    { id = "trade_boom",     title = "贸易繁荣",       desc = "加勒比地区贸易量增长17%",       probability = 15, effects = {wealth=200},                  type = "positive" },
    { id = "pirate_attack",  title = "海盗袭击",       desc = "海盗袭击了你的商船队",           probability = 12, effects = {wealth=-150,maritime=-5},      type = "negative" },
    { id = "slave_revolt",   title = "奴隶暴动",       desc = "殖民地发生奴隶起义",             probability = 8,  effects = {stability=-15},               type = "negative" },
    { id = "new_land",       title = "发现新大陆",     desc = "探险队发现了新的贸易据点",       probability = 5,  effects = {prestige=10,colonial=5},      type = "positive" },
    { id = "plague",          title = "瘟疫爆发",       desc = "殖民地爆发传染病",               probability = 6,  effects = {stability=-20,wealth=-100},   type = "negative" },
    { id = "alliance",       title = "外交联盟",       desc = "邻国提议建立贸易联盟",           probability = 10, effects = {colonial=10},                 type = "positive" },
    { id = "tech_discover",  title = "科学突破",       desc = "皇家科学院取得重大发现",         probability = 8,  effects = {enlightenment=50},            type = "positive" },
    { id = "storm",           title = "大西洋风暴",     desc = "风暴摧毁了部分贸易船队",         probability = 10, effects = {prestige=-5,wealth=-80},      type = "negative" },
    { id = "gold_mine",      title = "发现金矿",       desc = "殖民地发现了新的金矿",           probability = 4,  effects = {wealth=500},                  type = "positive" },
    { id = "french_war",     title = "法国对我方态度恶化", desc = "法国因贸易争端降低关系",     probability = 7,  effects = {diplomacy_france=-10},        type = "negative" },
    { id = "naval_victory",  title = "海战胜利",       desc = "我方舰队击退了敌方入侵",         probability = 6,  effects = {maritime=10,colonial=8},      type = "positive" },
    { id = "crop_failure",   title = "作物歉收",       desc = "加勒比种植园遭遇干旱",           probability = 8,  effects = {wealth=-120},                 type = "negative" },
}

return M
