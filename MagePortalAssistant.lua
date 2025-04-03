-- Mage Portal Assistant for Turtle Wow (1.12 client)
-- Version 4.4.4 - Tracks party joins but still requires /portal to cast

MPA = {
    version = "4.4.4",
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
        -- Destination synonyms and common misspellings
        destinationAliases = {
            ["undercity"] = {"uc", "under", "underc", "undercit", "undercityy", "undercityyy", "udercity", "undercitty"},
            ["orgrimmar"] = {"org", "og", "orgri", "orgrim", "orgrimar", "orgrimmr", "orgrimar", "orgrimma", "orgimmar", "orgimmar"},
            ["thunder bluff"] = {"tb", "tbluff", "thunder", "bluff", "thunderbluff", "thunder bluf", "thunder blu", "thunderb", "thundr bluff", "thunder bloff"}
        },
        cooldownTime = 60, -- 60 seconds cooldown between portals for same player
        chatCooldown = 10  -- 10 seconds cooldown between identical chat messages
    },
    debug = true,
    portalRequests = {}, -- Table to track all active portal requests
    playerCooldowns = {}, -- Table to track player cooldowns
    lastChatMessages = {}, -- Table to track last chat messages and their timestamps
    currentPortalTarget = nil -- Tracks who we're currently portaling
}

-- Load saved settings
if MPASettings then
    for k,v in pairs(MPASettings) do
        MPA.settings[k] = v
    end
else
    MPASettings = MPA.settings
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

-- Helper function to check for destination matches
local function matchDestination(message)
    message = string.lower(message)
    
    -- First check for invalid destinations
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
            return nil -- Return nil immediately for invalid destinations
        end
    end
    
    -- Then check exact matches
    for dest in pairs(MPA.settings.portalSpells) do
        if string.find(message, dest) then
            return dest
        end
    end
    
    -- Then check aliases
    for dest, aliases in pairs(MPA.settings.destinationAliases) do
        for _, alias in ipairs(aliases) do
            if string.find(message, alias) then
                return dest
            end
        end
    end
    
    return nil
end

local function OnEvent()
    if not MPA.settings.enabled then return end
    
    if event == "TRADE_ACCEPT_UPDATE" then
        -- Both player and target have accepted the trade
        if arg1 == 1 and arg2 == 1 then
            local msg = "Thanks for the tip!!"
            if canSendMessage(msg, "PARTY") then
                SendChatMessage(msg, "PARTY")
            end
        end
        return
    end
    
    if event == "PARTY_MEMBERS_CHANGED" then
        -- Check if any invited players have joined the party
        for playerName, request in pairs(MPA.portalRequests) do
            if not request.inParty then
                -- Check if player is now in party
                for i = 1, GetNumPartyMembers() do
                    if UnitName("party"..i) == playerName then
                        request.inParty = true
                        
                        if MPA.debug then
                            local msg = "MPA Debug: "..playerName.." has joined the party"
                            if canSendMessage(msg) then
                                DEFAULT_CHAT_FRAME:AddMessage(msg)
                            end
                        end
                        
                        -- Notify player they're ready for portal (but don't cast automatically)
                        if request.destination then
                            --local msg = playerName..", type /portal when you're ready for your "..request.destination.." portal!"
                            if canSendMessage(msg, "PARTY") then
                                SendChatMessage(msg, "PARTY")
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
        
        -- Check if player is on cooldown
        if MPA.playerCooldowns[playerName] and (GetTime() - MPA.playerCooldowns[playerName] < MPA.settings.cooldownTime) then
            local remaining = math.floor(MPA.settings.cooldownTime - (GetTime() - MPA.playerCooldowns[playerName]))
            local msg = "Please wait "..remaining.." more seconds before requesting another portal."
            if canSendMessage(msg, "WHISPER") then
                SendChatMessage(msg, "WHISPER", nil, playerName)
            end
            return
        end
        
        -- First check if this is a portal request
        if isPortalRequest(message) then
            -- Check for destination in the initial message
            local dest = matchDestination(message)
            
            -- If destination was specified but not valid, ignore the request
            if dest == nil and string.find(message, "port") then
                -- Check if any invalid destination was mentioned
                local invalidDestFound = false
                local words = {}
                for word in string.gfind(message, "%a+") do
                    word = string.lower(word)
                    -- If word looks like a potential destination but not in our list
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
                    return -- Ignore the request completely
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
            
            -- Initialize or update this player's request
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
        
        -- Check if we have a request from this player
        if MPA.portalRequests[playerName] and not MPA.portalRequests[playerName].completed then
            -- Mark that they're now in party (if not already marked)
            MPA.portalRequests[playerName].inParty = true
            
            -- Check if player is on cooldown
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
                --local msg = "Ok, "..dest.."! Type /portal when ready."
                if canSendMessage(msg, "PARTY") then
                    SendChatMessage(msg, "PARTY")
                end
            else
                -- Unknown destination requested
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
    end
