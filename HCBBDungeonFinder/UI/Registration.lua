-- "Find Group" tab (design 1a-1c): boss picker with bracket gating, role
-- cards with game role icons, minimum-size radios, leader opt-in, red
-- Search action button.
local _, NS = ...
local UI = NS.UI
local L = NS.L
local WHITE = "Interface\\Buttons\\WHITE8X8"

local ROW_H, VISIBLE_ROWS = 24, 8

local pane, picker, pickerText, pickerBracket, menu
local validate -- forward: menu rows re-validate on toggle, defined below
local searchBtn, errText, infoText, hintRoles, hintMin
local bossHeader, rolesHeader, minHeader, leadCheck
local roleCards, radios = {}, {}
local widgets = {}

local function prefs() return NS.addon.db.char.prefs end
local function cleared() return NS.addon.db.char.cleared end
local function playerLevel() return UnitLevel("player") end
-- A boss counts as cleared if the player ticked it OR has already out-levelled
-- it (R27): passing its unlock level means it was killed. The by-level case is
-- locked — shift-click can't undo a kill the game itself required.
local function clearedByLevel(id) return NS.Data:IsClearedByLevel(id, playerLevel()) end
local function isCleared(id) return cleared()[id] or clearedByLevel(id) end
local function isGrouped() return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 end

local function defaultBossId()
    for id = 1, NS.Data.NUM_BOSSES do
        if not isCleared(id) and NS.Data:IsEligible(id, playerLevel()) then
            return id
        end
    end
    return nil
end

-- Brackets are [unlock-4, unlock-1], so any gap wider than 4 levels between
-- two consecutive bosses leaves a dead level: 28, 41, 42 and 60 with the
-- default table. Nothing is wrong there — the player simply has to level up
-- (or, at 60, has run out of progression) — but the addon must say so instead
-- of silently greying the button. Cleared state is irrelevant here: a cleared
-- boss stays selectable, so this is purely about the level.
local function anyEligibleBoss()
    for id = 1, NS.Data.NUM_BOSSES do
        if NS.Data:IsEligible(id, playerLevel()) then return true end
    end
    return false
end

local function nextBracketFloor()
    local lvl, best = playerLevel(), nil
    for id = 1, NS.Data.NUM_BOSSES do
        local min = NS.Data:GetBracket(id)
        if min and min > lvl and (not best or min < best) then best = min end
    end
    return best
end

-- Selected targets (R28), ascending — ascending ids ARE the progression
-- priority order, so no separate ordering is ever stored.
local function selection()
    local p = prefs()
    p.bossIds = p.bossIds or {}
    return p.bossIds
end

local function isSelected(id)
    local ids = selection()
    for i = 1, #ids do if ids[i] == id then return true end end
    return false
end

