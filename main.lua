local RingMenuReborn_AddonName, RingMenuReborn = ...
local Masque, MasqueVersion = LibStub("Masque", true)

local RingMenuReborn_globalConfigDefault = {
    numRings = 1,
    allowMultipleOpenRings = false,
}

local RingMenuReborn_ringConfigDefault = {
    name = nil,
    keyBind = nil,
    closeOnClick = true,
    radius = 100,
    angle = 0,
    firstSlot = 13,
    numSlots = 12,
    backdropScale = 1.5,
    backdropColor = {
        r = 0.0,
        g = 0.0,
        b = 0.0,
        a = 0.5,
    },
}

local RingMenuReborn_globalStateDefault = {
}

local RingMenuReborn_ringStateDefault = {
}

-- Global variables for settings and ring state.
-- These will be updated with actual values in ADDON_LOADED.
RingMenuReborn_globalConfig = {}
RingMenuReborn_ringConfig = {}
RingMenuReborn.globalState = {}
RingMenuReborn.ringState = {}

function RingMenuReborn_AddRing()
    RingMenuReborn_globalConfig.numRings = RingMenuReborn_globalConfig.numRings + 1
    local ringID = RingMenuReborn_globalConfig.numRings
    RingMenuReborn_ringConfig[ringID] = RingMenuReborn.deep_copy(RingMenuReborn_ringConfigDefault)
    RingMenuReborn.ringState = RingMenuReborn.deep_copy(RingMenuReborn_ringStateDefault)
    RingMenuReborn_UpdateAllRings()
    return ringID
end

function RingMenuReborn_RemoveRing(ringID)
    table.remove(RingMenuReborn_ringConfig, ringID)
    table.remove(RingMenuReborn.ringState, ringID)
    RingMenuReborn_globalConfig.numRings = RingMenuReborn_globalConfig.numRings - 1
    RingMenuReborn_UpdateAllRings()
end

function RingMenuReborn_UpdateRing(ringID)
    -- Lazy-init of the ringFrame array
    RingMenuReborn.ringFrame = RingMenuReborn.ringFrame or {}

    local config = RingMenuReborn_ringConfig[ringID] -- required for further setup

    if not RingMenuReborn.ringFrame[ringID] then
        -- Lazy-init of the ringFrame itself
        RingMenuReborn.ringFrame[ringID] = CreateFrame("Frame", "RingMenuRebornRingFrame" .. ringID, UIParent)
        local rf = RingMenuReborn.ringFrame[ringID]
        rf.ringID = ringID

        -- Backdrop texture
        rf.backdrop = rf:CreateTexture(rf:GetName() .. "Backdrop", "BACKGROUND")
        rf.backdrop:SetPoint("BOTTOMLEFT", rf, "BOTTOMLEFT")
        rf.backdrop:SetPoint("TOPRIGHT", rf, "TOPRIGHT")
        rf.backdrop:SetTexture("Interface\\AddOns\\RingMenuReborn\\RingMenuBackdrop.tga")

        -- An invisible button used as a secure handler for
        -- (a) responding to CLICK RingMenuRebornToggleRing*:LeftButton binding events on a secure path
        -- (b) running secure event responses for the ring button OnClick event
        rf.toggleButton = CreateFrame("Button", "RingMenuRebornToggleRing" .. ringID, rf, "SecureHandlerMouseUpDownTemplate")
        rf.toggleButton:SetAttribute("downbutton", "")
        rf.toggleButton:SetFrameRef("UIParent", UIParent)
        rf.toggleButton:SetAttribute("_onmousedown", [[ -- (self, button)
            local rf = self:GetParent()
            local numRings = self:GetAttribute("numRings")
            local allowMultipleOpenRings = self:GetAttribute("allowMultipleOpenRings")
            local UIParent = self:GetFrameRef("UIParent")

            if rf:IsShown() then
                rf:Hide()
            else
                 if not allowMultipleOpenRings then
                    for ringID = 1, numRings do
                        local rfOther = self:GetFrameRef("ringFrame" .. ringID)
                        if rfOther then
                            rfOther:Hide()
                        end
                    end
                end
                local relx, rely = UIParent:GetMousePosition()
                local x = relx * UIParent:GetWidth()
                local y = rely * UIParent:GetHeight()
                rf:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
                rf:Show()
            end
        ]])

        rf:Hide()
    end
    local rf = RingMenuReborn.ringFrame[ringID]

    local frameSize = 2 * config.radius * config.backdropScale
    rf:SetSize(frameSize, frameSize)
    rf.backdrop:SetVertexColor(config.backdropColor.r, config.backdropColor.g, config.backdropColor.b, config.backdropColor.a)
    rf.toggleButton:SetAttribute("allowMultipleOpenRings", RingMenuReborn_globalConfig.allowMultipleOpenRings)
    rf:SetAttribute("closeOnClick", config.closeOnClick)

    -- Lazy-init this ringFrame's buttons
    rf.button = rf.button or {}
    for buttonID = 1, (config.numSlots or 1) do
        if not rf.button[buttonID] then
            rf.button[buttonID] = CreateFrame("CheckButton", "RingMenuRebornRingFrame" .. ringID .. "Button" .. buttonID, rf, "ActionBarButtonTemplate")
            if Masque then
                local masqueRing = Masque:Group("RingMenuReborn")
                masqueRing:AddButton(rf.button[buttonID])
            end
            local button = rf.button[buttonID]
            button.ringID = ringID
            button.buttonID = buttonID

            rf.toggleButton:WrapScript(button, "OnClick", [[ -- (self, button, down)
                local rf = self:GetParent()
                local closeOnClick = rf:GetAttribute("closeOnClick")
                if closeOnClick then
                    rf:Hide()
                end
            ]])
        end
        local button = rf.button[buttonID]

        local angle = 2 * math.pi * (0.25 - (buttonID - 1) / config.numSlots - config.angle / 360.0)
        local posX = config.radius * math.cos(angle)
        local posY = config.radius * math.sin(angle)
        button:SetPoint("CENTER", rf, "CENTER", posX, posY)
        button:SetAttribute("type", "action")
        local firstSlot = config.firstSlot or 1
        local buttonSlot = firstSlot + buttonID - 1
        button:SetAttribute("action", buttonSlot)
    end
    -- Hide unused buttons
    for id, button in ipairs(rf.button) do
        if id > config.numSlots then
            button:Hide()
        end
    end
