-- "Who's Looking" tab (design 1h): read-only virtualized pool list with
-- dungeon filter and freshness dots. Fixed row pool (NFR-P4).
local _, NS = ...
local UI = NS.UI
local L = NS.L

local ROW_H, VISIBLE_ROWS = 24, 11

local pane, scroll, emptyText, filterBtn, menuFrame
local rows, sorted = {}, {}
local dungeonFilter = nil -- nil = all

local function freshColor(age)
    local C = NS.Data.CONST
    if age < C.FRESH_GREEN then return UI.COLOR.green end
    if age < C.FRESH_YELLOW then return UI.COLOR.yellow end
    return UI.COLOR.red
end

local function refreshList()
    if not pane:IsShown() then return end
    sorted = NS.Pool:GetSorted(dungeonFilter)
    local me = UnitName("player")

    -- Own listing pinned on top (design 1h)
    for i, e in ipairs(sorted) do
        if e.name == me and i > 1 then
            table.remove(sorted, i)
            table.insert(sorted, 1, e)
            break
        end
    end

    local offset = FauxScrollFrame_GetOffset(scroll)
    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local e = sorted[i + offset]
        if e then
            local age = NS.now() - e.lastSeen
            row.dot:SetVertexColor(unpack(freshColor(age)))
            local own = e.name == me
            row.name:SetText(e.name)
            local _, classColor = UI.ClassInfo(e.class)
            if own then
                row.name:SetTextColor(unpack(UI.COLOR.yellow))
            elseif classColor then
                row.name:SetTextColor(unpack(classColor))
            else
                row.name:SetTextColor(unpack(UI.COLOR.text))
            end
            row.level:SetText(e.level)
            local shown = 0
            for _, role in ipairs(NS.Data.ROLE_ORDER) do
                local badge = row.badges[role]
                if math.floor(e.roles / role) % 2 == 1 then
                    badge:ClearAllPoints()
                    badge:SetPoint("LEFT", row, "LEFT", 170 + shown * 18, 0)
                    badge:Show()
                    shown = shown + 1
                else
                    badge:Hide()
                end
            end
            row.boss:SetText(UI.BossText(e.bossId))
            row.min:SetText(e.minSize .. "+")
            row.crown[e.lead == 1 and "Show" or "Hide"](row.crown)
            row:SetBackdropColor(own and 0.20 or 0.13, own and 0.16 or 0.10,
                                 own and 0.08 or 0.07, 1)
            row.entry = e
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(scroll, #sorted, VISIBLE_ROWS, ROW_H)
    emptyText[#sorted == 0 and "Show" or "Hide"](emptyText)
end

local function initFilterMenu()
    local info = UIDropDownMenu_CreateInfo()
    info.text = L["FILTER_ALL"]
    info.checked = dungeonFilter == nil
    info.func = function() dungeonFilter = nil refreshList() end
    UIDropDownMenu_AddButton(info)
    for _, dungeon in ipairs(NS.Data.dungeons) do
        info = UIDropDownMenu_CreateInfo()
        info.text = dungeon
        info.checked = dungeonFilter == dungeon
        info.func = function() dungeonFilter = dungeon refreshList() end
        UIDropDownMenu_AddButton(info)
    end
end

-- Click a listing to act on that player (design request): invite when you
-- can (solo or leader), otherwise suggest to the group, plus whisper. The
-- addon never auto-accepts anything (R19) — these are user-initiated.
local function canInvite()
    if GetNumRaidMembers() > 0 then return IsRaidLeader() == 1 end
    if GetNumPartyMembers() > 0 then return IsPartyLeader() == 1 end
    return true -- solo
end

local function showUnitMenu(entry)
    local name = entry.name
    if name == UnitName("player") then return end
    local items = { { text = name, isTitle = true, notCheckable = true } }
    if canInvite() then
        items[#items + 1] = { text = L["BROWSER_INVITE"], notCheckable = true,
            func = function() InviteUnit(name) end }
    else
        items[#items + 1] = { text = L["BROWSER_SUGGEST"], notCheckable = true,
            func = function()
                local boss = NS.Data.BOSSES[entry.bossId].boss
                -- Addon message → the leader's client pops a clickable Invite
                -- prompt (the server rejects clickable player links in chat).
                NS.Comm:SendGroup({ type = "S", target = name, bossId = entry.bossId })
                -- Plain chat fallback so a leader without the addon still sees it.
                local chan = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
                SendChatMessage(L["SUGGEST_MSG"]:format(name, boss), chan)
            end }
    end
    items[#items + 1] = { text = L["BROWSER_WHISPER"], notCheckable = true,
        func = function() ChatFrame_SendTell(name) end }
    items[#items + 1] = { text = L["BROWSER_CANCEL"], notCheckable = true }
    EasyMenu(items, menuFrame, "cursor", 0, 0, "MENU")
end

-- Prefer the game's native player menu (Ascension adds "Suggest Invite" to
-- it, alongside Invite/Whisper, all context-aware). FriendsFrame_ShowDropdown
-- is the standard path used by the Who/friends/guild lists. Falls back to our
-- own menu if it isn't available or errors.
local function openUnitMenu(entry)
    local name = entry.name
    if name == UnitName("player") then return end
    if FriendsFrame_ShowDropdown then
        local ok = pcall(FriendsFrame_ShowDropdown, name, 1)
        if ok then return end
    end
    showUnitMenu(entry) -- fallback
end

function UI.CreateBrowser(parent)
    pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints()
    pane:Hide()

    menuFrame = CreateFrame("Frame", "HCBBBrowserUnitMenu", UIParent,
                            "UIDropDownMenuTemplate")

    filterBtn = UI.Button(pane, 190, 26)
    filterBtn:SetPoint("TOPLEFT", 4, -4)
    local dropdown = CreateFrame("Frame", "HCBBBrowserFilter", pane,
                                 "UIDropDownMenuTemplate")
    dropdown:Hide()
    UIDropDownMenu_Initialize(dropdown, initFilterMenu, "MENU")
    filterBtn:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, dropdown, self, 0, 0)
    end)

    scroll = CreateFrame("ScrollFrame", "HCBBBrowserScroll", pane,
                         "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -36)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    scroll:SetScript("OnVerticalScroll", function(self, delta)
        FauxScrollFrame_OnVerticalScroll(self, delta, ROW_H, refreshList)
    end)

    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, pane)
        row:SetSize(436, ROW_H - 2)
        row:SetPoint("TOPLEFT", 6, -38 - (i - 1) * ROW_H)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        row:EnableMouse(true)

        row.dot = UI.Dot(row, 8)
        row.dot:SetPoint("LEFT", 4, 0)
        row.name = UI.Label(row, "small")
        row.name:SetPoint("LEFT", 18, 0)
        row.name:SetWidth(105)
        row.name:SetJustifyH("LEFT")
        row.level = UI.Label(row, "small", UI.COLOR.muted)
        row.level:SetPoint("LEFT", 128, 0)
        row.badges = {}
        for _, role in ipairs(NS.Data.ROLE_ORDER) do
            row.badges[role] = UI.Badge(row, role, 14)
            row.badges[role]:Hide()
        end
        row.boss = UI.Label(row, "small")
        row.boss:SetPoint("LEFT", 248, 0)
        row.boss:SetWidth(140)
        row.boss:SetJustifyH("LEFT")
        row.min = UI.Label(row, "small", UI.COLOR.muted)
        row.min:SetPoint("LEFT", 392, 0)
        row.crown = row:CreateTexture(nil, "ARTWORK")
        row.crown:SetSize(14, 14)
        row.crown:SetPoint("LEFT", 416, 0)
        row.crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        row.crown:Hide()

        row:SetScript("OnEnter", function(self)
            local e = self.entry
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(e.name, 1, 1, 1)
            local className, classColor = UI.ClassInfo(e.class)
            if className then
                GameTooltip:AddLine(("Level %d %s"):format(e.level, className),
                    classColor and classColor[1] or 0.8,
                    classColor and classColor[2] or 0.8,
                    classColor and classColor[3] or 0.8)
            end
            GameTooltip:AddLine(UI.BossText(e.bossId), unpack(UI.COLOR.gold))
            local roleNames = {}
            for _, role in ipairs(NS.Data.ROLE_ORDER) do
                if math.floor(e.roles / role) % 2 == 1 then
                    roleNames[#roleNames + 1] = L[UI.ROLE_KEY[role]]
                end
            end
            GameTooltip:AddLine(table.concat(roleNames, " / "), unpack(UI.COLOR.text))
            if e.lead == 1 then
                GameTooltip:AddLine(L["LEADER"], unpack(UI.COLOR.yellow))
            end
            if e.name ~= UnitName("player") then
                GameTooltip:AddLine(L["BROWSER_CLICK_HINT"], unpack(UI.COLOR.muted))
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" and self.entry then openUnitMenu(self.entry) end
        end)
        rows[i] = row
    end

    emptyText = UI.Label(pane, nil, UI.COLOR.muted)
    emptyText:SetPoint("CENTER", 0, 0)
    emptyText:SetWidth(360)

    local function refreshTexts()
        filterBtn:SetText(dungeonFilter or L["FILTER_ALL"])
        emptyText:SetText(L["POOL_EMPTY"])
    end
    tinsert(UI.refreshers, refreshTexts)
    refreshTexts()

    -- Pool events arrive in bursts; one repaint per second is plenty.
    local pending
    local listener = UI.Listener() -- own target: see UI.Listener
    listener:RegisterMessage("HCBB_POOL_CHANGED", function()
        if pending or not pane:IsShown() then return end
        pending = NS.addon:ScheduleTimer(function()
            pending = nil
            refreshList()
        end, 1)
    end)

    pane:SetScript("OnShow", refreshList)
    return pane
end
