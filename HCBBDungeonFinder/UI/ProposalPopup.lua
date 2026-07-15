-- Match proposal popup (design 1d-1g): leads with YOUR assigned role,
-- member rows with crown + role icon + status, gradient countdown that
-- turns red under 10 s (auto-decline at 0), footer that swaps in place.
-- Accept locks BOTH buttons ("waiting for others").
local _, NS = ...
local UI = NS.UI
local L = NS.L
local WHITE = "Interface\\Buttons\\WHITE8X8"

local popup, current
local memberRows = {}

local function setBar(grad, red)
    if red then
        popup.barFill:SetVertexColor(0.85, 0.24, 0.20, 1)
    else
        UI.Recolor(popup.barFill, grad)
    end
end

local function setFooter(text, color)
    popup.footer:SetText(text)
    popup.footer:SetTextColor(unpack(color))
    popup.footer:Show()
    popup.accept:Hide()
    popup.decline:Hide()
    popup.okay:Show()
end

local function setMemberStatus(name, status)
    for _, row in ipairs(memberRows) do
        if row.memberName == name then
            row.accepted = status == "accepted"
            if status == "accepted" then
                row.status:SetText(UI.ICON.check)
            elseif status == "declined" then
                row.status:SetText(UI.ICON.cross)
            else
                row.status:SetText(UI.ICON.wait)
            end
        end
    end
end

local function countAccepted()
    local n = 0
    for _, row in ipairs(memberRows) do
        if row.memberName and row.accepted then n = n + 1 end
    end
    return n
end

local function startCountdown()
    local total = NS.Data.CONST.PROPOSAL_TIMEOUT
    local start = NS.now()
    setBar(UI.GRAD.gold, false)
    popup.bar:SetScript("OnUpdate", function(self)
        local left = total - (NS.now() - start)
        if left <= 0 then
            self:SetScript("OnUpdate", nil)
            popup.barFill:SetWidth(0.001)
            return
        end
        popup.barFill:SetWidth(math.max(0.001, (self:GetWidth() - 2) * left / total))
        setBar(UI.GRAD.gold, left < 10)
        self.text:SetText(L["PROP_TIMER"]:format(math.ceil(left)))
    end)
end

local function stopCountdown()
    popup.bar:SetScript("OnUpdate", nil)
end

local function onShowProposal(_, proposal)
    current = proposal
    current.done = false

    local b = NS.Data.BOSSES[proposal.bossId]
    popup.boss:SetText(("%s |cff8f846c\194\183 %s \194\183 %d|r"):format(
        b.boss, b.dungeon, proposal.size))
    popup.youIcon:SetRole(proposal.yourRole)
    popup.youText:SetText(L["PROP_YOU_ROLE"]:format(L[UI.ROLE_KEY[proposal.yourRole]]))
    popup.youRole:SetText(L[UI.ROLE_KEY[proposal.yourRole]])
    local rc = UI.ROLE_COLOR[proposal.yourRole]
    popup.youRole:SetTextColor(rc[1], rc[2], rc[3])
    popup.youBanner:SetBackdropBorderColor(rc[1], rc[2], rc[3], 1)

    local me = UnitName("player")
    for i = 1, 5 do
        local row = memberRows[i]
        local m = proposal.members[i]
        if m then
            row.memberName = m.name
            row.memberLevel = m.level
            -- Class isn't on the P wire; resolve it like the browser does —
            -- from the local pool (peers) or UnitClass (self) — for the tooltip.
            local cls = m.class
            if not cls then
                if m.name == me then
                    cls = NS.Data.CLASS_ABBREV[select(2, UnitClass("player"))]
                elseif NS.Pool.entries[m.name] then
                    cls = NS.Pool.entries[m.name].class
                end
            end
            row.memberClass = cls
            row.crown[m.name == proposal.leader and "Show" or "Hide"](row.crown)
            row.name:SetText(("%s |cff9c927c%d|r"):format(m.name, m.level))
            row.name:SetTextColor(unpack(m.name == me and UI.COLOR.yellow or UI.COLOR.textHi))
            row.icon:SetRole(m.role)
            local mc = UI.ROLE_COLOR[m.role]
            row.roleText:SetText(L[UI.ROLE_KEY[m.role]])
            row.roleText:SetTextColor(mc[1], mc[2], mc[3])
            row.bg:SetVertexColor(m.name == me and 0.20 or 0, m.name == me and 0.16 or 0,
                                  m.name == me and 0.08 or 0, m.name == me and 1 or 0.32)
            setMemberStatus(m.name, "pending")
            row:Show()
        else
            row.memberName = nil
            row:Hide()
        end
    end

    popup.leaderText:SetText(L["LEADER"] .. ": |cffe8dcc0" .. proposal.leader .. "|r")
    popup.countText:SetText("")
    popup.footer:Hide()
    popup.okay:Hide()
    popup.accept:Show()
    popup.accept:Enable()
    popup.decline:Show()
    popup.decline:Enable()
    startCountdown()
    popup:Show()
    popup:Raise()
    if NS.addon.db.global.sound then PlaySound("ReadyCheck") end
