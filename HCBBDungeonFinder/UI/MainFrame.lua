-- Main window shell + shared widget factory, built to match the Claude
-- design mockup (docs/reference/sources/2026-07-13-*.dc.html): dark
-- gradient panels, 2 px bevels, gold serif titles, game role icons, a red
-- action button, and the double-dot status strip. UI reads state only via
-- AceEvent messages (architecture §8).
local _, NS = ...

local UI = NS.UI or {}
NS.UI = UI

local L = NS.L
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Exact tokens from the mockup.
UI.COLOR = {
    border   = { 0.29, 0.235, 0.14 },   -- #4a3c24
    borderIn = { 0.235, 0.188, 0.125 }, -- #3c3020
    gold     = { 0.78, 0.667, 0.43 },   -- #c8aa6e
    yellow   = { 1.00, 0.82, 0.00 },    -- #ffd100
    textHi   = { 0.91, 0.863, 0.753 },  -- #e8dcc0
    text     = { 0.812, 0.765, 0.647 }, -- #cfc3a5
    textMut  = { 0.702, 0.659, 0.541 }, -- #b3a789
    muted    = { 0.561, 0.518, 0.424 }, -- #8f846c
    mutedDim = { 0.435, 0.396, 0.322 }, -- #6f6552
    green    = { 0.208, 0.851, 0.290 }, -- #35d94a
    ingroup  = { 0.561, 0.851, 0.604 }, -- #8fd99a
    orange   = { 1.00, 0.549, 0.102 },  -- #ff8c1a
    red      = { 1.00, 0.275, 0.212 },  -- #ff4636
    white    = { 1, 1, 1 },
}

-- Role icon accent colors (design SVG fills) for borders and labels.
UI.ROLE_COLOR = {
    [1] = { 0.49, 0.635, 0.769 }, -- tank   #7da2c4
    [2] = { 0.345, 0.769, 0.345 }, -- healer #58c458
    [4] = { 0.706, 0.541, 0.831 }, -- support #b48ad4
    [8] = { 0.831, 0.353, 0.290 }, -- dps    #d45a4a
}
UI.ROLE_KEY = { [1] = "ROLE_TANK", [2] = "ROLE_HEAL", [4] = "ROLE_SUPPORT", [8] = "ROLE_DPS" }

-- Inline texture escapes for status marks. The 3.3.5 game font lacks the
-- ✓/✗ glyphs (they render as a green "?"), so we use ready-check textures
-- that render inside any FontString. ":0" sizes them to the line height.
UI.ICON = {
    check = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t",
    cross = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t",
    wait  = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:0|t",
}

-- Gradient palettes (top -> bottom).
UI.GRAD = {
    window = { { 0.149, 0.114, 0.071 }, { 0.075, 0.063, 0.035 } }, -- #261d12 -> #131009
    title  = { { 0.180, 0.137, 0.078 }, { 0.114, 0.086, 0.051 } }, -- #2e2314 -> #1d160d
    strip  = { { 0.090, 0.067, 0.043 }, { 0.063, 0.047, 0.027 } }, -- #17110b -> #100c07
    action = { { 0.604, 0.231, 0.149 }, { 0.278, 0.063, 0.031 } }, -- #9a3b26 -> #471008
    neutral= { { 0.290, 0.227, 0.133 }, { 0.118, 0.086, 0.039 } }, -- #4a3a22 -> #1e160a
    tabOn  = { { 0.173, 0.133, 0.078 }, { 0.102, 0.078, 0.047 } }, -- #2c2214 -> #1a1410
    gold   = { { 1.00, 0.851, 0.302 }, { 0.725, 0.478, 0.063 } },  -- countdown
    greenB = { { 0.290, 0.871, 0.388 }, { 0.094, 0.478, 0.173 } },
}

local BORDER_FILE = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Role icons: the game's LFG role atlas for tank/heal/dps (already colored,
-- recognizable), a spell icon for the CoA "Support" role (no native icon).
local LFG_ROLES = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local ROLE_TEXCOORD = {
    [1] = { 0, 0.296875, 0.34375, 0.640625 },        -- tank
    [2] = { 0.3125, 0.609375, 0.015625, 0.3125 },    -- healer
    [8] = { 0.3125, 0.609375, 0.34375, 0.640625 },   -- dps
}
local SUPPORT_ICON = "Interface\\Icons\\Spell_Holy_PowerInfusion"

-- ------------------------------------------------------- widget factory --

