local _, GG = ...
GG.Core = {}
local C = GG.Core
C.ReplySeconds = 300
local defaults = {
    dingEnabled = true, dingMessage = "Ding!", autoEnabled = true, autoMessage = "Gratz!",
    extraPhrases = "", scale = 1, reducedMotion = false, minimap = true, minimapAngle = 215,
    celebrationsEnabled = true, celebrationScale = 0.75,
}

local function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end
C.Trim = trim

function C.NameKey(name, realm)
    name = trim(name)
    if name == "" then return nil end
    if not name:find("-", 1, true) then name = name .. "-" .. (realm or "") end
    return name:gsub("%s", ""):lower()
end

function C.Initialize(db)
    db = type(db) == "table" and db or {}
    db.version = 2
    db.settings = type(db.settings) == "table" and db.settings or {}
    for k, v in pairs(defaults) do if db.settings[k] == nil then db.settings[k] = v end end
    db.guilds = type(db.guilds) == "table" and db.guilds or {}
    db.characters = type(db.characters) == "table" and db.characters or {}
    db.own = type(db.own) == "table" and db.own or {}
    db.ownGUIDs = type(db.ownGUIDs) == "table" and db.ownGUIDs or {}
    db.collection = type(db.collection) == "table" and db.collection or {}
    db.exclusions = type(db.exclusions) == "table" and db.exclusions or {}
    C.db = db
    return db
end

function C.GuildKey(name, realm)
    return (tostring(realm or ""):gsub("%s", ""):lower()) .. ":" .. tostring(name or ""):lower()
end

function C.GetGuild(name, realm)
    local key = C.GuildKey(name, realm)
    local g = C.db.guilds[key]
    if not g then
        g = { name = name, realm = realm, members = {}, history = {}, pending = {}, dings = 0, repayments = 0 }
        C.db.guilds[key] = g
    end
    g.members, g.history, g.pending = g.members or {}, g.history or {}, g.pending or {}
    g.dings, g.repayments = g.dings or 0, g.repayments or 0
    -- Carry the latest saved ding into the new rule without opening a fresh login window.
    if not g.replyWindow and g.celebration and g.celebration.source ~= "gratzButton" and type(g.celebration.at) == "number" then
        C.StartReplyWindow(g, g.celebration.at)
    end
    if g.celebration then
        g.celebration.source = g.celebration.source or "levelUp"
        g.celebration.expiresAt = g.celebration.expiresAt or (g.celebration.at + 300)
    end
    return g, key
end

function C.StartReplyWindow(g, at)
    g.replyWindow = {at = at, expiresAt = at + C.ReplySeconds}
    return g.replyWindow
end

function C.CanCredit(g, at, window)
    if window == nil then window = g and g.replyWindow end
    return type(window) == "table" and type(window.at) == "number" and type(window.expiresAt) == "number"
        and type(at) == "number" and at >= window.at and at < window.expiresAt
end

function C.ReplyRemaining(g, at)
    local window = g and g.replyWindow
    return window and type(window.expiresAt) == "number" and math.max(0, window.expiresAt - at) or 0
end

function C.IsOwn(key, guid)
    return (guid and C.db.ownGUIDs[guid]) or (key and (C.db.own[key] or C.db.exclusions[key])) or false
end

function C.MarkOwn(name, realm, guid)
    local key = C.NameKey(name, realm)
    if not key then return end
    C.db.own[key] = true
    if guid and guid ~= "" then C.db.ownGUIDs[guid] = true end
    for _, g in pairs(C.db.guilds) do
        for memberKey, m in pairs(g.members or {}) do
            if memberKey == key or C.IsOwn(memberKey, m.guid) then m.debt, m.selected = 0, false end
        end
    end
    return key
end

function C.Log(g, kind, name, value, at, detail)
    table.insert(g.history, 1, { kind = kind, name = name, value = value, at = at, detail = detail })
    while #g.history > 80 do table.remove(g.history) end
end

