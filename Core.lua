local addonName, ns = ...

local GERT = CreateFrame("Frame")
ns.GERT = GERT

GERT.addonName = addonName
GERT.windowTitle = "Good Enough Raid Tools"
GERT.slashPrefix = "/gert"
GERT.windowDefaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
}

GERT.categories = {
    "foodbuff",
    "flask",
    "elixir",
    "weaponbuff",
    "raidbuff",
    "blessing",
}

GERT.categoryLabels = {
    foodbuff = "Food",
    flask = "Flask",
    elixir = "Elixir",
    weaponbuff = "Weapon",
    raidbuff = "Raid",
    blessing = "Blessing",
}

GERT.statusColors = {
    present = { 0.15, 0.8, 0.25 },
    expiring = { 0.95, 0.82, 0.2 },
    missing = { 0.85, 0.2, 0.2 },
    unknown = { 0.55, 0.55, 0.55 },
}

GERT.statusTexts = {
    present = "OK",
    expiring = "WARN",
    missing = "MISS",
    unknown = "?",
}

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function GERT:NormalizeName(name)
    if not name or name == "" then
        return nil
    end

    local baseName = name:match("^[^-]+") or name
    return strlower(baseName)
end

function GERT:CloneCategories(defaultStatus)
    local result = {}
    for _, category in ipairs(self.categories) do
        result[category] = defaultStatus
    end
    return result
end

function GERT:DeepCopyScanCache(cache)
    local copy = {}
    for unitName, unitData in pairs(cache or {}) do
        copy[unitName] = {
            class = unitData.class,
            classFile = unitData.classFile,
            statuses = shallowCopy(unitData.statuses or {}),
            details = shallowCopy(unitData.details or {}),
            expires = shallowCopy(unitData.expires or {}),
            expiring = shallowCopy(unitData.expiring or {}),
            scanSource = unitData.scanSource,
        }
    end
    return copy
end

function GERT:GetDisplayStatusForCategory(row, category)
    local status = row and row.statuses and row.statuses[category] or "unknown"
    if status == "present" and row and row.expiring and row.expiring[category] then
        return "expiring"
    end
    return status
end

function GERT:GetReportFailureKind(row, category)
    local status = row and row.statuses and row.statuses[category] or "unknown"
    if status == "missing" then
        return "missing"
    end
    if status == "present" and row and row.expiring and row.expiring[category] then
        return "expiring"
    end
    return nil
end

function GERT:EnsureDB()
    if type(GoodEnoughRaidToolsDB) ~= "table" then
        GoodEnoughRaidToolsDB = {}
    end

    local db = GoodEnoughRaidToolsDB
    db.window = db.window or shallowCopy(self.windowDefaults)
    db.optouts = db.optouts or {}
    db.lastScan = db.lastScan or {}
    db.version = db.version or "1.0.3"

    self.db = db
end

function GERT:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff5fb7ffGERT|r " .. tostring(message))
end

function GERT:GetPlayerDisplayName(unit)
    local name = UnitName(unit)
    if not name then
        return nil
    end
    return name
end

function GERT:SaveWindowPosition()
    if not self.window then
        return
    end

    local point, _, relativePoint, x, y = self.window:GetPoint(1)
    self.db.window.point = point
    self.db.window.relativePoint = relativePoint
    self.db.window.x = x
    self.db.window.y = y
end

function GERT:GetWindowPosition()
    return self.db.window.point, self.db.window.relativePoint, self.db.window.x, self.db.window.y
end

function GERT:CanPublicReport()
    if not IsInRaid() then
        return false
    end

    if UnitIsGroupLeader and UnitIsGroupLeader("player") then
        return true
    end

    if UnitIsGroupAssistant and UnitIsGroupAssistant("player") then
        return true
    end

    local playerName = UnitName("player")
    if not playerName then
        return false
    end

    for index = 1, GetNumRaidMembers() do
        local name, rank = GetRaidRosterInfo(index)
        if name and self:NormalizeName(name) == self:NormalizeName(playerName) then
            return rank == 1 or rank == 2
        end
    end

    return false
end

function GERT:GetReportChannel()
    if IsInRaid() then
        if self:CanPublicReport() then
            return "RAID"
        end
        return nil
    end

    return "LOCAL"
end

function GERT:GetRosterUnits()
    local units = {}

    if IsInRaid() then
        for index = 1, GetNumRaidMembers() do
            units[#units + 1] = "raid" .. index
        end
    elseif GetNumPartyMembers() > 0 then
        units[#units + 1] = "player"
        for index = 1, GetNumPartyMembers() do
            units[#units + 1] = "party" .. index
        end
    else
        units[#units + 1] = "player"
    end

    return units
end

function GERT:OnInitialize()
    self:EnsureDB()
    self:RegisterSlashCommands()
    self:CreateWindow()
    self:RefreshMatrixFromCache()
end

function GERT:OnPlayerLogin()
    self:ScanRoster("login")
end

GERT:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName == addonName then
            GERT:OnInitialize()
        end
    elseif event == "PLAYER_LOGIN" then
        GERT:OnPlayerLogin()
    elseif event == "CHAT_MSG_WHISPER" then
        GERT:HandleWhisperCommand(...)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        GERT:RefreshMatrixFromCache()
    end
end)

GERT:RegisterEvent("ADDON_LOADED")
GERT:RegisterEvent("PLAYER_LOGIN")
GERT:RegisterEvent("CHAT_MSG_WHISPER")
GERT:RegisterEvent("GROUP_ROSTER_UPDATE")
GERT:RegisterEvent("PLAYER_ENTERING_WORLD")
