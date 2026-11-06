local _, GG = ...
local C, M = GG.Core, GG.Main
local U = { tab = "ledger", offset = 0, rows = {}, filters = {}, sort = "debt" }
GG.UI = U
local media = "Interface\\AddOns\\GratzGuild\\Media\\"
local gold = {1, 0.80, 0.46}
local muted = {0.66, 0.61, 0.56}
local ivory = {0.95, 0.91, 0.83}
local function widgetName()
    U.widgetID = (U.widgetID or 0) + 1
    return "GratzGuildWidget" .. U.widgetID
end

local function label(parent, text, x, y, width, height, size, color)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
    f:SetPoint("TOPLEFT", x, -y)
    f:SetSize(width, height)
    f:SetJustifyH("LEFT"); f:SetJustifyV("TOP")
    f:SetTextColor(unpack(color or ivory))
    f:SetText(text)
    return f
end

local function panel(parent, x, y, width, height, color, name)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", x, -y); f:SetSize(width, height)
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, insets = {left = 1, right = 1, top = 1, bottom = 1}})
    f:SetBackdropColor(unpack(color or {0.10, 0.075, 0.065, 1}))
    f:SetBackdropBorderColor(0.32, 0.23, 0.14, 1)
    return f
end

local function tooltip(widget, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(text, 1, 0.85, 0.60, true); GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function button(parent, text, x, y, width, action, primary)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetPoint("TOPLEFT", x, -y); b:SetSize(width, 30)
    b:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    b.normal = primary and {0.43, 0.12, 0.13, 1} or {0.18, 0.12, 0.09, 1}
    b:SetBackdropColor(unpack(b.normal)); b:SetBackdropBorderColor(0.54, 0.37, 0.18, 1)
    b.caption = label(b, text, 4, 8, width - 8, 18, 12, gold); b.caption:SetJustifyH("CENTER")
    b:SetScript("OnEnter", function(self) if self:IsEnabled() then self:SetBackdropColor(0.40, 0.23, 0.12, 1) end end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(self.normal)) end)
    b:SetScript("OnClick", action)
    return b
end

local function check(parent, text, x, y, width, action)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", x, -y); b:SetSize(24, 24)
    b.caption = label(b, text, 28, 5, width or 180, 20, 12)
    b:SetScript("OnClick", function(self) action(not not self:GetChecked()) end)
    return b
end

local function edit(parent, x, y, width, height, multiline)
    local holder = panel(parent, x, y, width, height, {0.07, 0.055, 0.045, 1})
    local scroll = CreateFrame("ScrollFrame", multiline and widgetName() or nil, holder, multiline and "UIPanelScrollFrameTemplate" or nil)
    scroll:SetPoint("TOPLEFT", 8, -6); scroll:SetPoint("BOTTOMRIGHT", multiline and -28 or -8, 6)
    local e = CreateFrame("EditBox", nil, scroll)
    e:SetSize(width - (multiline and 42 or 16), height - 12)
    e:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    e:SetTextColor(unpack(ivory)); e:SetAutoFocus(false); e:SetMultiLine(multiline == true)
    e:SetMaxLetters(multiline and 4000 or 255)
    if not multiline then e:SetTextInsets(0, 0, 2, 0) end
    scroll:SetScrollChild(e)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function() holder:SetBackdropBorderColor(unpack(gold)) end)
    e:SetScript("OnEditFocusLost", function() holder:SetBackdropBorderColor(0.32, 0.23, 0.14, 1) end)
    if not multiline then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
    return e, holder
end

local function texture(parent, name, x, y, width, height)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", x, -y); t:SetSize(width, height); t:SetTexture(media .. name)
    return t
end

local function showStatus(text) M.status = text; M.Dirty() end

function U.ResetPosition()
    if not U.frame then return end
    U.frame:ClearAllPoints(); U.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    C.db.settings.scale = math.min(C.db.settings.scale or 1, U.maxScale or 1.25)
    U.frame:SetScale(C.db.settings.scale)
end

function U.SetTab(tab)
    U.tab = tab
    for key, f in pairs(U.pages) do f:SetShown(key == tab) end
    for key, b in pairs(U.tabs) do
        b.normal = key == tab and {0.43, 0.12, 0.13, 1} or {0.18, 0.12, 0.09, 1}
        b:SetBackdropColor(unpack(b.normal))
    end
    if tab == "settings" then U.LoadSettings() end
    U.Refresh()
end

function U.Toggle(force)
    if not U.frame then return end
    if force then U.frame:Show() else U.frame:SetShown(not U.frame:IsShown()) end
    U.Refresh()
end

function U.Celebrate(level)
    if not U.frame then return end
    U.toast:SetText("LEVEL " .. tostring(level) .. "!  Let the grats roll in.")
    U.toast:Show()
    U.toastUntil = M.Time() + 6
    if not C.db.settings.reducedMotion then
        U.murlocPulse:Stop(); U.murlocPulse:Play()
    end
