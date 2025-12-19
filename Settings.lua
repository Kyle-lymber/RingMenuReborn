--[[
    RingMenu Reborn - Settings Panel
    Configuration interface for radial wheel customization
]]

local ADDON_NAME, Addon = ...

-------------------------------------------------------------------------------
-- Binding Helpers
-------------------------------------------------------------------------------

local function GetWheelBindCommand(idx)
    return "CLICK RadialWheelToggle" .. idx .. ":LeftButton"
end

local function GetWheelBoundKeys(idx)
    local cmd = GetWheelBindCommand(idx)
    return { GetBindingKey(cmd) }
end

local function ClearWheelBindings(idx)
    for _, key in ipairs(GetWheelBoundKeys(idx)) do
        SetBinding(key)
    end
end

local function GetBindingDisplayText(idx)
    local keys = GetWheelBoundKeys(idx)
    return (#keys > 0) and GetBindingText(keys[1]) or "(unbound)"
end

local function GetWheelSelectorText(idx)
    local profile = RadialWheelProfiles[idx]
    local keyText = GetBindingDisplayText(idx)
    if profile.label and #profile.label > 0 then
        return keyText .. ": " .. profile.label
    end
    return keyText
end

local function RestoreAllBindings()
    for i = 1, RadialWheelDB.wheelCount do
        local profile = RadialWheelProfiles[i]
        if profile.binding then
            SetBinding(profile.binding, GetWheelBindCommand(i))
        end
    end
    if AttemptToSaveBindings then
        AttemptToSaveBindings(GetCurrentBindingSet())
    else
        SaveBindings(GetCurrentBindingSet())
    end
end

-------------------------------------------------------------------------------
-- Panel Actions
-------------------------------------------------------------------------------

local function OnAddWheel()
    PlaySound(624)
    local panel = _G["RadialWheelSettingsPanel"]
    local idx = Addon:CreateWheel()
    panel.activeWheel = idx
    Addon:BuildAllWheels()
    panel.UpdateWidgets()
end

local function OnRemoveWheel()
    PlaySound(624)
    if RadialWheelDB.wheelCount <= 1 then
        PlaySound(847)
        return
    end

    local panel = _G["RadialWheelSettingsPanel"]
    ClearWheelBindings(panel.activeWheel)
    Addon:DestroyWheel(panel.activeWheel)

    if panel.activeWheel > RadialWheelDB.wheelCount then
        panel.activeWheel = RadialWheelDB.wheelCount
    end

    RestoreAllBindings()
    Addon:BuildAllWheels()
    panel.UpdateWidgets()
end

-- Expose for XML
function RadialWheelPanel_AddWheel()
    OnAddWheel()
end

function RadialWheelPanel_RemoveWheel()
    OnRemoveWheel()
end

-------------------------------------------------------------------------------
-- Widget Definitions
-------------------------------------------------------------------------------

local WIDGET_SPECS = {
    {
        id = "binding",
        title = "Key Binding",
        kind = "keybind",
    },
    {
        id = "label",
        title = "Label",
        kind = "textbox",
    },
    {
        id = "slotStart",
        title = "Starting Slot",
        kind = "numeric",
        hint = "The action bar slot for the first button.",
    },
    {
        id = "slotCount",
        title = "Button Count",
        kind = "range",
        low = 1, high = 24, step = 1, suffix = "",
    },
    {
        id = "quickCast",
        title = "Quick Cast",
        kind = "toggle",
        hint = "Hold key to show wheel, release to activate the button under cursor.",
    },
    {
        id = "dismissOnUse",
        title = "Dismiss on Use",
        kind = "toggle",
    },
    {
        id = "bgTint",
        title = "Background Tint",
        kind = "colorpicker",
    },
    {
        id = "size",
        title = "Wheel Radius",
        kind = "range",
        low = 0, high = 300, step = 1, suffix = " px",
    },
    {
        id = "rotation",
        title = "Rotation Offset",
        kind = "range",
        low = 0, high = 360, step = 1, suffix = "°",
    },
}

-------------------------------------------------------------------------------
-- Panel Setup
-------------------------------------------------------------------------------

function Addon:SetupSettingsPanel()
    local panel = _G["RadialWheelSettingsPanel"]
    local configArea = _G["RadialWheelSettingsPanelConfig"]
    local selector = _G["RadialWheelSettingsPanelSelector"]

    panel.activeWheel = 1

    -- Selector dropdown setup
    selector.OnSelect = function(self, idx)
        panel.activeWheel = idx
        panel.UpdateWidgets()
    end

    selector.PopulateMenu = function()
        for i = 1, RadialWheelDB.wheelCount do
            local info = UIDropDownMenu_CreateInfo()
            info.text = GetWheelSelectorText(i)
            info.value = i
            info.checked = (i == panel.activeWheel)
            info.func = selector.OnSelect
            info.arg1 = i
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(selector, selector.PopulateMenu)
    UIDropDownMenu_SetWidth(selector, 200)
    UIDropDownMenu_JustifyText(selector, "LEFT")
    UIDropDownMenu_SetText(selector, GetWheelSelectorText(panel.activeWheel))

    -- Widget layout helpers
    local LABEL_WIDTH = 160
    local WIDGET_WIDTH = 180
    local ROW_GAP = 24

    local function AttachWidget(parent, widget)
        widget:SetParent(parent)
        if parent.lastChild then
            widget:SetPoint("TOPLEFT", parent.lastChild, "BOTTOMLEFT", 0, -ROW_GAP)
        else
            widget:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)
        end
        parent.lastChild = widget
    end

    -- Widget refresh function
    local function RefreshWidget(spec)
        local widget = spec.widget
        if not widget then return end

        local profile = RadialWheelProfiles[panel.activeWheel]
        local val = profile[spec.id]

        if spec.kind == "range" then
            widget:SetValue(val)
        elseif spec.kind == "toggle" then
            widget:SetChecked(val)
        elseif spec.kind == "textbox" then
            widget:SetText(val or "")
            widget:SetCursorPosition(0)
            widget:ClearFocus()
        elseif spec.kind == "numeric" then
            widget:SetText(val or 0)
            widget:SetCursorPosition(0)
            widget:ClearFocus()
        elseif spec.kind == "keybind" then
            widget:SetText(GetBindingDisplayText(panel.activeWheel))
        elseif spec.kind == "colorpicker" then
            widget.swatch:SetVertexColor(val.red, val.green, val.blue, val.alpha)
        end
    end

    -- Value change handler
    local function OnValueChanged(spec, newVal)
        local profile = RadialWheelProfiles[panel.activeWheel]
        profile[spec.id] = newVal
        Addon:BuildWheel(panel.activeWheel)
        UIDropDownMenu_SetText(selector, GetWheelSelectorText(panel.activeWheel))
    end

    -- Slider callback
    local function SliderChanged(self, val, fromUser)
        local spec = self.spec
        local label = _G[self:GetName() .. "Value"]
        label:SetText(val .. (spec.suffix or ""))
        if fromUser then
            OnValueChanged(spec, val)
        end
    end

    -- Toggle callback
    local function ToggleClicked(self)
        OnValueChanged(self.spec, self:GetChecked() and true or false)
    end

    -- Text input callback
    local function TextChanged(self, fromUser)
        if fromUser then
            OnValueChanged(self.spec, self:GetText())
        end
    end

    -- Numeric input callback
    local function NumericChanged(self, fromUser)
        if fromUser then
            OnValueChanged(self.spec, tonumber(self:GetText()))
        end
    end

    -- Keybind capture
    local function KeybindKeyDown(self, key)
        if not self.capturing then return end

        -- Skip modifier-only presses
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
            return
        end

        -- Cancel on escape
        if key == "ESCAPE" then
            self.capturing = false
            self:SetText(GetBindingDisplayText(panel.activeWheel))
            self:EnableKeyboard(false)
            return
        end

        -- Build modifier string
        local combo = ""
        if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
        if IsControlKeyDown() then combo = combo .. "CTRL-" end
        if IsAltKeyDown() then combo = combo .. "ALT-" end
        combo = combo .. key

        -- Apply binding
        ClearWheelBindings(panel.activeWheel)
        SetBinding(combo, GetWheelBindCommand(panel.activeWheel))

        if AttemptToSaveBindings then
            AttemptToSaveBindings(GetCurrentBindingSet())
        else
            SaveBindings(GetCurrentBindingSet())
        end

        OnValueChanged(self.spec, combo)

        self.capturing = false
        self:SetText(GetBindingDisplayText(panel.activeWheel))
        self:EnableKeyboard(false)
    end

    local function KeybindClicked(self)
        if self.capturing then
            self.capturing = false
            self:SetText(GetBindingDisplayText(panel.activeWheel))
            self:EnableKeyboard(false)
        else
            self.capturing = true
            self:SetText("Press key...")
            self:EnableKeyboard(true)
        end
    end

    -- Color picker callback
    local function ColorClicked(self)
        local spec = self.spec
        local profile = RadialWheelProfiles[panel.activeWheel]
        local tint = profile[spec.id]

        ColorPickerFrame:SetColorRGB(tint.red, tint.green, tint.blue)
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = tint.alpha
        ColorPickerFrame.previousValues = { tint.red, tint.green, tint.blue, tint.alpha }

        local function ColorCallback(restore)
            local newTint = {}
            if restore then
                newTint.red, newTint.green, newTint.blue, newTint.alpha = unpack(restore)
            else
                newTint.red, newTint.green, newTint.blue = ColorPickerFrame:GetColorRGB()
                newTint.alpha = OpacitySliderFrame:GetValue()
            end
            spec.widget.swatch:SetVertexColor(newTint.red, newTint.green, newTint.blue, newTint.alpha)
            OnValueChanged(spec, newTint)
        end

        ColorPickerFrame.func = ColorCallback
        ColorPickerFrame.opacityFunc = ColorCallback
        ColorPickerFrame.cancelFunc = ColorCallback
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end

    -- Build all widgets
    for _, spec in ipairs(WIDGET_SPECS) do
        local lbl = configArea:CreateFontString(configArea:GetName() .. "Lbl" .. spec.id, "ARTWORK", "GameFontNormal")
        lbl:SetText(spec.title)
        lbl:SetWidth(LABEL_WIDTH)
        lbl:SetJustifyH("LEFT")
        AttachWidget(configArea, lbl)

        local widget

        if spec.kind == "range" then
            widget = CreateFrame("Slider", configArea:GetName() .. "Ctrl" .. spec.id, configArea, "BackdropTemplate")
            widget:SetPoint("LEFT", lbl, "RIGHT", 0, 0)
            widget:SetWidth(WIDGET_WIDTH)
            widget:SetHeight(17)
            widget:SetOrientation("HORIZONTAL")
            widget:SetBackdrop({
                bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                tile = true, tileSize = 8, edgeSize = 8,
                insets = { left = 3, right = 3, top = 6, bottom = 6 }
            })
            widget:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
            widget:SetMinMaxValues(spec.low, spec.high)
            if spec.step then
                widget:SetValueStep(spec.step)
                widget:SetObeyStepOnDrag(true)
            end
            widget:SetValue(spec.low)

            local valText = widget:CreateFontString(widget:GetName() .. "Value", "ARTWORK", "GameFontHighlightSmall")
            valText:SetPoint("TOP", widget, "BOTTOM", 0, 0)

            local minText = widget:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            minText:SetPoint("TOPLEFT", widget, "BOTTOMLEFT", 0, 0)
            minText:SetText(spec.low .. (spec.suffix or ""))

            local maxText = widget:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            maxText:SetPoint("TOPRIGHT", widget, "BOTTOMRIGHT", 0, 0)
            maxText:SetText(spec.high .. (spec.suffix or ""))

            widget:SetScript("OnValueChanged", SliderChanged)

        elseif spec.kind == "toggle" then
            widget = CreateFrame("CheckButton", configArea:GetName() .. "Ctrl" .. spec.id, configArea)
            widget:SetSize(26, 26)
            widget:SetPoint("LEFT", lbl, "RIGHT", -2, 0)
            widget:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
            widget:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
            widget:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
            widget:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
            widget:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
            widget:SetScript("OnClick", ToggleClicked)

        elseif spec.kind == "textbox" then
            widget = CreateFrame("EditBox", configArea:GetName() .. "Ctrl" .. spec.id, configArea, "InputBoxTemplate")
            widget:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
            widget:SetWidth(WIDGET_WIDTH - 6)
            widget:SetHeight(20)
            widget:SetAutoFocus(false)
            widget:SetScript("OnTextChanged", TextChanged)

        elseif spec.kind == "numeric" then
            widget = CreateFrame("EditBox", configArea:GetName() .. "Ctrl" .. spec.id, configArea, "InputBoxTemplate")
            widget:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
            widget:SetWidth(40)
            widget:SetHeight(20)
            widget:SetAutoFocus(false)
            widget:SetNumeric(true)
            widget:SetMaxLetters(3)
            widget:SetScript("OnTextChanged", NumericChanged)

        elseif spec.kind == "keybind" then
            widget = CreateFrame("Button", configArea:GetName() .. "Ctrl" .. spec.id, configArea, "UIPanelButtonTemplate")
            widget:SetPoint("LEFT", lbl, "RIGHT", -1, 0)
            widget:SetWidth(WIDGET_WIDTH + 2)
            widget:SetHeight(22)
            widget:SetText(GetBindingDisplayText(panel.activeWheel))
            widget.capturing = false
            widget:SetScript("OnClick", KeybindClicked)
            widget:SetScript("OnKeyDown", KeybindKeyDown)
            widget:EnableKeyboard(false)

        elseif spec.kind == "colorpicker" then
            widget = CreateFrame("Button", configArea:GetName() .. "Ctrl" .. spec.id, configArea)
            widget:SetPoint("LEFT", lbl, "RIGHT", 2, 0)
            widget:SetSize(18, 18)

            local bg = widget:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.8, 0.8, 0.8, 1.0)

            widget:SetNormalTexture("Interface/ChatFrame/ChatFrameColorSwatch")
            widget.swatch = widget:GetNormalTexture()
            widget.swatch:SetAllPoints()

            widget:SetScript("OnClick", ColorClicked)
        end

        if widget then
            if spec.hint then
                widget.tooltipText = spec.hint
            end
            widget.spec = spec
            spec.widget = widget
        end
    end

    -- Panel refresh function
    panel.UpdateWidgets = function()
        UIDropDownMenu_SetText(selector, GetWheelSelectorText(panel.activeWheel))
        for _, spec in ipairs(WIDGET_SPECS) do
            RefreshWidget(spec)
        end
    end

    -- Display version in title
    local ver = C_AddOns and C_AddOns.GetAddOnMetadata("RingMenuReborn", "Version") or GetAddOnMetadata("RingMenuReborn", "Version")
    local titleText = _G["RadialWheelSettingsPanelHeader"]
    titleText:SetText("RingMenu Reborn |cFF888888v" .. ver)

    panel.name = "RingMenu Reborn"
    panel.refresh = function()
        panel.UpdateWidgets()
    end

    -- Register with Settings API
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        cat.ID = panel.name
        Settings.RegisterAddOnCategory(cat)
        Addon.settingsCategoryID = cat.ID
    else
        InterfaceOptions_AddCategory(panel)
    end
end