-- Only call with a complete, nonempty roster. A failed refresh is not a departure.
function C.UpdateRoster(g, roster, at)
    if type(roster) ~= "table" or #roster == 0 then return false end
    local seen = {}
    for _, row in ipairs(roster) do
        local key = C.NameKey(row.name, g.realm)
        if row.guid and C.IsOwn(nil, row.guid) and not C.db.own[key] then C.MarkOwn(row.name, g.realm, row.guid) end
        if not key or seen[key] then return false end
        seen[key] = true
    end
    for key, m in pairs(g.members) do m.active, m.online = false, false end
    for _, row in ipairs(roster) do
        local key = C.NameKey(row.name, g.realm)
        local m = g.members[key]
        if not m then
            m = { debt = 0, repayments = 0, selected = not C.IsOwn(key, row.guid), firstSeen = at }
            g.members[key] = m
        end
        m.name, m.guid, m.class, m.level, m.rank = row.name, row.guid or m.guid, row.class, row.level, row.rank
        m.active, m.online, m.lastSeen = true, row.online == true, at
        if C.IsOwn(key, m.guid) then m.debt, m.selected = 0, false end
    end
    return true
end

function C.Charge(g, levels, player, at)
    levels = math.max(0, math.floor(tonumber(levels) or 0))
    if levels == 0 then return end
    for key, m in pairs(g.members) do
        if C.IsOwn(key, m.guid) then m.debt, m.selected = 0, false
        elseif m.active then m.debt = (m.debt or 0) + levels end
    end
    g.dings = g.dings + levels
    C.Log(g, "ding", player, levels, at)
end

function C.Repay(g, key, at, channel, window)
    local m = g and g.members[key]
    if not m or not m.active or C.IsOwn(key, m.guid) or (m.debt or 0) <= 0 or not C.CanCredit(g, at, window) then return false end
    m.debt, m.repayments, m.lastGrats = m.debt - 1, (m.repayments or 0) + 1, at
    g.repayments = g.repayments + 1
    C.Log(g, "grats", m.name, m.debt, at, channel)
    return true
end

function C.Correct(g, key, amount, at)
    local m = g and g.members[key]
    amount = tonumber(amount)
    if not m or C.IsOwn(key, m.guid) or not amount or amount ~= amount or amount == math.huge then return false end
    amount = math.max(0, math.min(999999, math.floor(amount)))
    m.debt = amount
    C.Log(g, "correction", m.name, amount, at)
    return true
end

function C.IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function C.Plain(text)
    -- Restricted chat text cannot be converted or inspected by addons.
    if C.IsSecret(text) then return "" end
    text = tostring(text or "")
    text = text:gsub("|H.-|h.-|h", " "):gsub("|T.-|t", " "):gsub("|A.-|a", " ")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text
end

