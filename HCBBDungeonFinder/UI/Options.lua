-- Options tab (design 1i): language (with manual override, R21), minimap
-- and sound toggles, read-only protocol info rendered from Data constants.
local _, NS = ...
local UI = NS.UI
local L = NS.L

local LANGS = {
    { code = "auto", label = nil }, -- label = L["LANG_AUTO"], resolved live
    { code = "enUS", label = "English" },
    { code = "frFR", label = "Français" },
    { code = "deDE", label = "Deutsch" },
    { code = "esES", label = "Español" },
    { code = "itIT", label = "Italiano" },
}

local pane, langBtn, langLabel, mmCheck, soundCheck, hbInfo, verText
local communityLabel, discordBtn, reportBtn, presenceCheck

local function langText(code)
    for _, lang in ipairs(LANGS) do
        if lang.code == code then return lang.label or L["LANG_AUTO"] end
    end
    return L["LANG_AUTO"]
end

function UI.CreateOptions(parent)
    pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints()
    pane:Hide()

    langLabel = UI.Label(pane, "small", UI.COLOR.gold)
    langLabel:SetPoint("TOPLEFT", 6, -10)

    langBtn = UI.Button(pane, 240, 26)
    langBtn:SetPoint("TOPLEFT", 4, -26)
    local dropdown = CreateFrame("Frame", "HCBBLangDropdown", pane,
                                 "UIDropDownMenuTemplate")
    dropdown:Hide()
    UIDropDownMenu_Initialize(dropdown, function()
        for _, lang in ipairs(LANGS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = lang.label or L["LANG_AUTO"]
            info.checked = NS.addon.db.global.lang == lang.code
            info.func = function()
                NS.addon.db.global.lang = lang.code
                NS.SetLanguage(lang.code) -- applies instantly (design 1i)
            end
            UIDropDownMenu_AddButton(info)
        end
    end, "MENU")
    langBtn:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, dropdown, self, 0, 0)
    end)

    mmCheck = UI.Check(pane)
    mmCheck:SetPoint("TOPLEFT", 6, -70)
    mmCheck:SetScript("OnClick", function(self)
        NS.addon.db.global.minimap.hide = not self:GetChecked()
        if UI.UpdateMinimap then UI.UpdateMinimap() end
    end)

    soundCheck = UI.Check(pane)
    soundCheck:SetPoint("TOPLEFT", 6, -100)
    soundCheck:SetScript("OnClick", function(self)
        NS.addon.db.global.sound = self:GetChecked() and true or false
    end)

    -- Checked = visible, so the stored flag is inverted (hidePresence).
    -- Presence:SetHidden owns the side effects: drop ourselves from our own
    -- list at once when hiding, re-announce at once when unhiding.
    presenceCheck = UI.Check(pane)
    presenceCheck:SetPoint("TOPLEFT", 6, -130) -- keep the 30 px checkbox rhythm
    presenceCheck:SetScript("OnClick", function(self)
        NS.Presence:SetHidden(not self:GetChecked())
    end)

    hbInfo = UI.Label(pane, "small", UI.COLOR.muted)
    hbInfo:SetPoint("TOPLEFT", 8, -162)

    communityLabel = UI.Label(pane, "small", UI.COLOR.gold)
    communityLabel:SetPoint("TOPLEFT", 6, -190)

    discordBtn = UI.Button(pane, 150, 24)
    discordBtn:SetPoint("TOPLEFT", 4, -206)
    discordBtn:SetScript("OnClick", function()
        UI.CopyPopup(L["DISCORD_POPUP"], NS.Data.LINKS.discord)
    end)

    reportBtn = UI.Button(pane, 150, 24)
    reportBtn:SetPoint("LEFT", discordBtn, "RIGHT", 8, 0)
    reportBtn:SetScript("OnClick", function()
        UI.CopyPopup(L["REPORT_POPUP"], NS.Data.LINKS.discord)
    end)

    verText = UI.Label(pane, "small", UI.COLOR.muted)
    verText:SetPoint("BOTTOMLEFT", 8, 6)

    local function refreshTexts()
        langLabel:SetText(L["OPT_LANG"])
        langBtn:SetText(langText(NS.addon.db.global.lang))
        mmCheck.label:SetText(L["OPT_MM"])
        soundCheck.label:SetText(L["OPT_SOUND"])
        presenceCheck.label:SetText(L["OPT_PRESENCE"])
        hbInfo:SetText(L["OPT_HB_INFO"]:format(NS.Data.CONST.HEARTBEAT,
                                               NS.Data.CONST.EXPIRY))
        communityLabel:SetText(L["OPT_COMMUNITY"])
        discordBtn:SetText(L["OPT_DISCORD"])
        reportBtn:SetText(L["OPT_REPORT_BUG"])
        verText:SetText(("%s v%s \194\183 proto %d"):format(L["TITLE"],
                        NS.VERSION, NS.Codec.PROTO))
    end
    tinsert(UI.refreshers, refreshTexts)

    pane:SetScript("OnShow", function()
        mmCheck:SetChecked(not NS.addon.db.global.minimap.hide)
        soundCheck:SetChecked(NS.addon.db.global.sound and true or false)
        presenceCheck:SetChecked(not NS.addon.db.global.hidePresence)
        refreshTexts()
    end)

    refreshTexts()
    return pane
end