local function updatePicker()
    local ids = selection()
    local id = ids[1]
    if id and NS.Data.BOSSES[id] then
        local check = (#ids == 1 and isCleared(id)) and (UI.ICON.check .. " ") or ""
        local txt = check .. UI.BossText(id)
        if #ids > 1 then txt = txt .. L["TARGETS_MORE"]:format(#ids - 1) end
        pickerText:SetText(txt)
        if #ids == 1 then
            local min, max = NS.Data:GetBracket(id)
            pickerBracket:SetText(("%d\226\128\147%d"):format(min, max))
        else
            pickerBracket:SetText("")
        end
    else
        pickerText:SetText(L["BOSS_LABEL"] .. "\226\128\166")
        pickerBracket:SetText("")
    end
end

-- ------------------------------------------------------------ boss menu --

local function menuRowUpdate()
    local offset = FauxScrollFrame_GetOffset(menu.scroll)
    for i = 1, VISIBLE_ROWS do
        local row = menu.rows[i]
        local id = i + offset
        local b = NS.Data.BOSSES[id]
        if b then
            row.bossId = id
            local eligible = NS.Data:IsEligible(id, playerLevel())
            local selected = isSelected(id)
            local check = isCleared(id) and (UI.ICON.check .. " ") or ""
            row.text:SetText(check .. b.dungeon .. " \226\128\148 " .. b.boss)
            if selected then
                row.text:SetTextColor(unpack(UI.COLOR.yellow))
            else
                row.text:SetTextColor(unpack(eligible and UI.COLOR.text or UI.COLOR.mutedDim))
            end
            row.sel[selected and "Show" or "Hide"](row.sel)
            row.eligible = eligible
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(menu.scroll, NS.Data.NUM_BOSSES, VISIBLE_ROWS, ROW_H)
end

local function createMenu()
    menu = UI.Panel(pane, UI.GRAD.window)
    menu:SetSize(452, VISIBLE_ROWS * ROW_H + 12)
    menu:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -2)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(picker:GetFrameLevel() + 10)
    menu:EnableMouse(true)
    menu:Hide()

    menu.scroll = CreateFrame("ScrollFrame", "HCBBBossMenuScroll", menu,
                              "FauxScrollFrameTemplate")
    menu.scroll:SetPoint("TOPLEFT", 4, -6)
    menu.scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    menu.scroll:SetScript("OnVerticalScroll", function(self, delta)
        FauxScrollFrame_OnVerticalScroll(self, delta, ROW_H, menuRowUpdate)
    end)

    menu.rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, menu)
        row:SetSize(420, ROW_H)
        row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_H)
        row.text = UI.Label(row, "small")
        row.text:SetPoint("LEFT", 6, 0)
        row.text:SetPoint("RIGHT", -6, 0)
        row.text:SetJustifyH("LEFT")
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(WHITE)
        hl:SetVertexColor(0.78, 0.667, 0.43, 0.15)
        -- Persistent tint for selected targets (R28) — the HIGHLIGHT layer
        -- only shows under the mouse, selection must survive it.
        row.sel = row:CreateTexture(nil, "BACKGROUND")
        row.sel:SetAllPoints()
        row.sel:SetTexture(WHITE)
        row.sel:SetVertexColor(0.78, 0.667, 0.43, 0.10)
        row.sel:Hide()
        row:SetScript("OnClick", function(self)
            if IsShiftKeyDown() then
                -- Can't un-clear a boss you had to kill to reach this level (R27).
                if clearedByLevel(self.bossId) then return end
                cleared()[self.bossId] = (not cleared()[self.bossId]) or nil
                menuRowUpdate()
                updatePicker()
                return
            end
            if not self.eligible then return end
            -- Toggle membership (R28); the menu stays open so several
            -- dungeons can be picked in one visit. Ascending insert keeps
            -- the list canonical (= progression priority order).
            local ids = selection()
            local at
            for k = 1, #ids do if ids[k] == self.bossId then at = k break end end
            if at then
                table.remove(ids, at)
            elseif #ids < NS.Data.CONST.MAX_TARGETS then
                ids[#ids + 1] = self.bossId
                table.sort(ids)
            end
            menuRowUpdate()
            updatePicker()
            validate()
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local b = NS.Data.BOSSES[self.bossId]
            GameTooltip:SetText(b.boss, 1, 1, 1)
            local min, max = NS.Data:GetBracket(self.bossId)
            if not self.eligible then
                GameTooltip:AddLine(L["BOSS_REQ"]:format(min, max, playerLevel()),
                                    unpack(UI.COLOR.red))
            else
                GameTooltip:AddLine(("%d\226\128\147%d"):format(min, max), unpack(UI.COLOR.muted))
            end
            if isCleared(self.bossId) then
                GameTooltip:AddLine(L["BOSS_CLEARED"], unpack(UI.COLOR.green))
            end
            if self.eligible then
                GameTooltip:AddLine(L["BOSS_PICK_HINT"], unpack(UI.COLOR.muted))
            end
            -- A by-level clear can't be toggled, so drop the misleading hint.
            if clearedByLevel(self.bossId) then
                GameTooltip:AddLine(L["BOSS_CLEARED_LEVEL"], unpack(UI.COLOR.muted))
            else
                GameTooltip:AddLine(L["BOSS_TOGGLE_HINT"], unpack(UI.COLOR.muted))
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        menu.rows[i] = row
    end
end

-- ------------------------------------------------------------ callbacks --

local function rolesMask()
    local mask = 0
    for role, card in pairs(roleCards) do
        if card.checked then mask = mask + role end
    end
    return mask
end

-- The role error shares the hint's anchor, so exactly one may be visible.
local function setRoleError(on)
    errText[on and "Show" or "Hide"](errText)
    hintRoles[on and "Hide" or "Show"](hintRoles)
end

function validate() -- assigns the forward local (menu rows call it on toggle)
    if not NS.eligible then return end
    local ids, allOk = selection(), true
    for i = 1, #ids do
        if not NS.Data:IsEligible(ids[i], playerLevel()) then allOk = false end
    end
    local ok = rolesMask() > 0 and #ids > 0 and allOk
    if NS.Session.state == "IDLE" then
        if ok then searchBtn:Enable() else searchBtn:Disable() end
    end
    setRoleError(rolesMask() == 0)
end

local function setInputsEnabled(on)
    for _, w in ipairs(widgets) do
        w:EnableMouse(on)
        w:SetAlpha(on and 1 or 0.5)
    end
    if menu then menu:Hide() end
end

local function onSearchClick()
    if NS.Session.state == "IDLE" then
        local p = prefs()
        p.roles = rolesMask()
        NS.Session:StartSearch({ bossIds = p.bossIds, roles = p.roles,
                                 minSize = p.minSize, lead = p.lead })
    else
        NS.Session:Cancel()
    end
end

-- Every reason the player cannot search, in priority order — returns the hint
-- and its colour, or nil when nothing blocks. Both updateInfo and
-- OnStateForPanes read it: they share infoText, so a pool event would
-- otherwise wipe whatever hint the state handler had just written.
local function blockedHint(state)
    state = state or NS.Session.state
    if not NS.eligible then return L["NOT_ENROLLED_HINT"], UI.COLOR.red end
    if isGrouped() then return L["ALREADY_GROUPED_HINT"], UI.COLOR.muted end
    -- Idle only: levelling up mid-search must not strand the player with a
    -- disabled Cancel button.
    if state == "IDLE" and not anyEligibleBoss() then
        local nxt = nextBracketFloor()
        if nxt then
            return L["NO_BOSS_NEXT"]:format(playerLevel(), nxt), UI.COLOR.red
        end
        -- No bracket left above us: level 60, i.e. the Blitz is over. That is
        -- an achievement, not an error — hence gold, not red.
        return L["BLITZ_OVER"]:format(playerLevel()), UI.COLOR.gold
    end
end

local function updateInfo()
    if not pane:IsShown() then return end
    local hint, color = blockedHint()
    if hint then
        infoText:SetText(hint)
        infoText:SetTextColor(unpack(color))
        return
    end
    infoText:SetTextColor(unpack(UI.COLOR.muted))
    if NS.Session.state == "SEARCHING" or NS.Session.state == "PAUSED" then
        local _, fresh, total = NS.Session:GetSearchInfo()
        fresh, total = fresh or 0, total or 0
        -- Only fresh players are matchable (R26). When some are stale, say so,
        -- so a full-looking bracket that won't match doesn't read as a bug.
        if total > fresh then
            infoText:SetText(L["POOL_COUNT_ACTIVE"]:format(fresh, total))
        else
            infoText:SetText(L["POOL_COUNT"]:format(fresh))
        end
    else
        infoText:SetText("")
    end
end

-- --------------------------------------------------------------- cards --

local function makeRoleCard(role, x, w)
    local card = CreateFrame("Button", nil, pane)
    card:SetSize(w, 52)
    card:SetPoint("TOPLEFT", x, -78)
    card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    card.icon = UI.RoleIcon(card, role, 18)
    card.icon:SetPoint("TOP", 0, -8)
    card.label = UI.Label(card, "small")
    card.label:SetPoint("BOTTOM", 0, 7)
    card.role = role
    card.Refresh = function(self)
        if self.checked then
            self:SetBackdropColor(0.20, 0.16, 0.10, 1)
            self:SetBackdropBorderColor(unpack(UI.COLOR.gold))
            self.label:SetTextColor(unpack(UI.COLOR.yellow))
            self.icon:SetAlpha(1)
        else
            self:SetBackdropColor(0, 0, 0, 0.30)
            self:SetBackdropBorderColor(unpack(UI.COLOR.borderIn))
            self.label:SetTextColor(unpack(UI.COLOR.textMut))
            self.icon:SetAlpha(0.75)
        end
    end
    card:SetScript("OnClick", function(self)
        self.checked = not self.checked
        self:Refresh()
        validate()
    end)
    card:Refresh()
    return card
end

local function makeRadio(size, x)
    local r = CreateFrame("Button", nil, pane)
    r:SetSize(90, 18)
    r:SetPoint("TOPLEFT", x, -168)
    local circle = r:CreateTexture(nil, "ARTWORK")
    circle:SetSize(14, 14)
    circle:SetPoint("LEFT", 0, 0)
    circle:SetTexture("Interface\\Buttons\\UI-RadioButton")
    circle:SetTexCoord(0, 0.25, 0, 1)
    r.dot = r:CreateTexture(nil, "OVERLAY")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("CENTER", circle, "CENTER", 0, 0)
    r.dot:SetTexture(WHITE)
    r.dot:SetVertexColor(unpack(UI.COLOR.yellow))
    r.label = UI.Label(r)
    r.label:SetPoint("LEFT", circle, "RIGHT", 5, 0)
    r.size = size
    r.SetSelected = function(self, on)
        self.dot[on and "Show" or "Hide"](self.dot)
    end
    r:SetScript("OnClick", function(self)
        prefs().minSize = self.size
        for _, other in ipairs(radios) do other:SetSelected(other.size == self.size) end
    end)
    return r
end

-- ---------------------------------------------------------------- pane --

function UI.CreateRegistration(parent)
    pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints()

    bossHeader = UI.Label(pane, "small", UI.COLOR.gold)
    bossHeader:SetPoint("TOPLEFT", 4, -4)

    -- Boss picker: flat black inset box with bracket + arrow (design 1a)
    picker = CreateFrame("Button", nil, pane)
    picker:SetPoint("TOPLEFT", 2, -20)
    picker:SetPoint("TOPRIGHT", -2, -20)
    picker:SetHeight(26)
    picker:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    picker:SetBackdropColor(0, 0, 0, 0.45)
    picker:SetBackdropBorderColor(unpack(UI.COLOR.borderIn))
    pickerText = UI.Label(picker, nil, UI.COLOR.white)
    pickerText:SetPoint("LEFT", 9, 0)
    pickerText:SetJustifyH("LEFT")
    pickerBracket = UI.Label(picker, "small", UI.COLOR.muted)
    pickerBracket:SetPoint("RIGHT", -28, 0)
    pickerText:SetPoint("RIGHT", pickerBracket, "LEFT", -6, 0)
    local arrow = UI.Label(picker, "small", UI.COLOR.gold)
    arrow:SetPoint("RIGHT", -9, 0)
    arrow:SetText("\226\150\188") -- down triangle
    picker:SetScript("OnClick", function()
        if menu:IsShown() then menu:Hide() else menuRowUpdate() menu:Show() end
    end)
    tinsert(widgets, picker)
    createMenu()

    rolesHeader = UI.Label(pane, "small", UI.COLOR.gold)
    rolesHeader:SetPoint("TOPLEFT", 4, -62)

    -- Role cards for the active mode (M6.2): the role set is data-driven per
    -- game mode, so Warcraft Reborn simply has no Support card. The cards
    -- re-space over the same width — the fill formula reproduces the 4-card
    -- layout exactly (110 px, step 117) and widens for 3 cards (149 px).
    local shown = NS.Data.MODE_ROLES[NS.gameMode] or NS.Data.ROLE_ORDER
    local SPAN, GAP = 461, 7
    local cardW = (SPAN - (#shown - 1) * GAP) / #shown
    for i, role in ipairs(shown) do
        local card = makeRoleCard(role, 2 + (i - 1) * (cardW + GAP), cardW)
        roleCards[role] = card
        tinsert(widgets, card)
    end

    hintRoles = UI.Label(pane, "small", UI.COLOR.muted)
    hintRoles:SetPoint("TOPLEFT", 4, -134)
    -- Deliberately the hint's anchor: there is no room for both lines above
    -- MIN_LABEL, so the error replaces the hint (setRoleError owns the swap).
    errText = UI.Label(pane, "small", UI.COLOR.red)
    errText:SetPoint("TOPLEFT", 4, -134)
    errText:Hide()

    minHeader = UI.Label(pane, "small", UI.COLOR.gold)
    minHeader:SetPoint("TOPLEFT", 4, -152)

    for i, size in ipairs({ 3, 4, 5 }) do
        local r = makeRadio(size, 4 + (i - 1) * 130)
        radios[i] = r
        tinsert(widgets, r)
    end

    hintMin = UI.Label(pane, "small", UI.COLOR.muted)
    hintMin:SetPoint("TOPLEFT", 4, -192)
    hintMin:SetWidth(456)
    hintMin:SetJustifyH("LEFT")

    leadCheck = UI.Check(pane)
    leadCheck:SetPoint("TOPLEFT", 4, -218)
    leadCheck:SetScript("OnClick", function(self)
        prefs().lead = self:GetChecked() and true or false
    end)
    tinsert(widgets, leadCheck)
    -- Crown icon next to the label (design 1a).
    local leadCrown = pane:CreateTexture(nil, "ARTWORK")
    leadCrown:SetSize(14, 14)
    leadCrown:SetPoint("LEFT", leadCheck.label, "RIGHT", 5, 0)
    leadCrown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")

    -- separator
    local sep = pane:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 8, -248)
    sep:SetPoint("TOPRIGHT", -8, -248)
    sep:SetTexture(WHITE)
    sep:SetVertexColor(unpack(UI.COLOR.borderIn))

    searchBtn = UI.ActionButton(pane, 210, 28)
    searchBtn:SetPoint("TOP", 0, -258)
    searchBtn:SetScript("OnClick", onSearchClick)

    infoText = UI.Label(pane, "small", UI.COLOR.muted)
    infoText:SetPoint("TOP", 0, -294)
    infoText:SetWidth(456)
    infoText:SetJustifyH("CENTER")

    local function refreshTexts()
        bossHeader:SetText(L["BOSS_LABEL"]:upper())
        rolesHeader:SetText(L["ROLES_LABEL"]:upper())
        minHeader:SetText(L["MIN_LABEL"]:upper())
        hintRoles:SetText(L["ROLES_HINT"])
        errText:SetText(L["ERR_NO_ROLE"])
        hintMin:SetText(L["MIN_HINT"])
        leadCheck.label:SetText(L["OPT_LEAD"])
        for i, key in ipairs({ "MIN_3", "MIN_4", "MIN_5" }) do
            radios[i].label:SetText(L[key])
        end
        for role, card in pairs(roleCards) do
            card.label:SetText(L[UI.ROLE_KEY[role]])
        end
        searchBtn:SetText(NS.Session.state == "IDLE" and L["BTN_SEARCH"] or L["BTN_CANCEL"])
        updatePicker()
    end
    tinsert(UI.refreshers, refreshTexts)

    -- Load saved prefs (R6)
    local p = prefs()
    for role, card in pairs(roleCards) do
        card.checked = math.floor((p.roles or 0) / role) % 2 == 1
        card:Refresh()
    end
    for _, r in ipairs(radios) do r:SetSelected(r.size == (p.minSize or 5)) end
    leadCheck:SetChecked(p.lead and true or false)

    pane:SetScript("OnShow", function()
        -- Drop targets the level no longer allows (R2), keep the rest; seed
        -- the first eligible uncleared boss when nothing valid remains.
        local ids, keep = selection(), {}
        for _, id in ipairs(ids) do
            if NS.Data:IsEligible(id, playerLevel()) then keep[#keep + 1] = id end
        end
        if #keep == 0 then
            local d = defaultBossId()
            if d then keep[1] = d end
        end
        prefs().bossIds = keep
        refreshTexts()
        UI.OnStateForPanes(NS.Session.state)
    end)

    local listener = UI.Listener() -- own target: see UI.Listener (shared object = lost callbacks)
    listener:RegisterMessage("HCBB_POOL_CHANGED", updateInfo)
    listener:RegisterMessage("HCBB_CLEARED_CHANGED", function()
        if pane:IsShown() then menuRowUpdate() updatePicker() end
    end)

    UI.OnStateForPanes = function(state)
        local hint, color = blockedHint(state)
        if hint then
            -- A dead level is the one block that leaves the inputs usable: the
            -- player can still shift-click bosses to track their progress
            -- while they level out of the gap.
            setInputsEnabled(NS.eligible and not isGrouped())
            searchBtn:Disable()
            searchBtn:SetText(L["BTN_SEARCH"])
            infoText:SetText(hint)
            infoText:SetTextColor(unpack(color))
            setRoleError(false)
            return
        end
        infoText:SetTextColor(unpack(UI.COLOR.muted))
        local idle = state == "IDLE"
        setInputsEnabled(idle)
        searchBtn:Enable()
        searchBtn:SetText(idle and L["BTN_SEARCH"] or L["BTN_CANCEL"])
        if state == "INGROUP" or state == "FORMING" then searchBtn:Disable() end
        validate()
        updateInfo()
    end

    refreshTexts()
    validate()
    return pane
end