end

function U.Confirm(title, detail, action)
    if U.modal then U.modal:Hide() end
    local f = panel(U.frame, 250, 235, 480, 210, {0.12, 0.065, 0.06, 1})
    f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
    label(f, title, 22, 20, 435, 28, 20, gold)
    label(f, detail, 22, 62, 435, 80, 13)
    button(f, "Confirm", 22, 158, 210, function() action(); f:Hide(); U.Refresh() end, true)
    button(f, "Cancel", 248, 158, 210, function() f:Hide() end)
    U.modal = f
end

function U.Correction(key)
    if U.modal then U.modal:Hide() end
    local guild = M.guild
    local m = guild and guild.members[key]
    if not m then return end
    local f = panel(U.frame, 250, 225, 480, 230, {0.12, 0.065, 0.06, 1})
    f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
    label(f, m.name, 22, 20, 435, 28, 19, gold)
    label(f, "Set their Gratz Debt balance. This requires confirmation.", 22, 62, 435, 35, 12)
    local value = edit(f, 22, 104, 210, 36, false); value:SetText(tostring(m.debt))
    button(f, "Forgive debt", 248, 106, 210, function()
        U.Confirm("Forgive Gratz Debt?", "Set " .. m.name .. "'s balance to zero?", function()
            C.Correct(guild, key, 0, M.Now()); showStatus("Debt forgiven for " .. m.name .. ".")
        end)
    end)
    button(f, "Set balance", 22, 175, 210, function()
        local amount = tonumber(value:GetText())
        if not amount or amount < 0 or amount > 999999 or amount ~= math.floor(amount) then
            M.Print("Enter a whole number from 0 to 999999."); return
        end
        U.Confirm("Change Gratz Debt?", "Set " .. m.name .. "'s balance to " .. amount .. "?", function()
            C.Correct(guild, key, amount, M.Now()); showStatus("Balance updated for " .. m.name .. ".")
        end)
    end, true)
    button(f, "Cancel", 248, 175, 210, function() f:Hide() end)
    U.modal = f
end

