std = "lua51"
codes = true
max_line_length = false
self = false

exclude_files = {
    "HCBBDungeonFinder/libs/**",
    ".git/**",
}

-- WoW 3.3.5a API surface used by the addon (NFR-C1: nothing newer), plus
-- the busted DSL for the specs. Applied globally: simpler and portable
-- across luacheck's Windows/Unix path handling.
read_globals = {
    -- frames & UI
    "CreateFrame", "UIParent", "Minimap", "GameTooltip",
    "NUM_CHAT_WINDOWS", "StaticPopup_Show", "CANCEL",
    "FauxScrollFrame_Update", "FauxScrollFrame_GetOffset",
    "FauxScrollFrame_OnVerticalScroll",
    "UIDropDownMenu_Initialize", "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton", "ToggleDropDownMenu", "EasyMenu", "FriendsFrame_ShowDropdown",
    "ChatFrame_RemoveChannel", "ChatFrame_AddMessageEventFilter",
    "ChatFrame_SendTell",
    -- API
    "GetTime", "GetLocale", "GetAddOnMetadata", "GetChannelName",
    "JoinPermanentChannel", "LeaveChannelByName", "SendChatMessage",
    "UnitName", "UnitLevel", "UnitClass", "UnitBuff", "UnitDebuff",
    "GetNumPartyMembers", "GetNumRaidMembers", "IsPartyLeader", "IsRaidLeader",
    "InviteUnit", "RAID_CLASS_COLORS",
    "IsShiftKeyDown", "GetCursorPosition", "PlaySound",
    -- addon loading (loader)
    "LoadAddOn", "IsAddOnLoaded", "EnableAddOn",
    -- libraries & wow lua aliases
    "LibStub", "tinsert", "tremove", "strsplit", "wipe",
}

globals = {
    "HCBB", "HCBB_DB", "UISpecialFrames", "StaticPopupDialogs",
    -- busted DSL (tests/) — also provided by tests/run.lua locally
    "describe", "it", "assert",
}
