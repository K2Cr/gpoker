//Adding files

include("shared.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

//Poker info
ENT.deck = {}
ENT.decks = {
    [1] = {},
    [2] = {},
    [3] = {},
    [4] = {}
}


//Functions//

//Player tries to spawn the table, send them derma
function ENT:SpawnFunction(ply, tr, class)
    if !IsValid(ply) then return end

    //Spawn derma
    net.Start("gpoker_derma_createGame")
    net.Send(ply)
end


//Player created the entity through derma
function ENT:Initialize()
    self:SetModel("models/props/de_tides/restaurant_table.mdl")
    self:SetModelScale(1.2, 0.00001)
    self:SetUseType(SIMPLE_USE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysWake()

    self:SetCheck(true)
    self:SetGameState(-1)
    self:SetDealer(0)
    self:SetPot(0)
    self:SetBet(0)

    //Precaching for client
    util.PrecacheModel("models/cards/stack.mdl")
    util.PrecacheModel("models/gpoker/dealerchip.mdl")
end

function ENT:updatePlayersTable()
    net.Start("gpoker_updatePlayers")
        net.WriteEntity(self)
        net.WriteTable(self.players)
    net.Broadcast()
end


//Player tries to join
function ENT:Use(act)
    if self:GetGameState() < 1 then
        if !gPoker.getTableFromPlayer() and (#self.players < self:GetMaxPlayers()) then
            if (gPoker.betType[self:GetBetType()].canJoin and not gPoker.betType[self:GetBetType()].canJoin(act,self)) then
                if (DarkRP) then
                    DarkRP.notify(act, 1, 4, "You can't join this table!")
                else
                    act:PrintMessage(HUD_PRINTTALK, "You can't join this table!")
                end
                return
            end
            timer.Simple(0.05, function() //We add delay because of leave request popping up
                if !IsValid(self) or !IsValid(act) then 
                    return 
                end

                //Add the player to the players table
                local index = #self.players + 1
                
                self.players[index] = {
                    ready = true,
                    fold = false,
                    ind = act:EntIndex(),
                    strength = nil,
                    value = nil,
                    paidBet = 0,
                }

                gPoker.betType[self:GetBetType()].call(self, act)

                self.decks[index] = {}
        
                self:updatePlayersTable()
                sound.Play("garrysmod/balloon_pop_cute.wav", self:GetPos())

                //Create seat

                local seat = self:createSeat()
                seat:SetLocalPos(Vector(0,0,0))
                seat:SetLocalAngles(Angle(0,0,0))
                seat:Spawn()

                act:EnterVehicle(seat)
                act:SetEyeAngles(Angle(0,90,0))

                //Position all seats
                self:updateSeatsPositioning()

                act:SetNWEntity("gpoker_table", self)
                //If we have enough players, we can start the intermission
                if self:getPlayersAmount() > 0 and #self.players > 1 and self:GetGameState() == -1 then 
                    self:SetGameState(0) 
                end
            end)
        end
    end
end



//Create a nice, comfy office chair
function ENT:createSeat()
    local vehicleList = list.Get("Vehicles")
    local vehicle = vehicleList["Chair_Office2"]

    local seat = ents.Create(vehicle.Class)
    seat:SetModel(vehicle.Model)

    if (vehicle && vehicle.KeyValues) then
        for k, v in pairs(vehicle.KeyValues) do
            local kLower = string.lower( k )
            if ( kLower == "vehiclescript" or
                 kLower == "limitview"     or
                 kLower == "vehiclelocked" or
                 kLower == "cargovisible"  or
                 kLower == "enablegun" )
            then
                seat:SetKeyValue(k, v)
            end

        end
    end

    seat:SetVehicleClass("Chair_Office2")
    seat.VehicleName = "Chair_Office2"
    seat.VehicleTable = vehicle
    seat:SetMoveType(MOVETYPE_NONE)
    seat:SetCollisionGroup(COLLISION_GROUP_WORLD)
    seat:SetParent(self)

    return seat
end



//Updates the positioning of all seats
function ENT:updateSeatsPositioning()
    local startAng = 90
    local startAngPos = 0
    local radius = 50
    for i = 1, #self.players do
        local ang = startAngPos - (360 / #self.players) * (i - 1)
        local ent = Entity(self.players[i].ind)

        if !IsValid(ent) then return end

        local veh = ent:GetVehicle()

        if !IsValid(veh) then return end
        
        ang = math.rad(ang)
        local x = math.cos(ang) * radius
        local y = math.sin(ang) * radius

        veh:SetLocalPos(Vector(x, y, 0))
        veh:SetLocalAngles(Angle(0,startAng - (360 / #self.players) * (i - 1),0))
    end
end



//Make players pay the ante
function ENT:entryFee()
    for k,v in pairs(self.players) do
        v.ready = false

        if v.ind and Entity(v.ind):IsPlayer() then
            net.Start("gpoker_payEntry", false)
                net.WriteEntity(self)
            net.Send(Entity(v.ind))
        else
            timer.Simple(math.random(5,15) * 0.1, function()
                if !IsValid(self) or self:GetGameState() < 1 then return end

                gPoker.betType[self:GetBetType()].add(Entity(v.ind), -self:GetEntryBet(), self)
                v.ready = true

                sound.Play("mvm/mvm_money_pickup.wav", self:GetPos())
                
                local allReady = true
                for _, value in pairs(self.players) do
                    if !value.ready then allReady = false break end
                end

                if allReady then self:nextState() end
            end)
        end
    end
end



//Begin the game (deal cards)
function ENT:beginRound()
    self:SetCheck(true)
    self:nextDealer()

    for k,v in pairs(self.players) do
        v.ready = false
        v.fold = false
        v.paidBet = 0
    end

    self:preGenerateDeck()
    self:dealCards()

    timer.Create("gpoker_finishDealingCards" .. self:EntIndex(), 0.4 * (#self.players * gPoker.gameType[self:GetGameType()].cardNum) + 0.6 * gPoker.gameType[self:GetGameType()].cardCommNum + 0.5, 1, function()
        if !IsValid(self) then return end

        sound.Play("garrysmod/content_downloaded.wav", self:GetPos())

        self:nextState()
    end)
end



//Sets next dealer
function ENT:nextDealer()
    self:SetDealer(self:nextPlayer(self:GetDealer()))
end



//And it is now YOUR turn to lose all your life savings!
function ENT:nextTurn()
    if self:GetTurn() == 0 then
        self:SetTurn(self:nextPlayer(self:GetDealer()))
    else
        self:SetTurn(self:nextPlayer(self:GetTurn()))
    end
end



//Helper function for nextTurn() and nextDealer()
function ENT:nextPlayer(index)
    index = index + 1

    if index > #self.players or self.players[index].fold then
        local max = 0 --for stopping inf loop

        repeat
            max = max + 1
            index = index + 1

            if index > #self.players then index = 1 end

            if !self.players[index].fold then break end
        until max > 25
    end

    return index
end




//Sets next state
function ENT:nextState()
    self:SetGameState(self:GetGameState() + 1)
    gPoker.gameType[self:GetGameType()].states[self:GetGameState()].func(self)
end



//Generates deck
function ENT:preGenerateDeck()
    for i = 0, 3 do  
        self.deck[i] = {} //Create table for all suits
    end

    for k,v in pairs(self.deck) do
        for i = 0, 12 do
            v[i] = true //Fill all suit tables with 13 card values where true = available
        end
    end
end



//Deals cards to every player
function ENT:dealCards()
    local ind = 1
    local card = 0

    timer.Create("gpoker_dealCards" .. self:EntIndex(), 0.4, gPoker.gameType[self:GetGameType()].cardNum * #self.players, function()
        if !IsValid(self) then return end

        if card == gPoker.gameType[self:GetGameType()].cardNum then
            card = 0
            ind = ind + 1
        end

        self:dealSingularCard(ind)
        self:updateDecksPositioning(ind)
        self:updatePlayersTable()

        sound.Play("gpoker/cardthrow.wav", self:GetPos())

        card = card + 1

        if timer.RepsLeft("gpoker_dealCards" .. self:EntIndex()) == 0 and gPoker.gameType[self:GetGameType()].cardComm then
            timer.Create("gpoker_dealCards" .. self:EntIndex(), 0.6, gPoker.gameType[self:GetGameType()].cardCommNum, function()
                if !IsValid(self) then return end

                self:dealSingularCard()
                self:updateDecksPositioning(0)
                sound.Play("gpoker/cardthrow.wav", self:GetPos())
            end)
        end
    end)
end



//Creates a card entity, no player means we create community cards
function ENT:dealSingularCard(p, key)
    if self:GetGameState() < 1 then return end
    
    key = key or nil
    p = p or nil

    local communityCard = false
    if p == nil then communityCard = true end

    local card

    //We don't have a card so we create it
    if key == nil then
        card = ents.Create("ent_poker_card")
        card:SetParent(self)
        if !communityCard then card:SetOwner(Entity(self.players[p].ind)) else card:SetOwner(self) end
        card:Spawn()
        card:Activate()

        if !communityCard then
            key = #self.decks[p] + 1
            self.decks[p][key] = {
                ind = card:EntIndex()
            }
        else
            key = #self.communityDeck + 1
            self.communityDeck[key] = {
                ind = card:EntIndex(),
                reveal = false
            }
        end
    else //We refer to an existing card by key
        if !communityCard then card = Entity(self.decks[p][key].ind) else card = Entity(self.communityDeck[key].ind) end
    end

    local tab
    if !communityCard then tab = self.decks[p][key] else tab = self.communityDeck[key] end

    //Now we assign it a suit and rank
    local suit, rank

    repeat
        suit = math.random(0,3)
        rank = math.random(0,12)

        if self.deck[suit][rank] then
            tab.suit = suit
            tab.rank = rank
        end
    until self.deck[suit][rank]

    self.deck[suit][rank] = false

    //And now we send the deck to the local player
    if !communityCard then
        local ply = Entity(self.players[p].ind)

        if IsValid(ply) and ply:IsPlayer() then
            net.Start("gpoker_sendDeck")
                net.WriteEntity(self)
                net.WriteBool(false)
                net.WriteTable(self.decks[p])
            net.Send(ply)
        end
    end
end



//We update player(s) deck
function ENT:updateDecksPositioning(key)
    key = key or nil //If we have a key, then we only position the deck of a certain player, 0 means we position COMMUNITY DECK

    local startAngPos = 0
    local radius = 30

    if key != 0 then
        for i = 1, #self.players do
            if (key != nil and i == key) or (key == nil) then
                local ang = startAngPos - (360 / #self.players) * (i - 1)

                ang = math.rad(ang)
                local x = math.cos(ang) * radius
                local y = math.sin(ang) * radius

                local deckCenter = Vector(x, y, 39) --That's the center of our deck

                for k,v in pairs(self.decks[i]) do
                    local angOff = -15
                    local cardAng = (startAngPos - 180 - (360 / #self.players) * (i - 1)) + angOff * (k - (math.Round(#self.decks[i] / 2)))

                    local angle = Angle(0, cardAng, 180)

                    cardAng = math.rad(cardAng)
                    local cardX = math.cos(cardAng) * 5 + deckCenter.x
                    local cardY = math.sin(cardAng) * 5 + deckCenter.y

                    local position = Vector(cardX, cardY, deckCenter.z + 0.05 * (k - 1))

                    if v.ind and IsValid(Entity(v.ind)) then
                        local card = Entity(v.ind)
                        card:SetLocalPos(position)
                        card:SetLocalAngles(angle)
                    end
                end
            end
        end
    else
        for i = 1, gPoker.gameType[self:GetGameType()].cardCommNum do
            local dealer = self:GetDealer() --We position the community cards infront of the dealer
            
            local ang = startAngPos - (360 / #self.players) * (dealer - 1)

            ang = math.rad(ang)
            local x = math.cos(ang) * (radius/2)
            local y = math.sin(ang) * (radius/2)

            local deckCenter = Vector(x, y, 39)

            for k,v in pairs(self.communityDeck) do
                local card = Entity(v.ind)

                if !IsValid(card) then return end

                local angle = startAngPos - 180 - (360 / #self.players) * (dealer - 1)
                angle = Angle(0, angle, 180)

                local ang = startAngPos - (360 / #self.players) * (dealer - 1)      +       90

                ang = math.rad(ang)
                local x = math.cos(ang)
                local y = math.sin(ang)

                local dir = Vector(x, y, 0) * 5

                local position = deckCenter + dir * (k - 1)
                position = position - (dir * (#self.communityDeck - 1))/2

                card:SetLocalPos(position)
                card:SetLocalAngles(angle)
            end
        end
    end
end



//Welp, time to gamble away all those precious smackaroos
function ENT:bettingRound()
    self:SetCheck(true)
    self:SetBet(0)
    for k,v in pairs(self.players) do
        if not v.fold then
            v.ready = false
            v.paidBet = 0
        end
    end
    self:updatePlayersTable()
    self:SetTurn(0)
    self:nextTurn()
end

//Called after player choosed an action
function ENT:proceed()
    //We check if there is only one player not folded
    local foldCount = 0

    for k,v in pairs(self.players) do
        if v.fold then foldCount = foldCount + 1 end
    end

    if foldCount >= #self.players - 1 then
        for k,v in pairs(gPoker.gameType[self:GetGameType()].states) do
            if v.final then 
                self:SetGameState(k)
                v.func(self)
                return
            end
        end
    end

    //We check if all players are ready, then we can move on
    local allRdy = true

    for k,v in pairs(self.players) do
        if !v.ready then allRdy = false break end
    end

    if allRdy then
        self:nextState()
        return
    end

    self:nextTurn()
end



function ENT:drawingRound()
    for k,v in pairs(self.players) do
        if not v.fold then
            v.ready = false
        end
    end
    self:updatePlayersTable()
    self:SetTurn(0)
    self:nextTurn()
end

//Reveals the community card(s), argument is either a table (multiple cards) or number (single card) 
function ENT:revealCommunityCards(cards)
    local revealTime = 0.5
    local multiple = istable(cards)

    local finishReveal
    if multiple then finishReveal = revealTime * #cards else finishReveal = revealTime end

    if multiple then
        for k, v in pairs(cards) do
            timer.Simple(revealTime * (k-1), function()
                if !IsValid(self) then return end
                if self:GetGameState() < 1 then return end

                local card = Entity(self.communityDeck[v].ind)

                if IsValid(card) then
                    local ang = card:GetLocalAngles()
                    card:SetLocalAngles(Angle(ang.p,ang.y,0))
                    card:SetLocalPos(card:GetLocalPos() * 0.98)

                    card:SetRank(self.communityDeck[v].rank)
                    card:SetSuit(self.communityDeck[v].suit)

                    self.communityDeck[v].reveal = true
    
                    sound.Play("gpoker/cardthrow.wav", self:GetPos())

                    local clientCopy = table.Copy(self.communityDeck)
                    for i = #clientCopy, 1, -1 do
                        if !clientCopy[i].reveal then table.remove(clientCopy, i) end
                    end

                    for k,v in pairs(self.players) do
                        net.Start("gpoker_sendDeck", false)
                            net.WriteEntity(self)
                            net.WriteBool(true)
                            net.WriteTable(clientCopy)
                        net.Send(Entity(v.ind))
                    end
                end
            end)
        end
    else
        local card = Entity(self.communityDeck[cards].ind)

        if IsValid(card) then
            local ang = card:GetLocalAngles()
            ang:RotateAroundAxis(ang:Forward(), 180)
            card:SetLocalAngles(ang)
            card:SetLocalPos(card:GetLocalPos() * 0.98)

            card:SetRank(self.communityDeck[cards].rank)
            card:SetSuit(self.communityDeck[cards].suit)

            self.communityDeck[cards].reveal = true

            sound.Play("gpoker/cardthrow.wav", self:GetPos())

            local clientCopy = table.Copy(self.communityDeck)
            for i = #clientCopy, 1, -1 do
                if !clientCopy[i].reveal then table.remove(clientCopy, i) end
            end

            for k,v in pairs(self.players) do
                net.Start("gpoker_sendDeck", false)
                    net.WriteEntity(self)
                    net.WriteBool(true)
                    net.WriteTable(clientCopy)
                net.Send(Entity(v.ind))
            end
        end
    end

    timer.Simple(finishReveal + revealTime, function()
        if !IsValid(self) then return end
        if self:GetGameState() < 1 then return end

        self:nextState()
    end)
end



//Reveal all cards
function ENT:revealCards()
    local textTime = 1
    local revealTime = 0.5
    local nextReveal = revealTime * gPoker.gameType[self:GetGameType()].cardNum + textTime

    //Sort folded and not-folded players into seperate tables
    local revealingPlayers = {}
    local foldedPlayers = {}

    for k,v in pairs(self.players) do
        if v.fold then foldedPlayers[#foldedPlayers + 1] = k else revealingPlayers[#revealingPlayers + 1] = k end 
    end



    for k, v in pairs(revealingPlayers) do
        timer.Simple(nextReveal * (k - 1), function()
            if !IsValid(self) then return end
            if self:GetGameState() < 1 then return end

            self:SetWinner(v)

            for deckK, deckV in pairs(self.decks[v]) do
                timer.Simple(revealTime * (deckK - 1), function()
                    if !IsValid(self) then return end
                    if self:GetGameState() < 1 then return end

                    local card = Entity(deckV.ind)

                    card:SetSuit(deckV.suit)
                    card:SetRank(deckV.rank)

                    local ang = card:GetLocalAngles()
                    ang:RotateAroundAxis(ang:Forward(), 180)
                    card:SetLocalAngles(ang)
                    card:SetLocalPos(card:GetLocalPos() * 0.98)

                    sound.Play("gpoker/cardthrow.wav", self:GetPos())
                end)
            end

            timer.Simple(revealTime * (gPoker.gameType[self:GetGameType()].cardNum - 1), function()
                if !IsValid(self) then return end
                if self:GetGameState() < 1 then return end
                
                local cards = table.Copy(self.decks[v])
                for k,v in pairs(self.communityDeck) do
                    if v.reveal then cards[#cards + 1] = v end
                end

                local st, vl = self:getDeckValue(cards)

                self.players[v].strength = st
                self.players[v].value = vl

                self:updatePlayersTable()
            end)
        end)
    end



    //Folded reveal cards at the same time at the end
    timer.Simple(nextReveal * #revealingPlayers, function()
        if !IsValid(self) then return end
        if self:GetGameState() < 1 then return end

        for k,v in pairs(foldedPlayers) do
            for deckK, deckV in pairs(self.decks[v]) do
                timer.Simple(revealTime/2 * (deckK - 1), function()
                    if !IsValid(self) then return end
                    if self:GetGameState() < 1 then return end

                    local card = Entity(deckV.ind)

                    card:SetSuit(deckV.suit)
                    card:SetRank(deckV.rank)

                    local ang = card:GetLocalAngles()
                    ang:RotateAroundAxis(ang:Forward(), 180)
                    card:SetLocalAngles(ang)
                    card:SetLocalPos(card:GetLocalPos() * 0.98)

                    sound.Play("gpoker/cardthrow.wav", self:GetPos(), 60)
                end)
            end

            timer.Simple(revealTime/2 * (gPoker.gameType[self:GetGameType()].cardNum - 1), function()
                if !IsValid(self) then return end
                if self:GetGameState() < 1 then return end

                local cards = table.Copy(self.decks[v])
                for k,v in pairs(self.communityDeck) do
                    if v.reveal then cards[#cards + 1] = v end
                end

                local st, vl = self:getDeckValue(cards)

                self.players[v].strength = st
                self.players[v].value = vl

                self:updatePlayersTable()
            end)
        end
    end)

    //Proceed
    local proceedTime = nextReveal * #revealingPlayers
    if #foldedPlayers > 0 then proceedTime = proceedTime + nextReveal - textTime end

    timer.Simple(proceedTime, function()
        if !IsValid(self) then return end
        if self:GetGameState() < 1 then return end

        self:nextState()
    end)
end



function ENT:finishRound()
    self:SetWinner(0)

    sound.Play("garrysmod/content_downloaded.wav", self:GetPos())

    for k,v in pairs(self.players) do
        if not v.fold then
            v.ready = false
        end
    end

    local deckValues = {}

    for k,v in pairs(self.players) do
        if v.fold then continue end

        deckValues[#deckValues + 1] = {strength = v.strength, value = v.value, ply = k}
    end

    table.sort(deckValues, function(a,b) return a.strength > b.strength end)

    local winner = deckValues[1].ply
    local strength = deckValues[1].strength
    local value = deckValues[1].value

    if #deckValues > 1 and deckValues[1].strength == deckValues[2].strength then
        local highStrength = deckValues[1].strength
        local sameStrength = {}

        for k,v in pairs(deckValues) do
            if v.strength == highStrength then sameStrength[k] = v end
        end

        table.sort(sameStrength, function(a,b) return a.value > b.value end)

        winner = sameStrength[1].ply
        strength = sameStrength[1].strength
        value = sameStrength[1].value

        if #sameStrength > 1 and sameStrength[1].value == sameStrength[2].value then
            local final = {}
            local highValue = sameStrength[1].value

            for k,v in pairs(sameStrength) do
                if v.value == highValue then 
                    local points = 0
                    for _, val in pairs(self.decks[v.ply]) do
                        points = points + (val.rank + 1)     
                    end

                    ind = #final + 1
                    final[ind] = v
                    final[ind].pt = points
                end
            end

            table.sort(final, function(a,b) return a.pt > b.pt end)

            winner = final[1].ply
            strength = final[1].strength
            value = final[1].value
        end
    end

    self:SetWinner(winner)

    timer.Simple(8, function()
        if !IsValid(self) then return end

        if self.players[winner] then gPoker.betType[self:GetBetType()].add(Entity(self.players[winner].ind), self:GetPot(), self) end

        self:SetBet(0)

        local i = 0
        local losers = {}

        for k,v in pairs(self.players) do
            if gPoker.betType[self:GetBetType()].get(Entity(v.ind)) < self:GetEntryBet() then losers[#losers + 1] = Entity(v.ind) end
        end

        for k,v in pairs(losers) do
            self:removePlayerFromMatch(v)
        end

        self:prepareForRestart()
    end)
end



function ENT:removePlayerFromMatch(ply)

    local key = self:getPlayerKey(ply)

    if key == nil then 
        return 
    end

    local chair = ply:GetVehicle()
    ply:ExitVehicle()

    if IsValid(chair) then 
        chair:Remove() 
    end

    for k,v in pairs(self.decks[key]) do
        if IsValid(Entity(v.ind)) then 
            Entity(v.ind):Remove() 
        end
    end

    table.remove(self.players, key)
    table.remove(self.decks, key)
    ply:SetNWEntity("gpoker_table", nil)

    self:updateSeatsPositioning()
    self:updateDecksPositioning()
    self:updatePlayersTable()

    if self:GetTurn() == key and #self.players > 0 then
        self:nextTurn()
    end

    if self:GetDealer() == key and #self.players > 0 then
        self:nextDealer()
    else
        self:SetDealer(self:GetDealer())
    end

    if #self.players <= 1 then 
        //Give last player the smackaroos if there is any
        if #self.players > 0 then
            for k,v in pairs(self.players) do
                gPoker.betType[self:GetBetType()].add(Entity(self.players[k].ind), self:GetPot(), self) 
                self:removePlayerFromMatch(Entity(self.players[k].ind))
                break
            end
        end
        self:prepareForRestart() 
    end
end

//Prepare the game for another round
function ENT:prepareForRestart()
    if timer.Exists("gpoker_intermission" .. self:EntIndex()) then 
        timer.Remove("gpoker_intermission" .. self:EntIndex()) 
    end

    if timer.Exists("gpoker_finishDealingCards" .. self:EntIndex()) then 
        timer.Remove("gpoker_finishDealingCards" .. self:EntIndex()) 
    end

    if timer.Exists("gpoker_dealCards" .. self:EntIndex()) then
        timer.Remove("gpoker_dealCards" .. self:EntIndex()) 
    end

    self:SetWinner(0)
    self:SetTurn(0)
    self:SetBet(0)
    self:SetPot(0)
    self:SetCheck(true)

    for k,v in pairs(self.players) do
        v.strength = nil
        v.value = nil

        self.decks[k] = {}
    end
    self.deck = {}
    self.communityDeck = {}

    local cards = ents.FindByClassAndParent("ent_poker_card", self)
    if cards then
        for k,v in pairs(cards) do
            v:Remove()
        end
    end

    if (self:getPlayersAmount() > 1) or (self:getPlayersAmount() > 0) then self:SetGameState(0) else
        if self:getPlayersAmount() > 0 then
            for k,v in pairs(self.players) do
                self:removePlayerFromMatch(Entity(v.ind))
            end
        end
        self:SetGameState(-1) 
        for k,v in pairs(self.players) do
            gPoker.betType[self:GetBetType()].call(self, Entity(v.ind))
        end
    end
end