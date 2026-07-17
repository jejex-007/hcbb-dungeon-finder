-- Proposal/negotiation state machine (architecture §7, design 1l).
-- States: IDLE, SEARCHING, COLLECTING (leader), PROPOSED (candidate),
-- FORMING, PAUSED, INGROUP. Every failure edge lands back in SEARCHING
-- with the listing intact ("zero dead ends").
local _, NS = ...

local Session = { state = "IDLE", seq = 0 }
NS.Session = Session

-- Own AceEvent target, and it is NOT optional: CallbackHandler keeps a single
-- callback per (message, object) — `events[eventname][self] = func` — so any
-- module subscribing through the shared `addon` object silently overwrites the
-- previous subscriber, with no error. Session used to lose HCBB_POOL_CHANGED
-- to the Browser and HCBB_CHANNEL_UP/DOWN to MainFrame, which killed reactive
-- matching (only the 91 s/181 s grace timers still fired) and left a PAUSED
-- search unable to resume. Subscribe on ourselves, never on `addon`.
LibStub("AceEvent-3.0"):Embed(Session)

local function C() return NS.Data.CONST end
local function now() return NS.now() end

function Session:Init(addon)
    self.addon = addon
    self.me = UnitName("player")
    self.blocked = {} -- name -> unblock time (decliner cooldown)

    Session:RegisterMessage("HCBB_POOL_CHANGED", function() Session:OnPoolChanged() end)
    Session:RegisterMessage("HCBB_CHANNEL_UP", function() Session:OnChannelUp() end)
    Session:RegisterMessage("HCBB_CHANNEL_DOWN", function() Session:OnChannelDown() end)
    addon:RegisterEvent("PARTY_MEMBERS_CHANGED", function() Session:OnParty() end)
    addon:RegisterEvent("PARTY_INVITE_REQUEST", function(_, sender) Session:OnInviteSeen(sender) end)
end

function Session:SetState(state)
    if self.state == state then return end
    NS.Debug("state", self.state, "->", state)
    self.state = state
    self.addon:SendMessage("HCBB_STATE_CHANGED", state)
end

local function hasRole(mask, role)
    return math.floor(mask / role) % 2 == 1
end

-- ------------------------------------------------------------ listing ----

-- prefs: { bossIds, roles, minSize, lead } — validated by the UI (R1/R28,
-- R3–R5), re-validated here as the single entry point. bossIds is
-- canonicalized (sorted ascending, deduped) so the wire encoder never sees
-- a click-ordered list.
function Session:StartSearch(prefs)
    if self.state ~= "IDLE" then return false end
    if not NS.eligible then return false end -- R23: participants only
    if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then return false end
    local level = UnitLevel("player")
    if prefs.roles < 1 or prefs.roles > 15 then return false end

    local ids, seen = {}, {}
    for _, id in ipairs(prefs.bossIds or {}) do
        if not seen[id] then
            seen[id] = true
            if not NS.Data:IsEligible(id, level) then return false end
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    if #ids < 1 or #ids > NS.Data.CONST.MAX_TARGETS then return false end

    self.reg = { bossIds = ids, roles = prefs.roles,
                 minSize = prefs.minSize, lead = prefs.lead and 1 or 0,
                 level = level, startedAt = now() }
    self:SetState(NS.Comm.healthy and "SEARCHING" or "PAUSED")
    self.hbTimer = self.addon:ScheduleRepeatingTimer(function()
        Session:Heartbeat()
    end, C().HEARTBEAT)
    -- Re-run the matcher when the size grace thresholds open up (R14).
    self.graceTimers = {
        self.addon:ScheduleTimer(function() Session:TryMatch() end, C().GRACE_SMALLER + 1),
        self.addon:ScheduleTimer(function() Session:TryMatch() end, C().GRACE_SMALLER * 2 + 1),
    }
    self:Heartbeat()
    return true
end

function Session:StopSearch(silent)
    if self.hbTimer then self.addon:CancelTimer(self.hbTimer, true); self.hbTimer = nil end
    for _, t in ipairs(self.graceTimers or {}) do self.addon:CancelTimer(t, true) end
    self.graceTimers = nil
    if not silent then
        self.seq = (self.seq + 1) % 65536
        NS.Comm:Broadcast({ type = "B", seq = self.seq })
    end
    NS.Pool:Remove(self.me)
    self.reg = nil
end

function Session:Cancel()
    if self.state == "SEARCHING" or self.state == "PAUSED" then
        self:StopSearch()
        self:SetState("IDLE")
    end
