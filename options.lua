local addOnName        = ...
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local addOnTitle       = GetAddOnMetadata(addOnName, "Title") or "Dead UI"
local addOnVersion     = GetAddOnMetadata(addOnName, "Version") or "1.0.0"

local expansionName    = _G
    ["EXPANSION_NAME" .. (GetExpansionLevel and GetExpansionLevel() or GetAccountExpansionLevel and GetAccountExpansionLevel() or 0)]

local SettingsLib      = LibStub and LibStub("LibEQOLSettingsMode-1.0", true)
local LSM              = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Defensive: if libs failed to load, stub the entry point.
if not SettingsLib then
    function OpenDeadUISettings()
        print("|cffff0000[DeadUI]|r settings library missing — reinstall the addon.")
    end

    return
end

local NS         = DeadUI
local DEFAULTS   = NS.DEFAULTS
local ANIMATIONS = NS.ANIMATIONS

local function Refresh()
    NS:RefreshVisual()
end

local function RestartAnim()
    NS:RestartAnimation()
end

-- Sorted animation list for dropdown.
local function GetAnimList()
    local names = {}
    for k in pairs(ANIMATIONS) do table.insert(names, k) end
    table.sort(names)
    return names
end

local function Capitalize(s)
    return s:sub(1, 1):upper() .. s:sub(2)
end

local outlineList = {
    { key = "",             label = "None" },
    { key = "OUTLINE",      label = "Thin" },
    { key = "THICKOUTLINE", label = "Thick" },
    { key = "MONOCHROME",   label = "Monochrome" },
}

local function DisableInitializerMouse(init)
    local orig = init.InitFrame
    function init:InitFrame(frame)
        if orig then orig(self, frame) end
        frame:EnableMouse(false)
    end
end

local function InitializeText(category, string, parentSection)
    local text = SettingsLib:CreateText(category, {
        name = string,
        parentSection = parentSection,
    })
    DisableInitializerMouse(text)
end

