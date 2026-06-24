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
    27141, 27143, 27127, 48469, 48470, 48467, 25392,
    26991, 32999, 27149, 27150, 27152, 27153, 27151,
    25528, 26968, 26969, 25291, 25898, 25899, 25916,
    27125, 27126, 25570, 25574, 26991, 17007,
}, "raidbuff", "present")

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

local raidBuffSpellIds = {
    27141, 27143, 27127, 48469, 48470, 48467, 25392,
    26991, 32999, 27149, 27150, 27152, 27153, 27151,
    25528, 26968, 26969, 25291, 25898, 25899, 25916,
    27125, 27126, 25570, 25574, 17007,
}

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
registerTrackedNames(raidBuffSpellIds)

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

    statuses.raidbuff = "missing"
    statuses.foodbuff = "missing"
    statuses.flask = "missing"
    statuses.elixir = "missing"
    statuses.weaponbuff = "unknown"
    statuses.blessing = self:RaidHasClass("PALADIN") and "missing" or "unknown"

    return statuses
end

function GERT:CollectBuffs(unit)
    local buffs = {}

    for index = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)
        if not name then
            break
        end

        if not spellId then
            spellId = trackedBuffNames[name]
        end

        buffs[#buffs + 1] = {
            name = name,
            spellId = spellId,
        }
    end

    return buffs
end

function GERT:EvaluateBuffCategories(unit)
    if not UnitExists(unit) then
        return self:CreateUnknownStatusMap(), {}
    end

    local statuses = self:GetInitialStatusesForUnit(unit)
    local details = {}
    local sawBattleElixir = false
    local sawGuardianElixir = false
    local sawFlask = false

    for _, buff in ipairs(self:CollectBuffs(unit)) do
        local spellId = buff.spellId
        local tracked = spellId and trackedBuffs[spellId] or nil

        if tracked then
            statuses[tracked.category] = mergeStatus(statuses[tracked.category], tracked.status)
            details[tracked.category] = buff.name
        end

        if flaskSet[spellId] then
            sawFlask = true
            details.flask = buff.name
            details.elixir = buff.name
        end

        if battleElixirSet[spellId] then
            sawBattleElixir = true
            details.elixir = buff.name
        end

        if guardianElixirSet[spellId] then
            sawGuardianElixir = true
            details.elixir = buff.name
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
    elseif sawBattleElixir and sawGuardianElixir then
        statuses.elixir = "present"
        statuses.flask = "missing"
    else
        statuses.flask = "missing"
        statuses.elixir = "missing"
    end

    return statuses, details
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
                local statuses, details = self:EvaluateBuffCategories(unit)
                results[displayName] = {
                    class = select(1, UnitClass(unit)),
                    classFile = classFile,
                    statuses = statuses,
                    details = details,
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
