-- English — complete base locale (NFR-L1). Every user-visible string lives
-- here (NFR-L2); other locales fall back to these values. File is UTF-8.
local _, NS = ...
NS.locales = NS.locales or {}

NS.locales.enUS = {
    TITLE = "HCBB Dungeon Finder",
    TAB_FIND = "Find Group",
    TAB_POOL = "Who's Looking",
    TAB_OPT = "Options",

    BOSS_LABEL = "Target boss",
    BOSS_REQ = "Requires level %d–%d — you are %d",
    BOSS_CLEARED = "Cleared",
    BOSS_TOGGLE_HINT = "Shift-click: toggle cleared",

    ROLES_LABEL = "Your roles",
    ROLES_HINT = "Pick every role you can actually play — at least one required.",
    ROLE_TANK = "Tank",
    ROLE_HEAL = "Healer",
    ROLE_SUPPORT = "Support",
    ROLE_DPS = "DPS",
    ERR_NO_ROLE = "Select at least one role",

    MIN_LABEL = "Minimum group size",
    MIN_3 = "3+",
    MIN_4 = "4+",
    MIN_5 = "5 only",
    MIN_HINT = "5-player groups are always preferred; smaller sizes widen your match.",

    OPT_LEAD = "I'm willing to lead the group",
    BTN_SEARCH = "Search for Group",
    BTN_CANCEL = "Cancel Search",
    POOL_COUNT = "%d players searching in your bracket",

    PROP_TITLE = "Group Found!",
    PROP_YOU_ROLE = "You were assigned:",
    BTN_ACCEPT = "Accept",
    BTN_DECLINE = "Decline",
    BTN_OKAY = "Okay",
    PROP_TIMER = "%d s to respond",
    PROP_OF = "of",
    PROP_ALL_IN = "everyone accepted — group forming",
    PROP_CANCELLED = "Proposal cancelled",
    PROP_WAIT = "Accepted — waiting for the others…",
    PROP_FORMING = "Everyone accepted — watch for the party invite!",
    PROP_DECLINED = "A player declined — you're back in the search, listing intact.",
    PROP_EXPIRED = "Proposal timed out — back to searching.",
    LEADER = "Leader",

    FILTER_ALL = "All dungeons",
    POOL_EMPTY = "Nobody in this bracket — list yourself to seed it.",
    BROWSER_CLICK_HINT = "Right-click for options",
    BROWSER_INVITE = "Invite to group",
    BROWSER_SUGGEST = "Suggest to group leader",
    BROWSER_WHISPER = "Whisper",
    BROWSER_CANCEL = "Cancel",
    SUGGEST_MSG = "Let's invite %s for %s",
    SUGGEST_POPUP = "%s suggests inviting %s for %s. Invite now?",

    OPT_LANG = "Language",
    LANG_AUTO = "Auto (game client)",
    OPT_MM = "Show minimap button",
    OPT_SOUND = "Play sound on group proposal",
    OPT_HB_INFO = "Heartbeat every %d s · listings expire after %d s",

    CH_OK = "Connected to the matchmaking channel",
    CH_RECON = "Reconnecting to the matchmaking channel…",
    CH_LABEL = "LFG channel",
    CH_RECON_SHORT = "reconnecting…",
    ST_SEARCH_FULL = "Searching — %s · %d in your bracket",

    ST_NOT_ENROLLED = "This character is not enrolled in the Hardcore Boss Blitz challenge",
    NOT_ENROLLED_HINT = "Only enrolled challengers can search. Speak to the Trial Master in your starting zone (level 1) to join the Boss Blitz.",
    ALREADY_GROUPED_HINT = "You're already in a group — leave it to search for a new one.",

    ST_IDLE = "Idle",
    ST_SEARCH = "Searching — %s",
    ST_PROPOSAL = "Proposal pending — answer the popup",
    ST_FORMING = "Group forming — watch for the party invite",
    ST_GROUP = "In group — good luck out there!",
    ST_PAUSED = "Paused — reconnecting to the channel…",

    MSG_BOSS_CLEARED = "%s marked as cleared.",
    MSG_NEWER_PROTO = "A newer version of HCBB Dungeon Finder is out there — consider updating.",
    MSG_USAGE = "/hcbb — toggle window · /hcbb demo · /hcbb debug · /hcbb pool",
}
