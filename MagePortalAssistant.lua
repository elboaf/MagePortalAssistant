-- Mage Portal Assistant for Turtle Wow (1.12 client)
-- Version 4.5.4 - Wider frame (900px), Clear All button, full message display

MPA = {
    version = "4.5.4",
    settings = {
        enabled = true,
        keywords = {
            "port", "portal", "teleport", "mage port", "mage portal",
            "can i get a port", "need a port", "city port", "can you port"
        },
        portalSpells = {
            ["undercity"] = "Portal: Undercity",
            ["orgrimmar"] = "Portal: Orgrimmar",
            ["thunder bluff"] = "Portal: Thunder Bluff"
        },
        destinationAliases = {
            ["undercity"] = {"uc", "under", "underc", "undercit", "undercityy", "undercityyy", "udercity", "undercitty"},
            ["orgrimmar"] = {"org", "og", "orgri", "orgrim", "orgrimar", "orgrimmr", "orgrimar", "orgrimma", "orgimmar", "orgimmar"},
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
                msgText:SetWidth(600)
                msgText:SetJustifyH("LEFT")
                msgText:SetTextColor(1, 1, 1)
                entryFrame.msgText = msgText
                
                local inviteButton = CreateFrame("Button", nil, entryFrame, "UIPanelButtonTemplate")
                inviteButton:SetPoint("LEFT", msgText, "RIGHT", 5, 0)
                inviteButton:SetWidth(60)
                inviteButton:SetHeight(20)
                inviteButton:SetText("Invite")
                
                inviteButton.playerToInvite = entry.player
                
                inviteButton:SetScript("OnClick", function()
                    local playerName = inviteButton.playerToInvite
                    InviteByName(playerName)
                    if MPA.debug then
                        DEFAULT_CHAT_FRAME:AddMessage("MPA Debug: Invited "..playerName.." from chat log")
                    end
                end)
                
                entryFrame.initialized = true
            else
                entryFrame.nameText:SetText(entry.player)
                entryFrame.msgText:SetText(entry.message)
                for _, child in ipairs({entryFrame:GetChildren()}) do
                    if child:GetObjectType() == "Button" and child:GetText() == "Invite" then
                        child.playerToInvite = entry.player
                    end
                end
            end
            
            entryFrame:Show()
            totalHeight = i * entryHeight
        end
    end
    
    scrollChild:SetHeight(totalHeight)
    
    local scrollBar = scrollFrame.scrollBar
    scrollBar:SetMinMaxValues(0, math.max(0, totalHeight - scrollFrame:GetHeight()))
    scrollBar:SetValue(0)
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
        "ironforge", "if", "stonard", "hyjal", "stormwind", "sw", 
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
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:SetScript("OnMouseDown", function() end)
    frame:Hide()
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText("Portal Requests")
    title:SetTextColor(1, 1, 1)
    
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -90, -4)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    
    local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -5, 0)
    clearButton:SetWidth(80)
    clearButton:SetHeight(20)
    clearButton:SetText("Clear All")
    clearButton:SetScript("OnClick", function()
        MPA.portalChatLog = {}
        UpdateChatDisplay()
        if MPA.debug then
            DEFAULT_CHAT_FRAME:AddMessage("MPA Debug: Cleared all portal requests.")
        end
    end)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 8)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(870)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    
    local scrollBar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -20, -16)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -8, 16)
    scrollBar:SetMinMaxValues(0, 100)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
    scrollBar:SetWidth(16)
    
    local scrollUp = CreateFrame("Button", nil, scrollBar, "UIPanelScrollUpButtonTemplate")
    scrollUp:SetPoint("BOTTOM", scrollBar, "TOP")
    
    local scrollDown = CreateFrame("Button", nil, scrollBar, "UIPanelScrollDownButtonTemplate")
    scrollDown:SetPoint("TOP", scrollBar, "BOTTOM")
    
    scrollFrame.scrollBar = scrollBar
    frame.scrollFrame = scrollFrame
    frame.scrollChild = scrollChild
    
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = scrollBar:GetValue()
        if delta > 0 then
            scrollBar:SetValue(current - 20)
        else
            scrollBar:SetValue(current + 20)
        end
    end)
    
    scrollBar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    
    MPA.chatFrame = frame
end



local function OnEvent()
    if not MPA.settings.enabled then return end
    if event == "TRADE_ACCEPT_UPDATE" then
        if arg1 == 1 and arg2 == 1 then
            local msg = "Thanks for the tip!!"
            if canSendMessage(msg, "PARTY") then
                SendChatMessage(msg, "PARTY")
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
            local msg = "Please wait "..remaining.." more seconds before requesting another portal."
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
                    if (word == "ironforge" or word == "stonard" or word == "hyjal" or word == "stormwind" or word == "darnassus" or 
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
                local msg = playerName..", where would you like to go? Undercity? Thunder Bluff?"
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
        --local zoneID = arg7
        if isPortalRequest(message) then
            table.insert(MPA.portalChatLog, 1, {
                player = playerName,
                message = message,
                timestamp = GetTime()
            })
            UpdateChatDisplay()
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
            table.insert(MPA.portalChatLog, 1, {
                player = playerName,
                message = message,
                timestamp = GetTime()
            })
            UpdateChatDisplay()

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
        
        local msg = lastMember..", where would you like to go? Undercity? Thunder Bluff?"
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