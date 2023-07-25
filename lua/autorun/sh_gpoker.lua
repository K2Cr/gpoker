gPoker = gPoker or {}

-- gPoker.model = Model("") // Why does this exist??

//Poker games

//WARNING: Keep in mind that networking of both game types and betting in the creation derma menu is used with net.WriteUInt(), and so the limit is 32
gPoker.gameType = {
    [0] = {
        name        = "Five Draw",  --The fancy name
        cardNum     = 5,            --Number of cards each player has
        cardDraw    = true,         --Can players exchange cards?
        cardComm    = false,        --Use community cards (cards in the center)?
        cardCommNum = 0,            --Amount of community cards (if uses any)
        cardCanSee  = true,         --Can players see their cards on HUD?
        available   = true,         --Is available?
        states      = {             --(NOTE: Begins AFTER the intermission timer) List of all actions
            [1] = {
                text    = "Entry Fee",
                func    = function(e) if CLIENT then return end e:entryFee() end  
            },
            [2] = {
                text    = "Dealing Cards...",           --Text to be displayed at the top, can also be function
                func    = function(e) if CLIENT then return end e:beginRound() end --Function that will run on the table
            },
            [3] = {
                text    = "Betting Round",
                func    = function(e) if CLIENT then return end e:bettingRound() end
            },
            [4] = {
                text    = "Drawing Round",
                func    = function(e) if CLIENT then return end e:drawingRound() end,
                drawing = true
            },
            [5] = {
                text    = "Last Betting Round",
                func    = function(e) if CLIENT then return end e:bettingRound() end
            },
            [6] = {
                text    = function(e)
                    local win = Entity(e.players[e:GetWinner()].ind)

                    if !IsValid(win) then return end

                    local t
                    if win:IsPlayer() then t = win:Nick() else t = "PLACEHOLDER" end
                    t =  t .. " has: "

                    if e.players[e:GetWinner()].strength and e.players[e:GetWinner()].value then
                        t = t .. gPoker.fancyDeckStrength(e.players[e:GetWinner()].strength, e.players[e:GetWinner()].value)
                    else
                        t = t .. "..."
                    end

                    return t
                end,
                func    = function(e) if CLIENT then return end e:revealCards() end,
                final   = true
            },
            [7] = {
                text    = function(e)
                    if !IsValid(e) then return end

                    local win = Entity(e.players[e:GetWinner()].ind)

                    if !IsValid(win) then return "Winner: " end

                    local t = "Winner: "
                    if win:IsPlayer() then t = t .. win:Nick() else t = t .. "PLACEHOLDER" end
                    t = t .. ", " .. gPoker.fancyDeckStrength(e.players[e:GetWinner()].strength, e.players[e:GetWinner()].value)

                    return t
                end,
                func    = function(e) if CLIENT then return end e:finishRound() end
            },
        }
    },
    [1] = {
        name        = "Texas Hold'em", 
        cardNum     = 2,           
        cardDraw    = false,        
        cardComm    = true,       
        cardCommNum = 5,
        cardCanSee  = true,
        available   = true,
        states      = {
            [1] = {
                text = "Entry Fee",
                func = function(e) if CLIENT then return end e:entryFee() end
            },
            [2] = {
                text = "Dealing Cards...",
                func = function(e) if CLIENT then return end e:beginRound() end
            },
            [3] = {
                text = "First Bet",
                func = function(e) if CLIENT then return end e:bettingRound() end
            },
            [4] = {
                text = "Revealing the Flop",
                func = function(e) if CLIENT then return end e:revealCommunityCards({1,2,3}) end
            },
            [5] = {
                text = "Second Bet",
                func = function(e) if CLIENT then return end e:bettingRound() end
            },
            [6] = {
                text = "Revealing the Turn",
                func = function(e) if CLIENT then return end e:revealCommunityCards(4) end
            },
            [7] = {
                text = "Third Bet",
                func = function(e) if CLIENT then return end e:bettingRound() end
            },
            [8] = {
                text = "Revealing the River",
                func = function(e) if CLIENT then return end e:revealCommunityCards(5) end
            },
            [9] = {
                text = "Last Bet",
                func = function(e) if CLIENT then return end e:bettingRound() end
            },
            [10] = {
                text    = function(e)
                    local win = Entity(e.players[e:GetWinner()].ind)

                    if !IsValid(win) then return end

                    local t
                    if win:IsPlayer() then t = win:Nick() else t = "PLACEHOLDER" end
                    t =  t .. " has: "

                    if e.players[e:GetWinner()].strength and e.players[e:GetWinner()].value then
                        t = t .. gPoker.fancyDeckStrength(e.players[e:GetWinner()].strength, e.players[e:GetWinner()].value)
                    else
                        t = t .. "..."
                    end

                    return t
                end,
                func    = function(e) if CLIENT then return end e:revealCards() end,
                final   = true
            },
            [11] = {
                text    = function(e)
                    if !IsValid(e) then return end

                    local win = Entity(e.players[e:GetWinner()].ind)

                    if !IsValid(win) then return "Winner: " end

                    local t = "Winner: "
                    if win:IsPlayer() then t = t .. win:Nick() else t = t .. "PLACEHOLDER" end
                    t = t .. ", " .. gPoker.fancyDeckStrength(e.players[e:GetWinner()].strength, e.players[e:GetWinner()].value)

                    return t
                end,
                func    = function(e) if CLIENT then return end e:finishRound() end
            },
        }
    }
}