-- Solid fill texture in the gradient's average color. The Ascension client
-- honors SetVertexColor (the status dots tint fine) but ignores
-- SetGradientAlpha (it leaves the texture white), so we use a flat tint —
-- reliable, and visually close to the design's subtle gradients.
function UI.Fill(parent, layer, grad, alpha)
    local a = alpha or 1
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(WHITE)
    local top, bot = grad[1], grad[2]
    t:SetVertexColor((top[1] + bot[1]) / 2, (top[2] + bot[2]) / 2,
                     (top[3] + bot[3]) / 2, a)
    return t
end

-- Recolor a Fill texture to another palette's average (used by tabs/bars).
function UI.Recolor(tex, grad, alpha)
    local top, bot = grad[1], grad[2]
    tex:SetVertexColor((top[1] + bot[1]) / 2, (top[2] + bot[2]) / 2,
                       (top[3] + bot[3]) / 2, alpha or 1)
end

-- 1 px inset bevel: light top-left, dark bottom-right (design signature).
local function addBevel(frame)
    local hl = frame:CreateTexture(nil, "BORDER")
    hl:SetTexture(WHITE)
    hl:SetVertexColor(0.91, 0.804, 0.588, 0.16)
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("TOPRIGHT", -1, -1)
    hl:SetHeight(1)
    local sh = frame:CreateTexture(nil, "BORDER")
    sh:SetTexture(WHITE)
    sh:SetVertexColor(0, 0, 0, 0.6)
    sh:SetPoint("BOTTOMLEFT", 1, 1)
    sh:SetPoint("BOTTOMRIGHT", -1, 1)
    sh:SetHeight(1)
end

-- Panel: black 1 px edge + inner border tint + optional gradient fill.
function UI.Panel(parent, grad, alpha)
    local f = CreateFrame("Frame", nil, parent)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    if grad then
        f.fill = UI.Fill(f, "BACKGROUND", grad, alpha)
        f.fill:SetPoint("TOPLEFT", 1, -1)
        f.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    return f
end

function UI.Label(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY",
        size == "large" and "GameFontNormalLarge"
        or size == "small" and "GameFontNormalSmall" or "GameFontNormal")
    local c = color or UI.COLOR.text
    fs:SetTextColor(c[1], c[2], c[3])
    return fs
end

-- Section header: 11 px bold, wide letter-spacing look, gold, UPPERCASE.
function UI.Header(parent, key)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetTextColor(unpack(UI.COLOR.gold))
    fs.key = key
    return fs
end

local function styleButton(b, grad, textColor, innerColor)
    -- Edge-only backdrop (no bgFile) so no white texture leaks under the
    -- gradient fill; the fill texture is the only background.
    b:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropBorderColor(0, 0, 0, 1)
    b.fill = UI.Fill(b, "BACKGROUND", grad)
    b.fill:SetPoint("TOPLEFT", 1, -1)
    b.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    local edge = b:CreateTexture(nil, "BORDER")
    edge:SetTexture(WHITE)
    edge:SetVertexColor(innerColor[1], innerColor[2], innerColor[3], 1)
    edge:SetPoint("TOPLEFT", 1, -1)
    edge:SetPoint("TOPRIGHT", -1, -1)
    edge:SetHeight(1)
    b.edge = edge
    local fs = UI.Label(b, nil, textColor)
    fs:SetPoint("CENTER", 0, 0)
    b:SetFontString(fs)
    b.textColor = textColor
    b._enable, b._disable = b.Enable, b.Disable
    b.Enable = function(self)
        self:_enable()
        self.fill:SetAlpha(1)
        self:GetFontString():SetTextColor(unpack(self.textColor))
    end
    b.Disable = function(self)
        self:_disable()
        self.fill:SetAlpha(0.4)
        self:GetFontString():SetTextColor(unpack(UI.COLOR.muted))
    end
    return b
end

