-- Mage Portal Assistant for Turtle Wow (1.12 client)
-- Version 4.5.4 - Wider frame (900px), Clear All button, full message display

MPA = {
    version = "4.5.4",
    settings = {
        enabled = true,
        keywords = {
            "port", "portal", "teleport", "mage port", "mage portal",
            "can i get a port", "need a port", "stonard", "can you port"
        },
        portalSpells = {
            ["undercity"] = "Portal: Undercity",
            ["orgrimmar"] = "Portal: Orgrimmar",
            ["stonard"] = "Portal: Stonard",
            ["thunder bluff"] = "Portal: Thunder Bluff"
        },
        destinationAliases = {
            ["undercity"] = {"uc", "under", "underc", "undercit", "undercityy", "undercityyy", "udercity", "undercitty"},
            ["orgrimmar"] = {"org", "og", "orgri", "orgrim", "orgrimar", "orgrimmr", "orgrimar", "orgrimma", "orgimmar", "orgimmar"},
            ["stonard"] = {"stonerd", "stonart", "stobard", "stonarf", "stonar", "stonardd", "stanard", "sunken temple"},
            ["thunder bluff"] = {"tb", "tbluff", "thunder", "bluff", "thunderbluff", "thunder bluf", "thunder blu", "thunderb", "thundr bluff", "thunder bloff"}
        },
        cooldownTime = 60,
        chatCooldown = 10
    },
    debug = false,
    portalRequests = {},
    playerCooldowns = {},
    lastChatMessages = {},
    currentPortalTarget = nil,
    portalChatLog = {},
    chatFrame = nil,
    chatFrameCreated = false
}

if MPASettings then
    for k,v in pairs(MPASettings) do
        MPA.settings[k] = v
    end
else
    MPASettings = MPA.settings
end

local function UpdateChatDisplay()
    if not MPA.chatFrame or not MPA.chatFrame:IsShown() then return end
    
    local scrollChild = MPA.chatFrame.scrollChild
    local scrollFrame = MPA.chatFrame.scrollFrame
    
    local children = {scrollChild:GetChildren()}
    for i=1, table.getn(children) do
        children[i]:Hide()
    end
    
    local totalHeight = 0
    local entryHeight = 40
    
    if table.getn(MPA.portalChatLog) == 0 then
        local noEntriesText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noEntriesText:SetPoint("CENTER", scrollChild, "CENTER", 0, 0)
        noEntriesText:SetText("")
        noEntriesText:SetTextColor(1, 1, 1)
        totalHeight = entryHeight
    else
        for i=1, table.getn(MPA.portalChatLog) do
            local entry = MPA.portalChatLog[i]
            local entryFrame = getglobal("MPAChatEntry"..i) or CreateFrame("Frame", "MPAChatEntry"..i, scrollChild)
            entryFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i-1)*entryHeight))
            entryFrame:SetWidth(860)
            entryFrame:SetHeight(entryHeight)
            
            if not entryFrame.initialized then
                local nameText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                nameText:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 5, -5)
                nameText:SetWidth(120)
                nameText:SetJustifyH("LEFT")
                nameText:SetTextColor(1, 0.82, 0)
                entryFrame.nameText = nameText
                
                local msgText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                msgText:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
                msgText:SetWidth(500)
                msgText:SetJustifyH("LEFT")
                msgText:SetTextColor(1, 1, 1)
                entryFrame.msgText = msgText
                
                local whisperButton = CreateFrame("Button", nil, entryFrame, "UIPanelButtonTemplate")
                whisperButton:SetPoint("LEFT", msgText, "RIGHT", -35, 0)
                whisperButton:SetWidth(70)
                whisperButton:SetHeight(20)
                whisperButton:SetText("Whisper")
                whisperButton.playerToWhisper = entry.player
                
                whisperButton:SetScript("OnClick", function()
                    local playerName = this.playerToWhisper
                    ChatFrame_OpenChat("/w "..playerName.." ", DEFAULT_CHAT_FRAME)
                    if MPA.debug then
                        DEFAULT_CHAT_FRAME:AddMessage("MPA Debug: Whispering "..playerName)
                    end
                end)
                
                local inviteButton = CreateFrame("Button", nil, entryFrame, "UIPanelButtonTemplate")
                inviteButton:SetPoint("LEFT", whisperButton, "RIGHT", 5, 0)
                inviteButton:SetWidth(70)
                inviteButton:SetHeight(20)
                inviteButton:SetText("Invite")
                inviteButton.playerToInvite = entry.player
                inviteButton.destination = entry.destination
                
                inviteButton:SetScript("OnClick", function()
                    local playerName = this.playerToInvite
                    InviteByName(playerName)
                    
                    if this.destination then
                        MPA.portalRequests[playerName] = {
                            player = playerName,
                            destination = this.destination,
                            thanked = false,
                            completed = false,
                            inParty = false
                        }
                        
                        if MPA.debug then
                            local msg = "MPA Debug: Pre-set destination "..this.destination.." for "..playerName
                            if canSendMessage(msg) then
                                DEFAULT_CHAT_FRAME:AddMessage(msg)
                            end
                        end
                    end
                    
                    if MPA.debug then
                        DEFAULT_CHAT_FRAME:AddMessage("MPA Debug: Invited "..playerName.." from chat log")
                    end
                end)
                
                entryFrame.initialized = true
            else
                entryFrame.nameText:SetText(entry.player)
                entryFrame.msgText:SetText(entry.message)
                for _, child in ipairs({entryFrame:GetChildren()}) do
                    if child:GetObjectType() == "Button" then
                        if child:GetText() == "Invite" then
                            child.playerToInvite = entry.player
                            child.destination = entry.destination
                        elseif child:GetText() == "Whisper" then
                            child.playerToWhisper = entry.player
                        end
                    end
                end
            end
            
            entryFrame:Show()
            totalHeight = i * entryHeight
        end
    end
    
    scrollChild:SetHeight(totalHeight)
    scrollFrame:SetVerticalScroll(0)
