--- 麻将AI算法
-- 思路： 向听数
-- 网址： http://tenhou.net/2/

package.path  = "../MjAI/?.lua;../common/?.lua;../lualib/?.lua"
package.cpath = "../luaclib/?.so"

local json = require "cjson"
local utils = require "utils"

-- 麻将牌类型
local CARD_TYPE = {
    WAN     = 1, --万
    TIAO    = 2, --筒
    TONG    = 3, --条
    ZI      = 4, --字
}

local CARD_HAND_PLAYER_COUNT = 13; -- 玩家起手牌

local players = {nil, nil, nil, nil} -- 4人
local CardHeap = {}
local CardCfgByThisId = {}
local AllCardIds = {}

local function LoadJsonFile(fileName)
    local fileContent = io.open(fileName)
    local data = json.decode(fileContent:read('a'))
    return data
end

-- 创建牌堆
local function CreateHeap(cards)
    local tb = {}
    for _, v in ipairs(cards) do
        table.insert(tb, v)
    end
    return tb
end

-- 洗牌
local function Shuffle()
    for i = #CardHeap, 2, -1 do
        local tmp = CardHeap[i]
        local index = math.random(1, i - 1)
        CardHeap[i] = CardHeap[index]
        CardHeap[index] = tmp
    end
end

-- 从牌堆获取牌
local function GetCardFromHeap(seatId, count)
    local player = players[seatId]
    assert(player, seatId)

    local cards = {}
    if #CardHeap < count then
        print("Game Over")
    else
        for _ = 1, count do
            local item = table.remove(CardHeap, 1)
            table.insert(players[seatId].handCards, item)
        end
    end
end

-- 发牌
local function SendCards()
    for i = 1, #players do
        GetCardFromHeap(i, CARD_HAND_PLAYER_COUNT)
    end
end

-- 摸牌
local function InCard(seatId)
    local item = table.remove(CardHeap, 1)
    table.insert(players[seatId].handCards, item)
    table.sort(players[seatId].handCards, function(a, b) return a.thisId < b.thisId end)
    print("摸牌: ", item.desc)
end

-- 移除手牌
local function RemoveCardFromHnad(seatId, thisId)
    local player = players[seatId]
    assert(player, seatId)

    local outCard
    for i = #player.handCards, 1, -1 do
        if (player.handCards[i].thisId == thisId) then
            outCard =table.remove(player.handCards, i)
        end
    end
    return outCard
end

-- 出牌
local function OutCard(seatId, thisId)
    local player = players[seatId]
    assert(player, seatId)

    local outCard = RemoveCardFromHnad(seatId, thisId)
    table.insert(player.outCards, outCard)
    print("打牌: ", outCard.desc)
end

-- 打印牌数组
local function GetCardsDesc(cards)
    local cardDescs = {}
    for _, v in ipairs(cards) do
        table.insert(cardDescs, v.desc)
    end
    return table.concat(cardDescs, " ")
end

local function GetCardsDescEx(cardIds)
    local cardDescs = {}
    for _, v in ipairs(cardIds) do
        table.insert(cardDescs, CardCfgByThisId[v*10+1].desc)
    end
    return table.concat(cardDescs, " ")
end



local function GetSameCards(cards, cardId)
    local arr = {}
    for _, v in ipairs(cards) do
        if v.cardId == cardId then
            table.insert(arr, v)
        end
    end
    return arr
end

-- 打印玩家信息
local function PrintPlayerInfo(seatId)
    local player = players[seatId]
    assert(player, seatId)

    print(string.format("seatId:%d, username:%s, cards:%s", player.seatId, player.username, GetCardsDesc(player.handCards)))
end

-- 计算剩余数量
local function CalcCardLeftCount(seatId, cardId)
    local player = players[seatId]
    assert(player, seatId)

    local count = 4
    for i, v in ipairs(player.handCards) do
        if v.cardId == cardId then
            count = count - 1
            if count == 0 then break end
        end
    end

    for i, v in ipairs(player.outCards) do
        if v.cardId == cardId then
            count = count - 1
            if count == 0 then break end
        end
    end
    -- todo: 加上吃碰杠的牌
    return count
