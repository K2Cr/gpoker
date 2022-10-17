surface.CreateFont("gpoker_header", {
    font = "Arial",
	extended = false,
	size = 24,
	weight = 1000,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = true,
	additive = false,
	outline = false,
})

surface.CreateFont("gpoker_text", {
    font = "Arial",
	extended = false,
	size = 16,
	weight = 500,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = true,
	additive = false,
	outline = false,
})

surface.CreateFont("gpoker_bold", {
    font = "Arial",
	extended = false,
	size = 16,
	weight = 800,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = true,
	additive = false,
	outline = false,
})



net.Receive("gpoker_derma_createGame", function()
    local winW, winH = 384, 216
    local win = vgui.Create("DFrame")
    win:SetSize(winW, winH)
    win:Center()
    win:SetTitle("Select Game Settings")
    win:SetDraggable(false)
    win:MakePopup()


    //The left twix//


    local left = vgui.Create("DPanel", win)
    left:SetSize(win:GetWide() * 0.25 - 15)
    left:Dock(LEFT)

    local optionsMenu = vgui.Create("DCategoryList", left)
    optionsMenu:Dock(FILL)
    optionsMenu:DockMargin(2, 2, 2, 2)

    local options = optionsMenu:Add("Settings")

    local gameOption = options:Add("Game")
    local betOption = options:Add("Betting")

    local createButton = vgui.Create("DButton", left)
    createButton:Dock(BOTTOM)
    createButton:DockMargin(2, 2, 2, 2)
    createButton:SetText("Create")
    createButton:SetTall(createButton:GetWide())


    //The right twix//


    local right = vgui.Create("DPanel", win)
    right:SetSize(win:GetWide() - left:GetWide() - 15)
    right:Dock(RIGHT)

    //Game

    local gamePanel = vgui.Create("DPanel", right)
    gamePanel:Dock(FILL)

    local gameSelectText = vgui.Create("DLabel", gamePanel)
    gameSelectText:SetColor(color_black)
    gameSelectText:SetText("Game Type")
    gameSelectText:Dock(TOP)
    gameSelectText:DockMargin(10,0,10,0)

    local gameSelect = vgui.Create("DComboBox", gamePanel)
    gameSelect:Dock(TOP)
    gameSelect:DockMargin(10,0,10,0)
    for i = 0, #gPoker.gameType do
        gameSelect:AddChoice(gPoker.gameType[i].name, i, i == 0)
    end

    local maxPlyText = vgui.Create("DLabel", gamePanel)
    maxPlyText:Dock(TOP)
    maxPlyText:DockMargin(10,10,10,0)
    maxPlyText:SetTextColor(color_black)
    maxPlyText:SetText("Maximum amount of players")

    local maxPly = vgui.Create("DNumberWang", gamePanel)
    maxPly:Dock(TOP)
    maxPly:DockMargin(10,0,10,0)
    maxPly:SetMinMax(2, 8)
    maxPly:SetValue(4)

    //Betting

    local betPanel = vgui.Create("DPanel", right)
    betPanel:Dock(FILL)
    betPanel:Hide()

    local betText = vgui.Create("DLabel", betPanel)
    betText:Dock(TOP)
    betText:DockMargin(10,0,10,0)
    betText:SetTextColor(color_black)
    betText:SetText("Bet Type")

    local betSelect = vgui.Create("DComboBox", betPanel)
    betSelect:Dock(TOP)
    betSelect:DockMargin(10,0,10,0)
    for i = 0, #gPoker.betType do
        betSelect:AddChoice(gPoker.betType[i].name, i, i == 0)
    end

    local entryFee = vgui.Create("DNumSlider", betPanel)
    entryFee:Dock(TOP)
    entryFee:DockMargin(10,10,10,0)
    entryFee:SetText("Entry Fee")
    entryFee:SetDark(true)
    entryFee:SetDecimals(0)

    local startValue = vgui.Create("DNumSlider", betPanel)
    startValue:Dock(TOP)
    startValue:DockMargin(10,10,10,0)
    startValue:SetText("Starting Value")
    startValue:SetDark(true)
    startValue:SetDecimals(0)
    startValue:SetMinMax(gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID()) or 0].setMinMax.min, gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID()) or 0].setMinMax.max)
    startValue:SetValue(startValue:GetMax()/10)

    if !gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID())].canSet then startValue:Hide() end

    entryFee:SetMinMax(0, gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID())].feeMinMax.max(startValue))
    if entryFee:GetMax() < 0 then entryFee:SetMax(0) end
    entryFee:SetValue(entryFee:GetMax() / 10)

    startValue.OnValueChanged = function()
        entryFee:SetMax(startValue:GetValue())
        if entryFee:GetValue() > startValue:GetValue() then entryFee:SetValue(startValue:GetValue()) end
    end

    betSelect.OnSelect = function()
        startValue:SetMinMax(gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID())].setMinMax.min, gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID())].setMinMax.max)

        if gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID())].canSet then 
            startValue:Show() 
        else startValue:Hide() end

        entryFee:SetMinMax(gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID())].feeMinMax.min, gPoker.betType[betSelect:GetOptionData(betSelect:GetSelectedID())].feeMinMax.max(startValue))
        if entryFee:GetValue() > entryFee:GetMax() then entryFee:SetValue(entryFee:GetMax()) end
        entryFee:SetValue(entryFee:GetMax() / 10)
    end

    gameOption.DoClick = function()
        gamePanel:Show()
        betPanel:Hide()
    end

    betOption.DoClick = function()
        gamePanel:Hide()
        betPanel:Show()
    end

    createButton.DoClick = function()

        local options = {
            game = {
                type    = gameSelect:GetOptionData(gameSelect:GetSelectedID()) or 0,
                maxPly  = math.Clamp(maxPly:GetValue(), 2, 8) 
            },
            bet = {
                type = betSelect:GetOptionData(betSelect:GetSelectedID()) or 0,
                entry = math.floor(entryFee:GetValue()),
                start = math.floor(startValue:GetValue()) or 0
            },
        }

        net.Start("gpoker_derma_createGame")
            net.WriteTable(options)
        net.SendToServer()

        win:Remove()
    end
end)



net.Receive("gpoker_updatePlayers", function()
    local ent = net.ReadEntity()

    if !IsValid(ent) then return end

    ent.players = net.ReadTable()
end)



net.Receive("gpoker_sendDeck", function()
    local ent = net.ReadEntity()
    local community = net.ReadBool()
    local deck = net.ReadTable()

    if community then
        ent.communityDeck = deck
    else
        ent.localDeck = deck
    end
end)



net.Receive("gpoker_payEntry", function()
    local ent = net.ReadEntity()

    if !IsValid(ent) then return else ent:openEntryFeeDerma() end
end)



net.Receive("gpoker_derma_bettingActions", function()
    local ent = net.ReadEntity()

    if !IsValid(ent) then return end
    local check = net.ReadBool()
    local bet = net.ReadFloat()

    ent:openBettingDerma(check, bet)
end)



net.Receive("gpoker_derma_exchange", function()
    local ent = net.ReadEntity()

    if !IsValid(ent) then return end
    ent:openExchangeDerma()
end)



hook.Add("KeyPress", "gpoker_leaveRequest", function(ply, key)
    if key == IN_USE and ply:InVehicle() and ply:GetVehicle():GetVehicleClass() == "Chair_Office2" and IsValid(ply:GetVehicle():GetParent()) and ply:GetVehicle():GetParent():GetClass() == "ent_poker_game" then
        if LocalPlayer() == ply then ply:GetVehicle():GetParent():openLeaveRequest() end
    end
end)