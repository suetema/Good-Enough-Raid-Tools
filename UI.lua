local _, ns = ...
local GERT = ns.GERT

local ROW_HEIGHT = 18
local NAME_WIDTH = 110
local COLUMN_WIDTH = 62

local function sortNames(cache)
    local names = {}
    for name in pairs(cache) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function createCell(parent, width, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetWidth(width)
    text:SetJustifyH(justify or "CENTER")
    text:SetHeight(ROW_HEIGHT)
    return text
end

function GERT:CreateWindow()
    if self.window then
        return
    end

    local frame = CreateFrame("Frame", "GoodEnoughRaidToolsWindow", UIParent, "BackdropTemplate")
    frame:SetSize(NAME_WIDTH + (COLUMN_WIDTH * #self.categories) + 30, 320)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(window)
        window:StopMovingOrSizing()
        GERT:SaveWindowPosition()
    end)

    local point, relativePoint, x, y = self:GetWindowPosition()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText(self.windowTitle)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshButton:SetSize(70, 22)
    refreshButton:SetPoint("TOPLEFT", 10, -30)
    refreshButton:SetText("Scan")
    refreshButton:SetScript("OnClick", function()
        GERT:ScanRoster("button")
        GERT:Print("Scan complete.")
    end)

    local reportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reportButton:SetSize(70, 22)
    reportButton:SetPoint("LEFT", refreshButton, "RIGHT", 8, 0)
    reportButton:SetText("Report")
    reportButton:SetScript("OnClick", function()
        GERT:HandleReportCommand("all")
    end)

    local scrollFrame = CreateFrame("ScrollFrame", "GoodEnoughRaidToolsScrollFrame", frame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 10, -60)
    content:SetSize(NAME_WIDTH + (COLUMN_WIDTH * #self.categories), 1)
    frame.content = content
    frame.scrollFrame = scrollFrame

    local headerName = createCell(content, NAME_WIDTH, "LEFT")
    headerName:SetPoint("TOPLEFT", 0, 0)
    headerName:SetText("Player")
    headerName:SetTextColor(1, 0.82, 0)

    frame.headers = { player = headerName }
    frame.rows = {}

    for index, category in ipairs(self.categories) do
        local header = createCell(content, COLUMN_WIDTH, "CENTER")
        header:SetPoint("TOPLEFT", NAME_WIDTH + ((index - 1) * COLUMN_WIDTH), 0)
        header:SetText(self.categoryLabels[category])
        header:SetTextColor(1, 0.82, 0)
        frame.headers[category] = header
    end

    frame:SetScript("OnShow", function()
        GERT:RefreshMatrixFromCache()
    end)

    self.window = frame
end

function GERT:EnsureRow(index)
    if self.window.rows[index] then
        return self.window.rows[index]
    end

    local row = {}
    local baseY = -ROW_HEIGHT * index

    row.name = createCell(self.window.content, NAME_WIDTH, "LEFT")
    row.name:SetPoint("TOPLEFT", 0, baseY)

    row.cells = {}
    for columnIndex, category in ipairs(self.categories) do
        local cell = createCell(self.window.content, COLUMN_WIDTH, "CENTER")
        cell:SetPoint("TOPLEFT", NAME_WIDTH + ((columnIndex - 1) * COLUMN_WIDTH), baseY)
        row.cells[category] = cell
    end

    self.window.rows[index] = row
    return row
end

function GERT:HideUnusedRows(startIndex)
    for index = startIndex, #self.window.rows do
        local row = self.window.rows[index]
        row.name:SetText("")
        for _, category in ipairs(self.categories) do
            row.cells[category]:SetText("")
        end
    end
end

function GERT:RefreshMatrixFromCache()
    if not self.window then
        return
    end

    local cache = self:GetCachedRoster()
    local names = sortNames(cache)

    for index, playerName in ipairs(names) do
        local row = self:EnsureRow(index)
        local data = cache[playerName]
        row.name:SetText(playerName)

        for _, category in ipairs(self.categories) do
            local status = (data.statuses and data.statuses[category]) or "unknown"
            local color = self.statusColors[status] or self.statusColors.unknown
            row.cells[category]:SetText(self.statusTexts[status] or "?")
            row.cells[category]:SetTextColor(color[1], color[2], color[3])
        end
    end

    self:HideUnusedRows(#names + 1)
    self.window.content:SetHeight((#names + 1) * ROW_HEIGHT)
end

function GERT:ToggleWindow()
    if not self.window then
        self:CreateWindow()
    end

    if self.window:IsShown() then
        self.window:Hide()
    else
        self.window:Show()
    end
end