end

local function onUpdateProposal(_, kind)
    if not popup:IsShown() or not current then return end
    if kind == "forming" then
        current.done = true
        stopCountdown()
        popup.barFill:SetWidth(math.max(0.001, popup.bar:GetWidth() - 2))
        setBar(UI.GRAD.greenB, false)
        popup.bar.text:SetText(L["PROP_ALL_IN"])
        for _, row in ipairs(memberRows) do
            if row.memberName then setMemberStatus(row.memberName, "accepted") end
        end
        setFooter(L["PROP_FORMING"], UI.COLOR.green)
    elseif kind == "refill" or kind == "aborted" or kind == "cancel" or kind == "declined" then
        current.done = true
        stopCountdown()
        popup.bar.text:SetText(L["PROP_CANCELLED"])
        setFooter(L["PROP_DECLINED"], UI.COLOR.red)
    elseif kind == "timeout" or kind == "expired" then
        current.done = true
        stopCountdown()
        popup.bar.text:SetText(L["PROP_CANCELLED"])
        setFooter(L["PROP_EXPIRED"], UI.COLOR.muted)
    elseif kind == "declined_self" then
        popup:Hide()
    end
    NS.addon:ScheduleTimer(function()
        if popup:IsShown() and current and current.done then popup:Hide() end
    end, 5)
end

local function onAccept()
    if not current then return end
    popup.accept:Disable()
    popup.decline:Disable() -- Accept locks both buttons (design 1k)
    setMemberStatus(UnitName("player"), "accepted")
    popup.countText:SetText(("%d %s %d"):format(countAccepted(), L["PROP_OF"], current.size))
    popup.footer:SetText(L["PROP_WAIT"])
    popup.footer:SetTextColor(unpack(UI.COLOR.gold))
    popup.footer:Show()
    if current.demo then
        NS.addon:ScheduleTimer(function()
            NS.addon:SendMessage("HCBB_PROPOSAL_UPDATE", "forming")
            -- End-to-end demo: a formed group takes you out of the queue. There
            -- is no real party to fire OnParty, so end any live search here so
            -- the demo faithfully reflects the real outcome.
            if NS.Session.state == "SEARCHING" or NS.Session.state == "PAUSED" then
                NS.Session:Cancel()
            end
        end, 2)
    else
        NS.Session:Accept()
    end
end

local function onDecline()
    stopCountdown()
    if current and not current.demo then NS.Session:Decline() end
    popup:Hide()
end

