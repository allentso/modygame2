-- ============================================================================
-- TechData.lua - 科技树定义
-- ============================================================================
local M = {}

-- 科技分类
M.categories = { "航海学", "金融学", "工业技术", "政治思想" }

-- 科技节点 { id, name, category, cost, prereqs, effects, desc }
-- effects 键名对齐 GameState 资源键: wealth/enlightenment/production/prestige/maritime/colonial
M.techs = {
    -- 航海学
    { id = "astro_nav",     name = "天文导航",     category = "航海学", cost = 80,  prereqs = {},              effects = {prestige=5},     desc = "提升远洋贸易效率" },
    { id = "ship_design",   name = "船体设计",     category = "航海学", cost = 120, prereqs = {"astro_nav"},    effects = {maritime=10},    desc = "增强舰队战斗力" },
    { id = "global_net",    name = "全球航运网络", category = "航海学", cost = 200, prereqs = {"astro_nav"},    effects = {prestige=15},    desc = "大幅提升贸易收入" },
    { id = "ocean_voyage",  name = "远洋航海",     category = "航海学", cost = 150, prereqs = {"ship_design"},  effects = {prestige=8},     desc = "开辟新贸易路线" },
    { id = "triple_deck",   name = "三层甲板战舰", category = "航海学", cost = 250, prereqs = {"ship_design"},  effects = {maritime=20},    desc = "最强战舰" },
    { id = "steam_nav",     name = "蒸汽动力船",   category = "航海学", cost = 300, prereqs = {"ocean_voyage"}, effects = {prestige=20,maritime=10}, desc = "划时代的动力革命" },
    -- 金融学
    { id = "royal_academy", name = "皇家科学院",   category = "金融学", cost = 100, prereqs = {},              effects = {enlightenment=10}, desc = "科研速度提升" },
    { id = "econ_liberal",  name = "经济自由主义", category = "金融学", cost = 150, prereqs = {"royal_academy"},effects = {wealth=50},        desc = "贸易收入增加" },
    { id = "joint_stock",   name = "股份有限公司", category = "金融学", cost = 200, prereqs = {"econ_liberal"}, effects = {wealth=80},        desc = "可发行股票融资" },
    -- 工业技术
    { id = "steam_engine",  name = "蒸汽机",       category = "工业技术", cost = 180, prereqs = {},              effects = {wealth=30},      desc = "工业产能提升" },
    { id = "machinery",     name = "机械制造",     category = "工业技术", cost = 220, prereqs = {"steam_engine"},effects = {wealth=50},      desc = "工厂产出翻倍" },
    { id = "factory_sys",   name = "工厂制度",     category = "工业技术", cost = 280, prereqs = {"machinery"},   effects = {wealth=80,colonial=5}, desc = "建立现代工厂体系" },
    -- 政治思想
    { id = "enlightenment", name = "启蒙思想",     category = "政治思想", cost = 100, prereqs = {},              effects = {colonial=10},    desc = "提升影响力" },
    { id = "constitution",  name = "宪政改革",     category = "政治思想", cost = 200, prereqs = {"enlightenment"},effects = {colonial=20},   desc = "政治稳定度提升" },
    { id = "abolition",     name = "废奴运动",     category = "政治思想", cost = 250, prereqs = {"enlightenment"},effects = {colonial=30},   desc = "殖民地稳定性提升" },
}

return M