local function Register()
    local category, layout = Settings.RegisterVerticalLayoutCategory(addOnTitle)
    Settings.DEADUI_CATEGORY_ID = category:GetID()

    --------------------------------------------------------------------------------
    -- HEADER
    --------------------------------------------------------------------------------
    local name = "Version " .. addOnVersion
    if expansionName then
        name = name .. " for " .. expansionName
    end
    local headerInit = SettingsLib:CreateHeader(category, { name = name })
    DisableInitializerMouse(headerInit)
    InitializeText(category, "Here, you can configure the settings of the |cffff5555Dead UI|r addon.", nil)
    InitializeText(category,
        "The |cffff5555Dead UI|r addon plays a sound and shows an animated banner when your character dies.", nil)
    InitializeText(category,
        "The |cffff5555Dead UI|r addon is free and open source, you can find the source code on |cff00ff00Github|r.", nil)
    InitializeText(category,
        "If you have any questions or suggestions, please visit the |cffff5555Dead UI|r addon page on |cff00ff00CurseForge|r.",
        nil)

    SettingsLib:CreateCheckbox(category, {
        prefix = "DEADUI_",
        key = "deadui_test_mode",
        name = "Test Mode",
        default = false,
        get = function() return NS:IsTestMode() end,
        set = function(value)
            NS:SetTestMode(value)
            if value and DeadUIDB.sound and DeadUIDB.sound ~= "" then
                PlaySoundFile(DeadUIDB.sound, "Master")
            end
        end,
        desc = "Force the banner to stay visible regardless of dead/alive state, so you can preview changes live.",
    })

    --------------------------------------------------------------------------------
    -- ANIMATION
    --------------------------------------------------------------------------------
    local animSection = SettingsLib:CreateExpandableSection(category, {
        name = "Animation", expanded = false, colorizeTitle = false,
    })

    SettingsLib:CreateScrollDropdown(category, {
        parentSection = animSection,
        prefix = "DEADUI_",
        key = "deadui_animation",
        name = "Animation",
        default = DEFAULTS.animation,
        height = 220,
        get = function() return Capitalize(DeadUIDB.animation or DEFAULTS.animation) end,
        set = function(value)
            DeadUIDB.animation = value; RestartAnim()
        end,
        desc = "Banner animation while dead",
        generator = function(dropdown, rootDescription)
            for _, key in ipairs(GetAnimList()) do
                local label = Capitalize(key)
                rootDescription:CreateRadio(label, function()
                    return DeadUIDB.animation == key
                end, function()
                    DeadUIDB.animation = key
                    RestartAnim()
                    dropdown:SetText(label)
                end)
            end
        end,
    })

    --------------------------------------------------------------------------------
    -- TEXT
    --------------------------------------------------------------------------------
    local textSection = SettingsLib:CreateExpandableSection(category, {
        name = "Text", expanded = false, colorizeTitle = false,
    })

    SettingsLib:CreateInput(category, {
        parentSection = textSection,
        prefix = "DEADUI_",
        key = "deadui_text",
        name = "Message",
        default = DEFAULTS.text,
        get = function() return DeadUIDB.text end,
        set = function(value)
            DeadUIDB.text = value; Refresh()
        end,
        desc = "Text shown on banner",
        readonly = false,
        selectAllOnFocus = false,
        multiline = false,
    })

    -- Font picker — uses LibSharedMedia if present.
    if LSM then
        SettingsLib:CreateScrollDropdown(category, {
            parentSection = textSection,
            prefix = "DEADUI_",
            key = "deadui_font",
            name = "Font",
            default = DEFAULTS.font,
            height = 220,
            get = function()
                local fonts = LSM:HashTable(LSM.MediaType.FONT)
                for name, path in pairs(fonts) do
                    if path == DeadUIDB.font then return name end
                end
                return "Friz Quadrata TT"
            end,
            set = function(value)
                -- value here is the font NAME; convert to path
                local fonts = LSM:HashTable(LSM.MediaType.FONT)
                if fonts[value] then
                    DeadUIDB.font = fonts[value]; Refresh()
                end
            end,
            desc = "Font face for banner text",
            generator = function(dropdown, rootDescription)
                dropdown.fontPool = {}
                if not dropdown._DEADUI_FontDropdown_OnMenuClosed_hooked then
                    hooksecurefunc(dropdown, "OnMenuClosed", function()
                        for _, fd in pairs(dropdown.fontPool) do fd:Hide() end
                    end)
                    dropdown._DEADUI_FontDropdown_OnMenuClosed_hooked = true
                end
                local fonts = LSM:HashTable(LSM.MediaType.FONT)
                local sorted = {}
                for name in pairs(fonts) do
                    if name ~= "" then table.insert(sorted, name) end
                end
                table.sort(sorted)

                for index, fontName in ipairs(sorted) do
                    local fontPath = fonts[fontName]
                    local button = rootDescription:CreateRadio(fontName, function()
                        return DeadUIDB.font == fontPath
                    end, function()
                        DeadUIDB.font = fontPath
                        Refresh()
                        dropdown:SetText(fontName)
                    end)
                    button:AddInitializer(function(self)
                        local fd = dropdown.fontPool[index]
                        if not fd then
                            fd = dropdown:CreateFontString(nil, "BACKGROUND")
                            dropdown.fontPool[index] = fd
                        end
                        self.fontString:Hide()
                        fd:SetParent(self)
                        fd:SetPoint("LEFT", self.fontString, "LEFT", 0, 0)
                        fd:SetFont(fontPath, 12)
                        fd:SetText(fontName)
                        fd:Show()
                    end)
                end
            end,
        })
    end

    SettingsLib:CreateSlider(category, {
        parentSection = textSection,
        prefix = "DEADUI_",
        key = "deadui_font_size",
        name = "Font Size",
        default = DEFAULTS.fontSize,
        min = 12,
        max = 120,
        step = 1,
        formatter = function(v) return string.format("%d", v) end,
        get = function() return DeadUIDB.fontSize end,
        set = function(value)
            DeadUIDB.fontSize = tonumber(string.format("%d", value)); Refresh()
        end,
        desc = "Text size in points",
    })

    SettingsLib:CreateScrollDropdown(category, {
        parentSection = textSection,
        prefix = "DEADUI_",
        key = "deadui_outline",
        name = "Outline",
        default = DEFAULTS.fontOutline,
        height = 180,
        get = function()
            for _, e in ipairs(outlineList) do
                if e.key == DeadUIDB.fontOutline then return e.label end
            end
            return "Thick"
        end,
        set = function(value) end,
        desc = "Font outline style",
        generator = function(dropdown, rootDescription)
            for _, e in ipairs(outlineList) do
                rootDescription:CreateRadio(e.label, function()
                    return DeadUIDB.fontOutline == e.key
                end, function()
                    DeadUIDB.fontOutline = e.key
                    Refresh()
                    dropdown:SetText(e.label)
                end)
            end
        end,
    })

    SettingsLib:CreateColorOverrides(category, {
        parentSection = textSection,
        prefix = "DEADUI_",
        entries = { { label = "Text Color", key = "color" } },
        hasOpacity = false,
        getColor = function(key)
            local c = DeadUIDB[key] or DEFAULTS[key]
            return c[1], c[2], c[3], 1
        end,
        setColor = function(key, r, g, b, a)
            DeadUIDB[key] = { r, g, b }
            Refresh()
        end,
        getDefaultColor = function(key)
            local c = DEFAULTS[key]
            return c[1], c[2], c[3], 1
        end,
        colorizeLabel = true,
    })

    --------------------------------------------------------------------------------
    -- POSITION
    --------------------------------------------------------------------------------
    local posSection = SettingsLib:CreateExpandableSection(category, {
        name = "Position", expanded = false, colorizeTitle = false,
    })

    SettingsLib:CreateSlider(category, {
        parentSection = posSection,
        prefix = "DEADUI_",
        key = "deadui_offset_y",
        name = "Y Offset",
        default = DEFAULTS.offsetY,
        min = -400,
        max = 400,
        step = 1,
        formatter = function(v) return string.format("%d", v) end,
        get = function() return DeadUIDB.offsetY end,
        set = function(value)
            DeadUIDB.offsetY = tonumber(string.format("%d", value)); Refresh()
        end,
        desc = "Vertical offset from screen center (positive = up)",
    })

    --------------------------------------------------------------------------------
    -- SOUND
    --------------------------------------------------------------------------------
    local soundSection = SettingsLib:CreateExpandableSection(category, {
        name = "Sound", expanded = false, colorizeTitle = false,
    })

    -- Sources, deduped by path:
    --  1. DeadUIDB.sounds — user-managed entries (added/removed via panel).
    --  2. LSM-registered sounds — from other addons (read-only here; we can't remove them).
    local function GetMergedSounds()
        local merged = {}
        local seenPaths = {}
        local function add(label, path)
            if label and label ~= "" and path and not seenPaths[path] then
                table.insert(merged, { label, path })
                seenPaths[path] = true
            end
        end
        if type(DeadUIDB.sounds) == "table" then
            for label, path in pairs(DeadUIDB.sounds) do add(label, path) end
        end
        if LSM then
            for label, path in pairs(LSM:HashTable(LSM.MediaType.SOUND)) do
                add(label, path)
            end
        end
        table.sort(merged, function(a, b) return a[1] < b[1] end)
        return merged
    end

    SettingsLib:CreateScrollDropdown(category, {
        parentSection = soundSection,
        prefix = "DEADUI_",
        key = "deadui_sound",
        name = "Sound",
        default = DEFAULTS.sound,
        height = 260,
        get = function()
            for _, entry in ipairs(GetMergedSounds()) do
                if entry[2] == DeadUIDB.sound then return entry[1] end
            end
            return "(custom)"
        end,
        set = function(value) end,
        desc = "Select a sound to play on death. Preview plays on selection.",
        generator = function(dropdown, rootDescription)
            for _, entry in ipairs(GetMergedSounds()) do
                local label, path = entry[1], entry[2]
                rootDescription:CreateRadio(label, function()
                    return DeadUIDB.sound == path
                end, function()
                    DeadUIDB.sound = path
                    PlaySoundFile(path, "Master")
                    dropdown:SetText(label)
                end)
            end
        end,
    })

    --------------------------------------------------------------------------------
    -- CUSTOM SOUNDS (sub-block inside Sound section)
    --------------------------------------------------------------------------------
    local customHeader = SettingsLib:CreateHeader(category, {
        name = "|cffffd100Custom Sounds|r",
        parentSection = soundSection,
    })
    DisableInitializerMouse(customHeader)

    InitializeText(category,
        "Type |cffffff00Filename|r and press Enter. Files must live in |cffffff00Interface\\Sounds\\|r as |cffffff00.ogg|r.\n" ..
        "Example: Save |cff00ff00bell|r which should be located at |cff00ff00Interface\\Sounds\\bell.ogg|r",
        soundSection)

    local addSoundControl
    local soundDropdownControl
    if not NS._controlHooksInstalled then
        hooksecurefunc(LibEQOL_InputControlMixin, "Init", function(self, initializer)
            local ok, setting = pcall(function() return initializer:GetSetting() end)
            if ok and setting and setting.GetVariable and setting:GetVariable() == "DEADUI_deadui_add_sound" then
                addSoundControl = self
            end
        end)
        hooksecurefunc(LibEQOL_ScrollDropdownMixin, "Init", function(self, initializer)
            local ok, setting = pcall(function() return initializer:GetSetting() end)
            if ok and setting and setting.GetVariable and setting:GetVariable() == "DEADUI_deadui_sound" then
                soundDropdownControl = self
            end
        end)
        NS._controlHooksInstalled = true
    end

    local function ClearAddInput()
        if not addSoundControl then return end
        C_Timer.After(0, function()
            if addSoundControl and addSoundControl.SetValue then
                addSoundControl:SetValue("")
            end
        end)
    end

    local function RefreshSoundDropdown()
        if not soundDropdownControl then return end
        C_Timer.After(0, function()
            if soundDropdownControl and soundDropdownControl.RefreshDropdownText then
                soundDropdownControl:RefreshDropdownText()
            end
        end)
    end

    SettingsLib:CreateInput(category, {
        parentSection = soundSection,
        prefix = "DEADUI_",
        key = "deadui_add_sound",
        name = "Add Sound",
        default = "",
        get = function() return "" end,
        set = function(value)
            if not value or value == "" then return end
            local label = NS.SoundLabelFromName(value)
            if label == "" then
                print("|cffff0000[DeadUI]|r invalid filename")
                ClearAddInput()
                return
            end
            local path = NS.NormalizeSoundPath(value)
            DeadUIDB.sounds[label] = path
            DeadUIDB.sound = path
            print(string.format("|cffff0000[DeadUI]|r added sound: %s -> [%s] (len=%d)", label, path, #path))
            PlaySoundFile(path, "Master")
            ClearAddInput()
            RefreshSoundDropdown()
        end,
        desc = "Type filename (no path, no extension). Label = filename. Press Enter to submit.",
        readonly = false,
        selectAllOnFocus = true,
        multiline = false,
    })

    SettingsLib:CreateScrollDropdown(category, {
        parentSection = soundSection,
        prefix = "DEADUI_",
        key = "deadui_remove_sound",
        name = "Remove Sound",
        default = "",
        height = 220,
        get = function() return "(select to remove)" end,
        set = function() end,
        desc = "Click a custom sound to remove it. Only user-added entries appear here.",
        generator = function(dropdown, rootDescription)
            local hasAny = false
            local labels = {}
            for label in pairs(DeadUIDB.sounds or {}) do table.insert(labels, label) end
            table.sort(labels)
            for _, label in ipairs(labels) do
                hasAny = true
                local path = DeadUIDB.sounds[label]
                rootDescription:CreateButton(label, function()
                    DeadUIDB.sounds[label] = nil
                    if DeadUIDB.sound == path then
                        DeadUIDB.sound = DEFAULTS.sound or ""
                        print("|cffff0000[DeadUI]|r active sound was removed — assignment reset")
                    end
                    ClearAddInput()
                    RefreshSoundDropdown()
                    print("|cffff0000[DeadUI]|r removed sound: " .. label)
                end)
            end
            if not hasAny then
                rootDescription:CreateTitle("(no custom sounds yet)")
            end
        end,
    })

    Settings.RegisterAddOnCategory(category)
end

SettingsRegistrar:AddRegistrant(Register)

local deaduiActive = false
hooksecurefunc(SettingsPanel, "DisplayCategory", function(self, category)
    local header = SettingsPanel.Container.SettingsList.Header
    deaduiActive = (category:GetID() == Settings.DEADUI_CATEGORY_ID)
    if deaduiActive then
        if not header.DeadUI_ResetSettings then
            header.DeadUI_ResetSettings = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
            header.DeadUI_ResetSettings:SetPoint("LEFT", header.DefaultsButton, "LEFT", -100, 0)
            header.DeadUI_ResetSettings:SetSize(header.DefaultsButton:GetWidth() * 2, header.DefaultsButton:GetHeight())
            header.DeadUI_ResetSettings:SetText("Reset configuration")
            header.DeadUI_ResetSettings:SetFrameLevel(header.DefaultsButton:GetFrameLevel() + 10)
            header.DeadUI_ResetSettings:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:ClearLines()
                GameTooltip:SetText("Reset configuration")
                GameTooltip:Show()
            end)
            header.DeadUI_ResetSettings:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            header.DeadUI_ResetSettings:SetScript("OnClick", function()
                SettingsPanel:Hide()
                NS:ResetDB()
                print("|cffff0000[DeadUI]|r config reset to defaults")
            end)
            header.DefaultsButton:HookScript("OnShow", function(self)
                if deaduiActive then self:Hide() end
            end)
        end

        header.DeadUI_ResetSettings:Show()
        header.DefaultsButton:Hide()
    else
        if header.DeadUI_ResetSettings then
            header.DeadUI_ResetSettings:Hide()
        end
        if not header.DefaultsButton:IsShown() then
            header.DefaultsButton:Show()
        end
    end
end)

-- Global entry point (slash + AddonCompartmentFunc).
function OpenDeadUISettings()
    if Settings and Settings.DEADUI_CATEGORY_ID then
        Settings.OpenToCategory(Settings.DEADUI_CATEGORY_ID)
    else
        print("|cffff0000[DeadUI]|r settings not yet registered.")
    end
end

SLASH_DEADUI1 = "/deadui"
SLASH_DEADUI2 = "/dead"
SLASH_DEADUI3 = "/dui"
SlashCmdList["DEADUI"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd = msg:lower()
    if cmd == "config" then
        OpenDeadUISettings()
    elseif cmd == "off" then
        NS:Hide()
    elseif cmd == "test" then
        NS:Test()
    elseif cmd == "reset" then
        NS:ResetDB()
        print("|cffff0000[DeadUI]|r config reset to defaults")
    else
        print("|cffff0000[DeadUI]|r usage: /deadui [help | config | test | off | reset]")
    end
end