end

function RingMenuReborn_UpdateRingCrossReferences()
    for ringID = 1, RingMenuReborn_globalConfig.numRings do
        local rf = RingMenuReborn.ringFrame[ringID]
        for ringIDOther = 1, RingMenuReborn_globalConfig.numRings do
            local rfOther = RingMenuReborn.ringFrame[ringIDOther]
            if rfOther then
                rf.toggleButton:SetFrameRef("RingFrame" .. ringIDOther, rfOther)
            end
        end
        rf.toggleButton:SetAttribute("numRings", RingMenuReborn_globalConfig.numRings)
    end
end

function RingMenuReborn_UpdateAllRings()
    for ringID = 1, RingMenuReborn_globalConfig.numRings do
        RingMenuReborn_UpdateRing(ringID)
    end
    RingMenuReborn_UpdateRingCrossReferences()
end

-- The main frame is used only to respond to global events
RingMenuReborn.mainFrame = CreateFrame("Frame")
RingMenuReborn.mainFrame.OnEvent = function (self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == RingMenuReborn_AddonName then
        -- Update empty fields in settings with default values
        RingMenuReborn_globalConfig = RingMenuReborn_globalConfig or {}
        RingMenuReborn.update_with_defaults(RingMenuReborn_globalConfig, RingMenuReborn_globalConfigDefault)
        for ringID = 1, RingMenuReborn_globalConfig.numRings do
            RingMenuReborn_ringConfig[ringID] = RingMenuReborn_ringConfig[ringID] or {}
            RingMenuReborn.update_with_defaults(RingMenuReborn_ringConfig[ringID], RingMenuReborn_ringConfigDefault)
        end

        -- Init state
        RingMenuReborn.globalState = RingMenuReborn.deep_copy(RingMenuReborn_globalStateDefault)
        for ringID = 1, RingMenuReborn_globalConfig.numRings do
            RingMenuReborn.ringState[ringID] = RingMenuReborn.deep_copy(RingMenuReborn_ringStateDefault)
        end

        RingMenuReborn_UpdateAllRings()

        -- Init options panel
        RingMenuRebornOptions_SetupPanel()
    end
end
RingMenuReborn.mainFrame:RegisterEvent("ADDON_LOADED")
RingMenuReborn.mainFrame:SetScript("OnEvent", RingMenuReborn.mainFrame.OnEvent)

SLASH_RINGMENUREBORN1 = '/rmr'
SLASH_RINGMENUREBORN2 = '/ringmenureborn'
function SlashCmdList.RINGMENUREBORN(msg, editBox)
    -- Use new Settings API if available (WoW 1.14.4+/10.0+)
    if Settings and Settings.OpenToCategory then
        if RingMenuReborn.settingsCategory then
            Settings.OpenToCategory(RingMenuReborn.settingsCategory.ID)
        end
    else
        -- Fallback for older clients
        -- Workaround: this function has to be called twice
        InterfaceOptionsFrame_OpenToCategory("RingMenu Reborn")
        InterfaceOptionsFrame_OpenToCategory("RingMenu Reborn")
    end
end