end

local function canSendMessage(message, channel)
    local now = GetTime()
    local key = message..(channel or "")
    
    if not MPA.lastChatMessages[key] or (now - MPA.lastChatMessages[key] >= MPA.settings.chatCooldown) then
        MPA.lastChatMessages[key] = now
        return true
    end
    return false
end

local function isPortalRequest(message)
    if not message then return false end
    message = string.lower(message)
    
    for _, keyword in ipairs(MPA.settings.keywords) do
        if string.find(message, string.lower(keyword)) then
            if MPA.debug then
                local msg = "MPA Debug: Matched keyword: "..keyword
                if canSendMessage(msg) then
                    DEFAULT_CHAT_FRAME:AddMessage(msg)
                end
            end
            return true
        end
    end
    return false
end

local function matchDestination(message)
    message = string.lower(message)
    
    local invalidDests = {
        "ironforge", "if", "hyjal", "stormwind", "sw", 
        "darnassus", "dar", "exodar", "shattrath", "dalaran"
    }
    
    for _, dest in ipairs(invalidDests) do
        if string.find(message, dest) then
            if MPA.debug then
                local msg = "MPA Debug: Invalid destination detected: "..dest
                if canSendMessage(msg) then
                    DEFAULT_CHAT_FRAME:AddMessage(msg)
                end
            end
            return nil
        end
    end
    
    for dest in pairs(MPA.settings.portalSpells) do
        if string.find(message, dest) then
            return dest
        end
    end
    
    for dest, aliases in pairs(MPA.settings.destinationAliases) do
        for _, alias in ipairs(aliases) do
            if string.find(message, alias) then
                return dest
            end
        end
    end
    
    return nil
end

