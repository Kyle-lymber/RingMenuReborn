--[[
    RingMenu Reborn - Core Module
    A radial action wheel system for World of Warcraft Classic
]]

local ADDON_NAME, Addon = ...

-- Attempt to load Masque for button skinning
local MasqueLib = LibStub and LibStub("Masque", true)

-------------------------------------------------------------------------------
-- Database Defaults
-------------------------------------------------------------------------------

local DATABASE_DEFAULTS = {
    wheelCount = 1,
    multipleWheelsOpen = false,
}

local WHEEL_DEFAULTS = {
    label = nil,
    binding = nil,
    dismissOnUse = true,
    size = 100,
    rotation = 0,
    slotStart = 13,
    slotCount = 12,
    bgSize = 1.5,
    bgTint = { red = 0.0, green = 0.0, blue = 0.0, alpha = 0.5 },
}

-------------------------------------------------------------------------------
-- Internal State
-------------------------------------------------------------------------------

Addon.wheels = {}
Addon.frames = {}

-- Persisted data (initialized on load)
RadialWheelDB = RadialWheelDB or {}
RadialWheelProfiles = RadialWheelProfiles or {}

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

local function CloneTable(source)
    if type(source) ~= "table" then
        return source
    end
    local result = {}
    for key, val in pairs(source) do
        result[CloneTable(key)] = CloneTable(val)
    end
    return result
end

local function ApplyDefaults(target, defaults)
    for key, defaultVal in pairs(defaults) do
        if target[key] == nil then
            target[key] = CloneTable(defaultVal)
        end
    end
end

Addon.CloneTable = CloneTable
Addon.ApplyDefaults = ApplyDefaults

-------------------------------------------------------------------------------
-- Wheel Management
-------------------------------------------------------------------------------

function Addon:CreateWheel()
    RadialWheelDB.wheelCount = RadialWheelDB.wheelCount + 1
    local idx = RadialWheelDB.wheelCount
    RadialWheelProfiles[idx] = CloneTable(WHEEL_DEFAULTS)
    self:BuildAllWheels()
    return idx
end

function Addon:DestroyWheel(idx)
    table.remove(RadialWheelProfiles, idx)
    RadialWheelDB.wheelCount = RadialWheelDB.wheelCount - 1
    self:BuildAllWheels()
end

function Addon:BuildWheel(idx)
    self.frames = self.frames or {}

    local profile = RadialWheelProfiles[idx]

    -- Create frame if needed
    if not self.frames[idx] then
        local container = CreateFrame("Frame", "RadialWheel" .. idx, UIParent)
        container.wheelIndex = idx
        self.frames[idx] = container

        -- Background texture layer
        local bg = container:CreateTexture(container:GetName() .. "BG", "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\AddOns\\RingMenuReborn\\RingMenuBackdrop.tga")
        container.background = bg

        -- Secure toggle handler for keybinding
        local toggle = CreateFrame("Button", "RadialWheelToggle" .. idx, container, "SecureHandlerMouseUpDownTemplate")
        toggle:SetAttribute("downbutton", "")
        toggle:SetFrameRef("GameParent", UIParent)
        toggle:SetAttribute("_onmousedown", [[
            local wheel = self:GetParent()
            local totalWheels = self:GetAttribute("totalWheels")
            local allowStacking = self:GetAttribute("allowStacking")
            local parent = self:GetFrameRef("GameParent")

            if wheel:IsShown() then
                wheel:Hide()
            else
                if not allowStacking then
                    for i = 1, totalWheels do
                        local other = self:GetFrameRef("wheel" .. i)
                        if other then other:Hide() end
                    end
                end
                local mx, my = parent:GetMousePosition()
                local px = mx * parent:GetWidth()
                local py = my * parent:GetHeight()
                wheel:SetPoint("CENTER", parent, "BOTTOMLEFT", px, py)
                wheel:Show()
            end
        ]])
        container.toggle = toggle

        container:Hide()
    end

    local container = self.frames[idx]

    -- Apply profile settings
    local dimension = 2 * profile.size * profile.bgSize
    container:SetSize(dimension, dimension)
    container.background:SetVertexColor(
        profile.bgTint.red,
        profile.bgTint.green,
        profile.bgTint.blue,
        profile.bgTint.alpha
    )
    container.toggle:SetAttribute("allowStacking", RadialWheelDB.multipleWheelsOpen)
    container:SetAttribute("dismissOnUse", profile.dismissOnUse)

    -- Create action buttons
    container.actions = container.actions or {}
    for slot = 1, (profile.slotCount or 1) do
        if not container.actions[slot] then
            local btn = CreateFrame("CheckButton", container:GetName() .. "Slot" .. slot, container, "ActionBarButtonTemplate")

            -- Register with Masque if available
            if MasqueLib then
                local group = MasqueLib:Group("RingMenuReborn")
                group:AddButton(btn)
            end

            btn.wheelIndex = idx
            btn.slotIndex = slot
            container.actions[slot] = btn

            -- Wrap click to optionally dismiss wheel
            container.toggle:WrapScript(btn, "OnClick", [[
                local wheel = self:GetParent()
                if wheel:GetAttribute("dismissOnUse") then
                    wheel:Hide()
                end
            ]])
        end

        local btn = container.actions[slot]

        -- Calculate circular position
        local theta = 2 * math.pi * (0.25 - (slot - 1) / profile.slotCount - profile.rotation / 360)
        local xPos = profile.size * math.cos(theta)
        local yPos = profile.size * math.sin(theta)

        btn:ClearAllPoints()
        btn:SetPoint("CENTER", container, "CENTER", xPos, yPos)
        btn:SetAttribute("type", "action")
        btn:SetAttribute("action", profile.slotStart + slot - 1)
        btn:Show()
    end

    -- Hide excess buttons
    for i, btn in ipairs(container.actions) do
        if i > profile.slotCount then
            btn:Hide()
        end
    end
end

function Addon:LinkWheels()
    local count = RadialWheelDB.wheelCount
    for i = 1, count do
        local container = self.frames[i]
        if container then
            for j = 1, count do
                local other = self.frames[j]
                if other then
                    container.toggle:SetFrameRef("wheel" .. j, other)
                end
            end
            container.toggle:SetAttribute("totalWheels", count)
        end
    end
end

function Addon:BuildAllWheels()
    for i = 1, RadialWheelDB.wheelCount do
        self:BuildWheel(i)
    end
    self:LinkWheels()
end

-------------------------------------------------------------------------------
-- Event Handler
-------------------------------------------------------------------------------

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == ADDON_NAME then
        -- Initialize database with defaults
        ApplyDefaults(RadialWheelDB, DATABASE_DEFAULTS)

        for i = 1, RadialWheelDB.wheelCount do
            RadialWheelProfiles[i] = RadialWheelProfiles[i] or {}
            ApplyDefaults(RadialWheelProfiles[i], WHEEL_DEFAULTS)
        end

        -- Build wheel frames
        Addon:BuildAllWheels()

        -- Initialize settings panel
        Addon:SetupSettingsPanel()
    end
end)

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------

SLASH_RADIALWHEEL1 = "/rmr"
SLASH_RADIALWHEEL2 = "/radialwheel"

SlashCmdList["RADIALWHEEL"] = function(input)
    if Settings and Settings.OpenToCategory then
        if Addon.settingsCategoryID then
            Settings.OpenToCategory(Addon.settingsCategoryID)
        end
    else
        InterfaceOptionsFrame_OpenToCategory("RingMenu Reborn")
        InterfaceOptionsFrame_OpenToCategory("RingMenu Reborn")
    end
end