end

function Session:Heartbeat()
    if not self.reg then return end
    self.reg.level = UnitLevel("player")
    -- Levelling up mid-search can push a target out of its bracket (R2).
    -- Prune before broadcasting: peers hard-reject a HELLO with any
    -- ineligible id, so an unpruned list would rot the whole listing.
    local keep = {}
    for _, id in ipairs(self.reg.bossIds) do
        if NS.Data:IsEligible(id, self.reg.level) then keep[#keep + 1] = id end
    end
    if #keep == 0 then
        self.addon:Print(NS.L["MSG_OUTLEVELED"])
        self:Cancel()
        return
    end
    self.reg.bossIds = keep
    self.seq = (self.seq + 1) % 65536
    local _, classToken = UnitClass("player")
    local msg = { type = "H", seq = self.seq, bossIds = self.reg.bossIds,
                  level = self.reg.level, roles = self.reg.roles,
                  minSize = self.reg.minSize, lead = self.reg.lead,
                  ver = NS.VERSION,
                  class = classToken and NS.Data.CLASS_ABBREV[classToken] or nil }
    NS.Comm:Broadcast(msg)
    -- Local echo: our own listing joins the pool even before the channel
    -- message loops back (dedupe by seq makes the echo a no-op).
    NS.Pool:OnHello(self.me, msg)
end

-- ------------------------------------------------------------ matching ---

function Session:OnPoolChanged()
    if self.state ~= "SEARCHING" then return end
    if self.matchTimer then return end
    self.matchTimer = self.addon:ScheduleTimer(function()
        Session.matchTimer = nil
        Session:TryMatch()
    end, C().MATCH_DEBOUNCE)
end

function Session:AllowedSizes()
    local age = now() - self.reg.startedAt
    local sizes = { 5 }
    if age > C().GRACE_SMALLER then sizes[#sizes + 1] = 4 end
    if age > C().GRACE_SMALLER * 2 then sizes[#sizes + 1] = 3 end
    return sizes
end

function Session:TryMatch()
    if self.state ~= "SEARCHING" or not self.reg then return end
    for name, untilTime in pairs(self.blocked) do
        if now() > untilTime then self.blocked[name] = nil end
    end
    -- R26: only match fresh (green) listings, so a client that went quiet but
    -- hasn't expired yet is never proposed into a group it can't answer.
    -- R28: one per-boss pool per targeted boss; the multi layer walks them
    -- size-major (largest group anywhere beats boss order).
    local byBoss = {}
    for _, id in ipairs(self.reg.bossIds) do
        byBoss[id] = NS.Pool:GetForBoss(id, self.blocked, C().FRESH_GREEN)
    end
    local match = NS.Matcher.findForSelfMulti(self.reg.bossIds, byBoss, {
        allowedSizes = self:AllowedSizes(),
        maxSpan = C().MAX_LEVEL_SPAN,
        selfName = self.me,
    })
    if match and match.leader == self.me then
        self:StartCollecting(match)
    end
end

-- --------------------------------------------------------- leader side ---

function Session:StartCollecting(match)
    self.seq = (self.seq + 1) % 65536
    -- match.bossId: the boss the multi layer settled on (R28) — a proposal
    -- is always single-boss (R10), whatever the registration targeted.
    local pending = { matchId = self.me .. "-" .. self.seq,
                      members = match.members, size = match.size,
                      bossId = match.bossId,
                      acks = {}, waiting = 0 }
    self.pending = pending
    self:SetState("COLLECTING")

    for _, m in ipairs(match.members) do
        if m.name ~= self.me then
            pending.waiting = pending.waiting + 1
            NS.Comm:Whisper(m.name, {
                type = "P", matchId = pending.matchId,
                bossId = match.bossId, size = match.size,
                yourRole = m.role, members = match.members,
            })
        else
            self.myRole = m.role
        end
    end
    -- The leader sees the same popup as everyone (design 1d), own consent
    -- included: accepting is what arms the collection.
    self.addon:SendMessage("HCBB_PROPOSAL_SHOW", {
        matchId = pending.matchId, bossId = match.bossId,
        size = match.size, yourRole = self.myRole,
        members = match.members, leader = self.me, iAmLeader = true,
    })
    self.collectTimer = self.addon:ScheduleTimer(function()
        Session:AbortMatch("timeout", true)
    end, C().PROPOSAL_TIMEOUT)
end

function Session:OnAck(sender, matchId)
    local p = self.pending
    if not (self.state == "COLLECTING" and p and p.matchId == matchId) then return end
    if p.acks[sender] then return end
    p.acks[sender] = true
    p.waiting = p.waiting - 1
    self.addon:SendMessage("HCBB_PROPOSAL_MEMBER", sender, "accepted")
    if p.waiting == 0 and p.selfAccepted then self:ConfirmMatch() end
end

function Session:OnNack(sender, matchId, reason)
    local p = self.pending
    if not (self.state == "COLLECTING" and p and p.matchId == matchId) then return end
    if reason == "declined" then
        self.blocked[sender] = now() + C().DECLINE_COOLDOWN
    end
    self:AbortMatch("refill", true, sender)
end

function Session:ConfirmMatch()
    local p = self.pending
    self:CancelTimer("collectTimer")
    for _, m in ipairs(p.members) do
        if m.name ~= self.me then
            NS.Comm:Whisper(m.name, { type = "C", matchId = p.matchId }, "ALERT")
            InviteUnit(m.name)
        end
    end
    self:SetState("FORMING")
    self.addon:SendMessage("HCBB_PROPOSAL_UPDATE", "forming")
    self.formingTimer = self.addon:ScheduleTimer(function()
        Session:BackToSearching("forming_timeout")
    end, C().FORMING_TIMEOUT)
end

-- Leader-side failure: notify everyone who already committed, drop
-- non-responders from the pool (design 1l), resume searching.
function Session:AbortMatch(reason, notify, exceptName)
    local p = self.pending
    if not p then return end
    self:CancelTimer("collectTimer")
    for _, m in ipairs(p.members) do
        if m.name ~= self.me and m.name ~= exceptName then
            if notify then
                NS.Comm:Whisper(m.name, { type = "X", matchId = p.matchId,
                                          reason = reason })
            end
            if reason == "timeout" and not p.acks[m.name] then
                NS.Pool:Remove(m.name)
            end
        end
    end
    self.pending = nil
    self:BackToSearching(reason)
end

-- ------------------------------------------------------ candidate side ---

function Session:OnPropose(sender, msg)
    -- One live proposal at a time (R16): anything unexpected is "busy".
    if self.state ~= "SEARCHING" or not self.reg then
        NS.Comm:Whisper(sender, { type = "N", matchId = msg.matchId, reason = "busy" })
        return
    end
    -- The matchId must be attributable to the proposing leader (NFR-S2).
    if msg.matchId:match("^(.+)%-%d+$") ~= sender then return end

    local me
    for _, m in ipairs(msg.members) do
        if m.name == self.me then me = m end
    end
    -- R28: the proposed boss must be one of OUR targets, not necessarily the
    -- only one — a 0.3.0 leader may propose any boss we both listed.
    local bossOk = false
    for _, id in ipairs(self.reg.bossIds) do
        if id == msg.bossId then bossOk = true break end
    end
    local valid = me ~= nil
        and bossOk
        and msg.size >= self.reg.minSize
        and me.role == msg.yourRole
        and hasRole(self.reg.roles, msg.yourRole)
    if valid then -- challenge rule R9, re-checked on our own data
        for _, m in ipairs(msg.members) do
            if math.abs(m.level - self.reg.level) > C().MAX_LEVEL_SPAN then
                valid = false
            end
        end
    end
    if not valid then
        NS.Comm:Whisper(sender, { type = "N", matchId = msg.matchId, reason = "changed" })
        return
    end

    self.current = { matchId = msg.matchId, leader = sender, msg = msg }
    self:SetState("PROPOSED")
    self.addon:SendMessage("HCBB_PROPOSAL_SHOW", {
        matchId = msg.matchId, bossId = msg.bossId, size = msg.size,
        yourRole = msg.yourRole, members = msg.members, leader = sender,
        iAmLeader = false,
    })
    self.proposalTimer = self.addon:ScheduleTimer(function()
        Session:Decline(true) -- auto-decline at 0 s (design 1d)
    end, C().PROPOSAL_TIMEOUT)
end

-- UI entry point, both roles: leader accepting arms the collection,
-- candidate accepting sends the ACK.
function Session:Accept()
    if self.state == "COLLECTING" and self.pending then
        self.pending.selfAccepted = true
        if self.pending.waiting == 0 then self:ConfirmMatch() end
    elseif self.state == "PROPOSED" and self.current then
        NS.Comm:Whisper(self.current.leader,
                        { type = "A", matchId = self.current.matchId }, "ALERT")
        self.current.accepted = true
    end
end

function Session:Decline(auto)
    if self.state == "COLLECTING" and self.pending then
        self:AbortMatch("cancel", true)
    elseif self.state == "PROPOSED" and self.current then
        self:CancelTimer("proposalTimer")
        NS.Comm:Whisper(self.current.leader,
                        { type = "N", matchId = self.current.matchId,
                          reason = auto and "timeout" or "declined" }, "ALERT")
        self.current = nil
        self:BackToSearching(auto and "expired" or "declined_self")
    end
end

function Session:OnConfirm(sender, matchId)
    local cur = self.current
    if not (self.state == "PROPOSED" and cur and cur.matchId == matchId
            and cur.leader == sender and cur.accepted) then
        return
    end
    self:CancelTimer("proposalTimer")
    self:SetState("FORMING")
    self.addon:SendMessage("HCBB_PROPOSAL_UPDATE", "forming")
    self.formingTimer = self.addon:ScheduleTimer(function()
        Session.current = nil
        Session:BackToSearching("forming_timeout")
    end, C().FORMING_TIMEOUT)
end

function Session:OnAbort(sender, matchId)
    local cur = self.current
    if not (cur and cur.matchId == matchId and cur.leader == sender) then return end
    self:CancelTimer("proposalTimer")
    self:CancelTimer("formingTimer")
    self.current = nil
    if self.state == "PROPOSED" or self.state == "FORMING" then
        self:BackToSearching("aborted")
    end
end

-- --------------------------------------------------------- transitions ---

function Session:BackToSearching(why)
    if not self.reg then self:SetState("IDLE") return end
    self:SetState(NS.Comm.healthy and "SEARCHING" or "PAUSED")
    self.addon:SendMessage("HCBB_PROPOSAL_UPDATE",
                           why == "forming_timeout" and "expired" or why)
    self:OnPoolChanged()
end

function Session:OnInviteSeen(sender)
    -- Only the expected leader's invite disarms the watchdog; a stranger's
    -- invite popup must not make us miss a leader who went offline.
    if self.state == "FORMING"
       and (not self.current or self.current.leader == sender) then
        self:CancelTimer("formingTimer") -- invite arrived; player decides (R19)
    end
end

function Session:OnParty()
    local n = GetNumPartyMembers()
    if n > 0 and self.state ~= "INGROUP" and self.state ~= "IDLE" then
        self:CancelTimer("formingTimer")
        self:StopSearch()
        self.pending, self.current = nil, nil
        self:SetState("INGROUP")
    elseif n == 0 and self.state == "INGROUP" then
        self:SetState("IDLE")
    end
    -- Always notify the UI so the Search button reflects group state, even
    -- when no Session state transition happened (e.g. idle + manually grouped).
    self.addon:SendMessage("HCBB_GROUP_CHANGED")
end

function Session:OnChannelDown()
    if self.state == "SEARCHING" then
        self:SetState("PAUSED")
        NS.Pool:Wipe() -- replica is stale the moment we stop hearing peers
    end
end

function Session:OnChannelUp()
    if self.state == "PAUSED" and self.reg then
        self:SetState("SEARCHING")
        self:Heartbeat() -- immediate rebroadcast (design 1l)
    end
end

function Session:OnWire(sender, t)
    if t.type == "P" then self:OnPropose(sender, t)
    elseif t.type == "A" then self:OnAck(sender, t.matchId)
    elseif t.type == "N" then self:OnNack(sender, t.matchId, t.reason)
    elseif t.type == "C" then self:OnConfirm(sender, t.matchId)
    elseif t.type == "X" then self:OnAbort(sender, t.matchId)
    elseif t.type == "S" then self:OnSuggest(sender, t)
    end
end

-- Suggest-invite from a group member (R24). Just relay to the UI; only a
-- client that can actually invite will surface the prompt.
function Session:OnSuggest(sender, t)
    self.addon:SendMessage("HCBB_SUGGESTION", sender, t.target, t.bossId)
end

function Session:CancelTimer(key)
    if self[key] then
        self.addon:CancelTimer(self[key], true)
        self[key] = nil
    end
end

-- UI helpers -----------------------------------------------------------

-- Returns (elapsed, fresh, total): fresh = matchable green listings in the
-- bracket, total = everyone still listed. See Pool:CountBracket.
function Session:GetSearchInfo()
    if not self.reg then return nil end
    local fresh, total = NS.Pool:CountBracket(self.reg.bossIds, self.reg.level, self.me)
    return now() - self.reg.startedAt, fresh, total
end