-- Neutral (brown) button — dropdowns, tabs, Decline.
function UI.Button(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    return styleButton(b, UI.GRAD.neutral, UI.COLOR.gold, { 0.353, 0.29, 0.18 })
end

-- Red action button — Search, Accept.
function UI.ActionButton(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    return styleButton(b, UI.GRAD.action, UI.COLOR.yellow, { 0.541, 0.427, 0.231 })
end

function UI.Check(parent, template)
    local c = CreateFrame("CheckButton", nil, parent,
                          template or "UICheckButtonTemplate")
    c:SetSize(20, 20)
    c.label = UI.Label(c)
    c.label:SetPoint("LEFT", c, "RIGHT", 3, 0)
    return c
end

-- Role icon (texture). :SetRole(role) swaps the glyph.
function UI.RoleIcon(parent, role, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size or 16, size or 16)
    t.SetRole = function(self, r)
        local tc = ROLE_TEXCOORD[r]
        if tc then
            self:SetTexture(LFG_ROLES)
            self:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
            self:SetVertexColor(1, 1, 1)
        else -- support
            self:SetTexture(SUPPORT_ICON)
            self:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            self:SetVertexColor(1, 1, 1)
        end
    end
    t:SetRole(role)
    return t
end
UI.Badge = UI.RoleIcon -- back-compat alias

function UI.Dot(parent, size)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(size or 8, size or 8)
    t:SetTexture(WHITE)
    return t
end

-- A colored dot that can pulse (alpha loop) without a Lua OnUpdate. The
-- AnimationGroup lives on a Frame (textures don't own one on 3.3.5).
function UI.PulseDot(parent, size)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size or 8, size or 8)
    frame.tex = frame:CreateTexture(nil, "OVERLAY")
    frame.tex:SetAllPoints()
    frame.tex:SetTexture(WHITE)
    local ag = frame:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetChange(-0.7)
    a:SetDuration(0.7)
    a:SetSmoothing("IN_OUT")
    frame.SetColor = function(self, c) self.tex:SetVertexColor(c[1], c[2], c[3]) end
    frame.SetPulse = function(self, on)
        if on then if not ag:IsPlaying() then ag:Play() end
        else ag:Stop(); self:SetAlpha(1) end
    end
    return frame
end

function UI.FormatClock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function UI.BossText(bossId)
    local b = NS.Data.BOSSES[bossId]
    return b and (b.dungeon .. " \226\128\148 " .. b.boss) or "?"
end

-- Class display name + color from a 2-letter wire abbreviation, or nil.
function UI.ClassInfo(abbrev)
    if not abbrev then return nil end
    local token = NS.Data.CLASS_TOKEN[abbrev]
    if not token then return nil end
    return NS.Data:ClassDisplay(token), NS.Data:GetClassColor(token)
end

-- Can the local player invite others right now (solo, or group/raid leader)?
function UI.CanInvite()
    if GetNumRaidMembers() > 0 then return IsRaidLeader() == 1 end
    if GetNumPartyMembers() > 0 then return IsPartyLeader() == 1 end
    return true
end

UI.refreshers = {}
function UI.OnLocaleChanged()
    for _, fn in ipairs(UI.refreshers) do fn() end
end

-- ----------------------------------------------------------- main frame --

-- state -> { dot color, text color, pulse }
local STATE_STYLE = {
    IDLE       = { "mutedDim", "textMut", false, "ST_IDLE" },
    SEARCHING  = { "yellow", "yellow", true, "ST_SEARCH" },
    COLLECTING = { "orange", "orange", true, "ST_PROPOSAL" },
    PROPOSED   = { "orange", "orange", true, "ST_PROPOSAL" },
    FORMING    = { "green", "green", true, "ST_FORMING" },
    INGROUP    = { "green", "ingroup", false, "ST_GROUP" },
    PAUSED     = { "yellow", "yellow", true, "ST_PAUSED" },
}

function UI.Init()
    if UI.frame then return end

    local f = CreateFrame("Frame", "HCBBMainFrame", UIParent)
    UI.frame = f
    f:SetSize(480, 420)
    f:SetPoint("CENTER", 0, 40)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER_FILE, edgeSize = 14,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(unpack(UI.COLOR.border))
    f.bg = UI.Fill(f, "BACKGROUND", UI.GRAD.window)
    f.bg:SetPoint("TOPLEFT", 3, -3)
    f.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    -- Above WeakAuras and other MEDIUM/HIGH frames when opened.
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:Hide()
    tinsert(UISpecialFrames, "HCBBMainFrame")

    -- Title bar (gradient, drag handle). Stops short of the close button so
    -- the drag zone never swallows the close click.
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -30, -4)
    titleBar:SetHeight(30)
    titleBar:EnableMouse(true)
    titleBar:SetScript("OnMouseDown", function() f:StartMoving() end)
    titleBar:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
    local tbBg = CreateFrame("Frame", nil, f) -- full-width visual bar behind
    tbBg:SetPoint("TOPLEFT", 4, -4)
    tbBg:SetPoint("TOPRIGHT", -4, -4)
    tbBg:SetHeight(30)
    local tb = UI.Fill(tbBg, "BACKGROUND", UI.GRAD.title)
    tb:SetAllPoints()
    addBevel(tbBg)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -11)
    f.title:SetTextColor(unpack(UI.COLOR.gold))

    -- Custom close button (design 1a): reliably clickable, styled to match.
    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -6, -8)
    close:SetFrameLevel(f:GetFrameLevel() + 10)
    close:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    close:SetBackdropBorderColor(0, 0, 0, 1)
    local cf = UI.Fill(close, "BACKGROUND", { { 0.227, 0.173, 0.102 }, { 0.141, 0.102, 0.055 } })
    cf:SetPoint("TOPLEFT", 1, -1)
    cf:SetPoint("BOTTOMRIGHT", -1, 1)
    local cx = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cx:SetPoint("CENTER", 0, 0)
    cx:SetText("\195\151") -- multiplication sign as a crisp X
    cx:SetTextColor(unpack(UI.COLOR.gold))
    close:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(UI.COLOR.gold)) end)
    close:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0, 0, 0, 1) end)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Status strip (design 1j): state dot + text, channel dot + label.
    local strip = UI.Panel(f, UI.GRAD.strip)
    strip:SetPoint("BOTTOMLEFT", 6, 6)
    strip:SetPoint("BOTTOMRIGHT", -6, 6)
    strip:SetHeight(24)

    f.stateDot = UI.PulseDot(strip, 8)
    f.stateDot:SetPoint("LEFT", 9, 0)
    f.status = UI.Label(strip)
    f.status:SetPoint("LEFT", 24, 0)
    f.status:SetJustifyH("LEFT")

    f.chanLabel = UI.Label(strip, "small", UI.COLOR.muted)
    f.chanLabel:SetPoint("RIGHT", -8, 0)
    f.chanDot = UI.PulseDot(strip, 7)
    f.chanDot:SetPoint("RIGHT", f.chanLabel, "LEFT", -6, 0)
    f.status:SetPoint("RIGHT", f.chanDot, "LEFT", -8, 0)

    local dotHit = CreateFrame("Frame", nil, strip)
    dotHit:SetPoint("TOPRIGHT", 0, 0)
    dotHit:SetPoint("BOTTOMRIGHT", 0, 0)
    dotHit:SetWidth(110)
    dotHit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local title = L["TITLE"]
        if not NS.eligible then
            GameTooltip:SetText(L["ST_NOT_ENROLLED"], 1, 1, 1, 1, true)
        else
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine(NS.Comm.healthy and L["CH_OK"] or L["CH_RECON"],
                                unpack(NS.Comm.healthy and UI.COLOR.green or UI.COLOR.yellow))
        end
        GameTooltip:Show()
    end)
    dotHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Content area between title and strip
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", 6, -38)
    f.content:SetPoint("BOTTOMRIGHT", -6, 34)

    -- Bottom tabs (flow layout — widths follow text, no overlap in any locale)
    f.tabs, f.panes = {}, {}
    local tabKeys = { "TAB_FIND", "TAB_POOL", "TAB_OPT" }
    for i, key in ipairs(tabKeys) do
        local tab = UI.Button(f, 10, 24)
        tab.key = key
        tab:SetScript("OnClick", function() UI.SelectTab(i) end)
        f.tabs[i] = tab
    end

    local function layoutTabs()
        local x = 12
        for _, tab in ipairs(f.tabs) do
            tab:SetText(L[tab.key])
            tab:SetWidth(tab:GetFontString():GetStringWidth() + 26)
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", x, 1)
            x = x + tab:GetWidth() + 3
        end
    end

    local function refreshTexts()
        f.title:SetText(L["TITLE"])
        layoutTabs()
        if StaticPopupDialogs["HCBB_SUGGEST_INVITE"] then
            StaticPopupDialogs["HCBB_SUGGEST_INVITE"].button1 = L["BROWSER_INVITE"]
        end
        UI.UpdateStatus()
    end
    tinsert(UI.refreshers, refreshTexts)

    if UI.CreateRegistration then f.panes[1] = UI.CreateRegistration(f.content) end
    if UI.CreateBrowser then f.panes[2] = UI.CreateBrowser(f.content) end
    if UI.CreateOptions then f.panes[3] = UI.CreateOptions(f.content) end
    if UI.CreateProposal then UI.CreateProposal() end
    if UI.CreateMinimap then UI.CreateMinimap() end

    f:SetScript("OnShow", function(self) self:Raise() end)

    NS.addon:RegisterMessage("HCBB_STATE_CHANGED", function() UI.UpdateStatus() end)
    NS.addon:RegisterMessage("HCBB_CHANNEL_UP", function() UI.UpdateStatus() end)
    NS.addon:RegisterMessage("HCBB_CHANNEL_DOWN", function() UI.UpdateStatus() end)
    NS.addon:RegisterMessage("HCBB_ELIGIBILITY_CHANGED", function() UI.UpdateStatus() end)
    NS.addon:RegisterMessage("HCBB_GROUP_CHANGED", function() UI.UpdateStatus() end)
    NS.addon:RegisterMessage("HCBB_LOCALE_CHANGED", function() UI.OnLocaleChanged() end)

    -- Suggest-invite prompt (R24): only the client that can invite pops it.
    StaticPopupDialogs["HCBB_SUGGEST_INVITE"] = {
        text = "%s",
        button1 = L["BROWSER_INVITE"],
        button2 = CANCEL,
        OnAccept = function(_, data)
            if data and data.target then InviteUnit(data.target) end
        end,
        timeout = 30, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }
    NS.addon:RegisterMessage("HCBB_SUGGESTION", function(_, from, target, bossId)
        if not UI.CanInvite() or target == UnitName("player") then return end
        local boss = NS.Data.BOSSES[bossId]
        StaticPopup_Show("HCBB_SUGGEST_INVITE",
            L["SUGGEST_POPUP"]:format(from, target, boss and boss.boss or "?"),
            nil, { target = target })
    end)

    -- Auto-close the window when combat starts (hiding never cancels the
    -- search — that lives in Session state, not window visibility).
    NS.addon:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if f:IsShown() then f:Hide() end
    end)

    refreshTexts()
    UI.SelectTab(1)
    UI.UpdateStatus()
