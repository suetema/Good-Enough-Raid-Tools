local _, ns = ...
local GERT = ns.GERT

local statusPriority = {
    missing = 1,
    unknown = 2,
    present = 3,
}

local function mergeStatus(current, candidate)
    if not current then
        return candidate
    end

    if statusPriority[candidate] > statusPriority[current] then
        return candidate
    end

    return current
end

local function addSpell(map, spellIds, category, status)
    for _, spellId in ipairs(spellIds) do
        map[spellId] = {
            category = category,
            status = status or "present",
        }
    end
end

local trackedBuffs = {}
local trackedBuffNames = {}
local EXPIRING_THRESHOLD_SECONDS = 240

local function setMaxRemaining(map, category, remainingSeconds)
    if not remainingSeconds then
        return
    end

    local current = map[category]
    if not current or remainingSeconds > current then
        map[category] = remainingSeconds
    end
end

local function normalizeRemainingSeconds(duration, expirationTime, now)
    if type(duration) ~= "number" or duration <= 0 then
        return nil
    end

    if type(expirationTime) ~= "number" or expirationTime <= 0 then
        return nil
    end

    now = now or GetTime()

    local remainingSeconds
    if expirationTime <= duration then
        remainingSeconds = expirationTime
    else
        remainingSeconds = expirationTime - now
        if remainingSeconds <= 0 and expirationTime <= (duration + 1) then
            remainingSeconds = expirationTime
        end
    end

    if type(remainingSeconds) ~= "number" or remainingSeconds <= 0 then
        return nil
    end

    if remainingSeconds > (duration + 1) then
        return nil
    end

    return remainingSeconds
end

local function registerTrackedNames(spellIds)
    for _, spellId in ipairs(spellIds) do
        local spellName = GetSpellInfo(spellId)
        if spellName then
            trackedBuffNames[spellName] = spellId
        end
    end
end

addSpell(trackedBuffs, {
    33254, 43722, 35272, 35273, 43764, 44106,
}, "foodbuff", "present")

addSpell(trackedBuffs, {
    17626, 28518, 28519, 42735, 42736, 42737,
}, "flask", "present")

addSpell(trackedBuffs, {
    28490, 28491, 33720, 28502, 28503, 38954, 39625,
    39626, 38938, 38940, 33721, 33726, 28509, 28514,
}, "elixir", "present")

addSpell(trackedBuffs, {
    16323, 25122, 25123, 28891, 3593, 8017, 8024,
    8027, 8033, 16339, 58804, 58801,
}, "weaponbuff", "present")

addSpell(trackedBuffs, {
    19740, 25782, 25894, 25895, 27149, 27150, 27151,
    27152, 27153, 25898, 25899, 25916,
}, "blessing", "present")

local foodBuffSpellIds = {
    33254, 43722, 35272, 35273, 43764, 44106,
}

local blessingSpellIds = {
    19740, 19834, 19835, 19836, 19837,
    19838, 25291, 27140, 27141, 25782,
    25894, 25895, 25898, 25899, 25916,
}

local battleElixirSpellIds = {
    28490, 33720, 28502, 28503, 38954, 39625, 39626,
}

local guardianElixirSpellIds = {
    28491, 33721, 33726, 28509, 28514, 38938, 38940,
}

local flaskSpellIds = {
    17626, 28518, 28519, 42735, 42736, 42737,
}

local weaponBuffSpellIds = {
    16323, 25122, 25123, 28891, 3593, 8017, 8024,
    8027, 8033, 16339, 58804, 58801,
}

local raidBuffRules = {
    {
        key = "fortitude",
        label = "Fortitude",
        providerClass = "PRIEST",
        spellIds = {
            1243, 1244, 1245, 2791, 10937, 10938, 25389,
            21562, 21564, 25392,
        },
    },
    {
        key = "intellect",
        label = "Intellect",
        providerClass = "MAGE",
        spellIds = {
            1459, 1460, 1461, 10156, 10157, 27126,
            23028, 27127,
        },
    },
    {
        key = "mark",
        label = "Mark",
        providerClass = "DRUID",
        spellIds = {
            1126, 5232, 6756, 5234, 8907, 9884,
            9885, 26990, 21849, 21850, 26991,
        },
    },
}
local raidBuffRuleBySpellId = {}