local function CreateChatDisplayFrame()
    if MPA.chatFrame then return end
    
    local frame = CreateFrame("Frame", "MPAChatDisplayFrame", UIParent)
    frame:SetWidth(900)
    frame:SetHeight(250)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.2, 0.9)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText("Mage Portal Assistant")
    title:SetTextColor(1, 1, 1)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, 1)
    
    -- Clear button
    local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", 0, -5)
    clearButton:SetWidth(80)
    clearButton:SetHeight(20)
    clearButton:SetText("Clear All")
    clearButton:SetScript("OnClick", function()
        MPA.portalChatLog = {}
        UpdateChatDisplay()
    end)

    -- Water and Food buttons frame
    local waterFoodFrame = CreateFrame("Frame", "MPAWaterFoodFrame", frame)
    waterFoodFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    waterFoodFrame:SetWidth(150)
    waterFoodFrame:SetHeight(180)

    -- Oranges! button (Ritual of Refreshment)
    local orangesButton = CreateFrame("Button", "MPAOrangesBtn", waterFoodFrame, "UIPanelButtonTemplate")
    orangesButton:SetPoint("TOP", waterFoodFrame, "TOP", -40, -5)
    orangesButton:SetWidth(80)
    orangesButton:SetHeight(25)
    orangesButton:SetText("Oranges!")
    orangesButton:SetScript("OnClick", function()
        CastSpellByName("Ritual of Refreshment")
        SendChatMessage("BEHOLD! The Grand Buffet of the Arcane... Oranges!! ", "SAY")

    end)

    -- Column headers
    local waterHeader = waterFoodFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    waterHeader:SetPoint("TOPLEFT", waterFoodFrame, "TOPLEFT", 0, -65)
    waterHeader:SetText("Water")
    waterHeader:SetTextColor(0.5, 0.5, 1)
    
    local foodHeader = waterFoodFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    foodHeader:SetPoint("TOPLEFT", waterFoodFrame, "TOPLEFT", 80, -65)
    foodHeader:SetText("Food")
    foodHeader:SetTextColor(1, 0.5, 0.5)
    
    -- Water spells data
    local waterSpells = {
        {name = "Conjure Water(Rank 2)", level = "5"},
        {name = "Conjure Water(Rank 3)", level = "15"},
        {name = "Conjure Water(Rank 4)", level = "25"},
        {name = "Conjure Water(Rank 5)", level = "35"},
        {name = "Conjure Water(Rank 6)", level = "45"},
        {name = "Conjure Water(Rank 7)", level = "55"}
    }
    
    -- Food spells data
    local foodSpells = {
        {name = "Conjure Food(Rank 2)", level = "5"},
        {name = "Conjure Food(Rank 3)", level = "15"},
        {name = "Conjure Food(Rank 4)", level = "25"},
        {name = "Conjure Food(Rank 5)", level = "35"},
        {name = "Conjure Food(Rank 6)", level = "45"},
        {name = "Conjure Food(Rank 7)", level = "55"}
    }
    
    -- Create water buttons
    for i, spell in ipairs(waterSpells) do
        local btn = CreateFrame("Button", "MPAWaterBtn"..i, waterFoodFrame, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", waterFoodFrame, "TOPLEFT", 0, -((i)*22 + 55))
        btn:SetWidth(60)
        btn:SetHeight(20)
        btn:SetText("Lv "..spell.level)
        btn.spellName = spell.name
        btn:SetScript("OnClick", function()
            CastSpellByName(this.spellName)
        end)
    end
    
    -- Create food buttons
    for i, spell in ipairs(foodSpells) do
        local btn = CreateFrame("Button", "MPAFoodBtn"..i, waterFoodFrame, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", waterFoodFrame, "TOPLEFT", 80, -((i)*22 + 55))
        btn:SetWidth(60)
        btn:SetHeight(20)
        btn:SetText("Lv "..spell.level)
        btn.spellName = spell.name
        btn:SetScript("OnClick", function()
            CastSpellByName(this.spellName)
        end)
    end
    
    -- Scroll frame for chat messages (simplified without scroll bar)
    local scrollFrame = CreateFrame("ScrollFrame", "MPAScrollFrame", frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 170, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    
    local scrollChild = CreateFrame("Frame", "MPAScrollChild", scrollFrame)
    scrollChild:SetWidth(870)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    
    MPA.chatFrame = frame
    MPA.chatFrame.scrollFrame = scrollFrame
    MPA.chatFrame.scrollChild = scrollChild
    MPA.chatFrameCreated = true
end

local function FormatMoney(copperAmount)
    copperAmount = tonumber(copperAmount) or 0
    
    -- Calculate gold, silver, copper (without using %)
    local gold = math.floor(copperAmount / 10000)
    local remainingAfterGold = copperAmount - (gold * 10000)
    local silver = math.floor(remainingAfterGold / 100)
    local copper = remainingAfterGold - (silver * 100)
    
    -- Apply WoW's standard color codes
    local goldText = gold > 0 and "|cffffd700"..gold.."g|r" or ""
    local silverText = silver > 0 and "|cffc7c7cf"..silver.."s|r" or ""
    local copperText = copper > 0 and "|cffeda55f"..copper.."c|r" or ""
    
    -- Combine the parts (only show non-zero values)
    local result = ""
    if gold > 0 then
        result = goldText
        if silver > 0 then result = result.." "..silverText end
        if copper > 0 then result = result.." "..copperText end
    elseif silver > 0 then
        result = silverText
        if copper > 0 then result = result.." "..copperText end
    else
        result = copperText
    end
    
    return result
end

local function OnEvent()
    if not MPA.settings.enabled then return end
    if event == "TRADE_ACCEPT_UPDATE" then
        if arg1 == 1 and arg2 == 1 then
            local tradeMoney = GetTargetTradeMoney()
            if tradeMoney and tradeMoney == 0 then
                local msg = "Enjoy!"
                if canSendMessage(msg, "PARTY") then
                    SendChatMessage(msg, "PARTY")
                end
            else if tradeMoney and tradeMoney ~= 0 then
                local formattedMoney = FormatMoney(tradeMoney)
                local msg = "Cha-ching! "..formattedMoney.."! Thanks for the tip!!"
                if canSendMessage(msg, "PARTY") then
                    SendChatMessage(msg, "PARTY")
                end
            end
            end
        end
        return
    end
    
    if event == "PARTY_MEMBERS_CHANGED" then
        for playerName, request in pairs(MPA.portalRequests) do
            if not request.inParty then
                for i = 1, GetNumPartyMembers() do
                    if UnitName("party"..i) == playerName then
                        request.inParty = true
                        
                        if MPA.debug then
                            local msg = "MPA Debug: "..playerName.." has joined the party"
                            if canSendMessage(msg) then
                                DEFAULT_CHAT_FRAME:AddMessage(msg)
                            end
                        end
                        break
                    end
                end
            end
        end
        return
    end
    
    if event == "CHAT_MSG_WHISPER" then
        local message = arg1
        local playerName = arg2
        
        if MPA.debug then
            local msg = "MPA Debug: Received whisper from "..playerName..": "..message
            if canSendMessage(msg) then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
        end
        
        if MPA.playerCooldowns[playerName] and (GetTime() - MPA.playerCooldowns[playerName] < MPA.settings.cooldownTime) then
            local remaining = math.floor(MPA.settings.cooldownTime - (GetTime() - MPA.playerCooldowns[playerName]))
            --local msg = "Please wait "..remaining.." more seconds before requesting another portal."
            if canSendMessage(msg, "WHISPER") then
                SendChatMessage(msg, "WHISPER", nil, playerName)
            end
            return
        end
        
        if isPortalRequest(message) then
            local dest = matchDestination(message)
            
            if dest == nil and string.find(message, "port") then
                local invalidDestFound = false
                local words = {}
                for word in string.gfind(message, "%a+") do
                    word = string.lower(word)
                    if (word == "ironforge" or word == "hyjal" or word == "stormwind" or word == "darnassus" or 
                        word == "if" or word == "sw" or word == "dar") then
                        invalidDestFound = true
                        break
                    end
                end
                
                if invalidDestFound then
                    if MPA.debug then
                        local msg = "MPA Debug: Ignoring request from "..playerName.." - invalid destination mentioned"
                        if canSendMessage(msg) then
                            DEFAULT_CHAT_FRAME:AddMessage(msg)
                        end
                    end
                    return
                end
            end
            
            if GetNumPartyMembers() >= 4 then
                local msg = "My party is full, can't invite."
                if canSendMessage(msg, "WHISPER") then
                    SendChatMessage(msg, "WHISPER", nil, playerName)
                end
                return
            end
            
            InviteByName(playerName)
            PlaySound("PVPTHROUGHQUEUE", "Master")

            MPA.portalRequests[playerName] = {
                player = playerName,
                destination = dest,
                thanked = false,
                completed = false,
                inParty = false
            }
            
            if dest then
                local msg = "Ok, "..dest.."!"
                if canSendMessage(msg, "WHISPER") then
                    SendChatMessage(msg, "WHISPER", nil, playerName)
                end
                
                if MPA.debug then
                    local msg = "MPA Debug: Found destination in initial whisper: "..dest
                    if canSendMessage(msg) then
                        DEFAULT_CHAT_FRAME:AddMessage(msg)
                    end
                end
            else
                local msg = "Hello "..playerName.."!, where would you like to go? Undercity? Thunder Bluff? Stonard perhaps?"
                if canSendMessage(msg, "WHISPER") then
                    SendChatMessage(msg, "WHISPER", nil, playerName)
                end
            end
            
            if MPA.debug then
                local msg = "MPA Debug: Invited "..playerName
                if canSendMessage(msg) then
                    DEFAULT_CHAT_FRAME:AddMessage(msg)
                end
            end
        end
        
    elseif event == "CHAT_MSG_PARTY" then
        local message = arg1
        local playerName = arg2
        
        if MPA.portalRequests[playerName] and not MPA.portalRequests[playerName].completed then
            MPA.portalRequests[playerName].inParty = true
            
            if MPA.playerCooldowns[playerName] and (GetTime() - MPA.playerCooldowns[playerName] < MPA.settings.cooldownTime) then
                local remaining = math.floor(MPA.settings.cooldownTime - (GetTime() - MPA.playerCooldowns[playerName]))
                local msg = playerName..", please wait "..remaining.." more seconds before requesting another portal."
                if canSendMessage(msg, "PARTY") then
                    SendChatMessage(msg, "PARTY")
                end
                MPA.portalRequests[playerName] = nil
                return
            end
            
            local dest = matchDestination(message)
            if dest then
                MPA.portalRequests[playerName].destination = dest
            else
                local validDests = ""
                for dest in pairs(MPA.settings.portalSpells) do
                    if validDests ~= "" then
                        validDests = validDests .. ", "
                    end
                    validDests = validDests .. dest
                end
                local msg = "Sorry, I can't port you there. I can port to: "..validDests
                if canSendMessage(msg, "PARTY") then
                    SendChatMessage(msg, "PARTY")
                end
            end
        end
    elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
        local message = arg1
        local playerName = arg2
        if isPortalRequest(message) then
            local dest = matchDestination(message)
            table.insert(MPA.portalChatLog, 1, {
                player = playerName,
                message = message,
                destination = dest,
                timestamp = GetTime()
            })
            UpdateChatDisplay()
            PlaySound("LEVELUPSOUND", "Master")
        end

        if table.getn(MPA.portalChatLog) > 10 then
            table.remove(MPA.portalChatLog, 11)
        end
        
        if not MPA.chatFrameCreated then
            CreateChatDisplayFrame()
            MPA.chatFrameCreated = true
        end
        UpdateChatDisplay()
        
        if MPA.debug then
            local msg = "MPA Debug: Detected portal request in /say or /yell from "..playerName
            if canSendMessage(msg) then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
        end

    elseif event == "CHAT_MSG_CHANNEL" then
        local message = arg1
        local playerName = arg2
        local channelName = arg4
        if isPortalRequest(message) and strfind(channelName, "General") then
            local dest = matchDestination(message)
            table.insert(MPA.portalChatLog, 1, {
                player = playerName,
                message = message,
                destination = dest,
                timestamp = GetTime()
            })
            UpdateChatDisplay()
            PlaySound("LEVELUPSOUND", "Master")

            if table.getn(MPA.portalChatLog) > 10 then
                table.remove(MPA.portalChatLog, 11)
            end
            
            if not MPA.chatFrameCreated then
                CreateChatDisplayFrame()
                MPA.chatFrameCreated = true
            end
            UpdateChatDisplay()
            
            if MPA.debug then
                local msg = "MPA Debug: Detected portal request in channel from "..playerName
                if canSendMessage(msg) then
                    DEFAULT_CHAT_FRAME:AddMessage(msg)
                end
            end
        end
    end
end

local function PortalCommand()
    AcceptTrade()
    
    if MPA.currentPortalTarget and MPA.portalRequests[MPA.currentPortalTarget] then
        local request = MPA.portalRequests[MPA.currentPortalTarget]
        if request.completed then
            MPA.currentPortalTarget = nil
        else
            local msg = "Currently handling a portal for "..MPA.currentPortalTarget..", please wait."
            if canSendMessage(msg) then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
            return
        end
    end
    
    local nextPlayer = nil
    for playerName, request in pairs(MPA.portalRequests) do
        if request.destination and not request.completed and request.inParty then
            nextPlayer = playerName
            break
        end
    end
    
    if not nextPlayer then
        if GetNumPartyMembers() == 0 then
            local msg = "You need to be in a party first."
            if canSendMessage(msg) then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
            return
        end
        
        local lastMember = UnitName("party"..GetNumPartyMembers())
        
        if MPA.playerCooldowns[lastMember] and (GetTime() - MPA.playerCooldowns[lastMember] < MPA.settings.cooldownTime) then
            local remaining = math.floor(MPA.settings.cooldownTime - (GetTime() - MPA.playerCooldowns[lastMember]))
            local msg = lastMember.." must wait "..remaining.." more seconds before requesting another portal."
            if canSendMessage(msg) then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
            return
        end
        
        MPA.portalRequests[lastMember] = {
            player = lastMember,
            destination = nil,
            thanked = false,
            completed = false,
            inParty = true
        }
        
        local msg = lastMember..", where shall I port you? UC? TB? Stonard?"
        if canSendMessage(msg, "PARTY") then
            SendChatMessage(msg, "PARTY")
        end
        
        if MPA.debug then
            local msg = "MPA Debug: Asked "..lastMember.." for destination"
            if canSendMessage(msg) then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
        end
        return
    end
    
    local request = MPA.portalRequests[nextPlayer]
    MPA.currentPortalTarget = nextPlayer
    
    local spellName = MPA.settings.portalSpells[request.destination]
    if spellName then
        local msg = "Enjoy your travel to "..request.destination.."!!"
        if canSendMessage(msg) then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
        
        if canSendMessage(msg, "WHISPER") then
            SendChatMessage(msg, "WHISPER", nil, nextPlayer)
        end
        
        MPA.playerCooldowns[nextPlayer] = GetTime()
        
        CastSpellByName(spellName)
        
        request.completed = true
    end
end

local function SlashHandler(msg)
    msg = string.lower(msg)
    
    if msg == "on" then
        MPA.settings.enabled = true
        local msg = "MagePortalAssistant: Enabled"
        if canSendMessage(msg) then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    elseif msg == "off" then
        MPA.settings.enabled = false
        local msg = "MagePortalAssistant: Disabled"
        if canSendMessage(msg) then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    elseif msg == "debug on" then
        MPA.debug = true
        local msg = "MagePortalAssistant: Debug enabled"
        if canSendMessage(msg) then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    elseif msg == "debug off" then
        MPA.debug = false
        local msg = "MagePortalAssistant: Debug disabled"
        if canSendMessage(msg) then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    elseif msg == "show" then
        if not MPA.chatFrameCreated then
            CreateChatDisplayFrame()
            MPA.chatFrameCreated = true
        end
        MPA.chatFrame:Show()
        UpdateChatDisplay()
    elseif msg == "hide" then
        if MPA.chatFrame then
            MPA.chatFrame:Hide()
        end
    else
        PortalCommand()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("CHAT_MSG_SAY")
frame:RegisterEvent("CHAT_MSG_YELL")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:SetScript("OnEvent", OnEvent)

SLASH_MPA1 = "/mpa"
SlashCmdList["MPA"] = SlashHandler

SLASH_PORTAL1 = "/portal"
SlashCmdList["PORTAL"] = PortalCommand

local msg1 = "MagePortalAssistant "..MPA.version.." loaded. Commands:"
local msg2 = "/mpa on|off - Toggle addon"
local msg3 = "/mpa debug on|off - Toggle debug"
local msg4 = "/portal - Ask party member where to portal"
local msg5 = "/mpa show|hide - Show/hide portal request window"

if canSendMessage(msg1) then DEFAULT_CHAT_FRAME:AddMessage(msg1) end
if canSendMessage(msg2) then DEFAULT_CHAT_FRAME:AddMessage(msg2) end
if canSendMessage(msg3) then DEFAULT_CHAT_FRAME:AddMessage(msg3) end
if canSendMessage(msg4) then DEFAULT_CHAT_FRAME:AddMessage(msg4) end
if canSendMessage(msg5) then DEFAULT_CHAT_FRAME:AddMessage(msg5) end