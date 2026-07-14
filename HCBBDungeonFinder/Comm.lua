-- Transport layer: hidden custom channel for presence broadcasts, AceComm
-- whispers for negotiation (architecture §3). Channel mechanics follow the
-- LootCollector pattern proven on Ascension.
local _, NS = ...

local Comm = { channelId = 0, healthy = false, joinTries = 0 }
NS.Comm = Comm

local MSG_TO_POOL = { H = true, B = true }
local MSG_TO_SESSION = { P = true, A = true, N = true, C = true, X = true, S = true }

function Comm:Init(addon)
    self.addon = addon
    self.channel = NS.Data.CONST.CHANNEL
    self.prefix = NS.Data.CONST.COMM_PREFIX

    addon:RegisterEvent("CHAT_MSG_CHANNEL", function(...) Comm:OnChannel(...) end)
    -- Channel join is driven by the participation gate (R23): Core calls
    -- ScheduleJoin when the character proves enrolled, not at login.
    addon:RegisterComm(self.prefix, function(...) Comm:OnComm(...) end)

    -- Keep our payloads out of chat even if the user shows the channel.
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", function(_, _, msg, _, _, _, _, _, _, _, chan)
        if chan == Comm.channel and type(msg) == "string" and msg:sub(1, 4) == "HCBB" then
            return true
        end
    end)

    addon:ScheduleRepeatingTimer(function() Comm:CheckHealth() end, 20)
end

-- The channel system is not usable right at login; LootCollector waits a
-- few seconds after PLAYER_ENTERING_WORLD and so do we.
function Comm:ScheduleJoin()
    self.addon:ScheduleTimer(function() Comm:EnsureJoined() end,
                             NS.Data.CONST.CHANNEL_JOIN_DELAY)
end

function Comm:EnsureJoined()
    if not NS.eligible then return end -- R23: participants only
    local id = GetChannelName(self.channel)
    if not id or id == 0 then
        JoinPermanentChannel(self.channel)
    end
    self:HideFromChat()
    self:CheckHealth()
end

function Comm:Leave()
    local id = GetChannelName(self.channel)
    if id and id > 0 then
        LeaveChannelByName(self.channel)
    end
    self.channelId = 0
    if self.healthy then
        self.healthy = false
        self.addon:SendMessage("HCBB_CHANNEL_DOWN")
    end
    NS.Pool:Wipe()
end

function Comm:HideFromChat()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and ChatFrame_RemoveChannel then
            ChatFrame_RemoveChannel(frame, self.channel)
        end
    end
end

function Comm:CheckHealth()
    if not NS.eligible then return end -- stay parked while not enrolled
    local id, name = GetChannelName(self.channel)
    local ok = id and id > 0 and name and name:lower() == self.channel:lower()
    self.channelId = ok and id or 0
    if ok ~= self.healthy then
        self.healthy = ok
        self.addon:SendMessage(ok and "HCBB_CHANNEL_UP" or "HCBB_CHANNEL_DOWN")
    end
    if not ok then
        self.joinTries = self.joinTries + 1
        self:EnsureJoined()
    else
        self.joinTries = 0
    end
end

-- Presence broadcast (H/B). Loss-tolerant: false return just means "not
-- joined yet"; the heartbeat will carry the state on the next tick.
function Comm:Broadcast(tbl)
    if not self.healthy or self.channelId == 0 then return false end
    local payload = NS.Codec.encode(tbl)
    if not payload then return false end
    SendChatMessage(payload, "CHANNEL", nil, self.channelId)
    NS.Debug("TX chan", payload)
    return true
end

-- Negotiation unicast (P/A/N/C/X), invisible to the recipient's chat.
function Comm:Whisper(target, tbl, prio)
    local payload = NS.Codec.encode(tbl)
    if not payload then return false end
    self.addon:SendCommMessage(self.prefix, payload, "WHISPER", target,
                               prio or "NORMAL")
    NS.Debug("TX whsp", target, payload)
    return true
end

-- Addon broadcast to the current party/raid (used for suggest-invite, R24).
-- Not chat: no escape-code filtering, and it never loops back to the sender.
function Comm:SendGroup(tbl)
    local payload = NS.Codec.encode(tbl)
    if not payload then return false end
    local dist = (GetNumRaidMembers() > 0 and "RAID")
        or (GetNumPartyMembers() > 0 and "PARTY")
    if not dist then return false end
    self.addon:SendCommMessage(self.prefix, payload, dist, nil, "NORMAL")
    NS.Debug("TX grp", dist, payload)
    return true
end

function Comm:OnChannel(_, msg, sender, _, _, _, _, _, _, chanName)
    if chanName ~= self.channel then return end
    if type(msg) ~= "string" or msg:sub(1, 4) ~= "HCBB" then return end
    sender = sender and sender:match("^[^%-]+") or sender -- strip realm suffix
    local t, err = NS.Codec.decode(msg)
    if not t then
        if err == "version" then NS.NoticeNewerVersion() end
        return
    end
    NS.Debug("RX chan", sender, msg)
    if not MSG_TO_POOL[t.type] then return end -- negotiation never on channel
    if t.type == "H" then
        -- Same protocol major (Codec accepted it), but a peer on a newer
        -- release nudges us to update — once per session (NFR-C5).
        if NS.Codec.isNewer(t.ver, NS.VERSION) then NS.NoticeNewerVersion() end
        NS.Pool:OnHello(sender, t)
    else
        NS.Pool:OnBye(sender)
    end
end

function Comm:OnComm(_, message, _, sender)
    sender = sender and sender:match("^[^%-]+") or sender
    local t, err = NS.Codec.decode(message)
    if not t then
        if err == "version" then NS.NoticeNewerVersion() end
        return
    end
    NS.Debug("RX whsp", sender, message)
    if not MSG_TO_SESSION[t.type] then return end
    NS.Session:OnWire(sender, t)
end
