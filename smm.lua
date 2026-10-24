local SMM = {
    target = "Hgportanny",
    pendingTarget = nil,
    recombTarget = "Hgportanny",
    pendingRecombTarget = nil,
    prefix = "MPL",
    recombItemID = 4381,
    nav = {
        enabled = true,
        mapID = nil,
        x = 0.5,
        y = 0.5,
    },
}

local function trim(s)
    if s == nil then
        return ""
    end
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

local function msg(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[SummonMinMax]|r " .. tostring(text))
    end
end

local function clamp(v, lo, hi)
    if v < lo then
        return lo
    end
    if v > hi then
        return hi
    end
    return v
end

local function nonLinearOffset(v, scale)
    local t = v / scale
    return t / (1 + math.abs(t) ^ 1.6)
end

local function getPlayerMapPosition()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return nil
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        return nil
    end

    local x, y = pos:GetXY()
    if not x or not y then
        return nil
    end

    return mapID, x, y
end

local function buildMacroText()
    if SMM.target and SMM.target ~= "" then
        return "/targetexact " .. SMM.target .. "\n/cast Ritual of Summoning"
    end
    return "/cast Ritual of Summoning"
end

local function getRitualIcon()
    local _, _, icon = GetSpellInfo("Ritual of Summoning")
    return icon
end

local function isWarlock()
    local _, classToken = UnitClass("player")
    return classToken == "WARLOCK"
end

local function isEngineer()
    if GetProfessions and GetProfessionInfo then
        local p1, p2 = GetProfessions()
        for _, profIndex in ipairs({ p1, p2 }) do
            if profIndex then
                local name, _, _, _, _, _, skillLine = GetProfessionInfo(profIndex)
                if skillLine == 202 then
                    return true
                end
                if name and string.find(string.lower(name), "engineering", 1, true) then
                    return true
                end
            end
        end
    end

    if IsSpellKnown then
        -- Engineering baseline spell in many Classic-era clients.
        if IsSpellKnown(4036) then
            return true
        end
    end

    if GetNumSkillLines and GetSkillLineInfo then
        local count = GetNumSkillLines() or 0
        for i = 1, count do
            local name, isHeader = GetSkillLineInfo(i)
            if not isHeader and name and string.find(string.lower(name), "engineering", 1, true) then
                return true
            end
        end
    end

    return false
end

local function getRecombIcon()
    if GetItemIcon then
        return GetItemIcon(SMM.recombItemID)
    end
    return nil
end

local function applyMacro()
    if not SMM.button then
        return
    end

    local macroText = buildMacroText()

    -- Set both generic and left-click attributes for Classic variants.
    SMM.button:SetAttribute("type", "macro")
    SMM.button:SetAttribute("macrotext", macroText)
    SMM.button:SetAttribute("type1", "macro")
    SMM.button:SetAttribute("macrotext1", macroText)
    SMM.button:SetAttribute("*type1", "macro")
    SMM.button:SetAttribute("*macrotext1", macroText)

    if SMM.buttonIcon then
        local icon = getRitualIcon()
        if icon then
            SMM.buttonIcon:SetTexture(icon)
        end
    end
end

local function setTarget(target)
    local v = trim(target)
    if v == "" then
        v = "Hgportanny"
    end

    if InCombatLockdown and InCombatLockdown() then
        SMM.pendingTarget = v
        msg("In combat: target update queued -> " .. v)
        return
    end

    SMM.target = v
    applyMacro()
    msg("Target set to: " .. SMM.target)
end

local function buildRecombMacroText()
    if SMM.recombTarget and SMM.recombTarget ~= "" then
        return "/targetexact " .. SMM.recombTarget .. "\n/use item:" .. tostring(SMM.recombItemID)
    end
    return "/use item:" .. tostring(SMM.recombItemID)
end

local function applyRecombMacro()
    if not SMM.recombButton then
        return
    end

    local macroText = buildRecombMacroText()
    SMM.recombButton:SetAttribute("type", "macro")
    SMM.recombButton:SetAttribute("macrotext", macroText)
    SMM.recombButton:SetAttribute("type1", "macro")
    SMM.recombButton:SetAttribute("macrotext1", macroText)
    SMM.recombButton:SetAttribute("*type1", "macro")
    SMM.recombButton:SetAttribute("*macrotext1", macroText)

    if SMM.recombButtonIcon then
        local icon = getRecombIcon()
        if icon then
            SMM.recombButtonIcon:SetTexture(icon)
        end
    end
end

local function setRecombTarget(target)
    local v = trim(target)
    if v == "" then
        v = "Hgportanny"
    end

    if InCombatLockdown and InCombatLockdown() then
        SMM.pendingRecombTarget = v
        msg("In combat: recomb target update queued -> " .. v)
        return
    end

    SMM.recombTarget = v
    applyRecombMacro()
    msg("Recomb target set to: " .. SMM.recombTarget)
end

local function applyNavTarget(mapID, x, y)
    SMM.nav.mapID = mapID
    SMM.nav.x = clamp(x, 0, 1)
    SMM.nav.y = clamp(y, 0, 1)
    msg(string.format("Nav target set: map %d @ %.3f, %.3f", SMM.nav.mapID, SMM.nav.x, SMM.nav.y))
end

local function setNavTargetHere()
    local mapID, x, y = getPlayerMapPosition()
    if not mapID then
        msg("Could not read player map position.")
        return
    end
    applyNavTarget(mapID, x, y)
end

local function parsePackedCoord(raw)
    local text = trim(raw or "")
    if text == "" then
        return nil
    end

    local asNumber = tonumber(text)
    if not asNumber then
        return nil
    end

    if string.find(text, "%.", 1, true) then
        return asNumber
    end

    local digits = string.len(text)
    if digits <= 0 then
        return nil
    end

    local scale = 10 ^ digits
    return asNumber / scale
end

local function getItemIDFromLink(link)
    if not link then
        return nil
    end

    local itemID = link:match("item:(%d+)")
    if not itemID then
        return nil
    end

    return tonumber(itemID)
end

local function hasMinorRecombInBags()
    local targetItemID = SMM.recombItemID

    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
        for bag = 0, 4 do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info then
                    local itemID = info.itemID
                    if not itemID and info.hyperlink then
                        itemID = getItemIDFromLink(info.hyperlink)
                    end
                    if itemID == targetItemID then
                        return true
                    end
                end
            end
        end
        return false
    end

    if GetContainerNumSlots and GetContainerItemLink then
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local link = GetContainerItemLink(bag, slot)
                if getItemIDFromLink(link) == targetItemID then
                    return true
                end
            end
        end
    end

    return false
end

local function hasMinorRecombEquipped()
    local targetItemID = SMM.recombItemID
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if getItemIDFromLink(link) == targetItemID then
            return true
        end
    end
    return false
end

local function updateRecombWidget()
    if not SMM.recombWidgetColor then
        return
    end

    if hasMinorRecombEquipped() then
        if SMM.recombWidget then
            SMM.recombWidget:Show()
        end
        SMM.recombWidgetColor:SetColorTexture(0.1, 0.85, 0.2, 0.95)
        return
    end

    if hasMinorRecombInBags() then
        if SMM.recombWidget then
            SMM.recombWidget:Show()
        end
        SMM.recombWidgetColor:SetColorTexture(0.95, 0.85, 0.1, 0.95)
        return
    end

    if SMM.recombWidget then
        SMM.recombWidget:Hide()
    end
end

local function updateRoleVisibility()
    if SMM.buttonHolder then
        if isWarlock() then
            SMM.buttonHolder:Show()
        else
            SMM.buttonHolder:Hide()
        end
    end

    if SMM.recombButtonHolder then
        if isEngineer() then
            SMM.recombButtonHolder:Show()
        else
            SMM.recombButtonHolder:Hide()
        end
    end
end

local function createRootFrame()
    if SMM.rootFrame then
        return
    end

    local root = CreateFrame("Frame", "SummonMinMaxRoot", UIParent)
    root:SetSize(260, 340)
    root:SetPoint("CENTER", 0, 10)
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    SMM.rootFrame = root
end

local function createRecombWidget()
    if SMM.recombWidget then
        return
    end

    local frame = CreateFrame("Frame", "SummonMinMaxRecombWidget", SMM.rootFrame)
    frame:SetSize(28, 28)
    frame:SetPoint("TOPLEFT", SMM.navFrame, "TOPRIGHT", 10, -2)

    local borderTop = frame:CreateTexture(nil, "ARTWORK")
    borderTop:SetColorTexture(0.8, 0.8, 0.8, 0.9)
    borderTop:SetPoint("TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", 0, 0)
    borderTop:SetHeight(1)

    local borderBottom = frame:CreateTexture(nil, "ARTWORK")
    borderBottom:SetColorTexture(0.8, 0.8, 0.8, 0.9)
    borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(1)

    local borderLeft = frame:CreateTexture(nil, "ARTWORK")
    borderLeft:SetColorTexture(0.8, 0.8, 0.8, 0.9)
    borderLeft:SetPoint("TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(1)

    local borderRight = frame:CreateTexture(nil, "ARTWORK")
    borderRight:SetColorTexture(0.8, 0.8, 0.8, 0.9)
    borderRight:SetPoint("TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    borderRight:SetWidth(1)

    local color = frame:CreateTexture(nil, "BACKGROUND")
    color:SetPoint("TOPLEFT", 1, -1)
    color:SetPoint("BOTTOMRIGHT", -1, 1)

    SMM.recombWidget = frame
    SMM.recombWidgetColor = color
    updateRecombWidget()
end

local function createRecombButton()
    if SMM.recombButton then
        return
    end

    local holder = CreateFrame("Frame", "SummonMinMaxRecombButtonHolder", SMM.rootFrame)
    holder:SetSize(76, 76)
    holder:SetPoint("LEFT", SMM.buttonHolder, "RIGHT", 12, 0)

    local borderTop = holder:CreateTexture(nil, "ARTWORK")
    borderTop:SetColorTexture(0.45, 0.9, 0.9, 0.95)
    borderTop:SetPoint("TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", 0, 0)
    borderTop:SetHeight(8)

    local borderBottom = holder:CreateTexture(nil, "ARTWORK")
    borderBottom:SetColorTexture(0.45, 0.9, 0.9, 0.95)
    borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(8)

    local borderLeft = holder:CreateTexture(nil, "ARTWORK")
    borderLeft:SetColorTexture(0.45, 0.9, 0.9, 0.95)
    borderLeft:SetPoint("TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(8)

    local borderRight = holder:CreateTexture(nil, "ARTWORK")
    borderRight:SetColorTexture(0.45, 0.9, 0.9, 0.95)
    borderRight:SetPoint("TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    borderRight:SetWidth(8)

    local button = CreateFrame("Button", "SummonMinMaxRecombButton", holder, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    button:SetSize(56, 56)
    button:SetPoint("CENTER", holder, "CENTER", 0, 0)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:EnableMouse(true)
    button:SetText("")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    SMM.recombButtonHolder = holder
    SMM.recombButton = button
    SMM.recombButtonIcon = icon
    applyRecombMacro()
end

local function updateNavWidget(elapsed)
    if not SMM.navFrame or not SMM.nav.enabled then
        return
    end

    SMM.navTick = (SMM.navTick or 0) + elapsed
    if SMM.navTick < 0.05 then
        return
    end
    SMM.navTick = 0

    local mapID, x, y = getPlayerMapPosition()
    if not mapID then
        SMM.navDot:Hide()
        return
    end

    if not SMM.nav.mapID then
        applyNavTarget(mapID, x, y)
    end

    if mapID ~= SMM.nav.mapID then
        SMM.navDot:Hide()
        return
    end

    local dx = x - SMM.nav.x
    local dy = y - SMM.nav.y

    local nx = nonLinearOffset(dx, 0.018)
    local ny = nonLinearOffset(dy, 0.018)

    local maxPixel = 72
    local px = nx * maxPixel
    local py = -ny * maxPixel

    SMM.navDot:ClearAllPoints()
    SMM.navDot:SetPoint("CENTER", SMM.navPlot, "CENTER", px, py)
    SMM.navDot:Show()

    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    if SMM.navArrow and facing then
        SMM.navArrow:SetRotation(facing)
    end
end

local function createNavWidget()
    if SMM.navFrame then
        return
    end

    local frame = CreateFrame("Frame", "SummonMinMaxNavWidget", SMM.rootFrame)
    frame:SetSize(220, 240)
    frame:SetPoint("TOP", SMM.rootFrame, "TOP", 0, -6)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -4)
    title:SetText("B737-800")

    local plot = CreateFrame("Frame", nil, frame)
    plot:SetSize(170, 170)
    plot:SetPoint("TOP", 0, -24)

    local bg = plot:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.08, 0.9)

    local borderTop = plot:CreateTexture(nil, "ARTWORK")
    borderTop:SetColorTexture(0.8, 0.8, 0.8, 0.8)
    borderTop:SetPoint("TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", 0, 0)
    borderTop:SetHeight(1)

    local borderBottom = plot:CreateTexture(nil, "ARTWORK")
    borderBottom:SetColorTexture(0.8, 0.8, 0.8, 0.8)
    borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(1)

    local borderLeft = plot:CreateTexture(nil, "ARTWORK")
    borderLeft:SetColorTexture(0.8, 0.8, 0.8, 0.8)
    borderLeft:SetPoint("TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(1)

    local borderRight = plot:CreateTexture(nil, "ARTWORK")
    borderRight:SetColorTexture(0.8, 0.8, 0.8, 0.8)
    borderRight:SetPoint("TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    borderRight:SetWidth(1)

    local axisV = plot:CreateTexture(nil, "ARTWORK")
    axisV:SetColorTexture(0.3, 0.3, 0.35, 1)
    axisV:SetPoint("TOP", 0, 0)
    axisV:SetPoint("BOTTOM", 0, 0)
    axisV:SetWidth(1)

    local axisH = plot:CreateTexture(nil, "ARTWORK")
    axisH:SetColorTexture(0.3, 0.3, 0.35, 1)
    axisH:SetPoint("LEFT", 0, 0)
    axisH:SetPoint("RIGHT", 0, 0)
    axisH:SetHeight(1)

    local targetX = plot:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    targetX:SetPoint("CENTER", 0, 0)
    targetX:SetText("X")
    targetX:SetTextColor(1, 0.2, 0.2)

    local dot = CreateFrame("Frame", nil, plot)
    dot:SetSize(16, 16)
    dot:SetPoint("CENTER", 0, 0)

    local arrow = dot:CreateTexture(nil, "BACKGROUND")
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetSize(28, 28)
    arrow:SetPoint("CENTER", 0, 0)

    SMM.navFrame = frame
    SMM.navPlot = plot
    SMM.navDot = dot
    SMM.navArrow = arrow

    frame:SetScript("OnUpdate", function(_, elapsed)
        updateNavWidget(elapsed)
    end)
end

local function registerPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(SMM.prefix)
        return
    end

    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(SMM.prefix)
    end
end

local function handleAddonMessage(prefix, payload)
    if prefix ~= SMM.prefix then
        return
    end

    local text = trim(payload)
    if text == "" then
        return
    end

    local summonTarget = text:match("^S(.+)$")
    if summonTarget then
        setTarget(summonTarget)
        return
    end

    local recombTarget = text:match("^R(.+)$")
    if recombTarget then
        setRecombTarget(recombTarget)
        return
    end

    local mapID, x, y = text:match("^P(%d+),([%d%.]+),([%d%.]+)$")
    if mapID and x and y then
        applyNavTarget(tonumber(mapID), tonumber(x), tonumber(y))
        return
    end

    local gx, gy = text:match("^G([^,]+),([^,]+)$")
    if gx and gy then
        local parsedX = parsePackedCoord(gx)
        local parsedY = parsePackedCoord(gy)
        if not parsedX or not parsedY then
            msg("Invalid G payload. Use Gxxxx,yyyyy or Gx.xxxx,y.yyyy")
            return
        end

        local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if not currentMapID then
            msg("Could not resolve current map for G payload.")
            return
        end

        applyNavTarget(currentMapID, parsedX, parsedY)
        return
    end

    if text == "PSHOW" then
        SMM.nav.enabled = true
        if SMM.navFrame then
            SMM.navFrame:Show()
        end
        return
    end

    if text == "PHIDE" then
        SMM.nav.enabled = false
        if SMM.navFrame then
            SMM.navFrame:Hide()
        end
        return
    end
end

local function createButton()
    if SMM.button then
        return
    end

    local holder = CreateFrame("Frame", "SummonMinMaxButtonHolder", SMM.rootFrame)
    holder:SetSize(76, 76)
    holder:SetPoint("TOP", SMM.navFrame, "BOTTOM", -44, -10)

    local borderTop = holder:CreateTexture(nil, "ARTWORK")
    borderTop:SetColorTexture(0.9, 0.85, 0.45, 0.95)
    borderTop:SetPoint("TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", 0, 0)
    borderTop:SetHeight(8)

    local borderBottom = holder:CreateTexture(nil, "ARTWORK")
    borderBottom:SetColorTexture(0.9, 0.85, 0.45, 0.95)
    borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(8)

    local borderLeft = holder:CreateTexture(nil, "ARTWORK")
    borderLeft:SetColorTexture(0.9, 0.85, 0.45, 0.95)
    borderLeft:SetPoint("TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(8)

    local borderRight = holder:CreateTexture(nil, "ARTWORK")
    borderRight:SetColorTexture(0.9, 0.85, 0.45, 0.95)
    borderRight:SetPoint("TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    borderRight:SetWidth(8)

    local button = CreateFrame("Button", "SummonMinMaxButton", holder, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    button:SetSize(56, 56)
    button:SetPoint("CENTER", holder, "CENTER", 0, 0)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:EnableMouse(true)
    button:SetText("")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    SMM.buttonIcon = icon

    SMM.buttonHolder = holder
    SMM.button = button
    applyMacro()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        registerPrefix()
        createRootFrame()
        createNavWidget()
        createButton()
        createRecombButton()
        createRecombWidget()
        updateRoleVisibility()
        updateRecombWidget()
        msg("Loaded. /smm <name>, /smmpos help, addon prefix MPL (S<name>, R<name>).")
    elseif event == "PLAYER_REGEN_ENABLED" then
        if SMM.pendingTarget and SMM.pendingTarget ~= "" then
            local queued = SMM.pendingTarget
            SMM.pendingTarget = nil
            SMM.target = queued
            applyMacro()
            msg("Applied queued target: " .. SMM.target)
        end
        if SMM.pendingRecombTarget and SMM.pendingRecombTarget ~= "" then
            local queuedRecomb = SMM.pendingRecombTarget
            SMM.pendingRecombTarget = nil
            SMM.recombTarget = queuedRecomb
            applyRecombMacro()
            msg("Applied queued recomb target: " .. SMM.recombTarget)
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, payload = ...
        handleAddonMessage(prefix, payload)
    elseif event == "BAG_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
        updateRecombWidget()
        updateRoleVisibility()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            updateRecombWidget()
            updateRoleVisibility()
        end
    elseif event == "SKILL_LINES_CHANGED" then
        updateRoleVisibility()
        updateRecombWidget()
    end
end)

SLASH_SUMMONMINMAX1 = "/smm"
SLASH_SUMMONMINMAX2 = "/summonminmax"
SlashCmdList["SUMMONMINMAX"] = function(msgText)
    setTarget(msgText)
end

SLASH_SUMMONMINMAXPOS1 = "/smmpos"
SlashCmdList["SUMMONMINMAXPOS"] = function(msgText)
    local text = trim(msgText)
    local cmd, rest = text:match("^(%S+)%s*(.*)$")
    if not cmd then
        msg("Usage: /smmpos sethere | set <x> <y> [map] | show | hide")
        return
    end

    cmd = string.lower(cmd)

    if cmd == "sethere" then
        setNavTargetHere()
        return
    end

    if cmd == "show" then
        SMM.nav.enabled = true
        if SMM.navFrame then
            SMM.navFrame:Show()
        end
        return
    end

    if cmd == "hide" then
        SMM.nav.enabled = false
        if SMM.navFrame then
            SMM.navFrame:Hide()
        end
        return
    end

    if cmd == "set" then
        local xs, ys, ms = rest:match("^(%-?[%d%.]+)%s+(%-?[%d%.]+)%s*(%d*)$")
        if not xs or not ys then
            msg("Usage: /smmpos set <x> <y> [map]")
            return
        end

        local x = tonumber(xs)
        local y = tonumber(ys)
        local mapID = tonumber(ms)
        if not x or not y then
            msg("Invalid coordinates.")
            return
        end

        if not mapID then
            local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            mapID = currentMapID
        end

        if not mapID then
            msg("No map available; provide map id explicitly.")
            return
        end

        applyNavTarget(mapID, x, y)
        return
    end

    if cmd == "help" then
        msg("/smmpos sethere | set <x> <y> [map] | show | hide")
        msg("Addon msg: MPL payload S<name> / R<name> / P<map>,<x>,<y> / Gxxxx,yyyyy / PSHOW/PHIDE")
        return
    end

    msg("Unknown /smmpos command.")
end
