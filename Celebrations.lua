local _, GG = ...
local C, M = GG.Core, GG.Main
local S = {queue = {}}
GG.Celebrations = S
S.rarePortraits = {OrcMale = true, OrcFemale = true, TrollMale = true, TrollFemale = true,
    TaurenMale = true, TaurenFemale = true, UndeadMale = true, UndeadFemale = true,
    SkyborneMale = true, SkyborneFemale = true, ForTheHorde = true}
local root = "Interface\\AddOns\\GratzGuild\\"
local art = root .. "Media\\Celebrations\\"

function S.IsHorde()
    return not UnitFactionGroup or UnitFactionGroup("player") == "Horde"
end

function S.Pick(tier)
    if tier == 15 then return GG.Sounds.horde end
    local pool = tier == 5 and GG.Sounds.cheer or tier == 10 and GG.Sounds.congrats
    if not pool or #pool == 0 then return end
    return pool[math.random(#pool)]
end

function S.PickPortrait(sound)
    if S.rarePortraits[sound.portrait] and math.random(100) <= 5 then
        return sound.portrait .. "Rare", true
    end
    return sound.portrait, false
end

function S.StopCurrent()
    if S.handle and StopSound then pcall(StopSound, S.handle) end
    S.handle, S.active = nil, nil
    if S.editor then S.editor:SetShown(S.editorRequested == true) end
    if S.frame then
        S.fadeIn:Stop(); S.fadeOut:Stop(); S.frame:SetAlpha(1); S.frame:Hide()
    end
end

function S.Stop()
    S.queue = {}
    S.StopCurrent()
end

function S.Start(guild, level, owner, at)
    S.Stop()
    if not S.IsHorde() then guild.celebration = nil; return end
    guild.celebrationSerial = (guild.celebrationSerial or 0) + 1
    guild.celebration = {id = guild.celebrationSerial, count = 0, level = level, owner = owner, at = at, fired = {}}
    M.Dirty()
end

function S.Receive(guild, id, receivedAt, creditWindow)
    local session = guild and guild.celebration
    if not S.IsHorde() or not session or id ~= session.id or not C.CanCredit(guild, receivedAt or M.Now(), creditWindow) then return end
    session.count = (session.count or 0) + 1
    session.fired = session.fired or {}
    local tier = session.count
    if (tier == 5 or tier == 10 or tier == 15) and not session.fired[tier] then
        session.fired[tier] = true
        if C.db.settings.celebrationsEnabled then
            S.Enqueue(S.Pick(tier), tier, id, false)
        end
    end
    M.Dirty()
end

function S.Enqueue(sound, tier, id, preview, portrait)
    if not sound then return false end
    local entry = {sound = sound, tier = tier, sessionID = id, guildKey = M.guildKey, preview = preview}
    if portrait then entry.portrait, entry.rare = portrait, false end
    S.queue[#S.queue + 1] = entry
    S.Update(0)
    return true
end

function S.Test()
    if not S.IsHorde() then M.Print("Celebration voices are for Horde characters."); return false end
    S.Stop()
    for _, sound in ipairs(GG.Sounds.cheer) do
        if sound.portrait == "OrcMale" then return S.Enqueue(sound, 5, nil, true, "OrcMale") end
    end
    return false
end

function S.RestorePosition()
    if not S.editor then return end
    S.editor:ClearAllPoints()
    local p = C.db.settings.celebrationPosition
    if type(p) == "table" and #p == 4 then S.editor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else S.editor:SetPoint("CENTER", UIParent, "CENTER", 220, 160) end
end

function S.CollectionEntries()
    local labels = {}
    for _, sound in ipairs(GG.Sounds.cheer) do labels[sound.portrait] = sound.label end
    labels.ForTheHorde = "Thrall & Sylvanas"
    local entries = {}
    for _, base in ipairs({"OrcMale", "OrcFemale", "TrollMale", "TrollFemale", "TaurenMale", "TaurenFemale",
        "UndeadMale", "UndeadFemale", "SkyborneMale", "SkyborneFemale", "ForTheHorde"}) do
        for _, rare in ipairs({false, true}) do
            local portrait = base .. (rare and "Rare" or "")
            entries[#entries + 1] = {portrait = portrait, label = labels[base] .. (rare and " [Rare]" or ""),
                requirement = (base == "ForTheHorde" and "15 grats" or "5 or 10 grats"),
                unlocked = C.db.collection[portrait]}
        end
    end
    return entries
end

function S.Unlock(entry)
    if entry.preview or C.db.collection[entry.portrait] then return end
    C.db.collection[entry.portrait] = {at = M.Now(), tier = entry.tier, character = M.playerKey}
    M.Dirty()
end

local function text(parent, x, y, w, h, size, color)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetPoint("TOPLEFT", x, -y); f:SetSize(w, h)
    f:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    f:SetJustifyH("CENTER"); f:SetJustifyV("TOP"); f:SetTextColor(unpack(color))
    return f
end

function S.SetScale(value)
    value = tonumber(value) or 0.75
    local maximum = math.min(2, (UIParent:GetWidth() - 40) / 350, (UIParent:GetHeight() - 40) / 430)
    value = math.max(0.4, math.min(maximum, value))
    C.db.settings.celebrationScale = value
    if S.frame then S.frame:SetScale(value) end
    if S.editor then
        S.applyingSize = true
        S.editor:SetSize(350 * value, 430 * value)
        S.editorHeader:SetWidth(350 * value)
        S.editorTitle:SetWidth(350 * value - 24)
        S.editorHint:SetWidth(350 * value - 24)
        S.applyingSize = false
    end
    M.Dirty()
    return value
end

function S.SavePlacement()
    local x, y = S.editor:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if x and y and ux and uy then
        C.db.settings.celebrationPosition = {"CENTER", "CENTER", x - ux, y - uy}
        S.RestorePosition()
    end
end

function S.SetEditorShown(shown)
    S.Initialize()
    S.editorRequested = shown == true
    S.editor:SetShown(S.editorRequested and not S.active)
end

function S.ResetLayout()
    C.db.settings.celebrationPosition = nil
    S.SetScale(0.75); S.RestorePosition()
end

function S.InitializeEditor()
    local guide = CreateFrame("Frame", "GratzGuildPopupGuide", UIParent, "BackdropTemplate")
    S.editor = guide
    guide:SetFrameStrata("DIALOG"); guide:SetClampedToScreen(true); guide:SetMovable(true); guide:SetResizable(true)
    guide:EnableMouse(false)
    guide:SetResizeBounds(140, 172, math.min(700, UIParent:GetWidth() - 40), math.min(860, UIParent:GetHeight() - 40))
    guide:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
    guide:SetBackdropColor(0.12, 0.07, 0.20, 0.06); guide:SetBackdropBorderColor(0.79, 0.59, 1, 0.85)
    local header = CreateFrame("Button", nil, guide, "BackdropTemplate")
    S.editorHeader = header
    header:SetPoint("TOPLEFT", 0, 0); header:SetSize(262.5, 27)
    header:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"}); header:SetBackdropColor(0.20, 0.09, 0.28, 0.92)
    S.editorTitle = text(header, 12, 7, 238, 20, 11, {0.90, 0.73, 1})
    S.editorTitle:SetText("POPUP PLACEMENT")
    S.editorHint = text(guide, 12, 45, 238, 65, 12, {0.90, 0.73, 1})
    S.editorHint:SetText("Drag this header to move.\nDrag the bottom-right corner to resize.\nApplies to all 5 / 10 / 15 grats popups.")
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() guide:StartMoving() end)
    header:SetScript("OnDragStop", function() guide:StopMovingOrSizing(); S.SavePlacement() end)
    local grip = CreateFrame("Button", nil, guide)
    S.editorGrip = grip
    grip:SetPoint("BOTTOMRIGHT", 0, 0); grip:SetSize(24, 24)
    local mark = text(grip, 0, 0, 24, 24, 22, {0.90, 0.73, 1}); mark:SetText("+")
    grip:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" then S.resizing = true; guide:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function(_, mouse)
        if mouse == "LeftButton" then guide:StopMovingOrSizing(); S.resizing = false; S.SavePlacement() end
    end)
    guide:SetScript("OnSizeChanged", function(_, width)
        if S.resizing and not S.applyingSize then S.SetScale(width / 350) end
    end)
    S.RestorePosition(); guide:Hide()
end

function S.Initialize()
    if S.frame then return end
    S.InitializeEditor()
    local frame = CreateFrame("Frame", "GratzGuildCelebrationFrame", UIParent)
    S.frame = frame
    frame:SetSize(350, 430); frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true)
    frame:SetMovable(true); frame:EnableMouse(false)
    frame:SetPoint("CENTER", S.editor, "CENTER", 0, 0)
    S.portrait = frame:CreateTexture(nil, "ARTWORK")
    S.portrait:SetPoint("TOPLEFT", 5, 0); S.portrait:SetSize(340, 340)
    local plaque = CreateFrame("Button", nil, frame, "BackdropTemplate")
    plaque:SetPoint("TOPLEFT", 0, -346); plaque:SetSize(350, 80)
    plaque:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
    plaque:SetBackdropColor(0.20, 0.055, 0.065, 0.96); plaque:SetBackdropBorderColor(0.85, 0.58, 0.25, 1)
    S.title = text(plaque, 12, 13, 320, 30, 23, {1, 0.81, 0.47})
    S.subtitle = text(plaque, 12, 49, 320, 20, 12, {0.95, 0.90, 0.80})
    plaque:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Open /gg to move or resize the popup guide.", 1, 0.81, 0.47); GameTooltip:Show()
    end)
    plaque:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local close = CreateFrame("Button", nil, plaque)
    close:SetPoint("TOPRIGHT", -4, -3); close:SetSize(20, 20)
    local closeText = text(close, 0, 0, 20, 20, 12, {1, 0.81, 0.47}); closeText:SetText("x")
    close:SetScript("OnClick", S.StopCurrent)
    S.close = close
    S.fadeIn = frame:CreateAnimationGroup()
    local anim = S.fadeIn:CreateAnimation("Alpha"); anim:SetFromAlpha(0); anim:SetToAlpha(1); anim:SetDuration(0.22)
    S.fadeOut = frame:CreateAnimationGroup()
    anim = S.fadeOut:CreateAnimation("Alpha"); anim:SetFromAlpha(1); anim:SetToAlpha(0); anim:SetDuration(0.4)
    S.SetScale(C.db.settings.celebrationScale); frame:Hide()