end

local function PortalCommand()
    -- Unconditionally accept trades
    AcceptTrade()
    
    -- First check if we're currently handling a portal
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
    
    -- Find the next player who needs a portal
    local nextPlayer = nil
    for playerName, request in pairs(MPA.portalRequests) do
        if request.destination and not request.completed and request.inParty then
            nextPlayer = playerName
            break
        end
    end
    
    if not nextPlayer then
        -- Check party members for new requests
        if GetNumPartyMembers() == 0 then
            local msg = "You need to be in a party first."
            if canSendMessage(msg) then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
            return
        end
        
        -- Check the last party member
        local lastMember = UnitName("party"..GetNumPartyMembers())
        
        -- Check if player is on cooldown
        if MPA.playerCooldowns[lastMember] and (GetTime() - MPA.playerCooldowns[lastMember] < MPA.settings.cooldownTime) then
            local remaining = math.floor(MPA.settings.cooldownTime - (GetTime() - MPA.playerCooldowns[lastMember]))
            local msg = lastMember.." must wait "..remaining.." more seconds before requesting another portal."
            if canSendMessage(msg) then
                DEFAULT_CHAT_FRAME:AddMessage(msg)
            end
            return
        end
        
        -- Initialize a new request for this player
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
    
    -- We have a player who needs a portal
    local request = MPA.portalRequests[nextPlayer]
    MPA.currentPortalTarget = nextPlayer
    
    local spellName = MPA.settings.portalSpells[request.destination]
    if spellName then
        local msg = "Enjoy your travel to "..request.destination.."!!"
        if canSendMessage(msg) then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
        
        -- Send final notification to player
        if canSendMessage(msg, "WHISPER") then
            SendChatMessage(msg, "WHISPER", nil, nextPlayer)
        end
        
        -- Set cooldown for this player
        MPA.playerCooldowns[nextPlayer] = GetTime()
        
        CastSpellByName(spellName)
        
        -- Mark request as completed
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
    else
        -- If no recognized command, treat as portal request
        PortalCommand()
    end
end

-- Initialize
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:SetScript("OnEvent", OnEvent)

SLASH_MPA1 = "/mpa"
SlashCmdList["MPA"] = SlashHandler

SLASH_PORTAL1 = "/portal"
SlashCmdList["PORTAL"] = PortalCommand

local msg1 = "MagePortalAssistant "..MPA.version.." loaded. Commands:"
local msg2 = "/mpa on|off - Toggle addon"
local msg3 = "/mpa debug on|off - Toggle debug"
local msg4 = "/portal - Ask party member where to portal"

if canSendMessage(msg1) then DEFAULT_CHAT_FRAME:AddMessage(msg1) end
if canSendMessage(msg2) then DEFAULT_CHAT_FRAME:AddMessage(msg2) end
if canSendMessage(msg3) then DEFAULT_CHAT_FRAME:AddMessage(msg3) end
if canSendMessage(msg4) then DEFAULT_CHAT_FRAME:AddMessage(msg4) end