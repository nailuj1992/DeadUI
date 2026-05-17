DeadUI = DeadUI or {}
local NS = DeadUI

-- Bump `version` whenever DEFAULTS change and you want DBs to re-sync.
local DEFAULTS = {
    version = 1,
    animation = "bob",
    sound = "",                           -- selected sound path; empty until user picks one
    sounds = {},                          -- user-registered sounds: { ["Label"] = "Path\\to\\file.ogg", ... }
    text = "YOU ARE DEAD!",
    font = "Fonts\\FRIZQT__.TTF",         -- e.g. "Fonts\\MORPHEUS.TTF", "Fonts\\SKURRI.TTF", or custom "Interface\\AddOns\\DeadUI\\fonts\\MyFont.ttf"
    fontFallback = "Fonts\\FRIZQT__.TTF", -- used when `font` fails to load
    fontSize = 52,
    fontOutline = "THICKOUTLINE",         -- "", "OUTLINE", "THICKOUTLINE", "MONOCHROME"
    color = { 1, 0.1, 0.1 },              -- {r, g, b} each 0..1
    offsetY = 200,
}

local banner = CreateFrame("Frame", "DeadUIBanner", UIParent)
banner:SetSize(800, 120)
banner:SetFrameStrata("HIGH")
banner:Hide()

local text = banner:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER")

local function ApplyVisual(cfg)
    local ok = text:SetFont(cfg.font, cfg.fontSize, cfg.fontOutline)
    if not ok then
        -- fallback if font path invalid (file missing / bad TTF)
        text:SetFont(cfg.fontFallback, cfg.fontSize, cfg.fontOutline)
        print("|cffff0000[DeadUI]|r font failed to load: " ..
            tostring(cfg.font) .. " — using fallback " .. tostring(cfg.fontFallback))
    end
    text:SetTextColor(cfg.color[1], cfg.color[2], cfg.color[3])
    text:SetText(cfg.text)
    banner:ClearAllPoints()
    banner:SetPoint("CENTER", UIParent, "CENTER", 0, cfg.offsetY)
end

-- Animation presets. Each fn(self, t) sets scale/alpha/offset based on elapsed time t (post-intro).
-- Return nothing. Intro fade-in (0..1s) handled outside.
local ANIMATIONS = {
    pulse = function(self, t)
        local s = math.sin(t * 2.5)
        self:SetScale(1.0 + 0.15 * s)
        self:SetAlpha(0.75 + 0.25 * s)
    end,
    flash = function(self, t)
        local on = (math.floor(t * 2) % 2 == 0)
        self:SetScale(1.0)
        self:SetAlpha(on and 1.0 or 0.2)
    end,
    bob = function(self, t)
        local y = math.sin(t * 2) * 25
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, DeadUIDB.offsetY + y)
        self:SetScale(1.0)
        self:SetAlpha(1.0)
    end,
    shake = function(self, t)
        local x = math.sin(t * 30) * 8 + math.sin(t * 17) * 4
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x, DeadUIDB.offsetY)
        self:SetScale(1.0)
        self:SetAlpha(1.0)
    end,
    grow = function(self, t)
        local cycle = t % 2
        local p = cycle / 2
        self:SetScale(0.8 + p * 0.8)
        self:SetAlpha(1.0 - p)
    end,
    static = function(self, t)
        self:SetScale(1.0)
        self:SetAlpha(1.0)
    end,
}

local introTime = 0.6
local elapsed = 0

banner:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < introTime then
        local p = elapsed / introTime
        self:SetScale(0.4 + 0.6 * p)
        self:SetAlpha(p)
        return
    end
    local fn = ANIMATIONS[DeadUIDB.animation] or ANIMATIONS.pulse
    fn(self, elapsed - introTime)
end)

local function ShowBanner()
    if banner:IsShown() then return end
    ApplyVisual(DeadUIDB)
    elapsed = 0
    banner:SetScale(0.4)
    banner:SetAlpha(0)
    banner:Show()
end

local function HideBanner()
    banner:Hide()
end

local SOUND_DIR = "Interface\\Sounds\\"
local SOUND_EXT = ".ogg"

local function SoundLabelFromName(name)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("^.*[\\/]", "")
    name = name:gsub("%.[^.]+$", "")
    return name
end

local function NormalizeSoundPath(name)
    return SOUND_DIR .. SoundLabelFromName(name) .. SOUND_EXT
end

-- Public API for options.lua / runtime callers.
NS.DEFAULTS = DEFAULTS
NS.ANIMATIONS = ANIMATIONS
NS.NormalizeSoundPath = NormalizeSoundPath
NS.SoundLabelFromName = SoundLabelFromName
function NS:RefreshVisual()
    if banner:IsShown() then ApplyVisual(DeadUIDB) end
end

function NS:RestartAnimation()
    if banner:IsShown() then elapsed = 0 end
end

function NS:IsShown() return banner:IsShown() end

function NS:Test()
    if DeadUIDB.sound and DeadUIDB.sound ~= "" then
        PlaySoundFile(DeadUIDB.sound, "Master")
    end
    ShowBanner()
end

-- Test mode: banner stays visible regardless of dead/alive state. Transient (not persisted).
NS.testMode = false
function NS:SetTestMode(enabled)
    NS.testMode = enabled and true or false
    if NS.testMode then
        ShowBanner()
    elseif not UnitIsDeadOrGhost("player") then
        HideBanner()
    end
end

function NS:IsTestMode() return NS.testMode end

function NS:Hide() HideBanner() end

local function IsDead()
    return UnitIsDeadOrGhost("player")
end

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, vv in pairs(v) do t[k] = deepCopy(vv) end
    return t
end

local function InitDB()
    DeadUIDB = DeadUIDB or {}
    -- Version mismatch → overwrite all keys from DEFAULTS (preserves user runtime tweaks of new fields by re-seeding from code).
    if DeadUIDB.version ~= DEFAULTS.version then
        for k, v in pairs(DEFAULTS) do DeadUIDB[k] = deepCopy(v) end
    else
        -- Same version → only fill missing keys (additive).
        for k, v in pairs(DEFAULTS) do
            if DeadUIDB[k] == nil then DeadUIDB[k] = deepCopy(v) end
        end
    end
end

function NS:ResetDB()
    DeadUIDB = nil
    InitDB()
    if banner:IsShown() then ApplyVisual(DeadUIDB) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_DEAD")
ev:RegisterEvent("PLAYER_ALIVE")
ev:RegisterEvent("PLAYER_UNGHOST")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DeadUI" then
        InitDB()
    elseif event == "PLAYER_DEAD" then
        if DeadUIDB.sound and DeadUIDB.sound ~= "" then
            PlaySoundFile(DeadUIDB.sound, "Master")
        end
        print("|cffff0000[DeadUI]|r You have died!")
        ShowBanner()
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        if IsDead() or NS.testMode then ShowBanner() else HideBanner() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitDB()
        if IsDead() or NS.testMode then ShowBanner() else HideBanner() end
    end
end)