//Poker bets
gPoker.betType = {
    [0] = {
        name        = "Money",                  --Name
        fix         = "£",                      --Text after value
        canSet      = false,               --Can players set the amount of value each player gets in the spawn derma?
        setMinMax   = {min = 0, max = 10000},   --The minimum and maximum number of starting value (if uses)
        canJoin     = function(ply,table)       --Can the player join the table?
            if (not DarkRP) then
                return true
            end
            local balance = ply:getDarkRPVar("money")
            local min = table:GetEntryBet() or 0
            
            return balance >= min
        end,
        payin       = function(ply, table)
            local balance = ply:getDarkRPVar("money")
            local min = table:GetEntryBet() or 0

            if balance < min then
                return false, "You don't have enough money to join this table!"
            end

            ply:addMoney(-min)
        end,
        payout      = function(ply, amount)
            ply:addMoney(amount)
        end,
        feeMinMax   = {min = 0, max = function(setSlider) 
            if CLIENT then 
                return setSlider:GetValue() 
            end
        end}, --The minimum and maximum of entry fee
        get = function(ply)                           --Method for getting specified player's value
            if (not ply or not IsValid(ply)) then 
                return 
            end
            
            local pokerTbl = gPoker.getTableFromPlayer(ply)

            local key = pokerTbl:getPlayerKey(ply)
            if key == nil then return end

            return pokerTbl.players[key].money
        end,
        add = function(ply, a, ent)                        --Method for adding or subtracting the value
            if CLIENT then 
                return 
            end
            if (not ply or not IsValid(ply)) then 
                return 
            end
            a = a or 0

            local key = ent:getPlayerKey(ply)
            if key == nil then return end

            ent.players[key].money = ent.players[key].money + a
            ent:updatePlayersTable()

            ent:SetPot(e:GetPot() - a)
        end,
        call = function(poker_tbl, ply) --Called after player joins, mostly used for setting up custom value
            poker_tbl.players[poker_tbl:getPlayerKey(ply)].money = poker_tbl:GetStartValue()
        end,
        models      = {  --The spinning model at the center
            [1] = {
                mdl = Model("models/items/currencypack_small.mdl"), --The model, MUST be used with Model() because of CSEnt
                val = 100, --Maximum value this model can be used with
                scale = 0.5 --The scale of the model
            },
            [2] = {
                mdl = Model("models/items/currencypack_medium.mdl"),
                val = 1000,
                scale = 0.5
            },
            [3] = {
                mdl = Model("models/items/currencypack_large.mdl"),
                val = 999999,
                scale = 0.5
            }
        }
    },
    [1] = {
        name        = "Health",
        fix         = "HP",
        canSet      = false,
        setMinMax   = {min = 0, max = 0},
        feeMinMax   = {min = 0, max = function() if CLIENT then return LocalPlayer():GetMaxHealth() end end},
        get         = function(ply)
            if ply:IsPlayer() then
                return ply:Health()
            else
                local ent = gPoker.getTableFromPlayer(ply)

                if !IsValid(ent) then return 0 end

                local key = ent:getPlayerKey(ply)
                return ent.players[key].health
            end
        end,
        add         = function(ply, a, e)
            if CLIENT then return end
            if !IsValid(ply) then return end
            
            a = a or 0

            local hp = gPoker.betType[e:GetBetType()].get(ply) + a
            
            if hp < 1 then 
                e:removePlayerFromMatch(ply)
                if ply:IsPlayer() then ply:Kill() end
            else
                if ply:IsPlayer() then ply:SetHealth(hp) else 
                    e.players[e:getPlayerKey(ply)].health = hp 
                    e:updatePlayersTable() 
                end
            end

            e:SetPot(e:GetPot() - a)
        end,
        call = function(poker_tbl, ply)
            if !ply:IsPlayer() then
                poker_tbl.players[poker_tbl:getPlayerKey(ply)].health = 100 + math.random(0,150) --Add a little randomziation ;)
            end
        end,
        models      = {
            [1] = {
                mdl = Model("models/healthvial.mdl"),
                val = 100,
                scale = 1
            },
            [2] = {
                mdl = Model("models/Items/HealthKit.mdl"),
                val = 999999,
                scale = 1
            }
        }
    }
}

