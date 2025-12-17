local RingMenuReborn_AddonName, RingMenuReborn = ...

local function getRingBindingCommand(ringID)
    local ringFrame = RingMenuReborn.ringFrame[ringID]
    local toggleButton = ringFrame.toggleButton
    return "CLICK " .. toggleButton:GetName() .. ":LeftButton"
end

local function getRingBindingKeyBinds(ringID)
    local command = getRingBindingCommand(ringID)
    return { GetBindingKey(command) }
end

local function unbindAllRingBindingKeyBinds(ringID)
    local keyBinds = getRingBindingKeyBinds(ringID)
    for _, keyBind in ipairs(keyBinds) do
        SetBinding(keyBind)
    end
end

local function getRingBindingKeyBindsText(ringID)
    local keyBinds = getRingBindingKeyBinds(ringID)
    if #keyBinds > 0 then
        return GetBindingText(keyBinds[1])
    else
        return "(not bound)"
    end
end

local function getRingDropdownText(ringID)
    local ringName = RingMenuReborn_ringConfig[ringID].name
    local bindingText = getRingBindingKeyBindsText(ringID)
    if ringName and strlen(ringName) > 0 then
        return bindingText .. ": " .. ringName
    else
        return bindingText
    end
end

local function restoreAllSavedKeyBinds()
    for ringID = 1, RingMenuReborn_globalConfig.numRings do
        local ringConfig = RingMenuReborn_ringConfig[ringID]
        if ringConfig.keyBind then
            SetBinding(ringConfig.keyBind, getRingBindingCommand(ringID))
        end
    end
    if AttemptToSaveBindings then
        AttemptToSaveBindings(GetCurrentBindingSet())
    else
        SaveBindings(GetCurrentBindingSet())
    end
end

function RingMenuRebornOptionsPanel_AddRing()
    PlaySound(624) -- GAMEGENERICBUTTONPRESS
    local ringPanel = _G["RingMenuRebornOptionsPanelRingConfig"]
    local ringID = RingMenuReborn_AddRing()
    RingMenuRebornOptionsPanel.currentRingID = ringID
    RingMenuReborn_UpdateAllRings()
    ringPanel.refresh()
end

function RingMenuRebornOptionsPanel_RemoveRing()
    PlaySound(624) -- GAMEGENERICBUTTONPRESS
    if RingMenuReborn_globalConfig.numRings <= 1 then
        PlaySound(847) -- igQuestFailed
        return
    end

    local ringPanel = _G["RingMenuRebornOptionsPanelRingConfig"]

    unbindAllRingBindingKeyBinds(RingMenuRebornOptionsPanel.currentRingID)
    RingMenuReborn_RemoveRing(RingMenuRebornOptionsPanel.currentRingID)
    if RingMenuRebornOptionsPanel.currentRingID > RingMenuReborn_globalConfig.numRings then
        RingMenuRebornOptionsPanel.currentRingID = RingMenuReborn_globalConfig.numRings
    end

    restoreAllSavedKeyBinds()
    RingMenuReborn_UpdateAllRings()
    ringPanel.refresh()
end

RingMenuReborn.ringConfigWidgets = {
    {
        name = "keyBind",
        label = "Key Binding",
        widgetType = "keyBind",
    },
    {
        name = "name",
        label = "Name",
        widgetType = "text",
    },
    {
        name = "firstSlot",
        label = "First Button Slot",
        widgetType = "number",
        tooltip = "The action button slot that is used for the first button in the RingMenu.",
    },
    {
        name = "numSlots",
        label = "Number of Buttons",
        widgetType = "slider",
        min = 1, max = 24, labelSuffix = "", valueStep = 1,
    },
    {
        name = "closeOnClick",
        label = "Close on Click",
        widgetType = "checkbox",
    },
    {
        name = "backdropColor",
        label = "Backdrop Color",
        widgetType = "color",
    },
    {
        name = "radius",
        label = "Radius",
        widgetType = "slider",
        min = 0, max = 300, labelSuffix = " px", valueStep = 1,
    },
    {
        name = "angle",
        label = "Angle",
        widgetType = "slider",
        min = 0, max = 360, labelSuffix = " °", valueStep = 1,
    },
}

