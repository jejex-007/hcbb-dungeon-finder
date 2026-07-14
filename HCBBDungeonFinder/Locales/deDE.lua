-- German. Missing keys fall back to enUS. File is UTF-8.
local _, NS = ...
NS.locales = NS.locales or {}

NS.locales.deDE = {
    TITLE = "HCBB Dungeon Finder",
    TAB_FIND = "Gruppe suchen",
    TAB_POOL = "Wer sucht?",
    TAB_OPT = "Optionen",

    BOSS_LABEL = "Zielboss",
    BOSS_REQ = "Erfordert Stufe %d–%d — Ihr seid %d",
    BOSS_CLEARED = "Besiegt",
    BOSS_TOGGLE_HINT = "Umschalt-Klick: besiegt an/aus",

    ROLES_LABEL = "Eure Rollen",
    ROLES_HINT = "Wählt jede Rolle, die ihr wirklich spielen könnt — mindestens eine erforderlich.",
    ROLE_TANK = "Tank",
    ROLE_HEAL = "Heiler",
    ROLE_SUPPORT = "Unterstützung",
    ROLE_DPS = "DPS",
    ERR_NO_ROLE = "Wählt mindestens eine Rolle",

    MIN_LABEL = "Mindestgruppengröße",
    MIN_3 = "3+",
    MIN_4 = "4+",
    MIN_5 = "Nur 5",
    MIN_HINT = "5-Spieler-Gruppen werden immer bevorzugt; kleinere Größen erweitern eure Chancen.",

    OPT_LEAD = "Ich bin bereit, die Gruppe zu leiten",
    BTN_SEARCH = "Suchen",
    BTN_CANCEL = "Suche abbrechen",
    SEARCH_ELAPSED = "Suche — %s",
    POOL_COUNT = "%d Spieler suchen in eurem Bereich",

    PROP_TITLE = "Gruppe gefunden!",
    PROP_YOU_ROLE = "Eure Rolle:",
    BTN_ACCEPT = "Annehmen",
    BTN_DECLINE = "Ablehnen",
    BTN_OKAY = "Okay",
    PROP_TIMER = "%d s zum Antworten",
    PROP_OF = "von",
    PROP_ALL_IN = "alle haben angenommen — Gruppe entsteht",
    PROP_CANCELLED = "Vorschlag abgebrochen",
    PROP_WAIT = "Angenommen — warte auf die anderen…",
    PROP_FORMING = "Alle haben angenommen — achtet auf die Gruppeneinladung!",
    PROP_DECLINED = "Ein Spieler hat abgelehnt — Platz wird neu besetzt.",
    PROP_EXPIRED = "Vorschlag abgelaufen — zurück zur Suche.",
    LEADER = "Leiter",

    FILTER_ALL = "Alle Dungeons",
    POOL_EMPTY = "Niemand in diesem Bereich — tragt euch ein und macht den Anfang.",
    BROWSER_CLICK_HINT = "Rechtsklick für Optionen",
    BROWSER_INVITE = "In die Gruppe einladen",
    BROWSER_SUGGEST = "Dem Gruppenleiter vorschlagen",
    BROWSER_WHISPER = "Flüstern",
    BROWSER_CANCEL = "Abbrechen",
    SUGGEST_MSG = "Laden wir %s für %s ein",
    SUGGEST_POPUP = "%s schlägt vor, %s für %s einzuladen. Jetzt einladen?",

    OPT_LANG = "Sprache",
    LANG_AUTO = "Auto (Spielclient)",
    OPT_MM = "Minikarten-Button anzeigen",
    OPT_SOUND = "Ton bei Gruppenvorschlag abspielen",
    OPT_HB_INFO = "Signal alle %d s · Einträge verfallen nach %d s",

    CH_OK = "Mit dem Suchkanal verbunden",
    CH_RECON = "Verbinde erneut mit dem Suchkanal…",
    CH_LABEL = "LFG-Kanal",
    CH_RECON_SHORT = "verbinde erneut…",
    ST_SEARCH_FULL = "Suche — %s · %d in eurem Bereich",

    ST_NOT_ENROLLED = "Dieser Charakter ist nicht für die Hardcore-Boss-Blitz-Herausforderung angemeldet",
    ST_UPDATE = "Update verfügbar \226\128\148 bitte aktualisiere das Addon",
    NOT_ENROLLED_HINT = "Nur angemeldete Teilnehmer können suchen. Sprecht mit dem Prüfungsmeister in eurem Startgebiet (Stufe 1), um dem Boss Blitz beizutreten.",
    ALREADY_GROUPED_HINT = "Ihr seid bereits in einer Gruppe — verlasst sie, um eine neue zu suchen.",

    ST_IDLE = "Untätig",
    ST_SEARCH = "Suche — %s",
    ST_PROPOSAL = "Vorschlag offen — antwortet im Fenster",
    ST_FORMING = "Gruppe entsteht — achtet auf die Einladung",
    ST_GROUP = "In Gruppe — viel Erfolg!",
    ST_PAUSED = "Pausiert — Kanal wird neu verbunden…",

    MSG_BOSS_CLEARED = "%s als besiegt markiert.",
    MSG_NEWER_PROTO = "Eine neuere Version von HCBB Dungeon Finder ist im Umlauf — bitte aktualisieren.",
    MSG_USAGE = "/hcbb — Fenster öffnen · /hcbb demo — Rundgang",
}