end

local function PrintSuggests(suggestsCards)
    if #suggestsCards > 0 then
        print("推荐出牌如下：")
        for _, v in ipairs(suggestsCards) do
            print("打 " .. v.desc .. " 摸 " ..  GetCardsDescEx(v.inCardIds) .. " 剩余 " .. v.targetNum .. " 张")
        end
    end
end

local function GetSingleCards(cards)
    local singleCards = {}

    local cardsByType = {} -- 类型分类
    local cardsCountByCardId = {} -- 牌值计数
    for _, v in ipairs(cards) do
        if not cardsByType[v.type] then
            cardsByType[v.type] = {}
        end
        table.insert(cardsByType[v.type], v)

        if not cardsCountByCardId[v.cardId] then
            cardsCountByCardId[v.cardId] = 0
        end
        cardsCountByCardId[v.cardId] = cardsCountByCardId[v.cardId] + 1
    end

    for cardType, v in pairs(cardsByType) do
        for _, card in ipairs(v) do
            if (card.type == CARD_TYPE.WAN or card.type == CARD_TYPE.TIAO or card.type == CARD_TYPE.TONG) then
                local point = card.point
                local exist = false
                for i = point-2, point+2 do
                    local cardId = card.type*10+i
                    if (i >= 1 and i <= 9) then
                        if cardsCountByCardId[cardId] then
                            if i == point then
                                if cardsCountByCardId[cardId] > 1 then
                                    exist = true
                                end
                            else
                                if cardsCountByCardId[cardId] > 0 then
                                    exist = true
                                end
                            end
                        end
                    end
                end
                if not exist then
                    table.insert(singleCards, card)
                end
            elseif card.type == CARD_TYPE.ZI then
                if cardsCountByCardId[card.cardId] == 1 then
                    table.insert(singleCards, card)
                end
            else
                print("card type error:", card.type)
            end
        end
    end
    return singleCards
end

local function CheckCardGroups(cards)
    if #cards == 0 then return true end
    local oneCards = GetSameCards(cards, cards[1].cardId)
    local count = #oneCards
    if (count == 1 or count == 2) then -- 单张两张必须是吃组合
        if oneCards[1].type == CARD_TYPE.ZI then return false end -- 万筒条才能组成顺子

        local twoCards = GetSameCards(cards, oneCards[1].cardId+1)
        if #twoCards <= 0 then return false end

        local threeCards = GetSameCards(cards, oneCards[1].cardId+2)
        if #threeCards <= 0 then return false end

        for i = #cards, 1, -1 do
            if cards[i] == oneCards[1] or cards[i] == twoCards[1] or cards[i] == threeCards[1] then
                table.remove(cards, i)
            end
        end
    elseif count == 3 then -- 三张可以是一个碰(注意如果三个都组成吃,则三个都是碰 算番会不一样)
        for i = 3, 1, -1 do
            table.remove(cards, i)
        end
    elseif count == 4 then -- 四张可以是1个碰和1个吃
        for i = 3, 1, -1 do
            table.remove(cards, i)
        end
    else
        print("this must not happend, if this happend please call me", count)
        return false
    end
    return CheckCardGroups(cards)
end

local function CheckCanHu(cards)
    local cardsByCardId = {} -- 相同牌值映射表 { cardId => {} }
    for _, v in ipairs(cards) do
        if not cardsByCardId[v.cardId] then
            cardsByCardId[v.cardId] = {}
        end
        table.insert(cardsByCardId[v.cardId],  v)
    end

    for k, v in pairs(cardsByCardId) do
        if #v >= 2 then
            local jiangCards = {}
            local copyCards = utils.copy(cards)
            for i = #copyCards, 1, -1 do
                if copyCards[i].cardId == k then
                    local card = table.remove(copyCards, i)
                    table.insert(jiangCards, card)
                end

                if #jiangCards >= 2 then break end
            end
            if CheckCardGroups(copyCards) then
                return true
            end
        end
    end
    return false