function UI.CreateProposal()
    popup = CreateFrame("Frame", "HCBBProposalPopup", UIParent)
    popup:SetSize(384, 336)
    popup:SetPoint("CENTER", 0, 120)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetToplevel(true)
    popup:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    popup:SetBackdropColor(0, 0, 0, 0)
    popup:SetBackdropBorderColor(0.42, 0.353, 0.204, 1) -- #6b5a34
    popup.bg = UI.Fill(popup, "BACKGROUND", UI.GRAD.window)
    popup.bg:SetPoint("TOPLEFT", 3, -3)
    popup.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    popup:EnableMouse(true)
    popup:Hide()

    local titleBar = CreateFrame("Frame", nil, popup)
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)
    titleBar:SetHeight(28)
    local tb = UI.Fill(titleBar, "BACKGROUND", UI.GRAD.title)
    tb:SetAllPoints()
    popup.title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("CENTER", 0, 0)
    popup.title:SetTextColor(unpack(UI.COLOR.yellow))

    popup.boss = UI.Label(popup, nil, UI.COLOR.white)
    popup.boss:SetPoint("TOP", 0, -40)

    -- You-banner: the loudest element (design 1k)
    popup.youBanner = CreateFrame("Frame", nil, popup)
    popup.youBanner:SetSize(356, 30)
    popup.youBanner:SetPoint("TOP", 0, -58)
    popup.youBanner:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    popup.youBanner:SetBackdropColor(0, 0, 0, 0.35)
    popup.youIcon = UI.RoleIcon(popup.youBanner, 8, 15)
    popup.youIcon:SetPoint("LEFT", 10, 0)
    popup.youText = UI.Label(popup.youBanner, "small", UI.COLOR.text)
    popup.youText:SetPoint("LEFT", 30, 0)
    popup.youRole = UI.Label(popup.youBanner)
    popup.youRole:SetPoint("LEFT", popup.youText, "RIGHT", 5, 0)

    local list = UI.Panel(popup)
    list:SetPoint("TOPLEFT", 14, -94)
    list:SetPoint("TOPRIGHT", -14, -94)
    list:SetHeight(5 * 26)
    list:SetBackdropColor(0, 0, 0, 0.32)

    for i = 1, 5 do
        local row = CreateFrame("Frame", nil, popup)
        row:SetSize(354, 26)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -(i - 1) * 26)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture(WHITE)
        row.bg:SetVertexColor(0, 0, 0, 0.32)
        row.crown = row:CreateTexture(nil, "ARTWORK")
        row.crown:SetSize(13, 13)
        row.crown:SetPoint("LEFT", 8, 0)
        row.crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        row.name = UI.Label(row, "small")
        row.name:SetPoint("LEFT", 26, 0)
        row.name:SetWidth(140)
        row.name:SetJustifyH("LEFT")
        row.icon = UI.RoleIcon(row, 8, 14)
        row.icon:SetPoint("LEFT", 176, 0)
        row.roleText = UI.Label(row, "small")
        row.roleText:SetPoint("LEFT", 194, 0)
        row.status = UI.Label(row)
        row.status:SetPoint("RIGHT", -10, 0)

        -- Class tooltip on hover, same mechanism as the "Who's Looking" browser.
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if not self.memberName then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.memberName, 1, 1, 1)
            local className, classColor = UI.ClassInfo(self.memberClass)
            if className then
                GameTooltip:AddLine(("Level %d %s"):format(self.memberLevel or 0, className),
                    classColor and classColor[1] or 0.8,
                    classColor and classColor[2] or 0.8,
                    classColor and classColor[3] or 0.8)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        memberRows[i] = row
    end

    popup.countText = UI.Label(popup, "small", UI.COLOR.muted)
    popup.countText:SetPoint("TOPLEFT", 16, -230)
    popup.leaderText = UI.Label(popup, "small", UI.COLOR.muted)
    popup.leaderText:SetPoint("TOPRIGHT", -16, -230)

    -- Countdown bar
    popup.bar = CreateFrame("Frame", nil, popup)
    popup.bar:SetSize(356, 16)
    popup.bar:SetPoint("TOP", 0, -248)
    popup.bar:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    popup.bar:SetBackdropColor(0, 0, 0, 0.5)
    popup.bar:SetBackdropBorderColor(0, 0, 0, 1)
    -- Fill as a texture (ARTWORK) on the bar itself, not a child frame, so
    -- the countdown text (OVERLAY) draws above it instead of being hidden.
    popup.barFill = UI.Fill(popup.bar, "ARTWORK", UI.GRAD.gold)
    popup.barFill:SetPoint("TOPLEFT", 1, -1)
    popup.barFill:SetPoint("BOTTOMLEFT", 1, 1)
    popup.barFill:SetWidth(354)
    popup.bar.text = UI.Label(popup.bar, "small", UI.COLOR.white)
    popup.bar.text:SetPoint("CENTER", 0, 0)

    popup.accept = UI.ActionButton(popup, 130, 26)
    popup.accept:SetPoint("BOTTOMLEFT", 42, 42)
    popup.accept:SetScript("OnClick", onAccept)
    popup.decline = UI.Button(popup, 130, 26)
    popup.decline:SetPoint("BOTTOMRIGHT", -42, 42)
    popup.decline:SetScript("OnClick", onDecline)

    popup.okay = UI.Button(popup, 110, 24)
    popup.okay:SetPoint("BOTTOM", 0, 42)
    popup.okay:SetScript("OnClick", function() popup:Hide() end)
    popup.okay:Hide()

    popup.footer = UI.Label(popup, "small", UI.COLOR.muted)
    popup.footer:SetPoint("BOTTOM", 0, 16)
    popup.footer:SetWidth(356)
    popup.footer:SetJustifyH("CENTER")
    popup.footer:Hide()

    local function refreshTexts()
        popup.title:SetText(L["PROP_TITLE"])
        popup.accept:SetText(L["BTN_ACCEPT"])
        popup.decline:SetText(L["BTN_DECLINE"])
        popup.okay:SetText(L["BTN_OKAY"])
    end
    tinsert(UI.refreshers, refreshTexts)
    refreshTexts()

    local listener = UI.Listener() -- own target: see UI.Listener
    listener:RegisterMessage("HCBB_PROPOSAL_SHOW", onShowProposal)
    listener:RegisterMessage("HCBB_PROPOSAL_UPDATE", onUpdateProposal)
    listener:RegisterMessage("HCBB_PROPOSAL_MEMBER", function(_, name, status)
        if popup:IsShown() then
            setMemberStatus(name, status)
            if current then
                popup.countText:SetText(("%d %s %d"):format(countAccepted(), L["PROP_OF"], current.size))
            end
        end
    end)
    listener:RegisterMessage("HCBB_STATE_CHANGED", function(_, state)
        if state == "INGROUP" and popup:IsShown() then popup:Hide() end
    end)
end