local function toSet(spellIds)
    local result = {}
    for _, spellId in ipairs(spellIds) do
        result[spellId] = true
    end
    return result
end

local blessingSet = toSet(blessingSpellIds)
local battleElixirSet = toSet(battleElixirSpellIds)
local guardianElixirSet = toSet(guardianElixirSpellIds)
local flaskSet = toSet(flaskSpellIds)
local weaponBuffSet = toSet(weaponBuffSpellIds)

registerTrackedNames(foodBuffSpellIds)
registerTrackedNames(flaskSpellIds)
registerTrackedNames(battleElixirSpellIds)
registerTrackedNames(guardianElixirSpellIds)
registerTrackedNames(weaponBuffSpellIds)
registerTrackedNames(blessingSpellIds)

for _, rule in ipairs(raidBuffRules) do
    registerTrackedNames(rule.spellIds)
    for _, spellId in ipairs(rule.spellIds) do
        raidBuffRuleBySpellId[spellId] = rule
    end
end

for spellId in pairs(trackedBuffs) do
    local spellName = GetSpellInfo(spellId)
    if spellName then
        trackedBuffNames[spellName] = spellId
    end
end

function GERT:CreateUnknownStatusMap()
    return self:CloneCategories("unknown")
end

function GERT:GetInitialStatusesForUnit(unit)
    local statuses = self:CreateUnknownStatusMap()
    local hasAnyRaidBuffProvider = false

    for _, rule in ipairs(raidBuffRules) do
        if self:RaidHasClass(rule.providerClass) then
            hasAnyRaidBuffProvider = true
            break
        end
    end

    statuses.raidbuff = hasAnyRaidBuffProvider and "missing" or "unknown"
    statuses.foodbuff = "missing"
    statuses.flask = "missing"
    statuses.elixir = "missing"
    statuses.weaponbuff = "unknown"
    statuses.blessing = self:RaidHasClass("PALADIN") and "missing" or "unknown"

    return statuses
end

function GERT:CollectBuffs(unit)
    local buffs = {}
    local now = GetTime()

    for index = 1, 40 do
        local name, _, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff(unit, index)
        if not name then
            break
        end

        if not spellId then
            spellId = trackedBuffNames[name]
        end

        buffs[#buffs + 1] = {
            name = name,
            spellId = spellId,
            duration = duration,
            expirationTime = expirationTime,
            remainingSeconds = normalizeRemainingSeconds(duration, expirationTime, now),
        }
    end

    return buffs
end