end

local function GetTingObj(cards, outCard)
    local inCardIds = {}
    for i = #cards, 1, -1 do
        if (cards[i].thisId == outCard.thisId) then
            table.remove(cards, i)
        end
    end
    for cardId, _ in pairs(AllCardIds) do -- fixme: 此处可以优化 去掉不必要的遍历
        local copyCards = utils.copy(cards)
        local inCard = utils.copy(CardCfgByThisId[cardId*10+1])
        inCard.thisId = cardId*10+5
        table.insert(copyCards, inCard)
        if(CheckCanHu(copyCards)) then
            table.insert(inCardIds, cardId)
        end
    end

    if #inCardIds > 0 then
        outCard.inCardIds = inCardIds
        return true
    else
        return false
    end
end

local function GetTingInfo(cards)
    local suggestsCards = {}

    local cardsByCardId = {} -- 相同牌值映射表 { cardId => {} }
    for _, v in ipairs(cards) do
        if not cardsByCardId[v.cardId] then
            cardsByCardId[v.cardId] = {}
        end
        table.insert(cardsByCardId[v.cardId],  v)
    end

    for k, v in pairs(cardsByCardId) do
        local copyCards = utils.copy(cards)
        if GetTingObj(copyCards, v[1]) then
            table.insert(suggestsCards, v[1])
        end
    end

    return suggestsCards
end

local function getNotUsedCard(cards)
    if not cards then return 0 end
    local count = 0
    for _, v in ipairs(cards) do
        if not v.used then
            count = count + 1
        end
    end
    return count
end

