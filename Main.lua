local addonName, GG = ...
local C = GG.Core
local M = { seen = {}, cooldown = {}, queue = {}, clock = 0 }
GG.Main = M
local incoming = {
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_COMMUNITIES_CHANNEL",
    "CHAT_MSG_BN_WHISPER",
}

function M.Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffce75GratzGuild|r  " .. tostring(message)) end
end

function M.Dirty() M.dirty = true end
function M.Now() return time and time() or 0 end
function M.Time() return GetTime and GetTime() or M.clock end

function M.CanSend()
    if not M.guild or not IsInGuild() then return false, "Join a guild to send guild chat." end
    if C_GuildInfo and C_GuildInfo.CanSpeakInGuildChat and not C_GuildInfo.CanSpeakInGuildChat() then
        return false, "Your guild rank cannot speak in guild chat."
    end
    return true
end

function M.Send(text, destination)
    local d = destination or {kind = "GUILD"}
    if d.kind == "GUILD" then local ok, reason = M.CanSend(); if not ok then return false, reason end end
    if GG.GratzButton then local ok, reason = GG.GratzButton.Validate(d); if not ok then return false, reason end end
    text = C.UTF8Cut(C.ChatText(text), 255)
    if text == "" then return false, "The message is empty." end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok, result
    if d.kind == "BN_WHISPER" then
        send = (C_BattleNet and C_BattleNet.SendWhisper) or BNSendWhisper
        if send then ok, result = pcall(send, d.target, text) end
    elseif d.kind == "COMMUNITIES_CHANNEL" then
        send = C_Club and C_Club.SendMessage
        if send then ok, result = pcall(send, d.club, d.stream, text) end
    elseif send then ok, result = pcall(send, text, d.kind, nil, d.target) end
    if not ok or result == false then return false, "Chat could not be submitted to " .. d.kind .. ": " .. tostring(result) end
    return true
end

function M.RequestRoster()
    local request = C_GuildInfo and C_GuildInfo.GuildRoster or GuildRoster
    if request and IsInGuild() then pcall(request) end
end

function M.Context()
    local name, _, _, guildRealm = GetGuildInfo("player")
    local key = name and C.GuildKey(name, guildRealm or M.realm) or nil
    if key ~= M.guildKey then
        if GG.Celebrations then GG.Celebrations.Stop() end
        if GG.GratzButton then GG.GratzButton.Clear() end
        M.queue, M.report, M.ready, M.cooldown = {}, nil, false, {}
        M.rosterDue, M.lastCapture, M.nextRoster = nil, nil, nil
        M.byGUID, M.byShort = {}, {}
        M.guild, M.guildKey = nil, key
        if name then M.guild = C.GetGuild(name, guildRealm or M.realm) end
        M.Dirty()
    end
    return M.guild
end

function M.ResolveSender(name, guid)
    if not M.guild then return end
    if guid and guid ~= "" and M.byGUID and M.byGUID[guid] then return M.byGUID[guid] end
    local key = C.NameKey(name, M.realm)
    if key and M.guild.members[key] and M.guild.members[key].active then return key end
    if name and not name:find("-", 1, true) then
        return M.byShort and M.byShort[name:lower()] or nil
    end
end

function M.IsSelf(sender, guid, key)
    if guid and guid ~= "" and (guid == M.playerGUID or C.IsOwn(nil, guid)) then return true end
    if C.IsOwn(key, guid) then return true end
    if type(sender) ~= "string" then return false end
    if C.NameKey(sender, M.playerRealm or M.realm) == M.playerKey then return true end
    return not sender:find("-", 1, true) and sender:lower() == M.playerName:lower()
end

