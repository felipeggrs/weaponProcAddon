local api = require("api")

local weapon_proc = {
    name = "Weapon Proc",
    author = "Wagasez",
    version = "1.0",
    desc = "Display longspear proc status. Created with George"
}

local DEBUG_MODE = false

local weaponProcs = {
    -- nodachi = {
    --     statName = "melee_critical_mul",
    --     thresholdIncrease = 900,
    --     displayName = "NODACHI CRIT",
    --     color = {1, 0.3, 0.3},  -- Red
    --     cooldown = 10000,
    -- },
    spear = {
        statName = "ignore_armor",
        thresholdIncrease = 8000,
        displayName = "SPEAR PEN",
        color = {0.3, 0.7, 1},
        cooldown = 10000,  -- 10 second cooldown after proc ends
    }
}

local procBar
local procLabel

local isDragging = false
local dragOffsetX = 0
local dragOffsetY = 0

local activeProcs = {}
local lastModifierInfo = nil
local procEndTime = {}
local settings

local function DetectStatChanges()
    local modInfo = api.Unit:UnitModifierInfo("player")
    if modInfo == nil then return end

    local currentTime = api.Time:GetUiMsec()

    if lastModifierInfo ~= nil then
        for statName, currentValue in pairs(modInfo) do
            if type(currentValue) == "number" then
                local lastValue = lastModifierInfo[statName]
                if lastValue ~= nil and type(lastValue) == "number" then
                    local diff = currentValue - lastValue

                    -- proc activation
                    if diff > 0 then
                        for procName, procDef in pairs(weaponProcs) do
                            if procDef.statName == statName and diff >= procDef.thresholdIncrease then
                                if not activeProcs[procName] then
                                    activeProcs[procName] = {
                                        startTime = currentTime,
                                        displayName = procDef.displayName,
                                        color = procDef.color,
                                        statName = statName,
                                        cooldown = procDef.cooldown or 10000
                                    }
                                end
                            end
                        end
                    end

                    if diff < -50 then
                        for procName, procData in pairs(activeProcs) do
                            if procData.statName == statName then
                                procEndTime[procName] = currentTime
                                activeProcs[procName] = nil
                            end
                        end
                    end
                end
            end
        end
    end

    lastModifierInfo = modInfo
end

local function UpdateUI()
    local currentTime = api.Time:GetUiMsec()

    local spearProc = activeProcs["spear"]
    local spearDef = weaponProcs["spear"]

    if spearProc then
        procLabel:SetText(spearProc.displayName)
        procLabel.style:SetColor(spearProc.color[1], spearProc.color[2], spearProc.color[3], 1)
    else
        local endTime = procEndTime["spear"]
        if endTime then
            local elapsed = currentTime - endTime
            local cooldown = spearDef.cooldown or 10000

            if elapsed >= cooldown then
                procLabel:SetText("AVAILABLE")
                procLabel.style:SetColor(0, 1, 0, 1)
            else
                local remaining = (cooldown - elapsed) / 1000
                procLabel:SetText(string.format("%.1fs", remaining))
                procLabel.style:SetColor(1, 0.3, 0.3, 1)
            end
        else
            procLabel:SetText("AVAILABLE")
            procLabel.style:SetColor(0, 1, 0, 1)
        end
    end
end

local function UpdateBarSize()
    if not procBar or not procLabel then return end
    local width = settings.fontSize * 8
    local height = settings.fontSize + 10
    procBar:SetExtent(width, height)
    procLabel:SetExtent(width, height)
end

local function HandleDrag()
    if not procBar then return end

    if isDragging then
        local mouseX, mouseY = api.Input:GetMousePos()
        procBar:RemoveAllAnchors()
        procBar:AddAnchor("TOPLEFT", "UIParent", mouseX - dragOffsetX, mouseY - dragOffsetY)

        if not api.Input:IsShiftKeyDown() then
            isDragging = false
            settings.posX = mouseX - dragOffsetX
            settings.posY = mouseY - dragOffsetY
            api.SaveSettings()
            api.Cursor:ClearCursor()
        end
    end