local function squeeze(word)
    local chars, previous = {}, nil
    for char in word:gmatch(".") do
        if char ~= previous or not char:match("%a") then chars[#chars + 1] = char end
        previous = char
    end
    return table.concat(chars)
end
function C.Normalized(text)
    local words = {}
    for word in C.Plain(text):lower():gmatch("[%w\128-\255]+") do words[#words + 1] = squeeze(word) end
    return " " .. table.concat(words, " ") .. " "
end

local builtin = {"grats", "gratz", "congrats", "congratz", "congratulations", "congratulation",
    "congratulationz", "congratzs", "gratzs", "gratulations", "gratulation", "gz", "grz", "grattis",
    "gratzies", "gratsies", "gratzor", "gratzors", "gratsz", "congratsz", "congrates", "congratzies",
    "cgrats", "cgratz", "congradulations", "congraduations", "congradz", "cg", "gratez"}

C.DefaultGratsPhrases = builtin
C.DefaultDingPhrases = {"ding", "BIG DINGUS"}
local dingNeedles = {}
for _, phrase in ipairs(C.DefaultDingPhrases) do dingNeedles[#dingNeedles + 1] = C.Normalized(phrase) end
local function matchesDing(normalized)
    for _, needle in ipairs(dingNeedles) do
        if normalized:find(needle, 1, true) then return true end
    end
    return false
end
local builtinNeedles = {}
for _, word in ipairs(builtin) do builtinNeedles[#builtinNeedles + 1] = C.Normalized(word) end
local extraText, extraNeedles
local function matches(normalized, extras)
    for _, needle in ipairs(builtinNeedles) do
        if normalized:find(needle, 1, true) then return true end
    end
    extras = tostring(extras or "")
    if extras ~= extraText then
        extraText, extraNeedles = extras, {}
        for phrase in extras:gmatch("[^,;\r\n]+") do
            local needle = C.Normalized(phrase)
            if needle ~= "  " then extraNeedles[#extraNeedles + 1] = needle end
        end
    end
    for _, needle in ipairs(extraNeedles) do
        if normalized:find(needle, 1, true) then return true end
    end
    return false
end

function C.Classify(text, extras)
    local normalized = C.Normalized(text)
    return matches(normalized, extras), matchesDing(normalized)
end
function C.IsGrats(text, extras) return matches(C.Normalized(text), extras) end
function C.IsDing(text) return matchesDing(C.Normalized(text)) end

function C.IsReport(text)
    return C.Plain(text):find("[GratzGuild]", 1, true) ~= nil
end

function C.UTF8Cut(text, bytes)
    if #text <= bytes then return text end
    local last = bytes
    -- If the first excluded byte continues a character, remove that whole character.
    while last > 0 and text:byte(last + 1) and text:byte(last + 1) >= 128 and text:byte(last + 1) < 192 do
        last = last - 1
    end
    return text:sub(1, last)
end

function C.ChatText(text)
    return trim(C.Plain(text):gsub("[\r\n\t]", " "):gsub("|", ""):gsub("%s+", " "))
end

function C.Message(template, name, level)
    local text = tostring(template or ""):gsub("{name}", function() return name or "" end)
    text = text:gsub("{level}", function() return tostring(level or "") end)
    return C.UTF8Cut(C.ChatText(text), 255)
end

function C.Members(g, options)
    options = options or {}
    local list = {}
    if not g then return list end
    for key, m in pairs(g.members) do
        if m.active and not C.IsOwn(key, m.guid) and (not options.online or m.online)
            and (not options.debt or m.debt > 0) and (not options.selected or m.selected)
            and (not options.search or m.name:lower():find(options.search:lower(), 1, true)) then
            list[#list + 1] = {key = key, member = m}
        end
    end
    local sort = options.sort or "debt"
    table.sort(list, function(a, b)
        local x, y = a.member, b.member
        if sort == "debt" and x.debt ~= y.debt then return x.debt > y.debt end
        if sort == "level" and x.level ~= y.level then return (x.level or 0) > (y.level or 0) end
        if sort == "online" and x.online ~= y.online then return x.online end
        return x.name:lower() < y.name:lower()
    end)
    return list
end

function C.Stats(g)
    local total, count, debtors = 0, 0, 0
    for key, m in pairs(g and g.members or {}) do
        if m.active and not C.IsOwn(key, m.guid) then
            total, count = total + m.debt, count + 1
            if m.debt > 0 then debtors = debtors + 1 end
        end
    end
    return total, count, debtors
end

function C.Select(g, mode)
    for _, entry in ipairs(C.Members(g)) do
        entry.member.selected = mode == "all" or (mode == "debt" and entry.member.debt > 0) or false
    end
end

function C.Report(g)
    local entries = C.Members(g, { selected = true })
    if #entries == 0 then return {} end
    local prefix = "[GratzGuild] "
    local lines = {prefix .. "=== Gratz Debt Ledger | " .. #entries .. " guildmate(s) ==="}
    for _, entry in ipairs(entries) do
        local m = entry.member
        local suffix = " - " .. tostring(m.debt) .. " grats owed"
        lines[#lines + 1] = prefix .. C.UTF8Cut(C.ChatText(m.name), 255 - #prefix - #suffix) .. suffix
    end
    return lines
end