//Cards materials, for hud

if (not gPoker.cards) then
    gPoker.cards = {}

    for poker_tbl = 0, 3 do
        gPoker.cards[poker_tbl] = {}

        for r = 0, 12 do
            gPoker.cards[poker_tbl][r] = Material("gpoker/cards/" .. poker_tbl .. r .. ".png")
        end
    end
end


gPoker.suit = {
    [0] = "Club",
    [1] = "Diamond",
    [2] = "Heart",
    [3] = "Spade"
}


gPoker.rank = {
    [0] = "Two",
    [1] = "Three",
    [2] = "Four",
    [3] = "Five",
    [4] = "Six",
    [5] = "Seven",
    [6] = "Eight",
    [7] = "Nine",
    [8] = "Ten",
    [9] = "Jack",
    [10] = "Queen",
    [11] = "King",
    [12] = "Ace"
}


gPoker.strength = {
    [0] = "High Card",
    [1] = "Pair",
    [2] = "Two Pairs",
    [3] = "Three of a Kind",
    [4] = "Straight",
    [5] = "Flush",
    [6] = "Full House",
    [7] = "Four of a Kind",
    [8] = "Straight Flush",
    [9] = "Royal Flush"
}

//Functions//

//Finds the table player is playing at
function gPoker.getTableFromPlayer(ply)
    if (not ply or not IsValid(ply)) then return end

    local ent = ply:GetNWEntity("gpoker_table")
    if (not ent or not IsValid(ent) or not ent.IsGPokerTable) then 
        return nil
    end

    return ent
end

//Returns a fancy formatted string of deck strength
function gPoker.fancyDeckStrength(st,vl)
    local text = ""
    
    if st == 0 then
        text = "High Card, " .. gPoker.rank[vl]
    elseif st == 1 then
        text = "Pair of "
        local pairText = ""
        if vl == 4 then pairText = "Sixes" else pairText = gPoker.rank[vl] .. "s" end

        text = text .. pairText
    elseif st == 2 then
        text = "Two Pairs, "
        local highPair = math.floor(vl)
        local lowPair = math.Round((vl - highPair) * 100)

        local highPairStr, lowPairStr

        if highPair == 4 then highPairStr = "Sixes" else highPairStr = gPoker.rank[highPair] .. "s" end
        if lowPair == 4 then lowPairStr = "Sixes" else lowPairStr = gPoker.rank[lowPair] .. "s" end

        local pairsText = highPairStr .. " and " .. lowPairStr 
        text = text .. pairsText
    elseif st == 3 then
        text = "Three of a Kind, "
        local threeText = ""
        if vl == 4 then threeText = "Sixes" else threeText = gPoker.rank[vl] .. "s" end

        text = text .. threeText
    elseif st == 4 then
        text = "Straight, " .. gPoker.rank[vl] .. " high"
    elseif st == 5 then
        text = "Flush, " .. gPoker.rank[vl] .. " high"
    elseif st == 6 then
        text = "Full House, "
        local threeKind = math.floor(vl)
        local pair = math.Round((vl - threeKind) * 100)
        local threeKindStr, pairStr

        if threeKind == 4 then threeKindStr = "Sixes" else threeKindStr = gPoker.rank[threeKind] .. "s" end
        if pair == 4 then pairStr = "Sixes" else pairStr = gPoker.rank[pair] .. "s" end

        local fullText =  threeKindStr .. " over " .. pairStr
        text = text .. fullText
    elseif st == 7 then
        text = "Four of a Kind, "
        local fourText = ""
        if vl == 0 then fourText = "Deuces" elseif vl == 4 then fourText = "Sixes" else fourText = gPoker.rank[vl] .. "s" end
        text = text .. fourText
    elseif st == 8 then
        text = "Straight Flush, " .. gPoker.rank[vl] .. " high"
    else
        text = "Royal Flush"
    end

    return text
end