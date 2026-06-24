local _, ns = ...
local GERT = ns.GERT

local function tokenize(input)
    local tokens = {}
    for token in string.gmatch(input or "", "%S+") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

local function normalizeCategory(category)
    if not category then
        return nil
    end

    local lowered = strlower(category)
    if lowered == "all" then
        return "all"
    end

    for _, supported in ipairs(GERT.categories) do
        if lowered == supported then
            return lowered
        end
    end

    return nil
end

function GERT:RegisterSlashCommands()
    SLASH_GOODENOUGHRAIDTOOLS1 = "/gert"
    SlashCmdList.GOODENOUGHRAIDTOOLS = function(message)
        GERT:HandleSlashCommand(message)
    end
end

function GERT:PrintHelp()
    self:Print("/gert - toggle window")
    self:Print("/gert scan")
    self:Print("/gert report [all|category]")
    self:Print("/gert optouts")
    self:Print("/gert optout add <player> <category|all>")
    self:Print("/gert optout remove <player> <category|all>")
end

function GERT:HandleSlashCommand(message)
    local tokens = tokenize(message)
    local command = tokens[1] and strlower(tokens[1]) or nil

    if not command or command == "" then
        self:ToggleWindow()
        return
    end

    if command == "scan" then
        self:ScanRoster("slash")
        self:Print("Scan complete.")
        return
    end

    if command == "report" then
        self:HandleReportCommand(tokens[2] or "all")
        return
    end

    if command == "optouts" then
        self:PrintOptouts()
        return
    end

    if command == "optout" then
        self:HandleOptoutSlash(tokens)
        return
    end

    self:PrintHelp()
end

function GERT:GetOptoutBucket(playerName)
    local normalized = self:NormalizeName(playerName)
    if not normalized then
        return nil
    end

    self.db.optouts[normalized] = self.db.optouts[normalized] or {}
    return self.db.optouts[normalized], normalized
end

function GERT:SetOptout(playerName, category, enabled)
    local bucket, normalized = self:GetOptoutBucket(playerName)
    if not bucket then
        return false
    end

    if category == "all" then
        for _, supported in ipairs(self.categories) do
            bucket[supported] = enabled and true or nil
        end
    else
        bucket[category] = enabled and true or nil
    end

    if not next(bucket) then
        self.db.optouts[normalized] = nil
    end

    return true
end

function GERT:IsOptedOut(playerName, category)
    local normalized = self:NormalizeName(playerName)
    local bucket = normalized and self.db.optouts[normalized]
    return bucket and bucket[category] or false
end

function GERT:PrintOptouts()
    if not next(self.db.optouts) then
        self:Print("No stored opt-outs.")
        return
    end

    for playerName, categories in pairs(self.db.optouts) do
        local categoryNames = {}
        for _, category in ipairs(self.categories) do
            if categories[category] then
                categoryNames[#categoryNames + 1] = category
            end
        end
        self:Print(playerName .. ": " .. table.concat(categoryNames, ", "))
    end
end

function GERT:HandleOptoutSlash(tokens)
    local action = tokens[2] and strlower(tokens[2]) or nil
    local playerName = tokens[3]
    local category = normalizeCategory(tokens[4])

    if (action ~= "add" and action ~= "remove") or not playerName or not category then
        self:Print("Usage: /gert optout add|remove <player> <category|all>")
        return
    end

    self:SetOptout(playerName, category, action == "add")
    self:Print(string.format("%s %s %s.", playerName, action == "add" and "opted out of" or "opted into", category))
end

local function parseWhisperCommand(message)
    local prefix, mode, category = string.match(strlower(message or ""), "^(gert)%s+(unsub|sub)%s+(%S+)$")
    if prefix ~= "gert" then
        return nil
    end
    return mode, normalizeCategory(category)
end

function GERT:HandleWhisperCommand(message, sender)
    local mode, category = parseWhisperCommand(message)
    if not mode or not category then
        return
    end

    local enabled = mode == "unsub"
    local senderName = sender and (sender:match("^[^-]+") or sender)
    if not senderName then
        return
    end

    self:SetOptout(senderName, category, enabled)

    local response
    if enabled then
        response = string.format("GERT: opted you out of %s mentions.", category)
    else
        response = string.format("GERT: opted you back into %s mentions.", category)
    end

    SendChatMessage(response, "WHISPER", nil, senderName)
end

local function categoryListFromArgument(argument)
    local normalized = normalizeCategory(argument)
    if normalized == "all" or not normalized then
        return GERT.categories
    end
    return { normalized }
end

local function summarizeCategory(category, cache)
    local failingPlayers = {}
    local optedOutCount = 0
    local failureTotal = 0

    for playerName, row in pairs(cache) do
        local failureKind = GERT:GetReportFailureKind(row, category)
        if failureKind then
            failureTotal = failureTotal + 1
            if GERT:IsOptedOut(playerName, category) then
                optedOutCount = optedOutCount + 1
            else
                failingPlayers[#failingPlayers + 1] = playerName
            end
        end
    end

    table.sort(failingPlayers)
    return failingPlayers, optedOutCount, failureTotal
end

function GERT:HandleReportCommand(argument)
    local channel = self:GetReportChannel()
    if IsInRaid() and not channel then
        self:Print("Only raid leaders or assistants can report publicly.")
        return
    end

    local cache = self:GetCachedRoster()
    if not next(cache) then
        self:Print("No scan data available. Run /gert scan first.")
        return
    end

    local categories = categoryListFromArgument(argument)

    for _, category in ipairs(categories) do
        local failingPlayers, optedOutCount, failureTotal = summarizeCategory(category, cache)
        local label = self.categoryLabels[category] or category
        local summary = string.format("%s missing/expiring <4m: %d players, %d opted out from mentions", label, failureTotal, optedOutCount)

        if #failingPlayers > 0 then
            summary = summary .. " (" .. table.concat(failingPlayers, ", ") .. ")"
        end

        if channel == "LOCAL" then
            self:Print(summary)
        else
            SendChatMessage(summary, channel)
        end
    end
end