-- 组合拆分
local function GetMultiCards(cards, suggestsCards)
    local needGroupCount = (#cards-2)/3 + 1

    local cardsByCardId = {} -- 相同牌值映射表 { cardId => {} }
    for _, v in ipairs(cards) do
        if not cardsByCardId[v.cardId] then
            cardsByCardId[v.cardId] = {}
        end
        table.insert(cardsByCardId[v.cardId],  v)
    end

    local lackGroups = {} -- 残缺组合
    local cardGroups = {} -- 完整组合
    -- fixme: 目前先实现单一组合 需要所有推荐 则用回溯法遍历所有情况
    for _, cardId, arr in utils.spairs(cardsByCardId) do
        for _, card in ipairs(arr) do
            local notUserCardCount = getNotUsedCard(arr)
            if not card.used then
                if #arr >= 3 and notUserCardCount >= 3 then -- 一坎
                    local cardGroup = {}
                    for _, v in ipairs(arr) do
                        if not v.used then
                            v.used = true
                            table.insert(cardGroup, v)
                            if #cardGroup >= 3 then break end
                        end
                    end
                    table.insert(cardGroups, cardGroup)
                elseif #arr >= 1 and (card.type <= 3 and card.point <= 7) and notUserCardCount >= 1 and getNotUsedCard(cardsByCardId[cardId+1]) >= 1 and getNotUsedCard(cardsByCardId[cardId+2]) >= 1 then -- 一句话
                    local cardGroup = {}
                    for _, v in ipairs(arr) do
                        if not v.used then
                            v.used = true
                            table.insert(cardGroup, v)
                            break
                        end
                    end
                    for _, v in ipairs(cardsByCardId[cardId+1]) do
                        if not v.used then
                            v.used = true
                            table.insert(cardGroup, v)
                            break
                        end
                    end
                    for _, v in ipairs(cardsByCardId[cardId+2]) do
                        if not v.used then
                            v.used = true
                            table.insert(cardGroup, v)
                            break
                        end
                    end
                    table.insert(cardGroups, cardGroup)
                elseif #arr >= 2 and notUserCardCount >= 2 then
                    local lackGroup = {}
                    for _, v in ipairs(arr) do
                        if not v.used then
                            v.used = true
                            table.insert(lackGroup, v)
                            if #lackGroup >= 2 then break end
                        end
                    end
                    table.insert(lackGroups, lackGroup)
                elseif (#arr >= 1) and (card.type <= 3 and card.point <= 7) and notUserCardCount >= 1 and (getNotUsedCard(cardsByCardId[cardId+1]) >= 1) or (getNotUsedCard(cardsByCardId[cardId+2]) >= 1) then
                    if cardsByCardId[cardId+1] then
                        for _, v1 in ipairs(cardsByCardId[cardId+1]) do
                            if not v1.used then
                                card.used = true
                                v1.used = true
                                table.insert(lackGroups, {card, v1})
                                break
                            end
                        end
                    elseif cardsByCardId[cardId+2] then
                        for _, v1 in ipairs(cardsByCardId[cardId+2]) do
                            card.used = true
                            v1.used = true
                            table.insert(lackGroups, {card, v1})
                            break
                        end
                    end
                end
            end
        end
    end

    -- 残缺组合刚好满足希望 则剩余的牌作为推荐
    -- 残缺组合多余期望 则剩余的牌+残缺组合中的一组作为推荐
    local outCards = {}

    for _, v in ipairs(cards) do
        if not v.used then
            table.insert(outCards, v)
        end
    end

    if #lackGroups > needGroupCount - #cardGroups then
        for _, arr in ipairs(lackGroups) do
            for _, v in ipairs(arr) do
                table.insert(outCards, v)
            end
        end
    end

    for i, v in ipairs(outCards) do
        local exist = false
        for _, v1 in ipairs(suggestsCards) do
            if v1.cardId == v.cardId then
                exist = true
                break
            end
        end
        if not exist then
            table.insert(suggestsCards, v)
        end
    end
end

-- 计算听牌信息
local function CalcPlayerTingInfo(seatId, handCards)
    local len = #handCards
    assert(len%3 == 2, len)

    local ret = 0
    local outCardId = 0
    local cards = utils.copy(handCards)
    local suggestsCards = {}
    if CheckCanHu(cards) then
        print("--------- 已经胡牌 ---------")
        ret = 0
    else
        suggestsCards = GetTingInfo(cards)
        if #suggestsCards > 0 then
            print("--------- 已经听牌 ---------")
            ret = 1
        else
            suggestsCards = GetSingleCards(cards) -- 优先出单张
            if #suggestsCards <= 0 then
                print("--------- 无单张牌 ---------")

                GetMultiCards(cards, suggestsCards)
                ret = 3
            else
                print("--------- 有单张牌 ---------")
                ret = 2
            end
        end

        local maxTargetNum = 1000
        for _, v in ipairs(suggestsCards) do
            if not v.inCardIds then v.inCardIds = {} end
            v.targetNum = 0
            for _, value in ipairs(v.inCardIds) do
                v.targetNum = v.targetNum + CalcCardLeftCount(seatId, value)
            end

            if v.targetNum < maxTargetNum then
                outCardId = v.thisId
            end
        end

        if #suggestsCards > 0 then
            PrintSuggests(suggestsCards)
        end
    end
    return ret, outCardId
end

local function main()
    math.randomseed(os.time())

    local player = {
        seatId      = 1,
        username    = "张三",
        handCards   = {},
        outCards    = {},
        chiGroups   = {},
        pengGroups  = {},
        gangGroups  = {},
        suggests    = {}, -- 推荐出牌数组
    }
    players[player.seatId] = player

    local CardCfg = LoadJsonFile("TableCard.json")
    for _, v in ipairs(CardCfg) do
        CardCfgByThisId[v.thisId] = v
        if not AllCardIds[v.cardId] then
            AllCardIds[v.cardId] = true
        end
    end

    CardHeap = CreateHeap(CardCfg)
    Shuffle()
    SendCards()

    local warnCount = 0
    while #CardHeap > 0 do
        InCard(1)

        PrintPlayerInfo(1)
        local ret, outCardId = CalcPlayerTingInfo(1, player.handCards)
        if ret == 0 then break end

        OutCard(1, outCardId)

        warnCount = warnCount + 1
        if warnCount > 100 then break end
    end
end

main()
