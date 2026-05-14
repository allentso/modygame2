-- ============================================================================
-- GameState.lua - 游戏核心数据模型
-- ============================================================================
local M = {}

function M.New()
    return {
        -- 基本信息
        year = 1721,
        chapter = "第三章：启蒙浪潮",
        familyName = "霍金斯家族",
        turn = 1,
        ap = 8,       -- 行动点
        maxAp = 8,

        -- 六项资源 { value, rate(每年) } —— 对齐 GDD
        resources = {
            wealth       = { value = 12450, rate = 320, icon = "\u{1F4B0}", label = "财富" },
            enlightenment = { value = 320,  rate = 18,  icon = "\u{1F52C}", label = "启蒙" },
            production   = { value = 180,   rate = 24,  icon = "\u{2699}",  label = "产能" },
            prestige     = { value = 76,    rate = -2,  icon = "\u{1F451}", label = "声望" },
            maritime     = { value = 42,    rate = 8,   icon = "\u{2693}",  label = "航权" },
            colonial     = { value = 58,    rate = 4,   icon = "\u{1F30D}", label = "殖民度" },
        },
        -- 资源顺序（用于 UI 展示）
        resourceOrder = { "wealth", "enlightenment", "production", "prestige", "maritime", "colonial" },

        -- 殖民地
        colonies = {
            {
                id = "havana", name = "哈瓦那殖民地", region = "加勒比地区", portId = "havana",
                control = 72, stability = 60,
                resources = {
                    { name = "蔗糖", count = 2, income = 84 },
                    { name = "烟草", count = 1, income = 26 },
                    { name = "棉花", count = 1, income = 18 },
                },
                capacity = 4, capacityRate = 4,
                colonialDeg = 3, colonialDegRate = 3,
                risks = {
                    resistance = "medium",
                    disease = "low",
                    pirate = "medium",
                },
                currentEvent = "奴隶暴动（2年后爆发）",
            },
            {
                id = "jamaica", name = "牙买加殖民地", region = "加勒比地区", portId = "jamaica",
                control = 55, stability = 45,
                resources = {
                    { name = "蔗糖", count = 3, income = 120 },
                    { name = "朗姆酒", count = 1, income = 40 },
                },
                capacity = 3, capacityRate = 2,
                colonialDeg = 2, colonialDegRate = 2,
                risks = { resistance = "high", disease = "medium", pirate = "low" },
                currentEvent = nil,
            },
            {
                id = "jamestown", name = "弗吉尼亚殖民地", region = "北美殖民地", portId = "jamestown",
                control = 85, stability = 78,
                resources = {
                    { name = "烟草", count = 3, income = 90 },
                    { name = "木材", count = 2, income = 30 },
                },
                capacity = 5, capacityRate = 3,
                colonialDeg = 4, colonialDegRate = 2,
                risks = { resistance = "low", disease = "low", pirate = "low" },
                currentEvent = nil,
            },
        },
        selectedColony = 1,

        -- 贸易路线
        tradeRoutes = {
            { name = "波尔多→卡萨→哈尔纳→波尔多", type = "三角贸易", grade = 3, income = 680,  risk = "low" },
            { name = "里斯本→圣多斯→多尔多",       type = "三角贸易", grade = 2, income = 420,  risk = "low" },
            { name = "利物浦→波士顿",               type = "直贸易",   grade = 2, income = 160,  risk = "medium" },
            { name = "阿姆斯特丹→巴达维亚",         type = "直贸易",   grade = 1, income = 120,  risk = "low" },
            { name = "波尔多→西非海岸",              type = "直贸易",   grade = 1, income = 90,   risk = "high" },
        },

        -- 家族成员 —— 属性键对齐 GDD 六维
        family = {
            { name = "威廉·霍金斯", role = "家族首领",   age = 55, stats = {leadership=82, commercial=61, sailing=58, engineering=71, diplomacy=61, exploration=78} },
            { name = "亨利",         role = "航运总监",   age = 32, stats = {leadership=68, commercial=65, sailing=62, engineering=55, diplomacy=70, exploration=78} },
            { name = "伊丽莎白",     role = "学术总监",   age = 29, stats = {leadership=45, commercial=88, sailing=40, engineering=72, diplomacy=65, exploration=80} },
            { name = "查尔斯",       role = "工业总监",   age = 35, stats = {leadership=50, commercial=55, sailing=85, engineering=40, diplomacy=72, exploration=60} },
            { name = "安妮",         role = "外交总监",   age = 28, stats = {leadership=30, commercial=60, sailing=35, engineering=90, diplomacy=75, exploration=85} },
            { name = "威廉二世",     role = "继承人",     age = 18, stats = {leadership=67, commercial=53, sailing=50, engineering=48, diplomacy=55, exploration=72} },
            { name = "玛丽",         role = "继承人",     age = 15, stats = {leadership=45, commercial=65, sailing=40, engineering=55, diplomacy=50, exploration=70} },
        },

        -- 科技
        researchedTechs = { "astro_nav", "royal_academy" },
        researchingTech = nil,
        researchProgress = 0,

        -- 外交（status 使用英文 key，与 Theme.relationColors 对齐）
        diplomacy = {
            { nation = "英国",   relation = 65,  status = "ally",    color = {200,60,60,255} },
            { nation = "葡萄牙", relation = 45,  status = "friend",  color = {40,160,80,255} },
            { nation = "法国",   relation = -30, status = "hostile", color = {70,130,220,255} },
            { nation = "西班牙", relation = 10,  status = "neutral", color = {220,180,40,255} },
        },

        -- 舰队
        fleet = {
            power = 1520,
            ships = 12,
        },

        -- 历史记录
        history = {
            events = {
                "加勒比地区贸易量增长17%",
                "西非海岸发生奴隶暴动",
                "法国对我方态度恶化",
                "新的科技研究完成：皇家科学院",
                "发现新大陆：新百汇",
            },
            wealthHistory = { 8000, 8500, 9200, 10100, 11200, 12450 },
            yearLabels = { "1716", "1717", "1718", "1719", "1720", "1721" },
        },

        -- 世界排名
        ranking = {
            { name = "霍金斯家族",   wealth = 12450 },
            { name = "范·奥兰家族",  wealth = 9860 },
            { name = "曹格宗家族",   wealth = 8740 },
            { name = "梅迪奇银行",   wealth = 6530 },
            { name = "穆拉维尔家族", wealth = 5420 },
        },

        -- 海战
        currentBattle = nil,
    }
end

return M