end

function UI.SelectTab(index)
    for i, pane in ipairs(UI.frame.panes) do
        pane[i == index and "Show" or "Hide"](pane)
        local tab = UI.frame.tabs[i]
        if i == index then
            tab.fill:SetVertexColor(0.137, 0.106, 0.063, 1)
            tab:GetFontString():SetTextColor(unpack(UI.COLOR.yellow))
        else
            tab.fill:SetVertexColor(0.09, 0.071, 0.031, 1)
            tab:GetFontString():SetTextColor(unpack(UI.COLOR.textMut))
        end
    end
end

local function ensureTicker(on)
    if on and not UI.statusTicker then
        UI.statusTicker = NS.addon:ScheduleRepeatingTimer(function()
            UI.UpdateStatus(true)
        end, 1)
    elseif not on and UI.statusTicker then
        NS.addon:CancelTimer(UI.statusTicker, true)
        UI.statusTicker = nil
    end
end

function UI.UpdateStatus(tickOnly)
    local f = UI.frame
    if not f then return end
    local state = NS.Session.state

    if not tickOnly then
        if not NS.eligible then
            f.stateDot:SetColor(UI.COLOR.red)
            f.stateDot:SetPulse(false)
            f.chanDot:SetColor(UI.COLOR.red)
            f.chanDot:SetPulse(false)
            f.chanLabel:SetText("")
        else
            local st = STATE_STYLE[state] or STATE_STYLE.IDLE
            f.stateDot:SetColor(UI.COLOR[st[1]])
            f.stateDot:SetPulse(st[3])
            local ok = NS.Comm.healthy
            f.chanDot:SetColor(ok and UI.COLOR.green or UI.COLOR.yellow)
            f.chanDot:SetPulse(not ok)
            f.chanLabel:SetText(ok and L["CH_LABEL"] or L["CH_RECON_SHORT"])
            f.chanLabel:SetTextColor(unpack(ok and UI.COLOR.muted or UI.COLOR.yellow))
        end
        ensureTicker(NS.eligible and state == "SEARCHING")
    end

    local text, color
    if not NS.eligible then
        text, color = L["ST_NOT_ENROLLED"], UI.COLOR.red
    elseif state == "SEARCHING" then
        local elapsed, count = NS.Session:GetSearchInfo()
        text = L["ST_SEARCH_FULL"]:format(UI.FormatClock(elapsed or 0), count or 0)
        color = UI.COLOR.yellow
    else
        local st = STATE_STYLE[state] or STATE_STYLE.IDLE
        text, color = L[st[4]], UI.COLOR[st[2]]
    end
    f.status:SetText(text)
    f.status:SetTextColor(color[1], color[2], color[3])

    if UI.OnStateForPanes and not tickOnly then UI.OnStateForPanes(state) end
end

function UI.Toggle()
    if not UI.frame then return end
    if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end
end
