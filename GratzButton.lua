local _, GG = ...
local C, M = GG.Core, GG.Main
local B = {entries = {}}
GG.GratzButton = B
local media = "Interface\\AddOns\\GratzGuild\\Media\\GratzButton\\"
local function groupIdentity(kind)
    if not GetNumGroupMembers then return nil end
    local ids = {}
    local prefix = IsInRaid and IsInRaid() and "raid" or "party"
    for i=1,GetNumGroupMembers() do ids[#ids+1] = UnitGUID(prefix .. i) or "" end
    table.sort(ids); return table.concat(ids, ",")
end
function B.Destination(event, sender, index, name, bn)
    local kind = event:gsub("CHAT_MSG_", ""):gsub("_LEADER$", "")
    if kind == "TEXT_EMOTE" then kind = "EMOTE" end
    local d = {kind = kind}
    if kind == "PARTY" or kind == "RAID" or kind == "RAID_WARNING" or kind == "INSTANCE_CHAT" then d.group = groupIdentity(kind) end
    if kind == "WHISPER" then d.target = sender
    elseif kind == "BN_WHISPER" then d.target = bn
    elseif kind == "CHANNEL" then d.target, d.channelName = index, name
    elseif kind == "COMMUNITIES_CHANNEL" and C_Club and C_Club.GetInfoFromLastCommunityChatLine then
        local _, club, stream = C_Club.GetInfoFromLastCommunityChatLine(); d.club, d.stream = club, stream
    end
    return d
end
function B.Validate(d)
    if C.IsSecret(d.target) or C.IsSecret(d.channelName) or C.IsSecret(d.club) or C.IsSecret(d.stream) then return false, "The destination is restricted." end
    if d.kind == "CHANNEL" then
        if not d.channelName or not GetChannelName then return false, "Original channel is unavailable." end
        local id, name = GetChannelName(d.channelName)
        if not id or id == 0 or name ~= d.channelName then return false, "Original channel is unavailable." end
        d.target = id
    elseif d.kind == "WHISPER" or d.kind == "BN_WHISPER" then
        if not d.target then return false, "Original whisper recipient is unavailable." end
    elseif d.kind == "COMMUNITIES_CHANNEL" then
        if not d.club or not d.stream or not C_Club or not C_Club.GetStreamInfo or not C_Club.GetStreamInfo(d.club, d.stream) then return false, "Original community stream is unavailable." end
    elseif d.kind == "PARTY" or d.kind == "RAID" or d.kind == "RAID_WARNING" or d.kind == "INSTANCE_CHAT" then
        if d.group and d.group ~= groupIdentity(d.kind) then return false, "The original group has changed." end
        if IsInGroup and not IsInGroup(d.kind == "INSTANCE_CHAT" and LE_PARTY_CATEGORY_INSTANCE or nil) then return false, "Original group is unavailable." end
    end
    return true
end
function B.Clear()
    B.entries, B.remaining, B.last, B.preview, B.pressed = {}, nil, nil, nil, nil
    if B.frame then
        B.frame:Hide()
        B.base:SetSize(210, 168); B.base:SetAlpha(1)
        B.hand:ClearAllPoints(); B.hand:SetPoint("TOPRIGHT", 0, 0)
        B.flash:SetAlpha(0)
        GameTooltip:Hide()
    end
end
function B.Combat(value)
    B.Update(); B.inCombat = value; B.last = M.Time(); B.Update()
end
function B.Add(key, destination)
    B.Update()
    if not destination or not C.db.settings.autoEnabled then return false end
    B.entries[#B.entries + 1] = {key = key, destination = destination, guildKey = M.guildKey}
    B.remaining = B.remaining and B.remaining + 10 or 30
    B.preview = nil; B.last = M.Time(); B.Update(); return true
end
function B.Messages()
    local groups, order = {}, {}
    for _, e in ipairs(B.entries) do
        local member = M.guild and M.guild.members[e.key]
        if e.guildKey == M.guildKey and member and member.active and not C.IsOwn(e.key, member.guid) then
            local d = e.destination
            local id = table.concat({d.kind, tostring(d.target), tostring(d.channelName), tostring(d.club), tostring(d.stream)}, ":")
            if not groups[id] then groups[id] = {destination = d, entries = {}, seen = {}}; order[#order+1] = groups[id] end
            local g = groups[id]
            if not g.seen[e.key] then g.entries[#g.entries+1] = e; g.seen[e.key] = true end
        end
    end
    local messages = {}
    local text = C.UTF8Cut(C.ChatText(C.db.settings.autoMessage), 255)
    for _, g in ipairs(order) do
        messages[#messages+1] = {text = text, destination = g.destination, entries = g.entries}
    end
    return messages
end
function B.Press()
    B.Update()
    if B.inCombat or B.pressed or (InCombatLockdown and InCombatLockdown()) then return end
    local preview = B.preview
    if not preview and (#B.entries == 0 or not B.remaining) then return end
    B.pressed, B.hitSound = M.Time(), false
    if preview then return end
    local sent, failed = 0, {}
    for _, message in ipairs(B.Messages()) do
        local ok, reason = M.Send(message.text, message.destination)
        if ok then sent = sent + 1 else
            M.Print(reason)
            for _, e in ipairs(message.entries) do failed[#failed+1] = e end
        end
    end
    B.entries = failed
    if #failed == 0 then B.remaining = nil end
    if sent > 0 then GG.Celebrations.OpenParticipation() end
    M.Dirty()
end
function B.Preview()
    if #B.entries > 0 then return end
    B.Initialize(); B.preview = true; B.Update()
end
function B.Restore()
    B.frame:ClearAllPoints()
    local p = C.db.settings.gratzPosition
    if type(p) == "table" and #p == 4 then B.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else B.frame:SetPoint("TOP", UIParent, "TOP", 220, -80) end
end
function B.Initialize()
    if B.frame then return end
    local f = CreateFrame("Button", "GratzGuildGratzButton", UIParent)
    B.frame = f; f:SetSize(320, 280); f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true)
    f:SetMovable(true); f:RegisterForDrag("RightButton"); f:RegisterForClicks("LeftButtonUp")
    B.Restore()
    B.base = f:CreateTexture(nil, "BACKGROUND"); B.base:SetTexture(media .. "Button"); B.base:SetSize(210, 168); B.base:SetPoint("BOTTOMLEFT", 0, 32)
    B.hand = f:CreateTexture(nil, "ARTWORK"); B.hand:SetTexture(media .. "Hand"); B.hand:SetSize(185, 210); B.hand:SetPoint("TOPRIGHT", 0, 0)
    B.caption = f:CreateFontString(nil, "OVERLAY"); B.caption:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE"); B.caption:SetTextColor(1, .82, .4); B.caption:SetPoint("BOTTOMLEFT", 24, 92); B.caption:SetSize(150, 35); B.caption:SetText("")
    B.status = f:CreateFontString(nil, "OVERLAY"); B.status:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE"); B.status:SetTextColor(1,.82,.4); B.status:SetPoint("BOTTOM", 0, 0); B.status:SetSize(320, 28)
    B.flash = f:CreateTexture(nil, "OVERLAY"); B.flash:SetTexture(media .. "Button"); B.flash:SetAllPoints(B.base); B.flash:SetBlendMode("ADD"); B.flash:SetAlpha(0)
    f:SetScript("OnClick", function() if not B.dragging then B.Press() end end)
    f:SetScript("OnDragStart", function(self) B.dragging = true; self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, r, x, y = self:GetPoint(); C.db.settings.gratzPosition = {p,r,x,y}; B.dragging = nil end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine("Gratz! Left-click to send. Right-drag to move.")
        for _, msg in ipairs(B.Messages()) do GameTooltip:AddLine(msg.destination.kind .. ": " .. msg.text, 1,.82,.4,true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local close = CreateFrame("Button", "GratzGuildGratzCloseButton", f, "UIPanelCloseButton")
    B.close = close
    close:SetSize(28, 28); close:SetPoint("TOPRIGHT", 0, 0)
    close:RegisterForClicks("LeftButtonUp")
    close:SetScript("OnClick", B.Clear)
    close:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Skip these dings", 1, .82, .4)
        GameTooltip:AddLine("Dismiss without sending Gratz. New dings can still appear.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    close:SetScript("OnLeave", function() GameTooltip:Hide() end)
    B.inCombat = InCombatLockdown and InCombatLockdown() or false
    f:Hide()
end
function B.Update()
    local now = M.Time()
    if not C.db then return end
    if not C.db.settings.autoEnabled and #B.entries > 0 then B.Clear() end
    if B.remaining then
        if not B.inCombat then B.remaining = B.remaining - math.max(0, now - (B.last or now)) end
        B.last = now
        if B.remaining <= 0 then B.Clear() end
    end
    if not B.frame then return end
    local visible = not B.inCombat and (B.remaining or B.preview or B.pressed)
    B.frame:SetShown(not not visible)
    if not visible then return end
    B.status:SetText(B.preview and "PREVIEW - right-drag to move" or (#B.entries .. (#B.entries == 1 and " ding  |  " or " dings  |  ") .. math.ceil(B.remaining or 0) .. "s"))
    local age = B.pressed and now - B.pressed
    local motion = not C.db.settings.reducedMotion
    if age then
        if age >= (motion and .12 or 0) and not B.hitSound then
            B.hitSound = true
            if PlaySoundFile then pcall(PlaySoundFile, "Interface\\AddOns\\GratzGuild\\sounds\\ParryWoodHitWood.ogg", "Master") end
        end
        local down = motion and (age < .12 and age/.12 or math.max(0, 1-(age-.12)/.22)) or 0
        B.hand:ClearAllPoints(); B.hand:SetPoint("TOPRIGHT", -down*70, -down*90)
        local bounce = motion and age > .22 and math.sin(math.min(1,(age-.22)/.43)*math.pi)*.22 or 0
        B.base:SetSize(210 * (1 + down*.13 + bounce), 168 * (1-down*.15 + bounce))
        B.flash:SetAlpha(age >= .12 and age < .3 and (.3-age)*3 or 0)
        if age >= .65 then B.pressed = nil; B.base:SetSize(210,168); B.hand:ClearAllPoints(); B.hand:SetPoint("TOPRIGHT",0,0) end
    end
    B.base:SetAlpha(age and 1 or (motion and (.86 + .14*math.sin(now*4)) or 1))
end
