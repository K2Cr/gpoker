util.AddNetworkString("gpoker_derma_createGame") 
util.AddNetworkString("gpoker_updatePlayers") 
util.AddNetworkString("gpoker_payEntry")
util.AddNetworkString("gpoker_sendDeck") 
util.AddNetworkString("gpoker_derma_bettingActions") 
util.AddNetworkString("gpoker_derma_exchange")
util.AddNetworkString("gpoker_derma_leaveRequest")

net.Receive("gpoker_derma_createGame", function(l, ply)
    if (not ply or not IsValid(ply)) then 
        return 
    end

    local tr = ply:GetEyeTraceNoCursor()
    local pos = tr.HitPos + tr.HitNormal * 10
    local ang = ply:EyeAngles()
    ang.ply = 0
    ang.y = ang.y + 180

    local options = net.ReadTable()

    local poker = ents.Create("ent_poker_game")
    poker:SetPos(pos)
    poker:SetAngles(ang)
    poker:Spawn()
    poker:Activate()

    undo.Create("GPoker Table")
        undo.AddEntity(poker)
        undo.SetPlayer(ply)
    undo.Finish()   

    poker:SetGameType(options.game.type)
    poker:SetMaxPlayers(options.game.maxPly)

    poker:SetBetType(options.bet.type)
    poker:SetEntryBet(options.bet.entry)
    poker:SetStartValue(options.bet.start)
end)



net.Receive("gpoker_payEntry", function(_, ply)
    local ent = gPoker.getTableFromPlayer(ply)
    local paid = net.ReadBool()

    if (not ent or not IsValid(ent)) then 
        return 
    end

    if (gPoker.betType[ent:GetBetType()].canJoin and not gPoker.betType[ent:GetBetType()].canJoin(ply,ent)) then
        if (DarkRP) then
            DarkRP.notify(ply, 1, 4, "You do not have enough money for the entry fee!")
        else
            ply:PrintMessage(HUD_PRINTTALK, "You do not have enough money for the entry fee!")
        end
        paid = false
    end

    if paid then
        gPoker.betType[ent:GetBetType()].add(ply, -ent:GetEntryBet(), ent)

        local key = ent:getPlayerKey(ply)

        if key != nil then
            ent.players[ent:getPlayerKey(ply)].ready = true
            sound.Play("mvm/mvm_money_pickup.wav", ent:GetPos())
        end
    else
        ent:removePlayerFromMatch(ply)
    end

    local allReady = true
    for _, v in pairs(ent.players) do
        if !v.ready then allReady = false break end
    end

    if allReady and IsValid(ent) and ent:GetGameState() > 0 then ent:nextState() end
end)



net.Receive("gpoker_derma_bettingActions", function(l, ply)
    local poker_tbl = gPoker.getTableFromPlayer(ply)
    if (not poker_tbl or not IsValid(poker_tbl)) then 
        return 
    end

    if (poker_tbl:GetGameState() < 1) then 
        return 
    end

    local choice = net.ReadUInt(3)
    local val = net.ReadFloat()
    local k = poker_tbl:getPlayerKey(ply)

    if choice == 0 then
        sound.Play("gpoker/check.wav", poker_tbl:GetPos())
    elseif choice == 1 then
        gPoker.betType[poker_tbl:GetBetType()].add(ply, -val, poker_tbl)
        poker_tbl:SetCheck(false)
        poker_tbl:SetBet(val)
        poker_tbl.players[k].paidBet = val

        for k,v in pairs(poker_tbl.players) do
            if not v.fold then
                v.ready = false
            end
        end

        sound.Play("mvm/mvm_money_pickup.wav", poker_tbl:GetPos())
    elseif choice == 2 then
        gPoker.betType[poker_tbl:GetBetType()].add(ply, -(poker_tbl:GetBet() - poker_tbl.players[k].paidBet), poker_tbl)
        poker_tbl.players[k].paidBet = poker_tbl:GetBet()

        sound.Play("mvm/mvm_money_pickup.wav", poker_tbl:GetPos())
    elseif choice == 3 then
        gPoker.betType[poker_tbl:GetBetType()].add(ply, -val, poker_tbl)
        poker_tbl.players[k].paidBet = val

        for k,v in pairs(poker_tbl.players) do
            if not v.fold then
                v.ready = false
            end
        end

        poker_tbl:SetBet(val)

        sound.Play("mvm/mvm_money_pickup.wav", poker_tbl:GetPos())
    elseif choice == 4 then
        poker_tbl.players[k].fold = true
    end

    poker_tbl.players[k].ready = true

    poker_tbl:updatePlayersTable()

    timer.Simple(0.2, function()
        if !IsValid(poker_tbl) then return end
        
        poker_tbl:proceed() 
    end)
end)



