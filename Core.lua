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
    quickCast = false,  -- Hold key, release to activate hovered button
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
Addon.activeQuickCast = nil  -- Tracks which wheel is in quick cast mode

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
-- Quick Cast Helpers
-------------------------------------------------------------------------------

-- Calculate which button index the mouse is pointing at based on angle from center
local function GetHoveredSlot(container, profile)
    local centerX, centerY = container:GetCenter()
    local mouseX, mouseY = GetCursorPosition()
    local scale = container:GetEffectiveScale()

    -- Adjust for UI scale
    mouseX = mouseX / scale
    mouseY = mouseY / scale

    -- Vector from center to mouse
    local dx = mouseX - centerX
    local dy = mouseY - centerY

    -- Check if mouse is too close to center (dead zone)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 20 then
        return nil
    end

    -- Calculate angle (atan2 gives angle from positive X axis)
    local mouseAngle = math.atan2(dy, dx)

    -- Convert to 0-2pi range
    if mouseAngle < 0 then
        mouseAngle = mouseAngle + 2 * math.pi
    end

    -- Calculate which slot this angle corresponds to
    -- Buttons start at top (90 degrees / pi/2) and go clockwise
    -- The formula mirrors how buttons are positioned in BuildWheel
    local slotCount = profile.slotCount
    local rotationRad = profile.rotation * math.pi / 180

    -- Normalize angle relative to first button position
    -- First button is at angle = 2*pi*(0.25 - rotation/360) = pi/2 - rotationRad
    local firstButtonAngle = math.pi / 2 - rotationRad

    -- Calculate angular difference
    local angleDiff = firstButtonAngle - mouseAngle

    -- Normalize to 0-2pi
    while angleDiff < 0 do angleDiff = angleDiff + 2 * math.pi end
    while angleDiff >= 2 * math.pi do angleDiff = angleDiff - 2 * math.pi end

    -- Convert to slot index (each slot spans 2*pi/slotCount radians)
    local slotAngle = 2 * math.pi / slotCount
    local slot = math.floor(angleDiff / slotAngle) + 1

    -- Clamp to valid range
    if slot < 1 then slot = 1 end
    if slot > slotCount then slot = slotCount end

    return slot
end

-- Update visual highlight on hovered button
local function UpdateQuickCastHighlight(container, profile, hoveredSlot)
    if not container.actions then return end

    for i, btn in ipairs(container.actions) do
        if i <= profile.slotCount then
            if i == hoveredSlot then
                -- Highlight the hovered button
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end
    end
end

-- Clear all highlights
local function ClearQuickCastHighlight(container)
    if not container.actions then return end
    for _, btn in ipairs(container.actions) do
        btn:UnlockHighlight()
    end
end

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
        -- Use SecureActionButtonTemplate to execute actions, SecureHandlerBaseTemplate for SetFrameRef
        local toggle = CreateFrame("Button", "RadialWheelToggle" .. idx, container, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
        toggle:SetFrameRef("GameParent", UIParent)
        toggle:SetFrameRef("wheel", container)
        toggle:RegisterForClicks("AnyDown", "AnyUp")

        -- PreClick runs before the action executes
        -- On DOWN click: show the wheel, clear action type so nothing fires
        -- On UP click: if quick cast, set action type so the hovered action fires
        SecureHandlerWrapScript(toggle, "PreClick", toggle, [[
            local wheel = self:GetParent()
            local parent = self:GetFrameRef("GameParent")
            local down = down  -- 'down' is true for key press, false for key release

            if down then
                -- Key pressed - show the wheel
                local totalWheels = self:GetAttribute("totalWheels")
                local allowStacking = self:GetAttribute("allowStacking")

                if wheel:IsShown() then
                    -- If not quick cast mode, toggle off
                    if not self:GetAttribute("quickCast") then
                        wheel:Hide()
                    end
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
                    wheel:ClearAllPoints()
                    wheel:SetPoint("CENTER", parent, "BOTTOMLEFT", px, py)
                    wheel:Show()
                end

                -- Clear action so nothing fires on key down
                self:SetAttribute("type", nil)
                self:SetAttribute("action", nil)
            else
                -- Key released
                if self:GetAttribute("quickCast") and wheel:IsShown() then
                    -- Get the currently hovered slot and set up the action
                    local hoveredSlot = self:GetAttribute("quickcastslot")
                    if hoveredSlot then
                        local btn = self:GetFrameRef("slot" .. hoveredSlot)
                        if btn then
                            local actionSlot = btn:GetAttribute("action")
                            if actionSlot then
                                self:SetAttribute("type", "action")
                                self:SetAttribute("action", actionSlot)
                            end
                        end
                    end
                    wheel:Hide()
                else
                    -- Not quick cast mode - don't fire action on release
                    self:SetAttribute("type", nil)
                    self:SetAttribute("action", nil)
                end
            end
        ]])

        -- PostClick runs after the action - clear the action attributes
        SecureHandlerWrapScript(toggle, "PostClick", toggle, [[
            self:SetAttribute("type", nil)
            self:SetAttribute("action", nil)
        ]])

        container.toggle = toggle

        -- OnUpdate for quick cast hover tracking (runs in insecure context)
        container:SetScript("OnUpdate", function(self)
            if not self:IsShown() then return end

            local wheelIdx = self.wheelIndex
            local profile = RadialWheelProfiles[wheelIdx]
            if not profile or not profile.quickCast then
                ClearQuickCastHighlight(self)
                return
            end

            local slot = GetHoveredSlot(self, profile)

            -- Update the toggle button's attribute so PreClick can read it on key release
            self.toggle:SetAttribute("quickcastslot", slot)

            UpdateQuickCastHighlight(self, profile, slot)
        end)

        -- Clear highlights when hidden
        container:SetScript("OnHide", function(self)
            ClearQuickCastHighlight(self)
            self.toggle:SetAttribute("quickcastslot", nil)
        end)

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
    container.toggle:SetAttribute("quickCast", profile.quickCast)
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

        -- Add frame reference for secure quick cast activation
        container.toggle:SetFrameRef("slot" .. slot, btn)
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
