-- "Who's Playing" tab: everyone online running the addon, fed by Presence
-- pings (not the search pool). Read-only virtualized list, fixed row pool
-- (NFR-P4). Right-click opens the game's native player menu, same as the
-- Who's Looking browser.
local _, NS = ...
local UI = NS.UI
local L = NS.L

local ROW_H, VISIBLE_ROWS = 24, 12
local PROF_MAX_CHARS = 32 -- 3.3.5 FontStrings can't ellipsize; we trim by hand

local pane, scroll, emptyText, countText, menuFrame
local rows, sorted = {}, {}

local function freshColor(age)
    local C = NS.Data.CONST
    if age < C.PRESENCE_PING then return UI.COLOR.green end
    if age < C.PRESENCE_PING * 2 then return UI.COLOR.yellow end
    return UI.COLOR.red
end

-- Display names are localized from the `PROF_<ab>` locale keys (NFR-L2); the
-- wire only ever carries the abbreviation (R22). The game client is enUS, so
-- GetSpellInfo would return English regardless of the addon's language — the
-- locale files are the only source that follows the user's choice.
local function profText(profs, full)
    if not profs or #profs == 0 then return "" end
    local parts = {}
    for i = 1, #profs do
        parts[#parts + 1] = L["PROF_" .. profs[i].ab] .. " " .. profs[i].rank
    end
    if #parts == 0 then return "" end
    local s = table.concat(parts, " \194\183 ") -- middot
    if not full and #s > PROF_MAX_CHARS then
        s = s:sub(1, PROF_MAX_CHARS - 3) .. "..."
    end
    return s
end

-- An empty list means two very different things: "we haven't pinged yet, so
-- we don't know" versus "we asked and nobody is there". Saying the second
-- while the first is true is a lie the user can catch.
local function emptyMessage()
    return NS.Presence.ready and L["PLAYING_EMPTY"] or L["PLAYING_INIT"]
end

local function refreshList()
    if not pane:IsShown() then return end
    sorted = NS.Presence:GetSorted()
    local me = UnitName("player")

    -- Own entry pinned on top, same as the browser.
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
            local className, classColor = UI.ClassInfo(e.class)
            if own then
                row.name:SetTextColor(unpack(UI.COLOR.yellow))
            elseif classColor then
                row.name:SetTextColor(unpack(classColor))
            else
                row.name:SetTextColor(unpack(UI.COLOR.text))
            end
            row.level:SetText(e.level)
            row.class:SetText(className or "")
            row.profs:SetText(profText(e.profs))
            row:SetBackdropColor(own and 0.20 or 0.13, own and 0.16 or 0.10,
                                 own and 0.08 or 0.07, 1)
            row.entry = e
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(scroll, #sorted, VISIBLE_ROWS, ROW_H)
    if #sorted == 0 then
        emptyText:SetText(emptyMessage())
        emptyText:Show()
    else
        emptyText:Hide()
    end
    countText:SetText(L["PLAYING_COUNT"]:format(#sorted))
end

-- Native player menu (Invite / Suggest Invite / Whisper / Target), the same
-- path the browser uses. Minimal fallback: Presence carries no boss, so the
-- browser's suggest-for-boss item doesn't apply here.
local function openUnitMenu(entry)
    local name = entry.name
    if name == UnitName("player") then return end
    if FriendsFrame_ShowDropdown then
        local ok = pcall(FriendsFrame_ShowDropdown, name, 1)
        if ok then return end
    end
    local items = { { text = name, isTitle = true, notCheckable = true } }
    if UI.CanInvite() then
        items[#items + 1] = { text = L["BROWSER_INVITE"], notCheckable = true,
            func = function() InviteUnit(name) end }
    end
    items[#items + 1] = { text = L["BROWSER_WHISPER"], notCheckable = true,
        func = function() ChatFrame_SendTell(name) end }
    items[#items + 1] = { text = L["BROWSER_CANCEL"], notCheckable = true }
    EasyMenu(items, menuFrame, "cursor", 0, 0, "MENU")
end

function UI.CreatePlaying(parent)
    pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints()
    pane:Hide()

    menuFrame = CreateFrame("Frame", "HCBBPlayingUnitMenu", UIParent,
                            "UIDropDownMenuTemplate")

    countText = UI.Label(pane, "small", UI.COLOR.gold)
    countText:SetPoint("TOPLEFT", 6, -8)

    scroll = CreateFrame("ScrollFrame", "HCBBPlayingScroll", pane,
                         "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -26)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    scroll:SetScript("OnVerticalScroll", function(self, delta)
        FauxScrollFrame_OnVerticalScroll(self, delta, ROW_H, refreshList)
    end)

    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, pane)
        row:SetSize(436, ROW_H - 2)
        row:SetPoint("TOPLEFT", 6, -28 - (i - 1) * ROW_H)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        row:EnableMouse(true)

        row.dot = UI.Dot(row, 8)
        row.dot:SetPoint("LEFT", 4, 0)
        row.name = UI.Label(row, "small")
        row.name:SetPoint("LEFT", 18, 0)
        row.name:SetWidth(100)
        row.name:SetJustifyH("LEFT")
        row.level = UI.Label(row, "small", UI.COLOR.muted)
        row.level:SetPoint("LEFT", 122, 0)
        row.class = UI.Label(row, "small", UI.COLOR.textMut)
        row.class:SetPoint("LEFT", 150, 0)
        row.class:SetWidth(90)
        row.class:SetJustifyH("LEFT")
        row.profs = UI.Label(row, "small", UI.COLOR.muted)
        row.profs:SetPoint("LEFT", 244, 0)
        row.profs:SetJustifyH("LEFT")

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
            local full = profText(e.profs, true)
            if full ~= "" then
                GameTooltip:AddLine(full, unpack(UI.COLOR.gold))
            else
                GameTooltip:AddLine(L["PLAYING_NO_PROFS"], unpack(UI.COLOR.muted))
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
        emptyText:SetText(emptyMessage())
        countText:SetText(L["PLAYING_COUNT"]:format(#sorted))
    end
    tinsert(UI.refreshers, refreshTexts)
    refreshTexts()

    -- Pings arrive in bursts; one repaint per second is plenty (NFR-P3).
    local pending
    local listener = UI.Listener() -- own target: see UI.Listener
    listener:RegisterMessage("HCBB_PRESENCE_CHANGED", function()
        if pending or not pane:IsShown() then return end
        pending = NS.addon:ScheduleTimer(function()
            pending = nil
            refreshList()
        end, 1)
    end)

    pane:SetScript("OnShow", refreshList)
    return pane
end