net.Receive("gpoker_derma_exchange", function(l,ply)
    local poker_tbl = gPoker.getTableFromPlayer(ply)
    local cards = net.ReadTable()

    if !IsValid(poker_tbl) then return end

    local plyKey = poker_tbl:getPlayerKey(ply)
    local selectCards = {}

    for k,v in ipairs(cards) do
        if v then selectCards[#selectCards + 1] = k end 
    end

    if !table.IsEmpty(selectCards) then
        local oldCards = {}

        for k,v in pairs(selectCards) do
            oldCards[poker_tbl.decks[plyKey][v].suit] = poker_tbl.decks[plyKey][v].rank

            poker_tbl:dealSingularCard(plyKey, v)
        end

        for k,v in pairs(oldCards) do
            poker_tbl.deck[k][v] = true
        end

        net.Start("gpoker_sendDeck")
            net.WriteEntity(poker_tbl)
            net.WriteTable(poker_tbl.decks[poker_tbl:getPlayerKey(ply)])
        net.Send(Entity(poker_tbl.players[poker_tbl:getPlayerKey(ply)].ind))

        sound.Play("gpoker/cardthrow.wav", poker_tbl:GetPos())
    end

    poker_tbl.players[plyKey].ready = true

    poker_tbl:updatePlayersTable()
    poker_tbl:proceed()
end)



net.Receive("gpoker_derma_leaveRequest", function(l, ply)
    local poker = gPoker.getTableFromPlayer(ply)
    poker:removePlayerFromMatch(ply)
end)



hook.Add("CanProperty", "gpoker_blockSkinChange", function(ply, property, ent)
    if ent:GetClass() == "ent_poker_card" then 
        return false 
    end
end)

hook.Add("PlayerDisconnected", "gpoker_playerDisconnected", function(ply)
    local ent = gPoker.getTableFromPlayer(ply)

    if IsValid(ent) then
        ent:removePlayerFromMatch(ply)
    end
end)

hook.Add("CanExitVehicle", "gpoker_disableSeatExitting", function(veh, ply)
    if veh:GetVehicleClass() == "Chair_Office2" and IsValid(veh:GetParent()) and veh:GetParent():GetClass() == "ent_poker_game" then return false end
end)

hook.Add("EntityTakeDamage", "gpoker_nullifyPlayerDamage", function(attacked, dmgInfo)
    local attacker = dmgInfo:GetAttacker()

    if (attacked:IsPlayer() and attacked:InVehicle() and IsValid(attacked:GetVehicle():GetParent()) and attacked:GetVehicle():GetParent():GetClass() == "ent_poker_game") or (attacker:IsPlayer() and attacker:InVehicle() and IsValid(attacker:GetVehicle():GetParent()) and attacker:GetVehicle():GetParent():GetClass() == "ent_poker_game") then
        dmgInfo:SetDamage(0)
    end
end)

hook.Add("PlayerChangedTeam","gpoker_plyChangedTeam",function(ply)
    local gpoker_tbl = gPoker.getTableFromPlayer(ply)
    if (gpoker_tbl and IsValid(gpoker_tbl)) then
        if (DarkRP) then
            DarkRP.notify(ply, 1, 4, "You have left the poker table.")
        else
            ply:PrintMessage(HUD_PRINTTALK, "You have left the poker table.")
        end
        gpoker_tbl:removePlayerFromMatch(ply)
    end
end)

hook.Add("CanPlayerSuicide", "gpoker_disableKillBind", function(ply)
    if ply:InVehicle() and IsValid(ply:GetVehicle():GetParent()) and ply:GetVehicle():GetParent():GetClass() == "ent_poker_game" then
        return false
    end
end)