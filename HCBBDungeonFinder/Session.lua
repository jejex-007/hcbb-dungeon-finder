-- Proposal/negotiation state machine (architecture §7, design 1l).
-- States: IDLE, SEARCHING, COLLECTING (leader), PROPOSED (candidate),
-- FORMING, PAUSED, INGROUP. Every failure edge lands back in SEARCHING
-- with the listing intact ("zero dead ends").
local _, NS = ...

local Session = { state = "IDLE", seq = 0 }
NS.Session = Session

local function C() return NS.Data.CONST end
local function now() return NS.now() end

function Session:Init(addon)
    self.addon = addon
    self.me = UnitName("player")
    self.blocked = {} -- name -> unblock time (decliner cooldown)

    addon:RegisterMessage("HCBB_POOL_CHANGED", function() Session:OnPoolChanged() end)
    addon:RegisterMessage("HCBB_CHANNEL_UP", function() Session:OnChannelUp() end)
    addon:RegisterMessage("HCBB_CHANNEL_DOWN", function() Session:OnChannelDown() end)
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

-- prefs: { bossId, roles, minSize, lead } — validated by the UI (R1–R5),
-- re-validated here as the single entry point.
function Session:StartSearch(prefs)
    if self.state ~= "IDLE" then return false end
    if not NS.eligible then return false end -- R23: participants only
    if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then return false end
    local level = UnitLevel("player")
    if not NS.Data:IsEligible(prefs.bossId, level) then return false end
    if prefs.roles < 1 or prefs.roles > 15 then return false end

    self.reg = { bossId = prefs.bossId, roles = prefs.roles,
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
    self.seq = (self.seq + 1) % 65536
    local _, classToken = UnitClass("player")
    local msg = { type = "H", seq = self.seq, bossId = self.reg.bossId,
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
    local listings = NS.Pool:GetForBoss(self.reg.bossId, self.blocked)
    local match = NS.Matcher.findForSelf(listings, {
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
    local pending = { matchId = self.me .. "-" .. self.seq,
                      members = match.members, size = match.size,
                      acks = {}, waiting = 0 }
    self.pending = pending
    self:SetState("COLLECTING")

    for _, m in ipairs(match.members) do
        if m.name ~= self.me then
            pending.waiting = pending.waiting + 1
            NS.Comm:Whisper(m.name, {
                type = "P", matchId = pending.matchId,
                bossId = self.reg.bossId, size = match.size,
                yourRole = m.role, members = match.members,
            })
        else
            self.myRole = m.role
        end
    end
    -- The leader sees the same popup as everyone (design 1d), own consent
    -- included: accepting is what arms the collection.
    self.addon:SendMessage("HCBB_PROPOSAL_SHOW", {
        matchId = pending.matchId, bossId = self.reg.bossId,
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
    local valid = me ~= nil
        and msg.bossId == self.reg.bossId
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

function Session:GetSearchInfo()
    if not self.reg then return nil end
    return now() - self.reg.startedAt,
           NS.Pool:CountBracket(self.reg.bossId, self.reg.level, self.me)
end