end

local feelgood = {
    OrcMale = "You're a legend, champion!", OrcFemale = "Keep smashing it, superstar!",
    TrollMale = "You da best, mon!", TrollFemale = "Your mojo be shining, mon!",
    TaurenMale = "Big hugs for a big achievement!", TaurenFemale = "Stand tall. You earned this!",
    UndeadMale = "You're drop-dead brilliant!", UndeadFemale = "Too fabulous to stay buried!",
    SkyborneMale = "The sky's the limit. Keep shining!", SkyborneFemale = "You were born to shine!",
    ForTheHorde = "Your Horde is cheering for you!",
}

function S.Show(entry)
    S.Initialize()
    local sound = entry.sound
    if not entry.portrait then entry.portrait, entry.rare = S.PickPortrait(sound) end
    entry.playbackSound = entry.playbackSound or (entry.tier == 15 and entry.rare and GG.Sounds.hordeRare or sound)
    sound = entry.playbackSound
    S.portrait:SetTexture(art .. entry.portrait)
    S.title:SetText(entry.preview and "TEST POPUP" or entry.tier == 15 and "FOR THE HORDE!" or entry.tier .. " GRATS!")
    S.subtitle:SetText(feelgood[entry.sound.portrait] or "You earned every cheer!")
    S.editor:Hide()
    S.frame:SetAlpha(1); S.frame:Show()
    if not C.db.settings.reducedMotion then S.fadeIn:Play() end
    local ok, played, handle
    if PlaySoundFile then ok, played, handle = pcall(PlaySoundFile, root .. sound.file, "Master") end
    if ok and played then S.handle = handle end
    if not ok or played == false then M.Print("The celebration sound could not play. Check your game sound settings.") end
    S.active = entry
    S.active.untilTime = M.Time() + math.max(5, (sound.duration or 0) + 0.7)
    S.active.fading = false
    S.lastSound, S.lastTier = sound, entry.tier
    S.lastPortrait, S.lastRare = entry.portrait, entry.rare
    S.Unlock(entry)
    M.Dirty()
end

function S.Update()
    if S.active then
        local valid = S.active.preview or (C.db.settings.celebrationsEnabled and M.guild
            and M.guildKey == S.active.guildKey and M.guild.celebration
            and M.guild.celebration.id == S.active.sessionID)
        if not valid or M.Time() >= S.active.untilTime then S.StopCurrent()
        elseif not C.db.settings.reducedMotion and not S.active.fading and M.Time() >= S.active.untilTime - 0.4 then
            S.fadeOut:Play(); S.active.fading = true
        end
    end
    while not S.active and #S.queue > 0 do
        local entry = table.remove(S.queue, 1)
        if entry.preview or (C.db.settings.celebrationsEnabled and entry.guildKey == M.guildKey and M.guild
            and M.guild.celebration and M.guild.celebration.id == entry.sessionID) then S.Show(entry) end
    end
end