function GERT:EvaluateBuffCategories(unit)
    if not UnitExists(unit) then
        return self:CreateUnknownStatusMap(), {}, {}, {}
    end

    local statuses = self:GetInitialStatusesForUnit(unit)
    local details = {}
    local expires = {}
    local sawBattleElixir = false
    local sawGuardianElixir = false
    local sawFlask = false
    local battleElixirRemaining
    local guardianElixirRemaining
    local flaskRemaining
    local availableRaidBuffs = {}
    local presentRaidBuffs = {}
    local raidBuffRemainingByKey = {}
    local presentRaidBuffLabels = {}
    local missingRaidBuffLabels = {}

    for _, rule in ipairs(raidBuffRules) do
        if self:RaidHasClass(rule.providerClass) then
            availableRaidBuffs[rule.key] = rule
        end
    end

    for _, buff in ipairs(self:CollectBuffs(unit)) do
        local spellId = buff.spellId
        local tracked = spellId and trackedBuffs[spellId] or nil
        local raidBuffRule = spellId and raidBuffRuleBySpellId[spellId] or nil

        if tracked then
            statuses[tracked.category] = mergeStatus(statuses[tracked.category], tracked.status)
            details[tracked.category] = buff.name
            if tracked.category ~= "flask" and tracked.category ~= "elixir" then
                setMaxRemaining(expires, tracked.category, buff.remainingSeconds)
            end
        end

        if raidBuffRule and availableRaidBuffs[raidBuffRule.key] then
            presentRaidBuffs[raidBuffRule.key] = true
            setMaxRemaining(raidBuffRemainingByKey, raidBuffRule.key, buff.remainingSeconds)
        end

        if flaskSet[spellId] then
            sawFlask = true
            details.flask = buff.name
            details.elixir = buff.name
            if buff.remainingSeconds then
                flaskRemaining = math.max(flaskRemaining or 0, buff.remainingSeconds)
            end
        end

        if battleElixirSet[spellId] then
            sawBattleElixir = true
            details.elixir = buff.name
            if buff.remainingSeconds then
                battleElixirRemaining = math.max(battleElixirRemaining or 0, buff.remainingSeconds)
            end
        end

        if guardianElixirSet[spellId] then
            sawGuardianElixir = true
            details.elixir = buff.name
            if buff.remainingSeconds then
                guardianElixirRemaining = math.max(guardianElixirRemaining or 0, buff.remainingSeconds)
            end
        end

        if blessingSet[spellId] then
            statuses.blessing = "present"
            details.blessing = buff.name
        end

        if weaponBuffSet[spellId] then
            statuses.weaponbuff = "present"
            details.weaponbuff = buff.name
        end
    end

    if sawFlask then
        statuses.flask = "present"
        statuses.elixir = "present"
        if flaskRemaining then
            expires.flask = flaskRemaining
            expires.elixir = flaskRemaining
        end
    elseif sawBattleElixir and sawGuardianElixir then
        statuses.elixir = "present"
        statuses.flask = "missing"
        if battleElixirRemaining and guardianElixirRemaining then
            expires.elixir = math.min(battleElixirRemaining, guardianElixirRemaining)
        end
    else
        statuses.flask = "missing"
        statuses.elixir = "missing"
    end

    for _, rule in ipairs(raidBuffRules) do
        if availableRaidBuffs[rule.key] then
            if presentRaidBuffs[rule.key] then
                presentRaidBuffLabels[#presentRaidBuffLabels + 1] = rule.label
            else
                missingRaidBuffLabels[#missingRaidBuffLabels + 1] = rule.label
            end
        end
    end

    if #presentRaidBuffLabels > 0 and #missingRaidBuffLabels == 0 then
        statuses.raidbuff = "present"
        details.raidbuff = table.concat(presentRaidBuffLabels, ", ")

        for _, rule in ipairs(raidBuffRules) do
            if availableRaidBuffs[rule.key] then
                local remainingSeconds = raidBuffRemainingByKey[rule.key]
                if remainingSeconds then
                    if not expires.raidbuff or remainingSeconds < expires.raidbuff then
                        expires.raidbuff = remainingSeconds
                    end
                end
            end
        end
    elseif #missingRaidBuffLabels > 0 then
        statuses.raidbuff = "missing"
        details.raidbuff = table.concat(missingRaidBuffLabels, ", ")
    end

    local expiring = {}
    for category, remainingSeconds in pairs(expires) do
        if remainingSeconds > 0 and remainingSeconds < EXPIRING_THRESHOLD_SECONDS then
            expiring[category] = true
        end
    end

    return statuses, details, expires, expiring
end

function GERT:RaidHasClass(classFile)
    for _, unit in ipairs(self:GetRosterUnits()) do
        if UnitExists(unit) and select(2, UnitClass(unit)) == classFile then
            return true
        end
    end

    return false
end

function GERT:ScanRoster(scanSource)
    local results = {}

    for _, unit in ipairs(self:GetRosterUnits()) do
        if UnitExists(unit) then
            local displayName = self:GetPlayerDisplayName(unit)
            if displayName then
                local _, classFile = UnitClass(unit)
                local statuses, details, expires, expiring = self:EvaluateBuffCategories(unit)
                results[displayName] = {
                    class = select(1, UnitClass(unit)),
                    classFile = classFile,
                    statuses = statuses,
                    details = details,
                    expires = expires,
                    expiring = expiring,
                    scanSource = scanSource or "manual",
                }
            end
        end
    end

    self.db.lastScan = results
    self:RefreshMatrixFromCache()

    return results
end

function GERT:GetCachedRoster()
    return self.db.lastScan or {}
end

function GERT:GetStatusForPlayer(name, category)
    local row = self.db.lastScan[name]
    if not row or not row.statuses then
        return "unknown"
    end
    return row.statuses[category] or "unknown"
end
