-- Italian. No itIT client locale exists on 3.3.5 (R21): this language is
-- only reachable through the manual override in Options. Missing keys fall
-- back to enUS. File is UTF-8.
local _, NS = ...
NS.locales = NS.locales or {}

NS.locales.itIT = {
    TITLE = "HCBB Dungeon Finder",
    TAB_FIND = "Cerca gruppo",
    TAB_POOL = "Chi cerca?",
    TAB_OPT = "Opzioni",

    BOSS_LABEL = "Boss bersaglio",
    BOSS_REQ = "Richiede livello %d–%d — sei %d",
    BOSS_CLEARED = "Sconfitto",
    BOSS_TOGGLE_HINT = "Maiusc-clic: segna sconfitto / da fare",

    ROLES_LABEL = "I tuoi ruoli",
    ROLES_HINT = "Scegli ogni ruolo che sai davvero giocare — almeno uno obbligatorio.",
    ROLE_TANK = "Tank",
    ROLE_HEAL = "Curatore",
    ROLE_SUPPORT = "Supporto",
    ROLE_DPS = "DPS",
    ERR_NO_ROLE = "Seleziona almeno un ruolo",

    MIN_LABEL = "Dimensione minima del gruppo",
    MIN_3 = "3+",
    MIN_4 = "4+",
    MIN_5 = "Solo 5",
    MIN_HINT = "I gruppi da 5 hanno sempre la priorità; dimensioni minori ampliano le possibilità.",

    OPT_LEAD = "Sono disposto a guidare il gruppo",
    BTN_SEARCH = "Cerca",
    BTN_CANCEL = "Annulla ricerca",
    SEARCH_ELAPSED = "Ricerca — %s",
    POOL_COUNT = "%d giocatori cercano nella tua fascia",

    PROP_TITLE = "Gruppo trovato!",
    PROP_YOU_ROLE = "Il tuo ruolo assegnato:",
    BTN_ACCEPT = "Accetta",
    BTN_DECLINE = "Rifiuta",
    BTN_OKAY = "OK",
    PROP_TIMER = "%d s per rispondere",
    PROP_OF = "su",
    PROP_ALL_IN = "tutti hanno accettato — formazione del gruppo",
    PROP_CANCELLED = "Proposta annullata",
    PROP_WAIT = "Accettato — in attesa degli altri…",
    PROP_FORMING = "Tutti hanno accettato — attento all'invito al gruppo!",
    PROP_DECLINED = "Un giocatore ha rifiutato — sostituzione in corso.",
    PROP_EXPIRED = "Proposta scaduta — di nuovo in ricerca.",
    LEADER = "Capogruppo",

    FILTER_ALL = "Tutti i dungeon",
    POOL_EMPTY = "Nessuno in questa fascia — iscriviti e fai da apripista.",
    BROWSER_CLICK_HINT = "Clic destro per le opzioni",
    BROWSER_INVITE = "Invita nel gruppo",
    BROWSER_SUGGEST = "Suggerisci al capogruppo",
    BROWSER_WHISPER = "Sussurra",
    BROWSER_CANCEL = "Annulla",
    SUGGEST_MSG = "Invitiamo %s per %s",
    SUGGEST_POPUP = "%s suggerisce di invitare %s per %s. Invitare ora?",

    OPT_LANG = "Lingua",
    LANG_AUTO = "Auto (client di gioco)",
    OPT_MM = "Mostra pulsante sulla minimappa",
    OPT_SOUND = "Riproduci suono alla proposta di gruppo",
    OPT_HB_INFO = "Segnale ogni %d s · gli annunci scadono dopo %d s",

    CH_OK = "Connesso al canale di ricerca",
    CH_RECON = "Riconnessione al canale di ricerca…",
    CH_LABEL = "Canale LFG",
    CH_RECON_SHORT = "riconnessione…",
    ST_SEARCH_FULL = "Ricerca — %s · %d nella tua fascia",

    ST_NOT_ENROLLED = "Questo personaggio non è iscritto alla sfida Hardcore Boss Blitz",
    NOT_ENROLLED_HINT = "Solo i partecipanti iscritti possono cercare un gruppo. Parla con il Maestro delle prove nella tua zona iniziale (livello 1) per unirti al Boss Blitz.",
    ALREADY_GROUPED_HINT = "Sei già in un gruppo — lascialo per cercarne uno nuovo.",

    ST_IDLE = "Inattivo",
    ST_SEARCH = "Ricerca — %s",
    ST_PROPOSAL = "Proposta in attesa — rispondi alla finestra",
    ST_FORMING = "Gruppo in formazione — attento all'invito",
    ST_GROUP = "In gruppo — buona fortuna!",
    ST_PAUSED = "In pausa — riconnessione al canale…",

    MSG_BOSS_CLEARED = "%s segnato come sconfitto.",
    MSG_NEWER_PROTO = "È in giro una versione più recente di HCBB Dungeon Finder — valuta l'aggiornamento.",
    MSG_USAGE = "/hcbb — apri la finestra · /hcbb demo — tour visivo",
}