end

local function OnUpdate()
    DetectStatChanges()
    UpdateUI()
    HandleDrag()
end

local function OnLoad()
    api.Log:Info("Weapon Proc v1.0 loaded")

    settings = api.GetSettings(weapon_proc.name)
    if settings.fontSize == nil then
        settings.fontSize = 14
    end

    local barWidth = settings.fontSize * 8
    local barHeight = settings.fontSize + 10

    procBar = api.Interface:CreateEmptyWindow("weaponProcBar", "UIParent")
    procBar:SetExtent(barWidth, barHeight)

    procBar.bg = procBar:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
    procBar.bg:SetTextureInfo("bg_quest")
    procBar.bg:SetColor(0, 0, 0, 0.5)  -- Semi-transparent black
    procBar.bg:AddAnchor("TOPLEFT", procBar, 0, 0)
    procBar.bg:AddAnchor("BOTTOMRIGHT", procBar, 0, 0)

    -- Position from saved settings or default to center
    local uiScale = api.Interface:GetUIScale()
    if settings.posX ~= nil and settings.posY ~= nil then
        procBar:AddAnchor("TOPLEFT", "UIParent", settings.posX * uiScale, settings.posY * uiScale)
    else
        procBar:AddAnchor("CENTER", "UIParent", 0, -150)
    end
    procBar:Show(true)

    function procBar:OnClick()
        if api.Input:IsShiftKeyDown() and not api.Input:IsControlKeyDown() then
            -- Shift+Click: Toggle dragging
            if not isDragging then
                isDragging = true
                local mouseX, mouseY = api.Input:GetMousePos()
                local barX, barY = procBar:GetOffset()
                dragOffsetX = mouseX - barX
                dragOffsetY = mouseY - barY
                api.Cursor:ClearCursor()
                api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
            else
                isDragging = false
                local mouseX, mouseY = api.Input:GetMousePos()
                settings.posX = mouseX - dragOffsetX
                settings.posY = mouseY - dragOffsetY
                api.SaveSettings()
                api.Cursor:ClearCursor()
            end
        elseif api.Input:IsControlKeyDown() and api.Input:IsShiftKeyDown() then
            -- Ctrl+Shift+Click: decrease font
            settings.fontSize = math.max(8, settings.fontSize - 2)
            procLabel.style:SetFontSize(settings.fontSize)
            UpdateBarSize()
            api.SaveSettings()
        elseif api.Input:IsControlKeyDown() then
            -- Ctrl+Click: increase font
            settings.fontSize = math.min(40, settings.fontSize + 2)
            procLabel.style:SetFontSize(settings.fontSize)
            UpdateBarSize()
            api.SaveSettings()
        end
    end
    procBar:SetHandler("OnClick", procBar.OnClick)

    -- label
    procLabel = procBar:CreateChildWidget("label", "procLabel", 0, true)
    procLabel:SetExtent(barWidth, barHeight)
    procLabel:SetText("AVAILABLE")
    procLabel:AddAnchor("TOPLEFT", procBar, "TOPLEFT", 0, 0)
    procLabel.style:SetFontSize(settings.fontSize)
    procLabel.style:SetAlign(ALIGN.CENTER)
    procLabel.style:SetShadow(true)
    procLabel.style:SetColor(0, 1, 0, 1)

    api.On("UPDATE", OnUpdate)
end

local function OnUnload()
    if procBar then
        procBar:Show(false)
        api.Interface:Free(procBar)
        procBar = nil
    end
    activeProcs = {}
    lastModifierInfo = nil
    procEndTime = {}
end

weapon_proc.OnLoad = OnLoad
weapon_proc.OnUnload = OnUnload

return weapon_proc