function M.CaptureRoster()
    if M.refreshing or not M.guild or not GetNumGuildMembers or not GetGuildRosterInfo then return false end
    M.lastCapture, M.rosterDue = M.Time(), nil
    M.refreshing = true
    local previous = GetGuildRosterShowOffline and GetGuildRosterShowOffline()
    local changed = previous == false and SetGuildRosterShowOffline ~= nil
    if changed then
        -- Some clients emit roster events for local filter changes; do not rescan those in a loop.
        M.suppressRosterUntil = M.Time() + 1
        SetGuildRosterShowOffline(true)
    end
    local ok, rows = pcall(function()
        local count = GetNumGuildMembers(true) or 0
        if count == 0 then return end
        local roster, containsPlayer = {}, false
        for i = 1, count do
            local name, rank, _, level, _, _, _, _, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if not name then return end
            if C.NameKey(name, M.realm) == M.playerKey or (guid and M.playerGUID and guid == M.playerGUID) then containsPlayer = true end
            roster[#roster + 1] = { name = name, rank = rank, level = level, online = not not online, class = class, guid = guid }
        end
        if containsPlayer then return roster end
    end)
    if changed then SetGuildRosterShowOffline(previous) end
    M.refreshing = false
    if not ok or not rows then return false end
    local updated = C.UpdateRoster(M.guild, rows, M.Now())
    if not updated then return false end
    M.byGUID, M.byShort = {}, {}
    for key, member in pairs(M.guild.members) do
        if member.active then
            if member.guid and member.guid ~= "" then M.byGUID[member.guid] = key end
            local short = member.name:match("^[^-]+"):lower()
            if M.byShort[short] == nil then M.byShort[short] = key else M.byShort[short] = false end
        end
    end
    M.ready = true
    local pendingEvents = M.guild.pending
    M.guild.pending = {}
    for _, pending in ipairs(pendingEvents) do
        if pending.kind == "chat" then
            M.HandleChat(pending.event, pending.message, pending.sender, pending.lineID, pending.guid,
                pending.bnSenderID, pending.at, pending.session ~= M.session, pending.celebrationID, pending.creditWindow or false, nil, pending.destination)
        else C.Charge(M.guild, pending.levels, pending.player, pending.at) end
    end
    M.Dirty()
    return true
end

function M.LevelUp(level)
    level = tonumber(level)
    if not level or not M.character then return end
    local previous = M.character.level or level - 1
    if level <= previous then return end
    M.character.level = level
    local at = M.Now()
    M.Context()
    if not M.guild then return end
    C.StartReplyWindow(M.guild, at)
    if GG.Celebrations then GG.Celebrations.Start(M.guild, level, M.playerKey, at) end
    if M.CaptureRoster() then C.Charge(M.guild, level - previous, M.playerName, at)
    else
        M.guild.pending[#M.guild.pending + 1] = {levels = level - previous, player = M.playerName, at = at}
        M.RequestRoster()
    end
    if C.db.settings.dingEnabled then
        local sent, reason = M.Send(C.Message(C.db.settings.dingMessage, M.playerName, level))
        if not sent then M.Print(reason) end
    end
    if GG.UI then GG.UI.Celebrate(level) end
    M.Dirty()
end

function M.BattleNetSender(accountID)
    if not accountID or not C_BattleNet or not C_BattleNet.GetAccountInfoByID then return end
    local ok, account = pcall(C_BattleNet.GetAccountInfoByID, accountID)
    local game = ok and account and account.gameAccountInfo
    -- Account display names are never treated as character names.
    if game and game.clientProgram == "WoW" and game.playerGuid then
        return M.ResolveSender(nil, game.playerGuid)
    end
end

-- Skip restricted events before parsing, identity lookups, deduplication or buffering.
local function hasSecretChatValue(message, sender, lineID, guid, bnSenderID)
    return C.IsSecret(message) or C.IsSecret(sender) or C.IsSecret(lineID)
        or C.IsSecret(guid) or C.IsSecret(bnSenderID)
end

function M.HandleChat(event, message, sender, lineID, guid, bnSenderID, receivedAt, suppressAuto, celebrationID, creditWindow, classification, destination)
    if hasSecretChatValue(message, sender, lineID, guid, bnSenderID) then return end
    if not M.guild or type(message) ~= "string" or C.IsReport(message) then return end
    if event ~= "CHAT_MSG_BN_WHISPER" and M.IsSelf(sender, guid) then return end
    local key
    if event == "CHAT_MSG_BN_WHISPER" then key = M.BattleNetSender(bnSenderID or guid)
    else key = M.ResolveSender(sender, guid) end
    if not key or M.IsSelf(event ~= "CHAT_MSG_BN_WHISPER" and sender or nil, M.guild.members[key] and M.guild.members[key].guid, key) then return end
    local now = M.Time()
    if lineID and lineID ~= 0 then
        local id = M.guildKey .. ":" .. tostring(lineID)
        if M.seen[id] then return end
        M.seen[id] = M.Time()
    end
    local grats, ding
    if classification then grats, ding = classification.grats, classification.ding
    else grats, ding = C.Classify(message, C.db.settings.extraPhrases) end
    if grats then
        local at = receivedAt or M.Now()
        if C.Repay(M.guild, key, at, event:gsub("CHAT_MSG_", ""), creditWindow) then M.Dirty() end
        if GG.Celebrations then GG.Celebrations.Receive(M.guild, celebrationID, at, creditWindow) end
        return
    end
    if not suppressAuto and C.db.settings.autoEnabled and ding and (not M.cooldown[key] or (receivedAt or M.Now()) - M.cooldown[key] >= 30) then
        if GG.GratzButton and GG.GratzButton.Add(key, destination, receivedAt) then M.cooldown[key] = receivedAt or M.Now() end
    end
end

function M.Chat(event, message, sender, language, channelName, _, _, _, channelIndex, channelBase, _, lineID, guid, bnSenderID)
    if hasSecretChatValue(message, sender, lineID, guid, bnSenderID) then return end
    if not M.guild or type(message) ~= "string" or C.IsReport(message) then return end
    local at = M.Now()
    local grats, ding = C.Classify(message, C.db.settings.extraPhrases)
    if not grats and not ding then return end
    if grats and not C.CanCredit(M.guild, at) and (not GG.Celebrations or GG.Celebrations.Remaining(M.guild, at) == 0) then return end
    local destination = GG.GratzButton and GG.GratzButton.Destination(event, sender, channelIndex, channelBase or channelName, bnSenderID)
    if not M.ready or #M.guild.pending > 0 then
        -- Retain arrival order so extra early grats never become credit for a later ding.
        M.guild.pending[#M.guild.pending + 1] = {kind = "chat", event = event, message = message, sender = sender,
            lineID = lineID, guid = guid, bnSenderID = bnSenderID, at = at,
            celebrationID = M.guild.celebration and M.guild.celebration.id, creditWindow = M.guild.replyWindow, destination = destination, session = M.session}
    else M.HandleChat(event, message, sender, lineID, guid, bnSenderID, at, nil,
        M.guild.celebration and M.guild.celebration.id, M.guild.replyWindow, {grats = grats, ding = ding}, destination) end
end

function M.StartReport(lines, memberCount)
    if M.report then return false, "A report is already being sent." end
    local ok, reason = M.CanSend()
    if not ok then return false, reason end
    if not lines or #lines == 0 then return false, "Select at least one guildmate first." end
    M.report = {sent = 0, total = #lines, lines = lines, members = memberCount or #C.Members(M.guild, {selected = true})}
    for _, line in ipairs(lines) do
        M.queue[#M.queue + 1] = {text = line, guildKey = M.guildKey, kind = "report"}
    end
    M.Dirty()
    return true
end

function M.CancelReport()
    for i = #M.queue, 1, -1 do if M.queue[i].kind == "report" then table.remove(M.queue, i) end end
    M.report = nil
    M.Dirty()
end

function M.Tick(elapsed)
    M.clock = M.clock + elapsed
    if GG.GratzButton then GG.GratzButton.Update() end
    if GG.Celebrations and (GG.Celebrations.active or #GG.Celebrations.queue > 0) then GG.Celebrations.Update(elapsed) end
    M.accumulator = (M.accumulator or 0) + elapsed
    if M.accumulator < 0.1 then return end
    M.accumulator = 0
    local now = M.Time()
    local remaining = GG.Celebrations and GG.Celebrations.Remaining(M.guild) or 0
    if remaining ~= M.lastReplyRemaining then
        M.lastReplyRemaining = remaining
        if GG.UI and GG.UI.frame and GG.UI.frame:IsShown() and GG.UI.tab == "celebrations" then GG.UI.RefreshCelebrations() end
    end
    if #M.queue > 0 and now >= (M.nextSend or 0) then
        local entry = table.remove(M.queue, 1)
        if entry.guildKey == M.guildKey and (entry.kind ~= "auto" or (C.db.settings.autoEnabled and not M.IsSelf(entry.sender, entry.guid, entry.senderKey))) then
            local sent, reason = M.Send(entry.text)
            if not sent then
                M.Print(reason)
                M.queue, M.report = {}, nil
            elseif entry.kind == "report" and M.report then
                M.report.sent = M.report.sent + 1
                if M.report.sent >= M.report.total then
                    M.status = "Report sent: " .. M.report.total .. " message(s)."
                    M.report = nil
                end
            end
            M.nextSend = now + 1.5
            M.Dirty()
        end
    end
    if now >= (M.nextCleanup or 0) then
        for id, timestamp in pairs(M.seen) do if now - timestamp > 120 then M.seen[id] = nil end end
        M.nextCleanup = now + 30
    end
    if M.rosterDue and now >= M.rosterDue then M.CaptureRoster() end
    if M.guild and (not M.ready or #M.guild.pending > 0) and now >= (M.nextRoster or 0) and now >= (M.lastCapture or 0) + 1 then
        M.RequestRoster()
        M.CaptureRoster()
        M.nextRoster = now + 5
    end
    if M.dirty and GG.UI and GG.UI.frame and GG.UI.frame:IsShown() then GG.UI.Refresh(); M.dirty = false end
end

function M.Initialize()
    M.session = {}
    GratzGuildDB = C.Initialize(GratzGuildDB)
    M.realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    M.playerName = name or UnitName("player")
    M.playerRealm = realm and realm ~= "" and realm or M.realm
    M.playerGUID = UnitGUID("player")
    M.playerKey = C.MarkOwn(M.playerName, M.playerRealm, M.playerGUID)
    M.character = C.db.characters[M.playerKey] or {}
    C.db.characters[M.playerKey] = M.character
    M.character.guid = M.playerGUID
    -- Login establishes a baseline, never fabricates offline level-ups.
    local level = UnitLevel("player")
    if level and level > 0 then M.character.level = level end
    M.Context()
    M.RequestRoster()
    M.CaptureRoster()
    if GG.Celebrations then GG.Celebrations.Initialize() end
    if GG.GratzButton then GG.GratzButton.Initialize() end
    if GG.UI then GG.UI.Initialize() end
    M.Dirty()
end

function M.ScheduleRoster()
    if not M.guild or M.refreshing or M.Time() < (M.suppressRosterUntil or 0) then return end
    M.rosterDue = M.rosterDue or math.max(M.Time() + 0.2, (M.lastCapture or 0) + 1)
end

local frame = CreateFrame("Frame")
GG.eventFrame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
local function activate()
    if M.initialized then return end
    M.initialized = true
    M.Initialize()
    frame:UnregisterEvent("PLAYER_LOGIN")
    for _, name in ipairs({"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD"}) do
        frame:RegisterEvent(name)
    end
    for _, name in ipairs(incoming) do pcall(frame.RegisterEvent, frame, name) end
    frame:SetScript("OnUpdate", function(_, elapsed) M.Tick(elapsed) end)
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= addonName then return end
        GratzGuildDB = C.Initialize(GratzGuildDB)
        frame:UnregisterEvent("ADDON_LOADED")
        if IsLoggedIn and IsLoggedIn() then activate() end
    elseif event == "PLAYER_LOGIN" then activate()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if GG.GratzButton then GG.GratzButton.Combat(event == "PLAYER_REGEN_DISABLED") end
    elseif event == "PLAYER_LEVEL_UP" then M.LevelUp(...)
    elseif event == "GUILD_ROSTER_UPDATE" then
        M.Context()
        M.ScheduleRoster()
    elseif event == "PLAYER_GUILD_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        M.Context(); M.RequestRoster(); M.ScheduleRoster(); M.Dirty()
    else M.Chat(event, ...) end
end)

SLASH_GRATZGUILD1, SLASH_GRATZGUILD2 = "/gratzguild", "/gg"
SlashCmdList.GRATZGUILD = function(message)
    message = C.Trim(message):lower()
    if message == "help" then M.Print("/gg opens the ledger. /gg settings opens settings. /gg announce previews debt reports. /gg celebrations adjusts popups. /gg collection opens unlocked artwork.")
    elseif message == "resetui" then
        C.db.settings.position, C.db.settings.scale = nil, 1
        if GG.UI then GG.UI.ResetPosition(); GG.UI.Toggle(true) end
    else
        if GG.UI then
            GG.UI.Toggle(message ~= "")
            if message == "settings" then GG.UI.SetTab("settings")
            elseif message == "celebrations" then GG.UI.SetTab("celebrations")
            elseif message == "collection" then GG.UI.SetTab("collection")
            elseif message == "announce" then GG.UI.SetTab("announcements") end
        end
    end
end