function U.History()
    if U.modal then U.modal:Hide() end
    local f = panel(U.frame, 175, 170, 630, 425, {0.12, 0.065, 0.06, 1})
    f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
    label(f, "Little celebrations, big receipts", 22, 20, 590, 30, 19, gold)
    local scroll = CreateFrame("ScrollFrame", widgetName(), f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -67); scroll:SetSize(565, 292)
    local body = CreateFrame("Frame", nil, scroll); body:SetSize(555, 300); scroll:SetScrollChild(body)
    local lines = {}
    for _, h in ipairs(M.guild and M.guild.history or {}) do
        local stamp = date and date("%d %b %H:%M", h.at or 0) or ""
        local detail
        if h.kind == "ding" then detail = h.name .. " gained " .. h.value .. " level(s). Debt added."
        elseif h.kind == "grats" then detail = h.name .. " repaid one. Balance: " .. h.value .. " (" .. (h.detail or "chat") .. ")."
        else detail = h.name .. "'s balance was set to " .. h.value .. "." end
        lines[#lines + 1] = stamp .. "  " .. detail
    end
    local text = label(body, #lines > 0 and table.concat(lines, "\n\n") or "Your story starts with the next ding.", 0, 0, 550, 280, 12)
    text:SetHeight(math.max(280, text:GetStringHeight())); body:SetHeight(text:GetHeight() + 10)
    button(f, "Close", 22, 378, 585, function() f:Hide() end)
    U.modal = f
end

function U.BuildLedger(parent)
    U.search = edit(parent, 0, 0, 365, 34, false)
    U.search:SetScript("OnTextChanged", function(self) U.filters.search = self:GetText(); U.offset = 0; U.RefreshLedger() end)
    label(parent, "Search guildmates", 380, 10, 220, 20, 12, muted)
    U.online = check(parent, "Online only", 0, 47, 155, function(v) U.filters.online = v; U.offset = 0; U.RefreshLedger() end)
    U.debtOnly = check(parent, "In debt only", 183, 47, 155, function(v) U.filters.debt = v; U.offset = 0; U.RefreshLedger() end)
    button(parent, "Refresh roster", 551, 44, 149, function() M.RequestRoster(); M.CaptureRoster(); U.Refresh() end)
    local headers = {{"Guildmate", 40, 230, "name"}, {"Level", 295, 53, "level"}, {"Status", 365, 64, "online"}, {"Debt", 448, 62, "debt"}}
    for _, h in ipairs(headers) do
        local sort = h[4]
        button(parent, h[1], h[2], 91, h[3], function() U.sort = sort; U.offset = 0; U.RefreshLedger() end)
    end
    label(parent, "Announce", 610, 100, 85, 18, 11, gold)
    for i = 1, 10 do
        local row = panel(parent, 0, 129 + (i - 1) * 33, 700, 32, i % 2 == 0 and {0.125, 0.092, 0.078, 1} or {0.10, 0.072, 0.06, 1})
        row:SetBackdropBorderColor(0.19, 0.14, 0.10, 1)
        row.number = label(row, "", 9, 9, 28, 17, 10, muted)
        row.name = label(row, "", 40, 8, 242, 20, 12)
        row.level = label(row, "", 302, 9, 50, 18, 11, muted)
        row.online = label(row, "", 365, 9, 80, 18, 11)
        row.debt = label(row, "", 463, 6, 55, 23, 16, gold)
        row.correct = button(row, "Edit", 525, 2, 62, function() if row.key then U.Correction(row.key) end end)
        row.correct:SetHeight(28)
        row.selected = check(row, "", 632, 4, 0, function(v)
            if row.key and M.guild then M.guild.members[row.key].selected = v; U.Refresh() end
        end)
        tooltip(row.selected, "Include this guildmate in your saved announcement list. Tracking stays active either way.")
        U.rows[i] = row
    end
    U.rowScroll = CreateFrame("Slider", "GratzGuildLedgerScrollBar", parent, "UIPanelScrollBarTemplate")
    U.rowScroll:SetPoint("TOPLEFT", 706, -147); U.rowScroll:SetSize(16, 280)
    U.rowScroll:SetMinMaxValues(0, 0); U.rowScroll:SetValueStep(1)
    U.rowScroll:SetScript("OnValueChanged", function(_, value)
        if U.offset ~= math.floor(value + 0.5) then U.offset = math.floor(value + 0.5); U.RefreshLedger() end
    end)
    parent:EnableMouseWheel(true)
    parent:SetScript("OnMouseWheel", function(_, delta)
        U.offset = math.max(0, math.min(U.maxOffset or 0, U.offset - delta * 3)); U.RefreshLedger()
    end)
    U.empty = label(parent, "", 25, 165, 650, 120, 16, muted); U.empty:SetJustifyH("CENTER")
    U.ledgerCount = label(parent, "", 0, 476, 440, 24, 11, muted)
    button(parent, "Recent activity", 530, 468, 170, U.History)
end

function U.RefreshLedger()
    if not U.search then return end
    U.filters.sort = U.sort
    local list = C.Members(M.guild, U.filters)
    U.maxOffset = math.max(0, #list - #U.rows)
    U.offset = math.min(U.offset, U.maxOffset)
    U.rowScroll:SetMinMaxValues(0, U.maxOffset); U.rowScroll:SetValue(U.offset)
    U.rowScroll:SetShown(U.maxOffset > 0)
    for i, row in ipairs(U.rows) do
        local entry = list[U.offset + i]
        row:SetShown(entry ~= nil)
        if entry then
            local m = entry.member
            row.key = entry.key
            row.number:SetText(tostring(U.offset + i))
            row.name:SetText(m.name)
            local class = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class or ""]
            row.name:SetTextColor(class and class.r or ivory[1], class and class.g or ivory[2], class and class.b or ivory[3])
            row.level:SetText(tostring(m.level or "?"))
            row.online:SetText(m.online and "Online" or "Offline")
            row.online:SetTextColor(unpack(m.online and {0.47, 0.80, 0.57} or muted))
            row.debt:SetText(tostring(m.debt))
            row.debt:SetTextColor(unpack(m.debt > 0 and gold or {0.47, 0.80, 0.57}))
            row.selected:SetChecked(m.selected == true)
        end
    end
    U.empty:SetShown(#list == 0)
    U.empty:SetText(not M.guild and "Join a guild to start your grats story." or not M.ready and "Waiting for your full guild roster..." or "No guildmates match these filters.")
    U.ledgerCount:SetText(#list .. " guildmates shown  |  Click a heading to sort")
end

function U.BuildAnnouncements(parent)
    label(parent, "Send a little reminder", 0, 0, 700, 30, 23, gold)
    label(parent, "Choose names in the Ledger. Your selection is remembered across your alts.", 0, 39, 700, 35, 12, muted)
    button(parent, "Select all", 0, 78, 148, function() if M.guild then C.Select(M.guild, "all") end; U.Refresh() end)
    button(parent, "Select debtors", 158, 78, 165, function() if M.guild then C.Select(M.guild, "debt") end; U.Refresh() end)
    button(parent, "Clear selection", 333, 78, 167, function() if M.guild then C.Select(M.guild, "none") end; U.Refresh() end)
    U.previewCount = label(parent, "", 510, 86, 195, 20, 11, muted)
    local box = panel(parent, 0, 127, 700, 260, {0.065, 0.055, 0.045, 1})
    label(box, "GUILD CHAT PREVIEW", 16, 14, 600, 20, 11, gold)
    local scroll = CreateFrame("ScrollFrame", widgetName(), box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -47); scroll:SetSize(650, 195)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(640, 195); scroll:SetScrollChild(content)
    U.previewBody = content
    U.preview = label(content, "", 0, 0, 636, 195, 13, {0.48, 0.86, 0.57})
    U.reportSend = button(parent, "Send to Guild", 0, 405, 230, function()
        local lines, guildKey = {}, M.guildKey
        for i, line in ipairs(U.previewLines) do lines[i] = line end
        local count = #C.Members(M.guild, {selected = true})
        local function send()
            if guildKey ~= M.guildKey then showStatus("Guild changed. Please review the report again."); return end
            local ok, reason = M.StartReport(lines, count)
            if not ok then showStatus(reason) end
            U.Refresh()
        end
        if count > 10 then
            U.Confirm("Send more than 10 lines?", "You selected " .. count .. " names. This will send " .. #lines .. " lines to guild chat, including the heading.\n\nSend this report?", send)
        else send() end
    end, true)
    U.reportCancel = button(parent, "Cancel sending", 242, 405, 180, function() M.CancelReport(); showStatus("Report cancelled.") end)
    U.reportProgress = label(parent, "", 440, 413, 260, 35, 12, muted)
    label(parent, "Reports include zero balances when selected. Messages are paced to keep guild chat readable.", 0, 463, 700, 40, 11, muted)
end

function U.RefreshAnnouncements()
    local lines = M.report and M.report.lines or C.Report(M.guild)
    local changed = lines ~= U.previewLines
    U.previewLines = lines
    local count = M.report and M.report.members or #C.Members(M.guild, {selected = true})
    U.previewCount:SetText(count .. " selected")
    if changed then
    U.preview:SetText(#U.previewLines > 0 and table.concat(U.previewLines, "\n") or "Select guildmates to see exactly what will be sent.")
    U.preview:SetHeight(math.max(195, U.preview:GetStringHeight()))
    U.previewBody:SetHeight(U.preview:GetHeight() + 10)
    end
    U.reportSend:SetEnabled(M.guild ~= nil and M.ready and not M.report and #U.previewLines > 0)
    U.reportCancel:SetEnabled(M.report ~= nil)
    U.reportProgress:SetText(M.report and ("Sending " .. M.report.sent .. " / " .. M.report.total) or (#U.previewLines .. " chat message(s)"))
end

function U.BuildSettings(parent)
    local outer = parent
    local scroll = CreateFrame("ScrollFrame", widgetName(), outer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0); scroll:SetSize(700, 435)
    parent = CreateFrame("Frame", nil, scroll); parent:SetSize(700, 760)
    scroll:SetScrollChild(parent)
    U.settingsScroll = scroll
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(325, self:GetVerticalScroll() - delta * 35)))
    end)
    label(parent, "DEFAULT GRATS VARIATIONS (always accepted)", 0, 510, 698, 24, 12, gold)
    U.defaultGrats = label(parent, table.concat(C.DefaultGratsPhrases, ", "), 0, 542, 680, 100, 12, ivory)
    label(parent, "DEFAULT DING VARIATIONS (always accepted)", 0, 655, 698, 24, 12, gold)
    U.defaultDings = label(parent, table.concat(C.DefaultDingPhrases, ", "), 0, 686, 680, 22, 12, ivory)
    label(parent, "Case, punctuation and repeated letters are accepted: GRAAATZZZ! / Diiiing 42.\nScroll for the complete reference. Extra grats phrases remain editable above.", 0, 718, 680, 40, 11, muted)
    U.dingEnabled = check(parent, "Announce my level-ups", 0, 0, 275, function(v) C.db.settings.dingEnabled = v; M.Dirty() end)
    U.dingMessage = edit(parent, 0, 35, 333, 36, false)
    label(parent, "Default: Ding!   Placeholders: {level}, {name}", 0, 82, 340, 30, 11, muted)
    U.autoEnabled = check(parent, "Auto-grats guildmates", 0, 122, 275, function(v) C.db.settings.autoEnabled = v; M.Dirty() end)
    U.autoMessage = edit(parent, 0, 157, 333, 36, false)
    label(parent, "Default: Gratz!   Placeholder: {name}\nA ding in any channel sends a guild reply.", 0, 204, 340, 45, 11, muted)
    U.minimapCheck = check(parent, "Show minimap button", 0, 267, 280, function(v)
        C.db.settings.minimap = v; if U.minimap then U.minimap:SetShown(v) end
    end)
    U.motionCheck = check(parent, "Reduced motion", 0, 303, 280, function(v)
        C.db.settings.reducedMotion = v; if v then U.murlocPulse:Stop() end
    end)
    U.scaleLabel = label(parent, "", 0, 349, 333, 20, 12, gold)
    U.scaleSlider = CreateFrame("Slider", "GratzGuildScaleSlider", parent, "OptionsSliderTemplate")
    for _, suffix in ipairs({"Low", "High", "Text"}) do
        local region = U.scaleSlider[suffix] or _G["GratzGuildScaleSlider" .. suffix]
        if region then region:Hide() end
    end
    U.scaleSlider:SetPoint("TOPLEFT", 8, -379); U.scaleSlider:SetSize(310, 18)
    U.scaleSlider:SetMinMaxValues(0.65, U.maxScale or 1.25); U.scaleSlider:SetValueStep(0.05)
    U.scaleSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value * 100 + 0.5) / 100
        C.db.settings.scale = value; U.frame:SetScale(value); U.scaleLabel:SetText("Window scale: " .. math.floor(value * 100) .. "%")
    end)
    label(parent, "EXTRA GRATS PHRASES", 365, 4, 333, 20, 11, gold)
    U.extraPhrases = edit(parent, 365, 35, 333, 115, true)
    label(parent, "One word or phrase per line. Built-in variants always count.", 365, 160, 333, 32, 11, muted)
    U.phraseTest = edit(parent, 365, 204, 333, 36, false)
    U.phraseResult = label(parent, "Try a message above", 365, 249, 333, 30, 11, muted)
    local function testPhrase()
        local t = U.phraseTest:GetText()
        U.phraseResult:SetText(C.IsGrats(t, U.extraPhrases:GetText()) and "Grats detected: repays one debt." or C.IsDing(t) and "Ding detected: triggers auto-grats." or "No grats or ding detected.")
    end
    U.phraseTest:SetScript("OnTextChanged", testPhrase)
    U.extraPhrases:SetScript("OnTextChanged", testPhrase)
    label(parent, "MY OTHER ALTS / EXCLUSIONS", 365, 297, 333, 20, 11, gold)
    U.exclusions = edit(parent, 365, 327, 333, 70, true)
    label(parent, "One Name-Realm per line. Your logged-in alts are\nautomatically excluded. Unvisited alts can go here.", 365, 406, 333, 35, 11, muted)
    button(outer, "Save messages & phrases", 0, 453, 333, U.SaveSettings, true)
    label(parent, "Replies count for 5 minutes after your ding.\nEvery guildmate owes one grats per level you gain.", 365, 455, 335, 40, 11, muted)
end

function U.LoadSettings()
    local s = C.db.settings
    U.dingEnabled:SetChecked(s.dingEnabled); U.autoEnabled:SetChecked(s.autoEnabled)
    U.dingMessage:SetText(s.dingMessage); U.autoMessage:SetText(s.autoMessage)
    U.extraPhrases:SetText(s.extraPhrases); U.minimapCheck:SetChecked(s.minimap); U.motionCheck:SetChecked(s.reducedMotion)
    U.scaleSlider:SetValue(s.scale)
    U.scaleLabel:SetText("Window scale: " .. math.floor(s.scale * 100) .. "%")
    local names = {}
    for key in pairs(C.db.exclusions) do names[#names + 1] = key end
    table.sort(names); U.exclusions:SetText(table.concat(names, "\n"))
end

function U.SaveSettings()
    local ding, auto = C.ChatText(U.dingMessage:GetText()), C.ChatText(U.autoMessage:GetText())
    if ding == "" or auto == "" then showStatus("Both messages need some text. Use the switches to disable them."); return end
    C.db.settings.dingMessage, C.db.settings.autoMessage = ding, auto
    C.db.settings.extraPhrases = U.extraPhrases:GetText()
    local exclusions = {}
    for name in U.exclusions:GetText():gmatch("[^\r\n]+") do
        local key = C.NameKey(name, M.realm)
        if key then exclusions[key] = true end
    end
    C.db.exclusions = exclusions
    U.dingMessage:ClearFocus(); U.autoMessage:ClearFocus(); U.extraPhrases:ClearFocus(); U.exclusions:ClearFocus()
    showStatus("Messages, phrases and exclusions saved. Your guild is ready to party.")
    U.Refresh()
end

function U.BuildCelebrations(parent)
    label(parent, "Let your guild cheer", 0, 0, 700, 32, 23, gold)
    U.celebrationsCheck = check(parent, "Sound & character celebrations", 0, 43, 430, function(value)
        C.db.settings.celebrationsEnabled = value
        if not value then GG.Celebrations.Stop() end
        M.Dirty()
    end)
    U.celebrationCounter = label(parent, "", 0, 87, 700, 31, 14, gold)
    for i, tier in ipairs({{5, "A random Horde cheer"}, {10, "Random congratulations"}, {15, "For the Horde!"}}) do
        local card = panel(parent, (i - 1) * 238, 130, 224, 72, {0.18, 0.075, 0.065, 1})
        label(card, tier[1] .. " GRATS", 14, 12, 197, 24, 18, gold)
        label(card, tier[2], 14, 43, 197, 21, 11, ivory)
    end
    label(parent, "Replies count for five minutes after your ding. Each reply counts, even at zero debt.\nA real popup permanently unlocks its picture in your Collection.", 0, 233, 700, 52, 12, muted)
    label(parent, "POSITION & SIZE", 0, 304, 700, 21, 12, gold)
    label(parent, "While this interface is open, drag the purple guide's header to position your popups.\nDrag its bottom-right corner to resize. All three milestones use the same layout.", 0, 337, 700, 48, 12, ivory)
    U.popupScaleLabel = label(parent, "", 0, 401, 700, 22, 12, muted)
    U.popupTest = button(parent, "Test popup (male orc)", 0, 447, 340, function() GG.Celebrations.Test() end, true)
    button(parent, "Reset popup layout", 360, 447, 340, function()
        GG.Celebrations.ResetLayout(); showStatus("Popup layout restored: 75% size, slightly above and to the right.")
    end)
end

function U.RefreshCelebrations()
    if not U.celebrationCounter then return end
    local session = M.guild and M.guild.celebration
    local count = session and session.count or 0
    U.gratsStat:SetText("Grats this ding: " .. count)
    U.celebrationsCheck:SetChecked(C.db.settings.celebrationsEnabled)
    local remaining = C.ReplyRemaining(M.guild, M.Now())
    local windowText = remaining > 0 and (string.format("%d:%02d LEFT", math.floor(remaining / 60), remaining % 60)) or "WINDOW CLOSED"
    U.celebrationCounter:SetText(session and ("LEVEL " .. session.level .. "  |  " .. count .. " GRATS RECEIVED  |  " .. windowText)
        or "Your celebration counter starts with your next ding.")
    U.popupScaleLabel:SetText("Popup size: " .. math.floor(C.db.settings.celebrationScale * 100 + 0.5) .. "%  |  The test does not unlock collection entries.")
end

function U.ShowCollected(entry)
    if not entry or not C.db.collection[entry.portrait] then return false end
    if U.modal then U.modal:Hide() end
    local f = panel(U.frame, 195, 90, 590, 555, {0.12, 0.065, 0.06, 1})
    f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
    label(f, entry.label, 22, 19, 545, 30, 20, gold)
    texture(f, "Celebrations\\" .. entry.portrait, 90, 63, 410, 410)
    label(f, "Unlocked  |  " .. entry.requirement, 22, 480, 545, 22, 12, muted)
    button(f, "Close", 22, 514, 546, function() f:Hide() end)
    U.modal = f
    return true
end

function U.BuildCollection(parent)
    U.collectionPage, U.collectionCards = 1, {}
    label(parent, "Your celebration collection", 0, 0, 700, 32, 23, gold)
    label(parent, "Real popups unlock pictures permanently across your alts. Click an unlocked picture to view it.", 0, 38, 700, 23, 11, muted)
    for i = 1, 6 do
        local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
        card:SetPoint("TOPLEFT", ((i - 1) % 3) * 240, - (69 + math.floor((i - 1) / 3) * 198))
        card:SetSize(220, 190)
        card:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        card:SetBackdropColor(0.12, 0.08, 0.065, 1); card:SetBackdropBorderColor(0.37, 0.26, 0.16, 1)
        card.art = card:CreateTexture(nil, "ARTWORK"); card.art:SetPoint("TOPLEFT", 49, -8); card.art:SetSize(122, 122); card.art:Hide()
        card.question = label(card, "?", 70, 24, 80, 75, 56, gold); card.question:SetJustifyH("CENTER")
        card.locked = label(card, "LOCKED", 12, 109, 196, 20, 11, muted); card.locked:SetJustifyH("CENTER")
        card.nameText = label(card, "", 12, 134, 196, 20, 12, gold); card.nameText:SetJustifyH("CENTER")
        card.requirement = label(card, "", 12, 158, 196, 29, 10, muted); card.requirement:SetJustifyH("CENTER")
        card:SetScript("OnClick", function() U.ShowCollected(card.entry) end)
        U.collectionCards[i] = card
    end
    U.collectionPrev = button(parent, "Previous", 0, 468, 140, function() U.collectionPage = U.collectionPage - 1; U.RefreshCollection() end)
    U.collectionNext = button(parent, "Next", 560, 468, 140, function() U.collectionPage = U.collectionPage + 1; U.RefreshCollection() end)
    U.collectionCount = label(parent, "", 150, 477, 400, 20, 12, gold); U.collectionCount:SetJustifyH("CENTER")
end

function U.RefreshCollection()
    if not U.collectionCards then return end
    local entries = GG.Celebrations.CollectionEntries()
    local pages = math.ceil(#entries / #U.collectionCards)
    U.collectionPage = math.max(1, math.min(pages, U.collectionPage))
    local unlocked = 0
    for _, entry in ipairs(entries) do if entry.unlocked then unlocked = unlocked + 1 end end
    for i, card in ipairs(U.collectionCards) do
        local entry = entries[(U.collectionPage - 1) * #U.collectionCards + i]
        card.entry = entry; card:SetShown(entry ~= nil)
        if entry then
            card:SetEnabled(not not entry.unlocked)
            card.nameText:SetText(entry.unlocked and entry.label or "Undiscovered celebration")
            card.requirement:SetText((entry.unlocked and "Unlocked: " or "Unlock: ") .. entry.requirement)
            card.question:SetShown(not entry.unlocked); card.locked:SetShown(not entry.unlocked)
            if entry.unlocked then card.art:SetTexture(media .. "Celebrations\\" .. entry.portrait); card.art:Show()
            else card.art:SetTexture(nil); card.art:Hide() end
        end
    end
    U.collectionPrev:SetEnabled(U.collectionPage > 1); U.collectionNext:SetEnabled(U.collectionPage < pages)
    U.collectionCount:SetText(unlocked .. " / " .. #entries .. " unlocked  |  Page " .. U.collectionPage .. " / " .. pages)
end

function U.BuildMinimap()
    if not Minimap then return end
    local b = CreateFrame("Button", "GratzGuildMinimapButton", UIParent)
    b:SetSize(32, 32); b:SetFrameStrata("MEDIUM")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.icon:SetTexture(media .. "MurlocIcon")
    local border = b:CreateTexture(nil, "OVERLAY"); border:SetSize(54, 54); border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
    local function place()
        local angle = math.rad(C.db.settings.minimapAngle or 215)
        local ratio = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local rx, ry = Minimap:GetWidth() * ratio / 2 + 24, Minimap:GetHeight() * ratio / 2 + 24
        local x, y = math.cos(angle), math.sin(angle)
        if GetMinimapShape and GetMinimapShape() == "SQUARE" then
            local divisor = math.max(math.abs(x), math.abs(y)); x, y = x / divisor, y / divisor
        end
        x, y = x * rx, y * ry
        if b.lastX ~= x or b.lastY ~= y then
            b.lastX, b.lastY = x, y
            b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end
    end
    b:SetScript("OnClick", function(_, mouse)
        if b.skipClick then b.skipClick = false; return end
        U.Toggle(mouse == "RightButton"); if mouse == "RightButton" then U.SetTab("settings") end
    end)
    b:SetScript("OnDragStart", function() b.dragging = true end)
    b:SetScript("OnUpdate", function(_, elapsed)
        if b.dragging then
            local x, y = GetCursorPosition(); local mx, my = Minimap:GetCenter(); local scale = Minimap:GetEffectiveScale()
            C.db.settings.minimapAngle = math.deg(math.atan2(y / scale - my, x / scale - mx)); place()
        else
            b.refresh = (b.refresh or 0) + elapsed
            if b.refresh >= 0.5 then b.refresh = 0; place() end
        end
    end)
    b:SetScript("OnDragStop", function() b.dragging = false; b.skipClick = true; place() end)
    if Minimap.HookScript then
        Minimap:HookScript("OnHide", function() b:Hide() end)
        Minimap:HookScript("OnShow", function() b:SetShown(C.db.settings.minimap) end)
    end
    tooltip(b, "GratzGuild\nLeft click: ledger\nRight click: settings\nDrag: move around the minimap")
    place(); b:SetShown(C.db.settings.minimap); U.minimap = b
end

function U.Initialize()
    if U.frame then return end
    local f = panel(UIParent, 0, 0, 980, 740, {0.065, 0.042, 0.035, 0.98}, "GratzGuildFrame")
    U.frame = f; f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true); f:EnableMouse(true)
    U.maxScale = math.max(0.65, math.min(1.25, (UIParent:GetWidth() - 40) / 980, (UIParent:GetHeight() - 40) / 740))
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relative, x, y = self:GetPoint()
        C.db.settings.position = {point, relative, x, y}
    end)
    f:SetScript("OnShow", function() GG.Celebrations.SetEditorShown(true); U.Refresh() end)
    f:SetScript("OnHide", function() if U.modal then U.modal:Hide() end; GG.Celebrations.SetEditorShown(false) end)
    f:SetScript("OnUpdate", function()
        if U.toastUntil and M.Time() >= U.toastUntil then U.toast:Hide(); U.toastUntil = nil end
    end)
    f:SetBackdropBorderColor(0.72, 0.49, 0.23, 1)
    U.ResetPosition()
    local p = C.db.settings.position
    if type(p) == "table" and #p == 4 then f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
    -- Let Escape close the main window without binding or replacing a game key.
    if UISpecialFrames then table.insert(UISpecialFrames, "GratzGuildFrame") end
    local header = panel(f, 1, 1, 978, 130, {0.25, 0.068, 0.07, 1})
    header:SetBackdropBorderColor(0.48, 0.24, 0.12, 1)
    label(header, "GRATZGUILD", 25, 22, 590, 45, 35, gold)
    label(header, "A little celebration. A very serious grats ledger.", 27, 75, 570, 26, 13, ivory)
    texture(header, "Horde", 657, 0, 275, 130)
    button(header, "x", 941, 12, 26, function() f:Hide() end)
    U.guildLabel = label(f, "", 26, 144, 190, 30, 12, gold)
    local sidebar = panel(f, 18, 180, 188, 465, {0.11, 0.067, 0.055, 1})
    label(sidebar, "THE GRATS LEDGER", 14, 14, 164, 20, 10, gold)
    U.debtStat = label(sidebar, "0", 14, 50, 158, 42, 35, gold)
    label(sidebar, "TOTAL GRATZ DEBT", 14, 98, 164, 18, 10, muted)
    U.memberStat = label(sidebar, "0", 14, 143, 80, 31, 25)
    label(sidebar, "GUILDMATES", 14, 177, 165, 18, 10, muted)
    U.repaidStat = label(sidebar, "0", 105, 143, 65, 31, 25, {0.47, 0.80, 0.57})
    label(sidebar, "REPAID", 105, 177, 67, 18, 10, muted)
    U.gratsStat = label(sidebar, "Grats this ding: 0", 14, 207, 164, 20, 11, gold)
    U.murloc = texture(sidebar, "Murloc", 14, 235, 160, 160)
    label(sidebar, "Mrrgl... pay your grats!", 12, 410, 167, 30, 11, gold)
    U.murlocPulse = U.murloc:CreateAnimationGroup()
    local grow = U.murlocPulse:CreateAnimation("Scale"); grow:SetScale(1.08, 1.08); grow:SetDuration(0.18); grow:SetOrder(1)
    local shrink = U.murlocPulse:CreateAnimation("Scale"); shrink:SetScale(1 / 1.08, 1 / 1.08); shrink:SetDuration(0.28); shrink:SetOrder(2)
    U.tabs, U.pages = {}, {}
    local specs = {{"ledger", "Guild Ledger", 0, 128}, {"announcements", "Announcements", 138, 158},
        {"celebrations", "Celebrations", 306, 138}, {"collection", "Collection", 454, 126}, {"settings", "Settings", 590, 110}}
    for _, spec in ipairs(specs) do
        local key = spec[1]
        U.tabs[key] = button(f, spec[2], 232 + spec[3], 141, spec[4], function() U.SetTab(key) end)
        local page = CreateFrame("Frame", nil, f); page:SetPoint("TOPLEFT", 232, -190); page:SetSize(725, 500)
        U.pages[key] = page
    end
    U.BuildLedger(U.pages.ledger); U.BuildAnnouncements(U.pages.announcements); U.BuildSettings(U.pages.settings)
    U.BuildCelebrations(U.pages.celebrations)
    U.BuildCollection(U.pages.collection)
    U.status = label(f, "Ready for your next ding.", 24, 710, 935, 23, 11, muted)
    U.toast = label(header, "", 25, 108, 610, 20, 12, gold); U.toast:Hide()
    U.BuildMinimap(); U.SetTab("ledger"); f:Hide()
end

function U.Refresh()
    if not U.frame or not U.frame:IsShown() then M.Dirty(); return end
    local debt, members = C.Stats(M.guild)
    U.debtStat:SetText(tostring(debt)); U.memberStat:SetText(tostring(members))
    U.repaidStat:SetText(tostring(M.guild and M.guild.repayments or 0))
    U.guildLabel:SetText(M.guild and M.guild.name or "No guild yet")
    U.status:SetText(M.status or (M.guild and not M.ready and "Waiting for a complete guild roster. Level-ups will be recorded when it arrives." or "Every level counts. Every grats counts. Shared across your alts."))
    U.gratsStat:SetText("Grats this ding: " .. (M.guild and M.guild.celebration and M.guild.celebration.count or 0))
    if U.tab == "ledger" then U.RefreshLedger()
    elseif U.tab == "announcements" then U.RefreshAnnouncements()
    elseif U.tab == "celebrations" then U.RefreshCelebrations()
    elseif U.tab == "collection" then U.RefreshCollection() end
end