function RingMenuRebornOptions_SetupPanel()
    local panel = _G["RingMenuRebornOptionsPanel"]
    local ringPanel = _G["RingMenuRebornOptionsPanelRingConfig"]
    local ringDropdown = _G["RingMenuRebornOptionsPanelRingDropDown"]

    -- Setup the drop down menu

    panel.currentRingID = 1

    function ringDropdown.Clicked(self, ringID, arg2, checked)
        RingMenuRebornOptionsPanel.currentRingID = ringID
        ringPanel.refresh()
    end

    function ringDropdown.Menu()
        for ringID = 1, RingMenuReborn_globalConfig.numRings do
            local info = UIDropDownMenu_CreateInfo()
            info.text = getRingDropdownText(ringID)
            info.value = ringID
            info.checked = (ringID == RingMenuRebornOptionsPanel.currentRingID)
            info.func = ringDropdown.Clicked
            info.arg1 = ringID
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(ringDropdown, ringDropdown.Menu)
    UIDropDownMenu_SetWidth(ringDropdown, 200)
    UIDropDownMenu_JustifyText(ringDropdown, "LEFT")
    UIDropDownMenu_SetText(ringDropdown, getRingDropdownText(RingMenuRebornOptionsPanel.currentRingID))

    -- Setup the per-ring configuration panel

    local function appendWidget(parent, child, rowPadding)
        child:SetParent(parent)
        if parent.lastWidget then
            child:SetPoint("TOPLEFT", parent.lastWidget, "BOTTOMLEFT", 0, -rowPadding)
        else
            child:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)
        end
        parent.lastWidget = child
    end

    local labelWidth = 160
    local widgetWidth = 180
    local columnPadding = 0
    local rowPadding = 24

    local function refreshWidget(widget)
        local widgetFrame = widget.widgetFrame
        if widgetFrame then
            local settingsTable = RingMenuReborn_ringConfig[RingMenuRebornOptionsPanel.currentRingID]
            local settingsField = widget.name
            local value = settingsTable[settingsField]
            if widget.widgetType == "slider" then
                widgetFrame:SetValue(value)
            elseif widget.widgetType == "checkbox" then
                widgetFrame:SetChecked(value)
            elseif widget.widgetType == "text" then
                widgetFrame:SetText(value or "")
                widgetFrame:SetCursorPosition(0) -- Fix to scroll the text field to the left
                widgetFrame:ClearFocus()
            elseif widget.widgetType == "number" then
                widgetFrame:SetText(value or 0)
                widgetFrame:SetCursorPosition(0) -- Fix to scroll the text field to the left
                widgetFrame:ClearFocus()
            elseif widget.widgetType == "keyBind" then
                widgetFrame:SetText(getRingBindingKeyBindsText(RingMenuRebornOptionsPanel.currentRingID))
            elseif widget.widgetType == "color" then
                local texture = widgetFrame.texture
                texture:SetVertexColor(value.r, value.g, value.b, value.a)
            else
                print("Unexpected widget type " .. widget.widgetType)
            end
        end
    end

    -- This is the method that actually updates the settings field in the RingMenuReborn_ringConfig table
    local function widgetChanged(widget, value)
        local settingsTable = RingMenuReborn_ringConfig[RingMenuRebornOptionsPanel.currentRingID]
        local settingsField = widget.name
        settingsTable[settingsField] = value
        RingMenuReborn_UpdateRing(RingMenuRebornOptionsPanel.currentRingID)

        -- Some config panel changes that should take immediate effect
        UIDropDownMenu_SetText(ringDropdown, getRingDropdownText(RingMenuRebornOptionsPanel.currentRingID))
    end

    local function sliderOnValueChanged(self, value, isUserInput)
        local widget = self.widget
        local label = _G[self:GetName() .. "Text"]
        local suffix = widget.labelSuffix or ""
        label:SetText(value .. suffix)

        if isUserInput then
            widgetChanged(widget, value)
        end
    end

    local function checkboxOnClick(self)
        local widget = self.widget
        local value = (not not self:GetChecked())
        widgetChanged(widget, value)
    end

    local function textOnValueChanged(self, isUserInput)
        if not isUserInput then
            return
        end
        local widget = self.widget
        local value = self:GetText()
        widgetChanged(widget, value)
    end

    local function numberOnValueChanged(self, isUserInput)
        if not isUserInput then
            return
        end
        local widget = self.widget
        local value = tonumber(self:GetText())
        widgetChanged(widget, value)
    end

    -- Custom keybind capture handler (replaces deprecated CustomBindingHandler)
    local function keyBindOnKeyDown(self, key)
        if not self.waitingForKey then return end

        -- Ignore modifier keys alone
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
            return
        end

        -- Handle escape to cancel
        if key == "ESCAPE" then
            self.waitingForKey = false
            self:SetText(getRingBindingKeyBindsText(RingMenuRebornOptionsPanel.currentRingID))
            self:EnableKeyboard(false)
            return
        end

        -- Build the key chord with modifiers
        local keyBind = ""
        if IsShiftKeyDown() then keyBind = keyBind .. "SHIFT-" end
        if IsControlKeyDown() then keyBind = keyBind .. "CTRL-" end
        if IsAltKeyDown() then keyBind = keyBind .. "ALT-" end
        keyBind = keyBind .. key

        -- Clear old bindings and set new one
        unbindAllRingBindingKeyBinds(RingMenuRebornOptionsPanel.currentRingID)
        local command = getRingBindingCommand(RingMenuRebornOptionsPanel.currentRingID)
        SetBinding(keyBind, command)
        if AttemptToSaveBindings then
            AttemptToSaveBindings(GetCurrentBindingSet())
        else
            SaveBindings(GetCurrentBindingSet())
        end

        widgetChanged(self.widget, keyBind)

        self.waitingForKey = false
        self:SetText(getRingBindingKeyBindsText(RingMenuRebornOptionsPanel.currentRingID))
        self:EnableKeyboard(false)
    end

    local function keyBindOnClick(self)
        if self.waitingForKey then
            -- Cancel if clicked again while waiting
            self.waitingForKey = false
            self:SetText(getRingBindingKeyBindsText(RingMenuRebornOptionsPanel.currentRingID))
            self:EnableKeyboard(false)
        else
            self.waitingForKey = true
            self:SetText("Press a key...")
            self:EnableKeyboard(true)
        end
    end

    local function colorOnClick(self)
        local widget = self.widget
        local settingsTable = RingMenuReborn_ringConfig[RingMenuRebornOptionsPanel.currentRingID]
        local settingsField = widget.name
        local color = settingsTable[settingsField]

        ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = color.a
        ColorPickerFrame.previousValues = {color.r, color.g, color.b, color.a}
        local colorPickerCallback = function (restore)
            local value = {}
            if restore then
                value.r, value.g, value.b, value.a = unpack(restore)
            else
                value.r, value.g, value.b = ColorPickerFrame:GetColorRGB()
                value.a = OpacitySliderFrame:GetValue()
            end
            -- Color preview
            widget.widgetFrame.texture:SetVertexColor(value.r, value.g, value.b, value.a)
            widgetChanged(self.widget, value)
        end
        ColorPickerFrame.func = colorPickerCallback
        ColorPickerFrame.opacityFunc = colorPickerCallback
        ColorPickerFrame.cancelFunc = colorPickerCallback
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end

    for _, widget in ipairs(RingMenuReborn.ringConfigWidgets) do
        local label = ringPanel:CreateFontString(ringPanel:GetName() .. "Label" .. widget.name, "ARTWORK", "GameFontNormal")
        label:SetText(widget.label)
        label:SetWidth(labelWidth)
        label:SetJustifyH("LEFT")
        appendWidget(ringPanel, label, rowPadding)

        local widgetFrame = nil

        if widget.widgetType == "slider" then
            -- Create slider without deprecated OptionsSliderTemplate
            widgetFrame = CreateFrame("Slider", ringPanel:GetName() .. "Widget" .. widget.name, ringPanel, "BackdropTemplate")
            widgetFrame:SetPoint("LEFT", label, "RIGHT", columnPadding, 0)
            widgetFrame:SetWidth(widgetWidth)
            widgetFrame:SetHeight(17)
            widgetFrame:SetOrientation("HORIZONTAL")
            widgetFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                tile = true, tileSize = 8, edgeSize = 8,
                insets = { left = 3, right = 3, top = 6, bottom = 6 }
            })
            widgetFrame:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
            widgetFrame:SetMinMaxValues(widget.min, widget.max)
            if widget.valueStep then
                widgetFrame:SetValueStep(widget.valueStep)
                widgetFrame:SetObeyStepOnDrag(true)
            end
            widgetFrame:SetValue(widget.min)

            -- Create text label for current value
            local textLabel = widgetFrame:CreateFontString(widgetFrame:GetName() .. "Text", "ARTWORK", "GameFontHighlightSmall")
            textLabel:SetPoint("TOP", widgetFrame, "BOTTOM", 0, 0)

            -- Create low/high labels
            local lowText = widgetFrame:CreateFontString(widgetFrame:GetName() .. "Low", "ARTWORK", "GameFontHighlightSmall")
            lowText:SetPoint("TOPLEFT", widgetFrame, "BOTTOMLEFT", 0, 0)
            local highText = widgetFrame:CreateFontString(widgetFrame:GetName() .. "High", "ARTWORK", "GameFontHighlightSmall")
            highText:SetPoint("TOPRIGHT", widgetFrame, "BOTTOMRIGHT", 0, 0)

            local lowLabel = widget.min
            local highLabel = widget.max
            if widget.labelSuffix then
                lowLabel = lowLabel .. widget.labelSuffix
                highLabel = highLabel .. widget.labelSuffix
            end
            lowText:SetText(lowLabel)
            highText:SetText(highLabel)

            widgetFrame:SetScript("OnValueChanged", sliderOnValueChanged)
        elseif widget.widgetType == "checkbox" then
            -- Create checkbox without deprecated OptionsCheckButtonTemplate
            widgetFrame = CreateFrame("CheckButton", ringPanel:GetName() .. "Widget" .. widget.name, ringPanel)
            widgetFrame:SetSize(26, 26)
            widgetFrame:SetPoint("LEFT", label, "RIGHT", columnPadding - 2, 0)
            widgetFrame:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
            widgetFrame:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
            widgetFrame:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
            widgetFrame:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
            widgetFrame:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")

            widgetFrame:SetScript("OnClick", checkboxOnClick)
        elseif widget.widgetType == "text" then
            widgetFrame = CreateFrame("EditBox", ringPanel:GetName() .. "Widget" .. widget.name, ringPanel, "InputBoxTemplate")
            widgetFrame:SetPoint("LEFT", label, "RIGHT", columnPadding + 6, 0)
            widgetFrame:SetWidth(widgetWidth - 6)
            widgetFrame:SetHeight(20)
            widgetFrame:SetAutoFocus(false)

            widgetFrame:SetScript("OnTextChanged", textOnValueChanged)
        elseif widget.widgetType == "number" then
            widgetFrame = CreateFrame("EditBox", ringPanel:GetName() .. "Widget" .. widget.name, ringPanel, "InputBoxTemplate")
            widgetFrame:SetPoint("LEFT", label, "RIGHT", columnPadding + 6, 0)
            widgetFrame:SetWidth(40)
            widgetFrame:SetHeight(20)
            widgetFrame:SetAutoFocus(false)
            widgetFrame:SetNumeric(true)
            widgetFrame:SetMaxLetters(3)

            widgetFrame:SetScript("OnTextChanged", numberOnValueChanged)
        elseif widget.widgetType == "keyBind" then
            -- Create custom keybind button (replaces deprecated CustomBindingManager)
            widgetFrame = CreateFrame("Button", ringPanel:GetName() .. "Widget" .. widget.name, ringPanel, "UIPanelButtonTemplate")
            widgetFrame:SetPoint("LEFT", label, "RIGHT", columnPadding - 1, 0)
            widgetFrame:SetWidth(widgetWidth + 2)
            widgetFrame:SetHeight(22)
            widgetFrame:SetText(getRingBindingKeyBindsText(RingMenuRebornOptionsPanel.currentRingID))
            widgetFrame.waitingForKey = false

            widgetFrame:SetScript("OnClick", keyBindOnClick)
            widgetFrame:SetScript("OnKeyDown", keyBindOnKeyDown)
            widgetFrame:EnableKeyboard(false)
        elseif widget.widgetType == "color" then
            widgetFrame = CreateFrame("Button", ringPanel:GetName() .. "Widget" .. widget.name, ringPanel)
            widgetFrame:SetPoint("LEFT", label, "RIGHT", columnPadding + 2, 0)
            widgetFrame:SetSize(18, 18)

            local texture = widgetFrame:CreateTexture(nil, "BACKGROUND")
            texture:SetPoint("CENTER", widgetFrame, "CENTER")
            texture:SetSize(18, 18)
            texture:SetColorTexture(0.8, 0.8, 0.8, 1.0)

            widgetFrame:SetNormalTexture("Interface/ChatFrame/ChatFrameColorSwatch")
            local normalTexture = widgetFrame:GetNormalTexture()
            normalTexture:SetPoint("TOPLEFT", widgetFrame, "TOPLEFT")
            normalTexture:SetPoint("BOTTOMRIGHT", widgetFrame, "BOTTOMRIGHT")

            widgetFrame.texture = normalTexture
            widgetFrame:SetScript("OnClick", colorOnClick)
        else
            print("RingMenuReborn: Unrecognized widget type: " .. widget.widgetType)
        end
        if widgetFrame then
            if widget.tooltip then
                widgetFrame.tooltipText = widget.tooltip
            end
            -- Establish cross-references
            widgetFrame.widget = widget
            widget.widgetFrame = widgetFrame
        end
    end

    function ringPanel.refresh()
        UIDropDownMenu_SetText(ringDropdown, getRingDropdownText(RingMenuRebornOptionsPanel.currentRingID))
        for _, widget in ipairs(RingMenuReborn.ringConfigWidgets) do
            refreshWidget(widget)
        end
    end

    -- Display the current version in the title
    local version = C_AddOns and C_AddOns.GetAddOnMetadata("RingMenuReborn", "Version") or GetAddOnMetadata("RingMenuReborn", "Version")
    local titleLabel = _G["RingMenuRebornOptionsPanelTitle"]
    titleLabel:SetText("RingMenu Reborn |cFF888888v" .. version)

    panel.name = "RingMenu Reborn"
    panel.refresh = function (self)
        ringPanel.refresh()
    end
    -- panel.okay
    -- panel.cancel
    -- panel.default

    -- Register with the new Settings API (WoW 1.14.4+/10.0+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
        RingMenuReborn.settingsCategory = category
    else
        -- Fallback for older clients
        InterfaceOptions_AddCategory(panel)
    end
end
