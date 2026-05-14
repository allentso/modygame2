-- ============================================================================
-- GameEngine.lua - 回合引擎（回合结算、经济、事件）
-- 资源键名对齐 GameState: wealth/enlightenment/production/prestige/maritime/colonial
-- ============================================================================
local EventData = require("data.EventData")
local TechData = require("data.TechData")

local M = {}

--- 结束回合，执行全部结算
---@param state table GameState
---@return table turnReport 回合报告
function M.EndTurn(state)
    local report = { events = {} }

    -- 1. 年份推进
    state.year = state.year + 1
    state.turn = state.turn + 1
    state.ap = state.maxAp

    -- 2. 资源按费率增减
    for key, res in pairs(state.resources) do
        if type(res) == "table" and res.rate then
            res.value = math.max(0, res.value + res.rate)
        end
    end

    -- 3. 殖民地产出结算
    for _, colony in ipairs(state.colonies) do
        local colonyIncome = 0
        for _, res in ipairs(colony.resources) do
            colonyIncome = colonyIncome + res.income
        end
        state.resources.wealth.value = state.resources.wealth.value + colonyIncome

        -- 殖民地控制度/稳定度自然变化
        colony.stability = math.min(100, colony.stability + math.random(-3, 2))
        colony.control = math.min(100, colony.control + math.random(-2, 2))
        colony.capacity = colony.capacity + colony.capacityRate
    end

    -- 4. 贸易路线收入
    for _, route in ipairs(state.tradeRoutes) do
        state.resources.wealth.value = state.resources.wealth.value + route.income
    end

    -- 5. 科技研究进度
    if state.researchingTech then
        for _, tech in ipairs(TechData.techs) do
            if tech.id == state.researchingTech then
                state.researchProgress = state.researchProgress + state.resources.enlightenment.rate
                if state.researchProgress >= tech.cost then
                    -- 科技研究完成
                    state.researchedTechs[#state.researchedTechs + 1] = tech.id
                    -- 应用科技效果
                    if tech.effects then
                        for key, val in pairs(tech.effects) do
                            if state.resources[key] then
                                state.resources[key].rate = state.resources[key].rate + val
                            end
                        end
                    end
                    report.events[#report.events + 1] = "科技研究完成：" .. tech.name
                    state.researchingTech = nil
                    state.researchProgress = 0
                end
                break
            end
        end
    end

    -- 6. 随机事件
    for _, evt in ipairs(EventData.events) do
        if math.random(100) <= evt.probability then
            report.events[#report.events + 1] = evt.title .. " - " .. evt.desc
            -- 应用事件效果
            if evt.effects then
                for key, val in pairs(evt.effects) do
                    if state.resources[key] then
                        state.resources[key].value = math.max(0, state.resources[key].value + val)
                    end
                    if key == "stability" then
                        for _, colony in ipairs(state.colonies) do
                            colony.stability = math.max(0, math.min(100, colony.stability + val))
                        end
                    end
                end
            end
            break -- 每回合最多触发一个随机事件
        end
    end

    -- 7. 外交关系自然变化（status 使用英文键，与 Theme.relationColors 对齐）
    for _, entry in ipairs(state.diplomacy) do
        entry.relation = entry.relation + math.random(-3, 3)
        entry.relation = math.max(-100, math.min(100, entry.relation))
        -- 更新状态描述（英文 key）
        if entry.relation >= 50 then entry.status = "ally"
        elseif entry.relation >= 20 then entry.status = "friend"
        elseif entry.relation >= -20 then entry.status = "neutral"
        else entry.status = "hostile" end
    end

    -- 8. 更新财富历史
    state.history.wealthHistory[#state.history.wealthHistory + 1] = state.resources.wealth.value
    state.history.yearLabels[#state.history.yearLabels + 1] = tostring(state.year)
    -- 保留最近6年
    while #state.history.wealthHistory > 6 do
        table.remove(state.history.wealthHistory, 1)
        table.remove(state.history.yearLabels, 1)
    end

    -- 9. 将新事件加入历史
    for _, evt in ipairs(report.events) do
        table.insert(state.history.events, 1, evt)
    end
    -- 保留最近10条
    while #state.history.events > 10 do
        table.remove(state.history.events)
    end

    -- 10. 更新排名
    state.ranking[1].wealth = state.resources.wealth.value
    -- 其他家族也有增长
    for i = 2, #state.ranking do
        state.ranking[i].wealth = state.ranking[i].wealth + math.random(100, 500)
    end
    -- 排序
    table.sort(state.ranking, function(a, b) return a.wealth > b.wealth end)

    -- 11. 家族成员年龄增长
    for _, member in ipairs(state.family) do
        member.age = member.age + 1
    end

    -- 更新章节
    if state.year >= 1750 then
        state.chapter = "第五章：工业黎明"
    elseif state.year >= 1740 then
        state.chapter = "第四章：帝国争霸"
    end

    return report
end

--- 研究科技
function M.StartResearch(state, techId)
    -- 检查科技是否可研究
    for _, id in ipairs(state.researchedTechs) do
        if id == techId then return false, "已研究" end
    end
    state.researchingTech = techId
    state.researchProgress = 0
    return true
end

--- 殖民地操作
function M.ColonyAction(state, action, colonyId)
    for _, colony in ipairs(state.colonies) do
        if colony.id == colonyId then
            if action == "upgrade" then
                if state.resources.wealth.value >= 200 then
                    state.resources.wealth.value = state.resources.wealth.value - 200
                    colony.capacityRate = colony.capacityRate + 1
                    for _, res in ipairs(colony.resources) do
                        res.income = res.income + math.random(5, 15)
                    end
                    return true, "种植园已升级"
                end
                return false, "财富不足"
            elseif action == "fleet" then
                if state.resources.maritime.value >= 20 then
                    state.resources.maritime.value = state.resources.maritime.value - 20
                    colony.risks.pirate = "low"
                    colony.control = math.min(100, colony.control + 10)
                    return true, "舰队已驻扎"
                end
                return false, "航权不足"
            elseif action == "tax" then
                state.resources.wealth.rate = state.resources.wealth.rate - 20
                colony.stability = math.min(100, colony.stability + 15)
                colony.risks.resistance = "low"
                return true, "已减税安抚"
            end
        end
    end
    return false, "未找到殖民地"
end

return M
