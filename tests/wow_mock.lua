-- Strict API surface for lifecycle, callbacks and layout inspection, not a WoW renderer.
mockObjects, mockChat, mockRoster, mockTime = {}, {}, {}, 1000
mockGuild, mockRealm, mockPlayer, mockLevel = "Murloc Appreciation Society", "TestRealm", "Celebrant", 40
mockPlayerGUID, mockOffline, mockCanSpeak = "Player-1-self", false, true
mockFaction, mockSounds, mockStoppedSounds = "Horde", {}, {}
local methods = {}
local mt = {__index = methods}
local function object(kind, name, parent, template)
    local f = setmetatable({kind = kind, name = name, parent = parent, template = template,
        shown = true, enabled = true, width = 100, height = 30, points = {}, scripts = {}, events = {}, text = "", scale = 1}, mt)
    mockObjects[#mockObjects + 1] = f
    f.id = #mockObjects
    if name then _G[name] = f end
    return f
end
function CreateFrame(kind, name, parent, template) return object(kind, name, parent, template) end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetPoint(point, a, b, c, d)
    local relative, relativePoint, x, y
    if type(a) == "number" then relative, relativePoint, x, y = self.parent, point, a, b
    elseif type(a) == "table" then relative, relativePoint, x, y = a, b or point, c or 0, d or 0
    else relative, relativePoint, x, y = self.parent, point, 0, 0 end
    self.points[#self.points + 1] = {point, relative, relativePoint, x or 0, y or 0}
end
function methods:ClearAllPoints() self.points = {} end
function methods:GetPoint() return unpack(self.points[1] or {}) end
function methods:SetAllPoints(relative)
    self:ClearAllPoints(); self:SetPoint("TOPLEFT", relative or self.parent, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", relative or self.parent, "BOTTOMRIGHT", 0, 0)
end
function methods:SetSize(w, h)
    local changed = self.width ~= w or self.height ~= h
    self.width, self.height = w, h
    if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, w, h) end
end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function methods:SetResizable(value) self.resizable = value end
function methods:SetResizeBounds(...) self.resizeBounds = {...} end
function methods:StartSizing(corner) self.sizing = corner end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetText(text)
    local old = self.text; self.text = tostring(text or "")
    if old ~= self.text and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function methods:GetText() return self.text end
function methods:SetFont(path, size, flags) self.font, self.fontSize = path, size end
function methods:GetStringHeight()
    assert(self.kind == "FontString", "GetStringHeight is only available on FontString")
    local lines = 0
    for line in (self.text .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#line * (self.fontSize or 12) * 0.52 / self.width)) end
    return lines * ((self.fontSize or 12) + 3)
end
function methods:SetTextColor(...) self.textColor = {...} end
function methods:SetJustifyH(value) self.justifyH = value end
function methods:SetJustifyV(value) self.justifyV = value end
function methods:SetTextInsets(...) self.insets = {...} end
function methods:SetMaxLetters(value) self.maxLetters = value end
function methods:SetMultiLine(value) self.multiline = value end
function methods:SetAutoFocus(value) self.autoFocus = value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:IsEnabled() return self.enabled end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:Show() local old = self.shown; self.shown = true; if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local old = self.shown; self.shown = false; if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:SetScale(value) self.scale = value end
function methods:SetAlpha(value) self.alpha = value end
function methods:GetEffectiveScale() return self.scale end
function methods:GetCenter() return self.width / 2, self.height / 2 end
function methods:SetMinMaxValues(a, b) self.minimum, self.maximum = a, b end
function methods:SetValueStep(value) self.step = value end
function methods:SetValue(value)
    value = math.max(self.minimum or 0, math.min(self.maximum or value, value))
    local old = self.value; self.value = value
    if old ~= value and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function methods:GetValue() return self.value or 0 end
function methods:ClearFocus() self.focus = false; if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
function methods:SetScrollChild(child) self.child = child end
function methods:CreateFontString(name) return object("FontString", name, self) end
function methods:CreateTexture(name, layer)
    local f = object("Texture", name, self); f.layer = layer; return f
end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor(...) self.background = {...} end
function methods:SetBackdropBorderColor(...) self.border = {...} end
function methods:SetTexture(value) self.texture = value end
function methods:SetNormalTexture(value) self.normalTexture = value end
function methods:SetFrameStrata(value) self.strata = value end
function methods:CreateAnimationGroup() return object("AnimationGroup", nil, self) end
function methods:CreateAnimation(kind) return object("Animation", nil, self) end
function methods:Play() self.playing = true end
function methods:Stop() self.playing = false end
for _, method in ipairs({"SetMovable", "SetClampedToScreen", "EnableMouseWheel", "RegisterForDrag",
    "RegisterForClicks", "StartMoving", "StopMovingOrSizing", "SetDuration", "SetOrder", "SetFromAlpha", "SetToAlpha"}) do methods[method] = function() end end

UIParent = object("Root", "UIParent"); UIParent:SetSize(1920, 1080)
Minimap = object("Frame", "Minimap", UIParent); Minimap:SetSize(140, 140)
UISpecialFrames, SlashCmdList = {}, {}
GameTooltip = {SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, text) mockLastPrint = text end}
RAID_CLASS_COLORS = {WARRIOR = {r = 0.78, g = 0.61, b = 0.43}, MAGE = {r = 0.41, g = 0.80, b = 0.94},
    HUNTER = {r = 0.67, g = 0.83, b = 0.45}, SHAMAN = {r = 0.20, g = 0.60, b = 1}, DRUID = {r = 1, g = 0.49, b = 0.04}}
function UnitName() return mockPlayer end
function UnitGUID() return mockPlayerGUID end
function UnitLevel() return mockLevel end
function UnitFactionGroup() return mockFaction end
function GetRealmName() return mockRealm end
GetNormalizedRealmName = GetRealmName
function IsInGuild() return mockGuild ~= nil end
function GetGuildInfo() return mockGuild end
function GetNumGuildMembers() return #mockRoster end
function GetGuildRosterShowOffline() return mockOffline end
function SetGuildRosterShowOffline(value)
    mockOffline = value
    mockFilterChanges = (mockFilterChanges or 0) + 1
end
function GetGuildRosterInfo(i)
    local row = mockRoster[i]
    if not row or row.missing then return end
    return row.name, row.rank or "Member", 1, row.level or 40, "Warrior", "Orgrimmar", "", "", row.online,
        0, row.class or "WARRIOR", 0, 0, false, false, 0, row.guid
end
C_GuildInfo = {GuildRoster = function() mockRosterRequests = (mockRosterRequests or 0) + 1 end,
    CanSpeakInGuildChat = function() return mockCanSpeak end}
C_ChatInfo = {SendChatMessage = function(text, channel)
    if mockChatFailure then error("Blocked by client") end
    mockChat[#mockChat + 1] = {text = text, channel = channel}
end}
function GetTime() return mockTime end
function time() return 1791932400 + math.floor(mockTime) end
function date(format, timestamp) return os.date(format, timestamp) end
function GetCursorPosition() return 0, 0 end
function PlaySoundFile(file, channel)
    if mockSoundFailure then return false end
    local handle = #mockSounds + 1
    mockSounds[handle] = {file = file, channel = channel, handle = handle}
    return true, handle
end
function StopSound(handle) mockStoppedSounds[#mockStoppedSounds + 1] = handle end

function mockIncoming(gg, event, text, sender, id, guid)
    gg.Main.Chat(event, text, sender, nil, nil, nil, nil, nil, nil, nil, nil, id, guid)
end
function mockAdvance(gg, seconds) mockTime = mockTime + seconds; gg.Main.Tick(seconds) end
function mockClick(widget, checked)
    if checked ~= nil then widget:SetChecked(checked) end
    if widget.enabled and widget.scripts.OnClick then widget.scripts.OnClick(widget, "LeftButton") end
end

-- Test-only tier injection; the shipped interface exposes only the fixed male-orc test.
function mockPreview(gg, tier)
    if not gg.Celebrations.IsHorde() then return false end
    gg.Celebrations.Stop()
    return gg.Celebrations.Enqueue(gg.Celebrations.Pick(tier), tier, nil, true)
end

function methods:EnableMouse(value) self.mouseEnabled = value end
function methods:SetFocus() self.focus = true; if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end end
function methods:SetVerticalScroll(value) self.verticalScroll = value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end

function methods:SetBlinkSpeed(value) self.blinkSpeed = value end
